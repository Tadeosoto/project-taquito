# Prompt de Blender: La Mojiganga

Propuesta de AG (2026-11-09; falta que el equipo la vote, `revision-historia` 4.14). Un jefe al estilo Dark Souls: la catrina gigante de cartonería del desfile de Día de Muertos, empapada de Serenol y movida desde adentro por un nudo de zombis (lore §16). El código ya existe (`scripts/catrina/Catrina.gd`) y usa un cuerpo provisional de figuras hasta que este modelo esté en `models/personajes/catrina/catrina.glb`; en cuanto exista, lo carga solo. Los nombres de los clips, huesos y mallas de abajo son los que busca el código: no los cambies.

---

**Goal.** Using the Blender MCP, build **La Mojiganga**, a rigged, animated low-poly boss for the Godot 4.7 game *Guadalajaja* (PS1 look, a Zapopan barrio). Also build her two drops as separate props.
- Deliver into `models/personajes/catrina/`: `catrina.glb`, `catrina.png`, `femur.glb`, `corona.glb`, `preview.png` and `fuente/catrina.blend` (with an empty `fuente/.gdignore`, so Godot doesn't try to import the `.blend`).
- Start with `get_addon_status` and `get_scene_info`, and use `look` after every major step.
- Work in a new scene named `Catrina`. Don't touch or delete anything in the user's other scenes.

**Who she was.** The colonia was getting its Día de Muertos parade ready, and this year's star was a **giant parade catrina**: a mojiganga, papier-mâché over a frame of carrizo (river cane), danced from inside by the neighbourhood boys. The outbreak hit a week before the parade and she was left standing in the plaza. The tap water (the Serenol) rained on her for days and soaked her through. The zombies that hid under her skirt from the sun got stuck to the cane frame, tangled into each other: **a knot of them walks her from inside her chest**, like a puppet. She drips dirty water.

**Originality rules (important).**
- Inspired by Mexican parade catrinas in general, **not a copy of any photographed figure or artist's piece**. Use our own embroidery pattern, face paint and colours.
- No brands, logos, text or real people's faces. The catrina is a public cultural icon (Posada); keep the design generic and ours.

**Look (cartonería, PS1).**
- **Size and build:** 6.0 m tall, a tall thin skeleton lady. It must read as **papier-mâché**: visible paper seams, slightly lumpy surfaces, painted rather than real bone, matte.
- **Skull:** big (about 1.2 m tall), painted like a sugar skull: cream base, big dark eye sockets, a wide toothy grin with the jaw a little open, a small painted flower on the forehead, blush dots on the cheekbones. Our own simple pattern.
- **Hair:** dark brown, pulled back into a big **braided bun** at the back of the head. A **long braid** hangs from the bun down to the waist (it whips in a clip, so it's a bone chain).
- **Flowers:** **four big paper flowers** across the top of the head (magenta, orange, purple, pink), each about 0.45 m across. These are the weak points: keep them chunky and readable from the floor.
- **Earrings:** long dangling pompom earrings, three pompoms each (green, orange, pink).
- **Blouse:** a purple huipil-style blouse with short puffed sleeves and a white ruffle at the hem of each sleeve, a V neckline with an embroidered flower band. Large simple embroidered ovals and swirls on the chest (our own pattern, not copied).
- **Sash:** a white sash at the waist with a band of embroidered flowers.
- **Skirt:** a long, full purple skirt to the floor, embroidered with a few big flowers and a bird, a white hem band. It hides the legs and feet completely when standing.
- **Arms and hands:** long thin painted-bone arms; bony hands with flower bracelets on both wrists. Idle pose: **left hand on the hip, right arm hanging**.
- **Wet:** darker damp stains climbing the skirt from the hem, drip streaks down the blouse, paper peeling at the edges.
- **Palette:** purple, cream bone, dark brown hair, white trim, flower magenta/orange/pink/green, dirty brown-green water stains.

**Phase meshes (separate objects, all skinned to the same rig).** The game shows and hides them by name:
- `Vestido`: the whole dress (blouse, sash, skirt). Visible in phase 1.
- `Vestido_Roto`: the same dress torn open: big ragged holes in the blouse and skirt, hanging flaps, darker and wetter. Hidden at first; shown in phase 2.
- `Carrizo`: the cane frame inside her: thin cane rods lashed with wire and rope around the torso and inside the skirt, seen through the holes. Hidden at first; shown in phase 2.
- `Nudo`: in the chest, a knot of three or four zombie torsos and arms fused together and tangled in the cane, greyish skin with milky Serenol veins, glowing faintly turquoise. About 1 m across. Hidden at first; shown in phase 3.
- `Craneo`: the skull, hair, bun, braid, flowers and earrings as one object, skinned only to the head and braid bones. The game hides it in phase 3 (her head falls off) and drops its own skull prop.
- The bony arms, hands, neck and feet are one more object (any name).

**Technical spec (match the game and the Panzón).**
- **Mesh:** up to 6,000 triangles total, no modifiers left unapplied, no shape keys.
- **Texture:** one 1024×1024 PNG, albedo only, hand-painted look with baked fake shading.
  - Material: Principled BSDF with the texture on Base Color, roughness 1, metallic 0.
  - The game uses nearest filtering, so paint for it.
- **Units:** metres, scale applied, origin at the feet (centre of the skirt's base). She faces **-Y** in Blender (+Z in Godot).
- **Rig:** humanoid armature with Mixamo-style names as in `resources/personajes/huesos_mixamo.tres` (read it first), with an underscore (`mixamorig_Hips`, `mixamorig_Spine1`…). Hidden legs still get bones (the stomp lifts one), and the skirt is weighted to the hips and thighs so it lifts with the stomping leg.
- **Extra bones** (the code finds them by these exact names):
  - Deform: `Trenza_0`..`Trenza_5`, a chain from the bun down the braid (child of `mixamorig_Head`).
  - Non-deform markers, each placed where the game needs the point:
    - `Mano_R` (child of `mixamorig_RightHand`, at the palm centre: where she holds the player), `Mano_L` (same, left).
    - `Pie_R` (child of `mixamorig_RightFoot`, at the sole).
    - `Cabeza` (child of `mixamorig_Head`, at the skull's centre).
    - `Trenza_Punta` (child of `Trenza_5`, at the braid's tip).
    - `Arete_L`, `Arete_R` (children of `mixamorig_Head`, at each earring's top).
    - `Flor_0`..`Flor_3` (children of `mixamorig_Head`, at each flower's centre, left to right as she faces you).
    - `Pecho_Nudo` (child of `mixamorig_Spine2`, at the knot's centre, slightly in front of the chest).
- **Animations:** one Action per clip, one NLA track each, 30 fps.
  - **All in place, no root motion.** The game moves the body, including the lunge.
  - The loop clips' first and last frames match.
  - For the grab clips, the player is held in `Mano_R`; the game moves them with it.

| Clip | Frames | Loop | What it shows | Timing the game needs |
|---|---|---|---|---|
| `Idle_Pose` | 60 | yes | Standing tall, left hand on the hip, right arm hanging, a slow sway; the braid and earrings swing a little. Also her opening pose between attacks | — |
| `Walk` | 48 | yes | A stately parade walk, hips swinging, the skirt rocking, ~1.4 m/s | — |
| `Stomp` | 51 | no | Lifts the front of the skirt with both hands, the right bony foot comes up high, then stamps down in front of her | foot up and held 6-24, lands at 24 |
| `Grab_Reach` | 69 | no | Bends from the waist, right arm drawn back, then sweeps the hand low across the floor in front of her (reach 3-7 m) and straightens slowly if it missed | arm back 0-30, sweep 30-40, upright at 69 |
| `Grab_Hold` | 30 | yes | Holding someone in the right hand at face height, squeezing in pulses, head tilted, looking at them | squeeze every 15 |
| `Throw` | 30 | no | Swings the held arm across and throws to her right | release at 9 |
| `Grab_Escape` | 39 | no | The victim wriggles free: she shakes the empty hand, offended | — |
| `Braid_Whip` | 45 | no | Turns her head and whips the braid straight out toward the target (up to ~14 m; the braid stretches, it's papier-mâché magic) and pulls it back | out at 21-28, back by 45 |
| `Kneel_Stagger` | 24 | no | A flower bursts: she drops to her knees, the skull lolls forward at about 3 m | on her knees at 18 |
| `Kneel_Idle` | 40 | yes | On her knees, swaying, head low | — |
| `Rise` | 30 | no | Gets back up from her knees | — |
| `Tear_Roar` | 75 | no | Phase 2: rears back, arms out, and screams; the dress tears (play it on `Vestido`; the game swaps to `Vestido_Roto` at the start) | — |
| `Skirt_Spin` | 60 | no | Sways the skirt as a warning, then spins two full turns with the arms out, the skirt flaring | sway 0-27, spin 27-45 |
| `Earrings_Snap` | 36 | no | Bends her head down and shakes it: the pompom earrings snap off | snap at 18 |
| `Scream` | 60 | no | Throws the head back and screams forward, jaw wide | scream at 24 |
| `Head_Fall` | 75 | no | Phase 3: the head tips and falls off (`Craneo` hidden by the game), she collapses onto all fours | on all fours at 45 |
| `Crawl` | 40 | yes | Crawling on hands and knees, ~1.8 m/s, the torn skirt dragging behind | — |
| `Crawl_Slam` | 45 | no | From all fours, raises the right hand high and slams it down 2.5 m in front | hand lands at 24 |
| `Crawl_Lunge` | 48 | no | Coils back, then lunges forward along the floor (the game moves her 6 m) | lunge 18-33 |
| `Death` | 75 | no | The frame buckles: she folds forward and sinks, the knot bursts. Last frame held | on the floor at 60 |

**The drops.**
- `femur.glb`: a bat-sized thigh bone (0.95 m) of painted papier-mâché with a cane core poking out of one cracked end, under 300 triangles, its own 128×128 texture. Origin at the grip end.
- `corona.glb`: a ring of five small paper marigolds (cempasúchil) with a wire band, about 0.3 m across, under 300 triangles, 128×128 texture. Origin at its centre.

**Export.**
- `catrina.glb`: the rig and all six mesh objects (keep the object names), the active scene only, NLA tracks as animations, starting at 0, +Y up. `Vestido_Roto`, `Carrizo` and `Nudo` can be visible in the file: the game hides them on load.
- `femur.glb` and `corona.glb` the same way, each from its own object.
- `preview.png`: a front 3/4 view of `Idle_Pose` at 512×384.
- `fuente/catrina.blend`: written with `bpy.data.libraries.write`, so the user's open file isn't re-saved under a new name.

**Check before finishing.**
- Report the triangle count per object, the bone count and the clip list with frame counts.
- Use `look` on: front, 3/4, `Stomp` at 24, `Grab_Reach` at 35, `Braid_Whip` at 25, `Kneel_Stagger` at 18, the torn dress with the frame showing, and `Crawl` with the knot showing.
- Check that no clip sinks into the floor (lowest vertex ≥ about −0.01 m) and that the skirt never clips through the legs in `Walk` and `Stomp`.
- Confirm she reads as a papier-mâché parade figure, not a real skeleton, and that the four flowers are easy to see from 10 m below.
- After export, in the game: `godot --path . --headless --import`, then `godot --path . scenes/catrina.tscn`. The code turns her 180° (`rotation.y = PI`, like the Panzón) and hides the phase meshes by name.

---

## Hecho (2026-11-09): por script, v3 "Dark Souls"

AG pidió más detalle y que se viera jefe de Dark Souls; se hizo con Claude por el MCP de Blender, todo por script en `tools/blender/` (orden y uso en su `README.md`). Lo que cambió respecto a lo de arriba:

- **Flujo de esculpido horneado**: una versión de alta (~200k triángulos, nunca va al juego) con cráneo agrietado (booleanas, carrizo adentro), dientes disparejos y quijada zafada, tela colgada del armazón entre vara y vara, olanes, bordado en relieve, parches cosidos, cuerda torcida, alambre y clavos; su color (fotos CC0 de Poly Haven + calavera deslavada, lágrimas de agua sucia, manchas del ruedo para arriba, mugre en lo hondo) se hornea en la malla del juego.
- **Malla del juego**: ~7.2k triángulos a la vez (AG pidió ~8k tras compararla con el Panzón, 2,550). Los seis nombres de arriba. Textura `catrina.png` 2048 con la mugre puesta y `catrina_emision.png` (brillo de Serenol en las cuencas, ojos y venas del nudo, flamas de las velas).
- **Silueta nueva**: un **resplandor** de ~4 m de varas de carrizo rotas con velas y cempasúchiles (dentro de `Craneo`, cae con la cabeza) y una **cola** de 3.6 m que se arrastra (huesos `Cola_0..3`).
- **Joroba**: el torso inclinado 13° y la cabeza adelantada 16°; brazos largos y garras.
- **Esqueleto**: nombres de Mixamo con guion bajo, `Trenza_0..5`, `Cola_0..3` y los marcadores tal cual la tabla. Un hueso extra, `Ruedo`, en el piso y sin clips: la falda reparte su peso entre el (abajo) y la cadera (en la cintura), asi al hincarse o gatear se aplasta en vez de hundirse o doblarse con la espalda; la cola cuelga de el. Pesos calculados por distancia a los huesos (los automáticos de Blender no se llevan con estas mallas).
- **Clips**: los 20 de la tabla, con sus cuadros. Son poses clave sencillas (primera pasada); el agarrón (llega al frente y abajo), el gateo y el latigazo de la trenza (una onda que baja hueso por hueso, `_latigo()`) ya se corrigieron.
- **Tela simulada** (2026-11-10): el rebozo y la cola son una simulación de tela de Blender (`catrina_tela.py`) en vez del drapeado a mano.
- **Piezas**: `femur.glb`, `corona.glb`, `craneo_caido.glb` (la cabeza que cae, la usa `Catrina._tirar_cabeza`) y `pompon.glb` (lo usa `PomponRodante`), todas abajo de 300 triángulos (160-268).
- **La plaza**: `models/escenarios/plaza_catrina/plaza_catrina.glb` (portales de cantera con arcos y balcones, kiosco, cuatro carros alegóricos, seis ofrendas y el papel picado; ~21k triángulos; colisiones `-colonly`). `PruebaCatrina` la carga si existe y ya no pone su papel picado.
