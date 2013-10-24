---
layout: post
title: Learning Scala Macros
published: true
tags:
    - Scala
    - Macros
    - Tech
---

## Learning to Learn

Scala Macros are powerful, but very daunting.  I only had time to quickly poke at them in the past, and I always felt overwhelmed.  I couldn't figure out how to modify the existing examples to do what I wanted, even when I thought I wanted to implement something very basic.  I finally had a chance to make some sense of them, so I'm sharing some tips I learned along the way. 

I had a specific goal in mind -- I wanted my macro to supply definitions for abstract methods.  More specifically, the macro should supply definitions for
*getters* of 'Int's and 'Float's, to read out of a 'ByteBuffer'.  Eg., given this:

<script src="https://gist.github.com/squito/7094987.js?file=trait.scala"></script>

My macro should generate the equivalent of

<script src="https://gist.github.com/squito/7094987.js?file=goalClass.scala"></script>

The idea seemed pretty simple, but I knew there would be a lot to learn about macros before I could make it happen.

(This idea is related to another project of mine, [Oleander](https://github.com/squito/oleander), which will read data directly from ByteBuffers for a variety of reasons.  However, that's not nearly ready for real use yet.  For now, this is just a way for me to learn.)

**WARNING** This is *not* a tutorial.  I'm not an expert by any means.  But I did get macros to do what I wanted in the end, and I even put the working examples into a [repo on github](https://github.com/squito/learn_macros) with the full sbt build configuration.  I do think you will learn a lot (and save a lot of time) if you read my advice on Learning ASTs and start from the example repo.

## First Steps

After doing a bit of search for a good, basic tutorial, I decided to follow this [great blog post](http://www.warski.org/blog/2012/12/starting-with-scala-macros-a-short-tutorial/) with an intro to macros.:
It was very straightforward, with a complete project set up, and even had a useful example.  I learned

* basic project setup
* simple macro defs
* a few basics on working with Abstract Syntax Trees (ASTs)

At this point, I thought this was going to be a piece of cake.  I figured a few simple modifications to those examples, and I'd have my macro.
But as it turned out, I still had a lot to learn.

## Hope and Despair

After doing a bit more reading, I realized that the latest and greatest version of macros came with [Macro Paradise](http://docs.scala-lang.org/overviews/macros/paradise.html).  From this point on, I was using scala 2.10.2, plus the macro-paradise 2.0.0-SNAPSHOT-jar.  It seemed like things were going to be *even easier* because I could use [Quasiquotes](http://docs.scala-lang.org/overviews/macros/quasiquotes.html).  Sure, I didn't understand them yet, but they promised to make all my problems magically disappear.


I won't go into all the gory details here, but lets just say I wasted a ton of time with random experiments, getting lots of weird, inexplicable errors.  I thought I could avoid learning ASTs with Quasiquotes, but I kept getting error messages that were just a  lot of AST gibberish.  Even without quasiquotes I was often really lost.  (Just to get a sense of the feeling of hopelessness, take a look at [this error msg](https://gist.github.com/squito/6597917).)  I even managed to slay the compiler a few times, that was fun.  

## Getting Basic ClassDefs workings

I was getting really frustrated, but I felt I had put in too much effort to give up at this point.  I decided to be a bit more methodical.  So I stepped back, did a bit of reading, and found some better tools to works with ASTs, and started again.

### Learning ASTs

* The [academic paper on quasiquotes](http://infoscience.epfl.ch/record/185242/files/QuasiquotesForScala.pdf) was quite useful; it actually has some nice simple examples, you only need to read the first 4 pages.  It helped me learn about both Quasiquotes, and ASTs in general
* Probably the most useful thing I learned was to **not** rely on `showRaw` as the only way to learn ASTs.  `showRaw` is great because it's so easy to use, but sometimes the tree it shows you is not the tree you want.  Sometimes, if you copy those trees verbatim, you just get some obscure compiler error.
* The **foolproof** way (in my experience) to get the correct AST is to ask `scalac` to do it for you, as [Eugene Burmako explains in this SO answer](http://stackoverflow.com/questions/14790115/where-can-i-learn-about-constructing-asts-for-scala-macros/14795999#14795999).  So I'd put some example code in a .scala file, and then run 
`scalac -Xplugin macro-paradise_2.10.2-2.0.0-SNAPSHOT.jar -deprecation -Xprint:parser -Ystop-after:parser -Yshow-trees-compact *.scala`  

* Though I no longer relied exclusively on `showRaw` to learn ASTs, I still tried it out first, especially after I learned how to use it quickly in the repl.  (If something went wrong, I'd fall back on `scalac`.)  To start a repl session with the compiler plugin & the appropriate imports, I'd run 
`scala -Xplugin macro-paradise_2.10.2-2.0.0-SNAPSHOT.jar`

then paste in

<script src="https://gist.github.com/squito/7094987.js?file=replImports.scala"></script>


For example, here's the way I'd discover some basic trees:

<script src="https://gist.github.com/squito/7094987.js?file=showRaw.scala"></script>

(Note that in the last example, showRaw actually gives an incorrect tree -- we need to use `scalac` to get the right one.)

### Annotations

Now I was ready to start making my macro.  First of all, I learned that in order to [add public methods to a class](https://groups.google.com/d/msg/scala-user/97ARwwoaq2U/kIGWeiqSGzcJ), I'd need to use [Macro Annotations](http://docs.scala-lang.org/overviews/macros/annotations.html).  They might not even make it into 2.11, but they are available through the macro-paradise compiler plugin even with 2.10, so I decided to still go for it.

To start slowly, I wanted to see if my macro could add definitions to a class, where I just hardcoded the missing methods.  Specifically, I wanted this to work:

    
<script src="https://gist.github.com/squito/7094987.js?file=annotationsGoal.scala"></script>

Without the macro, that code gives a compiler error, because `Foo` does not implement `x` or `y`.  I made `@FillInTraitDefs` provide the missing definitions with a macro.  First, I found the AST for the defs I wanted to add (I didn't particularly care what `x` or `y` did).

<script src="https://gist.github.com/squito/7094987.js?file=reify.scala"></script>

Similarly, I discovered the structure for classes, and figured out where the defs go:

    ClassDef(modifiers, name, _, Template(parents, _, defs))

Though I didn't learn what all the parts were, I knew enough for what I needed.  Now I could put the pieces together:

<script src="https://gist.github.com/squito/7094987.js?file=fullMacro.scala"></script>

The next step was to have my annotation add the trait as a parent in a macro.  Sounds simple, but I had a really hard time figuring out the syntax for declaring a parent class -- because I was relying on `showRaw`.  After I switched to using `scalac` to show me the AST, I had no trouble at all.  The tree for adding `com.imranrashid.oleander.macros.SimpleTrait` as a parent was:

<script src="https://gist.github.com/squito/7094987.js?file=addedTrait.scala"></script>

Everything seemed to be working pretty well, so I put together [a few unit tests](https://github.com/squito/learn_macros/blob/master/macrotests/src/test/scala/com/imranrashid/oleander/macros/SimpleTraitFillInTest.scala#L8) to confirm it worked as I expected.  The tests confirmed that I could add defs to my classes, make them extend a trait, and not lose any of their existing definitions.

### Quasiquotes

I was feeling pretty good now that I had all this working.  But, those ASTs were a bit of a pain to write, and they were pretty hard to follow -- two problems that quasiquotes were meant to solve.  I decided to give them another shot.

First, to get quasiquotes working in the repl, I added one more import for implicit conversions:  

<script src="https://gist.github.com/squito/7094987.js?file=quasiReplImports.scala"></script>

Now I could try out generating trees in the repl with quasiquotes:

<script src="https://gist.github.com/squito/7094987.js?file=quasiDefDef.scala"></script>

Not bad!  That was pretty easy.  In fact, you can even use quasiquotes to *deconstruct* trees.  It takes a little while to get the syntax right, but the best way to learn is to play around in the repl.  For example, to find the syntax for multiple traits, first I created an example tree:

<script src="https://gist.github.com/squito/7094987.js?file=quasiClassDef.scala"></script>

and after some trial and I error, I found I could pull it apart with:

<script src="https://gist.github.com/squito/7094987.js?file=quasiClassDefUnapply.scala"></script>

This was fantastic!  Remember the headache of figuring out how to declare a parent class when we were building the trees by hand?  Now I could just let quasiquotes do it for me!

<script src="https://gist.github.com/squito/7094987.js?file=quasiParentClass.scala"></script>

I'm glancing over a lot of details here, but hopefully this will help you make some sense of the [very terse documentation](http://docs.scala-lang.org/overviews/macros/quasiquotes.html).  There are a few gotchas; in particular, with Lists of trees, you must

1. cast everything to `List[Tree]`
2. after merging lists of trees together, call `.toList`

both of these are hinted at in the docs on quasiquotes and the [linked gist](https://gist.github.com/anonymous/7ab617d054f28d68901b), but aren't fully explained .  I hope these two rules, plus [my example code](https://github.com/squito/learn_macros/blob/master/macros/src/main/scala/com/imranrashid/oleander/macros/FillTraitDefs.scala#L78) make it more clear.

### Generating ASTs with reify

Even if you don't use quasiquotes, you can potentially generate some parts of the AST using reify.  But again, it requires you to know some internals of how ASTs get wrapped up by reify before you can use them.  For example, instead of specifying our trees for the new `DefDef`s manually, we could have done this:

<script src="https://gist.github.com/squito/7094987.js?file=reifyDefDefs.scala"></script>

The extra `.tree` and pattern match are necesary because `reify` wraps the defs into an `Expr(Block(...))`.  Simple once you know about it, but really confusing before you know what to look for.  By the time I figured this out, I already learned quasiquotes, so I just stuck with them.  Also, quasiquotes make it easier to pattern match against trees, which you can't do with just `reify`.  Still, it's up to you which way you would prefer to generate trees.

## Next Steps

Now I had macros to fill in method definitions and add in a trait as a parent class.  The only problem was, those methods & trait were constants!  I still need to figure out what the added trait & method definitions should be.  For that, I'd need to dive into [Scala Reflection](http://docs.scala-lang.org/overviews/reflection/overview.html), another new features in Scala 2.10.  This post is already pretty long, though, and I felt just learning the basics of macros is a good start, so I'll save that for another update.  Stay tuned.

I hope you've learned something from my experience -- I sure wish I knew some of this at the very beginning.  I've left out a lot of details, but I've tried to focus on the major breakthroughs I made, the things I didn't find elsewhere (or at least, I didn't find right away).  Leave some comments if you found this useful, if you have other tips on learning macros (or if you have any corrections)!
