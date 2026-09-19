#!/usr/bin/env python3
import argparse
import hashlib
import json
import math
import shutil
import subprocess
import tempfile
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def frame_index(path: Path) -> int:
    return int(path.stem.lstrip("f"))


def sha_rgb(crop: Image.Image) -> str:
    return hashlib.sha256(crop.convert("RGB").tobytes()).hexdigest()


def centroid_for_color(im: Image.Image, target, tolerance=16, bounds=(0, 0, 360, 390)):
    rgb = im.convert("RGB")
    x0, y0, x1, y1 = bounds
    sx = sy = n = 0
    tr, tg, tb = target
    pix = rgb.load()
    for y in range(max(0, y0), min(rgb.height, y1)):
        for x in range(max(0, x0), min(rgb.width, x1)):
            r, g, b = pix[x, y]
            if abs(r-tr) <= tolerance and abs(g-tg) <= tolerance and abs(b-tb) <= tolerance:
                sx += x
                sy += y
                n += 1
    if n < 8:
        return None
    return {"x": sx/n, "y": sy/n, "pixels": n}



def color_components(im: Image.Image, target, tolerance=18, bounds=(0, 0, 360, 380),
                     min_pixels=20, min_w=4, max_w=24, min_h=4, max_h=24):
    rgb = im.convert("RGB")
    x0, y0, x1, y1 = bounds
    pix = rgb.load()
    tr, tg, tb = target
    matched = set()
    for y in range(max(0, y0), min(rgb.height, y1)):
        for x in range(max(0, x0), min(rgb.width, x1)):
            r, g, b = pix[x, y]
            if abs(r-tr) <= tolerance and abs(g-tg) <= tolerance and abs(b-tb) <= tolerance:
                matched.add((x, y))

    components = []
    while matched:
        seed = matched.pop()
        stack = [seed]
        pts = [seed]
        while stack:
            x, y = stack.pop()
            for nb in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if nb in matched:
                    matched.remove(nb)
                    stack.append(nb)
                    pts.append(nb)
        if len(pts) < min_pixels:
            continue
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        w = max(xs) - min(xs) + 1
        h = max(ys) - min(ys) + 1
        if not (min_w <= w <= max_w and min_h <= h <= max_h):
            continue
        components.append({
            "x": sum(xs) / len(xs),
            "y": sum(ys) / len(ys),
            "pixels": len(pts),
            "bbox": [min(xs), min(ys), max(xs)+1, max(ys)+1],
            "width": w,
            "height": h,
        })
    return sorted(components, key=lambda p: (p["y"], p["x"]))


def life_icon_count(im: Image.Image):
    comps = color_components(
        im, (255, 255, 0), tolerance=28, bounds=(130, 385, 300, 420),
        min_pixels=25, min_w=7, max_w=28, min_h=7, max_h=24,
    )
    return {"count": len(comps), "components": comps}

def pacman_centroid(im: Image.Image):
    rgb = im.convert("RGB")
    pix = rgb.load()
    sx = sy = n = 0
    # Maze area only; excludes life icons and fruit/status row.
    for y in range(20, min(rgb.height, 380)):
        for x in range(0, min(rgb.width, 360)):
            r, g, b = pix[x, y]
            if r >= 190 and g >= 170 and b <= 85:
                sx += x
                sy += y
                n += 1
    if n < 30:
        return None
    return {"x": sx/n, "y": sy/n, "pixels": n}


