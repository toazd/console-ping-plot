#!/bin/sh
#
# console-ping-plot.sh UNLICENSE
# Toazd <wmcdannell@hotmail.com> Feb 2021
#
# Purpose:
#   Plot both ping and average ping for a single host in a console-friendly
#   format using Gnuplot.
#
# Refer to the output of the command
#   $ echo "show colornames" | gnuplot
# for color names and codes supported by your version of gnuplot
#
#
######### Choose the default colorscheme ######################################
theme=dark
###############################################################################
if [ "$theme" = "dark" ]; then

             terminal_type='ansirgb' # mono, ansi, ansi256, ansirgb
          label_host_color='red'
label_xlabel_samples_color='dark-salmon'
   label_ylabel_time_color='dark-salmon'
        label_jitter_color='dark-spring-green'
               xtics_color='sienna1'
               ytics_color='sienna1'
              border_color='goldenrod'
        plot_average_color='dark-cyan'
         plot_sample_color='dark-magenta'
        point_type_samples='x'
        point_type_average='μ'

elif [ "$theme" = "light" ]; then # WIP - not finished

             terminal_type='ansirgb' # mono, ansi, ansi256, ansirgb
          label_host_color='red'
label_xlabel_samples_color='dark-salmon'
   label_ylabel_time_color='dark-salmon'
        label_jitter_color='dark-spring-green'
               xtics_color='sienna1'
               ytics_color='sienna1'
              border_color='goldenrod'
        plot_average_color='dark-cyan'
         plot_sample_color='dark-magenta'
        point_type_samples='x'
        point_type_average='μ'

fi

#### Configurable variables ###################################################

null_response_max=25         # If null_response_count reaches this value the script will abort.
null_response_decay_factor=2 # How much null_response_count will be reduced by
                             #  (after multiplying by 1) for each successfull ping that follows any ping failure.
update_interval=1            # Number of seconds between ping requests.
plot_history_max=60          # Maximum number of data points to show at a time.
ping_max_good=100            # Ping values above this value will be shown in red.
                             # Ping values between ping_max_good and ping_max_warn will be shown in yellow.
ping_max_warn=70             # Ping values below this value will be shown in green.

save_logs=0                  # What to do with temporary log files on exit (1=save to current working path)

###############################################################################

null_response_count=0
target_host=""
file_ping_time=""
file_avg_ping_time=""
ping_time_min=999999999999
ping_time_max=0
latest_ping_time=0
ping_time_last=0
ping_time_average=0
jitter_count=0
jitter_delta_count=0
jitter_abs_delta=0
jitter_abs_delta_sum=0
console_height=""
console_width=""
data_line=""
data_lines_count=0
flag_missing=0
debug_mode=0
debug_random_ping_max=150
debug_command_generation='s' # a=Awk, s=shuf

#### Functions ################################################################

TrapCNTRLC() {
    exit_status=$?
    printf '\033[0m'
    exit "$exit_status"
}

ExitTrap() {
    # Temporary file cleanup
    if [ -f "$file_ping_time" ] || [ -f "$file_avg_ping_time" ]; then
        # If debug mode is disabled
        if [ "$debug_mode" -eq 0 ]; then
            # If save logs is enabled
            if [ "$save_logs" -eq 1 ]; then
                # save the log files to the cwd
                 mv "$file_ping_time" "ping_${target_host}_$(date).log"
                 mv "$file_avg_ping_time" "avg_${target_host}_$(date).log"
            # If save logs is disabled
            elif [ "$save_logs" -eq 0 ]; then
                # remove the temporary files
                rm -f "$file_ping_time"
                rm -f "$file_avg_ping_time"
            fi
        # If debug is enabled
        elif [ "$debug_mode" -eq 1 ]; then
            # Report which temporary file were used
            printf '\n%s\n' "Ping log: $file_ping_time"
            printf '%s\n' "Average log: $file_avg_ping_time"
        fi
    fi
}

trap 'TrapCNTRLC' INT
trap 'ExitTrap' ABRT HUP EXIT

