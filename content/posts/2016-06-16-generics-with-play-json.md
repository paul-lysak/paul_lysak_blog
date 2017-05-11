---
title: Generics with Play JSON
date: '2016-06-16T18:49:00.001+03:00'
author: Paul Lysak
tags:
- Play2
- Play
- Scala
- JSON
modified_time: '2016-06-16T18:54:40.651+03:00'
blogger_id: tag:blogger.com,1999:blog-5849718801312198988.post-7918852045742067541
blogger_orig_url: http://paullysak.blogspot.com/2016/06/generics-with-play-json.html
years: ['2016']
---
As Play JSON library uses implicits in order to know how to serialize/deserialize some object the type of that object has to be known at compile time. This makes serializing/deserializing generic classes not that straightforward - even if you know at compile time type which is substituted in generic class type parameter, you need to provide somehow reads/writes for each such type, not just for single generic class. The trick is to use `def` instead of `val`. Here is an example

Say, we have reads and writes for some classes `Foo` and `Bar`, and we'd like to serialize/deserialize such containers with them:

    case class MyContainer1[T](data: Seq[T])
    case class MyContainer2[T](name: String, data: Seq[T])


You'll need to define writes like this:

    implicit def myContainer1Writes[T](implicit dw: Writes[T]) = 
      new Writes[SeqContainer[T]] {
        override def writes(o: SeqContainer[T]): JsValue =
          Json.toJson(Map("data" -> o.data))
    }
    
    implicit def myContainer2Writes[T](implicit dw: Writes[T]) = 
      new Writes[SeqContainer[T]] {
        override def writes(o: SeqContainer[T]): JsValue =
          Json.toJson(Map("name" -> o.name, "data" -> o.data))
    }

and reads like this:

    implicit def myContainer1Reads[T](implicit dr: Reads[T]):
      Reads[SeqContainer[T]] = 
	     (JsPath \ "data").read[Seq[T]].map(MyContainer2[T])

	implicit def myContainer2Reads[T](implicit dr: Reads[T]):
	  Reads[SeqContainer[T]] = (
         (JsPath \ "name").read[String] and
	     (JsPath \ "data").read[Seq[T]]
	   )(MyContainer2[T] _)

And now having these implicits in your scope you can write:

    val foos1: Seq[Foo] = ...
    val json: JsValue = Json.toJson(MyContainer1(foos))
    val foos2: Seq[Foo] = json.as[MyContainer1[Foo]].data
    foos2 must be(foos1)

