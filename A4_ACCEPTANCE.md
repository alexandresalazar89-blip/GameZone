# A4 Acceptance Gate — Runtime PCK Packaging + Platform Acceptance

Status: **AUTOMATED + LIVE WEB PASS — PHYSICAL PHONE TEST PENDING USER ACCEPTANCE.**

Tested A4 code candidate:

`d1400ea787358e2a001768bb13c765668e987473`

GitHub Actions run:

https://github.com/alexandresalazar89-blip/GameZone/actions/runs/35454782035

Public Web build:

https://alexandresalazar89-blip.github.io/GameZone/

## What A4 proves

The platform now supports two registry source types:

- `source: "tree"` — game ships inside the main export.
- `source: "pack"` — game ships as an external runtime `.pck`.

The shell still discovers games only through `GameManager.get_installed_games()`; no per-game shell branch was added.

## Runtime Web PCK path

For `source: "pack"` on Web:

1. the base registry loads;
2. `pack_url` is resolved relative to the current page;
3. `window.fetch()` retrieves the PCK;
4. `response.arrayBuffer()` is converted to `PackedByteArray`;
5. bytes are written to `user://gamezone_packs/<id>.pck`;
6. `ProjectSettings.load_resource_pack(..., false)` mounts it;
7. metadata and entry scene are resolved from the newly mounted `res://games/<id>/...` namespace;
8. the module is added to the normal installed-game list and appears automatically in the hub.

The pack is not present as a normal base-project resource before mounting.

## Registry-driven pack build and staging

A4 also removes the last per-game hardcoded staging step.

- `tools/build_runtime_packs.gd` builds every `source: "pack"` entry from `games/registry.json`.
- `tools/stage_runtime_packs.gd` stages every built pack into the Web artifact using its registry `pack_url`.
- Adding another pack does not require a new shell branch or a new hardcoded copy command in the workflow.

## ADD_A_GAME validation

`ADD_A_GAME.md` was followed to add the validation module `stub_packed`.

It defines:

- `GameModule` implementation;
- metadata;
- pack source folder;
- registry entry;
- build source;
- runtime mount;
- Web `pack_url`.

The resulting game appears as **Runtime PCK Stub** in the hub with the two in-tree stubs, without shell-specific integration.

## Headless A4 evidence

From run #60:

```text
[A4_PACK_BUILD] PACK_BUILT id=stub_packed files=3 bytes=4440
[A4_PACK_BUILD] ALL_PACKS_OK count=1
[A4_TEST] PACK_TARGET_ABSENT_BEFORE_LOAD_OK
[A4] PACK_LOAD_OK id=stub_packed
[A4_TEST] PACK_RUNTIME_LOAD_OK games=3 packs=1
[A4_TEST] PACK_KEEP_ASPECT_OK native=256x192 display=(800.0, 600.0)
[A4_TEST] PACK_EXIT_CLEAN_OK
[A4_TEST] PACK_RELAUNCH_OK
[A4_TEST] SAVE_NAMESPACE_ALL_GAMES_OK
[A4_TEST] ALL_GAMES_CYCLE_OK
[A4_TEST] PLATFORM_ACCEPTANCE_SMOKE_OK
[A4_PACK_STAGE] PACK_STAGED id=stub_packed bytes=4440 url=packs/stub_packed.pck
[A4_PACK_STAGE] ALL_PACKS_STAGED_OK count=1
```

## Local Web evidence

The exported browser build fetched the runtime pack over HTTP, wrote it into the Web virtual filesystem, mounted it, then booted:

```text
[A4] PACK_HTTP_BEGIN id=stub_packed url=http://127.0.0.1:8080/packs/stub_packed.pck
[A4] PACK_HTTP_OK id=stub_packed status=200 bytes=4440
[A4] PACK_VFS_WRITE_OK id=stub_packed bytes=4440
[A4] PACK_LOAD_OK id=stub_packed
[A4] A4_BOOT_OK games=3 packs=1 cards=3
[A4_WEB_TEST] PACK_HTTP_LOAD_ORDER_OK
```

