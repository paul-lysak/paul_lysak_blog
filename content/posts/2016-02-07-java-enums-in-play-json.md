---
title: Java Enums in Play Json
date: '2016-02-07T08:05:00.001+02:00'
author: Paul Lysak
tags:
- Play2
- Play
- Scala
- JSON
modified_time: '2016-02-07T08:08:33.327+02:00'
blogger_id: tag:blogger.com,1999:blog-5849718801312198988.post-2898546575984250164
blogger_orig_url: http://paullysak.blogspot.com/2016/02/java-enums-in-play-json.html
years: ['2016']
---
I prefer using Java Enums even in Scala code, because unlike Scala enums they're distinguished by actual type, not just type parameter. Thus they still can be distinguished after compilation, unlike Scala enums which end up as the same type after type erasure (at least if not taking into account experimental tricks like [type tags](http://docs.scala-lang.org/overviews/reflection/typetags-manifests.html)). 

Unfortunately, Play doesn't have built-in support for Java enum serialization/deserialization to/from JSON at the moment (v. 2.4.2). But it's pretty easy to write generic code that extends to any enum you want.

`Writes` can be implemented once for all enums:

    implicit val enumWrites = new Writes[Enum[_]] {
      def writes(e: Enum[_]) = JsString(e.toString)
    }

while `Reads` should statically resolve type of enum, and therefore should there should be separate `Reads` for each enum. But big piece of common code can be shared:

    def enumReads[T <: Enum[T]](mkEnum: String => T) = new Reads[T] {
      override def reads(json: JsValue): JsResult[T] =
        json match {
          case JsString(s) => try {
            JsSuccess(mkEnum(s))
          } catch {
            case e: IllegalArgumentException =>
              JsError("Not a valid enum value: " + s)
          }
          case v => JsError("Can't convert to enum: " + v)
        }
    }

    implicit val firstEnumReads = enumReads(FirstEnum.valueOf)
    implicit val secondEnumReads = enumReads(SecondEnum.valueOf)
    ...

