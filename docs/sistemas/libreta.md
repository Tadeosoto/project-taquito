# La libreta del Nocturno (bestiary, AG's proposal)

> Moved from the root `CLAUDE.md` on 2026-11-11, word for word. Keep it in sync with the code; the root keeps only a pointer here.

An in-game guidebook in El Nocturno's own voice (informal Spanish, a bit of dark humor). Opened from the open inventory with **L** / gamepad **R3** (`inventory_guide`; it was B/RB on `lombriciento`, moved when merged because Tiliches has B; `InventoryUI` state `LIBRETA`; the Libreta tab of the bottom strip shows "!" with unread notes).
- **`Libreta` autoload** (`scripts/Libreta.gd`): per entry a level, 0 unknown / 1 seen / 2 fought / 3 killed (`ver`/`pelear`/`matar`), plus kill counts and unread flags.
  - Saved forever in `user://libreta.cfg`; not cleared on restart. In the safehouse Ctrl+B fills every page (`llenar`) and Shift+B forgets it.
  - A level-up shows a paper toast ("Nueva nota en la libreta...") with the generated `lapiz` sound.
  - Callers use `get_node_or_null("/root/Libreta")`.
- **Entries** (`scripts/LibretaEntradas.gd`, static): `zombi`, `cazador`, `infectado`, `gordo`, `jefe`, `crias`, `madre`, `remedios`.
  - Each has a title, nickname and the sections "Qué es" (level 1), "Por qué es así" (2), "Cómo matarlo" + "Datos" (3); locked sections show a hint.
  - `datos(id)` reads the live constants with `load()` (not class names, so the autoload doesn't pull Zombie in at startup).
  - Undecided lore (jefe, gordo, infectado) is written as his guesses; see `docs/revision-historia.md` 4.13.
- **Page** (`scripts/LibretaUI.gd`): a lined notebook page drawn in code (ring holes, red margin, seeded coffee/sludge stains, tape), the pixel drawing (or its silhouette for unknown entries), two sheets per entry (←/→), tabs on the left.
- **Drawings**: 32×32 ASCII art in `tools/libreta/dibujos.gd`, written ×4 to `textures/libreta/` and `textures/libreta/silueta/`. Run `godot --path . --headless -s tools/libreta/dibujos.gd`, then `--import`.
- **Unlock hooks**:
  - `Zombie`: `_id_libreta()` by type; seen on alert within `VE_DESDE`, fought on hit/being hit, killed in `recibir_golpe`'s kill branch.
  - `EnjambreLombrices`: seen within 15 m, fought on latch or player hit, killed on a whole-worm kill. Remedies are fought on salt/fire kills and killed at 10.
  - `MadreCarcamo`: seen when she starts an attack, fought on a sac hit, killed at death.
  - `Lanzador.lanzar`: remedies seen.
- The arena (`scenes/lombrices.tscn`) now has `InventoryUI`, so the libreta opens there.
