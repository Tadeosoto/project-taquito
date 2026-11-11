# Crafting: El Yonke de Don Chava (AG's proposal, spec §4.13; the team hasn't voted on it)

> Moved from the root `CLAUDE.md` on 2026-11-11, word for word. Keep it in sync with the code; the root keeps only a pointer here.

Kingdom Hearts 1-style synthesis with this world's own items.
- **Materials:**
  - `scripts/Materiales.gd` is the static table: 6 families × 3 tiers (COMUN), ESPECIAL and TROFEO, plus the drop rules (`botin`, `chatarra`).
  - The `Tiliches` autoload (`scripts/Tiliches.gd`, was Morral: a morral is a backpack) holds counts outside the inventory, so materials take no slots. It shows "+2 Rebaba" notices bottom right and resets on restart.
  - **The cangurera holds the tiliches** (`resources/productos/cangurera.tres`, `InventoryItemData.cangurera`, `Inventory.cangurera`, no slot, kept when fainting, reset on restart). Without it `Tiliches.dar` returns false and warns (`puede_guardar`, `avisar_sin_cangurera`): piles stay on the ground, zombie materials are lost, el punto won't sell Plata de Taxco, the workshop won't make a material, and the Tiliches tab is greyed. Trophies don't need it. You get it from the mission `resources/misiones/cangurera.tres` (2 Jarritos from the abarrotes), which isn't offered once you have one (`Misiones.ya_tienes_el_premio`).
  - **Trophies persist** in `user://taller.cfg` (section `vitrina`) and are shown at La Chava's, not in your Tiliches: V in the workshop opens the trophy case (`TilichesUI` with `vitrina = true`).
  - Icons are drawn by `godot --path . --headless -s tools/taller/iconos.gd`.
- **Where materials come from:**
  - `Zombie._morir` drops by zone `Deterioro`, night and hunter.
    - KH-style loot (AG's proposal): `scripts/map/CajaBotin.gd` (`CajaBotin.soltar`) turns the drop into one bouncing box per material, coloured by tier: Suelto purple/gold, Bueno red/silver, Fino blue/white, especial green. The kill's pesos (with Bolsillos and `Bonos`) come out as 1-3 coins.
    - After 0.35 s of game time they fly to a player within 4 m (Imán: `Habilidades.IMAN_RADIO`) and are collected with the generated `botin` chime and the `recoger` sheet.
    - Material boxes never fly in without a cangurera; they stay and warn. They last 30 s, at most 24 boxes plus 24 coins.
    - Meshes, the one unshaded vertex-colour material and the GPUParticles3D sparkle materials are all `static var`, shared by every box.
    - Group `botin`, cleared by `Partida.reiniciar`. Shift+Z in the safehouse drops a test set (Shift+B is the Libreta's).
  - `Chatarra.gd` piles beside posts (`Partida._poner_chatarra`), and Alambrón piles in front of obra negra houses (`Partida._poner_obras`, using `MapCasas.es_obra_negra`, a static function called through a preload because MapCasas has no class_name); two of those also hold blueprints.
  - Plata de Taxco is sold at el punto (`InventoryItemData.material`: a bought or picked-up item goes to the Tiliches).
- **Trophies:** `scripts/map/Hazanas.gd` (created by Partida, group `hazanas`; `Zombie._morir` calls `zombi_muerto`) gives them at most once per night:
  - Marca de cazador and Ojo de turba from hunters; Ceniza and Baba verde from burning kills; Chancla de oro from a kill with no weapon;
  - Tapa del tinaco after a night with no tinaco damage;
  - Diente del jefe plus the first missing blueprint from the boss;
  - Casco de GelA and Cobalto from the rare variants (`Zombis._variante` → `Zombie.poner_variante`: a pale "gela" at night, a glowing tougher "cobalto" where `Deterioro.zona` ≥ 0.5).
- **Recipes:** `scripts/Recetas.gd` lists 39: sets 1–5 open at 0/3/9/15/21 unique items made, and set 6 needs everything plus a blueprint.
  - The `Taller` autoload keeps the rank (`hechos`) and blueprints in `user://taller.cfg`; restarting a run does **not** reset it.
  - `hacer(id)` spends materials and pesos (`costo`, with Regateo, never the skin-tone factor).
  - Crafted items are `resources/taller/*.tres`, written by `tools/taller/objetos.gd`. Their models come from `tools/taller/modelos.gd`: the `melee_psx` pack split per weapon, plus simple shapes recoloured by `tinte`.
- **The place:**
  - **Map:** `scripts/map/YonkeMapa.gd` is a node in `map_test.tscn` at a vacant lot in Parques de Santa Mugre (+Z faces the street), with a sign, a shack, junk and the stores' yellow arrow. It emits `MapPuntos.entrar_negocio` with giro `yonke`, which `Interiores` maps to `scenes/interiores/yonke.tscn`.
  - **Interior:** `Yonke.gd` (extends `Interior`) with La Chava (`chava_psx` through `Gente.poner_modelo` on a plain Node3D: inside `npc.tscn` it threw null-material errors). It opens `TallerUI.gd` instead of the product carousel, and the chosen item floats on the counter (`Banco`).
- **Using what you make (`InventoryItemData`):**
  - **Weapons:** traits `alcance`, `empujon`, `velocidad`, `quema`, read in `Player._atacar`/`_golpear`. The torch calls `Zombie.quemar` (3 s of damage with the barrel-fire sheet).
  - **Equipar:** reuses the Utilizar slot (`InventoryUI._nombre_utilizar`); `Inventory.arma()` prefers the equipped weapon and otherwise picks the highest damage.
  - **Amulets:** an `amuleto` dict; "Ponerse" moves the amulet out of the inventory into one of 2 slots in the `Bonos` autoload (the oldest comes back when full).
  - **Estampitas:** `estampita` lasts the run.
  - **How the bonuses combine:** `Bonos` multiplies into life, strength, reach, damage taken (`Player.recibir_dano` now gets the attacker), pesos, tazo luck and the player's lamp.
  - **Resets:** `Bonos` resets with the run.
- **Inventory keys:** **B / RB** (`inventory_tiliches`) opens `TilichesUI.gd`, the materials page (only with a cangurera).
- **Safehouse:** the yonke is on the left.
  - Shift+P puts on a cangurera and gives +5 of every material; Y also takes the cangurera off.
  - The tazo kid stands near the yonke.
  - Shift+K raises the rank.
  - Ctrl+L gives all trophies and blueprints (Shift+L is the Madre del Cárcamo).
  - Shift+Y makes the workshop forget everything.
