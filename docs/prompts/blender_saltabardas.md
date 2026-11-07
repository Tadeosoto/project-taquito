# Prompt de Blender: El Saltabardas

Propuesta de AG (2026-11-07). Zombi especial que se te echa encima: el papel de un *pouncer*, con una cara propia del barrio (no es el Hunter de Left 4 Dead). Este archivo es el prompt para pasárselo a Claude con el MCP de Blender; lo de Godot (el estado de inmovilizado en `Zombie.gd`, el aviso, el arco del salto) va aparte.

---

**Goal.** Using the Blender MCP, build **El Saltabardas**, a rigged, animated low-poly zombie for the Godot 4.7 game *Guadalajaja* (PS1 look, a Zapopan barrio).
- Deliver one `.glb` plus a texture and a preview into `models/personajes/saltabardas/`.
- Start with `get_addon_status` and `get_scene_info`, and use `look` after every major step.
- Work in a fresh scene; don't touch the user's other objects.

**Who he was.** A *chavo de la esquina*: the skinny kid who hung out on the corner and jumped bardas (walls) for a living, running errands and escaping police. He died at dawn and got up. Now he still crouches on walls and lamp posts, and drops onto whoever passes.

**Originality rules (important).**
- This is an original character in a pouncer role. It must not look like Left 4 Dead's Hunter or any other existing game character.
- Don't use a plain green or grey hoodie with grey shorts, taped forearms or bandaged hands.
- No real brands, logos or team crests. Print designs are generic and hand-made.

**Look (Mexican barrio, PS1).**
- Body: very skinny, long limbs, about 1.75 m standing. His natural pose is a deep crouch (about 1.0 m tall). Greyish-olive dead skin with darker veins on the forearms and neck. Long dirty nails.
- **Sudadera** (hoodie), oversized, hood up and pulled low over the eyes.
  - Colour: faded maroon/vino, sun-bleached on the shoulders.
  - Back: a cracked, hand-painted print of a generic rays-and-roses devotional motif. No face, no text.
  - Kangaroo pocket torn. Sleeves pushed up.
- **Paliacate** (bandana), black with white paisley, tied over nose and mouth. Torn on one side to show the jaw and teeth.
- **Pants:** baggy khaki work pants cut off below the knee, frayed. Long white socks pulled up, dirty.
- **Tenis:** worn white low-tops, generic, no logo, one lace missing.
- **Accessories:** a wooden-bead rosary around the neck, swinging. A cheap digital watch on one wrist.
- **Palette:** maroon, khaki, off-white, black, greyish skin, dried brown-red stains.

**Technical spec (match the game).**
- **Mesh:** 1,500–3,000 triangles total, one object.
  - Hood, paliacate and rosary are part of the same mesh (separate islands are fine).
  - No subdivision or modifiers left unapplied. No shape keys.
- **Texture:** one 256×256 PNG, albedo only, hand-painted look with baked fake shading. No normal or roughness maps.
  - Material: Principled BSDF with the texture on Base Color, roughness 1, metallic 0.
  - The game uses nearest filtering, so paint for it: no fine gradients that would band.
- **Units:** metres, scale applied (Ctrl+A), origin at the feet between the soles.
  - Character faces **-Y** in Blender (exports facing +Z in Godot, like the other characters).
- **Rig:** humanoid armature, **T-pose or A-pose rest pose**, one deform skeleton.
  - Bone names must match the Mixamo-style names in `resources/personajes/huesos_mixamo.tres` (read that file first): `mixamorig_` with an **underscore**, e.g. `mixamorig_Hips`, `mixamorig_Spine1`, `mixamorig_LeftArm`. Don't use the colon. The game retargets them onto `SkeletonProfileHumanoid` on import.
  - Include fingers (at least thumb plus one combined finger chain per hand) and `mixamorig_Head`.
  - No extra bones for the hood or rosary: weight them to `mixamorig_Head`/`mixamorig_Neck`/`mixamorig_Spine2`.
  - Clean weights: check elbows, knees and the deep crouch for collapsing.
- **Animations:** one Blender Action per clip, pushed to the NLA, 30 fps.
  - **All in place, no root motion.** The game moves the body, including the leap arc.
  - Names exactly as below.
  - The loop clips' first and last frames must match.

| Clip | Frames (30 fps) | Loop | What it shows | Timing the game needs |
|---|---|---|---|---|
| `Idle_Crouch` | 60 | yes | Squatting on haunches, knuckles on the ground, ragged breathing, small twitches | — |
| `Sniff_Scan` | 90 | yes | Same crouch, head tilting side to side, sniffing upward, a quick neck jerk | — |
| `Stalk_Walk` | 32 | yes | Low creeping walk, hands brushing the floor, ~1.2 m/s stride | — |
| `Run_AllFours` | 16 | yes | Gallop on hands and feet, very low, ~7 m/s stride | — |
| `Shriek` | 24 | no | Rears up, arms out, screams (jaw open through the torn paliacate), head shake. This is the player's warning | scream peak frame 10 |
| `Pounce_Windup` | 12 | no | Coils lower, shoulders forward, last frame held = launch pose | leaves the ground at frame 12 |
| `Pounce_Air` | 10 | yes | Flying: arms reaching forward with claws open, legs tucked then extending, hood flapping | — |
| `Pin_Maul` | 30 | yes | Straddling a body lying on the floor (the target's chest at ~0.25 m), alternating downward claw slashes | claws hit frames 8 and 23 |
| `Stagger` | 18 | no | Hit or shoved: recoils backward, recovers to the crouch | — |
| `Knocked_Off` | 30 | no | Thrown off the victim: tumbles back, rolls, lands crouched | back in crouch at frame 30 |
| `Perch_Idle` | 60 | yes | On top of a 2 m barda or a post: feet on the top edge, one hand gripping, body hunched forward looking down, slow sway | — |
| `Perch_Leap` | 14 | no | Launches down and forward from the perch (ends in the `Pounce_Air` pose) | leaves the edge at frame 9 |
| `Death` | 36 | no | Collapses sideways out of the crouch, curls up. Last frame held | on the floor at frame 26 |

**Export.**
- `File > Export > glTF 2.0 (.glb)` to `models/personajes/saltabardas/saltabardas.glb`.
- Settings: +Y up, apply modifiers, include all NLA actions as separate animations, no cameras or lights.
- Texture: `models/personajes/saltabardas/saltabardas.png`, packed in the glb or alongside it.
- Preview: render a front 3/4 view of `Idle_Crouch` at 512×384 to `models/personajes/saltabardas/preview.png`.
- Save the `.blend` beside it as `saltabardas.blend`, for future edits.

**Check before finishing.**
- Report the triangle count, bone count and the clip list with frame counts.
- Use `look` on: front, side, back (the print), deep crouch, mid-leap and the pin pose.
- Confirm no Valve-Hunter look: the hoodie is maroon with the print, and there's the paliacate, the cut-offs with white socks, and the rosary.
