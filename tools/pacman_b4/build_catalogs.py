#!/usr/bin/env python3
import argparse, json, re
from pathlib import Path

ROOT_GHOST_RAW = "games/pacman/decompiled/sprites/DefineSprite_19_Ghost/1.svg"
FRIGHT_GHOST_RAW = "games/pacman/decompiled/sprites/DefineSprite_19_Ghost/2.svg"


def load_json(path):
    return json.loads(Path(path).read_text("utf-8"))


def svg_geometry(path):
    text = Path(path).read_text("utf-8", errors="replace")
    head = re.search(r"<svg[^>]*\bheight=\"([0-9.]+)px\"[^>]*\bwidth=\"([0-9.]+)px\"", text)
    if not head:
        # FFDec currently writes height before width; support the reverse too.
        head = re.search(r"<svg[^>]*\bwidth=\"([0-9.]+)px\"[^>]*\bheight=\"([0-9.]+)px\"", text)
        if not head:
            raise RuntimeError(f"Cannot parse SVG size: {path}")
        width, height = float(head.group(1)), float(head.group(2))
    else:
        height, width = float(head.group(1)), float(head.group(2))
    g = re.search(r"<g\s+transform=\"matrix\(([^)]*)\)\"", text)
    origin = [0.0, 0.0]
    if g:
        nums = [float(x.strip()) for x in g.group(1).split(",")]
        if len(nums) == 6:
            origin = [nums[4], nums[5]]
    return {"width": width, "height": height, "origin": origin}


def find_sprite_dir(raw_root, sid):
    matches = sorted((raw_root / "sprites").glob(f"DefineSprite_{sid}*"))
    if len(matches) != 1:
        raise RuntimeError(f"sprite {sid}: expected one raw directory, got {matches}")
    return matches[0]


