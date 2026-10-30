# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Guadalajaja" — a Godot 4.7 (Forward Plus, Jolt Physics) third-person 3D prototype with a PS1-style look. All gameplay code is GDScript; there is no build system, linter or test suite. Code comments and in-game UI text are in (informal) Spanish — keep new player-facing strings in Spanish.

## Commands

Godot 4.7 is installed as `godot`.

```bash
godot --path . --editor            # open in the editor
godot --path .                     # run the main scene (scenes/world.tscn)
godot --path . scenes/InventoryUI.tscn   # run a single scene in isolation
godot --path . --headless --import # (re)import assets / regenerate .godot cache
godot --path . --headless --check-only --script res://scripts/player.gd  # parse-check one script
```

## Architecture

- **Main scene**: `scenes/world.tscn` (referenced by UID `uid://c2iut07k626j5` in `project.godot`). It instances `player.tscn`, two `npc.tscn` instances (configured per-instance via exported `tint` and `dialogue`), level geometry from `models/*.glb`, and a `PS1_Postprocess` CanvasLayer whose full-screen ColorRect runs `shaders/dittershader.gdshader` over the screen texture. Render resolution is 640×480 with `viewport` stretch mode and nearest texture filtering — this is intentional for the retro look.
- **Player** (`scripts/player.gd`, `class_name Player`): CharacterBody3D. Movement is camera-relative (`CameraPivot` yaw + `SpringArm3D` pitch); the visual body is the child `Frijol`, which is rotated toward the movement direction separately from the physics body. The `jump` action doubles as "interact": if any node in the `npc` or `interactuable` groups reports `is_player_inside()`, the nearest one gets `interact()` instead of jumping. The player is in group `jugador`. `girar_con_qe` (on only in `map_test.tscn`) turns the camera with physical Q/E; it isn't an input action because Q is `inventory_previous` in `world.tscn`. Animation is delegated to `Frijol/Ninja` via duck-typed `update_animation(is_moving, is_airborne, is_sprinting)` (`scripts/character_animation.gd`).
- **Animation clips** are looked up by suffix (`"Idle"` matches `"...|Idle"`) because the imported FBX (`models/ninja_male.fbx`) prefixes clip names; loop mode is forced in code. Both player and NPC share this model.
- **NPC** (`scripts/npc.gd`): registers itself in group `npc`; a `TalkArea` Area3D detects the `Player`. The interaction prompt and speech bubble are 2D UIs rendered into SubViewports and displayed on `Sprite3D`s. The prompt key label switches between keyboard ("Space") and gamepad ("X") based on the last input device.
- **Inventory system**:
  - `Inventory` autoload (`scripts/Inventory.gd`) holds `items: Array[InventoryItemData]` and emits `inventory_changed` on every mutation. `_ready()` currently seeds temporary test items (caguama, taco, machete, cinta). Capacity is `CAPACIDAD_BASE` (6) or the `capacidad` of the equipped `mochila` (doesn't take a slot); `add_item` returns false when full and `equipar_mochila` only accepts a bigger backpack (the old one is discarded). `combinar(index_a, index_b)` applies the first matching `RECETAS` entry (`scripts/RecetaData.gd`: `a`, `b`, `resultado`; `resources/recetas/*.tres`).
  - `InventoryItemData` (`scripts/InventoryItemData.gd`) is a `Resource` with name, description, icon, `inspection_model` (a PackedScene whose root must be `Node3D`) , `curacion` (life restored by Utilizar; 0 = not usable), `capacidad` (> 0 = it's a backpack) and `tinte` (alpha > 0 paints the whole model that colour, without its texture: the three backpacks in `resources/productos/mochila*.tres`, 8/10/14 slots, share `mochila.scn`). `crear_modelo(tamano)` returns the model centred and normalized inside a holder node (models come in any unit; long ones are turned sideways). Items are authored as `.tres` files in `resources/`.
  - `Salud` autoload (`scripts/Salud.gd`): `vida` (test value 60 of 100), `vida_max`, signal `cambio`, `estado()` text. Only the inventory changes it for now.
  - `scenes/InventoryUI.tscn` / `scripts/InventoryUI.gd` (instanced in `map_test.tscn`, layer 11, not in `world.tscn`): CanvasLayer with a NAVIGATING/INSPECTING/COMBINING state machine. Tab/Start (`inventory_toggle`) opens it and pauses the tree (it runs with `process_mode` Always), which is what stops `E`/arrows from also moving the player and camera; it won't open while the `jugador` is disabled or its physics stopped (shop, stall close-up, drone). Q/E or left/right cycle items, up/down choose among the commands that apply to the item (Examinar/Utilizar/Combinar), Enter confirms, Esc goes back one step and finally closes. Run alone, it stays open. The look is inspired by Silent Hill 2, not a copy (the user's request), and uses the game's default font and marker yellow: black screen, Estado = the paused game (the view grabbed on opening, cropped below the minimap, not tinted: it shows where the player is) with `Salud.estado()` as coloured text over it, Equipo = the backpack model and used/total count, and a row of up to 7 items (`RANURAS`, one model per item in `modelos`, placed by `_lugar`) going back into a black depth fog so they fade with distance. The full-screen 3D preview lives in a SubViewport (not rendered while closed) whose `PreviewWorld` node runs `InventoryInspectViewer.gd` (arrow-key rotation of the centre model, PageUp/PageDown or mouse-wheel zoom).
  - `scripts/WorldItem.gd`: pickup in group `interactuable` that shows its normalized model and a prompt inside its Area3D; `interact()` equips it (`capacidad` > 0) or adds it to `Inventory` and frees itself, or stays on the ground if it doesn't fit (the prompt says so). `ObjetoPrueba1/2/3` and `MochilaPrueba1/2/3` in `map_test.tscn` are test pickups by the spawn.
- **Shaders** (`shaders/`): `ps1_combined.gdshader` merges the three standalone experiments (`jittershader` screen-space vertex snap, `vertex_wobble` view-space snap, `affine_warp` affine UVs) with per-effect toggles — prefer it for new materials.

## Real map and everything on it (`scenes/map_test.tscn`)

**Read `docs/mapa/tecnico.md` before changing the map pipeline, streaming, stores, houses, warehouses, walls, street lights, ground, deterioration, interiors, shop UI, or fruit machines.** It has the full detail, the regeneration commands and the reasons behind each decision. Keep it in sync with those systems. `docs/mapa/README.md` is the user-facing (Spanish) guide. Game design and open team decisions are in `docs/especificaciones.md`.

Overview:
- A real area of Zapopan built from OpenStreetMap with OSM2World by `tools/map_import/` (Python and Godot scripts), streamed from `resources/map/cuadros/`. `models/zona_mapa.glb` is gitignored; only rebuild it when changing the map.
- `scripts/map/`: `MapStreamer` (chunks), `MapPuntos` (stores), `MapCasas`, `MapBodegas`, `MapBardas`, `MapArboles`, `MapPasto`, `MapAlumbrado`, `MapDron` (V toggles the drone), `MapMinimapa`, `Maquinita`/`TragamonedasUI`/`Cohetes` (fruit machines). `scripts/tragamonedas.gd` is the machine's logic.
- `scripts/interiores/`: fixed first-person shop scenes, entered through the yellow arrows (`Interiores.gd`).
- New streaming systems must use the per-frame load budget in `scripts/map/CargaCuadro.gd`. Don't add per-instance `StandardMaterial3D`s in builders: recompiling them caused stutter.
- Scripts in `tools/` run with `-s`, before autoloads exist. Anything they load, including `MapPuntos` and what it references, must not name `Cartera`, `Salud` or `Inventory` directly; use `load()` at runtime.
- Map data is ODbL; keep the attribution in `CREDITS.md`. Don't use Google Maps or Street View data for geometry.

## Conventions / gotchas

- PS1 shaders must write `POSITION` unconditionally (`ps1_vertex()` returns the unsnapped clip position when `jitter_enabled` is false). A spatial shader that writes `POSITION` only inside an `if` leaves the mesh invisible when the branch isn't taken. The original `ps1_combined` had this bug; `shaders/jittershader.gdshader` still does. Huge meshes (the 1900 m `Suelo`) need jitter/wobble off, otherwise vertex snapping distorts them near the camera.
- `pkill -f <pattern>` from the Bash tool also kills the tool's own shell when the pattern appears in the command line; use a pattern that can't match itself (e.g. `fetch_sat[e]lite`).
- Chunk `visibility_range_end` is 250 m plus half the chunk's AABB diagonal, because Godot measures it to the AABB center and some chunks are 800+ m wide.
- Input actions are defined in `project.godot` (`move_*`, `camera_*`, `jump`, `sprint`, `inspect_*`, `inventory_*`). Note `E` is bound to both `camera_right` and `inventory_next`, and arrow keys to `move_*`, `inspect_*` and (left/right) `inventory_next`/`inventory_previous`. These only coexist because the open inventory pauses the tree; don't open a menu using them without pausing.
- Resources are referenced by `uid://`; keep each `.gd.uid` file alongside its script when moving/renaming, or edit via the Godot editor.
- `scenes/world.tscn` and `scripts/Inventory.gd.uid` are listed in `.gitignore` but are already tracked, so changes to them still show up in git.
- `scenes/InventoryUI.tscn*.tmp` files are editor save leftovers, not real scenes.
