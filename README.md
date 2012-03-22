avgtime
=======

Works like the linux `time` command, except it accepts a -r argument to
specify repetitions and shows stats.

If repetitions are specified, then stats are computed and shown, like
median, average, and standard deviation.

Pass `-q` to make the program under test silent (stdout and stderr 
piped to /dev/null).

How to use
==========

Do:

        avgtime -r 1000 <your_command>

to run <your_command> a thousand times. 

For instance:

        avgtime -r 10 -q ls -lR /etc

        ------------------------
        Total time (ms): 933.742
        Repetitions    : 10
        Median time    : 90.505
        Avg time       : 93.3742
        Std dev.       : 4.66808
        Minimum        : 88.732
        Maximum        : 101.225

Displayed times are in milliseconds.

Run avgtime without arguments to see more usage help.


How to install
==============

This little program is written in the most awesome programming language 
of the world: D  (http://dlang.org).

To compile `avgtime`, you must have D installed. You can download D
from http://dlang.org/download.html 

Compile with:
 
        dmd avgtime.d

and that's it. You can use `./avgtime` now. Copy it to /usr/local/bin
to have it in your path.


Why do I need the stats?
========================

If you are a benchmarker type of guy, you know that there is no `fast`
or `slow`. There is only `faster` and `slower`. So you usually find
yourself comparing the times of two different things, to see which
one is faster. Do you run them once? Are you satisfied that you
improved the running time of your program with just one run?

That depends on how big the time difference is. And usually, we
optimize things one step at a time, making small improvements.
This all means that we must run the program many times to distinguish
our little improvements from background noise. Which
now means that the running time of your program has become
a random variable (in the probability theory sense), of which
we must take samples to reach a conclusion about its 
probability distribution.

_Even when doing dramatic optimizations, as opposed to little ones,
ie: reducing time complexity by using better algorithms,
we must make sure that it was worthy and keep constant 
times in check._


To really know whether you made an improvement on running time,
you must take into account the standard deviation (or any other
confidence interval), and at least make sure that 
the `Average +/- StdDev` intervals don't overlap.
   Or, if you are too lazy, **just make sure that the maximum time
of the 'fast' version, is better than the minimum of the 'slow' 
version under test.**

See, one is not measuring the running time of a program. You are
actually measuring the interval of running times where it 
is likely to always stay... its probability distribution.


_(Look for 'Hypothesis Testing' and 'Confidence Intervals' on the web 
for more on the subject)._



HAVE FUN!

--



