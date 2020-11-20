#!/usr/bin/env bash

## arg 1: file to open
## arg 2: Executable
## arg 3: Title
## arg 4: icon
## arg 5: module to load

M=$(module -t -r --redirect avail | rg '^[[:alpha:]].*[[:alnum:]]$')
declare -A MODS
MODS[all]=$(echo $M | sed 's/ /!/g')
MODS[julia]=$(echo $(echo $M | sed 's/ /\n/g' | sort -r | rg -i '^julia') | sed 's/ /!/g')
MODS[mathematica]=$(echo $(echo $M | sed 's/ /\n/g' | sort -r | rg -i '^mathematica') | sed 's/ /!/g')
MODS[matlab]=$(echo $(echo $M | sed 's/ /\n/g' | sort -r | rg -i '^matlab') | sed 's/ /!/g')
MODS[octave]=$(echo $(echo $M | sed 's/ /\n/g' | sort -r | rg -i '^octave') | sed 's/ /!/g')
MODS[python]=$(echo $(echo $M | sed 's/ /\n/g' | sort -r | rg -i '^anaconda|^python') | sed 's/ /!/g')
MODS[r]=$(echo $(echo $M | sed 's/ /\n/g' | sort -r | rg -i '^r/') | sed 's/ /!/g')
MODS[stata]=$(echo $(echo $M | sed 's/ /\n/g' | sort -r | rg -i stata) | sed 's/ /!/g')
MODS[standared]="conda_system_base"

Y=$(yad --window-icon=$4 --image=$4 --title="Run ${3}" --center --bool-fmt=1
    --text="Select settings for this ${3} job." --form --align=right
    --field='Memory (in GB, max 1000)!<span>Memory is a shared resource, <b>request only what you need</b>.</span>:NUM' '10!10..1000'
    --field='CPUs (max 12)!<span>CPUs are a shared resource, <b>request only what you need</b>.</span>:NUM' '1!1..12'
    --field=$"$3 version:CB" "${MODS[$5]}"
    --field=$"Additional modules to load:CE" '!'"${MODS[all]}"
    --field=$"Starting directory:DIR" "${dir11:-$HOME}"
    --field=$"Job run time > 24 hours (max 72):CHK" ${long:-false}
    --field=$"Needs GPU:CHK" 'false'
    --field=$"Pre-submission command:" ''
    --button="Help!system-help!Click to read documentation:yelp /tmp/gridpowered/share/help/C/HBS_Grid_experimental/menulaunch.page"
    --button='yad-cancel' --button='yad-ok')

if [ "$Y" ]
then
    MEM=$(echo $Y | cut -d'|' -f1)
    CPU=$(echo $Y | cut -d'|' -f2); CPUORIG=$(echo $Y | cut -d'|' -f2)
    MOD=$(echo $Y | cut -d'|' -f3)
    ADDMOD=$(echo $Y | cut -d'|' -f4)    
    DIR="$(echo $Y | cut -d'|' -f5)"
    LONG=$(echo $Y | cut -d'|' -f6)
    GPU=$(echo $Y | cut -d'|' -f7)
    PRESUB="$(echo $Y | cut -d'|' -f8)"
    CONT=0
    if (( $MEM > 80 ))
    then
        /tmp/gridpowered/bin/grid_large_request.sh $MEM
        CONT=$?
    fi
    (( CONT == 1 )) && exit
    export OMP_NUM_THREADS=$CPU
    Q="short_int long_int"
    if [ $LONG = 1 ]
    then
        Q="long_int"
        [[ $CPU -ge 4 ]] && CPU=4
    fi
    if [ $GPU = 1 ]
    then
        Q="gpu -gpu -"
        [[ $CPU -ge 4 ]] && CPU=4
    fi
    TMP=$(mktemp)
    CONT=0
    (( CPU == CPUORIG )) || yad --center --skip-taskbar
    
    
    --text="<span>You requested $CPUORIG CPUS but only $CPU are available in this configuration. 

Click <b>Cancel</b> to abort, or <b>OK</b> to continue with $CPU CPUs.</span>"
    CONT=$?
    (( CONT == 0 )) || exit
    [[ -f "$1" ]] && DIR=$(dirname "$1")
    cd "$DIR"
    CMD="source /tmp/gridpowered/bin/grid_fixup.sh; ulimit -Sv $(($MEM * 1020**2)); ml-en-l conda_system-base $ADDMOD $MOD; eval \"$PRESUB\"; exec $2"
    [[ -f "$1" ]] && CMD=$CMD" \"$1\""
    bsub -q "$Q" -Ip
    -cwd "$DIR"
    -M ${MEM}G
    -n ${CPU}
    bash -norc -c "$CMD" &> $TMP &
    sleep 20
    JOB=$(grep "Job .* is submitted" $TMP | cut -d '<' -f2 | cut -d '>' -f1)
    if [[ ! $(grep "<<Starting on" $TMP) ]]
    then
        /tmp/gridpowered/bin/grid_submission_stalled.sh $JOB $CPU
        CONT=$?
    fi
    (( CONT == 1 )) && bkill $JOB
fi
rm -f $TMP
exit

