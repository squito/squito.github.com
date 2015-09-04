---
layout: post
title: Spark Accumulators, What Are They Good For?
published: true
tags:
    - Spark
    - Tech
---

**PRE-PRINT VERSION** _posting just to get some people to review, please ignore_

Spark Accumulators: What are they good for? Absolutely Nothing.

I don't make that statement lightly.  Accumulators were one of the reasons I was initially attracted to Apache Spark -- they appear
to be a fantastic generalization of counters in MapReduce.  Indeed, I've made a number of contributions to Spark, and
accumulators are probably the only place I've strongly [influenced the](https://github.com/apache/spark/commit/ae07f3864c2fe4837bfacb8faf6ea8432f510cf7)
 [public](https://github.com/apache/spark/commit/82a3327862d678500ecebd004c1b5b04862aaad8) [api](https://github.com/apache/spark/commit/6d7f907e73e9702c0dbd0e41e4a52022c0b81d3d).  But I'm not proud of that, its really a source of embarassment.  I made those suggestions before I properly understood
how accumulators fit into Spark's computational model.  Now I see they don't even work well as a replacement for MapReduce counters.

Potential Uses For Accumulators
=======

Let's start by looking at the problems you might *think* that accumulators will solve.

1.  Accurately measure a property of the data for debugging.  For example, find out how many records had a valid
user ID, or how many purchases occurred within some time window.  This is a classic use of counters in MapReduce.  The properties
that are checked might be ad-hoc during data exploration, or they could be fixed checks in a regularly run ETL pipeline.

2.  A light-weight debugging tool, to give interactive per-task information.   For example, we might be interested in how many
records we have per-task.  We may be interested in metrics that aren't available to the framework -- perhaps we know that in our
application, records that match some special filter X are far more expensive to process.  Thus the user might want to add a special
counter to track these records per-task.

3.  Accurately measure resources usage and profile a spark application, from the perspective of *cluster utilization*.  For example,
we might want to know how much data is read from HDFS, how many bytes are shuffled, how much time is spent in user code vs. in
spark internals, count how many times an RDD is recomputed, etc.

4.  Compute any arbitrary property of the data that is commutative and associative.  Effectively this would be adding a
[`reduce` operation](http://www.mpi-forum.org/docs/mpi-2.2/mpi22-report/node103.htm#Node103)
that could be computed as a *side-effect* of other processing.
For example, while parsing your input data, you might want to also count the total number of records, track a small sample of records with
parsing errors for debugging later on, label records into one of 100K buckets and track the total count per bucket, or produce a bloom
filter of user IDs that match some special criteria.  Obviously, this is completely impossible with counters.

At first blush, it might seem like Spark's Accumulators are perfect for all these situations.  The first three uses might seem nearly
identical, especially when you come from MapReduce, and fairly straightforward translations from counters.  And #4 makes it seems like Spark
greatly builds on the computational model of MapReduce.  But we'll see accumulators fail on all counts.  The problem is that each of these
uses actually has some fundamental differences, and by attempting to roll them all into one, Spark is stuck solving them all poorly.  Let's
start by looking at #4, and work backwards from there.

Failure As Generalized Reduce
=======

Unlike counters in MapReduce, Spark's accumulators generalize in two major ways:

1. The type of data is not limited to a `Long`
2. The user can define an arbitrary commutative and associative operation to merge values (instead of being limited to `+` on natural numbers).

This opens the door to a lot of cool possibilities.  You can consider many more types that define their own version of `+`.  For example, `+`
on two vectors might naturally be defined as element-wise addition.  For example, say you categorize users based on demographics, spending behavior,
activity profile, etc. -- you could easily end up with 10K different buckets.  Rather than having to come up with 10K counters, you could
create one accumulator:

<script src="https://gist.github.com/squito/6ba75eb102103cea266b.js?file=VectorAccumulable.scala"></script>

We extend this to many more types that define a `+` -- for example, see all the possibilities from
[Twitter's Algebird Library](https://github.com/twitter/algebird).  You could use an accumulator to track a set of interesting users, or even a BloomFilter for
(approximately) storing a really large set of users, or using HyperLogLog to (approximately) count distinct users.  What is really unique
about the possibility of using accumulators is that you can compute multiple types of aggregations **in one pass**.  This may seem
irrelevant if you are processing 50 GB on a large cluster, and you've got it all cached in memory -- but it makes a big difference
if you need to scan 100 TB
on disk.

Unfortunately, using Spark's accumulators this way is a bad idea, because they are extremely inefficient.  To be fair, this model of computation
has some very real limitations; fundamentally, if you have N cores on each executor, you'll need N in-memory copies of the accumulators.  So
if you have 16 cores, and you create 1 GB of accumulators, you'll need 16 GB of memory.  But even restricting ourselves to "modestly" sized
accumulators, say in the 10s of MB, still would open the doors to much more than what is possible with MapReduce counters.

However, Spark won't handle modestly sized accumulators.  The problem is that each task sends its accumulators directly to the driver.
This means that even if the accumulators are only 1 MB, if you have 10K tasks, you will send 10 GB of data back to a single node.  Tuning
the number of partitions with Spark is notoriously hard, and in general your best bet is to err on the side of using too many partitions.  10K
is a reasonable number for even 1 TB of data.

This is just an implementation detail, right?  Spark should be able to change the internals to avoid sending all results back to the
driver (and perhaps a host of other optimizations as well, eg. avoiding serialization & deserialization between tasks on the same executor).
Indeed, some of these optimizations are already planned for [`treeAggregate`](https://issues.apache.org/jira/browse/SPARK-8137).

Unfortunately, now we find that our hands are tied by the other uses of accumulators.  In particular, we show the value of each accumulator
per task, as a debugging tool (our original use case #2).  So we can't merge the values together, since we must keep distinct values
 per-task.

OK fine, so we don't get some grand generalization over MapReduce counters.  All we really want is counters anyway,
and we've still got that, right?

Strange API
============

Using accumulators as counters is very unsatisfactory, because of a clunky api and useless behavior around fault-tolerance.  We'll start by
considering the api, the simpler of the two.  Consider the most basic use case for counters, counting parse errors in our
input data:

<script src="https://gist.github.com/squito/6ba75eb102103cea266b.js?file=AccumulatorsAsCounters.scala"></script>

API design is very subjective, but several aspects of this seems pointlessly complicated to me.

1. Since we can really only use counters anyway, why bother with the complications introduced by accumulators?  There shouldn't be any need
to create the accumulator value up front.
2. Though its perfectly legal to create an accumulator without a name, eg. `sc.accumulator(0L)`, it won't show up in the UI unless you give
it a name.  This is a constant source of confusion for end users, who don't know to pass in a name and think that the accumulators aren't working.
3. In addition, just adding a name to your accumulator also has the side-effect that the UI will call `.toString` on the accumulator update from
each task.  So if you did use an accumulator on a more complex type with an expensive `.toString`, just giving the accumulator a name could
destroy performance.  We're left with the strange advice to users: if you are just using a counter, make sure you add a name to your counter;
but if its something more complicated than a counter, be sure you do *not* add a name.
4. Though we're storing the value of the accumulator per-partition for the UI, we don't have *programmatic* access to the per-partition values;
we can only (easily) access the fully merged value.
5. How do we know when our counter is "ready"?  Suppose we want to always log the value of the counter, and fail our job if
there are more than 50 parse errors.  Where would we put that logic?  Because RDD transformations are lazy, the value is still 0 at the end of
parsing transformation, regardless of how many errors there truly are.  The user has to destroy the modularity of their program, by not
looking at the value until after they execute some action.  And it gets even worse if the RDD is reused -- the behavior changes
based on how many times its reused, whether its cached, whether it fits in the cache, and whether it stays in the cache.  We could use a
`SparkListener` for this, but that
is very cumbersome for such a simple feature.

But you might say that I am a cry-baby for quibbling about such minor API issues.  Modularity is for the weak; you always have global knowledge of your spark
application, where every RDD is created, computed, cached, how much fits in memory, and you love updating your custom `SparkListener` every time
you add another counter.  Nonetheless, you *still* can't rely on accumulators to do anything useful for you, because of how strangely
they interact w/ Spark's failure handling.

Interlude on Fault-Tolerance & Stage Retries
==============

Before we get into what accumulators do when there are failures, we need to spend a moment to discuss Spark's failure handling.  Let
me warn you -- this section is complicated with lots of details of Spark internals, but its not possible to explain the way accumulators
work without touching on this.
There are really
two very different kinds of failure handling.  First, a task can fail due to some exception in user code.  For example, let's say that you
forget to put in any kind of error handling around your parsing code.  As soon as you hit one unexpected record, the task will throw an exception
and fail.  Spark will then retry the task (up to 4 times by default).  If the task fails everytime, Spark gives up and fails your job, showing
you the exception.  If by some stroke of luck, the task succeeds on the retries, then Spark happily continues.  It will only count the accumulator
update from the successful task, and the failed tasks are completely ignored.  All is well.

Things get a lot more interesting when we talk about *stage* failure.  This is how Spark handles a node going down in a cluster -- that
is, the error isn't from any fault of the user, but its from hardware failure.  Specifically, there is special handling when Spark notices a
node go down during a shuffle, while its reading shuffle output.  Because shuffle output is stored locally, if a node goes down, that shuffle
output is gone.  There is no sense in just retrying the task that reads the shuffle output, since its doomed to fail.  Instead, spark goes
back to the stage that *generated* the shuffle output, looks at which tasks need to be rerun, and executes them on one of the nodes that is
still alive.

Here is where things start (ha!) to get tricky.  After we regenerate the missing shuffle output, the stage which generated the map output has
executed some of its tasks multiple times, even
if the individual tasks were always successful.  Spark counts accumulator updates from all of them.  If multiple nodes go down, Spark may realize
this immediately, or it may take multiple rounds of stage retries to detect it.  In addition, if there is a long lineage of stages, from one shuffle
stage to another shuffle stage, Spark may need to recompute some tasks from all of those stages.  Furthermore, when Spark retries the stage,
it still leaves some tasks running in a ["zombie"](https://github.com/apache/spark/blob/afe9f03fd964d1e8604d02feee8d6970efbe6009/core/src/main/scala/org/apache/spark/scheduler/TaskSetManager.scala#L111)
 state.  Completed "zombie" tasks also count their accumulator updates.  This means the total amount of "over-counting" can greatly exceed
the percentage of nodes which fail.

Confused?  Don't worry, that puts you in good company.  Most Spark committers don't fully understand all the ins and outs of this behavior
(myself included).  There is general agreement that the scheduler code is extremely complicated and hard to understand.  And there is a major
[shortage of tests](https://issues.apache.org/jira/browse/SPARK-8987), so its hard to even find a good set of examples. [^nobody-understands]

[^nobody-understands]: I strongly suspect that the number of people that understand all the intricacies of stage retries is exactly 0.

Failure As Counters
===================

In theory, you shouldn't need to understand any of these details about failure handling and task recomputation as a user of Spark.  These are just
internal details -- you code to Spark's api; if there are failures, spark will handle it; and it all just works.  But the semantics of accumulators
make them effectively useless because of these details.  Even worse, they can easily *appear* to do the right thing, especially when you try a small
example.  But if you try to rely on them, they might be incorrect in unexpected ways.

Say you deploy a Spark app for a regular batch ETL pipeline, that runs a few times a day as you ingest data.  Maybe you process logs from customer
purchases, and you track total spend with a counter.  You may even have some alerting if spend levels are too high or too low.  You've unit-tested
this logic, and even come to rely on it for escalations.  But if one node in your cluster happens to go down, Spark may happily report the job
completes successfully, though your counter could be off an arbitrary amount.[^no-fault-tolerance]  So you get an alert at 2 AM that spend was too high, when it was
really just fine.  Or even worse, you fail to get an alert when spend is too low, and don't notice for far too long.  By the time you figure this
out, you are already in hot water.

[^no-fault-tolerance]: Though you'd be ill-advised to rely on Spark for fault-tolerance in any case, given [SPARK-5259](https://issues.apache.org/jira/browse/SPARK-5259), [SPARK-5945](https://issues.apache.org/jira/browse/SPARK-5945), [SPARK-8029](https://issues.apache.org/jira/browse/SPARK-8029), and [SPARK-8103](https://issues.apache.org/jira/browse/SPARK-8103).

Or maybe you are just doing ad-hoc data exploration, and throw in a counter for some basic data validation.  Initially the check works just fine,
correctly reporting errors as you try it out on a handful of different data sets.  In fact, it even helps you discover that one of your datasets
has a far higher percentage of errors than any other.  So you decide to spend some time investigating why this dataset is different.  Oh,
wait ... its simply
that this particular dataset was bigger, so it didn't fit in the cache.  Your code made multiple passes over the parsed data (which you expected to
be cached in memory), so your counters have over-counted.  No big deal, you just lost one week of your life chasing phantoms. [^worst-possible]

[^worst-possible]: This is the worst-possible behavior of a big-data system.  Pretend that everything is simple and easy on small examples you can run locally; but when run on large data sets, produce garbage data for reasons you can't possibly expect the average user to understand.

To be fair, this is all explained in [Spark's Programming Guide](http://spark.apache.org/docs/latest/programming-guide.html#accumulators-a-nameaccumlinka).
However, it can easily seem like these limitations are just for a small corner case, when in fact, they make accumulators a totally incomplete
replacement for MapReduce counters[^exception-in-transformation].  If
you do try to use accumulators outside of RDD actions, they are worse than useless -- they are actively misleading. [^and-speculation]

[^exception-in-transformation]: If Spark really wanted to discourage improper use of accumulators, it could always throw an exception if they were used when caching an RDD or in a ShuffleMapStage, but that would make this limitation far too obvious.
[^and-speculation]: And I haven't even mentioned anything about speculative execution yet.  Honestly, I have no idea what the behavior currently is, but I don't even want to bother trying.  There are enough problems as it is that it doesn't matter.


What Should Spark Have?
======================

We're unable to fix these problems with accumulators directly due to backwards compatibility (at least in Spark 1.x).  As strange (and useless) as
these semantics are for accumulators, that behavior can't be changed.  For example, if you are using accumulators to profile your code by tracking
time spent in various parts of your code (our original use case #3), then it may be useful to count the time spent when recomputing an RDD that
isn't cached.  This is fundamentally at odds with a metric that only depends on the input data, for use cases #1 and #4.  Furthermore, solving some
of these problems require changes to the api that just aren't compatible.  For example, the current muddling together of
simple counters with a more complex system for arbitrary computation on the data is one source of the problem.

I believe the first step is to provide a new api which aims to just provide good counters, and nothing more.  Here's an eample of what it might look like:

<script src="https://gist.github.com/squito/6ba75eb102103cea266b.js?file=BetterCounters.scala"></script>

There are some other ideas on [SPARK-603](https://issues.apache.org/jira/browse/SPARK-603) as well.  The key points are that the API should
be very simple, and the semantics around RDD recomputation & stage failure should be very clearly defined.

That would also allow us to create a new api *just* for efficient reduce-style operations as a side-effects over the data.  This would not
need to report any results per-task, so the implementation would have much more flexibility to do something efficient.  This would also
need to clearly define the semantics around RDD recomputation and stage failure, perhaps with an even more limited set of guarantees.
Maybe Spark doesn't need this now (and maybe it never will).  But in the meantime, accumulators should stop masquerading as this.
Whatever we do, its clear we should start by figuring out what *semantics* we want through all the different use cases and failure
scenarios, and then figure out what is feasible to implement (rather than just piling on series of convenient and incomprehensible hacks).

Summary
========

I know I've been a little over-the-top in my attacks on accumulators, but I want to make it painfully clear just how confusing
things get when you rely on accumulators.  The truth is, I still use them, but only because they are all I've got.  I've
even [written up some examples](https://gist.github.com/squito/2f7cc02c313e4c9e7df4) of uses of accumulators beyond
simple counters.  But I always get a queasy feeling in my stomach everytime I recommend them, since I'm certain users
don't understand the minefield they are walking into.

Spark can do better.

---
