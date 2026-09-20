# B4_ACCEPTANCE — Source Assets and Timelines

Status: **B4 COMPLETE / PASS — STOP / WAIT FOR GO BEFORE B5.**

Tested code candidate: `b55343ec28b072ab26a96157f1687b51dcf33a5b`

Validation workflow: **Pac-Man B4 Assets and Timelines #9 / run 35516659293**.

## Source accounting

- Shapes imported as Godot Texture2D: **36 / 36** raw SVG.
- Sprite timelines reconstructed: **25 / 25**.
- Raw sprite-frame SVG textures: **359 / 359**.
- Each timeline retains frame count, real labels and per-frame reconstructed depth state from `TIMELINE_MAP.json`.
- Discrete sounds imported: **13 / 13 MP3**.
- Streaming sound imported: **1 / 1 WAV**.
- Fonts: **2 embedded TTF** + font ID 49 Arial with zero glyphs using Godot fallback only where ID 49 is referenced.
- Text definitions catalogued: **27 / 27**.

All imported assets trace to immutable `games/pacman/decompiled` through `ASSET_TRACEABILITY.json`.

## Opening visual

B4 renders the immutable FFDec main frame 4 at native **360×420** and overlays only the four ActionScript-attached ghost clips at the fixed `initVars` positions. Pac-Man is already placed in the raw frame 4 at its source start coordinate.

B4 intentionally does **not** populate pellets from the logical `Maze[x][y]` string; consuming that game-state array is B5.

Comparison against the B2 Ruffle opening frame `pellet_line/reference/frames/f00106.png`:

- maze blue-mask F1: **0.999347** (required >= 0.90)
- maximum character color-centroid delta: **0.751 px** (required <= 4 px)
- result: **PASS**

Evidence: `artifacts/pacman_b4/imported_vs_oracle.png`.

## Timeline labels

The visual timeline renderer preserves the Flash symbol origin from each FFDec frame SVG and is driven by the B3 MovieClip shim.

Tested real labels include:

- Pac-Man sprite 40: `Die -> frame 6`; `gotoAndPlay("Die")` renders raw frame 6 then advances to raw frame 7.
- Snd sprite 92: `Chomp1 -> 2`, `Chomp2 -> 4`, `EatGhost -> 6`, `EatFruit -> 19`.
- Ghost sprite 19 raw frame 2 is addressable for the frightened visual state.

## Sound mapping

Direct ExportAssets mappings remain source-authoritative:

- 1 NewLev
- 2 ExLife
- 3 BGEyes
- 4 BGGhost
- 5 BG3
- 6 BG2
- 7 BG1

Timeline StartSound mappings:

- Chomp1 -> 88.mp3
- Chomp2 -> 89.mp3
- EatGhost -> 90.mp3
- EatFruit -> 91.mp3
- NewGame timeline -> 85.mp3 on the frame following label NewGame
- Killed timeline -> 86.mp3 on the frame following label Killed

FFDec also exported `sounds/-1.wav` as a streaming sound. The B1 timeline map does not uniquely bind that stream to a semantic label, so B4 imports and records it but does **not** invent a label association.

## Text/font handling

Dynamic/edit text definitions with known font IDs use the imported fonts directly. Score field ID 84 uses embedded Whimsy TT (font ID 21).

Font ID 49 is Arial with **0 embedded glyphs**. It uses `ThemeDB.fallback_font` only for text definitions that explicitly reference ID 49. No glyphs were fabricated.

Static DefineText artwork with no recoverable font ID in the B1 map is preserved exactly inside the FFDec sprite/frame SVGs rather than retyped.

## Scope gate

No maze array, pellet population, movement, ghost AI, scoring, collision rules or gameplay state machine was added.

Pac-Man remains absent from the permanent `games/registry.json`.

**B5 has not started.**
