# A2 — Game Module Contract

Status: implementation in progress.

## Stable module surface

Every game entry scene must instantiate a node derived from `GameModule`.

Required lifecycle:

- `start(context)`
- `pause()`
- `resume()`
- `teardown()`

Signals:

- `game_exited`
- `score_changed(value)`
- `state_saved(data)`

## GameContext

A game receives only its scoped context:

- `game_id`
- dedicated `SubViewport`
- game-scoped audio facade
- game-scoped save facade
- semantic InputMap action names
- `exit()`

Games must not navigate the shell scene tree or access another game's save/audio namespace.

## Aspect ratio

Each metadata resource declares `native_size`. The GameManager renders the game into a SubViewport at exactly that size. The shell displays that texture using keep-aspect-centered scaling over a black host surface, giving letterbox/pillarbox instead of stretching the game.

This deliberately does not use `SubViewportContainer.stretch=true`, because that mode resizes the SubViewport to the shell container. The module's logical render resolution remains stable.

## Input rule

Game modules read only semantic actions such as `move_left`, `action_a`, `pause`, and `back`. They do not read raw keycodes, joypad buttons, or touch events.
