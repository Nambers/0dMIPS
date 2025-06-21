#!/bin/bash

set -e

# TEST_DIR="build/bin"

# for test in $TEST_DIR/*Test; do
#     if [[ -x "$test" ]]; then
#         ./"$test" || true
#     fi
# done
echo "" > build/tests/memory.text.mem
echo "" > build/tests/memory.data.mem
GTEST_COLOR=1 ctest --test-dir build -V
