#!/usr/bin/env python3
# reproducible integration with explicit test models or completed production modules
import argparse
import hashlib
import json
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys


# run each tool with a deadline and retain full diagnostics
def run(command, directory, logfile, timeout):
    print("+ " + shlex.join(str(item) for item in command), flush=True)
    try:
        result = subprocess.run(command, cwd=directory, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout, check=False)
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b""
        logfile.write_text(output.decode(errors="replace") if isinstance(output, bytes) else output)
        raise RuntimeError(f"command timed out after {timeout}s; see {logfile}") from error
    logfile.write_text(result.stdout)
    if result.returncode:
        print(result.stdout[-8000:], file=sys.stderr)
        raise RuntimeError(f"command failed ({result.returncode}); see {logfile}")
    for line in result.stdout.splitlines():
        if line.startswith(("TEST PASSED:", "generated ")):
            print(line, flush=True)
    return result.stdout


# resolve tools before creating misleading partial test results
def tool(name):
    found = shutil.which(name)
    if found is None:
        raise RuntimeError(f"required tool is unavailable: {name}")
    return str(Path(found).absolute())


# require the verified generated-main coverage writer only when collecting coverage
def check_coverage_version(verilator, timeout):
    try:
        result = subprocess.run([verilator, "--version"], text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout, check=False)
    except subprocess.TimeoutExpired as error:
        raise RuntimeError("Verilator version check timed out") from error
    version = re.search(r"\bVerilator\s+(\d+)\.(\d+)\b", result.stdout)
    if result.returncode or version is None:
        raise RuntimeError("--coverage requires Verilator >=5.053; could not determine its version")
    if tuple(map(int, version.groups())) < (5, 53):
        raise RuntimeError(f"--coverage requires Verilator >=5.053 for verified automatic coverage output; "
                           f"found {version.group(0)}; omit --coverage for ordinary integration tests")


# reject the project's currently empty dependency shells explicitly
def check_production(sources):
    empty = []
    for source in sources:
        content = re.sub(r"/\*.*?\*/|//[^\n]*", "", source.read_text(), flags=re.DOTALL)
        if re.fullmatch(r"\s*module\s+\w+\s*\([^;]*\)\s*;\s*endmodule\s*", content, re.DOTALL):
            empty.append(source.name)
    if empty:
        raise RuntimeError("production integration requires completed modules: " + ", ".join(empty) +
                           "; model results do not validate these modules")


