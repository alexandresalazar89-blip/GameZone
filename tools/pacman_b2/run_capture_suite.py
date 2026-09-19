#!/usr/bin/env python3
import argparse
import json
import os
import re
import signal
import subprocess
import sys
import time
from pathlib import Path


def run(cmd, **kwargs):
    return subprocess.run(cmd, check=True, **kwargs)


def find_window(pid):
    for _ in range(150):
        p = subprocess.run(
            ["xdotool", "search", "--onlyvisible", "--pid", str(pid)],
            text=True, capture_output=True
        )
        if p.returncode == 0 and p.stdout.strip():
            return p.stdout.splitlines()[0].strip()
        time.sleep(0.1)
    return None


def geometry(window):
    text = subprocess.check_output(["xwininfo", "-id", window], text=True)
    def get(rx):
        m = re.search(rx, text, re.M)
        if not m:
            raise RuntimeError(f"Cannot parse xwininfo field: {rx}")
        return int(m.group(1))
    return {
        "x": get(r"Absolute upper-left X:\s+(-?\d+)"),
        "y": get(r"Absolute upper-left Y:\s+(-?\d+)"),
        "width": get(r"^\s*Width:\s+(\d+)"),
        "height": get(r"^\s*Height:\s+(\d+)"),
        "raw": text,
    }


def stop_process(proc):
    if proc.poll() is not None:
        return
    proc.terminate()
    try:
        proc.wait(timeout=4)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=2)


