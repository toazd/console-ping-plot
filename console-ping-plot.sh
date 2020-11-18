#!/bin/sh
# Known bugs:
# BUG CONTROL-C escaping at just the right moment (while in a subshell in the main loop) can cause an error in some tests
# BUG Using CONTROL+C escaping this way masks the real return value of any previous command
# BUG if the route of a ping takes it near a blackhole it may become negative

hostname=''
file_ping_time=''
file_avg_ping_time=''
terminal_type='ansi'
label_host_color='royalblue'
label_xlabel_samples_color='dark-cyan'
label_ylabel_time_color='dark-cyan'
plot_sample_color='grey60'
plot_average_color='dark-goldenrod'
label_jitter_color='orange'
xtics_color='dark-goldenrod'
ytics_color='dark-goldenrod'
border_color='khaki'
point_type_average='μ'
point_type_samples='x'
ping_time_min=999999999999
ping_time_max=0
null_response_max=10
null_response_count=0
update_interval=0.5
plot_history_max=500
ping_max_good=100
ping_max_warn=70
latest_ping_time=0
ping_time_last=0
ping_time_average=0
plot_y_min=0
plot_y_max=0
jitter_count=0
jitter_delta_count=0
jitter_abs_delta=0
jitter_abs_delta_sum=0
data_line=''
data_lines_count=0
debug_mode=0
debug_random_ping_max=150
debug_command_generation='s'

trap 'TrapCNTRLC' INT
trap 'ExitTrap' ABRT HUP EXIT

TrapCNTRLC() {
    exit_status=$?
    printf '\033[0m' # prevent the terminal cursor from changing color if you exit at just the right moment in any color mode
    exit "$exit_status"
}

ExitTrap() {
    if [ "$debug_mode" -eq 0 ]
    then
        [ -f "$file_ping_time" ] && rm -f "$file_ping_time"
        [ -f "$file_avg_ping_time" ] && rm -f "$file_avg_ping_time"
    elif [ "$debug_mode" -eq 1 ]
    then
        [ -f "$file_ping_time" ] && rm -vfi "$file_ping_time"
        [ -f "$file_avg_ping_time" ] && rm -vfi "$file_avg_ping_time"
    fi
}

BeHelpful() {
    cat <<END_OF_HELP

    $(basename "$0" .sh)

    Requirements:      Gnuplot, ping, bc

    -h                 - Show this help
    -H <host>          - Host name or IP recognized by ping
    -s <integer>       - Max samples to plot (default: $plot_history_max)
                           Max x-axis samples before clearing and starting over
                           Must be greater than or equal to 3
    -u <seconds>       - Plot update interval (default: $update_interval)
                           Values supported by sleep. Zero means as fast as possible.
    -m <mode>          - Gnuplot "dumb" terminal option (default: $terminal_type)
                           Accepted values: mono, ansi, ansi256, or ansirgb
                           For colors to work any mode except mono must be specified
    -i <character>     - Pointtype used for sample/ping points plot (default: $point_type_samples)
                           Only the first character will be used if multiple characters are supplied
    -l <character>     - Pointtype used for points in the average linespoints plot (default: $point_type_average)
                           Only the first character will be used if multiple characters are supplied
    -c <colorspec>     - Host label text color (default: $label_host_color)
    -j <colorspec>     - Jitter label text color (default: $label_jitter_color)
    -f <colorspec>     - X-axis label text color (default: $label_xlabel_samples_color)
    -g <colorspec>     - Y-axis label label text color (default: $label_ylabel_time_color)
    -b <colorspec>     - Border color (default: $border_color)
                           Color of the border including the x-axis and y-axis surrounding the plot
                           Must be a valid color recognized by gnuplot
    -p <colorspec>     - Points plot (sample/ping) color (default: $plot_sample_color)
                           Color of the points that plot each sample/ping
    -a <colorspec>     - Linespoints plot (average) color (default: $plot_average_color)
                           Color of the lines and points that plot average (ping)
    -x <colorspec>     - Xtics color (default: $xtics_color)
                           Color of the major labeled tics on the x-axis
    -y <colorspec>     - Ytics color (default: $ytics_color)
                           Color of the major labeled tics on the y-axis
    -d                 - Enable Debug mode (default: off)
                           Disables ping and instead ping time values are random generated values
                           You will be asked to remove temporary data files on script exit instead of silent removal
                           The -H parameter is not required in this mode
    -z <integer>       - When in debug mode, specifies the maximum integer used for random ping time generation
                           The minimum is always 0 (default: $debug_random_ping_max)
    -r <character>     - When in debug mode, use either (a)wk or (s)huf for random number generation
                           (default: $debug_command_generation)

END_OF_HELP
    exit
}

