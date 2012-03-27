/** avgtime - Runs a command with an optional repetition and shows 
 *  statistics of the time it took.
 *
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Juan Manuel Cabo
 * Version:   0.5
 * Source:    avgtime.d
 * Last update: 2012-03-27
 */
/*          Copyright Juan Manuel Cabo 2012.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

module avgtime;

import std.stdio, std.process, std.getopt, core.time, std.string, std.conv;
import std.algorithm: sort, replace, map, max;
import std.array: array, replicate;
import std.math: sqrt, log10;

version(Posix) {
    import core.sys.posix.unistd;
    import core.sys.posix.sys.wait;
} else version(Windows) {
    import core.sys.windows.windows;

    extern(Windows) {
        struct STARTUPINFOA {
            DWORD cb;
            LPSTR lpReserved;
            LPSTR lpDesktop;
            LPSTR lpTitle;
            DWORD dwX;
            DWORD dwY;
            DWORD dwXSize;
            DWORD dwYSize;
            DWORD dwXCountChars;
            DWORD dwYCountChars;
            DWORD dwFillAttribute;
            DWORD dwFlags;
            WORD wShowWindow;
            WORD cbReserved2;
            LPBYTE lpReserved2;
            HANDLE hStdInput;
            HANDLE hStdOutput;
            HANDLE hStdError;
        }
        alias STARTUPINFOA* LPSTARTUPINFOA;

        immutable DWORD STARTF_USESTDHANDLES = 0x00000100;

        /*
        struct SECURITY_ATTRIBUTES {
            DWORD nLength;
            LPVOID lpSecurityDescriptor;
            BOOL bInheritHandle;
        }
        alias SECURITY_ATTRIBUTES* PSECURITY_ATTRIBUTES;
        alias SECURITY_ATTRIBUTES* LPSECURITY_ATTRIBUTES;
        */

        struct PROCESS_INFORMATION {
            HANDLE hProcess;
            HANDLE hThread;
            DWORD dwProcessId;
            DWORD dwThreadId;
        }
        alias PROCESS_INFORMATION* PPROCESS_INFORMATION;
        alias PROCESS_INFORMATION* LPPROCESS_INFORMATION;

        export BOOL CreateProcessA(LPCSTR lpApplicationName, 
            LPSTR lpCommandLine,
            LPSECURITY_ATTRIBUTES lpProcessAttributes, 
            LPSECURITY_ATTRIBUTES lpThreadAttributes,
            BOOL bInheritHandles, DWORD dwCreationFlags, LPVOID lpEnvironment,
            LPCSTR lpCurrentDirectory, LPSTARTUPINFOA lpStartupInfo,
            LPPROCESS_INFORMATION lpProcessInformation
        );
    }

} else {
    static assert(false, "Untested platform");
}


