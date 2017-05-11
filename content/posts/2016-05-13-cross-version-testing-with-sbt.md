---
title: Cross-version testing with SBT
date: '2016-05-13T14:32:00.001+03:00'
author: Paul Lysak
tags:
- Play2
- Play
- testing
- Scala
- sbt
modified_time: '2016-05-13T14:35:26.669+03:00'
blogger_id: tag:blogger.com,1999:blog-5849718801312198988.post-6606193284822942861
blogger_orig_url: http://paullysak.blogspot.com/2016/05/cross-version-testing-with-sbt.html
years: ['2016']
---
I'd like to share my experience on testing versions compatibility with sbt. The system which had to be tested consists of server (Play application) and a client - library that exposes server functionality to other apps. Not all apps that use client library may be updated fast enough with new version of server, so before deploying new server version we must check that client versions which are in use currently keep working. Moreover, tests for the client should demonstrate using it in Play application. Therefore, 2 Play apps should run simultateously during the tests, often with different versions. Read on if you're interested for solution for such task. 

# Project structure

Both server, client and cross-version tests are sub-projects inside of common project. They share the same version via `version.sbt`. Here are the most important dirs and files:

    /my-proj
     +-/project
     |  +-MyTestUtils.scala
     +-/my-client
     |  +-build.sbt
     +-/my-client-tests
     |  +-/my-server-launcher
     |  |  +-build.sbt
     |  +-/app
     |  +-/conf
     |  |  +-clientTest.conf
     |  |  +-clientTest.routes
     |  +-/it
     |  |  +-/scala
     |  +-build.sbt
     +-/my-server
     |  +-/app
     |  +-/conf
     |  +-build.sbt
     +-build.sbt
     +-version.sbt

`my-server` and `my-client` are nothing special, just regular Play project and regular Scala project. Other files deserve specific attention.

# my-client-tests/my-server-launcher/build.sbt

    name := "my-server-launcher"

    val serverVersion = System.getProperty("serverVersion")

    if(serverVersion != null) {
        libraryDependencies += "my.org" %% "my-server" % serverVersion
    } else {
        libraryDependencies += "my.org" %% "my-server" % version.value
    }

This makes possible to launch specific version of server, as long as it's available in artifactories known to your project. Stepping forward and assuming that `my-server-launcher` is known as `myServerLaucher` to root project:

    sbt ";project myServerLauncher; run 9000" -DserverVersion=1.2.3

# my-client-tests/build.sbt

    name := "my-client-tests"

    libraryDependencies ++= Seq(
      ws,
      "org.scalatestplus" %% "play" % "1.4.0" % "it,test"
    )

    sourceDirectory in IntegrationTest := baseDirectory.value / "it"

    Keys.fork in IntegrationTest := true
    javaOptions in IntegrationTest += "-Dconfig.resource=clientTest.conf"

    routesGenerator := InjectedRoutesGenerator

As `my-client-tests` is a Play application which demostrates how to use `my-client`,  it requires usual Play configuration - like `routesGenerator`. Play plugin for this subproject is enabled in root project, I'll describe that a bit later. Important point is that`Key.fork` is set to `true` - it enables to run fake app for [integration/functional tests](https://www.playframework.com/documentation/2.4.x/ScalaFunctionalTestingWithScalaTest) with different config file then `my-server`. Otherwise javaOptions would be ignored.

# project/MyTestUtils.scala


    import sbt.Keys._
    import sbt._

    object MyTestUtils {
      private val serverPort = 9001
      lazy val acceptanceCommand: Command = Command.command("acceptance")({(state) =>
        var s = state
        s = Command.process("project myServerLauncher", s)
        s = Command.process("set PlayKeys.playInteractionMode := play.sbt.StaticPlayNonBlockingInteractionMode", s)
        s = Command.process(s"run $serverPort", s)   
        s = Command.process("project myClientTests", s)
        val serverUrl = s"http://localhost:$serverPort"
        s = Command.process(s"""set javaOptions in IntegrationTest ++= Seq(""-DtestServerUrl=$serverUrl") """.trim, s)
        s = Command.process(s"it:test", s)
        s
      })
    }

`MyTestUtils.acceptanceCommand` will be attached to root project and run the tests together with server. Sbt task wouldn't work here because we need to execute Play `run` which is a command itself. Pay attention to `playInteractionMode` which makes Play app run in background, together with tests. Also important point is that `testServerUrl` environment variable is passed to the tests and can be used to correctly configure the client.

# root project build.sbt

    name := "my-proj"
    
    scalaVersion := "2.11.7"
    organization := "my.org"
    
    lazy val root = (project in file(".")).
    aggregate(myServer,
      myClient,
      myClientTests).
    settings(
      aggregate in test := false /*to avoid running tests from myClientTests in incorrect environment*/
      ).
    configs(IntegrationTest).
    settings(Defaults.itSettings: _*)


    parallelExecution in Test := true
    parallelExecution in IntegrationTest := false

    lazy val myServer = project.in(file("my-server"))

    lazy val myClient = project.in(file("my-client"))

    lazy val myServerLauncher = project.in(file("my-client-tests/my-server-launcher")).enablePlugins(PlayScala)

    lazy val myClientTests = project.in(file("my-client-tests")).
      enablePlugins(PlayScala).
      configs(IntegrationTest).
      settings(publish := {}).
      settings(Defaults.itSettings: _*).
      aggregate(myClient).
      settings(aggregate in test := false).
      dependsOn(myClient)

    commands += MyTestUtils.acceptanceCommand

Here sub-projects gain the names that can be used in sbt and `acceptanceCommand` is configured. Now tests from `my-client-tests` can be launched with current version of `my-server`:

    sbt publishLocal
    sbt acceptance

or with custom version of `my-server`:

    sbt acceptance -DserverVersion=1.2.3

In order to check that latest changes are compatible with old clients you can publish locally latest version of server,  checkout older version of `my-project` by tag and run `sbt acceptance` with freshly published latest version.

