SRC        := $(wildcard src/*.sv)
MODULES    := $(basename $(notdir $(SRC)))
INC        := testbench/common
SIM        ?= iverilog
TABLE_GEN  := scripts/gen_control_table.py

# Stubs whose lint warnings are not enforced yet. Remove a module from this
# list in the PR that implements it.
LINT_SKIP  := alu branch_decoder control_unit data_mem instr_imm reg_file top

.PHONY: all lint l1 table-check ci clean

all: lint l1

lint:
	@for m in $(MODULES); do \
		if echo " $(LINT_SKIP) " | grep -q " $$m "; then \
			echo "lint $$m (stub, warnings not enforced)"; flags=-Wno-fatal; \
		else \
			echo "lint $$m"; flags=-Wall; \
		fi; \
		out=$$(verilator --lint-only $$flags $(SRC) --top-module $$m 2>&1) || { echo "$$out"; exit 1; }; \
	done
	@echo "iverilog compile"
	@iverilog -g2012 -o /dev/null $(SRC)

l1:
	@scripts/run_l1.sh $(SIM)

table-check:
	@python3 $(TABLE_GEN) --check

ci: lint
	@scripts/run_l1.sh iverilog
	@scripts/run_l1.sh verilator
	@$(if $(wildcard $(TABLE_GEN)),$(MAKE) --no-print-directory table-check)

clean:
	rm -rf build
