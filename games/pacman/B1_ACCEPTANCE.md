# B1_ACCEPTANCE

Status: B1 EXTRACTION COMPLETE — STOP / WAIT FOR GO BEFORE B2.

Immutable raw extraction:
- Source: games/pacman/original/pacman.swf
- SWF SHA-256: e0a61ed23375aaacf92dcac91c24e6d0111612b420024756f0872f56fd59cb26
- FFDec: 26.3.0
- Raw root: games/pacman/decompiled
- Export types: script,image,shape,sprite,sound,font,frame,text
- Raw files: 513
- Raw bytes: 836533
- Shape SVG-only check: PASS

No post-processing or hand-editing was performed inside games/pacman/decompiled.

Generated maps:
- games/pacman/ASSET_MANIFEST.json
- games/pacman/SYMBOL_MAP.json
- games/pacman/TIMELINE_MAP.json
- games/pacman/DETERMINISM_POLICY.json

Structure:
- Character definitions: 109
- Main timeline frames: 10
- Sprite timelines: 25
- Timeline ActionScript entries: 59
- Named instances: 48
- Frame labels: 17
- Non-timeline ActionScript files (button/clip actions): 13
- Font definitions: 3; exported TTF files: 2; zero-glyph font IDs: [49]
- Bitmap image definitions: 0; exported image files: 0

Determinism frozen for B2/B7:
- Deterministic near-diff: maze, +10, +40, walls, tunnel offsets +336/-12 and +348/-24, extra-life logic.
- RNG rule/distribution only: Flash random(n), ghChoice/ghBest, Shape._visible, hitTest/EatGhost/Ghost K respawn.
- Never replace clone ghost logic with arcade targeting.

Gate: STOP HERE. B2 has not started. Wait for explicit GO.