# keep compiler overrides explicit so SDK and host toolchain choices stay portable
def main():
    parser = argparse.ArgumentParser(
        description="run independent RV32I traces and the project assembler smoke test",
        epilog="default mode substitutes four test-only dependencies; rerun with --production after their owners complete them")
    parser.add_argument("--simulator", choices=("iverilog", "verilator", "both"), default="iverilog")
    parser.add_argument("--production", action="store_true", help="compile only src/*.sv; never substitute test models")
    parser.add_argument("--build-dir", type=Path, help="generated images, logs, binaries, and results directory")
    parser.add_argument("--seed", type=int, default=2601101)
    parser.add_argument("--random-instructions", type=int, default=1200)
    parser.add_argument("--coverage", action="store_true", help="enable coverage with Verilator >=5.053 and require coverage.dat output")
    parser.add_argument("--iverilog", default="iverilog")
    parser.add_argument("--vvp", default="vvp")
    parser.add_argument("--verilator", default="verilator")
    parser.add_argument("--make", default="make")
    parser.add_argument("--cxx", help="C++ compiler and linker override for Verilator builds")
    parser.add_argument("--cxxflags", help="additional host compiler configuration, including an SDK if needed")
    parser.add_argument("--ldflags", help="host linker configuration")
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--timeout", type=float, default=120, help="deadline in seconds for each command")
    args = parser.parse_args()
    if args.timeout <= 0 or args.jobs <= 0:
        parser.error("--timeout and --jobs must be positive")
    if args.coverage and args.simulator == "iverilog":
        parser.error("--coverage requires --simulator verilator or both")

    repo = Path(__file__).resolve().parents[1]
    fixture = repo / "testbench/top_integration"
    mode = "production" if args.production else "models"
    output = (args.build_dir or repo / "build/top_integration" / mode).resolve()
    sources = sorted((repo / "src").glob("*.sv"))
    if args.production:
        check_production(sources)
    else:
        sources = [repo / "src" / name for name in ("top.sv", "instr_imm.sv", "branch_decoder.sv")]
        sources.append(fixture / "behavioral_models.sv")
    sources.insert(0, fixture / "integration_tb.sv")
    simulators = ("iverilog", "verilator") if args.simulator == "both" else (args.simulator,)
    executables = {}
    for simulator in simulators:
        executables[simulator] = tool(getattr(args, simulator))
    if "iverilog" in simulators:
        executables["vvp"] = tool(args.vvp)
    if "verilator" in simulators:
        if args.coverage:
            check_coverage_version(executables["verilator"], args.timeout)
        executables["make"] = tool(args.make)
    output.mkdir(parents=True, exist_ok=True)
    hashes = {str(path.relative_to(repo)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
    for path in (fixture / "generate.py", repo / "assembler/assembler.py", Path(__file__).resolve()):
        hashes[str(path.relative_to(repo))] = hashlib.sha256(path.read_bytes()).hexdigest()
    summary = {"status": "running", "mode": mode, "source_sha256": hashes, "runs": []}
    summary_path = output / "results.json"
    summary_path.write_text(json.dumps(summary, indent=2) + "\n")
    print(f"mode: {mode}; production CPU validation: {'yes' if args.production else 'no'}", flush=True)

    # both fixtures use the same interpreter and architectural observer
    for name in ("independent", "assembler"):
        directory = output / name
        directory.mkdir(parents=True, exist_ok=True)
        generate = [sys.executable, str(fixture / "generate.py"), "--out", str(directory),
                    "--seed", str(args.seed), "--random-instructions", str(args.random_instructions)]
        if name == "assembler":
            generate.append("--assembler")
        run(generate, repo, directory / "generate.log", args.timeout)
        defines = [] if args.production else ["-DTOP_BEHAVIORAL_MODELS"]
        if name == "assembler":
            defines.append("-DTOP_DEFAULT_IMAGE")

        # isolated source lists prevent duplicate definitions of production modules
        for simulator in simulators:
            build = directory / simulator
            build.mkdir(parents=True, exist_ok=True)
            if simulator == "iverilog":
                binary = build / "integration.vvp"
                command = [executables[simulator], "-g2012", "-s", "integration_tb", "-I", str(directory),
                           *defines, "-o", str(binary), *map(str, sources)]
                run(command, directory, build / "compile.log", args.timeout)
                simulation = [executables["vvp"], "-n", str(binary)]
            else:
                command = [executables[simulator], "--cc", "--exe", "--main", "--timing", "--assert",
                           "-Wno-fatal", "--top-module", "integration_tb", "-I" + str(directory),
                           "-Mdir", str(build), *defines]
                if args.coverage:
                    command.append("--coverage")
                run(command + list(map(str, sources)), directory, build / "compile.log", args.timeout)
                make = [executables["make"], "-C", str(build), "-f", "Vintegration_tb.mk", "-j", str(args.jobs)]
                if args.cxx:
                    compiler = tool(args.cxx)
                    make.extend(["CXX=" + compiler, "LINK=" + compiler])
                if args.cxxflags is not None:
                    make.append("CXXFLAGS=" + args.cxxflags)
                if args.ldflags is not None:
                    make.append("LDFLAGS=" + args.ldflags)
                run(make, directory, build / "make.log", args.timeout)
                simulation = [str(build / "Vintegration_tb")]
                if args.coverage:
                    (build / "coverage.dat").unlink(missing_ok=True)
                    simulation.append("+verilator+coverage+file+" + str(build / "coverage.dat"))
            result = run(simulation, directory, build / "run.log", args.timeout)
            if "TEST PASSED:" not in result:
                raise RuntimeError(f"simulation ended without its completion marker; see {build / 'run.log'}")
            record = {"fixture": name, "simulator": simulator, "log": str(build / "run.log")}
            if args.coverage and simulator == "verilator":
                coverage = build / "coverage.dat"
                if not coverage.is_file() or not coverage.stat().st_size:
                    raise RuntimeError(f"Verilator did not write coverage: {coverage}")
                record["coverage"] = str(coverage)
                (build / "coverage_metadata.json").write_text(json.dumps({"mode": mode, "source_sha256": hashes}, indent=2) + "\n")
            summary["runs"].append(record)
    summary["status"] = "passed"
    summary_path.write_text(json.dumps(summary, indent=2) + "\n")
    print(f"all integration checks passed; results: {summary_path}")


# return a failing exit code for missing tools, incomplete modules, or failed checks
if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError) as error:
        print(f"integration error: {error}", file=sys.stderr)
        sys.exit(1)
