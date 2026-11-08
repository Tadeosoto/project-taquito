# Prompt de Blender: El Panzón

Propuesta de AG (2026-11-08) **para el tipo GORDO de `Zombie.gd`; falta que JJ la confirme** (CLAUDE.md dice que los ataques del gordo los define él). Arranca piedras del suelo y te las avienta, te embiste, te azota, te pisa tres veces y te avienta lejos. El papel viene de Left 4 Dead (tanque y embestidor), la cara es nuestra. Si JJ dice que no, el `zombie_gordo` viejo sigue ahí.

---

**Goal.** Using the Blender MCP, build **El Panzón**, a rigged, animated low-poly special zombie for the Godot 4.7 game *Guadalajaja* (PS1 look, a Zapopan barrio). Also build the rock he throws as a separate prop.
- Deliver into `models/personajes/panzon/`: `panzon.glb`, `panzon.png`, `roca.glb`, `preview.png` and `fuente/panzon.blend` (with an empty `fuente/.gdignore`, so Godot doesn't try to import the `.blend`).
- Start with `get_addon_status` and `get_scene_info`, and use `look` after every major step.
- Work in a new scene named `Panzon`. Don't touch or delete anything in the user's other scenes.

**Who he was.** *El carnal de la cuadra*: the big guy everyone on the block knew, who sat on the corner and kept an eye on things, and lifted whatever needed lifting. He died at dawn and got up swollen with Serenol. Now he tears the street apart to throw it at you, and runs you down like a truck.

**Originality rules (important).**
- This is an original character. It must not look like Left 4 Dead's Tank or Charger, or any other existing game character: no oversized single arm, no hunchback of rock, no exposed-muscle look.
- No real gang symbols, numbers, logos or brands. Tattoos are generic and hand-drawn.

**Look (Mexican barrio, PS1).**
- **Body:** 2.3 m tall, hunched, an enormous belly, wide shoulders, thick arms and legs, a head that looks small on top of all that. Dead greyish-brown skin with darker veins on the belly and neck. Dried white drool at the mouth corners (the Serenol).
- **Head:** shaved, under a black **hairnet**. A thick drooping mustache. Small round dark glasses, one lens cracked, with milky white eyes behind them. A small **tinaco** tattooed under the left eye.
- **Tee:** a huge white tee down to the knees, filthy (dirt, dried blood, grey stains).
  - Front: torn open in the middle, the belly bursting through.
  - Back: a long tear showing a tattoo of a generic rays-and-roses devotional piece (no face, no text).
- **Pants:** baggy khakis with a sharp ironed crease (now filthy).
- **Socks and shoes:** long white socks showing above the hem, black cloth slip-on shoes.
- **Accessories:** a thick chain with a round medalla on the chest, a red rag hanging from the back pocket.
- **Palette:** off-white, khaki, black, greyish-brown skin, dried brown-red, a touch of red (rag) and gold (medalla).

**Technical spec (match the game and the Saltabardas).**
- **Mesh:** up to 5,000 triangles, one object, no modifiers left unapplied, no shape keys.
- **Texture:** one 512×512 PNG, albedo only, hand-painted look with baked fake shading.
  - Material: Principled BSDF with the texture on Base Color, roughness 1, metallic 0.
  - The game uses nearest filtering, so paint for it.
- **Units:** metres, scale applied, origin at the feet. He faces **-Y** in Blender (+Z in Godot).
- **Rig:** humanoid armature, T-pose or A-pose rest pose.
  - Bone names: the Mixamo-style names in `resources/personajes/huesos_mixamo.tres` (read it first), with an underscore (`mixamorig_Hips`, `mixamorig_Spine1`…).
  - Give the elbows a small bend in the rest pose: perfectly straight arms won't bend under IK.
  - **One extra non-deform bone `Roca`, child of `mixamorig_Hips`.** The clips animate it to the middle of the slab between his hands, and the game attaches the rock prop to it. Keep it parked behind the hips when there's no rock.
  - The tee, chain and rag have no bones of their own: weight them to the spine and hips.
  - Clean weights for a huge belly: check the deep crouch and the stomp.
- **Animations:** one Action per clip, one NLA track each, 30 fps.
  - **All in place, no root motion.** The game moves the body, including the charge.
  - The loop clips' first and last frames match.
  - For the grab, slam, stomp and throw, assume the player lies on the floor with their chest **1.0 m in front** of his origin.

| Clip | Frames | Loop | What it shows | Timing the game needs |
|---|---|---|---|---|
| `Idle` | 60 | yes | Standing hunched, heavy breathing, belly heaving, fists twitching | — |
| `Walk` | 40 | yes | Lumbering, side to side, ~1.2 m/s stride | — |
| `Run_Charge` | 20 | yes | Head down, one shoulder forward, arms back, pounding steps, ~8 m/s | — |
| `Roar` | 36 | no | Rears up and beats his chest twice, mouth open under the mustache. The warning before a charge or a throw | peak at 14 |
| `Rip_Rock` | 36 | no | Crouches, punches the street, digs his fingers in and pulls a slab up over his head (`Roca` follows the hands) | fist hits the ground at 10, slab overhead (held) at 30 |
| `Throw` | 24 | no | From the slab overhead: steps in and hurls it forward two-handed | release at 14 |
| `Grab` | 12 | no | End of a charge: arms close around someone in front | arms close at 6 |
| `Slam` | 20 | no | Lifts the grabbed victim and slams them down in front of him | victim hits the floor at 12 |
| `Stomp` | 18 | no | Raises one foot high and stomps the victim (chest 1.0 m ahead) | foot lands at 10 |
| `Throw_Player` | 26 | no | Bends down, grabs the victim, swings and throws them away to his right | picks up at 8, release at 16 |
| `Charge_Miss` | 30 | no | Misses the charge: slides on his heels, stumbles, recovers | recovered at 30 |
| `Wall_Bonk` | 48 | no | Charges into a wall: bounces back, wobbles dazed, shakes his head | hits the wall at 4, dazed until 40 |
| `Ground_Slam` | 30 | no | Both fists raised and hammered down onto the ground in front (close-range hit) | fists hit at 16 |
| `Swat` | 16 | no | Upper-body backhand to one side (knocks zombies out of the way while charging) | hit at 7 |
| `Hit` | 16 | no | Takes a hit: a small recoil and a grunt | — |
| `Death` | 48 | no | Drops to his knees, then falls flat on his back. Last frame held | on the floor at 32 |

**The rock (`roca.glb`).**
- A slab of street about 0.9 × 0.7 × 0.35 m, under 150 triangles, with an irregular outline.
- Asphalt on top with a painted lane-line fragment, broken concrete and dirt underneath.
- Its own 128×128 texture, origin at its centre.

**Export.**
- `panzon.glb`: only the rig and the mesh, the active scene only, NLA tracks as animations, starting at 0, +Y up.
- `roca.glb` the same way, from its own object.
- `preview.png`: a front 3/4 view of `Idle` at 512×384.
- `fuente/panzon.blend`: written with `bpy.data.libraries.write`, so the user's open file isn't re-saved under a new name.

**Check before finishing.**
- Report the triangle count, bone count and the clip list with frame counts.
- Use `look` on: front, back (the tattoo through the tear), 3/4, `Rip_Rock` at 30, `Stomp` at 10 and `Throw_Player` at 16.
- Check that no clip sinks into the floor (lowest vertex ≥ about −0.01 m).
- Confirm no Tank or Charger look: the huge white tee, hairnet, mustache, glasses, khakis with socks and slip-ons, and the tinaco tattoo are all there.

---

## v2 (2026-11-08): rounder, about 50 % more triangles

AG's notes on v1: "too blocky". The long tee hung like a flat-bottomed bell and the legs poked out of it like sticks. The reference is a sketch of one soft round blob with the legs coming straight out of a round belly. Change only the body; the rig, bones, clips, rock and files stay the same.

- **Tee:** it ends under the belly. It wraps the round belly and tucks in under it at the crotch. The front tear (belly showing) and the back tear (tattoo) stay.
- **Belly:** shaped like a ball. The radius grows fast from the crotch to the widest point (about 1.3 m up), then eases back to the chest. No flat bottom.
- **Legs:** they grow out of the belly's round underside. The thigh tops start inside the belly, so there's no visible step. They taper to the knee, then the khakis, socks and slip-ons as before.
- **Resolution:** 12 sides around the body, 10 on legs, arms and head. About twice the rings on the belly and legs. About 1,700 triangles in total.
- **Shading:** smooth normals (Gouraud) on the body, legs, arms and head. The mustache, glasses, chain, medalla, rag and shoes stay flat-shaded.
- **Weights:** the rings under the belly are mostly `mixamorig_Hips`, so bending a thigh doesn't drag the belly.

---

## v3 (2026-11-08): the bad water shows, bare torso, real hands

AG's notes on v2:
- The shoulders clipped out: the sleeves started outside the body and their tops stuck up past the shoulder line.
- The belly looked like a flat patch.
- The hands looked stuck on.

And above all: **he's a cholo the bad water (Serenol) killed and brought back**, and that has to show. The rig, the `Roca` bone and the 16 clips stay the same; budget up to about 2,500 triangles.

- **Tee torn off:** bare torso. Only filthy, soaked shreds of the white tee hang from the collar and the shoulders (ragged edges, flat-shaded). The rays-and-roses tattoo now covers the whole bare back, cracked.
- **Skin:** dead grey-green, with swollen milky-white veins (the Serenol) spreading from the belly and the neck.
- **Belly:** bloated like a water balloon and sagging over the waist of the khakis. Pale blisters, stretch marks, the navel at the centre of a milky vein web, a leak streak. A khaki waistband shows under the overhang at the sides and back.
- **Face:** jaw hanging open under the mustache (chin about 4 cm lower), dark mouth with teeth, cracked lips, white drool streaks, milky pupil-less eyes behind the dark glasses. The tinaco tattoo stays.
- **Wounds and stains:** a bite on one forearm (red flesh, teeth marks), dark soaked patches on the khakis, the right knee torn open, the left slip-on gone (dirty sock).
- **Shoulders:** no sleeve boxes. The arms grow out of the body (the first ring starts inside the torso, a deltoid follows the shoulder slope, weights graded `Spine2` → `Shoulder` → `Arm`). Smooth skin down to the wrist.
- **Hands:** big and meaty, blending from the forearm through a wrist ring.
  - A padded palm and three thick fingers side by side, weighted to `HandIndex1/2/3` so they curl together.
  - A thumb on the inner side (weighted to `Hand`), swollen knuckles, dark nails.
- **Shading:** smooth on skin and khakis; flat on the tee shreds, mustache, glasses, chain, medalla and slip-on.