int main(string[] args) {
    if (args.length == 1) {
        showUsage();
        return 0;
    }

    //Parse options:
    int repetitions = 1;
    bool discardFirst = false;
    bool quiet = false;
    bool printTimes = false;
    bool printHistogram = false;
    try {
        getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.noPassThrough,
            std.getopt.config.stopOnFirstNonOption,
            "discardfirst|d", &discardFirst,
            "printtimes|p", &printTimes,
            "printhistogram|h", &printHistogram,
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
    if (discardFirst) {
        ++repetitions;
    }

    //Run the program, collecting time info.
    string prog = args[1];
    string[] progArgs = args[1..$];
    TickDuration[] durations;
    for (int i=0; i < repetitions; ++i) {
        TickDuration duration = run(prog, progArgs, quiet);
        if (!discardFirst || i != 0) {
            durations ~= duration;
        }
    }

    //Compute and show stats:
    showStats(durations, printTimes, printHistogram);

    return 0;
}

void showUsage() {
    version(Posix) {
        string examples = `
    avgtime -q -r30      ls -lR
    avgtime -h -q -r100  ls *`;
    } else version(Windows) {
        string examples = `
    avgtime -q -r30      cmd /c dir
    avgtime -h -q -r100  fc /?`;
    }

    writeln(
`avgtime - Runs a command repeatedly and shows time statistics.
Usage: avgtime [OPTIONS] <command> [<arguments>]

  -r, --repetitions=N    Repeat <command> N times
  -q, --quiet            Suppress the command's stdout and stderr
                         piping them to /dev/null.
  -h, --printhistogram   Print a nice histogram, grouping times by
                         most significant digits.
  -p, --printtimes       Print all measurements in milliseconds
  -d, --discardfirst     Performs an extra repetition, and then discards 
                         it. It's like a warmup to prevent first 
                         run outlier.

Examples: 
` ~ examples ~ `

Notes:

    * The 'sample mode' is the most frequent rounded measurement.

    * The 'median' is the timing in the middle of the sorted list of timings.

    * If the 95% confidence interval's of the timings of two programs 
      don't overlap, then you can be confident that one is faster 
      than the other.
      This assumes a 'normal distribution', and for the assumption 
      to work, N must be at least 30. The more repetitions, the better.

    * There is a small irreductible overhead in the order of 1ms to 10ms,
      depending on your computer and OS, inherent to forking and 
      process loading.`
);
}

TickDuration run(string prog, string[] progArgs, bool quiet) {
    TickDuration start;
    TickDuration end;

    version(Posix) 
    {
        start = TickDuration.currSystemTick();

        //Using fork() and execvp(). system() and shell() would 
        //invoke '/bin/sh' first which wouldn't be so direct.
        pid_t pid = fork();
        if (pid == 0) {
            if (quiet) {
                freopen("/dev/null", "w", stdout.getFP());
                freopen("/dev/null", "w", stderr.getFP());
            }

            //Run the program:
            auto ret = std.process.execvp(prog, progArgs);
            if (ret == -1) {
                stderr.writeln("Error: command '" ~ prog  ~ "' not found.");
                _exit(1);
            }

            _exit(0);
        }
        int status;
        waitpid(pid, &status, 0);
        end = TickDuration.currSystemTick();
    }
    else version(none) 
    {
        progArgs = progArgs[1..$];
        string cmdLine = prog ~ " " ~ join(progArgs, " ");
        start = TickDuration.currSystemTick();
        //The system() function works, but it first invokes a shell:
        system(cmdLine);
        end = TickDuration.currSystemTick();
    } 
    else version(Windows) 
    {
        progArgs = progArgs[1..$];
        string cmdLine = prog ~ " " ~ join(progArgs, " ");
        
        PROCESS_INFORMATION processInfo;
        STARTUPINFOA startupInfo;
        startupInfo.cb = startupInfo.sizeof;

        HANDLE handleNull;
        LPSECURITY_ATTRIBUTES saProcess = null;
        if (quiet) {
            startupInfo.dwFlags = STARTF_USESTDHANDLES;

            SECURITY_ATTRIBUTES sa;
            sa.nLength = SECURITY_ATTRIBUTES.sizeof;
            sa.bInheritHandle = true;
            saProcess = &sa;

            //Open windows "NUL" file:
            handleNull = CreateFileA("NUL", GENERIC_READ | GENERIC_WRITE, 
                    FILE_SHARE_READ | FILE_SHARE_WRITE, &sa, OPEN_EXISTING, 0,
                    null);

            //Set "NUL" as stdout and stderr of the new process:
            startupInfo.hStdInput = INVALID_HANDLE_VALUE;
            startupInfo.hStdOutput = handleNull;
            startupInfo.hStdError = handleNull;
        }

        //Run the program
        start = TickDuration.currSystemTick();
        auto result = CreateProcessA(null, cast(char*)toStringz(cmdLine),
            saProcess, saProcess, quiet, 0, null, null, 
            &startupInfo, &processInfo);

        if(!result) {
            stderr.writeln("Error: command '" ~ prog  ~ "' not found.");
            return TickDuration(0);
        }

        //Wait until it finishes
        WaitForSingleObject(processInfo.hProcess, INFINITE);

        end = TickDuration.currSystemTick();

        CloseHandle(processInfo.hProcess);
        CloseHandle(processInfo.hThread);
        if (quiet) {
            CloseHandle(handleNull);
        }
    }
    return end - start;
}


void showStats(TickDuration[] durations, bool printTimes, bool printHistogram) {
    long N = durations.length;

    if (N == 0) {
        writeln("Error, no time info.");
        return;
    }
    if (N == 1) {
        writeln("\n------------------------");
        writeln("Total time (ms): ", durations[0].usecs() / 1000.0);
        return;
    }

    //Get sum, average and stdDev:
    real sum = 0;
    real sumSq = 0;
    real min = durations[0].usecs();
    real max = durations[0].usecs();
    real[] durationsUsecs;
    foreach (TickDuration duration; durations) {
        real usecs = duration.usecs();
        sum += usecs;
        sumSq += usecs * usecs;
        durationsUsecs ~= usecs;
        if (min > usecs) { min = usecs; }
        if (max < usecs) { max = usecs; }
    }
    real avg = sum / N;
    real stdDevFast = sqrt(sumSq/N - avg * avg);

    //Sort and get median:
    sort(durationsUsecs);
    real median = 0;
    if ((durationsUsecs.length % 2) == 0) {
        //Average between the two central values
        median = (durationsUsecs[($/2) - 1] + durationsUsecs[$/2]) / 2.0;
    } else {
        //Value in the middle:
        median = durationsUsecs[$/2];
    }


    //To build a histogram and get the mode, we need to group 
    //many values into a few bins. So we'll zero out the least 
    //significant digits. Spliting into X subintervals isn't as 
    //nice as this.
    int roundingQuotient;
    if (min > 100_000) {
        //Round 1234.5 to 1230.0 milliseconds.
        roundingQuotient = 10_000;
    } else if (min > 10_000) {
        //Round 123.45 to 123.00 milliseconds.
        roundingQuotient = 1000;
    } else {
        //Round 12.345 to 12.300 milliseconds.
        roundingQuotient = 100;
    }

    //Build frequencies and find sample mode at the same time:
    int[int] frequencies;
    real mode;
    int maxFreq = 0;
    foreach (real usecs; durationsUsecs) {
        int roundedTime = cast(int)(usecs / roundingQuotient);
        int freq = frequencies.get(roundedTime, 0);
        ++freq;
        frequencies[roundedTime] = freq;
        //Get the biggest of the modes, if there is more than one:
        if (freq >= maxFreq) {
            maxFreq = freq;
            mode = roundedTime * roundingQuotient / 1000.0;
        }
    }

    //Confidence intervals assuming a normal (gaussian) distribution:
    immutable real z0_005 = 2.57582930355;
    immutable real z0_025 = 1.95996398454;
    real muError99 = z0_005 * stdDevFast / sqrt(cast(real)N);
    real muError95 = z0_025 * stdDevFast / sqrt(cast(real)N);
    real error99 = z0_005 * stdDevFast;
    real error95 = z0_025 * stdDevFast;

    writeln("\n------------------------");
    writeln("Total time (ms): ", sum / 1000.0);
    writeln("Repetitions    : ", N);
    writeln("Sample mode    : ", mode, " (", maxFreq, " ocurrences)");
    writeln("Median time    : ", median / 1000.0);
    writeln("Avg time       : ", avg / 1000.0);
    writeln("Std dev.       : ", stdDevFast / 1000.0);
    writeln("Minimum        : ", min / 1000.0);
    writeln("Maximum        : ", max / 1000.0);
    writeln("95% conf.int.  : [", (avg - error95) / 1000.0, ", ", 
        (avg + error95) / 1000.0, "]  e = ", error95 / 1000.0);
    writeln("99% conf.int.  : [", (avg - error99) / 1000.0, ", ", 
        (avg + error99) / 1000.0, "]  e = ", error99 / 1000.0);
    writeln("EstimatedAvg95%: [", (avg - muError95) / 1000.0, ", ", 
        (avg + muError95) / 1000.0, "]  e = ", muError95 / 1000.0);
    writeln("EstimatedAvg99%: [", (avg - muError99) / 1000.0, ", ", 
        (avg + muError99) / 1000.0, "]  e = ", muError99 / 1000.0);


    //Print histogram:
    if (printHistogram) {
        //Normalize histogram. 
        //maxFreq is 100% (1.0), everything else is proportional.
        float[int] histogram;
        foreach (k,v; frequencies) {
            histogram[k] = v / cast(float)maxFreq;
        }

        //Sort the bins to print them in order:
        int[] histogramKeys = array(frequencies.keys());
        sort(histogramKeys);

        //Fix the number of digits to print after the decimal point:
        int precision = 3 - cast(int) log10(roundingQuotient);
        precision = std.algorithm.max(0, precision);
        string timeFormatStr = "%5." ~ to!string(precision) ~ "f";

        writeln("Histogram      :");
        writeln("    msecs: count  normalized bar");
        foreach(int roundedTime; histogramKeys) {
            //"Un-round" to get the milliseconds:
            real msecs = roundedTime * roundingQuotient / 1000.0;
            string msecsStr = format(timeFormatStr, msecs);

            //Bar proportional to the frequency:
            immutable LONGEST_BAR_CHARS = 40;
            string bars = replicate("#", 
                    cast(size_t)(histogram[roundedTime] * LONGEST_BAR_CHARS));

            writefln("    %s: %5.d  %s", msecsStr, 
                    frequencies[roundedTime], bars);
        }
    }

    //Print all measurements, sorted:
    if (printTimes) {
        string allTimes = format(array(map!("a / 1000.0")(durationsUsecs)));
        allTimes = wrap(replace(allTimes, ",", ", "), 80, "", "    ");

        string breakLineIfWrapped = (allTimes.indexOf('\n'))? "\n    " : "";
        writeln("Sorted times   : ", breakLineIfWrapped, allTimes);
    }
}



