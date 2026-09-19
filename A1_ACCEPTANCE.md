# A1 Acceptance Gate

Status: **implementation/CI in progress; A1 is not accepted until all physical-device rows pass.**

A1 is done only when the same single-threaded Godot Web export boots and is evidenced on:

| Target | Required evidence | Status |
|---|---|---|
| Desktop browser | Live HTTPS URL, screenshot, browser console containing `A1_BOOT_OK`, keyboard action/movement visible | Pending CI/live deployment |
| Real phone browser | Screenshot from a physical phone showing the live build, touch controls visible, action/movement proof | **Pending physical device** |
| Actual connected gamepad | Screenshot showing the controller name/ID and active input = `gamepad`, plus movement/A/B/Start/Back proof | **Pending physical controller** |

Playwright mobile emulation is used only as an additional responsive smoke test. It **does not** satisfy the real-phone row.

## Where build and tests run

- Godot import/headless smoke: **GitHub Actions CI, Ubuntu runner**
- Godot Web release export: **GitHub Actions CI, Ubuntu runner**
- Godot version: **4.7.2-stable**
- Export mode: **single-threaded**
- Deployment target: **GitHub Pages HTTPS**
- Automated desktop-browser smoke: **Chromium/Playwright in GitHub Actions**
- Automated mobile-layout smoke: **Pixel 7 emulation/Playwright in GitHub Actions; supplementary only**
- Physical phone test: **must use a real phone against the exact GitHub Pages build**
- Physical gamepad test: **must use a real controller connected to a browser device against the exact GitHub Pages build**

## Physical phone procedure

1. Open the GitHub Pages URL in the phone browser.
2. Confirm the page shows `Runtime: Web`.
3. Confirm `Touch capability: true`.
4. Confirm the on-screen D-pad, A, B, PAUSE and BACK controls are automatically visible.
5. Move the green square with the on-screen D-pad.
6. Press A and B and confirm the event counters increment.
7. Rotate or resize if desired and confirm the UI remains usable.
8. Capture a screenshot including the diagnostics and controls.

Record browser, phone model, OS version, screenshot, result, and any browser console/log evidence available.

## Physical gamepad procedure

1. Open the same GitHub Pages URL over HTTPS on a browser with the controller connected.
2. Press a controller button once. Browser Gamepad API implementations commonly do not expose a controller until interaction.
3. Confirm diagnostics change to `active input: gamepad`.
4. Confirm a controller name/ID appears under `gamepads`.
5. Verify left stick and D-pad move the green square.
6. Verify controller A increments Action A, B increments Action B, Start increments Pause, and Back increments Back.
7. Disconnect the controller and confirm the gamepad list updates.
8. Reconnect, press a button, and confirm hot-swap works again.
9. Capture screenshots before/after hot-swap and record browser/OS/controller model.

## Gate rule

Do **not** begin A2 merely because CI is green. A1 closes only after the live build boots and the desktop + physical phone + physical gamepad evidence has been recorded.
