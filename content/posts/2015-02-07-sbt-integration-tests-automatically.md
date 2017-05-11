---
title: 'SBT integration tests: automatically launch application'
date: '2015-02-07T14:16:00.001+02:00'
author: Paul Lysak
tags:
- integration test
- Scala
- sbt
modified_time: '2015-02-07T14:19:12.116+02:00'
blogger_id: tag:blogger.com,1999:blog-5849718801312198988.post-8277357359169589860
blogger_orig_url: http://paullysak.blogspot.com/2015/02/sbt-integration-tests-automatically.html
years: ['2015']
---
I'd like to share my experience in automatic launch of tested web application in SBT (tested with version 0.13.6) before running integration tests and shutting it down after tests. That wasn't very straight-forward and involved custom tasks creation. I'd be happy to hear about easier ways if you know some.

SBT documentation about [testing](http://www.scala-sbt.org/0.13/docs/Testing.html) describes how to enable integration tests and run custom code before them via `testOptions in IntegrationTest += Tests.Setup(...)`, but there's a class visibility issue: this custom code resides in project definition code (project of project), so it has no direct access to project main classes - it is responsible for building main classes, so it has to be fully compiled before them. This leaves 2 options:

1. Move integration tests to separate project, where build definition depends on the project where main classes are defined.
2. Use dynamic class resolution - class which is to be launched should be referenced by string containing its name, and launched via SBT API: `sbt.Fork.java.fork(...)`

I've choosen the 2nd option as it would keep the project structure small enough. However, this leaves an open question: how would custom pre-integration test code know the correct classpath? I've solved it via shared object (let's name it "remote control") which gets initialized in main code build, and later used to start/stop application in projects build. Here full source code of `my_project/project/Build.scala`:

    import java.io.IOException
	import java.net.URL
	import sbt._
	import Keys._
	import scala.util.{Failure, Success, Try}
	
	//rather generic project build definition - enabling integration tests
	object MyBuildBuild extends Build {
	  lazy val root = Project(id = "my-project-id",
	    base = file(".")).
	    configs(IntegrationTest).
	    settings(Defaults.itSettings : _*).
	      settings(testOptions in IntegrationTest += Tests.Setup({_ => AppRunnerRemoteControl.start()})).
	      settings(testOptions in IntegrationTest += Tests.Cleanup({_ => AppRunnerRemoteControl.stop()})).
	      settings(parallelExecution in IntegrationTest := false)
	}
	
	//the core part of solution - shared object
	object AppRunnerRemoteControl {
	  //receive class path from main build definition
	  def setClassPath(cp: Seq[File]): Unit = {
	    this.cp = cp
	  }
	  //in order to have remote control logs in same style as the build logs
	  def setLog(log: Logger): Unit = {
	    this.log = Option(log)
	  }
	
	  def start(): Unit = {
	    log.foreach(_.info("starting application ..."))
	    val options = ForkOptions(outputStrategy = Some(StdoutOutput))
	    //build classpath string
	    val cpStr = cp.map(_.getAbsolutePath).mkString(":")
	    val arguments: Seq[String] = List("-classpath", cpStr, "-Dmy.custom.property=myCustomValue")
	    //Here goes the name of the class which would be launched
	    val mainClass: String = "my.pkg.AppRunner"
	    //Launch it. Pay attention that class name comes last in the list of arguments
	    proc = Option(Fork.java.fork(options, arguments :+ mainClass))
	
		//make sure application really started or failed before proceed to the tests
	    waitForStart().recover({case e =>
	      stop()
	      throw e
	    }).get
	  }
	
	  def stop(): Unit = {
	    log.foreach(_.info(s"stopping application $proc ..."))
	    //kill application
	    proc.foreach(_.destroy())
	    proc = None
	  }
	
	  private def waitForStart(): Try[_] = {
	    val maxAttempts = 10
	    val u = new URL("http://localhost:8080")
	    val c = u.openConnection()
	    val result = (1 to maxAttempts).toStream map {i =>
	      log.foreach(_.info(s"connection attempt $i of $maxAttempts"))
	      Try {c.connect()}} find {
	      case Success(_) => true
	      case Failure(e: IOException) => Thread.sleep(1000); false
	      case Failure(_) => false
	    }
	    if(result.isEmpty)
	      Failure(new RuntimeException(s"Failed to connect to application after $maxAttempts attempts"))
	    else
	      Success(None)
	  }
	
	  var log: Option[Logger] = None
	  var cp: Seq[File] = Nil
	  var proc: Option[Process] = None
	}

In order to use these capabilities main build has to be amended as well. Here is excerpt from `my_project/build.sbt`:

	lazy val integrate = taskKey[Unit]("Starts REST API server and runs integration tests")
	
	lazy val preIntegrationTests = taskKey[Unit]("Starts REST API server and runs integration tests")
	
	preIntegrationTests := {
	  val cp: Seq[File] = (fullClasspath in IntegrationTest).value.files
	  AppRunnerRemoteControl.setClassPath(cp)
	  AppRunnerRemoteControl.setLog(streams.value.log)
	}
	
	integrate := {
	  preIntegrationTests.value
	  (test in IntegrationTest).value
	}

Now you may run this command to start the application, run integration tests, and stop the application:

    sbt integrate

Initially I was planning to have just one custom task - `integrate`. But it turned out that macroses used during defining tasks make sure that all dependencies of the tasks are invoked before running the tasks - not at the moment when they're mentioned in task code. So the following code:
	
	integrate := {
		val cp: Seq[File] = (fullClasspath in IntegrationTest).value.files
		AppRunnerRemoteControl.setClassPath(cp)
		AppRunnerRemoteControl.setLog(streams.value.log)
	    (test in IntegrationTest).value
	}

would first run integration tests code (`(test in IntegrationTest).value`), as `integrate` depends on that task. And only then run code of `integrate` itself which should run the application for testing.


