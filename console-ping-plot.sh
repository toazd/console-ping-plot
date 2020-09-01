#!/bin/sh
#
# The only real answer is to drink way too much coffee and
# buy yourself a desk that doesn’t collapse when you beat your head against it
#

# Known bugs:
# BUG CONTROL-C escaping at just the right moment (while in a subshell in the main loop) can cause an error in some tests
# BUG Using CONTROL+C escaping this way masks the real return value of any previous command

set -e

#shellcheck disable=SC2039,SC2128
if [ -n "$BASH_VERSINFO" ]; then
    set -o posix >/dev/null
fi

sHOST=""
sDATAFILE_PING_TIME=""
sDATAFILE_AVG_PING_TIME=""
sTERM_TYPE="mono"
sLABEL_HOST_COLOR="royalblue"
sLABEL_XLABEL_SAMPLES_COLOR="dark-cyan"
sLABEL_YLABEL_TIME_COLOR="dark-cyan"
sPLOT_SAMPLE_COLOR="grey60"
sPLOT_AVERAGE_COLOR="dark-goldenrod"
sLABEL_JITTER_COLOR="orange"
sXTICS_COLOR="dark-goldenrod"
sYTICS_COLOR="dark-goldenrod"
sBORDER_COLOR="khaki"
sPOINT_TYPE_AVERAGE="μ"
sPOINT_TYPE_SAMPLES="x"
sPING_TIME_MIN=999999999999
sPING_TIME_MAX=0 # BUG if the route of a ping takes it near a blackhole it may become negative
iNULL_RESPONSE_MAX=10
iNULL_RESPONSE_COUNT=0
iUPDATE_INTERVAL=0.5
iPLOT_HISTORY_MAX=500
iPING_MAX_GOOD=100
iPING_MAX_WARN=70
sPING_TIME=0
sPING_TIME_LAST=0
sPING_TIME_AVG=0
iPLOT_Y_MIN=0
iPLOT_Y_MAX=0
iJITTER_COUNT=0
iJITTER_DELTA_COUNT=0
iJITTER_ABS_DELTA=0
iJITTER_ABS_DELTA_SUM=0
iDATA_LINES_COUNT=0
iDEBUG=0
iDEBUG_RANDOM_PING_MAX=150
sDEBUG_COMMAND_GENERATION="s"

# It's a trap!
# BUG doing this masks the real exit status
trap 'TrapCNTRLC' INT
trap 'ExitTrap' ABRT HUP EXIT

TrapCNTRLC() {
    printf "\033[0m" # prevent the terminal cursor from changing color if you exit at just the right moment in any color mode
    exit 0
}

ExitTrap() {
    if [ "$iDEBUG" -eq 0 ]; then
        [ -f "$sDATAFILE_PING_TIME" ] && rm -f "$sDATAFILE_PING_TIME"
        [ -f "$sDATAFILE_AVG_PING_TIME" ] && rm -f "$sDATAFILE_AVG_PING_TIME"
    elif [ "$iDEBUG" -eq 1 ]; then
        [ -f "$sDATAFILE_PING_TIME" ] && rm -vfi "$sDATAFILE_PING_TIME"
        [ -f "$sDATAFILE_AVG_PING_TIME" ] && rm -vfi "$sDATAFILE_AVG_PING_TIME"
    fi
    # So long, and thanks for all the fish
}

