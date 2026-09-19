# A1 Manual Physical-Device Test Guide

Public build:

https://alexandresalazar89-blip.github.io/GameZone/

This guide is for the two acceptance tests that require real hardware and therefore must be performed manually.

A1 remains OPEN until both sections are reported PASS. Do not start A2 before that.

## A. Physical phone browser

### A1. Boot

1. On a real phone, open:
   `https://alexandresalazar89-blip.github.io/GameZone/`
2. Wait for **GameZone — A1 Web & Input Diagnostics**.
3. Before touching the Godot canvas, note the status panel.
4. Confirm these values:
   - `Runtime: Web`
   - the same line contains `single-thread preset`
   - `Touch capability: true`
   - `gamepads: none` unless a controller is already connected
5. The phone should automatically show the large on-screen controls:
   - `UP`, `DOWN`, `LEFT`, `RIGHT`
   - `A`, `B`, `PAUSE`, `BACK`
6. The input prompt should read:
   `TOUCH: on-screen D-pad = move • A/B • PAUSE • BACK`

**PASS:** the Godot diagnostics screen boots, the values above are visible, and the touch controls appear without pressing **Preview touch controls**.

**FAIL:** blank/failed Web page, `Runtime` is not `Web`, `Touch capability` is false, controls are missing, or the page is unusable.

### A2. First-touch audio unlock

1. Reload the page if necessary so no Godot control has been touched yet.
2. Observe:
   `Audio unlocked: false`
3. Touch any Godot control once, for example `A`.
4. Observe the status again.

**PASS:** after that first touch, the screen changes to `Audio unlocked: true` and stays true.

**FAIL:** it remains false after a valid touch inside the Godot canvas.

### A3. Touch InputMap actions

1. Hold `RIGHT`.
2. While holding it, inspect the Actions line.
3. The green square in the **MOVE TEST** area must move right.
4. Repeat with `LEFT`, `UP`, and `DOWN`.
5. Tap `A`, `B`, `PAUSE`, and `BACK`.

Expected live values while a direction is held:

- `[X] move_right`, or the corresponding direction.
- When released it returns to `[ ] move_right`.

Expected counter changes:

- A increases `Event counts — A:`
- B increases `B:`
- PAUSE increases `Pause:`
- BACK increases `Back:`

**PASS:** all four directions move the square and all four buttons reach the shared semantic actions/counters.

**FAIL:** any control only changes visually but does not activate the corresponding Action line/movement/counter.

### A4. Fullscreen from user gesture

1. Tap **Toggle fullscreen** directly.
2. If fullscreen is entered, tap it again to return.

**PASS:** the browser enters/exits fullscreen from that explicit user tap.

**FAIL:** no fullscreen transition occurs. If the browser/OS explicitly blocks fullscreen, report the phone model, OS, browser and exact behavior instead of marking PASS.

### A5. Responsive portrait / landscape

1. Test in portrait.
2. Confirm the diagnostics text can be read/scrolled and all touch controls can be reached.
3. Rotate to landscape.
4. Confirm the `viewport: <width>x<height>` values change.
5. Repeat one movement and one A-button press in landscape.

**PASS:** both orientations remain usable; controls are not clipped off-screen; scrolling works where needed; movement/actions still respond.

**FAIL:** important controls become unreachable, the layout overlaps so badly that it cannot be used, the canvas fails to resize, or input stops after rotation.

### Phone evidence to send back

Copy/fill this:

```text
PHONE TEST
Phone:
OS/version:
Browser/version:

Boot: PASS / FAIL
Touch controls auto-visible: PASS / FAIL
Runtime: Web: PASS / FAIL
Touch capability: true: PASS / FAIL
First-touch Audio unlocked false -> true: PASS / FAIL
D-pad movement + Actions [X]: PASS / FAIL
A/B/PAUSE/BACK counters: PASS / FAIL
Fullscreen: PASS / FAIL
Portrait responsive: PASS / FAIL
Landscape responsive: PASS / FAIL

Notes:
Screenshot(s):
```

