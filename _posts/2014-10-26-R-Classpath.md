---
layout: post
title: Simple "Classpath" for Reusable R Scripts
published: true
tags:
    - R
    - Tech
---

I'm primarily a Java / Scala developer, but every so often I dabble in R, whether its to do a little
data analysis, train statistical models, or plot some graphs.  95% of my R code is throw-away
scripts, that are undocumented and aren't meant to be shared or ever looked at again.  But every
so often, I write a utility function in R that I'd like to reuse, and even share with others.  I've
found that R's "standard" methods for sharing & reusing code aren't quite enough, but I think I've
come up with a scheme that works pretty well.

One method for sharing R code is to create a package
Packages are fantastic ways to share polished tools with a wide
audience.  In fact, one of the major benefits of R is all the fantastic packages that have been
written by others and shared publicly on [CRAN](http://cran.r-project.org/).  But they are **much**
too heavy-weight for some simple utility functions; I don't want to
go through all that work when I write a little util that just defaults some options to `plot()`.  

The other way to re-use your utility functions is to stick them in a plain `.R` file, and then
`source()` that file whenever you want to use it.  This is perfect when you are working by yourself,
and just on your on laptop.  But by itself, it doesn't work that well when you need to share your
work with others in scripts that can be run repeatably, because of the way `source()` searches
for the file.

I could reference my file with an absolute path, eg. `source("/Users/imran/myRutils/plotUtils.R")`.
Obviously, that would break if I send someone else all my `.R` files, because they'll put everything
in a different directory.  So, you could just use relative paths: if my scripts lives in
`"/Users/imran/coolNewProject/analyzeData.R"`, then I could load my utils with
`source("../../myRUtils/plotsUtils.R")`.

This gets us further, but it has some problems as the code gets used more:

1. All team members have to use the exact same directory structure.  Since we're using relative
paths, everybody has to put their utility functions in the same place relative to their scripts.
This doesn't sound too bad, but as the number of scripts proliferate this can be become a pain.

2. Its hard to have utilities "stand alone", eg. in their own git repo, or even to have multiple git
repos of utilities from many different sources, as they all need to be put in exactly the right
location to work correctly.

Both of these reasons are really just different takes on the same issue: we want looser coupling
between our scripts and our utility functions, and more flexibility on where we put our utility
functions.  In the Java world, the Java runtime has a somewhat
similar problem of figuring out where to look for all the compiled code.  You could just dump it all
in one directory -- but this can make it a pain to have shared components used by multiple different
programs.  Java solves this with a **classpath** -- a list of places to search for code.  For lack
of a better term, I propose creating a "classpath" for R as well.

If instead of using `source()`, we use the `mylib()` function I have defined below, we can get R to
search for our utilities in a handful of predefined locations.  This way, we can keep our utilities
in a completely separate location from the one-off scripts -- in fact, the utilities can even be in
a separate repo, checked out to a different location.  This can make it a lot easier for a team to
keep a set of shared utilities, which they all use, maintain, and contribute to, while they are free
to put their hacky scripts wherever they like.

Here's how we define `mylib()`:

<script src="https://gist.github.com/squito/c1a094b1aee0fe6e84cf.js?file=mylib.R"></script>

There is just one missing piece: how do we ensure this file gets loaded all the time?  We don't want
to have to paste these function definitions at the top of every file, or in the beginning of every R
session; we would be no better off than we were in the beginning.

We can solve this problem by using `~/.Rprofile`, a file which contains ordinary R code that 
is automatically loaded every time R starts up.  We can either paste the definitions from there into
`~/.Rprofile`, or we can put those definitions in another file, and just have `~/.Rprofile` source
that file.  (Yes, in this one case, we'll need to use `source()` and every individual will have to
ensure the paths are right for their setup.)

After we do this small amount of setup, it becomes easy to use the `mylib()` function:

<script src="https://gist.github.com/squito/c1a094b1aee0fe6e84cf.js?file=usage.R"></script>

One final note for mac users: if you want to use environment variables when defining your
`source.dirs`, its a little tricky to make sure those environment variables are defined for gui
applications, like RStudio.  using env variables is a bit tricky on the mac, if you want them
present in a GUI also, like RStudio. In that case, you need edit a file `~/.launchd.conf` and add
a line like `setenv <VAR_NAME> <VAR_VALUE>`
then execute
`launchctl < ~/.launchd.conf`

Now that we've got our utility functions nicely separated, so they are easier to reuse and maintain,
the next step would be set some unit tests for them.  But, that will have to wait for a future blog
post :)

I hope this was helpful -- honestly this is a system I came up with myself to fill a need.  I'm
curious if bigger teams of R users have developed other ways of dealing with this problem, I'd love
to hear about it in the comments.
