---
layout: post
title: Large Scala Maps Fail Serialization
published: true
tags:
    - Scala
---

I spent some time dealing with a rather unusual error.  Took me a little while to figure it out, but it turns out
that large Maps in Scala are not serializable.  The exception does not occur on serialization, though; it happens
when you try to deserialize the map later.

    java.lang.ArrayIndexOutOfBoundsException: -7119
    at scala.collection.mutable.HashTable$class.addEntry(HashTable.scala:119)
    at scala.collection.mutable.HashMap.addEntry(HashMap.scala:43)
    at scala.collection.mutable.HashTable$class.init(HashTable.scala:81)
    at scala.collection.mutable.HashMap.init(HashMap.scala:43)
    at scala.collection.mutable.HashMap.readObject(HashMap.scala:130)
    at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
    at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:39)
    at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:25)
    at java.lang.reflect.Method.invoke(Method.java:597)
    at java.io.ObjectStreamClass.invokeReadObject(ObjectStreamClass.java:969)
    ...


The number in the exception changes depending on the exact data, but it always looks roughly similar.  I made
some simple tests, and with a basic `Map[String,Int]` with short strings, the exceptions occur around 2.2 million
elements.  Everything works fine with Java maps, so I was able to work around the problem by stuffing everything
into a java.util.HashMap instead.

Here's a test case demonstrating the problem:

    import collection.mutable
    import java.io.{ObjectInputStream, ByteArrayInputStream, ByteArrayOutputStream, ObjectOutputStream}
    import java.util
    import org.scalatest.FunSuite
    import org.scalatest.matchers.ShouldMatchers

    class RandomTests extends FunSuite with ShouldMatchers {

      val m = new mutable.HashMap[String, Int]()
      val l = 2.5e6.toInt
      (0 to l).foreach {
        idx =>
          m(idx.toString) = idx
      }

      test("mutable HashMap") {
        testSerialization(m)
      }

      test("immutable HashMap") {
        testSerialization(collection.immutable.HashMap(m.toSeq: _*))
      }

      test("java map") {
        val jmap = new util.HashMap[String, Int]()
        m.foreach{case(k,v) =>
          jmap.put(k,v)
        }
        val deser = serializeDeserialize(jmap)
        deser.size() should be(m.size)
        (0 to l).foreach {
          idx =>
            if (deser.get(idx.toString) != idx) {
              fail("check failed for " + idx)
            }
        }
      }

      def serializeDeserialize[A](a: A) = {
        val bytes = new ByteArrayOutputStream()
        val out = new ObjectOutputStream(bytes)
        out.writeObject(a)
        out.close()

        val buf = bytes.toByteArray
        val in = new ObjectInputStream(new ByteArrayInputStream(buf))
        in.readObject().asInstanceOf[A]
      }

      def testSerialization(m: collection.Map[String,Int]) {
        val deser = serializeDeserialize(m)
        deser.size should be(m.size)
        (0 to l).foreach {
          idx =>
            if (deser.get(idx.toString) != idx) {
              fail("check failed for " + idx)
            }
        }
      }

    }
     
The "java map" test passes, and the others fail.

I observed the problem on Scala 2.9.1
