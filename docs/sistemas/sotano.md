# El Sótano (the Gotera's underground casino)

AG, 2026-11-18.
- **v2** (2026-11-19, branch `sotano-v2`): two halls, Texas Hold'em instead of the lotería, the game on the cabinet screen, simpler fruit machines, people.
- **v3** (2026-11-19, branch `sotano-v3`): solid boxes (nothing floats any more), real seats and bottles, readable reel cards, the machines renamed **EL GORDO**, tube neon from Blender, a roomier hall 2, poker card animations.
- **v4** (2026-11-19, branch `sotano-v4`): EL GORDO as a real slot machine (a lever you pull, casino sounds, 3D-rendered card art, a livelier screen), a branded fridge, a readable single-stroke neon, the waitress carries her tray, shady people everywhere, the race camera, a readable poker board, and a walkable Silent Hill bathroom.
- **v5** (2026-11-19, branch `sotano-v5`): blackjack, roulette (red/black/green, with a double-or-nothing doblete), baccarat, the red-and-blue dice neon by the fridge, colour neon strips and lights on the bar, and EL GORDO cards back to 2D: cartoon pixel art drawn by code (AG didn't like the 3D renders).
- **v6** (2026-11-19, branch `sotano-v6`): a bigger roulette table, a ball that really rolls and bounces, 3D chip stacks on the felt (roulette and baccarat), and celebrations for winning, win streaks and losing.
- **v9** (2026-11-19, branch `sotano-v9`), after AG's reference photos:
  - baccarat as a half-moon with a red padded rail and a black felt;
  - roulette with three squares in a row next to the wheel;
  - a round poker table with cup holders and padded wooden chairs;
  - a jukebox, a dartboard, barrels and hanging bulbs;
  - detailed chips and smoother bottles.

The story is in `docs/lore.md` §11 "El Sótano". Keep this file in sync with the code.

**Naming:** the machines are called EL GORDO in the game (they used to be "OL PLEY"). The code still calls them `OlPley`: `GabineteOlPley`, `OlPleyUI`, the `Marca_OlPley_*` marks and `gabinete_olpley.glb`.

## Getting in

- **Door:** the `casa_vecino` marker `Sotano` in the Santa Mugre colonia JSON (and in `resources/mapa/santa_mugre/marcas.json`), beside the door of the Mini Super Santa Mugre on the tianguis street.
  - `"abierto": "noche"`.
  - `"bodega": true` makes `Colonia._bodega` add a plastic strip curtain, crates and a red bulb.
- **Walkable house:** a `CasaPropia` like the neighbours' houses: combat off, the door on the west wall at z 3.11. The scene is `scenes/casas/sotano.tscn`: root `scripts/sotano/Sotano.gd` plus the Blender room `Cuarto` (`models/sotano/sotano.glb`).
- **Permission:** the `Fichas` autoload (`scripts/sotano/Fichas.gd`, reset per run in `Partida._otra_vez`) holds `permiso` and `fichas`.
  - With no permission, a chain at the foot of the stairs blocks the way (`CadenaChoque-colonly`). The guard takes the one-time `CUOTA` ($300) at the `MuebleCasa` beside him.
  - The Gotera missions will grant `permiso = 1` (escalón 1, `docs/misiones.md`).
- **Safehouse:** an arrow `Sotano` at (-15, 0, 40.2), always open. `.` grants permission and +50 chips.
- **Standalone test scene:** `godot --path . scenes/sotano_prueba.tscn` (`scripts/sotano/PruebaSotano.gd`). The casino is in the `.tscn`, so it shows in the editor.
  - It puts you before the chain with $1000.
  - Keys: `.` permission and chips, `P` +$500, `K` remove the permission, `H` all EL GORDO hot, `R` back to the stairs, `F12` start from scratch, `F1` hide the help.
  - `-- --foto=<file.png>` saves one screenshot and quits.
  - `-- --fotos=<dir>` saves a screenshot from each camera in `FOTOS` and quits. The cameras are low and side views (machines, window, bar, poker, every neon), to catch floating or hollow things.
  - `-- --poker=<dir>` sits at the poker table and saves a frame every 0.15 s, to see the cards move.
  - `-- --gordo=<dir>` opens the first EL GORDO, pulls the lever three times and saves frames.
  - `-- --mesas=<dir>` plays a blackjack hand, a baccarat hand and a roulette spin, saving frames of each.
  - `--fotos` opens the bathroom door first and also covers the fridge, the lever, the waitress (the camera follows her), the shady people and the bathroom.

## The rooms (Blender)

`tools/blender/sotano/sotano.py` builds everything in Godot coordinates, in scene metres (`CasaPropia` scales by 1.25).
- Run it in an empty file, or in `models/sotano/fuente/sotano.blend`.
- It exports `sotano.glb`, `gabinete_olpley.glb` and `botellas.glb`.

**Faces must point outward.** `caja()` and `cable_recto()` call `_afuera()` (`bmesh.ops.recalc_face_normals`). In v2 the boxes came out inside out:
- walls and cabinets looked hollow;
- the floor you saw was the bottom face of the floor box, 0.4 below its collision (0.5 m in the game), so everyone looked like they floated.

`probar_sotano` now checks that the floor's top face points up.

- **Shell:**
  - Walls 0.4 thick (`GRUESO`), ceiling at 3 m, beams.
  - Stairs: solid steps with nosing, side stringers, a handrail, and a hidden walking ramp (`Rampa-colonly`).
  - Hall 1 (`SALON`, 14 × 10): the machines.
  - The arch (`ARCO`, with jambs and lintel) leads to hall 2 (`SALON2`, 14 × 10, the same z as hall 1).
- **Hall 1:**
  - The Primo's window: counter at 1 m, bars 0.2 apart, a green lamp, cash box and fan.
  - The guard and his chain.
  - Ten EL GORDO (eight on the north wall, two on the south), each with a bar stool.
  - Two fruit machines facing the room.
  - The race track as an island in the south half (`PISTA`, finish at `PISTA_META` 16.5; the horses run along +x).
  - The altar, the speaker, crates, two columns.
- **Hall 2:**
  - Bar on the north wall: back bar with three shelves of bottles, a red fridge with a lit glass door, the counter with taps and bottles, and five tall stools.
  - Round poker table in the middle (`MESA`, `MESA_R`), like AG's photo.
    - A pedestal, green felt with a ring line, and a wide wooden rail with eight cup holders (beers sit in some).
    - Chip towers, and a high lamp.
    - Padded wooden chairs (`silla_madera()`) at `Poker_0..2` and your spot `Poker_tu`; the dealer (`Crupier`) stands to the north-east.
  - Caguama freezer in the south-west corner, the bathroom door on the east wall, a high table with beers.
- **Seats:** `banco()` is a cantina stool (chrome post, foot ring, red vinyl cushion). `silla_plegable()` is a brewery folding chair with the Coronela logo on its back, taken from the poster atlas.
  - Seat height `ASIENTO` 0.5: the `Sitting_Idle` thighs sit at 0.52.
  - That clip leaves the hips 0.38 behind the feet, so `Sotano.CADERA` moves each seated NPC forward. `tools/sotano/medir_sentado.gd` measures it.
- **Fridge:** `refri()` builds a branded Tecatl cooler:
  - a lit marquee and stickers from `textures/sotano/refri.png` (`arte.py refri()`);
  - a see-through glass door (`vidrio_refri`) with a frame and handle;
  - three wire shelves full of beers and caguamas, a white inner light (`Luz_refri`), feet and a compressor grille.
  - The chest freezer got stickers and a lid handle.
- **Back bar:** three shelves from `REPISA_Y` 1.15, `REPISA_SEPARA` 0.34 apart. The tallest bottle stays under the beams, and bottles stop at the shelf edge.
- **Bar neon:** emissive strips: pink under the counter edge, cyan and violet under the shelves, violet and blue along the base and the back bar. Coloured lights sit at `Luz_barra_*` (`Sotano.LUCES_BARRA`).
- **Blackjack** (`mesa_blackjack`, `BLACKJACK`): a half-moon table, built by `media_luna`.
  - The felt is printed (`blackjack.png`); a padded rail runs along the arc; the chip tray and shoe sit on the dealer side.
  - Two stools with players, and a lamp.
- **Roulette** (`mesa_ruleta`, `RULETA` 2.6 × 1.8, `RUEDA`): the wheel is sunk flush into the table (`HUECO`), and a raised wooden frame runs round the table.
  - Like AG's photo, the felt has three squares in a row next to the wheel: green, black, red.
  - The marks `Ruleta_verde` / `_negro` / `_rojo` sit on the squares and hold your chip stack.
  - `Ruleta_rueda`: a ring of 37 pockets in European order with chrome separators (`Ruleta_separa_*`), a wooden hub with gold spokes and the turret.
  - The ball `Ruleta_bola`; the sloped outer track lives in the bowl.
  - The felt strip (`ruleta.png`) shows VERDE, NEGRO and ROJO only.
- **Baccarat** (`mesa_baccarat`, `BACCARAT_MESA`): a half-moon table in the south-west corner of hall 2, like AG's photo.
  - A red padded rail runs all round.
  - The black felt (`baccarat.png`, 1024 × 512) has faint spades, white arcs and three bands: PUNTO outside, BANCA in the middle, EMPATE 8 A 1 inside (`BACCARAT_BANDAS`).
  - The dealer's chip tray is set into the straight edge; the shoe is red.
  - One stool, and a lamp.
  - The marks `Baccarat_banca` / `_empate` / `_punto` (due south on each band) hold your chip stack; the cards are dealt in a row near the dealer.
- The walkers' route goes around the blackjack table by the east wall (`Camino_10`, `Camino_12`) and around the baccarat table on the west (`Camino_13`). The bar-corner deal moved by the arch.
- **VIP room** (`cuarto_vip()`, `VIP`): behind the east wall of hall 2, north of the bathroom, through a second doorway (`VIP_PUERTA`). It has a gold frame, a velvet rope on gold posts and a gold VIP neon beside the door, at eye level.
  - Inside: red velvet walls with gold mouldings, black marble floor and a gold chandelier.
  - A round stage with a pink neon edge and a chrome pole (`VIP_tubo`).
  - The gold blackjack table: black felt `blackjack_vip.png` with gold letters, a gold rail and gold chips.
  - Two velvet booths with gold side tables and champagne buckets.
  - A display case of gold bars, and a pink CLUB neon.
  - Gold chips are `FICHA_COLORES[4]`.
- **Bathroom** (`banho()`, behind the east wall of hall 2, `BANO`): the door hangs on `Bano_bisagra` and opens into hall 2.
  - Inside: dirty tiles (`azulejo.png`), a green-and-black floor (`azulejo_piso.png`), two stalls (one door hanging off), toilets, a urinal, two sinks with the shattered mirror and an empty mirror frame.
  - Also: the drain with a stain (`banho_mancha`, multiply blend), graffiti ("NO ESTAS SOLO"), rusty pipes and a bare bulb (`Luz_bano`).
  - Textures come from `arte.py banho()`.
- **Chips:** `ficha_piezas()` builds a casino chip: rounded 24-sided edge, six white edge inserts and a lighter centre inlay.
  - Table stacks are one mesh each (`torre_fichas()`).
  - `models/sotano/ficha.glb` (`Ficha_0..3`, one per colour) feeds `PilaFichas`.
- **Round tubes:** `tubo_curva()` sweeps a round tube along points, used for the padded rails of the baccarat and blackjack tables.
- **Decoration** (`decoracion()`, after AG's photo):
  - a jukebox with a pink and violet neon arch on the south wall of hall 2 (`Luz_rocola`);
  - a dartboard with three darts;
  - four tequila barrels with hoops in the south-east corner;
  - five bare bulbs hanging over the bar.
- **Bottles:** `botella()` turns a profile on the lathe (`girar()`) and joins glass, label and cap into one mesh (`juntar()`).
  - Types in `BOTELLAS`: tequila, mezcal (with its worm), whisky, rum, beer, caguama.
  - `botellas.glb` has one of each at the origin (`Botella_<tipo>`), for the waitress's tray.
- **Name suffixes:**
  - `-convcol`: solid box.
  - `-colonly`: collision only. Must be unique, or Godot renames the body.
- **Empties `Marca_*`** place everything else: lights, neons, posters, cabinets, NPCs, seats, the walking route `Camino_*`.
- **Neon:** `tools/blender/sotano/neones.py` exports `models/sotano/neones.glb`, one `Neon_<name>` empty per sign, facing +Z.
  - **Dice** (`dado()`, sign `dados`): two corner-view cubes, red and blue, with white pips, beside the fridge.
  - **Block letters** use `TRAZOS`, a hand-made single-stroke alphabet: one tube per stroke, like real neon, with wider spacing. Glyph outlines gave two tubes per stroke and read as mush at 640 × 480.
  - **Script words** (Pacifico) are filled, thin glyphs. The text halo is thinner (`HALO_TEXTO` 2.0).
  - **Shapes:** curves with a bevel, turned into meshes.
  - **Halo:** a thicker copy of each tube in an additive material. It glows without environment glow.
  - **Bulbs:** two meshes per sign (`_focos_a`, `_focos_b`) that take turns.
  - **Brackets:** black rails behind each sign.
  - **Fonts:** block letters use Blender's font; the hand-written words use `fonts/Pacifico.ttf` (OFL, credited in `CREDITS.md`).
  - **Signs:**
    - EL GORDO: hangs back to back from the middle beam of hall 1.
    - ¡Premio!: over the south machines.
    - PÓKER: with the four suits and "Texas".
    - ABIERTO 24 HRS.
    - Tecatl with a beer mug: on the bar front.
    - BAÑO: with an arrow.
- **Art:** `tools/blender/sotano/arte.py` renders with flat Workbench and no AA (`SOLO=(...)` renders only some):
  - `textures/sotano/cartas.png`: 24 lotería card frames, 96 × 144 each (the size they show on the screen), with only the colour field: no picture, no name.
  - `textures/sotano/baraja.png`: the playing cards for poker, blackjack and baccarat, crisp pixel art drawn by code in `tools/sotano/dibujar_baraja.gd`. The Blender version looked pencilled by hand.
    - 14 × 4 cards of 128 × 192 (`PokerUI.CARTA_PX`).
    - Ranks use a pixel font (`LETRAS`); suits are 9 × 9 bitmaps (`PALOS`), scaled up.
    - Pips follow the classic layout, with the bottom ones upside down; from the 7 up they are smaller.
    - The faces are cartoon portraits (J with a feathered cap, Q with long hair, K with a beard and crown).
    - The back is El Tinaco on a wine-red lattice.
  - `textures/sotano/cartas_dibujos.png`: the card pictures, cartoon pixel art drawn by code in `tools/sotano/dibujar_cartas.gd` (`godot --path . --headless -s tools/sotano/dibujar_cartas.gd`).
    - Shaded balls with a highlight, polygons with a drop shade, big eyes and faces, a 1 px dark outline.
    - Transparent 8 × 3 atlas of 80 × 80.
    - `CartasLoteria.dibujo(i)` returns one; `OlPleyUI` puts it over the colour field and writes the name below.
    - The 3D renders (`cartas3d.py`) were dropped.
  - `calcomanias.png` and `pantalla.png`: the EL GORDO cabinet and its idle screen.
  - `pantalla_juego.png`: the 384 × 288 game screen background.
  - The deck (`baraja.png`) is no longer made here: see `tools/sotano/dibujar_baraja.gd` below.
  - `anuncios.png`: six beer posters (`CERVEZAS`): Tecatl, Indita, Coronela, Modelito, Pacífica and the caguama deal.
  - `textures/maquinita/adorno_frutas.png`.
- **Materials:** `scripts/sotano/SotanoPostImport.gd` is the import script of every Sótano `.glb`. It swaps Blender materials by name for the game's:
  - textures;
  - glowing tubes;
  - `neon_*`: neon cores;
  - `*_halo`: additive halos;
  - `foco_*`: bulbs;
  - `vidrio_*`: glossy glass (mezcal is see-through);
  - `cromo`.

  A new `.glb` needs `import_script/path` set in its `.import` file. The Blender scripts delete materials when cleaning up, because a preview texture got embedded once.

## What's inside (`Sotano.gd`)

- **Light:** ten tube lights (two fail: `PARPADEAN`), the window lamp, the poker lamp.
- **Neon** (`NEONES`): instances from `neones.glb`, each with:
  - its scale;
  - a coloured light;
  - bulbs taking turns every `FOCOS` s;
  - some signs fail (`_parpadear` hides the sign).
- **Beer posters** (`CARTELES`): one shared material per poster.
- **Games and things to use:**
  - The ten EL GORDO (`GabineteOlPley`) and the two fruit machines in chip mode.
  - **The bathroom:** `_armar_bano`.
    - The door opens and closes (`_puerta_bano`); a `StaticBody3D` blocks the doorway while it is shut.
    - The bulb flickers, a soft fog drifts (`CPUParticles3D` with a radial gradient), a broken radio loops procedural static (`_estatica`, 3D), and it drips while you're inside.
    - The mirror and the stall say unsettling things (`LINEAS_ESPEJO`, `LINEAS_CASETA`).
    - **The candy man** sits on his stool by the entrance (`Marca_Bano_dulcero`, smoking).
      - His stand (`Bano_puesto`) carries sweets, lollipops, cigarettes and little bags.
      - `DulceroUI` ("¿Algo pa' la fiesta, joven?") sells for chips: mazapán, gansito, cigarettes and "algo pa' la fiesta" (the tachas, 16 chips).
  - The window (`VentanillaUI`), the poker (`PokerUI`), the races (`CarrerasUI`).
  - The freezer (a caguama for 3 chips), the bar (a Tecatl from the bartender for 2 chips; the same caguama item), the altar.
- **People:**
  - Talkers on `npc.tscn`: guard, Primo, bartender, dealer, onlooker. The onlooker points out the hot EL GORDO.
  - Seated: four at EL GORDO stools and three on the poker chairs (`Civiles` with `Sitting_Idle`, moved forward by `CADERA`).
  - Seated vices (`VICIOS`): some smoke (a cigarette with a smoke puff) or hold a beer. `_dar` attaches the object to the hand bone with a `BoneAttachment3D`, scaled by 1 / `Civiles.ESCALA`.
  - Shady people standing (`TURBIOS`, talkers with their own clip and lines):
    - the lookout by the stairs, who sweeps his head;
    - a deal in the bar corner (packet and bills);
    - the one counting the machines' money;
    - the drunk at the bar (`Drink`).
  - `GenteSotano`: five walkers on fixed routes of `Camino_*` and the waitress.
    - Some walkers stay in hall 1, around the track; others go through the arch to the bar.
    - The waitress walks with `Walk_Carry`, and her tray (two real Tecatl bottles) sits level between her hands every frame (`_process`). When she stops, the clip freezes. Her `MuebleCasa` follows her and sells a Tecatl.
- **Ambience:** the speaker loops `bocina_musica`, and the two fans spin.
- **Leaving with chips:** the Primo shouts once if you go up the stairs carrying chips.

## The games (the house cheats, with tells)

- **Chips:** $5 each (`Fichas.PRECIO`). Cashing out leaves 10% with the Primo.
- **EL GORDO** (`OlPleyUI`): the camera flies to the cabinet, framing the screen with the lever on the right. The game runs in a 384 × 288 `SubViewport` that the cabinet shows on its screen (`GabineteOlPley.mostrar_en_pantalla`).
  - **The lever:** the `Palanca` empty of `gabinete()`. Space or ↓ pulls it: `GabineteOlPley.jalar_palanca` swings it down 55° and springs it back, and the reels start at the bottom of the pull.
  - **The screen:** cylinder shading over the reels, marquee bulbs that chase (faster while spinning), 7-segment counters, and a banner that scrolls the prize (`_cruzar_letrero`).
  - **Reels:** lotería cards that scroll and stop one by one with a bounce. Each card shows its name in caps, in `PixelifySans` with no antialiasing (`_poner_carta`).
  - **On a win:** the pay line blinks, the counters show bet, chips and prize, and pixelfx plays: coins (`resources/fx/olpley_monedas`) or confetti (`olpley_confeti`).
  - **The board** is `Carretes`: about 89% return, a win one spin in four, El Tinaco is wild and pays double. `SIN_CAJA`; when it is `CALIENTE`, the marquee light blinks.
- **Fruit machines (everywhere):** simpler play in `TragamonedasUI`.
  - One fruit at a time: ←/→ moves the bet to another fruit, ↑/↓ sets 1–9 coins, Space spins.
  - The TIRAR and SALIR labels sit on the front panel above their button groups (`tools/map_import/make_maquinita.gd`).
  - `Maquinita.moneda = "fichas"` charges chips and keeps them open at night.
- **Sounds:** Raw Signal Casino LITE (`audio/casino-effects/`, from AG; the MP3 copies carry a `.gdignore`). Registered in `Sonidos.ARCHIVOS` and `DefensaTinaco.SONIDOS`:
  - `slot_palanca`, `slot_carrete`, `slot_boton`, `slot_gana`, `slot_gana_grande`, `slot_premio_mayor`;
  - `monedas_caen`, `ficha_cae`, `apuesta_sube`, `carta`, `ficha_mesa`, `caballitos`.
  - They are also used by the fruit machine (spin button, win) and the window.
- **Texas Hold'em:**
  - **Rules** (`Holdem.gd`): fixed limit (blinds 1/2, raises of 2 then 4, 3 raises per round), best 5 of 7 with Spanish names, no side pots. The house takes 10% of each pot (up to 5).
  - **AI:** Doña Cuca is tight and Tacho bluffs. "El de la gorra" is the house's player: from the turn on he knows whether he beats you. The bartender and the onlooker drop hints.
  - **Table** (`PokerUI`): the camera flies to your seat and looks under the lamp.
    - The board and the neighbours' cards lie on the felt in 3D. The neighbours' cards sit 0.5 m from the centre, so the far ones don't clip the rail.
    - The 5 board cards are also shown on screen, top centre, flipping as they land.
    - On the table: chip towers, beers, an ashtray, the deck.
    - Chips entering the pot play `ficha_mesa`.
  - **Cards move:**
    - The dealer deals one card at a time from his deck, in an arc and spinning (`_repartir`, `_volar`).
    - Board cards come out face down and flip (`_voltear`).
    - A player who folds tosses his cards to the deck (`_tirar_al_mazo`).
    - At showdown the neighbours' cards flip one by one.
    - Your two cards on screen enter face down and flip.
  - **Keys:** C check/call, R raise, F fold, Space next hand, Esc stand up. You play with your chips.
  - The NPCs' stacks persist between hands, and they rebuy at the window when broke.
- **VIP** (`Sotano._armar_vip`):
  - **Getting in:** the bouncer outside charges the pass (`Fichas.CUOTA_VIP` $500, once; `Fichas.vip`, reset per run). Until you pay, a body blocks the rope (`_cordon`); paying hides the rope.
  - **Gold blackjack:** `BlackjackUI` with `prefijo` `VIP_bj`, bets from 10 to 100 in steps of 10, dealer "Doña Oro".
  - **People:** the dancer turns slowly round the pole (`Idle_Talking`), and rich players smoke cigars (`puro`) at the gold table and in the booths.
  - **Light:** gold, pink and violet (`LUCES_VIP`).
  - In the test scene, V gives the pass.
- **Table camera:** `JuegoSotano.acercar_camara` / `regresar_camara` (blackjack, roulette, baccarat).
- **Chips on the felt** (`PilaFichas`, roulette and baccarat): one chip per chip you bet; the stack moves to the spot you pick.
  - On a win the dealer slides the payout next to it and pushes both to you (on cash-out in the roulette).
  - On a loss the stack slides to the dealer.
- **Celebrations** (`JuegoSotano.festejar`, roulette, blackjack, baccarat; the streak is kept per game for the whole run):
  - A win shows "¡GANASTE!" with coins.
  - A second win in a row shows "¡OTRA VEZ!" with confetti; three or more show "¡RACHA DE n!" with confetti, rays and the jackpot sound.
  - A loss shows "CHALE..." with smoke and a dark flash; after three losses in a row, "¡QUÉ SALADO!".
- **Blackjack** (`Blackjack.gd`, `BlackjackUI.gd`):
  - The dealer is La Güera. She stands on all 17s; a natural blackjack pays 3 to 2; you can double on two cards.
  - Keys: ←/→ bet, Space deal, H hit, S stand, D double.
  - The cheat: with bets of `CARGADO_DESDE` (5) or more she sometimes stacks the shoe, so her hole card puts her on 20 or 21. Tell: she adjusts her earring.
- **Roulette** (`Ruleta.gd`, `RuletaUI.gd`):
  - Bets are red or black (1 to 1) or green (35 to 1) only. ↑/↓ colour, ←/→ bet, Space spin.
  - After a win, C cashes out or D doubles (`dobletear`): everything goes back on a colour, once. If the doblete loses, it's all gone; if it wins, it cashes out by itself.
  - The wheel slows to a stop.
  - The ball runs the outer track the other way, drops into the pockets and bounces between separators, ticking.
    - The bounces use gravity.
    - It rolls by the distance it travels.
    - It is the UI's own smooth sphere with a few grey specks, so the roll shows; the room's ball is hidden while you play.
  - The spin is slow and long (`GIRO` 6.5 s, 1.1 wheel turns, 3.4 ball turns).
    - Faster, each frame skipped almost two pockets, and at 640 × 480 the separators strobed.
    - A translucent red-black blur ring (`_barrido`) covers the pockets while the wheel is fast and fades out as it slows.
  - The cheat: with `FRENO_DESDE` (10) or more at stake the ball sometimes jumps to the next pocket, which is always another colour. Tell: the dealer taps the table.
- **Baccarat** (`Baccarat.gd`, `BaccaratUI.gd`):
  - Bets are on punto, banca or empate.
  - Player 1 to 1, banker 1 to 1 minus 5 %, tie 8 to 1 (punto and banca get their bet back on a tie).
  - The drawing rules: natural 8 or 9, the player draws on 0 to 5, and the banker's third-card table (`banca_pide`).
  - The cheat: with bets of `ARREGLO_DESDE` (5) or more, if you were going to win, Don Chepe sometimes reshuffles and deals again. Tell: he blows on the cards.
  - The cards are also dealt on the felt: each flies from the shoe in an arc and flips, the player hand on the left and the banker hand on the right over the EMPATE strip, with the third card turned sideways (`_carta_mesa`). Don Chepe sweeps them away on the next hand.
- **Races** (`CarrerasUI`): the camera flies to watch the track from the north while the horses run (`_ver_pista`), then returns.
  - Odds 2/3/5/8/12, with chances proportional to 1/odds.
  - A bet of 5+ halves your horse's luck, and the house's horse trembles first (`Sotano.temblar`).

## La Desaguadora (the secret boss, AG 2026-11-19)

Knock three times on the closed bathroom stall (`Sotano._tocar_caseta`, `TOQUES_SECRETO`). The door swings open by itself (`Bano_caseta_bisagra`) and reveals a rusty hatch on the floor (`Bano_escotilla`). "Bajar por la escotilla" builds the drain room far below the bathroom (`DESAGUE_EN`) and puts you on its ladder with combat on.

- **The arena** (`tools/blender/sotano/desague.py` → `models/sotano/desague.glb`): Silent Hill 2 mood, but our own.
  - Rusty sheet walls (`oxido.png`) with flesh growing on them (`carne.png`), and a rusted grating floor.
  - A black water pool in the middle, ringed by chain-link fences (`reja.png`, alpha) with two gaps.
  - Five drains (`Coladera_*`), thick pipes with valves, hanging chains with hooks and caged red lamps.
  - A big wall fan that turns, a rusty gurney and an overturned wheelchair.
  - The ladder up (`Entrada`/`Salida`). Textures come from `arte.py desague()`.
- **The arena logic** (`Desague.gd`):
  - Volumetric fog: it turns it on in the Environment and adds a `FogVolume`, then restores the Environment on leaving. The fog thickens and reddens per phase.
  - On arrival a procedural siren plays, followed by a low drone.
  - The boss bar.
  - You can't faint here: a blow that would kill you sends you back up to the bathroom with `VIDA_RESCATE` (`herir_jugador`).
  - Win: `PREMIO_FICHAS` 300 and `resources/productos/varilla_desague.tres` (24 damage; `models/armas/varilla/varilla.glb`), once per run (`Fichas.desaguadora`).
  - "Subir por la escalera" goes back up at any time (she resets).
- **The boss** (`Desaguadora.gd`, `models/sotano/desaguadora.glb`): a bloated faceless woman of drain hair and black water, 3.2 m tall.
  - **Model:** a skirt of wet hair strands, a hunched grey-blue torso, a hair curtain over the face and chest, and very long arms with extra fingers. There is no rig: the code moves the empties `Hombro_L/R`, `Cabeza`, `Pelo`.
  - **Damage:** she is in the `zombis` group with `recibir_golpe` and `radio_golpe`, so the machete reaches her. The pistol reaches her through `PuntoDebil` (body ×1, heart ×2.5 while exposed).
  - **Attacks, all telegraphed:**
    - zarpazo: the right arm rises, then sweeps a cone in front;
    - charcos: red circles grow where you stand, then burst into black water;
    - pelo (phase 2+): a red line, then the hair whip along it;
    - gotas (phase 3): black water falls from the ceiling over you;
    - hundirse: she sinks into a drain and rises from the one farthest from you.
  - **Opening:** after the zarpazo her chest opens for `EXPUESTA_DURA` s: the heart glows and melee does ×2.
  - **Life and phases:** `VIDA` 650, phases at 0.6 and 0.25 (she screams and gets faster).
- **Test scene:** `-- --desague=<dir>` knocks, goes down, saves frames, stands you next to her and prints your life.

## Tests

- `godot --path . tools/sotano/probar_sotano.tscn -- --capturas=<dir>` (needs a window; the folder must exist) ends with `RESULTADO: BIEN`. Steps:
  1. Enter the Sótano and check the people; the walkers stand on the floor and the floor's top face points up.
  2. Check the chain and the cuota.
  3. Buy chips at the window.
  4. Play 20 EL GORDO spins on the screen.
  5. Play a poker hand.
  6. Run a race.
  7. Buy beers at the freezer, the bar and from the waitress.
  8. Play a simple fruit spin.
  9. Cash out and leave.
  10. Also: the VIP pass and a gold-blackjack hand, the secret door (three knocks, the hatch), going down to the drain, beating La Desaguadora through her phases, the reward, and climbing back up.
- `godot --path . --headless -s tools/sotano/probar_holdem.gd` runs known hands plus 2000 AI hands and checks there are no stalls and no lost chips.
- `godot --path . --headless -s tools/sotano/probar_mesas.gd` checks the blackjack, roulette and baccarat rules, payouts and cheats (thousands of rounds).
- `probar_sotano` also plays one hand of blackjack, one of baccarat, and a roulette spin (with the doblete if it wins).

## Pending

- Real sounds (JJ picks). The games reuse `boton`, `paso` and `moneda`; the speaker uses `bocina_musica`.
- The Gotera missions that grant `permiso`.
- Walkers pass through the player and each other (no navigation).