BeHelpful() {
    cat <<END_OF_HELP

  $(basename "$0" .sh)

    Requirements:      Gnuplot, ping, bc

    -h                 - Show this help
    -H <host>          - Host name or IP recognized by ping
    -s <integer>       - Max samples to plot (default: $iPLOT_HISTORY_MAX)
                           Max x-axis samples before clearing and starting over
                           Must be greater than or equal to 3
    -u <seconds>       - Plot update interval (default: $iUPDATE_INTERVAL)
                           Values supported by sleep. Zero means as fast as possible.
    -m <mode>          - Gnuplot "dumb" terminal option (default: $sTERM_TYPE)
                           Accepted values: mono, ansi, ansi256, or ansirgb
                           For colors to work any mode except mono must be specified
    -i <character>     - Pointtype used for sample/ping points plot (default: $sPOINT_TYPE_SAMPLES)
                           Only the first character will be used if multiple characters are supplied
    -l <character>     - Pointtype used for points in the average linespoints plot (default: $sPOINT_TYPE_AVERAGE)
                           Only the first character will be used if multiple characters are supplied
    -c <colorspec>     - Host label text color (default: $sLABEL_HOST_COLOR)
    -j <colorspec>     - Jitter label text color (default: $sLABEL_JITTER_COLOR)
    -f <colorspec>     - X-axis label text color (default: $sLABEL_XLABEL_SAMPLES_COLOR)
    -g <colorspec>     - Y-axis label label text color (default: $sLABEL_YLABEL_TIME_COLOR)
    -b <colorspec>     - Border color (default: $sBORDER_COLOR)
                           Color of the border including the x-axis and y-axis surrounding the plot
                           Must be a valid color recognized by gnuplot
    -p <colorspec>     - Points plot (sample/ping) color (default: $sPLOT_SAMPLE_COLOR)
                           Color of the points that plot each sample/ping
    -a <colorspec>     - Linespoints plot (average) color (default: $sPLOT_AVERAGE_COLOR)
                           Color of the lines and points that plot average (ping)
    -x <colorspec>     - Xtics color (default: $sXTICS_COLOR)
                           Color of the major labeled tics on the x-axis
    -y <colorspec>     - Ytics color (default: $sYTICS_COLOR)
                           Color of the major labeled tics on the y-axis
    -d                 - Enable Debug mode (default: off)
                           Disables ping and instead ping time values are random generated values
                           You will be asked to remove temporary data files on script exit instead of silent removal
                           The -H parameter is not required in this mode
    -z <integer>       - When in debug mode, specifies the maximum integer used for random ping time generation
                           The minimum is always 0 (default: $iDEBUG_RANDOM_PING_MAX)
    -r <character>     - When in debug mode, use either (a)wk or (s)huf for random number generation
                           (default: $sDEBUG_COMMAND_GENERATION)

END_OF_HELP
    exit 0
}

OPTERR=1
# TODO easter egg option
while getopts 'hH:s:u:m:j:b:p:a:x:y:i:l:c:f:g:dz:r:' sOPT; do
    case "$sOPT" in
        ("h"|"?") BeHelpful ;;
        ("H") sHOST=$OPTARG ;;
        ("s") if [ "$OPTARG" -lt 3 ]; then iPLOT_HISTORY_MAX=3; else iPLOT_HISTORY_MAX=$OPTARG; fi ;;
        ("u") iUPDATE_INTERVAL=$OPTARG ;;
        ("m") sTERM_TYPE=$OPTARG ;;
        ("c") sLABEL_HOST_COLOR=$OPTARG ;;
        ("j") sLABEL_JITTER_COLOR=$OPTARG ;;
        ("b") sBORDER_COLOR=$OPTARG ;;
        ("p") sPLOT_SAMPLE_COLOR=$OPTARG ;;
        ("a") sPLOT_AVERAGE_COLOR=$OPTARG ;;
        ("x") sXTICS_COLOR=$OPTARG ;;
        ("y") sYTICS_COLOR=$OPTARG ;;
        ("i") sPOINT_TYPE_SAMPLES=$OPTARG ;;
        ("l") sPOINT_TYPE_AVERAGE=$OPTARG ;;
        ("f") sLABEL_XLABEL_SAMPLES_COLOR=$OPTARG ;;
        ("g") sLABEL_YLABEL_TIME_COLOR=$OPTARG ;;
        ("d") iDEBUG=1; sHOST="DEBUG"; sLABEL_HOST_COLOR="red" ;;
        ("z") if [ "$OPTARG" -lt 2 ]; then iDEBUG_RANDOM_PING_MAX=2; else iDEBUG_RANDOM_PING_MAX=$OPTARG; fi ;;
        ("r") if [ "$OPTARG" = "s" ] || [ "$OPTARG" = "a" ]; then sDEBUG_COMMAND_GENERATION=$OPTARG; else exit 1; fi ;;
        (":") exit 1 ;; # Behelpful?
    esac
