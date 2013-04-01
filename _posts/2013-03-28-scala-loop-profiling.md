---
layout: post
title: Profiling Scala Loops
published: true
tags:
    - Scala
---

I've started putting more effort into implementing machine learning algorithms in Scala, and right away
I started wondering about the performance of various ways of looping.  I explored this a bit before
I switched to Scala from Java, and I remember deciding that I could get comparable performance as long
as I was careful to use primitive arrays.

But now that I've got a bit more experience using Scala, looping over arrays with a while loop looks
horribly ugly.  Not to mention, its extremely bug-prone -- I often forget to increment the index. (Why
doesn't Scala have a proper for loop?)

So I wanted to compare the direct while loop to two alternatives:

1. *Tail Recursion*.  Scala claims this gets compiled down to an iterative loop, so lets see if its true
2. *Foreach over a Range*.  This is probably the cleanest approach, but I thought the inline lambda functions
  would get compiled to calling a method on a class, which would have a lot of overhead.


All of these experiments are with Scala 2.9.1-1, on a MacbookPro 2.4 GHz Intel Core i7, 8 GB 1333 MHz DDR3.

## My Experiments

The first thing I wanted to profile was a very simple loop over a giant array.  I made a couple of modifications along
the way, which I'll discuss below, but here's code I ended up with at the end.  (I added the `array.foreach` towards the
end of my experiments, so not all my results include it.)

	package org.sblaj.ml

	import annotation.tailrec

	object IterationTiming {
	 def timeIterations(n: Int) {
	   val arr = new Array[Int](n)
	   var idx = 0
	   val itrStart = System.currentTimeMillis()
	   while (idx < n) {
	     arr(idx) = idx + 1
	     idx += 1
	   }
	   val itrEnd = System.currentTimeMillis()
	   println("itr took " + (itrEnd - itrStart) + "ms")

	   @tailrec
	   def tailRecItr(arr: Array[Int], idx: Int) {
	     if (idx >= n)
	       return  //tailrec annotation not happy if recursive call is inside a condition, so have to use a return
	     arr(idx) = idx + 2
	     tailRecItr(arr, idx + 1)
	   }
	   val tailRecStart = System.currentTimeMillis()
	   tailRecItr(arr, 0)
	   val tailRecEnd = System.currentTimeMillis()
	   println("tail rec took " + (tailRecEnd - tailRecStart) + "ms")

	   val forStart = System.currentTimeMillis()
	   (0 until n).foreach{idx => arr(idx) = idx + 3}
	   val forEnd = System.currentTimeMillis()
	   println("foreach took " + (forEnd - forStart) + "ms")


	   idx = 0
	   val itrStart2 = System.currentTimeMillis()
	   while (idx < n) {
	     arr(idx) = idx + 1
	     idx += 1
	   }
	   val itrEnd2 = System.currentTimeMillis()
	   println("itr took " + (itrEnd2 - itrStart2) + "ms")

	   //Try doing a foreach over anything other than a range.  Even just using an array w/ all the values
	   // in it is *much* slower
	   val range = (0 until n)
	   val idxArray = range.toArray
	   val arrayForStart = System.currentTimeMillis()
	   idxArray.foreach{idx => arr(idx) = idx - 1}
	   val arrayForEnd = System.currentTimeMillis()
	   println("array foreach took " + (arrayForEnd - arrayForStart) + "ms")
	 }

	  def main(args: Array[String]) {
	    timeIterations(args(0).toInt)
	  }
	}


First, I tried just pasting the relevant code into the scala REPL, first setting n = 1e6.   Here's what I saw printed out:

    itr took 36ms
    tail rec took 7ms
    foreach took 573ms
    itr took 46ms

As I has suspected, the foreach loop took much longer.  But I couldn't understand why the tail-recursive version would be
*faster*.  I tried doing a similar experiment from within the sbt console, instead of the scala REPL, and got very similar
results.  Then I suspected the REPL might be doing something funny, so I put the code into a file and compiled it with sbt.

When run this way, the times were **totally different**.  The experiments of pasting code in the REPL were totally misleading.
After compiling the code, calling it from the REPL or a standalone java were pretty similar.  Now the times were massively
faster, but the relative comparison was different:

    scala> org.sblaj.ml.Blah.blah(1e6.toInt)
    itr took 4ms
    tail rec took 3ms
    foreach took 11ms
    itr took 0ms

    scala> org.sblaj.ml.Blah.blah(1e7.toInt)
    itr took 34ms
    tail rec took 6ms
    foreach took 11ms
    itr took 6ms

    scala> org.sblaj.ml.Blah.blah(1e8.toInt)
    itr took 79ms
    tail rec took 73ms
    foreach took 100ms
    itr took 71ms

One standalone run with n=5e8, the warmed
up iterative version was somewhat faster:

    bash-3.2$ scala -J-Xmx4G -cp ml/target/scala-2.9.1/classes/ org.sblaj.ml.Blah 500000000
    itr took 3049ms
    tail rec took 1171ms
    foreach took 515ms
    itr took 399ms

The iterative version was faster, but not by very much.  I was puzzled.

## JIT,javap, and scalac

I thought that maybe the only reason the foreach was able to keep is because the hotspot compiler was able to eliminate
its overhead and inline that code very quickly.  Indeed, turning off the hotspot compiler `-Xint` did change the runtime, though not quite
as expected:

    bash-3.2$ scala -J-Xint -J-Xmx1G -cp ml/target/scala-2.9.1/classes/ org.sblaj.ml.Blah 100000000
    itr took 1380ms
    tail rec took 1499ms
    foreach took 2407ms
    itr took 1390ms


I tried turning on extra info on what the hotspot compiler was doing with `-XX:+PrintCompilation`, and I was shocked to see
it wasn't doing anything special w/ the foreach!  After looking with `javap`, I found out that the lambda if _already compiled away_.
The foreach wasn't another function call!  This was a real shock.  But, i also had my doubts, because according to javap, my
tail-recursive function was still creating a function call.  If that was really the case, there is no way it would have comparable
performance. 

    bash-3.2$ javap -classpath ml/target/scala-2.9.1/classes -c org.sblaj.ml.Blah$
    ...
       91:  invokespecial   #55; //Method tailRecItr$1:([III)V
    ...

I'm no expert on javap, but that sure looks like a method call.  And the method its calling doesn't seem to exist.

However, after some digging, I discovered that scalac already [optimizes foreach over Ranges](https://github.com/scala/scala/commit/4cfc633fc6).
So, all of that worrying for nothing, foreach was a bit slower, but not massively so.  Maybe good enough in a lot of cases.  Some more 
reading on the topic:

* http://ochafik.com/blog/?p=806
* http://dynamicsofprogramming.blogspot.co.uk/2013/01/loop-performance-and-local-variables-in.html


Just to be really sure I wasn't crazy, I tried another foreach, not on a range (the last `array.foreach` in my code).  This confirmed my expectations
-- it was much slower.

	bash-3.2$ scala -J-Xmx1G -cp ml/target/scala-2.9.1/classes/ org.sblaj.ml.IterationTiming 100000000
	itr took 77ms
	tail rec took 77ms
	foreach took 106ms
	itr took 57ms
	array foreach took 430ms

And without the JIT, it was devastatingly slow:

	bash-3.2$ scala -J-Xint -cp ml/target/scala-2.9.1/classes/ org.sblaj.ml.IterationTiming 1000000
	itr took 14ms
	tail rec took 15ms
	foreach took 26ms
	itr took 14ms
	array foreach took 750ms

# Summary

* Never use the REPL for timing experiments!  Its extremely misleading, not representative of the way you'll really use your code.  Its ok
to invoke code from within the REPL when timing, but be sure the code is defined in a file that is compiled normally.
* `Range.foreach` is optimized!! Yay!! You can still get a bit faster w/ while loops, but its not that bad.  (Don't be fooled into thinking
this means *all* foreachs are fast -- they're not.)
* The bytecode of tail-recursive calls is still mysterious ... maybe more on that in the future.
