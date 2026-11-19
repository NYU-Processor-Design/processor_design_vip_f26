#!/bin/bash
# Run every check and print a summary table: the one command for grading.
#   usage:  sw/check_all.sh                 everything
#           sw/check_all.sh uart spi        only these peripherals (plus lint + core)
# needs:   verilator (v5+), a C++ compiler, riscv64-unknown-elf-gcc, python3
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$HERE/..
. "$HERE/hdl_files.sh"
OUT=${OUT:-$ROOT/build}
mkdir -p "$OUT"
list=("$@"); [ ${#list[@]} -eq 0 ] && list=("${PERIPHERALS[@]}")

status() { if [ "$1" -eq 0 ]; then echo PASS; else echo FAIL; fi; }

echo "=== lint (whole design) ==="
"$HERE/lint.sh" > "$OUT/lint.log" 2>&1; lint_rc=$?
[ $lint_rc -eq 0 ] && echo "lint: clean" || { tail -20 "$OUT/lint.log"; echo "lint: FAILED (see build/lint.log)"; }

echo "=== CPU core (smoke tests) ==="
"$HERE/run_core_test.sh" "$HERE/smoke.c"; core_rc=$?

echo "=== unit tests (hardware only) ==="
declare -A U S
for p in "${list[@]}"; do "$HERE/run_unit_test.sh" "$p"; U[$p]=$?; done

echo "=== SoC tests (hardware + driver + fpro_mmio_sys) ==="
for p in "${list[@]}"; do OUT="$OUT" "$HERE/run_soc_test.sh" "$p"; S[$p]=$?; done

echo
echo "================ SUMMARY ================"
printf '%-8s %-6s %-6s\n' "" "unit" "soc"
for p in "${list[@]}"; do printf '%-8s %-6s %-6s\n' "$p" "$(status ${U[$p]})" "$(status ${S[$p]})"; done
printf 'lint     %s\ncore     %s\n' "$(status $lint_rc)" "$(status $core_rc)"