OPTERR=1
while getopts 'hH:s:u:m:j:b:p:a:x:y:i:l:c:f:g:dz:r:' sOPT
do
    case "$sOPT" in
        ('h'|'?') BeHelpful ;;
        ('H') hostname=$OPTARG ;;
        ('s')
            if [ "$OPTARG" -lt 3 ]
            then
                plot_history_max=3
            else
                plot_history_max=$OPTARG
            fi
        ;;
        ('u') update_interval=$OPTARG ;;
        ('m') terminal_type=$OPTARG ;;
        ('c') label_host_color=$OPTARG ;;
        ('j') label_jitter_color=$OPTARG ;;
        ('b') border_color=$OPTARG ;;
        ('p') plot_sample_color=$OPTARG ;;
        ('a') plot_average_color=$OPTARG ;;
        ('x') xtics_color=$OPTARG ;;
        ('y') ytics_color=$OPTARG ;;
        ('i') point_type_samples=$OPTARG ;;
        ('l') point_type_average=$OPTARG ;;
        ('f') label_xlabel_samples_color=$OPTARG ;;
        ('g') label_ylabel_time_color=$OPTARG ;;
        ('d') debug_mode=1; hostname='DEBUG'; label_host_color='red' ;;
        ('z')
            if [ "$OPTARG" -lt 2 ]
            then
                debug_random_ping_max=2
            else
                debug_random_ping_max=$OPTARG
            fi
        ;;
        ('r')
            if [ "$OPTARG" = 's' ] || [ "$OPTARG" = 'a' ]
            then
                debug_command_generation=$OPTARG
            else
                exit 1
            fi
        ;;
        (':') exit 1 ;;
    esac
done

# required parameters
if [ -z "$hostname" ] && [ "$debug_mode" -eq 0 ]
then
    echo "-H is a required parameter"
    BeHelpful
fi

# required debug commands
if [ "$debug_command_generation" = 's' ] && [ "$debug_mode" -eq 1 ];
then
    if ! command -v shuf >/dev/null
    then
        echo "shuf not found"
        exit 1
    fi
fi

if [ "$debug_command_generation" = 'a' ] && [ "$debug_mode" -eq 1 ]
then
    if ! command -v awk >/dev/null
    then
        echo "awk not found"
        exit 1
    fi
fi

# required commands
if ! command -v gnuplot >/dev/null
then
    echo "gnuplot is a required command"
    exit 1
fi

if ! command -v ping >/dev/null
then
    echo "ping is a required command"
    exit 1
fi

if ! command -v shuf >/dev/null
then
    echo "bc is a required command"
    exit 1
fi

# setup temporary data files
file_ping_time=$(mktemp -q --tmpdir "$(basename "$0" .sh)".$$.tmp.XXXXXXXXXX)
file_avg_ping_time=$(mktemp -q --tmpdir "$(basename "$0" .sh)".$$.tmp.XXXXXXXXXX)

