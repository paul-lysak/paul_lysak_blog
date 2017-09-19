+++
date = "2017-09-18T14:23:18+03:00"
draft = true
title = "Lessons learned from serverless application development"
tags = ["AWS", "serverless"]
years = ["2017"]
+++

I'd like to share some experience from serverless pet project - [photo gallery](https://github.com/paul-lysak/gallery-proto).
The idea was to be able to browse family photos backed up to Amazon S3 storage service.
They should not be publically available - only authenticated users must be able to browse.
When browsing the photos they must be resized to screen size in order to avoid excessive traffic,
resized photos must be cached for subsequent requests.
And it must be cost-effective - as I don't need this tool very often, 
I don't want to pay for constantly running full-featured server which performs useful job just few hours a year. 
Luckily, Amazon has a rich set of high-level services which can be combined to solve the problem. 
Let's talk which services were used in this project and how they play together.

## Services used

### [S3](https://aws.amazon.com/s3/)

Stores the original photos in a bucket which isn't publically available and application code in a folder of another bucket.

### [Cognito](https://aws.amazon.com/cognito/)

This is user management service, it has lots and lots of features but here is what we need now:

- maintain users collection, with user attributes and credentials
- authenticate users - make a call from UI containing username and some code derived from password, and get couple of tokens in case of success 
- assign AWS roles to certain users - for example, users may be granted access to certain S3 locations, and having tokens from previous step UI can directly list S3 bucket content, without intermediate server calls

Cognito has [JavaScript SDK](https://github.com/aws/amazon-cognito-identity-js), so you don't need to construct HTTP requests manually.


### [CloudFront](https://aws.amazon.com/cloudfront/) 

Is a content distribution network. Besides caching resized pictures, 
the most important feature for me was ability to [protect content with signed cookies](http://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-signed-cookies.html) - 
you can configure some content (behaviors) to be available only when special cookie is provided. 
Some clarification - in CloudFront distribution most imporant concepts are origins (where from do you take content) 
and behaviors (where end users can take it from you).

In my configuration, a single CloudFront distribution gathers under different sub-folders following content:

- original full-size pictures (restricted access)
- endpoint for resizing the pictures (restricted access)
- endpoint for generating signed cookies (non-restricted in CloudFront, underlying API Gateway endpoint requires authentication)
- application UI code
- application UI config file 

As everything is under the single domain name, cross-origin request issues are avoided and it's easier to make sure cookies are used safely.


### [Lambda](https://aws.amazon.com/lambda/)

What doesn't fit existing high-level services, but is impractical to run on dedicated machine - goes here.
With Lambda you can run any code as a reaction to some events. Currently JDK 8 (Scala works well), C#, Node.js and Python are supported. 
Key feature here is that you pay only for execution time - no cost when function isn't triggered, this makes Lambda very cost-efficient
for rare workloads. And if out of sudden you need to handle large workload - it can scale out almost instantly.

Gallery has 2 lambdas, each doing its job:

- generate signed cookie which grants access to original and resized pictures
- resize the picture to fit into requested bounds. Its results are cached in CloudFront, so no need to worry about persisting the picture - just give it away in response.

[API Gateway](https://aws.amazon.com/api-gateway/)

Lambdas on their own know nothing about HTTP - they are merely generic functions which can be bound to wide range of events.
API Gateway is the only way to bound them to HTTP requests. The way endpoints/methods are configured in APi Gateway defines
request and response format for Lambda functions. When using `LAMBDA_PROXY` request types 
(the easiest option - you don't need to configure each parameter manually in this case),
you may find [library from awslabs](https://github.com/awslabs/aws-serverless-java-container) useful - it provides 
classes for request and response. Unfortunately, API Gateway method is configured to use Cognito authentication - those 
classes don't capture all user information accurately enough.


## Gotchas

  - AWS JavaScript libraries are kinda patchwork - different styles of API for each service. Don't be surprised by this. 
  And Cognito JavaScript API at the moment doesn't support promises, it relies on old schoold callbacks.

  - Can't get fully functioning users just with Cognito, need to develop some UI to fill missing parts and reset the password

  - Make sure CloudFront behavior URLs are disambiguated, otherwise 404 from first location may prevent from calling subsequest locations

  - Lambdas don't impose request/response restrictions, it depends on services which actually call lambdas.
  There's a library for Java which helps with HTTP Lambdas.

  - Returning binary content from Lambda is tricky

  - The only built-in way to protect API Gateway endpoints - API key 


