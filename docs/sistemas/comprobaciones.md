# Comprobaciones (the automated test suite)

`tools/comprobaciones/` holds headless tests that run on the real scenes (safehouse, `map_test`, the boss arenas) and print `OK`/`FALLA`. Run them before merging into `main-testing`. Made on 2026-11-24 from the throwaway harnesses of the sandbox work; they had already caught the night counted twice after a scene change and a container count that only saw the first slot.

```bash
tools/comprobaciones/correr.sh                 # all of them; also counts SCRIPT ERROR lines from the console
tools/comprobaciones/correr.sh capilla         # just one
GODOT=/path/to/godot tools/comprobaciones/correr.sh   # when godot is not on PATH
godot --path . --headless res://tools/comprobaciones/correr.tscn -- --solo=bolsa   # without the wrapper
```

The exit code is failures plus script errors (0 = all good). A full run takes about 90 s.

- **Runner** (`Correr.gd`, scene `correr.tscn`):
  - It runs each name in `LISTA` in order. Before each one it calls `_limpiar()`: unpause, `PasoJefe.reiniciar()`, `Guardado.nueva()`, and remove leftover tazo shows and dialogue boxes.
  - At start it sets `current_scene = null`, so `ir_a()` (`change_scene_to_file`) frees the previous scene and never the runner. Nulling it on every change instead left old scenes piled up: two `Ciclo`s, two players.
  - **It never touches the player's files.** It backs up `user://{partida,noches,libreta,taller,personaje}.cfg` to `user://_respaldo_comprobaciones/` and restores them at the end. If a run crashed and left the backup behind, the next run restores it first.
  - A test that hangs (an error mid-coroutine leaves it waiting forever) is cut after `TOPE_S` (420 s). It counts as a failure, the backup is restored, and the run quits.
  - A test file that doesn't compile counts as one failure, and the run continues.
- **A test** is one file here that `extends Comprobacion` and implements `correr(r)`. `r` is the runner:
  - `r.ok(cond, texto)`
  - `r.ir_a(escena)`, `r.escena_es(ruta)`
  - `r.frames(n)`, `r.segundos(s)`
  - `r.saltar_ciclo()`, `r.cerrar_tazo()`, `r.apretar(accion)`
  - `r.nodo(grupo)`, `r.autoload(nombre)`

  Add its name to `Correr.LISTA`. Assign autoloads with `=`, not `:=`: `r.autoload()` returns an untyped value and `:=` won't parse.
- **Tests:**
  - `especiales`: the charged slash, the spin and the air thrust are unlocked by the campaign or by the tazos (`Misiones.ataques_de_campana`), and the album pays for the whole tree.
  - `noches`: the count, the garrafonero on night 3, the record, the milestone tazo, horde growth, repeating bosses, and that arriving at night doesn't count another night.
  - `bolsa`: a faint drops the bag; by day it lies on the floor; at night the leader carries it, with guards, the backpack on a bone and the drinking; killing him drops it; a second faint replaces it; it can be picked up.
  - `guardado`: save/load of the autoloads, the night, the campaign (`Guardado.CAMPANA`) and the defeated bosses; the arrival point is taken once; Partida nueva wipes it.
  - `capilla`: the chapel (F3): the cupo, water at dawn, the filter mission after the gate guard, a Puri-GelA outside the walls, and that it saves.
  - `entrada_jefe`: Juanjo's `EntradaJefe` is gated by milestone without a mission; inside the fight there is `aguante`; a faint returns with the bag at the entrance.
  - `dialogo`: the `DialogueBox` opens, pauses and closes with Space.
  - `marro`: the heavy combo (`Player.PESADO`): with the marro the swing is `Sword_Heavy_A`, it hasn't hit at 0.3 s (the machete hits at 0.24), it stuns, the first two swings nudge the zombie (it stays in reach) and land, the third (`Sword_Heavy_C`) throws it, one swing hits three zombies in front without killing any and misses the one behind, the garrafonero (a boss) is hit but not pushed, and with the machete the combo is unchanged.
  - `escenas`: the main scenes load and keep running (`inicio`, `safehouse`, `map_test`, `mapa`, `defensa_tinaco`, `lombrices`, `catrina`, `tuneles`).
- **What it doesn't see:** anything that needs a window or the eye (screenshots, FPS: `tools/medir_mapa.tscn`), and the `simi_jefe.gltf` import error (its `scene.bin` is gitignored, JJ has it locally).