Desktop Chromium also launched and returned from all three games twice:

```text
[A4_WEB_TEST] ALL_GAMES_RELAUNCH_FLOW_OK {
  "allGames":["stub_packed","stub_tall","stub_wide"],
  "rounds":[
    ["stub_packed","stub_tall","stub_wide"],
    ["stub_packed","stub_tall","stub_wide"]
  ],
  "launchCount":6,
  "hubReturnCount":6,
  "relaunchEach":true,
  "audioTeardown":true
}
```

Pixel 7 browser emulation also booted the runtime-pack platform successfully.

## Live GitHub Pages evidence

The decisive Web proof ran against the deployed HTTPS site, not localhost:

```text
[A4] PACK_HTTP_BEGIN id=stub_packed url=https://alexandresalazar89-blip.github.io/GameZone/packs/stub_packed.pck
[A4] PACK_HTTP_OK id=stub_packed status=200 bytes=4440
[A4] PACK_VFS_WRITE_OK id=stub_packed bytes=4440
[A4] PACK_LOAD_OK id=stub_packed metadata=res://games/stub_packed/metadata.tres entry_scene=res://games/stub_packed/main.tscn
[A4] A4_BOOT_OK games=3 packs=1 cards=3
[A4_WEB_TEST] PACK_HTTP_LOAD_ORDER_OK
[A4_WEB_TEST] ALL_GAMES_RELAUNCH_FLOW_OK ...
[WEB_TEST] RESOURCE_OK index.html 200 https://alexandresalazar89-blip.github.io/GameZone/index.html
[WEB_TEST] RESOURCE_OK index.pck 200 https://alexandresalazar89-blip.github.io/GameZone/index.pck
[WEB_TEST] RESOURCE_OK index.wasm 200 https://alexandresalazar89-blip.github.io/GameZone/index.wasm
[WEB_TEST] RESOURCE_OK packs/stub_packed.pck 200 https://alexandresalazar89-blip.github.io/GameZone/packs/stub_packed.pck
[WEB_TEST] HTTPS_RESOURCES_OK
[WEB_TEST] COOP_COEP_ABSENT
[A4_WEB_TEST] DESKTOP_BOOT_OK
```

Run #60 conclusions:

- build: **success**
- runtime pack build: **success**
- A4 smoke: **success**
- local browser smoke: **success**
- Pages deploy: **success**
- live desktop smoke: **success**

## Aspect ratio and isolation

- `stub_packed`: native **256x192**, verified keep-aspect display **800x600** inside a 1000x600 host.
- `stub_tall`: native **240x320**.
- `stub_wide`: native **320x180**.
- The A2 SubViewport + keep-aspect/letterbox contract remains unchanged.
- Save namespaces for all three games remain isolated.
- Audio scopes return to zero after teardown.

## Web configuration

Recorded in `PLATFORM_VERSIONS.md`:

- Godot **4.7.2.stable.official.ed1daf0bf**
- Emscripten **4.0.20**
- **single-threaded**
- COOP: **absent**
- COEP: **absent**

## Deferred items

- `BL-001`: physical gamepad validation remains deferred due to unavailable hardware.
- `BL-002`: input remapping UI remains backlog.

Neither item was deleted or bypassed.

## Remaining acceptance — physical phone

Use `A4_MANUAL_TEST.md` against:

https://alexandresalazar89-blip.github.io/GameZone/

The required physical test is:

- see all 3 cards;
- launch **Runtime PCK Stub**;
- move via touch;
- touch BACK to return;
- relaunch the packed game;
- launch/return from both in-tree games;
- confirm no obvious state/audio/input bleed;
- confirm responsive hub remains usable.

## Gate

**STOP HERE. Part B / Pac-Man is not authorized until explicit user GO after the physical-phone A4 result.**
