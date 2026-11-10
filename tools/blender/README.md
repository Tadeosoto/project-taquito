# tools/blender: La Mojiganga y su plaza, hechas por script

Scripts de Python que se corren dentro de Blender 5.2 (con el MCP de Blender:
`exec(open(r"<ruta>", encoding="utf-8").read())`, o desde el editor de texto de Blender). Cada uno
rehace su parte desde cero en la escena "Catrina" (o "Plaza"). Las fotos de Poly Haven se bajan a
`cache/` (no se versiona; los creditos estan en `CREDITS.md`). Si `cache/` desaparece pero Blender
sigue abierto con las imagenes cargadas, se pueden volver a guardar desde ahi (`image.save()`).

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
   La paleta es de funeral podrido (`PINTURA`, manchas en `_manchas`). Para solo cambiar colores:
   `solo_pintura()` (repinta y rehornea sin desenvolver otra vez; despues el paso 8). Los objetos
   con `hide_render` (Vestido_Roto, Carrizo, Nudo) hay que prenderlos para hornear.
6. `catrina_rig.py`: el esqueleto (nombres de Mixamo, trenza, cola, marcadores) y los pesos. Las
   puntas de las flamas de la corona son huesos `Vela_0..7` (de `catrina_baja.puntas_velas()`); si
   cambia el resplandor de `craneo_bajo`, cambiar tambien `puntas_velas`.
7. `catrina_clips.py`: las 20 animaciones de la tabla de `docs/prompts/blender_catrina.md`,
   muestreadas cuadro por cuadro: curva por tramo (`_c`), retraso por cadena (`RETRASO`) y capas
   (`CAPAS`: respirar, temblar, el tic). No cambia la malla: basta repetir el paso 8.
8. `catrina_exportar.py`: `catrina.glb`, `preview.png` y `fuente/catrina.blend`.
9. `catrina_props.py`: `femur.glb`, `corona.glb`, `craneo_caido.glb`, `pompon.glb`.
10. `plaza.py`: la plaza (`models/escenarios/plaza_catrina/plaza_catrina.glb`) con sus colisiones
   `-colonly`. Cada carro y ofrenda es su objeto (`Carro_0`...) con su copia aplastada
   (`Carro_0_Roto`) para `scripts/catrina/Rompible.gd`. Tambien seis braseros (`Brasero_i`, con su colision
   y su vacio `Brasero_i_Fuego`) y vacios en las puntas de las velas de las ofrendas
   (`Ofrenda_i_Vela_k`), donde Godot pone el fuego de pixelfx.

Si se rehace la malla del juego (paso 4) hay que repetir 5 a 8: los UV, el horneado y los pesos
son de esa malla. Despues, en Godot: `--import` y `scenes/catrina.tscn -- --medir=40`.
