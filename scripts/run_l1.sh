#!/usr/bin/env bash
# Build and run every level 1 testbench. A test passes only if it prints "TEST PASSED".
#   testbench/level1_tb/<name>_tb.sv   SystemVerilog testbench, run with Icarus
#   testbench/level1_tb/<name>_tb.cpp  C++ testbench for module <name>, run with Verilator
# Empty testbench files are skipped.
set -u

src=(src/*.sv)
inc=testbench/common
out=build/l1
mkdir -p "$out"

passed=0 failed=0 skipped=0
for tb in testbench/level1_tb/*_tb.sv testbench/level1_tb/*_tb.cpp; do
    [ -e "$tb" ] || continue
    file=$(basename "$tb")
    name=${file%.*}
    if [ ! -s "$tb" ]; then
        echo "SKIP $file (empty)"
        skipped=$((skipped + 1))
        continue
    fi

    log=$out/$file.log
    case $tb in
        *.sv)
            iverilog -g2012 -I "$inc" -s "$name" -o "$out/$name.vvp" "$tb" "${src[@]}" > "$log" 2>&1 &&
                timeout 60 vvp -n "$out/$name.vvp" >> "$log" 2>&1
            ;;
        *.cpp)
            verilator --cc --exe --build -Wno-fatal --top-module "${name%_tb}" -Mdir "$out/$name" \
                -CFLAGS "-I$PWD/$inc" -o "$name" "${src[@]}" "$PWD/$tb" > "$log" 2>&1 &&
                timeout 60 "$out/$name/$name" >> "$log" 2>&1
            ;;
    esac

    if grep -q "^TEST PASSED" "$log" && ! grep -q "TEST FAILED" "$log"; then
        echo "PASS $file"
        passed=$((passed + 1))
    else
        echo "FAIL $file (see $log)"
        failed=$((failed + 1))
    fi
done

echo "level 1: $passed passed, $failed failed, $skipped skipped"
[ "$failed" -eq 0 ]