def capture_one(args, replay_path, capture_name):
    schedule = json.loads(Path(replay_path).read_text("utf-8"))
    fps = int(schedule["fps"])
    duration = float(schedule["duration_seconds"])
    out = Path(args.out_root) / capture_name
    out.mkdir(parents=True, exist_ok=True)
    logs = out / "logs"
    logs.mkdir(exist_ok=True)

    env = dict(os.environ)
    env["DISPLAY"] = args.display
    env["PULSE_SINK"] = args.pulse_sink
    env["VK_LOADER_DEBUG"] = "error"

    ruffle_log = (logs / "ruffle.log").open("wb")
    ruffle = subprocess.Popen([
        args.ruffle,
        "--graphics", "vulkan",
        "--power", "low",
        "--width", "360",
        "--height", "420",
        "--no-gui",
        "--frame-rate", str(fps),
        "--volume", "1",
        "--open-url-mode", "deny",
        args.swf,
    ], stdout=ruffle_log, stderr=subprocess.STDOUT, env=env)

    try:
        win = find_window(ruffle.pid)
        if not win:
            stop_process(ruffle)
            ruffle_log.close()
            raise RuntimeError(f"Ruffle window did not appear for {capture_name}: " + (logs/"ruffle.log").read_text(errors="replace"))

        run(["xdotool", "windowmove", win, "0", "0"], env=env)
        run(["xdotool", "windowsize", win, "360", "420"], env=env)
        run(["xdotool", "windowfocus", "--sync", win], env=env)
        focused = subprocess.check_output(["xdotool", "getwindowfocus"], text=True, env=env).strip()
        if focused != win:
            raise RuntimeError(f"Window focus mismatch: expected {win}, got {focused}")
        time.sleep(0.4)

        geo = geometry(win)
        (out / "window-info.txt").write_text(geo["raw"], "utf-8")
        if geo["width"] != 360 or geo["height"] != 420:
            raise RuntimeError(f"Unexpected Ruffle client size: {geo}")

        video = out / "capture.mkv"
        audio = out / "capture.wav"
        ffmpeg_log = (logs / "ffmpeg.log").open("wb")
        video_proc = subprocess.Popen([
            "ffmpeg", "-hide_banner", "-loglevel", "warning", "-y",
            "-f", "x11grab", "-draw_mouse", "0", "-framerate", str(fps),
            "-video_size", f"{geo['width']}x{geo['height']}",
            "-i", f"{args.display}+{geo['x']},{geo['y']}",
            "-t", str(duration),
            "-c:v", "ffv1", "-level", "3", "-pix_fmt", "bgr0",
            str(video)
        ], stdout=ffmpeg_log, stderr=subprocess.STDOUT, env=env)

        parec_log = (logs / "parec.log").open("wb")
        audio_proc = subprocess.Popen([
            "timeout", str(duration + 0.5),
            "parec", f"--device={args.pulse_sink}.monitor",
            "--file-format=wav", str(audio)
        ], stdout=parec_log, stderr=subprocess.STDOUT, env=env)

        audit = out / "replay-audit.json"
        replay_copy = out / "replay.json"
        replay_copy.write_text(json.dumps(schedule, indent=2) + "\n", "utf-8")
        subprocess.run([
            sys.executable, args.replay_driver,
            "--window", win,
            "--schedule", str(replay_path),
            "--audit", str(audit),
            "--start-delay", "0.75",
            "--input-mode", "xtest",
        ], check=True, env=env)

        if video_proc.wait(timeout=duration + 8) != 0:
            raise RuntimeError(f"ffmpeg capture failed for {capture_name}")
        try:
            audio_proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            audio_proc.terminate()
            audio_proc.wait(timeout=2)

        stop_process(ruffle)
        ruffle_log.close()
        ffmpeg_log.close()
        parec_log.close()

        if not video.exists() or video.stat().st_size == 0:
            raise RuntimeError(f"Empty video for {capture_name}")
        if not audio.exists() or audio.stat().st_size == 0:
            raise RuntimeError(f"Empty audio for {capture_name}")

        analysis_dir = out / "reference"
        subprocess.run([
            sys.executable, args.analyzer,
            "--video", str(video),
            "--audio", str(audio),
            "--schedule", str(replay_path),
            "--audit", str(audit),
            "--out-dir", str(analysis_dir),
        ], check=True)

        audit_data = json.loads(audit.read_text("utf-8"))
        late = max(abs(float(e["lateness_ms"])) for e in audit_data["events"])
        if late > 25:
            raise RuntimeError(f"Replay jitter {late:.3f} ms exceeded 25 ms for {capture_name}")

        analysis = json.loads((analysis_dir / "analysis.json").read_text("utf-8"))
        if analysis["observable"]["audio"].get("max_peak_db", -120) <= -70:
            raise RuntimeError(f"Effectively silent capture for {capture_name}")

        summary = {
            "capture_name": capture_name,
            "scenario": schedule["name"],
            "classification": schedule["classification"],
            "video_bytes": video.stat().st_size,
            "audio_bytes": audio.stat().st_size,
            "max_replay_lateness_ms": round(late, 3),
            "pacman_x_jumps": analysis["observable"]["pacman_large_x_jumps"],
            "score_crop_segments": len(analysis["observable"]["score_crop_stable_segments"]),
            "audio_max_peak_db": analysis["observable"]["audio"].get("max_peak_db"),
        }
        (out / "capture-summary.json").write_text(json.dumps(summary, indent=2) + "\n", "utf-8")
        return summary
    finally:
        stop_process(ruffle)
        try:
            ruffle_log.close()
        except Exception:
            pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ruffle", required=True)
    ap.add_argument("--swf", required=True)
    ap.add_argument("--replay-dir", required=True)
    ap.add_argument("--out-root", required=True)
    ap.add_argument("--replay-driver", required=True)
    ap.add_argument("--analyzer", required=True)
    ap.add_argument("--display", default=":99")
    ap.add_argument("--pulse-sink", default="oracle")
    args = ap.parse_args()

    replay_dir = Path(args.replay_dir)
    plan = [
        ("pellet_line.json", "pellet_line"),
        ("power_right.json", "power_right"),
        ("tunnel_right.json", "tunnel_right"),
        ("tunnel_left.json", "tunnel_left"),
    ]
    for i in range(1, 6):
        plan.append(("rng_motion.json", f"rng_motion_r{i}"))
    if (replay_dir / "level_clear_route.json").exists():
        for i in range(1, 4):
            plan.append(("level_clear_route.json", f"level_clear_r{i}"))

    results = []
    for file_name, capture_name in plan:
        print(f"[B2_CAPTURE] begin {capture_name}", flush=True)
        summary = capture_one(args, replay_dir / file_name, capture_name)
        print("[B2_CAPTURE] ok " + json.dumps(summary, sort_keys=True), flush=True)
        results.append(summary)

    Path(args.out_root, "suite-summary.json").write_text(json.dumps(results, indent=2) + "\n", "utf-8")


if __name__ == "__main__":
    main()
