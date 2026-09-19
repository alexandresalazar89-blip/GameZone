# ADD_A_GAME.md

GameZone supports two registration modes without editing shell code:

1. **In-tree game** — resources ship inside the main Web export.
2. **Runtime PCK game** — the browser downloads a separate `.pck`, writes it to the Web virtual filesystem, loads it with `ProjectSettings.load_resource_pack()`, then resolves the module metadata/entry scene.

The shell discovers both forms exclusively through `games/registry.json`.

## Stable module contract

Every game entry scene must have a root that extends `GameModule`.

Required lifecycle:

- `start(context)`
- `pause()`
- `resume()`
- `teardown()`

Available module signals:

- `game_exited`
- `score_changed(value)`
- `state_saved(data)`

Game input must use the semantic actions from `GameContext` / the shared InputMap. Do not read raw keys, touch coordinates or joypad buttons inside game logic.

Every metadata resource must define:

- `id`
- `title`
- `version`
- `controls_text`
- `thumbnail` (or allow the shell fallback preview)
- `entry_scene`
- `native_size`

`native_size` is the game's logical render size. The shell preserves this aspect ratio and letterboxes/pillarboxes as required.

---

## Option A — add an in-tree game

Create:

```text
games/<id>/
  metadata.tres
  main.tscn
  <id>.gd
  thumbnail.svg   # optional
```

Register it in `games/registry.json`:

```json
{
  "source": "tree",
  "metadata": "res://games/<id>/metadata.tres"
}
```

No shell file is changed.

Run the platform CI. The hub will include the game because `GameManager.get_installed_games()` is registry-driven.

---

## Option B — add a runtime .pck game

This is the path validated by A4 using `stub_packed`.

### 1. Create pack source files

Put source files under:

```text
pack_sources/<id>/
  metadata.tres
  main.tscn
  <id>.gd
```

The parent `pack_sources/.gdignore` is intentional. It prevents these source files from being imported/exported as normal project resources. The runtime mount path does **not** exist in the base game.

Inside the source files, references must use the final runtime mount paths, for example:

```text
res://games/<id>/<id>.gd
res://games/<id>/main.tscn
```

The game script still extends `GameModule`. Shared platform classes are supplied by the base GameZone build and are not copied into the pack.

### 2. Add one registry entry

Add:

```json
{
  "source": "pack",
  "id": "<id>",
  "metadata": "res://games/<id>/metadata.tres",
  "pack_url": "packs/<id>.pck",
  "local_path": "res://build/runtime-packs/<id>.pck",
  "build_source": "pack_sources/<id>",
  "mount": "res://games/<id>"
}
```

Field meanings:

- `source`: selects runtime-pack handling.
- `id`: must match metadata `id`.
- `metadata`: resource path that becomes available **after** the pack is mounted.
- `pack_url`: Web URL relative to the deployed GameZone page.
- `local_path`: build/headless path used by CI and desktop development.
- `build_source`: ignored source folder that `tools/build_runtime_packs.gd` reads.
- `mount`: destination namespace inside the generated PCK.

No shell file is changed.

### 3. Build the PCK

The CI command is:

```bash
mkdir -p build/runtime-packs
godot --headless --path . --script res://tools/build_runtime_packs.gd
```

The builder reads the registry, packs every `source: "pack"` entry and writes its `local_path`.

For the Web artifact, copy each PCK to the path represented by `pack_url`. A4 does this automatically for the validated stub:

```bash
mkdir -p build/web/packs
cp build/runtime-packs/stub_packed.pck build/web/packs/stub_packed.pck
```

For additional packs, extend the staging step or generate the copy list from the registry in a future build-system refinement. The runtime shell itself still requires no changes.

### 4. What happens in Web at runtime

For each pack registry entry:

1. the hub loads the base registry;
2. `GameManager` resolves `pack_url` relative to the current Web page;
3. `HTTPRequest` fetches the PCK bytes over HTTP(S);
4. the file is written to `user://gamezone_packs/<id>.pck`;
5. only after the download completes, `ProjectSettings.load_resource_pack(..., false)` mounts the PCK;
6. `metadata` is loaded from its mounted `res://games/<id>/...` path;
7. the game is added to `get_installed_games()`;
8. the shell creates a normal card automatically;
9. launching follows the same `GameModule` / `GameContext` / SubViewport path as an in-tree game.

The second parameter to `load_resource_pack` is `false` so runtime packs cannot replace existing shell resources.

### 5. Acceptance checklist for a new game

Before considering a game integrated:

- metadata validates;
- its ID is unique;
- it appears in the hub without shell changes;
- launch succeeds;
- native aspect ratio is preserved;
- Back returns to the hub;
- relaunch succeeds;
- per-game save namespace is isolated;
- per-game audio scope is removed on teardown;
- if packaged, the Web console shows HTTP download before PCK mount;
- Web `pack_url` returns HTTP 200.

## A4 validation of this document

A4 followed this exact runtime-PCK procedure to add `stub_packed`.

The acceptance tests explicitly verify that `res://games/stub_packed/metadata.tres` does not exist before loading the PCK, then exists after `load_resource_pack()`, and the live Pages build downloads and launches that game.
