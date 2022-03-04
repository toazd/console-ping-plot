![](https://github.com/toazd/console-ping-plot/blob/master/preview/preview.gif)
Note that the default colorscheme is suitable for a dark background.
Color related options are easily customizable both inside the script itself and as command-line parameters.

This script was created as a learning exercise inspired by:
https://www.reddit.com/r/commandline/comments/hnjpc6/pingplotter_makes_a_live_graph_of_ping_times_to_a/

Usage
----------
- Quickstart: ./console-ping-plot.sh -h <hostname_or_ip>
- ./console-ping-plot.sh or ./console-ping-plot.sh -H for command line options.
- This script is intentionally designed to run continuously. To exit, simply press Control+C.

Features
----------
- Written targeting POSIX sh.
- Necessary commands are checked before running (bc, gnuplot, mktemp, shuf, optional: awk).
- Provides visual plot of both data points and a rolling average for a single host.
- Displays minimum, mean, maximum, and jitter for the current plot data set.
  - Minimum, mean, and maximum are color-coded based on configurable thresholds to visually indicate status (green, yellow, red).
  - Calculations are done using bc and support displaying three decimal places.
- Tracks null/failed pings to abort without wasting resources but also supports a bad or transient connection (configurable using -F)

