+++
date = "2017-09-18T14:23:18+03:00"
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


### [S3](https://aws.amazon.com/s3/)

Stores original photos in a bucket which isn't publically available and application code in a folder of another bucket.

### [Cognito](https://aws.amazon.com/cognito/)

This is user management service, it has lots and lots of features but here is what we need now:

- maintain users collection, with user attributes and credentials
- authenticate users - make a call from UI containing username and some code derived from password, and get couple of tokens in case of success 
- assign AWS roles to certain users - for example, users may be granted access to certain S3 locations, and having tokens from previous step UI can directly list S3 bucket content, without intermediate server calls

As far as I can see, there's no ready-made UI provided by Cognito - it's purely back-end service: you call it from your code when you need something.
Beware that while Cognito users can be created with AWS console, they won't have all required attributes and they won't be fully functioning immediately - the idea is that admins shouldn't know the passwords of other users. 
You need to develop special UI which is displayed to newly created users after first login, captures missing attributes and new password. Ater saving these attributes 
and updating the password user becomes active.

Cognito has [JavaScript SDK](https://github.com/aws/amazon-cognito-identity-js), so you don't need to construct HTTP requests manually.
This SDK also takes care about storing the token in browser local storage so that user wouldn't need to enter the password after page reload. 
Other AWS services also have [SDK](https://github.com/aws/aws-sdk-js), it integrates nicely with Cognito - you can configure it with token returned by Cognito
and then, for example, get content of S3 folder without providing additional credentials. 

Be prepared that SDKs for different services are a bit of patchwork and style of their API differs a bit. Some services already leverage promises, but Cognito and S3 - not yet, unfortunately. 
They still rely ond plain old callbacks.


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
An important point here is to make sure that URLs of different behaviors don't intersect - otherwise if origin standing behind one behavior  
returns 404, then next behavior which may have satisfied request isn't chedked - CloudFront returns 404. 


### [Lambda](https://aws.amazon.com/lambda/)

What doesn't fit existing high-level services, but is impractical to run on dedicated machine - goes here.
With Lambda you can run any code as a reaction to some events. Currently JDK 8 (Scala works well), C#, Node.js and Python are supported. 
Key feature here is that you pay only for execution time - no cost when function isn't triggered, this makes Lambda very cost-efficient
for rare workloads. And if out of sudden you need to handle large workload - it can scale out almost instantly.

Gallery has 2 lambdas, each doing its job:

- generate signed cookie which grants access to original and resized pictures
- resize the picture to fit into requested bounds. Its results are cached in CloudFront, so no need to worry about persisting the picture - just give it away in response.

Configuration of lambdas is quite convinient via environment variables in AWS console, so no need to package much configuration in the deployment artifact.
What's even better - it can transparently use [KMS](https://aws.amazon.com/kms/) to encrypt sensitive information, so that no other user with access to AWS console
could read it or illegally use it - AWS will only grant access to necessary keys to lambda function itself in order to decrypt the value.
AWS console even can generate decryption code for you - just need to paste it into your project.

[API Gateway](https://aws.amazon.com/api-gateway/)

Lambdas on their own know nothing about HTTP - they are merely generic functions which can be bound to wide range of events.
API Gateway is the only way to bound them to HTTP requests. The way endpoints/methods are configured in APi Gateway defines
request and response format for Lambda functions. When using `LAMBDA_PROXY` request types 
(the easiest option - you don't need to configure each parameter manually in this case),
you may find [library from awslabs](https://github.com/awslabs/aws-serverless-java-container) useful - it provides 
classes for request and response. Unfortunately, API Gateway method is configured to use Cognito authentication - those 
classes don't capture all user information accurately enough.

There's a catch regarding picture resizing lambda security - unlike most AWS services, API Gateway endpoints can't be restricted to only allow access from other AWS services,
and not from the internet. All your APIs are open to the world.
Such restriction would be very helpful as actual authorization happens in CloudFront - using signed cookies it desides whether user can access the content or not.
As I said earlier, this is essential in order to have stable URLs and thus make them cache efficiently. There's no easy way to provide additional credentials
to resizer lambda function. The only reasonable solution (or rather workaround) which I could find is to use API key - it's just an obscure sequence of numbers and letters generated by API Gateway console,
API may be configured to require such key to be specified in `x-api-key` header. And CloudFront distribution origin may be configured to send such header. 
This solves the problem, however I'm not very happy with solution as the key doesn't rotate with time - need to think of more secure approach.


