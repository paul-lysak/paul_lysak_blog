---
title: Iteratees raison d'être
date: '2015-01-02T19:17:00.001+02:00'
author: Paul Lysak
tags:
- Play2
- iteratee
- Scala
modified_time: '2015-01-08T19:57:48.401+02:00'
blogger_id: tag:blogger.com,1999:blog-5849718801312198988.post-2090501424136961474
blogger_orig_url: http://paullysak.blogspot.com/2015/01/iteratee-raison-detre.html
years: ['2015']
---
[Iteratees](https://www.playframework.com/documentation/2.3.x/Iteratees) were pretty hard concept to grasp for me. Thanks to nice article http://mandubian.com/2012/08/27/understanding-play2-iteratees-for-normal-humans/ I managed to understand what it is and how it works, but event then it wasn't clear for me why one may need it - mentioned features seem to be achievable with simpler tools like 
Scala lazy Streams (http://scala-lang.org/api/current/#scala.collection.immutable.Stream) and RxScala observables (http://reactivex.io/documentation/observable.html):
 
 1. Backpressure (produce data with such speed that consumer has time to process it) - lazy Streams do exactly this thing: element of Stream isn't evaluated until someone attempts to retrieve it. RxScala observables at the moment seem to miss this feature.
 2. Ability to stop processing before input ends - for some cases lazy Stream has ready-made methods like `find`, `collectFirst` etc. which return result without iterating the full data set. Observables may be unsubscribed to stop processing. Iteratees as far as I see always require rather complex custom code.
 3. Composition - both lazy streams and observables allow composition of processing step in monad-like way.
 4. Asynchronous, non-blocking - observables are non-blocking as well. Lazy streams miss this point and it can be just partly emulated by wrapping into `Future`.

From these points in my mind arise such things as Scala lazy Streams (http://scala-lang.org/api/current/#scala.collection.immutable.Stream) and RxScala observables (http://reactivex.io/documentation/observable.html). They seem much simpler to understand then iteratees, that's why there's a natural question: what features do iteratees provide that make them worth learning (btw - I think this is the best introduction article: http://mandubian.com/2012/08/27/understanding-play2-iteratees-for-normal-humans/)?

I've implemented 2 pretty simple tasks (print all elements and calculate sum of all elements of a Seq) with each technology in order to feel the difference. Full code is available here: https://github.com/paul-lysak/misc_learning/blob/master/iteratee/play-iteratee/test/IterateeSpec.scala .

Having sample data let's look at all implementations and then compare them:

	val data = Seq[Int](10, 20, 30, 40, 50)

Iteratee implementation:

	val itPrint = Iteratee.foreach[Int](a => println("element="+a))
	val itSum = Iteratee.fold[Int, Int](0)(_ + _)
	
	val en = Enumerator(data: _*)
	val fp1 = en.run(itPrint)
	Await.ready(fp, DurationInt(10).seconds)
	
	val fs1 = en.run(itSum)
	fs1.foreach(s => println("sum="+s))

Lazy Stream implementation:

	val str = data.toStream
	str.foreach(a => println("elStr="+a))
	
	val s = str.fold(0)(_ + _)
	println("sumStr="+s)

RxScala observable:

	val o = Observable.from(data)
	val o1 = Observable.from(data)
	
	o.subscribe(a => println("rxItem="+a))
	
	val so = o1.foldLeft(0)(_ + _)	
	so.subscribe(a => println("rxSum="+a))

At its core trait `play.api.libs.iteratee.Iteratee` just defines reaction to 3 possible events (next item, empty input, end of input) in a pretty complex way. So constructing manually is pretty tedious and error-prone. However, luckily `Iteratee` companion object contains couple of utility methods that hide most of complexity and make Iteratee construction almost as simple as `fold` or `map` on regular collections - see examples in code above. But still - what makes Iteratees special? Here is what I can say:

 1. Unlike Streams and Observables, iteration logic is fully decoupled from data source. That means that you can define Iteretee before defining data source. I would call this killer feature of Iteratees - both stream and observable require that corresponding stream or observable already exist before doing foreach/map/fold/etc. . 
 2. Ability to reduce threads consumption. Iteratee construction methods come in 2 flavours - blocking and non-blocking. For example, object `Iteratee` has method `def fold[E, A](state: A)(f: (A, E) => A)` and `def foldM[E, A](state: A)(f: (A, E) => Future[A])`. First one (`fold`) is blocking - despite the fact that `Enumerator.run` returns `Future` when called with such `Iteratee` and doesn't block current thread, 1 thread from `ExecutionContext` will be 100% time busy with Iteratee until that `Future` completes - no matter what job Iteratee is doing. Second method (`foldM`) is non-blocking - as a reaction for new element it may run slow I/O operation and return `Future` that will be completed after I/O end. Thus the thread will be used only for doing actual job by CPU when sending I/O operation or processing its result. That's clear advantage compared to lazy stream (which could be packed in future to partly emulate asynchronous behavior), but observables do the things this way too.
 3. Remainder handling - if there's an error during some element processing, or Iteratee decides to stop before reaching input end, there are means to get failed element and remaining part of input. So we may retry operation or go on processing with another iteratee. That may be nice advantage in some special cases compared both to lazy streams and observables.

Conclusion: Iteratees seem to have richer feature set then similar tools, but it is harder to use. I would call 2 cases when I would definitely stick to Iteratees:

 1. When asynchronous handling (slow I/O for each element) and backpressure required at the same time
 2. When iteration logic should be strongly decoupled from data source

