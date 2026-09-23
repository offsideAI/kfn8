#!/usr/bin/env python3
"""Drive the Kfn8 M0 probe on a paired Vision Pro from the Mac.

Writes Documents/commands.json into the app container with `devicectl copy to`, waits for the app to execute it,
pulls Documents/status.json back, and optionally captures the Mac screen (use with the headset's "Mirror My View"
to this Mac) so the agent can look at what the headset shows.

Usage:
  probe_remote.py status
  probe_remote.py run '<json commands array>' [--wait 3] [--capture out.png]
  probe_remote.py evidence out.json
  probe_remote.py launch [--args "--open-immersive --lamp-on"]
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path

DEVICE = os.environ.get("KFN8_DEVICE", "00008112-000979EA1A21A01E")
BUNDLE = "com.appliaison.kfn8.m0probe"
DEVELOPER_DIR = os.environ.get("DEVELOPER_DIR", "/Users/coder/Developer/Xcode/Xcode_27_0_0/Xcode_27_0_0.app/Contents/Developer")


def devicectl(*args, timeout=90):
    env = dict(os.environ, DEVELOPER_DIR=DEVELOPER_DIR)
    result = subprocess.run(["xcrun", "devicectl", *args], env=env, capture_output=True, text=True, timeout=timeout)
    return result.returncode, result.stdout + result.stderr


def copy_to(local: Path, remote_name: str):
    return devicectl("device", "copy", "to", "--device", DEVICE, "--source", str(local), "--destination", f"Documents/{remote_name}",
                     "--domain-type", "appDataContainer", "--domain-identifier", BUNDLE)


def copy_from(remote_name: str, local: Path):
    if local.exists():
        local.unlink()
    return devicectl("device", "copy", "from", "--device", DEVICE, "--source", f"Documents/{remote_name}", "--destination", str(local),
                     "--domain-type", "appDataContainer", "--domain-identifier", BUNDLE)


def status(verbose=True):
    local = Path(tempfile.gettempdir()) / "kfn8-status.json"
    code, out = copy_from("status.json", local)
    if code != 0 or not local.exists():
        print("status unavailable:", out.strip().splitlines()[-1] if out.strip() else code)
        return None
    data = json.loads(local.read_text())
    if verbose:
        print(json.dumps(data, indent=2, sort_keys=True))
    return data


def run(commands, wait: float, capture: str | None):
    cmd_id = str(uuid.uuid4())
    payload = {"id": cmd_id, "commands": commands}
    local = Path(tempfile.gettempdir()) / "kfn8-commands.json"
    local.write_text(json.dumps(payload))
    code, out = copy_to(local, "commands.json")
    if code != 0:
        print("copy failed:", out.strip())
        sys.exit(1)
    deadline = time.time() + max(wait, 1.0) + 10
    data = None
    while time.time() < deadline:
        time.sleep(1.0)
        data = status(verbose=False)
        if data and data.get("lastCommandID") == cmd_id:
            break
    if not data or data.get("lastCommandID") != cmd_id:
        print("command not acknowledged; is the app in the foreground on the headset?")
        if data:
            print(json.dumps(data, indent=2, sort_keys=True))
        sys.exit(2)
    if wait > 1.0:
        time.sleep(wait - 1.0)
        data = status(verbose=False)
    print(json.dumps(data, indent=2, sort_keys=True))
    if data.get("errors"):
        print("ERRORS:", data["errors"])
    if capture:
        subprocess.run(["screencapture", "-x", capture], check=False)
        print("captured", capture)


def evidence(out: str):
    code, msg = copy_from("M0-EVIDENCE.json", Path(out))
    print(msg.strip().splitlines()[-1] if msg.strip() else code)


def launch(args: str):
    argv = ["device", "process", "launch", "--device", DEVICE, "--terminate-existing", BUNDLE]
    if args:
        argv += args.split()
    code, out = devicectl(*argv, timeout=60)
    print(out.strip()[-400:] if out.strip() else f"exit {code}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    r = sub.add_parser("run")
    r.add_argument("commands")
    r.add_argument("--wait", type=float, default=3.0)
    r.add_argument("--capture", default=None)
    e = sub.add_parser("evidence")
    e.add_argument("out")
    l = sub.add_parser("launch")
    l.add_argument("--args", default="")
    a = parser.parse_args()
    if a.cmd == "status":
        status()
    elif a.cmd == "run":
        run(json.loads(a.commands), a.wait, a.capture)
    elif a.cmd == "evidence":
        evidence(a.out)
    elif a.cmd == "launch":
        launch(a.args)


if __name__ == "__main__":
    main()
