# tools/blender: La Mojiganga y su plaza, hechas por script

Scripts de Python que se corren dentro de Blender 5.2 (con el MCP de Blender:
`exec(open(r"<ruta>", encoding="utf-8").read())`, o desde el editor de texto de Blender). Cada uno
rehace su parte desde cero en la escena "Catrina" (o "Plaza"). Las fotos de Poly Haven se bajan a
`cache/` (no se versiona; los creditos estan en `CREDITS.md`).

En orden:

1. `catrina_malla.py`: la disposicion, las zonas de color, la joroba (`doblar`) y las funciones que
   usan los demas. Solo, arma la version v2 (la que reemplaza `catrina_baja.py`).
2. `catrina_alta.py`: la version de alta resolucion (~200k triangulos, coleccion `Catrina_Alta`):
   craneo agrietado, resplandor, tela colgada del armazon, cola, rebozo, huesos, nudo. Solo para
   hornear; nunca va al juego.
3. `catrina_tela.py`: simula el rebozo y la cola (tela de Blender, 60 cuadros, ~5 s) y deja
   `Rebozo_Alta`, `Cola_Alta` y sus copias rotas; desde aqui `catrina_alta.py` ya no dibuja los
   suyos. Hay que volver a correr `armar_alta(["vestido"])` despues.
4. `catrina_baja.py`: la malla del juego (~7.2k triangulos a la vez), los seis objetos que busca
   `scripts/catrina/Catrina.gd`.
5. `catrina_textura.py`: UV, la pintura de la alta (fotos + calavera deslavada, lagrimas, agua
   sucia, mugre) y el horneado a `catrina.png` (2048) y `catrina_emision.png`. Por pasos:
   `uv()`, `pintar()`, `material_juego()`, `hornear(nombre)`, `guardar()`, o `todo()`.
6. `catrina_rig.py`: el esqueleto (nombres de Mixamo, trenza, cola, marcadores) y los pesos.
7. `catrina_clips.py`: las 20 animaciones de la tabla de `docs/prompts/blender_catrina.md`.
8. `catrina_exportar.py`: `catrina.glb`, `preview.png` y `fuente/catrina.blend`.
9. `catrina_props.py`: `femur.glb`, `corona.glb`, `craneo_caido.glb`, `pompon.glb`.
10. `plaza.py`: la plaza (`models/escenarios/plaza_catrina/plaza_catrina.glb`) con sus colisiones
   `-colonly`.

Si se rehace la malla del juego (paso 4) hay que repetir 5 a 8: los UV, el horneado y los pesos
son de esa malla. Despues, en Godot: `--import` y `scenes/catrina.tscn -- --medir=40`.
