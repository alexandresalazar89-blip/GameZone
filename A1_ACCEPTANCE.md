# A1 Acceptance Gate

Status: **A1 implementation and CI browser boot are complete. The acceptance gate remains OPEN until the live GitHub Pages build is enabled and tested on a physical phone and an actual gamepad. A2 must not start before that.**

## Current evidence — 2026-09-19

Exact main build workflow:

- GitHub Actions run: https://github.com/alexandresalazar89-blip/GameZone/actions/runs/35444949329
- Build job: **PASS**
- Godot: **4.7.2-stable official**
- Web mode: **single-threaded**
- Headless contract smoke: **PASS**
- Browser smoke: **PASS**
- Pages deploy: **BLOCKED — repository Pages site is not enabled yet**\n- Auto-enablement attempt: https://github.com/alexandresalazar89-blip/GameZone/actions/runs/35445339492 — build **PASS**, deploy **FAIL** because the GitHub integration is not permitted to create the Pages site

Independent PR validation of the same A1 code path:

- Validation run: https://github.com/alexandresalazar89-blip/GameZone/actions/runs/35444954910
- Build job: **PASS**
- `[A1_TEST] KEYBOARD_MOUSE_GAMEPAD_BINDINGS_OK`
- `[A1_TEST] TOUCH_SCENE_OK`
- `[A1_TEST] HEADLESS_SMOKE_OK`
- Export produced:
  - `index.html` — 5,437 bytes
  - `index.pck` — 25,992 bytes
  - `index.wasm` — 39,514,754 bytes
- Desktop Chromium boot:
  - `[A1] A1_BOOT_OK`
  - `[A1_WEB_TEST] DESKTOP_BOOT_OK {"width":1440,"height":900,"clientWidth":1440,"clientHeight":900}`
- Pixel 7 browser emulation boot:
  - `[A1] A1_BOOT_OK`
  - `[A1_WEB_TEST] MOBILE_BOOT_OK {"width":1081,"height":2202,"clientWidth":411,"clientHeight":838}`

The mobile emulation screenshot proves the responsive/touch layout renders, but **does not count as the required physical-phone acceptance test**.

## Live deployment blocker

The main build successfully created and uploaded the Pages artifact. The deploy job then failed at `Configure Pages` with:

```text
Get Pages site failed. Please verify that the repository has Pages enabled
and configured to build using GitHub Actions.
Error: Not Found
```

`actions/configure-pages@v6` was also retried with `enablement: true`. GitHub returned `Create Pages site failed: Resource not accessible by integration`, so this cannot be completed through the connected GitHub App.\n\nOne repository setting is required:

1. Open **GameZone → Settings → Pages**.
2. Under **Build and deployment**, set **Source** to **GitHub Actions**.

After that setting is enabled, the open validation PR https://github.com/alexandresalazar89-blip/GameZone/pull/2 can be rerun to prove the live HTTPS boot, and the main deployment can be rerun. The intended live URL is:

```text
https://alexandresalazar89-blip.github.io/GameZone/
```

## Definition of done

A1 is done only when the same single-threaded Godot Web export boots and is evidenced on:

| Target | Required evidence | Current status |
|---|---|---|
| Desktop browser | Live HTTPS URL, screenshot, browser console containing `A1_BOOT_OK`, keyboard/mouse action proof | **CI browser boot passed; live Pages test pending enablement** |
| Real phone browser | Screenshot from a physical phone showing the live build, touch controls visible, action/movement proof | **Pending physical device** |
| Actual connected gamepad | Screenshot showing controller name/ID and active input = `gamepad`, movement/A/B/Start/Back and hot-swap proof | **Pending physical controller** |

## Where build and tests run

- Godot import/headless smoke: **GitHub Actions CI, Ubuntu runner**
- Godot Web release export: **GitHub Actions CI, Ubuntu runner**
- Godot version: **4.7.2-stable**
- Export mode: **single-threaded**
- Deployment target: **GitHub Pages HTTPS**
- Automated desktop browser: **Chromium/Playwright in GitHub Actions**
- Automated mobile layout: **Pixel 7 emulation/Playwright; supplementary only**
- Physical phone: **real phone against the exact Pages build**
- Physical gamepad: **real controller against the exact Pages build**

## Physical phone procedure

1. Open the GitHub Pages URL in the phone browser.
2. Confirm the page shows `Runtime: Web`.
3. Confirm `Touch capability: true`.
4. Confirm the large on-screen D-pad, A, B, PAUSE and BACK controls are automatically visible.
5. Move the green square with the on-screen D-pad.
6. Press A and B and confirm their event counters increment.
7. Confirm the layout remains usable in portrait and landscape.
8. Test **Enable / resume audio**.
9. Test **Toggle fullscreen** from its button.
10. Capture a screenshot including diagnostics and controls.

Record browser, phone model, OS version, screenshot and result.

## Physical gamepad procedure

1. Open the same live HTTPS URL with an actual controller connected.
2. Press a controller button once so the browser exposes it to the Gamepad API.
3. Confirm diagnostics change to `active input: gamepad`.
4. Confirm the controller name/ID appears under `gamepads`.
5. Verify left stick and D-pad move the green square.
6. Verify controller A increments Action A, B increments Action B, Start increments Pause, and Back increments Back.
7. Disconnect the controller and confirm the gamepad list updates.
8. Reconnect, press a button and confirm hot-swap works again.
9. Capture screenshots before/after hot-swap and record browser/OS/controller model.

## Gate rule

Do **not** begin A2 because CI is green. A1 closes only after the live build boots and the desktop + physical phone + physical gamepad evidence has been recorded.
