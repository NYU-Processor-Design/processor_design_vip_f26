#!/usr/bin/env bash
# Build and run every testbench/level1_tb/*_tb.sv with the given simulator
# (iverilog or verilator). A test passes only if it prints "TEST PASSED".
# Empty testbench files are skipped.
set -u

sim=${1:-iverilog}
src=(src/*.sv)
inc=testbench/common
out=build/l1/$sim
mkdir -p "$out"

passed=0 failed=0 skipped=0
for tb in testbench/level1_tb/*_tb.sv; do
    name=$(basename "$tb" .sv)
    if [ ! -s "$tb" ]; then
        echo "SKIP $name (empty)"
        skipped=$((skipped + 1))
        continue
    fi

    log=$out/$name.log
    case $sim in
        iverilog)
            iverilog -g2012 -I "$inc" -s "$name" -o "$out/$name.vvp" "$tb" "${src[@]}" > "$log" 2>&1 &&
                timeout 60 vvp -n "$out/$name.vvp" >> "$log" 2>&1
            ;;
        verilator)
            verilator --binary -Wno-fatal -I"$inc" --top-module "$name" -Mdir "$out/$name" \
                -o "$name" "$tb" "${src[@]}" > "$log" 2>&1 &&
                timeout 60 "$out/$name/$name" >> "$log" 2>&1
            ;;
        *)
            echo "unknown simulator: $sim" >&2
            exit 2
            ;;
    esac

    if grep -q "^TEST PASSED" "$log" && ! grep -q "TEST FAILED" "$log"; then
        echo "PASS $name"
        passed=$((passed + 1))
    else
        echo "FAIL $name (see $log)"
        failed=$((failed + 1))
    fi
done

echo "level 1 [$sim]: $passed passed, $failed failed, $skipped skipped"
[ "$failed" -eq 0 ]
