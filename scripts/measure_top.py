#!/usr/bin/env python3
"""measure top source coverage or partial structure without FPGA claims"""

import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[1]
BLACKBOXES = ("alu", "control_unit", "data_mem", "reg_file")


# keep commands and output together for reproducible measurements
def run(command, logfile, timeout=300):
    with logfile.open("w") as log:
        log.write(json.dumps(command) + "\n")
        log.flush()
        result = subprocess.run(command, cwd=ROOT, stdout=log,
                                stderr=subprocess.STDOUT, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f"command failed ({result.returncode}); see {logfile}")
    return logfile.read_text()


# record the exact inputs without depending on repository history
def hashes():
    files = list((ROOT / "src").glob("*.sv"))
    files += list((ROOT / "testbench/level1_tb").glob("top*"))
    files += list((ROOT / "testbench/common").glob("*.svh"))
    files += list((ROOT / "testbench/top_integration").glob("*"))
    files += list((ROOT / "testbench/top_measure").glob("*"))
    files += [ROOT / "scripts/measure_top.py", ROOT / "scripts/run_top_integration.py",
              ROOT / "assembler/assembler.py"]
    return {str(file.relative_to(ROOT)): hashlib.sha256(file.read_bytes()).hexdigest()
            for file in sorted(files) if file.is_file()}


# select top source counters and collapse fixture-specific hierarchy names
def top_coverage(source, destination):
    records = []
    for line in source.read_text().splitlines():
        match = re.fullmatch(r"C '(.*)' ([0-9]+)", line)
        if not match:
            continue
        fields = dict(field.split("\x02", 1) for field in match[1].split("\x01")[1:])
        filename = Path(unquote(fields.get("f", "")))
        if not filename.is_absolute():
            filename = ROOT / filename
        if filename.resolve() != ROOT / "src/top.sv":
            continue
        fields["f"] = "src/top.sv"
        fields["h"] = "top"
        if "page" in fields:
            fields["page"] = fields["page"].split("/", 1)[0] + "/top"
        key = "".join("\x01" + name + "\x02" + value for name, value in fields.items())
        records.append(f"C '{key}' {match[2]}")
    if not records:
        raise RuntimeError(f"no src/top.sv coverage counters in {source}")
    destination.write_text("# SystemC::Coverage-3\n" + "\n".join(records) + "\n")


# separate counters on simulation-only lines without hiding the full report
def separate_diagnostics(merged, output):
    diagnostics = set()
    inside = False
    for number, line in enumerate((ROOT / "src/top.sv").read_text().splitlines(), 1):
        if line.strip() == "`ifndef SYNTHESIS":
            inside = True
        if inside:
            diagnostics.add(number)
        if line.strip() == "`endif":
            inside = False
    groups = {"datapath": [], "diagnostics": []}
    for line in merged.read_text().splitlines():
        match = re.search(r"\x01l\x02([0-9]+)(?:\x01|')", line)
        if match:
            group = "diagnostics" if int(match[1]) in diagnostics else "datapath"
            groups[group].append(line)
    for group, records in groups.items():
        filename = output / f"{group}.dat"
        filename.write_text("# SystemC::Coverage-3\n" + "\n".join(records) + "\n")
        run(["verilator_coverage", "--report", "summary", str(filename)],
            output / f"{group}.txt")
    return sorted(diagnostics)


