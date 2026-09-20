# PACMAN_PORT_PLAN

Status: **B2 ORACLE CAPTURE COMPLETE WITH DOCUMENTED LIMITATIONS — STOP / WAIT FOR GO BEFORE B3.**

## Source of truth

- SWF: games/pacman/original/pacman.swf
- Source URL: https://raw.githubusercontent.com/AmmarSAA/flash-games-directory/main/pacman.swf
- SHA-256: e0a61ed23375aaacf92dcac91c24e6d0111612b420024756f0872f56fd59cb26
- Port rule: decompiled ActionScript + extracted SWF assets are authoritative. No arcade-original substitutions, redesigns, or guessed behavior.

## B0 toolchain — exact runner versions

- Java: **openjdk version 17.0.20.1 2026-08-18**
- FFDec release: **version26.3.0**
- FFDec asset: ffdec_26.3.0.zip
- Ruffle release: **nightly-2026-09-19**
- Ruffle asset: ruffle-nightly-2026_09_19-linux-x86_64.tar.gz
- Ruffle version command: Ruffle 0.7.0-nightly.2026.9.19-nightly (28f2fccd19db20fe9797097e24aa1c83d815c398 2026-09-19)

FFDec CLI flags were verified on the runner; the help header was:

~~~text
JPEXS Free Flash Decompiler v.26.3.0
------------------------------------
[1;4mUsage[m: <executable> [PRE-OPTIONS] [COMMAND]

[1;4mExecutable[m:
       Linux: ffdec or ffdec.sh
      Mac OS: ffdec.sh
     Windows: ffdec-cli.exe or ffdec.bat
~~~

## B0 SWF triage

- SWF signature/compression: **CWS / zlib**
- SWF version: **6**
- ActionScript VM: **AVM1**
- Decompiled source style: **ActionScript 1/2 timeline style**
- Frame rate: **21 fps**
- Fixed-step target: **1 / 21 s per SWF frame**
- Main timeline frame count: **10**
- Stage origin: **(0, 0) px**
- Stage size: **360 × 420 px**
- Stage RECT twips: {'xmin': 0, 'xmax': 7200, 'ymin': 0, 'ymax': 8400}
- SWF size: **42511 bytes**

### Definitions visible at B0

- Defined character tags: **109**
- Sprites: **25**
- Shapes: **36**
- Images: **0**
- Sounds: **13**
- Fonts: **3**
- Text definitions: **27**
- Buttons: **5**
- ActionScript files exported only for B0 readability triage: **65**

The full immutable FFDec export to games/pacman/decompiled is **not** performed until B1.

## Obfuscation / readability gate

Assessment: **no_obvious_obfuscation_in_b0**

- decompiled scripts: 65
- non-empty source lines: 1374
- readable control-flow/Flash API lines: 233
- replacement characters: 0
- very-long identifier hits: 0
- >500-char line ratio: 0.0007

If B1 exposes damaged or ambiguous logic, the port stops there instead of guessing.

## Real decompiled ActionScript excerpt

Selected file: scripts/frame_6/DoAction.as
Approx. starting line: 100

~~~actionscript
      nextX = 27;
      Pacman._x = OFFX + 336;
   }
   else if(Maze[pacX - 1][pacY] == "R")
~~~

Selection note: Highest B0 movement/character-logic score. The complete raw scripts are deferred to B1.

## Flash semantic contract

- _x/_y are pixels; Y points down.
- 20 twips = 1 px.
- _xscale/_yscale are percent.
- _rotation is degrees.
- _alpha is 0–100.
- Preserve Flash depth order and the SWF's actual hitTest usage.
- Drive gameplay by SWF frames at **21 fps** unless source explicitly uses time.
- Preserve symbol names, frame labels, variables and function names.

## Phase gates

- **B0 — COMPLETE:** triage only.
- **B1 — COMPLETE:** immutable FFDec export + ASSET_MANIFEST + SYMBOL_MAP + TIMELINE_MAP.
- **B2 — COMPLETE WITH DOCUMENTED LIMITATIONS:** observable Ruffle oracle, fixed-frame replays, deterministic score/power/tunnel references and multi-run RNG evidence. No successful level-clear or isolated 10,000 extra-life visual oracle was fabricated.
- **B3 — PENDING:** minimal Flash runtime shim.
- **B4 — PENDING:** SWF assets and timelines.
- **B5 — PENDING:** 1:1 ActionScript port.
- **B6 — PENDING:** A2 GameModule integration.
- **B7 — PENDING:** oracle behavior/frame diff and VERIFICATION.md.
- **B8 — PENDING:** Web packaging and Pages desktop/phone verification.

Single-threaded remains mandatory. Physical gamepad remains deferred under BL-001.

## B0 gate

**STOP HERE. Do not start B1 until explicit user GO.**


## B2/B7 determinism contract

Deterministic near-diff scope:
- maze layout;
- pellet +10 and power-pellet additional +40;
- wall collision;
- Pac-Man tunnel offsets +336/-12;
- ghost tunnel offsets +348/-24;
- extra-life threshold logic based on score / 10000 exactly as decompiled.

RNG rule/distribution scope:
- Flash random(n) returns an integer from 0 through n-1;
- !random(n) is true with probability 1/n;
- do not require frame/pixel-identical ghost trajectories against Ruffle;
- validate ghChoice legality, ghBest selection behavior, Shape._visible frightened branching;
- validate source-faithful Pacman.Hit / Shape.Hit collision, EatGhost scoring, and Ghost["K"+g] respawn.

Never replace this clone's ghost logic with arcade-original targeting.


## B2 oracle result

Final validated capture run: **#19 / 35498392611** at code candidate `e91a826dce009336e06419d4556b569651cf7d21`.

Ruffle is accepted as the observable gameplay oracle for this SWF:

- visual gameplay at 360x420 / 21 fps is functional;
- score, pellet removal, Pac-Man motion, ghosts and frightened visuals are captured;
- sound is audibly captured, but MP3 decoder warnings mean B7 uses audio event/presence comparison rather than sample-perfect PCM equality.

Deterministic references captured:

- pellet score `0→10→...→70`;
- power transition `170→220` (+10 +40);
- left and right tunnel wraps using shortest source-derived routes.

RNG references:

- five identical-input ghost runs, used only for rule/distribution validation;
- three long route attempts demonstrate death/Game Over variation and do not constitute a level-clear oracle.

Observable-only limitations:

- no successful level-clear capture was obtained before RNG deaths;
- 10,000-point extra-life cannot be isolated without multiple RNG-exposed levels or RNG scoring, so no internal state was injected to manufacture that oracle.

Canonical details: `games/pacman/oracle/B2_ACCEPTANCE.md` and `games/pacman/oracle/B2_SCENARIOS.json`.

**B3 has not started.**
