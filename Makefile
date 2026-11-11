SRC        := $(wildcard src/*.sv)
MODULES    := $(basename $(notdir $(SRC)))
TABLE_GEN  := scripts/gen_control_table.py
LINT_CONFIG := build/lint_stubs.vlt
RVT_REPO   := https://github.com/riscv-software-src/riscv-tests.git
RVT_REV    := 3df703cd52d5f0d8224e3c50bf03c6cb70efff98
RVT_DIR    := build/riscv-tests

# Stubs whose lint warnings are not enforced yet. Remove a module from this
# list in the PR that implements it.
LINT_SKIP  :=

.PHONY: all lint l1 table-check ci isa clean

all: lint l1 isa

lint:
	@mkdir -p build
	@printf '%s\n' '`verilator_config' > $(LINT_CONFIG)
	@for m in $(LINT_SKIP); do \
		printf 'lint_off -rule UNUSEDSIGNAL -file "src/%s.sv"\n' "$$m"; \
		printf 'lint_off -rule UNDRIVEN -file "src/%s.sv"\n' "$$m"; \
	done >> $(LINT_CONFIG)
	@for m in $(MODULES); do \
		if echo " $(LINT_SKIP) " | grep -q " $$m "; then \
			echo "lint $$m (stub, warnings not enforced)"; flags=-Wno-fatal; \
		else \
			echo "lint $$m"; flags=-Wall; \
		fi; \
		out=$$(verilator --lint-only $$flags $(LINT_CONFIG) $(SRC) --top-module $$m 2>&1) || { echo "$$out"; exit 1; }; \
	done
	@echo "iverilog compile"
	@iverilog -g2012 -o /dev/null $(SRC)

l1:
	@scripts/run_l1.sh

table-check:
	@python3 $(TABLE_GEN) --check

ci: lint l1 table-check

# official rv32ui tests on core_tb; needs riscv64-unknown-elf-gcc
isa: $(RVT_DIR)
	@OUT=$(CURDIR)/build/isa sw/run_riscv_tests.sh $(abspath $(RVT_DIR))

$(RVT_DIR):
	git init -q $@
	git -C $@ fetch -q --depth 1 $(RVT_REPO) $(RVT_REV)
	git -C $@ checkout -q FETCH_HEAD

clean:
	rm -rf build
