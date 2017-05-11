---
title: Mockito and default parameters in Scala
date: '2016-12-05T19:25:00.001+02:00'
author: Paul Lysak
tags:
- testing
- Scala
- Mockito
modified_time: '2016-12-05T19:26:04.162+02:00'
blogger_id: tag:blogger.com,1999:blog-5849718801312198988.post-7503225977278887748
blogger_orig_url: http://paullysak.blogspot.com/2016/12/mockito-and-default-parameters-in-scala.html
years: ['2016']
---
Suppose we need to mock such service and verify that `doSomething` is called exactly once, and then no interaction happens with the service:

    class SomeService {
        def doSomething(from: Int = 0, to: Int = 10): Unit = {
          //... implementation ...
        }

        //... other methods ...
    }

A common approach to do it:

    val serviceMock = Mockito.mock(classOf[SomeService])
    
    //run tested code which invokes this:
    serviceMock.doSomething() 

    Mockito.verify(serviceMock).search(0, 10)
    Mockito.verifyNoMoreInteractions(serviceMock)

But here's surprise: it fails with such error message:

    Argument(s) are different! Wanted:
    doSomething.search(0, 10);
    -> at .....
    Actual invocation has different arguments:
    doSomething.search(0, 0);
    -> at ....

Somehow, default params weren't picked - instead `doSomething` was called with zeros. The mistery continues if we replace `Mockito.verify` line with this one:

    Mockito.verify(serviceMock).search(Matchers.anyInt(), Matchers.anyInt())

Now error message tells us:

    No interactions wanted here:
    -> at ...
    But found this interaction:
    -> at ...
    ***
    For your reference, here is the list of all invocations ([?] - means unverified).
    1. [?]-> at ...
    2. [?]-> at ...
    3. -> at ...

We honestly call `doSomething()` one time and never call other methods of `SomeService`. Where from did other 2 calls appear then? Time to look at actual Java representation of default params. Go to the `target` folder of the project and find the folder with `SomeService.class`. Then run `javap SomeService'. You'll find something like this in the output:

    public void doSomething(int, int);
    public int doSomething$default$1();
    public int doSomething$default$2();

That pretty much explains our issues: when you omit parameters and expect to have default values, Scala compiler adds behind the scenes calls to the methods which return those parameters. That's how additional 2 calls appear. And as the mock doesn't have return values specified for those methods, it just returns zeros.

