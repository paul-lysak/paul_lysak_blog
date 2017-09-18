+++
date = "2017-09-18T14:23:18+03:00"
draft = true
title = "Lessons learned from serverless application development"
tags = ["AWS", "serverless"]
years = ["2017"]
+++

- Intro

- Describe the problem, link to the source code

- Services used:

  - S3 for data storage and application code

  - Cognito for managing users

  - CloudFront for granting access by signed cookie

  - Lamba for resizing the pictures and signing the cookies

  - API Gateway for calling Lambdas via HTTP

- Gotchas

  - Make sure CloudFront behavior URLs are disambiguated, otherwise 404 from first location may prevent from calling subsequest locations

  - Lambdas don't impose request/response restrictions, it depends on services which actually call lambdas.
  There's a library for Java which helps with HTTP Lambdas.

  - Returning binary content from Lambda is tricky

  - The only built-in way to protect API Gateway endpoints - API key 


