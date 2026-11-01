"""run top image and control diagnostics, including expected failures"""

import pathlib
import subprocess


# resolve every input from the repository, independently of the caller's directory
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "build" / "top_checks"
BENCH = ROOT / "testbench" / "top_checks" / "top_checks_tb.sv"
EXPECTED = {
    1: "unknown execution control",
    2: "unknown execution control",
    3: "unknown execution control",
    4: "unknown execution control",
    5: "invalid writeback selector",
    6: "invalid ALU A selector",
    7: "unknown ALU B selector",
    8: "invalid ALU function",
    9: "invalid memory access size",
    10: "unknown subword load sign",
    13: "invalid branch condition",
    14: "invalid ALU A selector",
    15: "invalid ALU function",
    16: "invalid writeback selector",
    18: "invalid branch condition",
    19: "invalid memory access size",
}


# retain diagnostic output and fail on compiler errors or hung simulations
def run(command, log):
    result = subprocess.run(
        command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, timeout=30,
    )
    log.write_text(result.stdout)
    return result


# compile the actual production interfaces once for the control scenarios
def main():
    OUT.mkdir(parents=True, exist_ok=True)
    executable = OUT / "controls.vvp"
    inputs = [str(BENCH), *map(str, sorted((ROOT / "src").glob("*.sv")))]
    compiled = run(
        ["iverilog", "-g2012", "-s", "top_checks_tb", "-o", str(executable), *inputs],
        OUT / "compile.log",
    )
    if compiled.returncode:
        raise SystemExit(compiled.stdout)
    for case in range(22):
        result = run(["vvp", "-n", str(executable), f"+case={case}"], OUT / f"case_{case}.log")
        expected = EXPECTED.get(case)
        if expected:
            passed = result.returncode != 0 and f"top: {expected}" in result.stdout
        else:
            passed = result.returncode == 0 and "TEST PASSED" in result.stdout
        if not passed:
            raise SystemExit(f"control case {case} failed\n{result.stdout}")

    # choose a guaranteed missing image without changing the default image contract
    missing = OUT / "missing_image_directory" / "absent.mem"
    if missing.exists():
        raise SystemExit(f"expected a missing image at {missing}")
    missing_executable = OUT / "missing.vvp"
    compiled = run(
        ["iverilog", "-g2012", "-s", "top_checks_tb",
         f'-Ptop_checks_tb.IMAGE="{missing}"', "-o", str(missing_executable), *inputs],
        OUT / "missing_compile.log",
    )
    if compiled.returncode:
        raise SystemExit(compiled.stdout)
    result = run(["vvp", "-n", str(missing_executable), "+case=0"], OUT / "missing.log")
    if result.returncode == 0 or "top: cannot open instruction image" not in result.stdout:
        raise SystemExit(f"missing image did not fail explicitly\n{result.stdout}")
    print("TEST PASSED: 22 control cases and missing-image diagnostic")


# run only when invoked directly
if __name__ == "__main__":
    main()
