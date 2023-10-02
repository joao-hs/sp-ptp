#!/bin/bash

ran_tests=1

if [ -z "$1" ]; then
    echo "Running all tests"
    for f in instances/*/*.in.json; do
        echo "OUTPUT FOR TEST: $(basename ${f/.in.json/})------------------"
        python proj.py $f ${f/.in.json/.out.json}
        echo "TEST DONE ---------------------------------------------------"
    done
elif [ $# == 1 ]; then
    if [ $1 == "easy" ]; then
        echo "Running easy tests"
        for f in instances/easy/*.in.json; do
            echo "OUTPUT FOR TEST: $(basename ${f/.in.json/})------------------"
            python proj.py $f ${f/.in.json/.out.json}
            echo "TEST DONE ---------------------------------------------------"
        done
    elif [ $1 == "medium" ]; then
        echo "Running medium tests"
        for f in instances/medium/*.in.json; do
            echo "OUTPUT FOR TEST: $(basename ${f/.in.json/})------------------"
            python proj.py $f ${f/.in.json/.out.json}
            echo "TEST DONE ---------------------------------------------------"
        done
    elif [ $1 == "hard" ]; then
        echo "Running hard tests"
        for f in instances/hard/*.in.json; do
            echo "OUTPUT FOR TEST: $(basename ${f/.in.json/})------------------"
            python proj.py $f ${f/.in.json/.out.json}
            echo "TEST DONE ---------------------------------------------------"
        done
    elif [ $1 == "custom" ]; then
        echo "Running custom tests"
        for f in instances/custom/*.in.json; do
            echo "OUTPUT FOR TEST: $(basename ${f/.in.json/})------------------"
            python proj.py $f ${f/.in.json/.out.json}
            echo "TEST DONE ---------------------------------------------------"
        done
    # elif $1.in.json is in instances subdirectories
    elif [ -f instances/*/$1.in.json ]; then
        echo "OUTPUT FOR TEST: $(basename ${f/.in.json/})------------------"
        echo proj.py instances/${1/_*/}/$1.in.json instances/${1/_*/}/$1.out.json
        echo "TEST DONE ---------------------------------------------------"
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
    echo "Done"
    exit 0
fi


