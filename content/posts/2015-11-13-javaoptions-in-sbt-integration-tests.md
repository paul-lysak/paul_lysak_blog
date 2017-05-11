---
title: javaOptions in sbt integration tests
date: '2015-11-13T08:40:00.001+02:00'
author: Paul Lysak
tags:
- integration test
- Play2
- Play
- Scala
- sbt
modified_time: '2015-11-13T08:42:07.263+02:00'
blogger_id: tag:blogger.com,1999:blog-5849718801312198988.post-7451322001331516720
blogger_orig_url: http://paullysak.blogspot.com/2015/11/javaoptions-in-sbt-integration-tests.html
years: ['2015']
---
My goal was to make separate config files for run, tests, and integration tests in Play application - so that default settings for database in run and integration test environments would be different, and in tests database settings would be unavailable to make sure that no unit test works with real DB. This may be achieved via `config.resource` [system property](https://www.playframework.com/documentation/2.4.x/Configuration). I've tried to apply solution from http://stackoverflow.com/questions/15399161/how-do-i-specify-a-config-file-with-sbt-0-12-2-for-sbt-test with such code in `build.sbt`:

    lazy val root = (project in file(".")).enablePlugins(PlayScala).
    configs(IntegrationTest).
    settings(Defaults.itSettings : _*).
    settings(javaOptions in Test ++= Seq("-Dconfig.resource=testing.conf")).
    settings(javaOptions in IntegrationTest ++= Seq("-Dconfig.resource=integration.conf"))

But turned out that settings for integration tests have no effect, and default file `application.conf` is still being used. The reason is that `IntegrationTest` configuration is inherited from `Runtime`, not from `Test`, and by default doesn't fork the JVM. And `javaOptions` are applied only to newly started JVMs. So there are few options available how to provide settings for integration tests:

 - Make integration tests fork the JVM with `fork in IntegrationTest := true`. Simple enough, but as system properties from original JVM aren't inherited by forked one, you won't be abie to override settings from configuration file using command line - and it might be essential when running integration tests on CI environment, where DB credentials differ from default.
 - Specify configuration file location as command-line option when starting sbt: `sbt -Dconfig.resource=integration.conf it:test` That leaves more space for mistakes when running tests, as developer needs to keep in mind location of config file (or remember that special script should be used for launching integration tests rather then raw sbt).
 - use `Tests.Setup` to provide custom initialization code before tests run. This way default name of configuration file is defined in `build.sbt`,  but can be overriden from command line, as well as individual options.

I've chosen the last way, here how it looks in `build.sbt`: 

    lazy val root = (project in file(".")).enablePlugins(PlayScala).
    configs(IntegrationTest).
    settings(Defaults.itSettings : _*).
    settings(javaOptions in Test ++= Seq("-Dconfig.resource=testing.conf")).
    settings(testOptions in IntegrationTest += Tests.Setup(() =>
      if(System.getProperty("config.resource") == null)
        System.setProperty("config.resource", "integration.conf")
    ))


