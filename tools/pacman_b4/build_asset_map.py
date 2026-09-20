#!/usr/bin/env python3
import json, re, hashlib
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT=Path("games/pacman")
RAW=ROOT/"decompiled"
XLINK="{http://www.w3.org/1999/xlink}href"
FFCHAR="{https://www.free-decompiler.com/flash}characterId"

def sha(p):
    h=hashlib.sha256()
    h.update(Path(p).read_bytes())
    return h.hexdigest()

manifest=json.loads((ROOT/"ASSET_MANIFEST.json").read_text())
symbols=json.loads((ROOT/"SYMBOL_MAP.json").read_text())
timeline=json.loads((ROOT/"TIMELINE_MAP.json").read_text())

files={x["path"]:x for x in manifest["files"]}

# Shapes: exact FFDec raw SVGs.
shapes=[]
for rel,entry in sorted(files.items()):
    m=re.fullmatch(r"shapes/(\d+)\.svg",rel)
    if m:
        shapes.append({"id":int(m.group(1)),"raw_source":"res://games/pacman/decompiled/"+rel,"sha256":entry["sha256"]})
assert len(shapes)==36, len(shapes)

# Sprites: exact FFDec-rendered timeline frames, plus labels/depth events from TIMELINE_MAP.
sprite_frames={}
sprite_dir_names={}
for rel,entry in files.items():
    m=re.fullmatch(r"sprites/(DefineSprite_(\d+)(?:_[^/]+)?)/(\d+)\.svg",rel)
    if not m: continue
    folder,sid,frame=m.group(1),int(m.group(2)),int(m.group(3))
    sprite_dir_names[sid]=folder
    sprite_frames.setdefault(sid,[]).append({
        "frame":frame,
        "raw_source":"res://games/pacman/decompiled/"+rel,
        "sha256":entry["sha256"],
    })

sprites=[]
for sid_s,tl in sorted(timeline["sprites"].items(),key=lambda kv:int(kv[0])):
    sid=int(sid_s)
    frames=sorted(sprite_frames.get(sid,[]),key=lambda x:x["frame"])
    if len(frames)!=int(tl["declared_frame_count"]):
        raise SystemExit(f"sprite {sid}: raw frames {len(frames)} != declared {tl['declared_frame_count']}")
    labels={}
    depth_events={}
    for f in tl["frames"]:
        for label in f.get("labels",[]):
            labels[label]=int(f["frame"])
        depth_events[str(f["frame"])]=[
            e for e in f.get("events",[])
            if e.get("type") in ("place","remove")
        ]
    sprites.append({
        "id":sid,
        "raw_dir":"res://games/pacman/decompiled/sprites/"+sprite_dir_names[sid],
        "frame_count":int(tl["declared_frame_count"]),
        "frames":frames,
        "labels":labels,
        "depth_events":depth_events,
        "timeline_source":"res://games/pacman/TIMELINE_MAP.json",
    })
assert len(sprites)==25, len(sprites)
assert sum(len(x["frames"]) for x in sprites)==359

# Sound definitions and the one stream.
sound_defs={x["character_id"]:x for x in symbols["character_definitions"] if x["kind"]=="sound"}
sounds=[]
for rel,entry in sorted(files.items()):
    if not rel.startswith("sounds/"): continue
    name=Path(rel).name
    m=re.match(r"(-?\d+)",name)
    sid=int(m.group(1))
    d=sound_defs.get(sid,{})
    triggers=[]
    for export_name in d.get("export_names",[]):
        triggers.append({"type":"export_name","name":export_name})
    for spr_id,tl in timeline["sprites"].items():
        nearest_label=None
        for f in tl["frames"]:
            if f.get("labels"):
                nearest_label=f["labels"][-1]
            for e in f.get("events",[]):
                if e.get("type")=="start_sound" and e.get("sound_id")==sid:
                    triggers.append({
                        "type":"timeline_start_sound",
                        "sprite_id":int(spr_id),
                        "frame":int(f["frame"]),
                        "frame_labels":list(f.get("labels",[])),
                        "nearest_preceding_label":nearest_label,
                    })
    if sid==-1:
        triggers.append({"type":"stream_sound","name":"main_timeline_stream"})
    sounds.append({
        "id":sid,
        "raw_source":"res://games/pacman/decompiled/"+rel,
        "sha256":entry["sha256"],
        "export_names":d.get("export_names",[]),
        "triggers":triggers,
    })
assert len(sounds)==14, len(sounds)
assert len([x for x in sounds if x["raw_source"].endswith(".mp3")])==13
assert len([x for x in sounds if x["raw_source"].endswith(".wav")])==1

# Fonts.
font_paths={}
for rel,entry in files.items():
    if rel.startswith("fonts/"):
        m=re.match(r"(\d+)_",Path(rel).name)
        if m:
            font_paths[int(m.group(1))]=("res://games/pacman/decompiled/"+rel,entry["sha256"])

