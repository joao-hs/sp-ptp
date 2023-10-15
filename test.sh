#!/bin/bash

ran_tests=1

start=$(date +%s.%N)
count=0
parallelCount=1
source .venv/bin/activate


if [ -z "$1" ]; then
    echo "Running all tests"
    for f in instances/*/*.in.json; do
        echo $(basename ${f/.in.json/})
        (echo "OUTPUT FOR TEST: $(basename ${f/.in.json/})------------------"
        python3 proj.py $f ${f/.in.json/.out.json}
        python3 jsonToDzn.py $f.mzn.json ${f/.in.json/.dzn}
        echo "TEST DONE ---------------------------------------------------") > ${f/.in.json/.out} &
        count=$((count+1))
        if [ $count == $parallelCount ]; then
            wait
            count=0
        fi
    done
    wait
elif [ $# == 1 ]; then
    if [ $1 == "easiest" ]; then
        echo "Running easiest tests"
        for f in instances/easiest/*.in.json; do
            (echo "OUTPUT FOR TEST: $(basename ${f/.in.json/})------------------"
            python3 proj.py $f ${f/.in.json/.out.json}
            python3 jsonToDzn.py $f.mzn.json ${f/.in.json/.dzn}
            echo "TEST DONE ---------------------------------------------------") > ${f/.in.json/.out} &
            count=$((count+1))
            if [ $count == $parallelCount ]; then
                wait
                count=0
            fi
        done
        wait
    elif [ $1 == "easy" ]; then
        echo "Running easy tests"
        for f in instances/easy/*.in.json; do
            (echo "OUTPUT FOR TEST: $(basename ${f/.in.json/})------------------"
            python3 proj.py $f ${f/.in.json/.out.json}
            python3 jsonToDzn.py $f.mzn.json ${f/.in.json/.dzn}
            echo "TEST DONE ---------------------------------------------------") > ${f/.in.json/.out} &
            count=$((count+1))
            if [ $count == $parallelCount ]; then
                wait
                count=0
            fi
        done
        wait
    elif [ $1 == "medium" ]; then
        echo "Running medium tests"
        for f in instances/medium/*.in.json; do
            (echo "OUTPUT FOR TEST: $(basename ${f/.in.json/})------------------"
            python3 proj.py $f ${f/.in.json/.out.json}
            python3 jsonToDzn.py $f.mzn.json ${f/.in.json/.dzn}
            echo "TEST DONE ---------------------------------------------------")  > ${f/.in.json/.out} &
            count=$((count+1))
            if [ $count == $parallelCount ]; then
                wait
                count=0
            fi
        done
        wait
    elif [ $1 == "hard" ]; then
        echo "Running hard tests"
        for f in instances/hard/*.in.json; do
            (echo "OUTPUT FOR TEST: $(basename ${f/.in.json/})------------------"
            python3 proj.py $f ${f/.in.json/.out.json}
            python3 jsonToDzn.py $f.mzn.json ${f/.in.json/.dzn}
            echo "TEST DONE ---------------------------------------------------")  > ${f/.in.json/.out} &
            count=$((count+1))
            if [ $count == $parallelCount ]; then
                wait
                count=0
            fi
        done
        wait
    elif [ $1 == "custom" ]; then
        echo "Running custom tests"
        for f in instances/custom/*.in.json; do
            (echo "OUTPUT FOR TEST: $(basename ${f/.in.json/})------------------"
            python3 proj.py $f ${f/.in.json/.out.json}
            python3 jsonToDzn.py $f.mzn.json ${f/.in.json/.dzn}
            echo "TEST DONE ---------------------------------------------------")  > ${f/.in.json/.out} &
            count=$((count+1))
            if [ $count == $parallelCount ]; then
                wait
                count=0
            fi
        done
        wait
    # elif $1.in.json is in instances subdirectories
    elif [ -f instances/*/$1.in.json ]; then
        (echo "OUTPUT FOR TEST: $1 -----------------------------------------"
        python3 proj.py instances/${1/_*/}/$1.in.json instances/${1/_*/}/$1.out.json
        python3 jsonToDzn.py instances/${1/_*/}/$1.in.json.mzn.json instances/${1/_*/}/$1.dzn
        echo "TEST DONE ---------------------------------------------------") > instances/${1/_*/}/$1.out
    else
        ran_tests=0
    fi
fi
if [ $ran_tests == 0 ]; then
    echo "Usage: ./test.sh [instance_group | short_instance_name]"
    echo " e.g.: ./test.sh easy"
    echo "       ./test.sh custom_toy_example"
    echo "       ./test.sh hard_1"
    echo "Available instance groups:"
    echo "  easy, medium, hard, custom"
    exit 1
else
    end=$(date +%s.%N)
    runtime=$(echo "$end - $start" | bc)
    echo "Done in $runtime seconds."
    exit 0
fi