ShowHelp() {
    cat <<END_OF_HELP

    ${0##*/}

    -H                 - Show this help
    -h <host>          - Host name or IP recognized by ping
    -s <integer>       - Max samples to plot (default: $plot_history_max)
                           Max x-axis samples before clearing and starting over
                           Must be greater than or equal to 3
    -u <seconds>       - Plot update interval (default: $update_interval)
                           Values supported by sleep. Zero means as fast as possible.
    -m <mode>          - Gnuplot "dumb" terminal option (default: $terminal_type)
                           Accepted values: mono, ansi, ansi256, or ansirgb
                           For colors to work any mode except mono must be specified
    -F <integer>       - Maximum null/failed ping responses before aborting (0=disable this feature)
                           Successfull pings interspersed amongst failures will lower the abort counter
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
    exit 0
}

#### Parse command-line parameters and arguments ##############################

OPTERR=1
while getopts 'h:Hs:u:m:j:b:p:a:x:y:i:l:c:f:F:g:dz:r:' option
do
    case "$option" in
        ('H'|'?') ShowHelp ;;
        ('h') target_host=$OPTARG ;;
        ('s')
            # Set a minimum for the maximum number of data points to plot
            if [ "$OPTARG" -lt 3 ]; then
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
        ('F') null_response_max=$OPTARG ;;
        ('g') label_ylabel_time_color=$OPTARG ;;
        ('d')
            debug_mode=1
            target_host='DEBUG'
            label_host_color='red'
        ;;
        ('z')
            if [ "$OPTARG" -lt 2 ]; then
                debug_random_ping_max=2
            else
                debug_random_ping_max=$OPTARG
            fi
        ;;
        ('r')
            if [ "$OPTARG" = 's' ] || [ "$OPTARG" = 'a' ]; then
                debug_command_generation=$OPTARG
            else
                printf '%s\n' "Invalid choice for -r: $OPTARG (valid: 's' or 'a')"
                exit 1
            fi
        ;;
    esac
done

# required parameters
if [ -z "$target_host" ] && [ "$debug_mode" -eq 0 ]; then
    printf '%s\n' "${0##*/}: -h is a required parameter"
    ShowHelp
fi

###############################################################################

# check for required commands and report the status of all not found
while IFS= read -r result; do
    case $result in
        (*'not found'*)
            missing=${result%: *}
            missing=${missing##*: }
            printf '%s\n' "$missing is a required command"
            flag_missing=1
        ;;
    esac
done <<EOC
$(command -V gnuplot ping bc mktemp 2>&1)
EOC
[ "$flag_missing" -eq 1 ] && exit 1

# setup temporary files to hold ping results
file_ping_time=$(mktemp -q --tmpdir "${0##*/}.$$.tmp.XXXXXXXXXX")
file_avg_ping_time=$(mktemp -q --tmpdir "${0##*/}.$$.tmp.XXXXXXXXXX")

#### Main loop ################################################################

# All hope abandon, ye who enter here!
while :; do
    # If not in debug mode (normal run mode)
    if [ "$debug_mode" -eq 0 ]; then
        #shellcheck disable=SC2034
        # Read the results from ping into variables based on column position
        while IFS=' ' read -r -- f0 f1 f2 f3 f4 f5 f6 f7 f8; do
            case $f6 in
                (*'='*)
                    # Get the value after time= from the 7th column
                    if [ "${f6%=*}" = 'time' ]; then
                        latest_ping_time=${f6#*=}
                        break 1
                    else
                    # If columns are not how we expect, search the columns next to the one we expect
                    # Different implementations of ping result in different columns for results
                        if [ "${f5%=*}" = 'time' ]; then
                            latest_ping_time=${f5#*=}
                            break 1
                        elif [ "${f7%=*}" = 'time' ]; then
                            latest_ping_time=${f7#*=}
                            break 1
                        else
                            latest_ping_time=""
                            break 1
                        fi
                        # digit check (checking the data type if latest_ping_time is not empty)
                    fi
                ;;
            esac
# NOTE: Do not combine ping arguments (lowers compatibility)
        done <<EOC
$(ping -n -4 -c 1 "$target_host" 2>/dev/null)
EOC
    # If debug mode is enabled (test run)
    elif [ "$debug_mode" -eq 1 ]; then
        # Used for quickly testing "random" input values using Awk or shuf
        while [ "$latest_ping_time" = "$ping_time_last" ]; do
            if [ "$debug_command_generation" = 'a' ]; then
                latest_ping_time=$(awk -v min=0 -v max="$debug_random_ping_max" 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')
                latest_ping_time=${latest_ping_time}.${latest_ping_time}
            elif [ "$debug_command_generation" = 's' ]; then
                latest_ping_time=$(shuf -i 0-"$debug_random_ping_max" -n 1)
                latest_ping_time=${latest_ping_time}.${latest_ping_time}
            fi
        done
        ping_time_last=$latest_ping_time
    fi

    # avoid writing null to the data file
    [ -n "$latest_ping_time" ] && {
        # write the current ping time to a temporary data file
        printf '%s\n' "${latest_ping_time}" >> "${file_ping_time}"
        # update the data file line count
        data_lines_count=$(wc -l < "$file_ping_time")
    }

    # ensure we don't get stuck in an endless loop if a connection is dropped or an unreachable host is specified
    # number of consecutive NULL|zero responses from ping which will cause the script to abort
    # set null_response_max=0 or use the script parameter (-F 0) to disable this feature
    [ "$null_response_max" -ne 0 ] && {
        if [ "$(printf '%s\n' "$latest_ping_time > 0" | bc)" -eq 1 ]; then
            # Successfull pings will lower the abort counter
            [ "$null_response_count" -gt 0 ] && null_response_count=$((null_response_count-(1*null_response_decay_factor)))
        else
            null_response_count=$((null_response_count+1))
            [ "$null_response_count" -ge "$null_response_max" ] && {
                printf '%s\n' "Max NULL or Zero responses reached. Aborting."
                exit 1
            }
        fi
    }

    # calculate average ping on a rolling basis
    ping_time_average=0
    if [ "$data_lines_count" -gt 1 ]; then
        while read -r data_line; do
            # NOTE: scale= may be ignored for operations excluding division (bc)
            ping_time_average=$(printf '%s\n' "scale=4; $ping_time_average + $data_line" | bc -l)
        done < "$file_ping_time"
    elif [ "$data_lines_count" -eq 1 ]; then
        ping_time_average=$latest_ping_time
    fi

    # avoid dividing by zero
    if [ "$data_lines_count" -eq 0 ]; then
        ping_time_average=0
    else
        ping_time_average=$(printf '%s\n' "scale=4; $ping_time_average / $data_lines_count" | bc -l)
    fi

    # write the avg so far to a temporary file
    printf '%s\n' "$ping_time_average" >> "$file_avg_ping_time"

    # calculate jitter on a rolling basis
    [ -n "$latest_ping_time" ] && {

        # Alternate placing latest ping time into two seperate variables
        if [ $((data_lines_count%2)) -eq 0 ]; then
            jitter_sample_a=$latest_ping_time
        elif [ $((data_lines_count%2)) -eq 1 ]; then
            jitter_sample_b=$latest_ping_time
        fi
        jitter_count=$((jitter_count+1))

        [ "$jitter_count" -ge 2 ] && {
            jitter_abs_delta=$(printf '%s\n' "scale=4; $jitter_sample_a - $jitter_sample_b" | bc -l)
            jitter_abs_delta=${jitter_abs_delta#-}
            jitter_abs_delta_sum=$(printf '%s\n' "scale=4; $jitter_abs_delta_sum + $jitter_abs_delta" | bc -l)
            jitter_delta_count=$((jitter_delta_count+1))
        }

        [ "$jitter_delta_count" -ge 1 ] && {
            jitter_current=$(printf '%s\n' "scale=4; $jitter_abs_delta_sum / $jitter_delta_count" | bc -l)
        }
    }

    # max history reached, clear data files and start over
    [ "$data_lines_count" -gt "$plot_history_max" ] && {
        printf "" > "$file_ping_time"
        printf "" > "$file_avg_ping_time"
        continue
    }

    # If the current ping time is greater than the current ping time max it becomes the latest maximum
    [ "$(printf '%s\n' "$latest_ping_time > $ping_time_max" | bc)" -eq 1 ] && ping_time_max=$latest_ping_time

    # If the current ping time is less than the current ping min it becomes the latest minimum
    [ "$(printf '%s\n' "$latest_ping_time < $ping_time_min" | bc)" -eq 1 ] && ping_time_min=$latest_ping_time

    # Get the current screen character width and height for gnuplot
    if [ -z "$console_height" ] || [ -z "$console_width" ]; then
        console_dimensions=$(stty size)
        console_height=${console_dimensions% *}
        console_width=${console_dimensions#* }
    fi

    # Color the ping stats labels text based on quality thresholds set above
    # Latest ping time
    if [ "$(printf '%s\n' "$latest_ping_time >= $ping_max_good" | bc)" -eq 1 ]; then
        label_ping_current_color="red"
    elif [ "$(printf '%s\n' "$latest_ping_time >= $ping_max_warn && $latest_ping_time < $ping_max_good" | bc)" -eq 1 ]; then
        label_ping_current_color="yellow"
    else
        label_ping_current_color="green"
    fi

    # Latest ping time minimum
    if [ "$(printf '%s\n' "$ping_time_min >= $ping_max_good" | bc)" -eq 1 ]; then
        label_ping_min_color="red"
    elif [ "$(printf '%s\n' "$ping_time_min >= $ping_max_warn && $ping_time_min < $ping_max_good" | bc)" -eq 1 ]; then
        label_ping_min_color="yellow"
    else
        label_ping_min_color="green"
    fi

    # Latest ping time maximum
    if [ "$(printf '%s\n' "$ping_time_max >= $ping_max_good" | bc)" -eq 1 ]; then
        label_ping_max_color="red"
    elif [ "$(printf '%s\n' "$ping_time_max >= $ping_max_warn && $ping_time_max < $ping_max_good" | bc)" -eq 1 ]; then
        label_ping_max_color="yellow"
    else
        label_ping_max_color="green"
    fi

    # Latest ping time average
    if [ "$(printf '%s\n' "$ping_time_average >= $ping_max_good" | bc)" -eq 1 ]; then
        label_ping_avg_color="red"
    elif [ "$(printf '%s\n' "$ping_time_average >= $ping_max_warn && $ping_time_average < $ping_max_good" | bc)" -eq 1 ]; then
        label_ping_avg_color="yellow"
    else
        label_ping_avg_color="green"
    fi

    # Make the labels
    label_host=" $target_host "
    label_ping_min=" Minimum: $(printf '%1.3g' "$ping_time_min") "
    label_ping_max=" Maximum: $(printf '%1.3g' "$ping_time_max") "
    label_ping_avg=" Average: $(printf '%1.3g' "$ping_time_average") "
    label_ping_current=" Current: $(printf '%1.3g' "$latest_ping_time") "
    label_jitter=" Jitter: $(printf '%1.3g' "$jitter_current") "
    label_samples="${data_lines_count}/${plot_history_max} samples, ${update_interval}s interval"

    gnuplot -e "set term dumb $terminal_type size $console_width, $console_height; \
                set encoding utf8; set key off; set autoscale x; set autoscale y; \
                set x2label; set y2label; \
                set xlabel \"$label_samples\" norotate offset character 0,0 textcolor \"$label_xlabel_samples_color\"; \
                set ylabel \"Time\n(ms)\" norotate offset character 4,2 textcolor \"$label_ylabel_time_color\"; \
                set bmargin 3; set tmargin 3; set rmargin 1; \
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