## B. Physical gamepad hot-swap

Use a desktop/laptop browser if practical so the phone test stays independent.

### B1. Boot with no controller

1. Make sure the controller is disconnected.
2. Open:
   `https://alexandresalazar89-blip.github.io/GameZone/`
3. Confirm:
   - `Runtime: Web`
   - `gamepads: none`
   - on a non-touch desktop, `active input: keyboard_mouse`
   - prompt:
     `KEYBOARD/MOUSE: WASD / arrows = move • Space/Z or left click = A • X/Shift or right click = B • P = pause • Esc = back`

**PASS:** no phantom gamepad is listed and the keyboard/mouse prompt is active.

### B2. Connect after boot — hot-swap in

1. With the page already running, connect/pair the real controller.
2. Press one controller button once. Browsers may not expose the Gamepad API device until user interaction.
3. Observe the diagnostics.

Expected values:

- `active input: gamepad`
- `gamepads: <actual controller name> (#<id>)`
- prompt changes to:
  `GAMEPAD: left stick / D-pad = move • A = action A • B = action B • Start = pause • Back = back`

**PASS:** the controller appears without reloading and the prompt changes to GAMEPAD.

**FAIL:** it only works after reload, never appears, or the prompt remains keyboard/touch after controller input.

### B3. Gamepad InputMap actions

1. Move the left stick right, left, up and down.
2. Repeat using the physical D-pad.
3. Watch the green square and the Actions line.
4. Press controller `A`, `B`, `Start`, and `Back/Select/View` according to the controller.

Expected behavior:

- stick/D-pad changes the appropriate `move_*` item from `[ ]` to `[X]` and moves the green square.
- A increments `Event counts — A:`
- B increments `B:`
- Start increments `Pause:`
- Back increments `Back:`

**PASS:** all controls work through the same InputMap actions without keyboard/touch-specific game logic.

**FAIL:** any required action does not activate, uses an unexpected raw-key workaround, or movement/counters do not react.

### B4. Disconnect — hot-swap out

1. Disconnect or power off the controller while the page remains open.
2. Observe the status.

Expected:

- `gamepads: none`
- on desktop: `active input: keyboard_mouse`
- keyboard/mouse prompt returns.

**PASS:** the controller disappears and the prompt falls back without page reload.

**FAIL:** a stale controller remains listed, or `active input: gamepad`/GAMEPAD prompt remains stuck after the final gamepad is gone.

### B5. Reconnect — hot-swap recovery

1. Reconnect/pair the same controller while the page is still open.
2. Press one controller button once.
3. Confirm:
   - the controller name/ID reappears,
   - `active input: gamepad`,
   - GAMEPAD prompt returns.
4. Move with the stick and press A once more.

**PASS:** reconnect works without reload and movement/action input works again.

**FAIL:** reload is required, the device is listed but input no longer works, or prompts/actions fail to recover.

### Gamepad evidence to send back

Copy/fill this:

```text
GAMEPAD TEST
Computer/device:
OS/version:
Browser/version:
Controller model:
Connection: USB / Bluetooth / other

Boot with gamepads: none: PASS / FAIL
Connect after boot detected: PASS / FAIL
active input -> gamepad: PASS / FAIL
Controller name/#ID shown: PASS / FAIL
GAMEPAD prompt shown: PASS / FAIL
Left stick movement: PASS / FAIL
D-pad movement: PASS / FAIL
A counter: PASS / FAIL
B counter: PASS / FAIL
Start/Pause counter: PASS / FAIL
Back counter: PASS / FAIL
Disconnect -> gamepads none: PASS / FAIL
Disconnect -> keyboard/touch prompt restored: PASS / FAIL
Reconnect without reload: PASS / FAIL
Input works after reconnect: PASS / FAIL

Notes:
Screenshot(s):
```

## Gate rule

Both physical reports must be PASS before A1 is closed.

CI, Playwright mobile emulation, and a connected-device simulator are useful supporting evidence but do not replace these two real-hardware tests.
