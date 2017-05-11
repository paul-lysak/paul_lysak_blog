---
title: Futures and blocking in Scala
date: '2015-03-20T17:04:00.001+02:00'
author: Paul Lysak
tags:
- reactive
- Scala
modified_time: '2016-03-31T16:30:35.880+03:00'
blogger_id: tag:blogger.com,1999:blog-5849718801312198988.post-5479024973672203681
blogger_orig_url: http://paullysak.blogspot.com/2015/03/futures-and-blocking-in-scala.html
years: ['2015']
---
Quite often I see around ignorance about core concept around `Future`s in Scala: transition from synchronous to asynchronous code and back, execution context configuration and so on. I've shot myself in the leg with same mistakes once, and then had to dive into the details and make the picture clear for myself. Here I'd like to share some lessons learned and make `Future`s a little less "magic".

# Let's remind ourselves some basic primitives
Just to make sure we're on the same page. Synchronous code always runs in a single thread and waits for step 1 to complete before going to step 2. So dependency between operations is expressed by order of expressions in the code. Asynchronous may run in multiple threads and use different forms of callbacks to build dependencies between operations. `Future` is an example of asynchronous code.

Whenever you'd like to run some code in background (therefore turning synchronous code into asynchronous):

    val f = Future({doSomeStuff()})
    doOtherStuff()

In this piece of code `doSomeStuff()` starts to run and then `doOtherStuff()` starts - without waiting for `doSomeStuff()` to complete. These 2 functions most probably will run in parallel.

When you have some `Future` you may specify some transformations on it. They will run asynchronously. Example:

	val f2 = f.map({num => num*2})
	yetAnotherStuff()

Again, this would return immidiately and proceed to `yetAnotherSutff()`, and eventually when result of `f` is available - calculate `f2` as well

Whenever you have some `Future` and you absolutely need to get its result right now (even if you might need to stop the world for it):

	import scala.concurrent.duration._
	val v = Await.result(f, 5 seconds)
	moreNewStuff()

This converts asynchronous code to synchronous - current thread blocks until result is available for up to 5 seconds. Afterwards it either goes on with some known value `v`, or throws timeout exception. Unlike previous examples `moreNewStuff()` isn't started until `f` is complete (or times out).

In order for all this code to run you need an `ExecutionContext` - it provides thread pool which will be used for running background tasks. Simplest way to get it:

	import scala.concurrent.ExecutionContext.Implicits.global

Now let's take a look what might go wrong.

# Blocking in standard pool

Moving slow I/O operations to background is often highly desired. It may be easy when underlying I/O layer runs asynchronously and only needs a thread to prepare data for sending/handle received data. Such API may be efficiently wrapped into "honest" `Future`s. A good example is Finagle/Netty stack. But what if you're obliged to use API which is inherently blocking? For example, some wrapper for WebDriver, or Amazon Java SDK, or JDBC. Luckily `Future.apply` may help:

	import scala.concurrent.ExecutionContext.Implicits.global
	val res = Future({myLongIOOpertion()})
	val res2 = res.map(r => myPostProcessing(r))
	
But at what cost does it come? At cost of exhausting precious resource of threads in default `ExecutionContext`. How many threads are there? The answer can be found in `scala.concurrent.impl.ExecutionContextImpl` in standard Scala library. It's controlled by `scala.concurrent.context.minThreads`, `scala.concurrent.context.numThreads` and `scala.concurrent.context.maxThreads`. By default they're all equal to `Runtime.getRuntime.availableProcessors`. So on modern desktop you'll probably have 4, 8 or 16 threads. If code runs on some VM in the cloud - there's high chance that you'll get only *one* thread in that pool. Therefore while you have even *one* long I/O operation running - no other operations on `Future`s or parallel collections can run. Even simplest `.map` or `.filter` on results of asynchronous operations. What can we do about it if we still do need long tasks on background? In the end, there may be some long calculations which do need a thread for all their time. 

# Alternative thread pool

Luckily,  you may specify custom ExecutionContext in which `Future`-related operations should run. Here is example how you can define it:

	import scala.concurrent.ExecutionContext
	import java.util.concurrent.Executors
	val THREAD_POOL_SIZE = 5
	implicit val executionContext = ExecutionContext.fromExecutorService(Executors.newFixedThreadPool(THREAD_POOL_SIZE))

Now all performance issues become a local issue, and long operation can't kill performance of all application.

# Tell current pool to grow

If your execution context is backed by `ForkJoinPool` (default one usually is), you may [instruct](http://docs.scala-lang.org/overviews/core/futures.html#the-global-execution-context) it to grow to some extent by wrapping blocking code in `scala.concurrent.blocking`:

    import scala.concurrent.blocking
    
    Future {
      blocking {myLongIOOpertion()}
    }

# How about Finagle Futures?

At it's core Finagle `Future`s are very similar to standard Scala `Future`s (in fact, Finagle inspired all this API). However, important difference is that Finagle doesn't allow to specify custom thread pool. To good or bad, Finagle uses single global object `com.twitter.concurrent.Scheduler` to run its jobs, and it can be customized only globally. Default implementation sticks to Netty's pool of worker threads which is pretty limited. Therefore for Finagle things get stricter: long operations (including `Await`s) in their methods will almost certainly lead to severe problems. If you really need to so some kind of such thing as a reaction to Finagle's `Future` completion - wrap it in Scala's standard `Future` and define custom `ExecutionContext`. Therefore the job of Finagle's `Scheduler` would be just to resolve Scala's `Future` - it's blazingly fast. And all the heavy lifting would run in custom `ExecutionContext`

# Conclusion

Therefore rule of thumb: *avoid running long operations in standard ExecutionContext*, it's intended for relatively simple operations that convert the result retrieved from elsewhere. Another lesson that I've learned from my past failures - *beware of `Await.result(Future.apply())` chains*. They may rise as a result of attempt to make your API look asynchronously, while you really need to use it in synchronous context. Such chains give you no benefit, they just waste resources and increase risks.


