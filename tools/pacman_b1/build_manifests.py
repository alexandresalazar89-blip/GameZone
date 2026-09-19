#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import xml.etree.ElementTree as ET

CHAR_ID_ATTRS = {
    "DefineShapeTag": "shapeId", "DefineShape2Tag": "shapeId", "DefineShape3Tag": "shapeId", "DefineShape4Tag": "shapeId",
    "DefineSpriteTag": "spriteId", "DefineSoundTag": "soundId",
    "DefineFontTag": "fontID", "DefineFont2Tag": "fontID", "DefineFont3Tag": "fontID", "DefineFont4Tag": "fontID",
    "DefineTextTag": "characterID", "DefineText2Tag": "characterID", "DefineEditTextTag": "characterID",
    "DefineButtonTag": "buttonId", "DefineButton2Tag": "buttonId",
}

KIND_MAP = {
    "DefineShapeTag": "shape", "DefineShape2Tag": "shape", "DefineShape3Tag": "shape", "DefineShape4Tag": "shape",
    "DefineSpriteTag": "sprite", "DefineSoundTag": "sound",
    "DefineFontTag": "font", "DefineFont2Tag": "font", "DefineFont3Tag": "font", "DefineFont4Tag": "font",
    "DefineTextTag": "text", "DefineText2Tag": "text", "DefineEditTextTag": "text",
    "DefineButtonTag": "button", "DefineButton2Tag": "button",
}


