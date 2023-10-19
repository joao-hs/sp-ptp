#!/bin/bash

ran_tests=1

start=$(date +%s.%N)
count=0
parallelCount=3
source .venv/bin/activate

function run_test () {
    echo "Started $(basename ${1/.in.json/})"
    (echo "OUTPUT FOR TEST: $(basename ${1/.in.json/})------------------"
    startSingle=$(date +%s.%N)
    timeout 70 python3 proj.py $1 ${1/.in.json/.out.json}
    endSingle=$(date +%s.%N)
    runtimeSingle=$(echo "$endSingle - $startSingle" | bc)
    python3 jsonToDzn.py $1.mzn.json ${1/.in.json/.dzn}
    echo "TEST DONE ----------------------------------------------------"
    echo "Completed in $runtimeSingle seconds.") > ${1/.in.json/.out}
    echo "Ended $(basename ${1/.in.json})"
}


if [ -z "$1" ]; then
    echo "Running all tests"
    for f in instances/*/*.in.json; do
        run_test $f &
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
            run_test $f &
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
            run_test $f &
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
            run_test $f &
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
            run_test $f &
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
            run_test $f &
            count=$((count+1))
            if [ $count == $parallelCount ]; then
                wait
                count=0
            fi
        done
        wait
    # elif $1.in.json is in instances subdirectories
    elif [ -f instances/*/$1.in.json ]; then
        run_test "instances/*/$1.in.json"
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
    echo "All tests completed in $runtime seconds."
    results_file=reports/"$(date +%F_%X)"
    echo "Check overall results in $results_file.out"
    for f in instances/*/*.out; do
        (
        echo "Results for $(basename ${f/.out/}):"
        if grep -q grantedRequests $f; then
            echo "  $(grep result.status $f)"
            echo "  $(grep grantedRequests $f)"
            echo "    $(grep noRequests ${f/.out/.dzn})"
            echo "    $(grep noOriginalVehicles ${f/.out/.dzn})"
            echo "    $(grep noCategories ${f/.out/.dzn})"
            echo "  $(grep seconds $f)"
        else
            echo "  $(grep result.status $f)"
            echo "  TIMEOUT"
            echo "    $(grep noRequests ${f/.out/.dzn})"
            echo "    $(grep noOriginalVehicles ${f/.out/.dzn})"
            echo "    $(grep noCategories ${f/.out/.dzn})"
        fi
        echo ""
        ) >> $results_file.out
        
    done
    exit 0
fi