# compile and run the isolated wiring test with assertions and coverage enabled
def coverage(args, output):
    for tool in ("verilator", "verilator_coverage", "make"):
        if not shutil.which(tool):
            raise RuntimeError(f"required tool not found: {tool}")
    version = subprocess.check_output(["verilator", "--version"], text=True).strip()
    release = re.search(r"Verilator ([0-9]+)\.([0-9]+)", version)
    if not release or tuple(map(int, release.groups())) < (5, 53):
        raise RuntimeError(f"coverage tooling requires Verilator 5.053 or later; found {version}")
    analyzer_version = subprocess.check_output(["verilator_coverage", "--version"], text=True).strip()
    analyzer_release = re.search(r"Verilator ([0-9]+)\.([0-9]+)", analyzer_version)
    if not analyzer_release or analyzer_release.groups() != release.groups():
        raise RuntimeError(f"verilator_coverage must match {version}; found {analyzer_version}")
    model = output / "unit"
    model.mkdir(parents=True, exist_ok=True)
    command = ["verilator", "--cc", "--exe", "--main", "--timing", "--assert",
               "--coverage", "-Wno-fatal", "--top-module", "top_tb",
               "-Itestbench/common", "-Mdir", str(model),
               "testbench/level1_tb/top_tb.sv"]
    command += [str(file.relative_to(ROOT)) for file in sorted((ROOT / "src").glob("*.sv"))]
    run(command, output / "unit-compile.log")
    make = ["make", "-C", str(model), "-f", "Vtop_tb.mk", f"-j{args.jobs}"]
    if args.cxx:
        make += [f"CXX={args.cxx}", f"LINK={args.cxx}"]
    if args.cxxflags:
        make.append(f"CXXFLAGS={args.cxxflags}")
    if args.ldflags:
        make.append(f"LDFLAGS={args.ldflags}")
    run(make, output / "unit-build.log")
    data = model / "coverage.dat"
    data.unlink(missing_ok=True)
    text = run([str(model / "Vtop_tb"), f"+verilator+coverage+file+{data}"],
               output / "unit-run.log", timeout=60)
    if "TEST PASSED" not in text or "TEST FAILED" in text:
        raise RuntimeError(f"unit test did not pass; see {output / 'unit-run.log'}")
    inputs = [data]
    if args.integration:
        command = [sys.executable, "scripts/run_top_integration.py",
                   "--simulator", "verilator", "--coverage"]
        for name in ("cxx", "cxxflags", "ldflags"):
            if getattr(args, name):
                command.append(f"--{name}={getattr(args, name)}")
        run(command, output / "integration.log", timeout=600)
        inputs += [ROOT / f"build/top_integration/models/{fixture}/verilator/coverage.dat"
                   for fixture in ("independent", "assembler")]
    filtered = []
    for index, datafile in enumerate(inputs):
        destination = output / f"top-{index}.dat"
        top_coverage(datafile, destination)
        filtered.append(str(destination))
    merged = output / "top.dat"
    run(["verilator_coverage", "--write", str(merged)] + filtered,
        output / "merge.log")
    summary = run(["verilator_coverage", "--report", "summary", str(merged)],
                  output / "coverage.txt")
    diagnostic_lines = separate_diagnostics(merged, output)
    run(["verilator_coverage", "--annotate", str(output / "annotated"),
         "--annotate-all", "--annotate-points", "--annotate-min", "1", str(merged)],
        output / "annotate.log")
    print(summary.strip())
    return {
        "scope": "src/top.sv source counters, collapsed across fixture hierarchies",
        "tool": version,
        "inputs": [str(file.relative_to(ROOT)) for file in inputs],
        "assertions": "enabled",
        "hit_threshold": 1,
        "limitations": ["passing runs only; fatal diagnostic paths may remain uncovered",
                        "instrumented points only; Verilator omits some fatal paths and source lines",
                        "two-state Verilator counters do not measure four-state behavior",
                        "code coverage does not prove functional correctness",
                        "large instruction array excluded by Verilator coverage size limit",
                        "unit controls are forced; integration uses models until production is ready"],
        "report": str(output / "coverage.txt"),
        "diagnostic_lines": diagnostic_lines,
        "split_reports": "datapath.txt and diagnostics.txt classify each counter by its primary source line",
        "fpga": "not measured; target measurement is outside this command's scope",
    }


# inspect retained RTL structure while treating four unfinished modules as blackboxes
def structure(args, output):
    if not shutil.which("yosys"):
        raise RuntimeError("required tool not found: yosys")
    script = (ROOT / "testbench/top_measure/structure.ys").read_text()
    script += f'\nwrite_json "{output / "structure.json"}"\n'
    scriptfile = output / "structure.ys"
    scriptfile.write_text(script)
    run(["yosys", "-s", str(scriptfile)], output / "structure.log")
    design = json.loads((output / "structure.json").read_text())
    cells = [cell for module in design["modules"].values()
             for cell in module.get("cells", {}).values()]
    memories = []
    for cell in cells:
        if cell["type"] == "$mem_v2":
            parameters = cell["parameters"]
            memories.append({name.lower(): int(parameters[name], 2)
                             for name in ("WIDTH", "SIZE", "RD_PORTS", "RD_CLK_ENABLE", "WR_PORTS")})
    report = {
        "scope": "unmapped top wiring and real immediate/branch decoders; no optimization pass",
        "tool": subprocess.check_output(["yosys", "-V"], text=True).strip(),
        "blackboxes": list(BLACKBOXES),
        "cells": dict(sorted(Counter(cell["type"] for cell in cells).items())),
        "flip_flop_widths": [int(cell["parameters"]["WIDTH"], 2)
                             for cell in cells if cell["type"] == "$dff"],
        "memories": memories,
        "limitations": ["no LUT, FF, BRAM, placement, routing, or timing measurement",
                        "blackbox internals excluded even after production implementations exist"],
        "fpga": "not measured; generic structure is not an FPGA utilization or timing result",
    }
    print(json.dumps(report, indent=2))
    return report


# keep reports in the ignored build tree and reject inputs changing during a run
def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     epilog="coverage tooling requires Verilator 5.053 or later")
    parser.add_argument("mode", choices=("coverage", "structure"))
    parser.add_argument("--integration", action="store_true", help="also run model integration coverage")
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--cxx", default=os.environ.get("CXX"))
    parser.add_argument("--cxxflags", default=os.environ.get("CXXFLAGS"))
    parser.add_argument("--ldflags", default=os.environ.get("LDFLAGS"))
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    output = ROOT / "build/top_measure" / args.mode
    output.mkdir(parents=True, exist_ok=True)
    (output / "report.json").unlink(missing_ok=True)
    original = hashes()
    report = coverage(args, output) if args.mode == "coverage" else structure(args, output)
    if original != hashes():
        raise RuntimeError("source files changed during measurement; rerun for consistent results")
    report["sha256"] = original
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"report: {output / 'report.json'}")


# return a failure status for missing tools, failed checks, and timeouts
if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError, ValueError) as error:
        print(f"measurement failed: {error}", file=sys.stderr)
        sys.exit(1)
