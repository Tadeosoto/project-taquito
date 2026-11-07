# Pack de personajes PSX

79 personajes de [Characters_psx](https://sketchfab.com/3d-models/characters-psx-d940162487c3493b9e203d624fdd763a) de Elbolillo, licencia CC-BY 4.0 (crédito en `CREDITS.md`).

- Una carpeta por personaje: `<nombre>.fbx`, su textura (con el nombre original, porque el FBX la busca así), `preview.png` (frente y espalda) y `LICENSE_sketchfab.txt`.
- `hoja.png`: todos juntos para escoger rápido.
- Esqueleto de Mixamo (`mixamorig_*`), en pose T, sin animaciones propias (solo un clip `mixamo_com`): las animaciones de Mixamo les quedan directo.
- Los monstruos 0-3 (`monstruo_00`..`03`) son los zombis normales (`scripts/map/Zombie.gd`, `SKINS`), y traen el mismo retarget (`EXTRA` en `retarget_civiles.gd`). Usan los clips de zombi de Quaternius.
- Los civiles (`hombre_*`, `mujer_*`) traen el retarget a `SkeletonProfileHumanoid` en su `.import` (lo pone `godot --path . --headless -s tools/personajes/retarget_civiles.gd`, luego `--import`), como el_compa: usan las animaciones de Quaternius de `resources/personajes/animaciones_humanas.res`. Los pone `scripts/personajes/Civiles.gd` (los que atienden las tiendas y los que caminan).
- `mujer_01` viene sin textura en el pack original (sale blanca).
- Los previews se regeneran con `godot --path . -s tools/personajes/previews.gd` (necesita ventana) y luego `--import`.

| Carpeta | Archivo original | Grupo del pack |
|---|---|---|
| asesino_00 | Character_Killer | Killers |
| asesino_01 | Character_Killer_01 | Killers |
| asesino_02 | Character_Killer_02 | Killers |
| asesino_03 | Character_Killer_03 | Killers |
| asesino_04 | Character_Killer_04 | Killers |
| asesino_05 | Character_Killer_05 | Killers |
| asesino_06 | Character_Killer_06 | Killers |
| asesino_07 | Character_Killer_07 | Killers |
| bombera_21 | Character_21_Female_Firefighter | Female |
| bombera_22 | Character_22_Female_Firefighter | Female |
| bombero_23 | Character_23_Firefighter | Male |
| bombero_24 | Character_24_Firefighter | Male |
| doctor_25 | Character_25_Doctor | Male |
| doctor_26 | Character_26_Doctor | Male |
| doctora_23 | Character_23_Female_Doctor | Female |
| doctora_24 | Character_24_Female_Doctor | Female |
| hazmat_27 | Character_27_HM | Male |
| hazmat_28 | Character_28_HM | Male |
| hazmat_mujer_27 | Character_27_Female_HM | Female |
| hazmat_mujer_28 | Character_28_Female_HM | Female |
| hombre_01 | Character_01 | Male |
| hombre_02 | Character_02 | Male |
| hombre_03 | Character_03 | Male |
| hombre_04 | Character_04 | Male |
| hombre_05 | Character_05 | Male |
| hombre_06 | Character_06 | Male |
| hombre_07 | Character_07 | Male |
| hombre_08 | Character_08 | Male |
| hombre_09 | Character_09 | Male |
| hombre_10 | Character_10 | Male |
| hombre_11 | Character_11 | Male |
| hombre_12 | Character_12 | Male |
| hombre_13 | Character_13 | Male |
| hombre_14 | Character_14 | Male |
| hombre_15 | Character_15 | Male |
| hombre_16 | Character_16 | Male |
| hombre_29 | Character_29 | Male |
| hombre_30 | Character_30 | Male |
| hombre_31 | Character_31 | Male |
| hombre_32 | Character_32 | Male |
| monstruo_00 | Character_Monster | Killers |
| monstruo_01 | Character_Monster_01 | Killers |
| monstruo_02 | Character_Monster_02 | Killers |
| monstruo_03 | Character_Monster_03 | Killers |
| monstruo_04 | Character_Monster_04 | Killers |
| monstruo_05 | Character_Monster_05 | Killers |
| mujer_01 | Character_Female_01 | Female |
| mujer_02 | Character_Female_02 | Female |
| mujer_03 | Character_Female_03 | Female |
| mujer_04 | Character_Female_04 | Female |
| mujer_05 | Character_Female_05 | Female |
| mujer_06 | Character_Female_06 | Female |
| mujer_07 | Character_Female_07 | Female |
| mujer_08 | Character_Female_08 | Female |
| mujer_09 | Character_Female_09 | Female |
| mujer_10 | Character_Female_10 | Female |
| mujer_11 | Character_Female_11 | Female |
| mujer_12 | Character_Female_12 | Female |
| mujer_13 | Character_Female_13 | Female |
| mujer_14 | Character_Female_14 | Female |
| mujer_15 | Character_Female_15 | Female |
| mujer_16 | Character_Female_16 | Female |
| mujer_29 | Character_29_Female | Female |
| mujer_30 | Character_30_Female | Female |
| mujer_31 | Character_31_Female | Female |
| mujer_32 | Character_32_Female | Female |
| mujer_33 | Character_33_Female | Female |
| policia_17 | Character_17_Police | Male |
| policia_18 | Character_18_Police | Male |
| policia_19 | Character_19_Police | Male |
| policia_20 | Character_20_Police | Male |
| policia_21 | Character_21_Police | Male |
| policia_22 | Character_22_Police | Male |
| policia_mujer_17 | Character_17_Female_Police | Female |
| policia_mujer_18 | Character_18_Female_Police | Female |
| policia_mujer_19 | Character_19_Female_Police | Female |
| policia_mujer_20 | Character_20_Female_Police | Female |
| policia_mujer_25 | Character_25_Female_Police | Female |
| policia_mujer_26 | Character_26_Female_Police | Female |
