---
layout: post
title: Where Scala Got It Wrong
published: true
tags:
    - Scala
---

I've been a Scala developer for just over half a year now.  Scala is amazing; coming from a background in
Java, it solves so many of the issues that aggravated me for years.  But, because its still compiled
to the JVM, I didn't need to start completely from scratch; I can still draw on all the existing Java
libraries, plus all the tools I'm used to using for debugging and diagnosing my Java programs.  I'd have
a hard time going back to programming in Java after this.

Despite my love of Scala, though, there are a few things that drive me bonkers.  Maybe some Scala guru
will see this post and take into consideration for future versions of the language -- but almost certainly not.
If I'm lucky, than this post might be read by someone else that is new to Scala, that is going through similar
frustrations -- at least this way they'll know they are not alone.  But, really, this post is just my chance
to vent.

1. Collections in Predef.  Functional languages are really big on immutable data structures, and Scala is no
exception.  I had often wanted a way to force immutability in Java.  Scala made a big improvement on this, by
creating immutable and mutable versions of most collections, plus a common interface covering both.  (I'm not
a huge fan of the fact that the names are only differentiated by packages, but I can live with that.)

    But, they made a horrible mistake when they included the *immutable* versions, instead of the *common interfaces*
in Predef.  I can only imagine that they did this because they wanted to bias everyone to use immutable collections
by default, as all "good" functional programmers should.  This means that when you write a method `def doXYZ(data:Map[String,Int]) : Boolean`,
you have just defined a method that can *only* accept immutable maps.  That might even by work fine for you
when you write the method.  But later on, another developer will come along and try to use that method with
a mutable Map, and it won't compile.

    From now on, I always `import collection._`.  That way, I get the generic interfaces by default in my API, and I
explicitly request the mutable or immutable version of the collection if I want to, eg. `val m = mutable.Map[String,Int]()`

2. DSL run amok.  One of my biggest complaints about Java was the lack of operator overloading.  Just look at the BigNumber api,
you quickly see what a pain it is.  Scala fixes this problem -- code is so much cleaner by adding `apply`, `+=`, `++`, etc.  Such
a huge improvement.  Unfortunately, Scala developers have gotten a little carried away.  Libraries are full of so much crazy,
*undocumented* operator overloading, it ends up making code inscrutable to anyone that isn't an export in the library.  I guess
I'm not actually complaining about Scala itself here -- it's great that it lets you do this -- I'm complaining about how much
people abuse the ability to create custom DSL.  Most often, my goal is invest as little time as possible in a tool to get what
I need out of it -- as a good Computer Scientist, I try to find the highest layer of abstraction that is still sufficient.  Lots
of DSL just makes that harder.

3. Slow compile times.  Yes, I know, the Scala compiler is much more complicated than the Java compiler, that it has to work so much
harder, etc. etc.  It still annoys me.  Even with large Java projects, I felt like the compiler (especially continuous compilation
within Eclipse) was so fast that the compiler was never a burden.  Compiling Scala code regularly grinds my laptop to a halt.
The sad truth is, this leads to all sorts of bad development practices on my part, like not bothering to run unit tests because
I don't want to wait for the compiler.  OK, maybe its unfair to say "Scala got it wrong" on this one, I just switch I could speed up
compilation, eg. by turning off some of the features.

4. SBT.  Simple Build Tool.  I hope that choice of name was ironic.  I used to use Ant as a Java developer; I won't claim it was simple,
or amazing, but at least it was well documented.  But sbt project definitions are just Scala code!  Sounds easy enough -- as a Scala
developer, I won't have any trouble understanding, right?  Nope, I'm just stuck in DSL hell.  Yes, I know it is scala code, but even just
getting past the crazy syntax, let alone tracking down the method definitions, is more than I want to deal with for setting up a simple build.

OK, I'm done with my rant.  Now I should write some more constructive posts about why I like scala, and how I've learned to use it.  Am I alone
in thinking these are problems with Scala?  Does anybody have any solutions to these problems?  I'd love to hear your feedback.
