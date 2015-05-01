avgtime
=======

Works like the linux `time` command, except it accepts a -r argument to
specify repetitions and shows stats.

It works for Windows, Linux and OS X.

If repetitions are specified, then stats are computed and shown, like
median, average, and standard deviation.

Pass `-q` to make the program under test silent (stdout and stderr 
piped to /dev/null). The console output sometimes slows down programs,
so it might be desirable to suppress their output with `-q`.

Pass `-d` to discard the first run. If -d is passed, there is one extra
repetition which is discarded.

Pass `-p` to print the sorted times in milliseconds.

Pass `-h` to print a very nice histogram.

How to use
==========

Do:

        avgtime -r 1000 <your_command>

to run <your_command> a thousand times. 

For instance:

        /avgtime -q -r30  ls -lR /etc

        ------------------------
        Total time (ms): 2914.28
        Repetitions    : 30
        Sample mode    : 99 (6 ocurrences)
        Median time    : 98.01
        Avg time       : 97.1426
        Std dev.       : 4.52638
        Minimum        : 89.625
        Maximum        : 106.68
        95% conf.int.  : [88.2711, 106.014]  e = 8.87154
        99% conf.int.  : [85.4834, 108.802]  e = 11.6592
        EstimatedAvg95%: [95.5229, 98.7623]  e = 1.61972
        EstimatedAvg99%: [95.0139, 99.2712]  e = 2.12867

Displayed times are in milliseconds.

Run avgtime without arguments to see more usage help.

Don't forget to check out the *nice histogram*.

*Note* that the following histogram shows two peaks because
of the CPU speed switching that laptops do. Some laptops
will often switch to low speed even in "High Performance" mode
and plugged to the wall. Forcing to high speed (always on)
eliminates the second peak (how to do that is beyond the scope).

        avgtime -q -h -r1000   ls /etc -lR

        ------------------------
        Total time (ms): 97920.7
        Repetitions    : 1000
        Sample mode    : 90 (137 ocurrences)
        Median time    : 99.0305
        Avg time       : 97.9207
        Std dev.       : 5.26182
        Minimum        : 89.081
        Maximum        : 111.864
        95% conf.int.  : [87.6077, 108.234]  e = 10.313
        99% conf.int.  : [84.3672, 111.474]  e = 13.5535
        EstimatedAvg95%: [97.5945, 98.2468]  e = 0.326125
        EstimatedAvg99%: [97.4921, 98.3493]  e = 0.428601
        Histogram      :
            msecs: count  normalized bar
               89:    45  #############
               90:   137  ########################################
               91:    58  ################
               92:    43  ############
               93:    16  ####
               94:     8  ##
               95:    33  #########
               96:    44  ############
               97:    59  #################
               98:    53  ###############
               99:    76  ######################
              100:    84  ########################
              101:    87  #########################
              102:    86  #########################
              103:    77  ######################
              104:    35  ##########
              105:    22  ######
              106:    12  ###
              107:    10  ##
              108:     6  #
              109:     6  #
              110:     1  
              111:     2  

You can see the importance of the histogram now, and of
statistics such as the 'sample mode', 'median', and
standard deviation of the sample. All these together might
help *visualize and quantify* performance effects that you 
wouldn't see by timing your program just once.


How to install
==============

This little program is written in the most awesome programming language 
of the world: D  (http://dlang.org).

To compile `avgtime`, you must have D installed. You can download D
from http://dlang.org/download.html 

Compile with:
 
        dmd avgtime.d

and that's it. You can use `./avgtime` now. Copy it to /usr/local/bin
to have it in your path (or C:\Windows\ for Windows).


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
we must make sure that it was worth it and keep constant 
times in check._


To really know whether you made an improvement on running time,
you must take into account the standard deviation (or any other
confidence interval), and at least make sure that 
the `Average +/- StdDev` intervals don't overlap.
   Or, if you are too lazy, **just make sure that the maximum time
of the 'fast' version, is better than the minimum of the 'slow' 
version under test.**

See, one is not measuring the running time of a program. One is
actually measuring the interval of running times where it 
is likely to always stay... to know more about its probability 
distribution.


_(Look for 'Hypothesis Testing' and 'Confidence Intervals' on the web 
for more on the subject)._



HAVE FUN!

--