def digest(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def definition_id(tag):
    t = tag.attrib.get("type", "")
    attr = CHAR_ID_ATTRS.get(t)
    if not attr:
        return None
    value = tag.attrib.get(attr)
    return int(value) if value and value.isdigit() else None


def export_names(top_tags):
    by_id = {}
    occurrences = []
    for item in top_tags:
        if item.attrib.get("type") != "ExportAssetsTag":
            continue
        ids = [int(x.text) for x in (item.find("tags") or [])]
        names = [x.text or "" for x in (item.find("names") or [])]
        for cid, name in zip(ids, names):
            by_id.setdefault(cid, [])
            if name not in by_id[cid]:
                by_id[cid].append(name)
            occurrences.append({"character_id": cid, "name": name})
    return by_id, occurrences


def matrix_data(node):
    if node is None:
        return None
    out = {}
    for key in ["scaleX", "scaleY", "rotateSkew0", "rotateSkew1", "translateX", "translateY"]:
        if key in node.attrib:
            value = node.attrib[key]
            try:
                out[key] = float(value) if "." in value else int(value)
            except ValueError:
                out[key] = value
    return out


def timeline(container, timeline_id, kind, frame_count):
    frames = []
    current = {"frame": 1, "labels": [], "events": []}
    placements = []
    actions = []

    def finish_frame():
        nonlocal current
        frames.append(current)
        current = {"frame": current["frame"] + 1, "labels": [], "events": []}

    for item in list(container):
        t = item.attrib.get("type", "")
        if t == "FrameLabelTag":
            name = item.attrib.get("name", "")
            current["labels"].append(name)
            current["events"].append({"type": "frame_label", "name": name})
        elif t == "PlaceObject2Tag":
            ev = {
                "type": "place",
                "depth": int(item.attrib.get("depth", "0")),
                "character_id": int(item.attrib["characterId"]) if item.attrib.get("characterId", "").isdigit() else None,
                "instance_name": item.attrib.get("name") if item.attrib.get("placeFlagHasName") == "true" else None,
                "move": item.attrib.get("placeFlagMove") == "true",
                "matrix": matrix_data(item.find("matrix")),
            }
            current["events"].append(ev)
            placements.append({"timeline": timeline_id, "frame": current["frame"], **ev})
        elif t == "RemoveObject2Tag":
            current["events"].append({"type": "remove", "depth": int(item.attrib.get("depth", "0"))})
        elif t == "DoActionTag":
            if kind == "main":
                script = "scripts/frame_%d/DoAction.as" % current["frame"]
            else:
                script = "scripts/DefineSprite_%d/frame_%d/DoAction.as" % (timeline_id, current["frame"])
            current["events"].append({"type": "action", "script": script})
            actions.append({"timeline": timeline_id, "frame": current["frame"], "script": script})
        elif t == "StartSoundTag":
            current["events"].append({"type": "start_sound", "sound_id": int(item.attrib["soundId"]) if item.attrib.get("soundId", "").isdigit() else None})
        elif t == "SoundStreamHead2Tag":
            current["events"].append({"type": "sound_stream_head"})
        elif t == "ShowFrameTag":
            finish_frame()

    if (current["labels"] or current["events"]) and current["frame"] <= max(frame_count, 1):
        frames.append(current)

    return {
        "id": timeline_id,
        "kind": kind,
        "declared_frame_count": frame_count,
        "observed_frames": len(frames),
        "frames": frames,
        "placements": placements,
        "actions": actions,
    }


def source_hits(raw_root, patterns):
    result = {name: [] for name in patterns}
    base = raw_root / "scripts"
    if not base.exists():
        return result
    for path in sorted(base.rglob("*.as")):
        rel = str(path.relative_to(raw_root)).replace(os.sep, "/")
        for number, line in enumerate(path.read_text("utf-8", errors="replace").splitlines(), 1):
            for name, rx in patterns.items():
                if re.search(rx, line):
                    result[name].append({"file": rel, "line": number, "source": line.strip()})
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--swf", required=True)
    ap.add_argument("--xml", required=True)
    ap.add_argument("--raw", required=True)
    ap.add_argument("--ffdec-version", required=True)
    ap.add_argument("--out-dir", required=True)
    args = ap.parse_args()

    swf = Path(args.swf)
    raw = Path(args.raw)
    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)

    root = ET.parse(args.xml).getroot()
    top_tags = root.find("tags")
    if top_tags is None:
        raise SystemExit("FFDec XML has no top-level tags")

    files = []
    categories = {}
    extensions = {}
    for path in sorted(p for p in raw.rglob("*") if p.is_file()):
        rel = path.relative_to(raw)
        category = rel.parts[0].lower() if len(rel.parts) > 1 else "_root"
        ext = path.suffix.lower() or "(none)"
        entry = {
            "path": str(rel).replace(os.sep, "/"),
            "category": category,
            "bytes": path.stat().st_size,
            "sha256": digest(path),
        }
        files.append(entry)
        categories.setdefault(category, {"files": 0, "bytes": 0})
        categories[category]["files"] += 1
        categories[category]["bytes"] += entry["bytes"]
        extensions[ext] = extensions.get(ext, 0) + 1

    non_svg_shapes = [f["path"] for f in files if f["category"] == "shapes" and not f["path"].lower().endswith(".svg")]
    if non_svg_shapes:
        raise SystemExit("Raw shape export contains non-SVG files: " + ", ".join(non_svg_shapes))

    asset_manifest = {
        "schema": 1,
        "raw_root": "games/pacman/decompiled",
        "immutable_policy": "Raw FFDec output. Never hand-edit files under this root.",
        "source_swf": {"path": "games/pacman/original/pacman.swf", "bytes": swf.stat().st_size, "sha256": digest(swf)},
        "ffdec": args.ffdec_version,
        "export_types": ["script", "image", "shape", "sprite", "sound", "font", "frame", "text"],
        "formats": {
            "script": "as", "image": "FFDec default", "shape": "svg", "sprite": "svg",
            "sound": "mp3/wav/flv according to source encoding", "font": "ttf", "frame": "svg", "text": "plain"
        },
        "shape_vector_only_verified": not non_svg_shapes,
        "category_summary": dict(sorted(categories.items())),
        "extension_summary": dict(sorted(extensions.items())),
        "total_files": len(files),
        "total_bytes": sum(f["bytes"] for f in files),
        "files": files,
    }

    names_by_id, name_occurrences = export_names(top_tags)
    definitions = {}
    for item in top_tags:
        cid = definition_id(item)
        if cid is None:
            continue
        tag_type = item.attrib.get("type", "")
        info = {
            "character_id": cid,
            "tag_type": tag_type,
            "kind": KIND_MAP.get(tag_type, "other"),
            "export_names": names_by_id.get(cid, []),
        }
        if tag_type == "DefineSpriteTag":
            info["frame_count"] = int(item.attrib.get("frameCount", "0"))
        elif tag_type == "DefineSoundTag":
            info["sound_format"] = int(item.attrib.get("soundFormat", "0"))
            info["sound_rate"] = int(item.attrib.get("soundRate", "0"))
            info["sample_count"] = int(item.attrib.get("soundSampleCount", "0"))
        elif tag_type.startswith("DefineFont"):
            info["font_name"] = item.attrib.get("fontName")
        elif tag_type == "DefineEditTextTag":
            info["variable_name"] = item.attrib.get("variableName", "")
            info["font_id"] = int(item.attrib["fontId"]) if item.attrib.get("fontId", "").isdigit() else None
        definitions[cid] = info

    main_tl = timeline(top_tags, 0, "main", int(root.attrib.get("frameCount", "0")))
    sprite_tls = {}
    all_placements = list(main_tl["placements"])
    all_actions = list(main_tl["actions"])
    for item in top_tags:
        if item.attrib.get("type") != "DefineSpriteTag":
            continue
        sid = int(item.attrib["spriteId"])
        subtags = item.find("subTags")
        if subtags is None:
            continue
        tl = timeline(subtags, sid, "sprite", int(item.attrib.get("frameCount", "0")))
        sprite_tls[str(sid)] = tl
        all_placements.extend(tl["placements"])
        all_actions.extend(tl["actions"])

    placements_by_char = {}
    instances = {}
    for placement in all_placements:
        cid = placement.get("character_id")
        if cid is None:
            continue
        placements_by_char.setdefault(str(cid), []).append({
            "timeline": placement["timeline"], "frame": placement["frame"], "depth": placement["depth"],
            "instance_name": placement.get("instance_name"), "move": placement.get("move")
        })
        name = placement.get("instance_name")
        if name:
            instances.setdefault(name, [])
            ref = {"character_id": cid, "timeline": placement["timeline"], "frame": placement["frame"], "depth": placement["depth"]}
            if ref not in instances[name]:
                instances[name].append(ref)

    for cid, info in definitions.items():
        info["placements"] = placements_by_char.get(str(cid), [])

    symbol_map = {
        "schema": 1,
        "source_swf_sha256": digest(swf),
        "character_definitions": [definitions[k] for k in sorted(definitions)],
        "export_assets_occurrences": name_occurrences,
        "export_names_by_character_id": {str(k): v for k, v in sorted(names_by_id.items())},
        "instance_names": dict(sorted(instances.items())),
    }

    display = root.find("displayRect")
    timeline_map = {
        "schema": 1,
        "source_swf_sha256": digest(swf),
        "frame_rate": float(root.attrib.get("frameRate", "0")),
        "stage": {
            "frame_count": int(root.attrib.get("frameCount", "0")),
            "display_rect_twips": {
                "xmin": int(display.attrib.get("Xmin", "0")), "xmax": int(display.attrib.get("Xmax", "0")),
                "ymin": int(display.attrib.get("Ymin", "0")), "ymax": int(display.attrib.get("Ymax", "0")),
            },
        },
        "main": main_tl,
        "sprites": sprite_tls,
        "all_action_scripts": all_actions,
    }

    patterns = {
        "rng": r"\brandom\s*\(",
        "ghost_choice": r"\bghChoice\b|\bghBest\b",
        "frightened_visibility": r"Shape\._visible",
        "pacman_ghost_hittest": r"Pacman\.Hit\.hitTest\(Shape\.Hit\)|hitTest\(_root\.Pacman\.Hit\)",
        "eat_ghost": r"EatGhost|Ghost\[\"K\" \+ g\]",
        "score_plus_10": r"score\s*\+=\s*10",
        "score_plus_40": r"score\s*\+=\s*40",
        "extra_life_10000": r"score\s*/\s*10000",
        "pacman_tunnel_right": r"OFFX\s*\+\s*336",
        "pacman_tunnel_left": r"OFFX\s*-\s*12",
        "ghost_tunnel_right": r"OFFX\s*\+\s*348",
        "ghost_tunnel_left": r"OFFX\s*-\s*24",
    }
    evidence = source_hits(raw, patterns)

    determinism = {
        "flash_random_semantics_required": "random(n) returns an integer in [0,n-1]; !random(n) is true with probability 1/n.",
        "oracle_policy_for_b2_b7": {
            "deterministic_near_diff": [
                "maze layout", "pellet score +10", "power-pellet additional +40", "wall collision",
                "Pac-Man tunnel offsets +336/-12", "ghost tunnel offsets +348/-24",
                "extra-life threshold logic around score / 10000 exactly as source writes it",
            ],
            "rng_rule_distribution_only": [
                "ghost trajectories are not frame/pixel path-diffed against Ruffle",
                "directions must come from valid ghChoice entries",
                "Shape._visible frightened state changes random-vs-best choice exactly as written",
                "chase uses ghBest when source selects that branch",
                "ghost-eat collision/score/EatGhost/Ghost K respawn follows source hitTest/state transitions",
            ],
        },
        "source_evidence": evidence,
    }

    (out / "ASSET_MANIFEST.json").write_text(json.dumps(asset_manifest, indent=2, ensure_ascii=False) + "\n", "utf-8")
    (out / "SYMBOL_MAP.json").write_text(json.dumps(symbol_map, indent=2, ensure_ascii=False) + "\n", "utf-8")
    (out / "TIMELINE_MAP.json").write_text(json.dumps(timeline_map, indent=2, ensure_ascii=False) + "\n", "utf-8")
    (out / "DETERMINISM_POLICY.json").write_text(json.dumps(determinism, indent=2, ensure_ascii=False) + "\n", "utf-8")

    label_count = sum(len(f["labels"]) for f in main_tl["frames"])
    label_count += sum(len(f["labels"]) for tl in sprite_tls.values() for f in tl["frames"])

    report = []
    report.append("# B1_ACCEPTANCE")
    report.append("")
    report.append("Status: B1 EXTRACTION COMPLETE — STOP / WAIT FOR GO BEFORE B2.")
    report.append("")
    report.append("Immutable raw extraction:")
    report.append("- Source: games/pacman/original/pacman.swf")
    report.append("- SWF SHA-256: " + digest(swf))
    report.append("- FFDec: " + args.ffdec_version)
    report.append("- Raw root: games/pacman/decompiled")
    report.append("- Export types: script,image,shape,sprite,sound,font,frame,text")
    report.append("- Raw files: %d" % len(files))
    report.append("- Raw bytes: %d" % sum(f["bytes"] for f in files))
    report.append("- Shape SVG-only check: PASS")
    report.append("")
    report.append("No post-processing or hand-editing was performed inside games/pacman/decompiled.")
    report.append("")
    report.append("Generated maps:")
    report.append("- games/pacman/ASSET_MANIFEST.json")
    report.append("- games/pacman/SYMBOL_MAP.json")
    report.append("- games/pacman/TIMELINE_MAP.json")
    report.append("- games/pacman/DETERMINISM_POLICY.json")
    report.append("")
    report.append("Structure:")
    report.append("- Character definitions: %d" % len(definitions))
    report.append("- Main timeline frames: %d" % main_tl["declared_frame_count"])
    report.append("- Sprite timelines: %d" % len(sprite_tls))
    report.append("- Timeline ActionScript entries: %d" % len(all_actions))
    report.append("- Named instances: %d" % len(instances))
    report.append("- Frame labels: %d" % label_count)
    report.append("")
    report.append("Determinism frozen for B2/B7:")
    report.append("- Deterministic near-diff: maze, +10, +40, walls, tunnel offsets +336/-12 and +348/-24, extra-life logic.")
    report.append("- RNG rule/distribution only: Flash random(n), ghChoice/ghBest, Shape._visible, hitTest/EatGhost/Ghost K respawn.")
    report.append("- Never replace clone ghost logic with arcade targeting.")
    report.append("")
    report.append("Gate: STOP HERE. B2 has not started. Wait for explicit GO.")
    (out / "B1_ACCEPTANCE.md").write_text("\n".join(report) + "\n", "utf-8")


if __name__ == "__main__":
    main()
