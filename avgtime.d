/** avgtime - Runs a command with an optional repetition and shows 
 *  statistics of the time it took.
 *
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Juan Manuel Cabo
 * Version:   0.1
 * Source:    avgtime.d
 * Last update: 2012-03-21
 */
/*          Copyright Juan Manuel Cabo 2012.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

module avgtime;

import std.stdio;
import std.process;
import std.datetime;
import core.time;
import core.sys.posix.unistd;
import core.sys.posix.sys.wait;
import core.thread;
import std.getopt;
import std.algorithm: sort;
import std.math: sqrt;


Duration[] durations;

int main(string[] args) {
    if (args.length == 1) {
        showUsage();
        return 0;
    }

    //Parse options:
    int repetitions = 1;
    bool quiet = false;
    try {
        getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.noPassThrough,
            std.getopt.config.stopOnFirstNonOption,
            "repetitions|r", &repetitions,
            "quiet|q", &quiet);
    } catch (Exception ex) {
        stderr.writeln(ex.msg);
        return 1;
    }

    if (args.length < 2) {
        showUsage();
        return 0;
    }

    if (repetitions <= 1) {
        repetitions = 1;
    }

    //Run the program, collecting time info.
    string prog = args[1];
    string[] progArgs = args[1..$];
    for (int i=0; i < repetitions; ++i) {
        Duration duration = run(prog, progArgs, quiet);
        durations ~= duration;
    }

    //Compute and show stats:
    showStats();

    return 0;
}

void showUsage() {
    writeln("avgtime - Runs a command repeatedly and shows time statistics."
          ~ "\nUsage: avgtime [--quiet|-q] [--repetitions=N|-r N] <command> [<arguments>]"
          ~ "\nExamples: "
          ~ "\n    avgtime ls -lR"
          ~ "\n    avgtime -r 10 ls -lR"
          ~ "\n    avgtime --repetitions=10 --quiet ls -lR"
          ~ "\n    avgtime --repetitions=10 sleep 0.1"
          ~ "\n    avgtime -q -r10 ls -lR"
    );
}

Duration run(string prog, string[] progArgs, bool quiet) {
    SysTime start = Clock.currTime();

    //Must use fork and execvp, because shell() has some overhead.
    pid_t pid = fork();
    if (pid == 0) {
        if (quiet) {
            freopen("/dev/null", "w", stdout.getFP());
            freopen("/dev/null", "w", stderr.getFP());
        }

        std.process.execvp(prog, progArgs);

        _exit(0);
    }
    int status;
    waitpid(pid, &status, 0);

    SysTime end = Clock.currTime();
    return end - start;
}


void showStats() {
    long N = durations.length;

    if (N == 0) {
        writeln("Error, no time info.");
        return;
    }
    if (N == 1) {
        writeln("\n------------------------");
        writeln("Total time (ms): ", durations[0].total!"usecs"() / 1000.0);
        return;
    }

    //Get sum, average and stdDev:
    real sum = 0;
    real sumSq = 0;
    real min = durations[0].total!"usecs"();
    real max = durations[0].total!"usecs"();
    real[] durationsUsecs;
    foreach (Duration duration; durations) {
        real usecs = duration.total!"usecs"();
        sum += usecs;
        sumSq += usecs * usecs;
        durationsUsecs ~= usecs;
        if (min > usecs) { min = usecs; }
        if (max < usecs) { max = usecs; }
    }
    real avg = sum / N;
    real stdDevFast = sqrt(sumSq/N - avg * avg);

    //Sort and get media:
    sort(durationsUsecs);
    real median = 0;
    if ((durationsUsecs.length % 2) == 0) {
        //Average between the two central values
        median = (durationsUsecs[($/2) - 1] + durationsUsecs[$/2]) / 2.0;
    } else {
        //Value in the middle:
        median = durationsUsecs[$/2];
    }


    writeln("\n------------------------");
    writeln("Total time (ms): ", sum / 1000.0);
    writeln("Repetitions    : ", N);
    writeln("Median time    : ", median / 1000.0);
    writeln("Avg time       : ", avg / 1000.0);
    writeln("Std dev.       : ", stdDevFast / 1000.0);
    writeln("Minimum        : ", min / 1000.0);
    writeln("Maximum        : ", max / 1000.0);
}



