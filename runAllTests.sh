#!/bin/bash

set -e

# placeholder file
echo "" > build/tests/memory.mem
GTEST_COLOR=1 ctest --test-dir build -V

if [ -n "$DUMP_COV" ]; then
    echo "Dumping coverage data..."
    verilator_coverage --write-info coverage.info build/tests/logs/*.dat
    if command -v genhtml &>/dev/null; then
        genhtml --output-dir coverage_html coverage.info
    fi
fi
