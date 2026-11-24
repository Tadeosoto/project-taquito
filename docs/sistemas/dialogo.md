# Dialogue box (`DialogueBox`)

> Brought from branch `dialogos-test` (commit `e861d04`, AG, 2026-11-04) onto `sandbox-sin-fin` on 2026-11-23. The commit was not merged: its new files were copied and its small edits re-applied by hand. Keep this file in sync with the code.

- **Files:** `scenes/dialogue_box.tscn` and `scripts/dialogue_box.gd` (`class_name DialogueBox`). The open puff is `resources/fx/dialogo_abre.*`, the pixelfx `spawn/poof` entry in `tools/pixelfx/efectos.json`.
- **Who uses it:** every `npc.gd` talks through it, mission givers included. The old 3D speech bubble (`npc_bubble.gd`, the `Bubble`/`BubbleViewport` nodes in `npc.tscn`) is gone.
  - `npc.gd` takes the line from `al_hablar.call()` or `dialogue`. It opens the shared box (`DialogueBox.compartida(self)`: one per scene, created inside the current scene so it goes away with it) with its `nombre` and its own random blip pitch (`TONO_VOZ` 0.85-1.25).
  - While the box is open the NPC doesn't take another `interact()`.
  - Shop sellers only lend their `dialogue` to `TiendaUI`/`Interiores`.
- **API:** `decir(lineas: Array[String], hablante, retrato = null, tono = 1.0)`, signal `termino`, `abierta`.
- **How it behaves:**
  - Layer 12, `PROCESS_MODE_ALWAYS`. It **pauses the tree** while open and restores the previous pause state on close (`_pausaba`).
  - `jump`/`ui_accept`/`attack` first finish the line, then go to the next one, then close. `inventory_toggle`/`inventory_map` are swallowed so nothing opens on top.
- **Typewriter:**
  - It runs on the real clock (`Time.get_ticks_msec`) and reads letters from `get_parsed_text()`.
  - It pauses after `. ? ! …` and `, ; :`, but only when a space follows.
  - Each letter plays a `blip` (`Sonidos`, also in `DefensaTinaco.SONIDOS`).
- **Writer tags:** `[feliz]`, `[enojo]` and `[clave]` expand to wave, shake and yellow (`ETIQUETAS`). `MisionesMundo.TEXTO_ACEPTAR` uses `[clave]` ("Háblale otra vez para aceptar.").
- **Portrait:** a 3-frame sheet (closed, open, blink). A code-drawn placeholder is used until there is art (`_retrato_prueba`).
- **pixelfx:** through `EfectosPixel.hoja_ui`, which moved there from the tinaco defence's private `_hoja` and is now shared by both.
  - `dialogo_abre` puffs on open and close.
  - `recoger_brillo` plays on `[clave]` words.
  - `rabia` plays on `[enojo]`.
  - All of them turn off with F9 (`EfectosPixel.extras`).
- **Testing:** Shift+8 in the safehouse (plain 8 is the estela toggle). The yard NPC is "Doña Chuy". `scenes/dialogue_box.tscn` run alone loops the sample lines (`PRUEBA`).
- **Pending:**
  - real portraits per character;
  - the box covers the bottom HUD labels (weapon, "Q curar", clock) while open;
  - the `nombre` of most NPCs is empty (only Doña Chuy has one), so the name tag is hidden for them.
