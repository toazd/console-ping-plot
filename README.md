![](https://github.com/toazd/console-ping-plot/blob/master/preview/preview.gif)  
Note that the default colorscheme is suitable for a dark background or a dark theme.  
Color related options are easily customizable both inside the script itself and as command-line parameters.  

This script was created as a learning exercise inspired by:  
https://www.reddit.com/r/commandline/comments/hnjpc6/pingplotter_makes_a_live_graph_of_ping_times_to_a/

Features
----------
Written targeting POSIX sh and to be as minimal and as effecient as possible while still maintaining a high degree of legibility and precision  
Provides visual plot of both data points and a rolling average  
Tracks null/failed pings so that a bad connection can still be plotted (configurable)  
All relevant calculations are done using bc and support displaying three decimal places (eg. 43.517)  


    -h                 - Show this help
    -H <host>          - Host name or IP recognized by ping
    -s <integer>       - Max samples to plot
                           Max x-axis samples before clearing and starting over
                           Must be greater than or equal to 3
    -u <seconds>       - Plot update interval
                           Values supported by sleep. Zero means as fast as possible.
    -m <mode>          - Gnuplot "dumb" terminal option
                           Accepted values: mono, ansi, ansi256, or ansirgb
                           For colors to work any mode except mono must be specified
    -F <integer>       - Maximum null/failed ping responses before aborting (0=disable this feature)
                           Successfull pings interspersed amongst failures will lower the abort counter
    -i <character>     - Pointtype used for sample/ping points plot
                           Only the first character will be used if multiple characters are supplied
    -l <character>     - Pointtype used for points in the average linespoints plot
                           Only the first character will be used if multiple characters are supplied
    -c <colorspec>     - Host label text color
    -j <colorspec>     - Jitter label text color
    -f <colorspec>     - X-axis label text color
    -g <colorspec>     - Y-axis label label text color
    -b <colorspec>     - Border color
                           Color of the border including the x-axis and y-axis surrounding the plot
                           Must be a valid color recognized by gnuplot
    -p <colorspec>     - Points plot (sample/ping) color
                           Color of the points that plot each sample/ping
    -a <colorspec>     - Linespoints plot (average) color
                           Color of the lines and points that plot average (ping)
    -x <colorspec>     - Xtics color
                           Color of the major labeled tics on the x-axis
    -y <colorspec>     - Ytics color
                           Color of the major labeled tics on the y-axis
    -d                 - Enable Debug mode (default: off)
                           Disables ping and instead ping time values are random generated values
                           You will be asked to remove temporary data files on script exit instead of silent removal
                           The -H parameter is not required in this mode
    -z <integer>       - When in debug mode, specifies the maximum integer used for random ping time generation
                           The minimum is always 0
    -r <character>     - When in debug mode, use either (a)wk or (s)huf for random number generation
