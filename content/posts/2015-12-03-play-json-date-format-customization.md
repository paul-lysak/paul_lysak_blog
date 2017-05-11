---
title: Play Json date format customization
date: '2015-12-03T08:41:00.001+02:00'
author: Paul Lysak
tags:
- Play2
- Play
- Scala
- JSON
modified_time: '2015-12-03T08:43:43.756+02:00'
blogger_id: tag:blogger.com,1999:blog-5849718801312198988.post-703190592152901381
blogger_orig_url: http://paullysak.blogspot.com/2015/12/play-json-date-format-customization.html
years: ['2015']
---
By default Play Json just truncates time zone when working with ZonedDateTime from Java 8.
So the following code:

    case class MyClass(createdAt: ZonedDateTime)
    implicit val myWrites = Json.writes[MyClass]
    ...
    val d = MyClass(ZonedDateTime.parse("2015-10-01T12:13:14.00+02:00"))
    val json = Json.toJson(d)

would produce following Json: `{"createdAt": "2015-10-01T12:13:14"}`. That's because `play.api.libs.json.DefaultWrites.DefaultZonedDateTimeWrites` uses same formatter as `DefaultLocalDateTimeWrites` and simply disregards time zone. To display the time zone together with date time you'll need to add following code before `myWrites`:

      implicit val timeWrites: Writes[ZonedDateTime] =
	     Writes.temporalWrites[ZonedDateTime, DateTimeFormatter](DateTimeFormatter.ISO_DATE_TIME)

And then Json result will change to `{"createdAt": "2015-10-01T12:13:14+02:00"}`
