---
title: "FS2: how to stop the queue"
date: 2018-05-09T13:33:57+03:00
tags: ["fs2", "scala"]
years: ["2018"]
---

If you want to get 

[FS2](https://functional-streams-for-scala.github.io/fs2/) is a streaming library for Scala which offers more lightweight and more "functional" 
alternative to [Akka Streams](https://doc.akka.io/docs/akka/2.5/stream/index.html). However, as it's relatively young it either misses some functionality,
or has it available in non-obvious way and lacks appropriate documentation. One such example is retrieving data from callback-based API which 
expects an interface with callbacks for next element, stream end and stream failure - like [Subscriber](http://www.reactive-streams.org/reactive-streams-1.0.2-javadoc/org/reactivestreams/Subscriber.html) from Reactive Streams Initiative. If your data provider actually exposes Reactive Streams - compatible API then you can
use [fs2-reactive-streams](https://github.com/zainab-ali/fs2-reactive-streams) library. 
If it only follows general approach and API doesn't implement actual Ractive Streams interfaces - you'll have a hard time connecting `fs2-reactive-streams` to your data provider.

For such custom integration you most probably will want to use the [Queue](https://github.com/functional-streams-for-scala/fs2/blob/series/0.10/core/shared/src/main/scala/fs2/async/mutable/Queue.scala). Unfortunately, unlike a (Queue in Akka Streams)[https://doc.akka.io/japi/akka/current/akka/stream/scaladsl/SourceQueueWithComplete.html],
it only has a method for receiving new element - no way to signal that the data stream has ended or failed. There are, however, ways to work around this issue.
One solution is to use `Either[Throwable, Option[A]]` where `A` is your element type. Here is an example with some simplifications: 


    val queue = fs2.async
      .boundedQueue[IO, Either[Throwable, Option[String]](maxSize = 100)
      .unsafeRunSync()

    someApi.getData(new SomeDataListener(
      override def onElement(element: String): Unit = {
        queue.enqueue1(Right(Some(element))).unsafeRunSync()
      }

      override def onEnd(): Unit = {
        queue.enqueue1(Right(None)).unsafeRunSync()
      }

      override def onError(throwable: Throwable): Unit = {
        queue.enqueue1(Left(throwable)).unsafeRunSync()
      }
    ))

    val stream: fs2.Stream[IO, String] = queue.dequeue
      .map {
        case Left(throwable) => throw throwable
        case Right(elementOpt) => elementOpt
      }
      .takeWhile(_.isDefined)
      .map(_.get)

Thus you'll get a stream of elements which completes as soon as the queue has `Left(Throwable)` or `Right(None)`.
There's one thing to notice, however - if there's a failure, the elements which have already been queued will continue to flow
through the stream. If we want a fail fast behavior (i.e. abort the stream as soon as there's an error) we may use a `fs2.Promise`
together with `Stream.interruptWhen`. Here is another example:

    val queue = fs2.async
      .boundedQueue[IO, Option[String](maxSize = 100)
      .unsafeRunSync()

    val terminationPromise = fs2.async
      .promise[IO, Either[Throwable, Unit]]
      .unsafeRunSync

    someApi.getData(new SomeDataListener(
      override def onElement(element: String): Unit = {
        queue.enqueue1(Some(element)).unsafeRunSync()
      }

      override def onEnd(): Unit = {
        queue.enqueue1(None).unsafeRunSync()
      }

      override def onError(throwable: Throwable): Unit = {
        terminationPromise.complete(Left(exception)).unsafeRunSync()
      }
    ))

    val stream: fs2.Stream[IO, String] = queue.dequeue
      .interruptWhen(terminationPromise.get)
      .takeWhile(_.isDefined)
      .map(_.get)

Notice that `interruptWhen` aborts the reading side immediately upon receiving signal with `terminationPromise` - that's why it can't be used alone to signal
data input termination: reading will be aborted while there are still some unread data in the queue.

In real world you would want to avoid using `unsafeRunSync` when creating a `Queue` and a `Promise` and use `flatMap` or for-comprehension, 
probably together with `fs2.Stream.eval`, to make sure that your code is lazily evaluated and referentially transparent.


