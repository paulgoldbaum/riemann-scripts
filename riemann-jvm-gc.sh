#!/bin/bash

if [ $# -lt 3 ]; then
    echo "Sends information about a running jvm's garbage collector to Riemann."
    echo "Each tick it sends the current utilization of each of the heap areas"
    echo "as service \"<service>-[survivor,eden,old]\" and the number and duration"
    echo "of garbage collections as \"<service>-[ygc,ygct,fgc,fgct,gct]\" as separate"
    echo "events"
    echo
    echo "Usage `basename $0` <pid> <freq> <service>"
    echo "  pid     : Pid of the jvm"
    echo "  freq    : Time between ticks in millisecs. Can end in 's' for seconds"
    echo "  service : Name of the service"
    echo
    echo "All additional arguments are forwarded to 'riemann-cli send'."
    echo "Please run 'riemann-cli help send' for more information"
    exit
fi

hash riemann-cli >/dev/null 2>&1 || { echo >&2 "riemann-cli could not be found in path. Aborting."; exit 1; }

pid=$1
freq=$2
service=$3
shift 3
first=true
jstat -gcutil $pid $freq | while read -r line
do
    if $first ; then
        if [ "${line// /}" != "S0S1EOPYGCYGCTFGCFGCTGCT" ]; then
            echo "Unsupported jstat output format"
            exit
        fi
        first=false
        continue
    fi
    read -a array <<< $line
    survivor=$(echo ${array[0]} + ${array[1]} | bc)

    riemann-cli send $@ --service $service"-survivor" --metric $survivor
    riemann-cli send $@ --service $service"-eden" --metric ${array[2]}
    riemann-cli send $@ --service $service"-old" --metric ${array[3]}
    riemann-cli send $@ --service $service"-permanent" --metric ${array[4]}
    riemann-cli send $@ --service $service"-ygc" --metric ${array[5]}
    riemann-cli send $@ --service $service"-ygct" --metric ${array[6]}
    riemann-cli send $@ --service $service"-fgc" --metric ${array[7]}
    riemann-cli send $@ --service $service"-fgct" --metric ${array[8]}
    riemann-cli send $@ --service $service"-gct" --metric ${array[9]}

done

riemann-cli send $@ --state "critical" --service $service --description "JVM pid $pid is down"
