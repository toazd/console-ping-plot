![](https://github.com/toazd/console-ping-plot/blob/master/preview/preview.gif)  
Note that the default colorscheme is suitable for a dark background or a dark theme.  
Color related options are easily customizable both inside the script itself and as command-line parameters.  

This script was created as a learning exercise inspired by:  
https://www.reddit.com/r/commandline/comments/hnjpc6/pingplotter_makes_a_live_graph_of_ping_times_to_a/

Features
----------
- Written targeting POSIX sh 
- Provides visual plot of both data points and a rolling average  
- Displays minimum, mean, maximum, and jitter for the current plot data set  
  - Minimum, mean, and maximum are color-coded based on configurable thresholds to visually indicate a values status (green, yellow, red)  
- Tracks null/failed pings so that a bad connection can still be plotted (configurable)  
- All relevant calculations are done using bc and support displaying three decimal places (eg. 43.517)  
