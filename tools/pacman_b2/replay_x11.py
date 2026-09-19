#!/usr/bin/env python3
import argparse
import json
import subprocess
import time
from pathlib import Path


def run_xdotool(window_id, event, input_mode):
    kind = event["type"]
    if input_mode == "xtest":
        if kind == "mouse_click":
            subprocess.run([
                "xdotool", "mousemove", "--sync",
                str(event["x"]), str(event["y"]),
            ], check=True)
            subprocess.run(["xdotool", "click", str(event.get("button", 1))], check=True)
            return
        key = event["key"]
        if kind == "key_down":
            subprocess.run(["xdotool", "keydown", key], check=True)
        elif kind == "key_up":
            subprocess.run(["xdotool", "keyup", key], check=True)
        else:
            raise ValueError(f"Unsupported replay event type: {kind}")
        return

    if kind == "mouse_click":
        subprocess.run([
            "xdotool", "mousemove", "--window", window_id,
            str(event["x"]), str(event["y"]),
        ], check=True)
        subprocess.run([
            "xdotool", "click", "--window", window_id,
            str(event.get("button", 1)),
        ], check=True)
        return
    key = event["key"]
    if kind == "key_down":
        subprocess.run(["xdotool", "keydown", "--window", window_id, key], check=True)
    elif kind == "key_up":
        subprocess.run(["xdotool", "keyup", "--window", window_id, key], check=True)
    else:
        raise ValueError(f"Unsupported replay event type: {kind}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--window", required=True)
    ap.add_argument("--schedule", required=True)
    ap.add_argument("--audit", required=True)
    ap.add_argument("--start-delay", type=float, default=0.75)
    ap.add_argument("--input-mode", choices=["direct", "xtest"], default="direct")
    args = ap.parse_args()

    schedule = json.loads(Path(args.schedule).read_text("utf-8"))
    fps = float(schedule["fps"])
    events = sorted(schedule["events"], key=lambda e: (int(e["frame"]), int(e.get("order", 0))))
    t0 = time.monotonic() + args.start_delay
    audit = {
        "fps": fps,
        "frame_period_seconds": 1.0 / fps,
        "window": args.window,
        "start_delay_seconds": args.start_delay,
        "input_mode": args.input_mode,
        "events": [],
    }

    for event in events:
        frame = int(event["frame"])
        target = t0 + frame / fps
        while True:
            now = time.monotonic()
            remaining = target - now
            if remaining <= 0:
                break
            time.sleep(min(remaining, 0.002))
        before = time.monotonic()
        run_xdotool(args.window, event, args.input_mode)
        after = time.monotonic()
        audit["events"].append({
            **event,
            "target_seconds_from_t0": frame / fps,
            "dispatch_start_seconds_from_t0": before - t0,
            "dispatch_end_seconds_from_t0": after - t0,
            "lateness_ms": (before - target) * 1000.0,
        })

    Path(args.audit).write_text(json.dumps(audit, indent=2) + "\n", "utf-8")


if __name__ == "__main__":
    main()