def stable_segments(values, min_len=2):
    out = []
    if not values:
        return out
    start = 0
    for i in range(1, len(values)+1):
        if i == len(values) or values[i][1] != values[start][1]:
            if i-start >= min_len:
                out.append({
                    "start_frame": values[start][0],
                    "end_frame": values[i-1][0],
                    "hash": values[start][1],
                    "representative_frame": values[(start+i-1)//2][0],
                })
            start = i
    return out


def make_score_contact(frames_dir: Path, segments, out_path: Path):
    if not segments:
        return
    tile_w, tile_h = 180, 58
    canvas = Image.new("RGB", (tile_w, tile_h*len(segments)), "white")
    draw = ImageDraw.Draw(canvas)
    for i, seg in enumerate(segments):
        im = Image.open(frames_dir / f"f{seg['representative_frame']:05d}.png").convert("RGB")
        crop = im.crop((0, 386, min(145, im.width), min(420, im.height)))
        crop.thumbnail((145, 34))
        y = i*tile_h
        canvas.paste(crop, (0, y+20))
        draw.text((0, y+2), f"f{seg['start_frame']}-{seg['end_frame']}", fill="black")
    canvas.save(out_path)


def audio_frame_metrics(wav_path: Path, fps: float):
    with wave.open(str(wav_path), "rb") as wf:
        channels = wf.getnchannels()
        width = wf.getsampwidth()
        rate = wf.getframerate()
        total = wf.getnframes()
        if width != 2:
            return {"supported": False, "reason": f"sample_width={width}"}
        raw = wf.readframes(total)
    import array
    samples = array.array("h")
    samples.frombytes(raw)
    if channels > 1:
        mono = []
        for i in range(0, len(samples), channels):
            mono.append(sum(samples[i:i+channels]) / channels)
    else:
        mono = list(samples)
    per = rate / fps
    rows = []
    frame = 0
    while int(frame*per) < len(mono):
        a = int(frame*per)
        b = min(len(mono), int((frame+1)*per))
        chunk = mono[a:b]
        if not chunk:
            break
        rms = math.sqrt(sum(v*v for v in chunk)/len(chunk))
        peak = max(abs(v) for v in chunk)
        rms_db = -120.0 if rms <= 0 else 20*math.log10(rms/32768.0)
        peak_db = -120.0 if peak <= 0 else 20*math.log10(peak/32768.0)
        rows.append({"frame": frame+1, "rms_db": round(rms_db, 3), "peak_db": round(peak_db, 3)})
        frame += 1
    active = [r for r in rows if r["rms_db"] > -55]
    return {
        "supported": True,
        "sample_rate": rate,
        "channels": channels,
        "frame_metrics": rows,
        "active_frame_count_above_minus55db": len(active),
        "first_active_frame": active[0]["frame"] if active else None,
        "last_active_frame": active[-1]["frame"] if active else None,
        "max_peak_db": max((r["peak_db"] for r in rows), default=-120),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--video", required=True)
    ap.add_argument("--audio", required=True)
    ap.add_argument("--schedule", required=True)
    ap.add_argument("--audit", required=True)
    ap.add_argument("--out-dir", required=True)
    args = ap.parse_args()

    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    schedule = json.loads(Path(args.schedule).read_text("utf-8"))
    fps = float(schedule["fps"])

    with tempfile.TemporaryDirectory(prefix="pacman-b2-") as td:
        frames_dir = Path(td)
        subprocess.run([
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-i", args.video,
            str(frames_dir / "f%05d.png")
        ], check=True)
        frames = sorted(frames_dir.glob("f*.png"))
        if not frames:
            raise SystemExit("No frames decoded from oracle capture")

        score_hashes = []
        pac = []
        ghosts = []
        lives = []
        colors = {
            "ghost_red": (221,0,0),
            "ghost_pink": (255,153,153),
            "ghost_cyan": (102,255,255),
            "ghost_orange": (255,153,0),
            "frightened_blue": (0,51,255),
        }
        for path in frames:
            idx = frame_index(path)
            im = Image.open(path).convert("RGB")
            score_crop = im.crop((0, 386, min(145, im.width), min(420, im.height)))
            score_hashes.append((idx, sha_rgb(score_crop)))
            pc = pacman_centroid(im)
            if pc:
                pac.append({"frame": idx, **pc})
            if idx % 3 == 0:
                row = {"frame": idx}
                for name, target in colors.items():
                    row[name] = centroid_for_color(im, target, tolerance=18, bounds=(0, 0, 360, 380))
                row["frightened_blue_components"] = color_components(
                    im, colors["frightened_blue"], tolerance=18, bounds=(0, 0, 360, 380),
                    min_pixels=30, min_w=7, max_w=20, min_h=7, max_h=20,
                )
                ghosts.append(row)
                lives.append({"frame": idx, **life_icon_count(im)})

        score_segments = stable_segments(score_hashes, min_len=2)
        # Keep only actual changes in the score/status crop, but retain enough
        # context to inspect them visually. Values are intentionally not OCR'd.
        make_score_contact(frames_dir, score_segments, out / "score-contact.png")

        jumps = []
        for a, b in zip(pac, pac[1:]):
            if b["frame"] == a["frame"] + 1 and abs(b["x"] - a["x"]) >= 180:
                jumps.append({
                    "from_frame": a["frame"], "to_frame": b["frame"],
                    "from_x": round(a["x"],3), "to_x": round(b["x"],3),
                    "y": round((a["y"]+b["y"])/2,3),
                    "delta_x": round(b["x"]-a["x"],3),
                })

        # Fixed reference frames every whole second plus every detected tunnel jump.
        refs = set()
        for sec in range(1, int(schedule.get("duration_seconds", 12))):
            refs.add(min(len(frames), int(round(sec*fps))+1))
        for jump in jumps:
            refs.update([max(1,jump["from_frame"]-1), jump["from_frame"], jump["to_frame"], min(len(frames),jump["to_frame"]+1)])
        ref_dir = out / "frames"
        ref_dir.mkdir(exist_ok=True)
        for idx in sorted(refs):
            src = frames_dir / f"f{idx:05d}.png"
            if src.exists():
                shutil.copy2(src, ref_dir / src.name)

    audit = json.loads(Path(args.audit).read_text("utf-8"))
    audio = audio_frame_metrics(Path(args.audio), fps)
    result = {
        "schema": 1,
        "scenario": schedule["name"],
        "classification": schedule["classification"],
        "fps": fps,
        "frame_count": len(frames),
        "duration_seconds": len(frames)/fps,
        "replay_schedule": schedule,
        "replay_audit": audit,
        "observable": {
            "score_crop_stable_segments": score_segments,
            "pacman_centroids": pac,
            "pacman_large_x_jumps": jumps,
            "ghost_color_centroids_every_3_frames": ghosts,
            "life_icons_every_3_frames": lives,
            "audio": audio,
        },
        "policy": "Screen pixels and captured audio only; no AVM/internal-variable inspection.",
    }
    (out / "analysis.json").write_text(json.dumps(result, indent=2) + "\n", "utf-8")


if __name__ == "__main__":
    main()