done

# required parameters
if [ -z "$sHOST" ] && [ "$iDEBUG" -eq 0 ]; then
    echo "-H is a required parameter"
    BeHelpful
fi

# required debug commands
if [ "$sDEBUG_COMMAND_GENERATION" = "s" ] && [ "$iDEBUG" -eq 1 ]; then
    if ! command -v shuf >/dev/null; then
        echo "shuf not found"
        exit 1
    fi
fi

if [ "$sDEBUG_COMMAND_GENERATION" = "a" ] && [ "$iDEBUG" -eq 1 ]; then
    if ! command -v awk >/dev/null; then
        echo "awk not found"
        exit 1
    fi
fi

# required commands
if ! command -v gnuplot >/dev/null; then
    echo "gnuplot is a required command"
    exit 1
fi

if ! command -v ping >/dev/null; then
    echo "ping is a required command"
    exit 1
fi

if ! command -v shuf >/dev/null; then
    echo "bc is a required command"
    exit 1
fi

# setup temporary data files
sDATAFILE_PING_TIME="$(mktemp -q --tmpdir "$(basename "$0" .sh)".$$.tmp.XXXXXXXXXX)"
sDATAFILE_AVG_PING_TIME="$(mktemp -q --tmpdir "$(basename "$0" .sh)".$$.tmp.XXXXXXXXXX)"
echo "hello"
# All hope abandon, ye who enter here!
while :; do
    # If not in debug mode
    if [ "$iDEBUG" -eq 0 ]; then
        #shellcheck disable=SC2034
        while IFS=' ' read -r -- f0 f1 f2 f3 f4 f5 f6 f7 f8; do
            case $f6 in
                (*'='*)
                    # time=100
                    if [ "${f6%=*}" = 'time' ]; then
                        sPING_TIME=${f6#*=}
                        break 1
                    else
                        sPING_TIME=''
                    fi
                ;;
            esac
        done <<EOC
$(ping -nc1 "$sHOST")
EOC
        #sPING_TIME=$(ping -nc1 "$sHOST" | awk 'NR==2 {print substr($7,6)}')
    elif [ "$iDEBUG" -eq 1 ]; then
        # Used for quickly testing "random" input values
        while [ "$sPING_TIME" = "$sPING_TIME_LAST" ]; do
            if [ "$sDEBUG_COMMAND_GENERATION" = "a" ]; then
                sPING_TIME=$(awk -v min=0 -v max="$iDEBUG_RANDOM_PING_MAX" 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')
            elif [ "$sDEBUG_COMMAND_GENERATION" = "s" ]; then
                sPING_TIME=$(shuf -i 0-"$iDEBUG_RANDOM_PING_MAX" -n 1)
            else
                exit 1
            fi
        done
        sPING_TIME_LAST=$sPING_TIME
    fi

    # avoid writing null to the data file
    if [ -n "$sPING_TIME" ]; then
        # write the current ping time to a temporary data file
        printf "%s\n" "${sPING_TIME}" >> "${sDATAFILE_PING_TIME}"
        # update the data file line count
        iDATA_LINES_COUNT=$(wc -l < "$sDATAFILE_PING_TIME")
    fi

    # ensure we don't get stuck in an endless, frivolous loop if a connection is dropped or an unreachable host is specified
    # number of consecutive NULL|zero responses from ping which will cause the script to abort
    # NOTE interspersed successful pings > @(NULL|0) will reduce the count so a bad connection can still be plotted
    # NOTE iNULL_RESPONSE_MAX might need tweaking
    # TODO update variable names to indicate that a zero response in addition to NULL will trigger this
    if [ "$(printf "%s\n" "$sPING_TIME > 0" | bc -l)" -eq 1 ]; then
        [ "$iNULL_RESPONSE_COUNT" -gt 0 ] && iNULL_RESPONSE_COUNT=$(( iNULL_RESPONSE_COUNT - 1 ))
    else
        iNULL_RESPONSE_COUNT=$(( iNULL_RESPONSE_COUNT + 1 ))
        [ "$iNULL_RESPONSE_COUNT" -ge "$iNULL_RESPONSE_MAX" ] && { echo "Max NULL or Zero responses reached. Aborting."; exit 1; }
    fi

    # calculate average ping on a rolling basis
    # TODO find a POSIX way to avoid re-reading the entire file each loop (must be more efficient). good luck with that.
    sPING_TIME_AVG=0
    if [ "$iDATA_LINES_COUNT" -gt 1 ]; then
        while read -r; do
            sPING_TIME_AVG="$(printf "%s\n" "scale=4; $sPING_TIME_AVG + $REPLY" | bc -l)"
        done < "$sDATAFILE_PING_TIME"
    elif [ "$iDATA_LINES_COUNT" -eq 1 ]; then
        sPING_TIME_AVG=$sPING_TIME
    fi

    # avoid dividing by zero
    if [ "$iDATA_LINES_COUNT" -eq 0 ]; then
        sPING_TIME_AVG=0
    else
        sPING_TIME_AVG=$(printf "%s\n" "scale=4; $sPING_TIME_AVG / $iDATA_LINES_COUNT" | bc -l)
    fi

    # write the avg so far to a temporary file
    printf "%s\n" "$sPING_TIME_AVG" >> "$sDATAFILE_AVG_PING_TIME"

    # calculate jitter on a rolling basis
    if [ -n "$sPING_TIME" ]; then
        if [ $(( iDATA_LINES_COUNT % 2 )) -eq 0 ]; then
            iJITTER_SAMPLE_A=$sPING_TIME
        elif [ $(( iDATA_LINES_COUNT % 2 )) -eq 1 ]; then
            iJITTER_SAMPLE_B=$sPING_TIME
        fi
        iJITTER_COUNT=$(( iJITTER_COUNT + 1 ))

        if [ "$iJITTER_COUNT" -ge 2 ]; then
            iJITTER_ABS_DELTA="$(printf "%s\n" "scale=4; $iJITTER_SAMPLE_A - $iJITTER_SAMPLE_B" | bc -l)"
            iJITTER_ABS_DELTA=${iJITTER_ABS_DELTA#-}
            iJITTER_ABS_DELTA_SUM="$(printf "%s\n" "scale=4; $iJITTER_ABS_DELTA_SUM + $iJITTER_ABS_DELTA" | bc -l)"
            iJITTER_DELTA_COUNT=$(( iJITTER_DELTA_COUNT + 1 ))
        fi

        if [ "$iJITTER_DELTA_COUNT" -ge 1 ]; then
            iJITTER="$(printf "%s\n" "scale=4; $iJITTER_ABS_DELTA_SUM / $iJITTER_DELTA_COUNT" | bc -l)"
        fi

        # DEBUG only
        #[ "$iJITTER_DELTA_COUNT" -ge 1 ] && printf "%s\n" "$iJITTER" >> jitter.out
    fi

    # max history reached, clear data files and start over
    # TODO find a better way
    if [ "$iDATA_LINES_COUNT" -gt "$iPLOT_HISTORY_MAX" ]; then
        printf "" > "$sDATAFILE_PING_TIME"
        printf "" > "$sDATAFILE_AVG_PING_TIME"
        continue
    fi

    # If the current ping time is greater than the current ping time max it becomes the latest maximum
    [ "$(printf "%s\n" "$sPING_TIME > $sPING_TIME_MAX" | bc -l)" -eq 1 ] && sPING_TIME_MAX=$sPING_TIME

    # If the current ping time is less than the current ping min it becomes the latest minimum
    [ "$(printf "%s\n" "$sPING_TIME < $sPING_TIME_MIN" | bc -l)" -eq 1 ] && sPING_TIME_MIN=$sPING_TIME

    # Adjust the yrange based on the max and min centered around the avg
    # For whatever reason, gnuplot has trouble autosizing to include all plot values
    # and centering the graph at the average plot even when using a graph offset
    if [ "$(printf "%s\n" "$sPING_TIME_AVG > 0" | bc -l)" -eq 1  ]; then
        iPLOT_Y_MAX="$(printf "%s\n" "scale=4; ($sPING_TIME_MAX + ($sPING_TIME_AVG / 10))" | bc -l)"
        iPLOT_Y_MIN="$(printf "%s\n" "scale=4; ($sPING_TIME_MIN - ($sPING_TIME_AVG / 10))" | bc -l)"
    fi

    # Get the current screen character width and height for gnuplot
    sCONSOLE_DIMENSIONS=$(stty size)
    iCONSOLE_HEIGHT=${sCONSOLE_DIMENSIONS% *}
    iCONSOLE_WIDTH=${sCONSOLE_DIMENSIONS#* }

    # Color the ping stats labels text based on quality thresholds set above
    # Unfortunately, multi-colored text on a single label is not supported by gnuplot
    # so it's either this way or add more labels
    # Latest ping time
    if [ "$(printf "%s\n" "$sPING_TIME >= $iPING_MAX_GOOD" | bc -l)" -eq 1 ]; then
        sLABEL_PING_CURR_COLOR="red"
    elif [ "$(printf "%s\n" "$sPING_TIME >= $iPING_MAX_WARN && $sPING_TIME < $iPING_MAX_GOOD" | bc -l)" -eq 1 ]; then
        sLABEL_PING_CURR_COLOR="yellow"
    else
        sLABEL_PING_CURR_COLOR="green"
    fi

    # Latest ping time minimum
    if [ "$(printf "%s\n" "$sPING_TIME_MIN >= $iPING_MAX_GOOD" | bc -l)" -eq 1 ]; then
        sLABEL_PING_MIN_COLOR="red"
    elif [ "$(printf "%s\n" "$sPING_TIME_MIN >= $iPING_MAX_WARN && $sPING_TIME_MIN < $iPING_MAX_GOOD" | bc -l)" -eq 1 ]; then
        sLABEL_PING_MIN_COLOR="yellow"
    else
        sLABEL_PING_MIN_COLOR="green"
    fi

    # Latest ping time maximum
    if [ "$(printf "%s\n" "$sPING_TIME_MAX >= $iPING_MAX_GOOD" | bc -l)" -eq 1 ]; then
        sLABEL_PING_MAX_COLOR="red"
    elif [ "$(printf "%s\n" "$sPING_TIME_MAX >= $iPING_MAX_WARN && $sPING_TIME_MAX < $iPING_MAX_GOOD" | bc -l)" -eq 1 ]; then
        sLABEL_PING_MAX_COLOR="yellow"
    else
        sLABEL_PING_MAX_COLOR="green"
    fi

    # Latest ping time average
    if [ "$(printf "%s\n" "$sPING_TIME_AVG >= $iPING_MAX_GOOD" | bc -l)" -eq 1 ]; then
        sLABEL_PING_AVG_COLOR="red"
    elif [ "$(printf "%s\n" "$sPING_TIME_AVG >= $iPING_MAX_WARN && $sPING_TIME_AVG < $iPING_MAX_GOOD" | bc -l)" -eq 1 ]; then
        sLABEL_PING_AVG_COLOR="yellow"
    else
        sLABEL_PING_AVG_COLOR="green"
    fi

    # Concatenate the text and variables for the labels
    sLABEL_HOST=" $sHOST "
    sLABEL_PING_MIN=" Minimum: $(printf "%1.3g" "$sPING_TIME_MIN") "
    sLABEL_PING_MAX=" Maximum: $(printf "%1.3g" "$sPING_TIME_MAX") "
    sLABEL_PING_AVG=" Average: $(printf "%1.3g" "$sPING_TIME_AVG") "
    sLABEL_PING_CURR=" Current: $(printf "%1.3g" "$sPING_TIME") "
    sLABEL_JITTER=" Jitter: $(printf "%1.3g" "$iJITTER") "
    sLABEL_SAMPLES="${iDATA_LINES_COUNT}/${iPLOT_HISTORY_MAX} samples, ${iUPDATE_INTERVAL}s interval"

    # avoid errors with gnuplot when there is no y-axis coordinate to plot
    # TODO test if this is even needed anymore
    [ "$(printf "%s\n" "$iPLOT_Y_MIN >= $iPLOT_Y_MAX" | bc -l)" -eq 1 ] && continue

    # DEBUG labels
    #set label \"DEBUG - DeltaSum: $iJITTER_ABS_DELTA_SUM JitDeltaCnt: $iJITTER_DELTA_COUNT JitCnt: $iJITTER_COUNT SmpA: $iJITTER_SAMPLE_A SmpB: $iJITTER_SAMPLE_B AbsDelta: $iJITTER_ABS_DELTA\" at graph 0.5,0.05 center front nopoint textcolor \"red\"; \
    # set label \"($iPLOT_Y_MIN $iPLOT_Y_MAX)\" at graph 0.5,0.3 center front nopoint textcolor \"red\"; \

    gnuplot -e "set terminal dumb noenhanced $sTERM_TYPE size $iCONSOLE_WIDTH, $iCONSOLE_HEIGHT; \
                set encoding utf8; set key off; set autoscale x; \
                set x2label; set y2label; \

                set yrange [$iPLOT_Y_MIN:$iPLOT_Y_MAX]; \

                set xlabel \"$sLABEL_SAMPLES\" norotate offset character 0,0 textcolor \"$sLABEL_XLABEL_SAMPLES_COLOR\"; \
                set ylabel \"Time\n(ms)\" norotate offset character 4,3 textcolor \"$sLABEL_YLABEL_TIME_COLOR\"; \

                set bmargin 3; set tmargin 1; set rmargin 1; \
                set border front linestyle 1 linecolor \"${sBORDER_COLOR}\"; \

                set xtics mirror border in autojustify scale default textcolor \"$sXTICS_COLOR\"; \
                set ytics mirror border in autojustify scale default textcolor \"$sYTICS_COLOR\"; \

                set label \"$sLABEL_HOST\" at graph 0.5,0.01 center front nopoint textcolor \"$sLABEL_HOST_COLOR\"; \

                set label \"$sLABEL_PING_MIN\" at graph 0.25,1 center front nopoint textcolor \"$sLABEL_PING_MIN_COLOR\"; \
                set label \"$sLABEL_PING_MAX\" at graph 0.37,1 center front nopoint textcolor \"$sLABEL_PING_MAX_COLOR\"; \
                set label \"$sLABEL_PING_AVG\" at graph 0.49,1 center front nopoint textcolor \"$sLABEL_PING_AVG_COLOR\"; \
                set label \"$sLABEL_PING_CURR\" at graph 0.61,1 center front nopoint textcolor \"$sLABEL_PING_CURR_COLOR\"; \
                set label \"$sLABEL_JITTER\" at graph 0.73,1 center front nopoint textcolor \"$sLABEL_JITTER_COLOR\"; \

                set datafile separator \"\n\"; \
                set datafile commentschars \"#\"; \
                plot \"$sDATAFILE_AVG_PING_TIME\" with linespoints pointtype \"$sPOINT_TYPE_AVERAGE\" linecolor \"$sPLOT_AVERAGE_COLOR\", \
                     \"$sDATAFILE_PING_TIME\" with points pointtype \"$sPOINT_TYPE_SAMPLES\" linecolor \"$sPLOT_SAMPLE_COLOR\""
    sleep "$iUPDATE_INTERVAL"s
done
