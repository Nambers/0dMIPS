#!/bin/bash

set -e

# placeholder file
echo "" > build/tests/memory.mem
GTEST_COLOR=1 ctest --test-dir build -V

if [ -n "$DUMP_COV" ]; then
    echo "Dumping coverage data..."
    mapfile -t coverage_logs < <(find ./build/tests/logs -type f -name "*.dat" -print)
    if [ "${#coverage_logs[@]}" -eq 0 ]; then
        echo "No Verilator coverage logs found under ./build/tests/logs" >&2
        exit 1
    fi
    verilator_coverage --write-info coverage.info "${coverage_logs[@]}"
fi
