#!/usr/bin/env bash
# build and run every level 1 testbench, requiring successful commands and a pass marker
#   testbench/level1_tb/<name>_tb.sv   SystemVerilog testbench, run with Icarus
#   testbench/level1_tb/<name>_tb.cpp  C++ testbench for module <name>, run with Verilator
# empty testbench files are skipped
set -u

src=(src/*.sv)
inc=testbench/common
out=build/l1
mkdir -p "$out"

# image diagnostics can be nonfatal; excess-digit warnings omit the readmem task name
image_diagnostic='(error|fatal|warning).*([$]readmem([hb])?([[:space:][:punct:]]|$)|excess (hex|binary) digits.*while reading)'

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
    # compile failure skips execution; retain each command chain's status immediately
    case $tb in
        *.sv)
            iverilog -g2012 -I "$inc" -s "$name" -o "$out/$name.vvp" "$tb" "${src[@]}" > "$log" 2>&1 &&
                timeout 60 vvp -n "$out/$name.vvp" +wave="$out/$file.vcd" >> "$log" 2>&1
            command_status=$?
            ;;
        *.cpp)
            verilator --cc --exe --build --trace -Wno-fatal --top-module "${name%_tb}" -Mdir "$out/$name" \
                -CFLAGS "-I$PWD/$inc" -o "$name" "${src[@]}" "$PWD/$tb" > "$log" 2>&1 &&
                timeout 60 "$out/$name/$name" +wave="$out/$file.vcd" >> "$log" 2>&1
            command_status=$?
            ;;
    esac

    # a pass marker cannot override failed commands or memory image diagnostics
    if [ "$command_status" -eq 0 ] &&
       grep -q "^TEST PASSED" "$log" &&
       ! grep -q "TEST FAILED" "$log" &&
       ! grep -Eiq "$image_diagnostic" "$log"; then
        echo "PASS $file"
        passed=$((passed + 1))
    else
        echo "FAIL $file (see $log)"
        failed=$((failed + 1))
    fi
done

echo "level 1: $passed passed, $failed failed, $skipped skipped"
[ "$failed" -eq 0 ]
