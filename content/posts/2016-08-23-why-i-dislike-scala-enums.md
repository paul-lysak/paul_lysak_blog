---
title: Why I dislike Scala enums
date: '2016-08-23T19:42:00.001+03:00'
author: Paul Lysak
tags:
- Java
- Scala
modified_time: '2016-08-23T19:42:48.759+03:00'
blogger_id: tag:blogger.com,1999:blog-5849718801312198988.post-7037365049768924912
blogger_orig_url: http://paullysak.blogspot.com/2016/08/why-i-dislike-scala-enums.html
years: ['2016']
---
I came to conclusion that even in fully-Scala projects it's better to define enums using Java. Even third-party libraries that have support for Scala enums suffer from the fact that in runtime all Scala enums have the same type. So if you get some enum value - you have no way to tell to which enum type does it belong. Let me show you how bad it can be with `json4s`. If you have such enums:

    object FooVersion extends Enumeration {
      val V1, V2, V3 = Value
    }
    object BarVersion extends Enumeration {
      val V1, V2, V3 = Value
    } 

and such formats:

    implicit val formats = org.json4s.DefaultFormats +
      new org.json4s.ext.EnumNameSerializer(FooVersion) +
      new org.json4s.ext.EnumNameSerializer(BarVersion)

you will be able to serialize and deserizlize the data:

    val d1 = SampleData(name = "first foo", version = FooVersion.V1)
    println("original: " + d1)
    val s1 = Serialization.write(d1)
    println("serialized: " + s1)
    val ds1 = Serialization.read[SampleData](s1)
    println("deserialized: " + ds1)

and it will look the same:

    original: SampleData(first foo,V1)
    serialized: {"name":"first foo","version":"V1"}
    deserialized: SampleData(first foo,V1)

but the objects are not going to be equal!

    println("original == deserialized: " + (d1 == ds1))

prints following result:

    original == deserialized: false

With debugger you may inspect private fields and discover that type of `d1.version.scala$Enumeration$$OuterEnum` is `FooVersion$`, and of `ds1.version.scala$Enumeration$$OuterEnum` - `BarVersion$`.

