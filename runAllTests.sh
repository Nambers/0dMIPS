#!/bin/bash

set -e

TEST_DIR="build/bin"

for test in $TEST_DIR/*Test; do
    if [[ -x "$test" ]]; then
        ./"$test" || true
    fi
done
