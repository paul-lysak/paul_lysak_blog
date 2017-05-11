---
title: Scala traits internals or what needs to be recompiled
date: '2015-04-18T16:07:00.001+03:00'
author: Paul Lysak
tags:
- Scala
modified_time: '2015-04-18T16:08:36.508+03:00'
blogger_id: tag:blogger.com,1999:blog-5849718801312198988.post-7035470888483374301
blogger_orig_url: http://paullysak.blogspot.com/2015/04/scala-traits-internals-or-what-needs-to.html
years: ['2015']
---
I was wondering if classes inherited from traits need to be recompiled if trait code changes, so I've investigated a bit traits internals - how are they represented after compilation. I'd like to share some observations.

Suppose we have file SuperTrait1.scala:

	trait SuperTrait1 {
	  def doOp1(): Unit = {
	    println("do op1 V1")
	  }
	}

SuperTrait2.scala:

	trait SuperTrait2 {
	  def doOp2(): Unit = {
	    println("do op2 V1")
	  }
	}

and SubClass.scala:

	class SubClass extends SuperTrait1 with SuperTrait2 {
	  def doOps(): Unit = {
	    doOp1()
	    doOp2()
	  }
	}

After compilation we'll get 5 class files: `SubClass.class`, `SuperTrait1.class`, `SuperTrait1$class.class`,  `SuperTrait2.class`, `SuperTrait2$class.class`. Let's take a look inside of `SuperTrait1.class` and `SuperTrait1$class.class`:

	$ javap -p SuperTrait1
	Compiled from "SuperTrait1.scala"
	public interface SuperTrait1 {
	  public abstract void doOp1();
	}
	$ javap -p SuperTrait1.class
	Compiled from "SuperTrait.scala"
	public abstract class SuperTrait1$class {
	  public static void doOp1(SuperTrait1);
	  public static void $init$(SuperTrait1);
	}

So `SuperTrait1` is an interface and `SuperTrait1$class` contains body of trait code, in form of static methods. Now to `SubClass.class`: 

	$ javap -p SubClass
	Compiled from "SubClass.scala"
	public class SubClass implements SuperTrait1,SuperTrait2 {
	  public void doOp2();
	  public void doOp1();
	  public void doOps();
	  public SubClass();
	}

So `SubClass` implements (in strict meaning) interfaces of traits. But how it implements - by copying or by referencing? Let's find it out:

	$ javap -c SubClass
	...
	  public void doOp1();
    Code:
       0: aload_0
       1: invokestatic  #27                 // Method SuperTrait1$class.doOp1:(LSuperTrait1;)V
       4: return

	...

It's clear from this decompilation that subclass doesn't copy methods body, it just references static methods with actual impementation. So we may rest assured that changing trait methods body doesn't require subclasses re-compilation. On the other hand, if methods signature is changed or new methods added to traits then there's a reason for subclass re-compilation, as it doesn't follow the contract of the interface any more.