fonts=[]
for d in [x for x in symbols["character_definitions"] if x["kind"]=="font"]:
    fid=d["character_id"]
    if fid in font_paths:
        path,digest=font_paths[fid]
        fonts.append({"id":fid,"font_name":d.get("font_name","").replace("\u0000",""),"glyph_count":d.get("glyph_count",0),"raw_source":path,"sha256":digest,"fallback":False})
    else:
        fonts.append({"id":fid,"font_name":d.get("font_name","").replace("\u0000",""),"glyph_count":d.get("glyph_count",0),"raw_source":None,"sha256":None,"fallback":True,"fallback_policy":"Godot ThemeDB fallback font; source embeds zero glyphs, so no glyphs are fabricated"})
assert len(fonts)==3
assert sum(1 for x in fonts if not x["fallback"])==2
assert [x["id"] for x in fonts if x["fallback"]]==[49]

# Resolve static text font family from raw SVG references whenever SYMBOL_MAP lacks font_id.
family_to_id={"Whimsy_TT":21,"Verdana":43,"Arial":49}
svg_paths=[RAW/entry["path"] for entry in manifest["files"] if entry["path"].endswith(".svg")]

def infer_font_id(text_id):
    needle=str(text_id)
    for p in svg_paths:
        try:
            root=ET.parse(p).getroot()
        except Exception:
            continue
        id_map={el.attrib.get("id"):el for el in root.iter() if el.attrib.get("id")}
        refs=[]
        for el in root.iter():
            if el.attrib.get(FFCHAR)==needle:
                href=el.attrib.get(XLINK,"")
                if href.startswith("#"):
                    refs.append(href[1:])
        for rid in refs:
            node=id_map.get(rid)
            if node is None: continue
            for child in node.iter():
                href=child.attrib.get(XLINK,"")
                if not href.startswith("#font_"): continue
                body=href[len("#font_"):]
                for family,fid in family_to_id.items():
                    if body.startswith(family+"_"):
                        return fid
    return None

text_defs={x["character_id"]:x for x in symbols["character_definitions"] if x["kind"]=="text"}
texts=[]
for rel,entry in sorted(files.items()):
    m=re.fullmatch(r"texts/(\d+)\.txt",rel)
    if not m: continue
    tid=int(m.group(1))
    d=text_defs[tid]
    explicit=d.get("font_id")
    inferred=explicit if explicit is not None else infer_font_id(tid)
    content=(RAW/rel).read_text("utf-8",errors="replace")
    texts.append({
        "id":tid,
        "raw_source":"res://games/pacman/decompiled/"+rel,
        "sha256":entry["sha256"],
        "text":content,
        "variable_name":d.get("variable_name",""),
        "font_id":inferred,
        "font_resolution":"SYMBOL_MAP explicit" if explicit is not None else ("raw SVG glyph reference" if inferred is not None else "none"),
        "placements":d.get("placements",[]),
    })
assert len(texts)==27, len(texts)

out={
    "schema":1,
    "policy":"B4 imports only FFDec raw assets. No artwork is redrawn. Logical Maze[x][y], movement, AI and scoring remain B5.",
    "native_stage":[360,420],
    "main_visual":{
        "raw_source":"res://games/pacman/decompiled/frames/4.svg",
        "sha256":files["frames/4.svg"]["sha256"],
        "note":"Static SWF frame-4 visual composition. Dynamic pellet placement is intentionally absent because it derives from the B5 Maze[x][y] source state."
    },
    "shapes":shapes,
    "sprites":sprites,
    "sounds":sounds,
    "fonts":fonts,
    "texts":texts,
    "initial_visual_state":{
        "source":"res://games/pacman/decompiled/scripts/frame_4/DoAction.as",
        "offset_px":[18,18],
        "pacman":{"position":[186,294],"sprite_id":40,"frame":1},
        "ghosts":[
            {"index":1,"position":[180,150],"body_sprite_id":14,"eyes_sprite_id":16,"rgb":14483456},
            {"index":2,"position":[180,192],"body_sprite_id":14,"eyes_sprite_id":16,"rgb":16751001},
            {"index":3,"position":[156,192],"body_sprite_id":14,"eyes_sprite_id":16,"rgb":6750207},
            {"index":4,"position":[204,192],"body_sprite_id":14,"eyes_sprite_id":16,"rgb":16750848}
        ],
        "frightened":{"body_rgb":13311,"eyes_sprite_id":18},
        "note":"Only source-defined starting visual placement/color is reproduced in B4; no movement/state update logic."
    },
    "traceability_sources":[
        "res://games/pacman/ASSET_MANIFEST.json",
        "res://games/pacman/SYMBOL_MAP.json",
        "res://games/pacman/TIMELINE_MAP.json"
    ]
}
(ROOT/"B4_ASSET_MAP.json").write_text(json.dumps(out,indent=2,ensure_ascii=False)+"\n","utf-8")
print(json.dumps({
    "shapes":len(shapes),"sprites":len(sprites),"sprite_frames":sum(len(x["frames"]) for x in sprites),
    "sounds":len(sounds),"fonts_embedded":sum(1 for x in fonts if not x["fallback"]),
    "font_fallbacks":[x["id"] for x in fonts if x["fallback"]],"texts":len(texts)
},indent=2))