def snapshot_depths(timeline):
    active = {}
    frames = []
    for frame in timeline["frames"]:
        for ev in frame.get("events", []):
            if ev["type"] == "remove":
                active.pop(int(ev["depth"]), None)
            elif ev["type"] == "place":
                depth = int(ev["depth"])
                old = dict(active.get(depth, {}))
                if ev.get("character_id") is not None:
                    old["character_id"] = int(ev["character_id"])
                if ev.get("instance_name") is not None:
                    old["instance_name"] = ev.get("instance_name")
                if ev.get("matrix") is not None:
                    old["matrix"] = ev.get("matrix")
                old["depth"] = depth
                old["move"] = bool(ev.get("move", False))
                active[depth] = old
        frames.append({
            "frame": int(frame["frame"]),
            "depths": [dict(active[k]) for k in sorted(active)],
        })
    return frames


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root", default=".")
    ap.add_argument("--out-dir", required=True)
    args=ap.parse_args()
    root=Path(args.repo_root)
    out=root/args.out_dir
    out.mkdir(parents=True, exist_ok=True)
    raw=root/"games/pacman/decompiled"
    manifest=load_json(root/"games/pacman/ASSET_MANIFEST.json")
    symbols=load_json(root/"games/pacman/SYMBOL_MAP.json")
    timelines=load_json(root/"games/pacman/TIMELINE_MAP.json")

    defs={int(x["character_id"]):x for x in symbols["character_definitions"]}

    shape_entries=[]
    for item in manifest["files"]:
        if item["category"]!="shapes":
            continue
        cid=int(Path(item["path"]).stem)
        path=f"games/pacman/decompiled/{item['path']}"
        shape_entries.append({
            "character_id":cid,
            "raw":path,
            "godot_resource":"res://"+path,
            "sha256":item["sha256"],
            "geometry":svg_geometry(root/path),
            "import_as":"Texture2D",
        })

    sprite_entries=[]
    total_sprite_frames=0
    for sid_s, tl in sorted(timelines["sprites"].items(), key=lambda kv:int(kv[0])):
        sid=int(sid_s)
        directory=find_sprite_dir(raw,sid)
        frames=[]
        for p in sorted(directory.glob("*.svg"), key=lambda p:int(p.stem)):
            frame_no=int(p.stem)
            rel=p.relative_to(root).as_posix()
            frames.append({
                "frame":frame_no,
                "raw":rel,
                "godot_resource":"res://"+rel,
                "geometry":svg_geometry(p),
            })
        declared=int(tl["declared_frame_count"])
        if len(frames)!=declared:
            raise RuntimeError(f"sprite {sid}: {len(frames)} SVGs != declared {declared}")
        labels={}
        for fr in tl["frames"]:
            for label in fr.get("labels",[]):
                labels[label]=int(fr["frame"])
        sprite_entries.append({
            "character_id":sid,
            "export_names":defs.get(sid,{}).get("export_names",[]),
            "raw_dir":directory.relative_to(root).as_posix(),
            "declared_frame_count":declared,
            "labels":labels,
            "frames":frames,
            "depth_snapshots":snapshot_depths(tl),
            "render_strategy":"FFDec per-frame SVG texture; depth state retained from TIMELINE_MAP",
        })
        total_sprite_frames += len(frames)

    sound_files={}
    stream_files=[]
    for item in manifest["files"]:
        if item["category"]!="sounds":
            continue
        path=f"games/pacman/decompiled/{item['path']}"
        stem=Path(item["path"]).stem
        m=re.match(r"(-?\d+)",stem)
        sid=int(m.group(1)) if m else None
        entry={"raw":path,"godot_resource":"res://"+path,"sha256":item["sha256"]}
        if sid is not None and sid>=0:
            sound_files[sid]=entry
        else:
            stream_files.append(entry)

    sound_entries=[]
    for sid,entry in sorted(sound_files.items()):
        names=defs.get(sid,{}).get("export_names",[])
        sound_entries.append({"character_id":sid,"export_names":names,**entry,"timeline_triggers":[]})

    by_sound={x["character_id"]:x for x in sound_entries}
    for timeline_id,tl in [(0,timelines["main"])]+[(int(k),v) for k,v in timelines["sprites"].items()]:
        nearest_label=None
        for fr in tl["frames"]:
            labels=fr.get("labels",[])
            if labels:
                nearest_label=labels[-1]
            for ev in fr.get("events",[]):
                if ev["type"]=="start_sound" and ev.get("sound_id") in by_sound:
                    by_sound[ev["sound_id"]]["timeline_triggers"].append({
                        "timeline":timeline_id,
                        "frame":int(fr["frame"]),
                        "frame_labels":labels,
                        "nearest_preceding_label":nearest_label,
                    })

    font_paths={}
    for item in manifest["files"]:
        if item["category"]=="fonts":
            m=re.match(r"(\d+)",Path(item["path"]).name)
            if m:
                font_paths[int(m.group(1))]={
                    "raw":f"games/pacman/decompiled/{item['path']}",
                    "godot_resource":f"res://games/pacman/decompiled/{item['path']}",
                    "sha256":item["sha256"],
                }
    font_entries=[]
    for d in sorted((x for x in symbols["character_definitions"] if x["kind"]=="font"),key=lambda x:x["character_id"]):
        fid=int(d["character_id"])
        entry={
            "character_id":fid,
            "name":d.get("font_name","").replace("\u0000",""),
            "glyph_count":int(d.get("glyph_count",0)),
        }
        if fid in font_paths:
            entry.update(font_paths[fid])
            entry["strategy"]="imported_ttf"
        else:
            entry["raw"]=None
            entry["godot_resource"]=None
            entry["strategy"]="godot_fallback_only_when_referenced"
        font_entries.append(entry)

    text_files={}
    for item in manifest["files"]:
        if item["category"]=="texts":
            tid=int(Path(item["path"]).stem)
            p=root/"games/pacman/decompiled"/item["path"]
            text_files[tid]={
                "raw":p.relative_to(root).as_posix(),
                "content":p.read_text("utf-8",errors="replace"),
                "sha256":item["sha256"],
            }
    text_entries=[]
    for d in sorted((x for x in symbols["character_definitions"] if x["kind"]=="text"),key=lambda x:x["character_id"]):
        tid=int(d["character_id"])
        f=text_files[tid]
        font_id=d.get("font_id")
        text_entries.append({
            "character_id":tid,
            "raw":f["raw"],
            "sha256":f["sha256"],
            "content":f["content"],
            "variable_name":d.get("variable_name",""),
            "font_id":font_id,
            "placements":d.get("placements",[]),
            "render_strategy":"Godot Label with imported/fallback font" if font_id else "static text preserved inside FFDec frame/sprite SVG texture",
        })

    derived=[
        {"path":"games/pacman/b4/derived/ghost_red.svg","source":ROOT_GHOST_RAW,"transform":"replace ghost body+bottom #ffffff with cOrig #dd0000"},
        {"path":"games/pacman/b4/derived/ghost_pink.svg","source":ROOT_GHOST_RAW,"transform":"replace ghost body+bottom #ffffff with cOrig #ff9999"},
        {"path":"games/pacman/b4/derived/ghost_cyan.svg","source":ROOT_GHOST_RAW,"transform":"replace ghost body+bottom #ffffff with cOrig #66ffff"},
        {"path":"games/pacman/b4/derived/ghost_orange.svg","source":ROOT_GHOST_RAW,"transform":"replace ghost body+bottom #ffffff with cOrig #ff9900"},
        {"path":"games/pacman/b4/derived/ghost_frightened_blue.svg","source":FRIGHT_GHOST_RAW,"transform":"replace ghost body+bottom #ffffff with source frightened color #0033ff"},
    ]

    trace={
        "schema":1,
        "policy":"Every imported/derived asset traces to immutable games/pacman/decompiled raw. No redraws.",
        "stage":{"size_px":[360,420],"opening_visual_raw":"games/pacman/decompiled/frames/4.svg"},
        "shapes":shape_entries,
        "sprites":{"count":len(sprite_entries),"total_frame_svgs":total_sprite_frames},
        "sounds":{"count":len(sound_entries),"stream_files":stream_files},
        "fonts":font_entries,
        "texts":{"count":len(text_entries)},
        "derived":derived,
    }
    (out/"ASSET_TRACEABILITY.json").write_text(json.dumps(trace,indent=2,ensure_ascii=False)+"\n","utf-8")
    (out/"TIMELINE_CATALOG.json").write_text(json.dumps({"schema":1,"sprites":sprite_entries},indent=2,ensure_ascii=False)+"\n","utf-8")
    (out/"SOUND_CATALOG.json").write_text(json.dumps({"schema":1,"sounds":sound_entries,"stream_files":stream_files},indent=2,ensure_ascii=False)+"\n","utf-8")
    (out/"TEXT_CATALOG.json").write_text(json.dumps({"schema":1,"fonts":font_entries,"texts":text_entries},indent=2,ensure_ascii=False)+"\n","utf-8")

    print(f"[B4_CATALOG] shapes={len(shape_entries)} sprites={len(sprite_entries)} sprite_frames={total_sprite_frames} sounds={len(sound_entries)} streams={len(stream_files)} fonts={len(font_entries)} texts={len(text_entries)}")
    if len(shape_entries)!=36 or len(sprite_entries)!=25 or total_sprite_frames!=359 or len(sound_entries)!=13 or len(stream_files)!=1 or len(font_entries)!=3 or len(text_entries)!=27:
        raise SystemExit("B4 source accounting mismatch")


if __name__=="__main__":
    main()
