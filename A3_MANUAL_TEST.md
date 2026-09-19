# A3 Manual Test — Physical Phone

A3 automated evidence covers registry cards, Godot focus navigation, keyboard actions, module launch/exit, clean teardown and Web boot. This checklist is the required physical-touch acceptance.

## Test P — phone/touch

Open:

https://alexandresalazar89-blip.github.io/GameZone/

Record:

- Phone:
- Android/version:
- Browser/version:

Check:

- [ ] Hub boots and shows two game cards.
- [ ] Both cards show thumbnail, title and Play.
- [ ] Touch controls are hidden while on the hub.
- [ ] Tap Stub Tall card or Play -> game launches.
- [ ] Touch controls appear inside the game.
- [ ] Touch BACK -> returns to the hub.
- [ ] Hub is interactive immediately after return.
- [ ] Launch Stub Tall again -> works.
- [ ] Return by touch BACK again -> works.
- [ ] Launch Stub Wide -> works.
- [ ] Touch BACK -> returns to the hub.
- [ ] Relaunch Stub Wide -> works.
- [ ] No stale score/audio/input behaviour leaks from the previous game session.
- [ ] Portrait hub layout is usable.
- [ ] Landscape hub layout is usable.
- [ ] Settings -> master volume control reacts.
- [ ] Settings -> fullscreen toggle works from the button gesture.

Expected result:

`PHONE A3: PASS`

## Gamepad

Physical gamepad is **not FAIL**. It remains deferred under `BL-001`. A3 automated/browser tests validate the shared focus/action path without claiming physical hardware validation.
