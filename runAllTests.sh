#!/bin/bash

set -e

# placeholder file
echo "" > build/tests/memory.mem
GTEST_COLOR=1 ctest --test-dir build -V
