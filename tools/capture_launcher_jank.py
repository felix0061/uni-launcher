#!/usr/bin/env python3
"""Capture one manual Android 9 interaction, without installing or changing apps.

This tool preserves raw evidence. It intentionally does not turn idle gaps into
animation FPS or equate a Flutter texture-consumption counter with map production.
"""

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
import time
import zlib
from pathlib import Path


SCENARIOS = (
    "idle", "page-swipe", "map-pan", "tap",
    "no-map-page-swipe", "fullscreen-map-pan",
)
PACKAGES = ("xyz.i4o.uni.launcher", "com.autonavi.amapautp.yh")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", default="adb")
    parser.add_argument("--serial", required=True)
    parser.add_argument("--scenario", required=True, choices=SCENARIOS)
    parser.add_argument("--seconds", type=int, default=10)
    parser.add_argument("--optimize-mode", choices=("on", "off", "unknown"), default="off")
    parser.add_argument("--map-texture-scale", choices=("on", "off", "unknown"), default="unknown")
    parser.add_argument("--note", default="")
    parser.add_argument("--map-package", default=PACKAGES[1])
    parser.add_argument("--output", type=Path)
    parser.add_argument("--allow-emulator", action="store_true",
                        help="Only for checking the collector; not car performance evidence")
    args = parser.parse_args()
    if not 2 <= args.seconds <= 30:
        parser.error("--seconds must be between 2 and 30")
    adb = [args.adb, "-s", args.serial]
    packages = (PACKAGES[0], args.map_package)

    def run(*command, timeout=20):
        try:
            result = subprocess.run(adb + list(command), capture_output=True, timeout=timeout)
            return {
                "command": list(command), "returncode": result.returncode,
                "stdout": result.stdout.decode("utf-8", errors="replace"),
                "stderr": result.stderr.decode("utf-8", errors="replace"),
            }
        except subprocess.TimeoutExpired as error:
            return {
                "command": list(command), "returncode": None, "error": "timeout",
                "stdout": (error.stdout or b"").decode("utf-8", errors="replace"),
                "stderr": (error.stderr or b"").decode("utf-8", errors="replace"),
            }

    state = run("get-state")
    if state.get("returncode") != 0 or state.get("stdout", "").strip() != "device":
        raise RuntimeError(f"ADB target is not ready: {state}")
    props = run("shell", "getprop")
    prop_values = {}
    for line in props["stdout"].splitlines():
        match = re.fullmatch(r"\[([^]]+)\]: \[(.*)\]", line.strip())
        if match:
            prop_values[match.group(1)] = match.group(2)
    abi = prop_values.get("ro.product.cpu.abilist", "") or prop_values.get("ro.product.cpu.abi", "")
    emulator = (args.serial.startswith("emulator-")
                or prop_values.get("ro.kernel.qemu") == "1"
                or prop_values.get("ro.boot.qemu") == "1"
                or "x86" in abi)
    if emulator and not args.allow_emulator:
        raise RuntimeError("Target appears to be an emulator/x86 device. Select the car serial; "
                           "--allow-emulator is only for validating this collector.")

    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out = args.output or Path("car-reports/perf") / f"diagnosis-{stamp}-{args.scenario}"
    out.mkdir(parents=True, exist_ok=False)
    metadata = {
        "schema": 1, "capturedAtUtc": stamp, "serial": args.serial,
        "scenario": args.scenario, "seconds": args.seconds,
        "packages": packages,
        "emulatorOrX86": emulator,
        "declaredSettings": {"optimizeMode": args.optimize_mode,
                             "mapTextureScale": args.map_texture_scale},
        "note": args.note,
        "limits": [
            "Settings are supplied by the operator, not read back from the app.",
            "Actions are manual; the collector does not verify page changes or mark individual gestures.",
            "Whole-window idle gaps must not be reported as animation jank.",
            "Thread/surface names and package versions do not establish installed APK hashes.",
            "Release builds may omit Flutter app trace events; missing events are not zero work.",
            "Trace collection can perturb timing; repeat comparisons with the same collection settings.",
        ],
    }
    (out / "getprop.txt").write_text(props["stdout"], encoding="utf-8")
    (out / "cpuinfo.txt").write_text(run("shell", "cat", "/proc/cpuinfo")["stdout"], encoding="utf-8")
    categories = run("shell", "atrace", "--list_categories")
    metadata["atraceCategories"] = categories
    available = set(re.findall(r"^\s*([\w-]+)\s+-", categories["stdout"], re.M))
    wanted = ("gfx", "input", "view", "wm", "am", "sched", "freq", "idle", "binder_driver", "dalvik")
    selected = [name for name in wanted if name in available]
    metadata["selectedCategories"] = selected

    def snapshot(label):
        commands = {
            "uptime": ("shell", "cat", "/proc/uptime"),
            "layers": ("shell", "dumpsys", "SurfaceFlinger", "--list"),
            "display": ("shell", "dumpsys", "display"),
            "cpu": ("shell", "dumpsys", "cpuinfo"),
            "threads": ("shell", "ps", "-A", "-T"),
        }
        for package in packages:
            commands[f"package-{package}"] = ("shell", "dumpsys", "package", package)
            commands[f"memory-{package}"] = ("shell", "dumpsys", "meminfo", package)
        records = {name: run(*command) for name, command in commands.items()}
        (out / f"{label}.json").write_text(
            json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"Target: {args.serial}; ABI: {abi}; scenario: {args.scenario}", flush=True)
    print("Collecting metadata. Prepare the requested screen; wait for CAPTURE START.", flush=True)
    snapshot("before")
    if not selected:
        metadata["traceError"] = "No readable atrace categories; no trace captured."
        (out / "metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"No readable atrace categories; diagnostics saved in {out}", file=sys.stderr)
        return 2

    # Some Android 9 adbd builds translate binary newlines on `adb shell`.
    # exec-out keeps the compressed trace intact.
    trace_command = ["exec-out", "atrace", "-z", "-b", "8192", "-t", str(args.seconds),
                     "-a", ",".join(packages)] + selected
    metadata["traceCommand"] = trace_command
    with (out / "interaction.atrace").open("wb") as raw:
        start = time.monotonic()
        process = subprocess.Popen(adb + trace_command, stdout=raw, stderr=subprocess.PIPE)
        print(f"CAPTURE START: perform only {args.scenario} for {args.seconds}s.", flush=True)
        try:
            _, stderr = process.communicate(timeout=args.seconds + 30)
        except subprocess.TimeoutExpired:
            process.kill()
            _, stderr = process.communicate()
            metadata["traceTimedOut"] = True
        metadata["hostTraceElapsedSeconds"] = round(time.monotonic() - start, 3)
        metadata["traceReturnCode"] = process.returncode
        metadata["traceStderr"] = stderr.decode("utf-8", errors="replace")
    print("CAPTURE END. Collecting final metadata.", flush=True)
    with (out / "interaction.atrace").open("rb") as raw:
        data = raw.read()
    metadata["traceHasHeader"] = b"TRACE:" in data[:4096]
    metadata["traceDecompressed"] = False
    if metadata["traceHasHeader"]:
        try:
            payload = data.split(b"TRACE:", 1)[1].lstrip(b"\r\n")
            decoded = zlib.decompress(payload)
            (out / "interaction.ftrace").write_bytes(decoded)
            metadata["traceDecompressed"] = True
        except zlib.error as error:
            metadata["traceDecodeError"] = str(error)
    snapshot("after")
    (out / "metadata.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Saved: {out.resolve()}", flush=True)
    if process.returncode != 0 or metadata.get("traceTimedOut") or not metadata["traceDecompressed"]:
        print("Trace incomplete; inspect metadata.json and interaction.atrace.", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
