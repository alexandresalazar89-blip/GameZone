# A1 Acceptance Gate

Status: **OPEN. The final single-threaded Web build is live and desktop-verified. A1 closes only after the physical-phone and physical-gamepad reports are returned PASS. A2 must not start before that.**

## Final automated evidence — 2026-09-19

Public build:

https://alexandresalazar89-blip.github.io/GameZone/

Final candidate commit:

`a469454e6aa2ca1e5edaf49e24e31566a05ecc8a`

Final GitHub Actions run:

https://github.com/alexandresalazar89-blip/GameZone/actions/runs/35446087718

Results:

- Build: **PASS**
- Godot: **4.7.2-stable official**
- Web export: **PASS**
- Export mode: **single-threaded**
- Headless A1 smoke: **PASS**
- Local Chromium Web boot: **PASS**
- Local Pixel 7 emulation: **PASS** — supporting evidence only, not the physical-phone gate
- GitHub Pages deploy: **PASS**
- Live HTTPS Chromium smoke: **PASS**
- Live browser console: `[A1] A1_BOOT_OK`
- Live runtime log: `Emscripten 4.0.20, single-threaded, no GDExtension support.`
- Live `index.html`: **HTTP 200 over HTTPS**
- Live `index.pck`: **HTTP 200 over HTTPS**
- Live `index.wasm`: **HTTP 200 over HTTPS**
- COOP header: **absent**
- COEP header: **absent**
- Browser page errors: **none**

Final live resource evidence:

```text
[A1_WEB_TEST] RESOURCE_OK index.html 200 https://alexandresalazar89-blip.github.io/GameZone/index.html
[A1_WEB_TEST] RESOURCE_OK index.pck 200 https://alexandresalazar89-blip.github.io/GameZone/index.pck
[A1_WEB_TEST] RESOURCE_OK index.wasm 200 https://alexandresalazar89-blip.github.io/GameZone/index.wasm
[A1_WEB_TEST] HTTPS_RESOURCES_OK
[A1_WEB_TEST] COOP_COEP_ABSENT
[A1_WEB_TEST] DESKTOP_BOOT_OK {"width":1440,"height":900,"clientWidth":1440,"clientHeight":900}
```

The live screenshot and JSON evidence are stored in the workflow artifact `a1-live-desktop-evidence`.

## Definition of done

| Target | Required evidence | Current status |
|---|---|---|
| Desktop browser | Live HTTPS URL, `A1_BOOT_OK`, screenshot, no page errors | **PASS** |
| Real phone browser | Physical phone boot, touch controls, first-touch audio unlock, fullscreen gesture, portrait/landscape responsive proof | **PENDING USER PHYSICAL TEST** |
| Actual connected gamepad | Connect after boot, prompt/device detection, all InputMap actions, disconnect/reconnect hot-swap proof | **PENDING USER PHYSICAL TEST** |

## Hot-swap correction included in final candidate

The final A1 candidate explicitly falls back from `gamepad` to `keyboard_mouse` or `touch` when the last connected gamepad is removed, so prompts do not remain stale after disconnect.

## Manual physical-device procedure

Use:

`A1_MANUAL_TEST.md`

It contains copy/paste PASS/FAIL forms tied to the exact values displayed by `a1_diagnostics.gd`.

## Gate rule

Do **not** begin A2 because CI and desktop are green. A1 closes only after both physical reports are returned PASS.
