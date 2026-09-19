# A3 Acceptance Gate — Shell UI / Hub

Status: **AUTOMATED + LIVE WEB PASS — PHYSICAL PHONE TOUCH TEST PENDING USER ACCEPTANCE.**

A3 tested code candidate:

`c06ff4e215046d19360a39241215d2ca5deee6b9`

GitHub Actions run:

https://github.com/alexandresalazar89-blip/GameZone/actions/runs/35449073729

Public Web build:

https://alexandresalazar89-blip.github.io/GameZone/

## Scope delivered

- The A2 harness was replaced by the real GameZone hub.
- The game grid is populated exclusively from `GameManager.get_installed_games()`.
- No per-game hardcoding is required in the shell.
- The two registered stubs are shown as cards with thumbnail, title and Play.
- The grid changes column count with available width.
- Touch on a card launches that game.
- Keyboard and gamepad use the shared semantic actions `move_*`, `action_a` and `back`.
- Godot focus is retained/restored between hub launches and returns.
- Physical gamepad remains deferred under `BL-001`; A3 validates keyboard and synthetic gamepad events through the same shell input path.
- Each game runs in its own `SubViewport`.
- Exit returns through `GameModule.game_exited` into the shared GameManager unload path.
- Esc, semantic gamepad BACK and the touch BACK control all request the same current-game exit.
- Game teardown removes the per-game audio scope; automated evidence reports `audio_scopes=0` after return.
- The A2 keep-aspect render contract remains unchanged: each module keeps its native viewport size and the shell uses keep-aspect centering/letterboxing rather than stretching.
- Web export remains single-threaded.
- Settings includes master volume and user-gesture fullscreen toggle.
- Input remapping remains the `BL-002` placeholder/backlog item.
- No A4 packaging work and no Pac-Man work has been started.

## A3 headless contract evidence

From run #50:

```text
[A3] A3_BOOT_OK games=2 cards=2
[A3_TEST] GRID_REGISTRY_OK ids=[&"stub_tall", &"stub_wide"]
[A3_TEST] KEYBOARD_FOCUS_NAV_OK first=stub_tall second=stub_wide
[A3] GAME_RUNNING id=stub_wide native=(320, 180)
[A3_TEST] KEYBOARD_ACTION_A_LAUNCH_OK id=stub_wide
[A3] HUB_RETURN from=stub_wide audio_scopes=0
[A3_TEST] KEYBOARD_BACK_TO_HUB_OK id=stub_wide
[A3_TEST] GAMEPAD_FOCUS_NAV_EMULATION_OK id=stub_tall
[A3] GAME_RUNNING id=stub_tall native=(240, 320)
[A3] HUB_RETURN from=stub_tall audio_scopes=0
[A3_TEST] GAMEPAD_ACTIONS_EMULATION_OK id=stub_tall
[A3_TEST] RELAUNCH_TEARDOWN_OK id=stub_tall
[A3_TEST] HUB_SMOKE_OK
```

## Local Web evidence

Desktop Chromium:

```text
[A3] A3_BOOT_OK games=2 cards=2
[A3_WEB_TEST] KEYBOARD_FOCUS_FLOW_OK {"focusNavigation":true,"firstLaunchId":"stub_tall","secondLaunchId":"stub_wide","launchCount":2,"hubReturnCount":2}
[WEB_TEST] RESOURCE_OK index.html 200
[WEB_TEST] RESOURCE_OK index.pck 200
[WEB_TEST] RESOURCE_OK index.wasm 200
[A3_WEB_TEST] DESKTOP_BOOT_OK
```

Pixel 7 browser emulation:

```text
[A3] A3_BOOT_OK games=2 cards=2
[WEB_TEST] RESOURCE_OK index.html 200
[WEB_TEST] RESOURCE_OK index.pck 200
[WEB_TEST] RESOURCE_OK index.wasm 200
[A3_WEB_TEST] MOBILE_BOOT_OK
```

## Live GitHub Pages evidence

```text
[A3] A3_BOOT_OK games=2 cards=2
[A3] GAME_RUNNING id=stub_tall native=(240, 320)
[A3] HUB_RETURN from=stub_tall audio_scopes=0
[A3] GAME_RUNNING id=stub_wide native=(320, 180)
[A3] HUB_RETURN from=stub_wide audio_scopes=0
[A3_WEB_TEST] KEYBOARD_FOCUS_FLOW_OK {"focusNavigation":true,"firstLaunchId":"stub_tall","secondLaunchId":"stub_wide","launchCount":2,"hubReturnCount":2}
[WEB_TEST] RESOURCE_OK index.html 200 https://alexandresalazar89-blip.github.io/GameZone/index.html
[WEB_TEST] RESOURCE_OK index.pck 200 https://alexandresalazar89-blip.github.io/GameZone/index.pck
[WEB_TEST] RESOURCE_OK index.wasm 200 https://alexandresalazar89-blip.github.io/GameZone/index.wasm
[WEB_TEST] HTTPS_RESOURCES_OK
[WEB_TEST] COOP_COEP_ABSENT
[A3_WEB_TEST] DESKTOP_BOOT_OK {"width":1440,"height":900,"clientWidth":1440,"clientHeight":900}
```

Run #50 conclusions:

- build: **success**
- deploy: **success**
- live-desktop-smoke: **success**

## Remaining acceptance — physical phone

Use the published Pages build and complete the checklist in `A3_MANUAL_TEST.md`.

Reply with `PHONE A3: PASS` plus any issue you see.

## Gate

**STOP HERE. A4 is not authorized until explicit user GO after the physical-phone A3 acceptance.**