# All hope abandon, ye who enter here!
while :
do
    # If not in debug mode
    if [ "$debug_mode" -eq 0 ]
    then
        #shellcheck disable=SC2034
        while IFS=' ' read -r -- f0 f1 f2 f3 f4 f5 f6 f7 f8
        do
            case $f6 in
                (*'='*)
                    # time=100
                    if [ "${f6%=*}" = 'time' ]
                    then
                        latest_ping_time=${f6#*=}
                        break 1
                    else
                        latest_ping_time=''
                    fi
                ;;
            esac
        done <<EOC
$(ping -nc1 "$hostname" 2>/dev/null)
EOC
        #latest_ping_time=$(ping -nc1 "$hostname" | awk 'NR==2 {print substr($7,6)}')
    elif [ "$debug_mode" -eq 1 ]
    then
        # Used for quickly testing "random" input values
        while [ "$latest_ping_time" = "$ping_time_last" ]
        do
            if [ "$debug_command_generation" = 'a' ]
            then
                latest_ping_time=$(awk -v min=0 -v max="$debug_random_ping_max" 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')
            elif [ "$debug_command_generation" = 's' ]
            then
                latest_ping_time=$(shuf -i 0-"$debug_random_ping_max" -n 1)
            else
                exit 1
            fi
        done
        ping_time_last=$latest_ping_time
    fi

    # avoid writing null to the data file
    if [ -n "$latest_ping_time" ]
    then
        # write the current ping time to a temporary data file
        printf '%s\n' "${latest_ping_time}" >> "${file_ping_time}"
        # update the data file line count
        data_lines_count=$(wc -l < "$file_ping_time")
    fi

    # ensure we don't get stuck in an endless, frivolous loop if a connection is dropped or an unreachable host is specified
    # number of consecutive NULL|zero responses from ping which will cause the script to abort
    # NOTE interspersed successful pings > @(NULL|0) will reduce the count so a bad connection can still be plotted
    # NOTE null_response_max might need tweaking
    # TODO update variable names to indicate that a zero response in addition to NULL will trigger this
    if [ "$(printf '%s\n' "$latest_ping_time > 0" | bc -l)" -eq 1 ]
    then
        [ "$null_response_count" -gt 0 ] && null_response_count=$(( null_response_count - 1 ))
    else
        null_response_count=$(( null_response_count + 1 ))
        [ "$null_response_count" -ge "$null_response_max" ] && { echo "Max NULL or Zero responses reached. Aborting."; exit 1; }
    fi

    # calculate average ping on a rolling basis
    ping_time_average=0
    if [ "$data_lines_count" -gt 1 ]
    then
        while read -r data_line
        do
            ping_time_average=$(printf "%s\n" "scale=4; $ping_time_average + $data_line" | bc -l)
        done < "$file_ping_time"
    elif [ "$data_lines_count" -eq 1 ]
    then
        ping_time_average=$latest_ping_time
    fi

    # avoid dividing by zero
    if [ "$data_lines_count" -eq 0 ]
    then
        ping_time_average=0
    else
        ping_time_average=$(printf "%s\n" "scale=4; $ping_time_average / $data_lines_count" | bc -l)
    fi

    # write the avg so far to a temporary file
    printf '%s\n' "$ping_time_average" >> "$file_avg_ping_time"

    # calculate jitter on a rolling basis
    if [ -n "$latest_ping_time" ]
    then
        if [ $((data_lines_count%2)) -eq 0 ]
        then
            jitter_sample_a=$latest_ping_time
        elif [ $((data_lines_count%2)) -eq 1 ]
        then
            jitter_sample_b=$latest_ping_time
        fi
        jitter_count=$((jitter_count+1))

        if [ "$jitter_count" -ge 2 ]
        then
            jitter_abs_delta=$(printf '%s\n' "scale=4; $jitter_sample_a - $jitter_sample_b" | bc -l)
            jitter_abs_delta=${jitter_abs_delta#-}
            jitter_abs_delta_sum=$(printf '%s\n' "scale=4; $jitter_abs_delta_sum + $jitter_abs_delta" | bc -l)
            jitter_delta_count=$((jitter_delta_count + 1))
        fi

        if [ "$jitter_delta_count" -ge 1 ]
        then
            iJITTER=$(printf "%s\n" "scale=4; $jitter_abs_delta_sum / $jitter_delta_count" | bc -l)
        fi

        # DEBUG only
        #[ "$jitter_delta_count" -ge 1 ] && printf "%s\n" "$iJITTER" >> jitter.out
    fi

    # max history reached, clear data files and start over
    if [ "$data_lines_count" -gt "$plot_history_max" ]
    then
        printf '' > "$file_ping_time"
        printf '' > "$file_avg_ping_time"
        continue
    fi

    # If the current ping time is greater than the current ping time max it becomes the latest maximum
    [ "$(printf '%s\n' "$latest_ping_time > $ping_time_max" | bc -l)" -eq 1 ] && ping_time_max=$latest_ping_time

    # If the current ping time is less than the current ping min it becomes the latest minimum
    [ "$(printf '%s\n' "$latest_ping_time < $ping_time_min" | bc -l)" -eq 1 ] && ping_time_min=$latest_ping_time

    # Adjust the yrange based on the max and min centered around the avg
    # For whatever reason, gnuplot has trouble autosizing to include all plot values
    # and centering the graph at the average plot even when using a graph offset
    if [ "$(printf "%s\n" "$ping_time_average > 0" | bc -l)" -eq 1  ]
    then
        plot_y_max=$(printf '%s\n' "scale=4; ($ping_time_max + ($ping_time_average / 10))" | bc -l)
        plot_y_min=$(printf '%s\n' "scale=4; ($ping_time_min - ($ping_time_average / 10))" | bc -l)
    fi

    # Get the current screen character width and height for gnuplot
    console_dimensions=$(stty size)
    console_height=${console_dimensions% *}
    console_width=${console_dimensions#* }

    # Color the ping stats labels text based on quality thresholds set above
    # Unfortunately, multi-colored text on a single label is not supported by gnuplot
    # so it's either this way or add more labels
    # Latest ping time
    if [ "$(printf "%s\n" "$latest_ping_time >= $ping_max_good" | bc -l)" -eq 1 ]
    then
        label_ping_current_color="red"
    elif [ "$(printf "%s\n" "$latest_ping_time >= $ping_max_warn && $latest_ping_time < $ping_max_good" | bc -l)" -eq 1 ]
    then
        label_ping_current_color="yellow"
    else
        label_ping_current_color="green"
    fi

    # Latest ping time minimum
    if [ "$(printf "%s\n" "$ping_time_min >= $ping_max_good" | bc -l)" -eq 1 ]
    then
        label_ping_min_color="red"
    elif [ "$(printf "%s\n" "$ping_time_min >= $ping_max_warn && $ping_time_min < $ping_max_good" | bc -l)" -eq 1 ]
    then
        label_ping_min_color="yellow"
    else
        label_ping_min_color="green"
    fi

    # Latest ping time maximum
    if [ "$(printf "%s\n" "$ping_time_max >= $ping_max_good" | bc -l)" -eq 1 ]
    then
        label_ping_max_color="red"
    elif [ "$(printf "%s\n" "$ping_time_max >= $ping_max_warn && $ping_time_max < $ping_max_good" | bc -l)" -eq 1 ]
    then
        label_ping_max_color="yellow"
    else
        label_ping_max_color="green"
    fi

    # Latest ping time average
    if [ "$(printf "%s\n" "$ping_time_average >= $ping_max_good" | bc -l)" -eq 1 ]
    then
        label_ping_avg_color="red"
    elif [ "$(printf "%s\n" "$ping_time_average >= $ping_max_warn && $ping_time_average < $ping_max_good" | bc -l)" -eq 1 ]
    then
        label_ping_avg_color="yellow"
    else
        label_ping_avg_color="green"
    fi

    # Make the labels
    label_host=" $hostname "
    label_ping_min=" Minimum: $(printf "%1.3g" "$ping_time_min") "
    label_ping_max=" Maximum: $(printf "%1.3g" "$ping_time_max") "
    label_ping_avg=" Average: $(printf "%1.3g" "$ping_time_average") "
    label_ping_current=" Current: $(printf "%1.3g" "$latest_ping_time") "
    label_jitter=" Jitter: $(printf "%1.3g" "$iJITTER") "
    label_samples="${data_lines_count}/${plot_history_max} samples, ${update_interval}s interval"

    # avoid errors with gnuplot when there is no y-axis coordinate to plot
    # TODO test if this is even needed anymore
    [ "$(printf "%s\n" "$plot_y_min >= $plot_y_max" | bc -l)" -eq 1 ] && continue

    # DEBUG labels
    #set label \"DEBUG - DeltaSum: $jitter_abs_delta_sum JitDeltaCnt: $jitter_delta_count JitCnt: $jitter_count SmpA: $jitter_sample_a SmpB: $jitter_sample_b AbsDelta: $jitter_abs_delta\" at graph 0.5,0.05 center front nopoint textcolor \"red\"; \
    # set label \"($plot_y_min $plot_y_max)\" at graph 0.5,0.3 center front nopoint textcolor \"red\"; \

    gnuplot -e "set terminal dumb noenhanced $terminal_type size $console_width, $console_height; \
                set encoding utf8; set key off; set autoscale x; \
                set x2label; set y2label; \

                set yrange [$plot_y_min:$plot_y_max]; \

                set xlabel \"$label_samples\" norotate offset character 0,0 textcolor \"$label_xlabel_samples_color\"; \
                set ylabel \"Time\n(ms)\" norotate offset character 4,3 textcolor \"$label_ylabel_time_color\"; \

                set bmargin 3; set tmargin 1; set rmargin 1; \
                set border front linestyle 1 linecolor \"${border_color}\"; \

                set xtics mirror border in autojustify scale default textcolor \"$xtics_color\"; \
                set ytics mirror border in autojustify scale default textcolor \"$ytics_color\"; \

                set label \"$label_host\" at graph 0.5,0.01 center front nopoint textcolor \"$label_host_color\"; \

                set label \"$label_ping_min\" at graph 0.25,1 center front nopoint textcolor \"$label_ping_min_color\"; \
                set label \"$label_ping_max\" at graph 0.37,1 center front nopoint textcolor \"$label_ping_max_color\"; \
                set label \"$label_ping_avg\" at graph 0.49,1 center front nopoint textcolor \"$label_ping_avg_color\"; \
                set label \"$label_ping_current\" at graph 0.61,1 center front nopoint textcolor \"$label_ping_current_color\"; \
                set label \"$label_jitter\" at graph 0.73,1 center front nopoint textcolor \"$label_jitter_color\"; \

                set datafile separator \"\n\"; \
                set datafile commentschars \"#\"; \
                plot \"$file_avg_ping_time\" with linespoints pointtype \"$point_type_average\" linecolor \"$plot_average_color\", \
                     \"$file_ping_time\" with points pointtype \"$point_type_samples\" linecolor \"$plot_sample_color\""
    sleep "$update_interval"s
done
