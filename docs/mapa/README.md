# El mapa real de Zapopan

`scenes/map_test.tscn` es un pedazo real de Zapopan, Jalisco, de ~1.7 × 1.7 km, para recorrerlo a pie o en dron con el look PS1 del juego. Va de **20.606286, −103.423463** a **20.590700, −103.406515** y cubre colonias como Parques de Santa María, Haciendas de San José, Parques del Bosque, Agua Blanca, El Mante y La Palmira.

| A pie | En dron |
|---|---|
| ![A pie, enfrente de la farmacia](pie.png) | ![Desde el dron](dron.png) |

La escala es real: 1 unidad de Godot = 1 metro, y el personaje mide 1.74 m.

## Cómo correrlo

```bash
godot --path . scenes/map_test.tscn
```

La primera vez hay que abrir el proyecto en el editor o correr `godot --path . --headless --import` para que Godot importe los modelos. En el editor, `map_test.tscn` sale sin mapa: los cuadros se cargan solo al correr la escena.

### Controles

| Acción | A pie | En dron |
|---|---|---|
| Moverse | WASD / flechas | WASD / flechas (15 m/s, a 30 m de altura) |
| Girar la cámara | Mouse o Q / E | Mouse o Q / E |
| Correr | Shift (10 m/s, 18 m/s corriendo) | Shift (×3) |
| Saltar | Espacio | — |
| Cambiar entre jugador y dron | V | V |

Se arranca a pie, enfrente de una Farmacia Guadalajara con un puesto. Al pasar del dron al jugador, el jugador aterriza justo debajo del dron, en la calle o en una azotea.

## Qué hay en el mapa

- **Calles y edificios**:
  - La geometría sale de [OpenStreetMap](https://www.openstreetmap.org), convertida a 3D con [OSM2World](https://osm2world.org).
  - OSM solo tiene ~970 casas en la zona; el resto sale de [Google Open Buildings](https://sites.research.google/open-buildings/), huellas detectadas por satélite. En total son ~7,900 edificios.
  - Los que no tienen datos salen de 1–2 pisos, con azotea plana y un color de fachada.
- **Casas modelo por colonia**:
  - Unas 10,300 casas se cambian por modelos de Sketchfab:
    - Parques del Bosque: Casa Semi Residencial y Mexican House 3.
    - Todas las demás colonias: Casa Urbi/Infonavit de 1 y 2 pisos, y Semi Residencial en algunas de 2 pisos.
    - Agua Blanca Industrial se queda como está, porque ahí son bodegas.
  - La colonia de cada manzana sale de los negocios del DENUE que hay en ella. Así una manzana nunca mezcla dos colonias.
  - Las hileras de casas se parten en lotes de 6.5 m, y las fachadas de una cuadra quedan alineadas aunque sean modelos distintos.
  - Cada casa pinta su muro de un color al azar y deja puertas, ventanas y herrería como vienen.
- **Fachadas**: las casas que no son modelo usan un shader que pinta en cada tramo ventanas con herrería, puertas, cortinas metálicas y zaguanes. Las azoteas son de impermeabilizante rojo o losa gris. Las texturas son fotos CC0 de [Poly Haven](https://polyhaven.com) más dibujo propio. El suelo de tierra y las banquetas también salen de Poly Haven.
- **Negocios reales**: 85 negocios del [DENUE del INEGI](https://www.inegi.org.mx/app/descarga/?ti=6): tiendas, taquerías, OXXO, farmacias, tortillerías, puestos y una gasolinera.
  - Si hay varios del mismo giro muy juntos, se deja solo uno (80 m; 150 m en tiendas de abarrotes).
  - Cada tienda ocupa el lote de una casa y mira hacia la calle.
  - OXXO, tiendas, farmacias, puestos y gasolinera usan modelos low-poly de Sketchfab (CC BY).
  - Taquerías y tortillerías son locales armados en código, con cortina, mostrador, letrero y lona.
- **Señales de alto** en 1 de cada 20 esquinas, del lado derecho y de cara al tráfico.
- **Minimapa estilo GTA** en la esquina superior derecha:
  - Gira con la cámara y marca al jugador con una flecha, el norte con una N y cada negocio con un cuadrito de color.
  - Colores: rojo OXXO, amarillo tienda, naranja tacos, beige tortillería, turquesa farmacia, verde gasolinera, rosa puesto.
  - En dron se aleja para ver más.
- **Carga por partes**: el mapa está partido en 201 cuadros de 128 m. Solo se cargan los cercanos (~40), en segundo plano. Las tiendas y las casas modelo se cargan igual, por celdas.

<p align="center"><img src="minimapa.png" width="420" alt="Imagen completa del minimapa"></p>

En la laptop de desarrollo (Intel Iris Plus 640) corre a ~150–190 FPS a pie y ~140–160 en dron, sin vsync.

No se usan imágenes ni datos de Google Maps o Street View, porque sus términos lo prohíben. Street View solo sirve como referencia visual para corregir cosas a mano.

## Cómo está hecho

```
data/map/area.osm  ─┐
google_buildings   ─┼─▶ prepare_osm.py ─▶ area_prepared.osm ─▶ OSM2World ─▶ models/zona_mapa.glb
denue_*.json       ─┤        │                                                   │ MapPostImport.gd (materiales PS1, colisiones, cuadros)
casas.json, ...    ─┘        │                                                   ▼
                             │                                   split_cuadros.gd ─▶ resources/map/cuadros/*.scn
                             ├─▶ resources/map/puntos_mapa.json   (tiendas y altos)
                             ├─▶ resources/map/casas_mapa.json    (lotes de casas modelo)
                             └─▶ make_minimapa.py ─▶ textures/map/minimapa.png
```

Al correr la escena, cada nodo carga lo suyo alrededor del dron, que cuando no está volando va pegado al jugador:

| Nodo en `map_test.tscn` | Script | Qué hace |
|---|---|---|
| `Mapa` | `scripts/map/MapStreamer.gd` | Carga y descarga los cuadros de `resources/map/cuadros/`. |
| `Puntos` | `scripts/map/MapPuntos.gd` | Pone los negocios y altos con su modelo (`prefabs`), o arma los locales. |
| `Casas` | `scripts/map/MapCasas.gd` | Dibuja las casas modelo con un MultiMesh por celda y les pone colisión. |
| `Dron` | `scripts/map/MapDron.gd` | Modo dron (tecla V). |
| `Minimapa` | `scripts/map/MapMinimapa.gd` | El radar de la esquina. |

Shaders del mapa:
- `ps1_facade`: fachadas de OSM2World.
- `ps1_casa`: casas modelo, con color de muro por casa.
- `ps1_suelo`: tierra y banquetas.
- `minimapa`: el radar.

Todos comparten el vértice PS1 de `ps1_vertex.gdshaderinc` (menos el radar, que es 2D).

## Corregir o agregar cosas a mano

| Archivo | Para qué |
|---|---|
| `data/map/overrides.json` | Cambiar etiquetas de un edificio de OSM, por ejemplo pisos o color: `"way/<id>": {"building:levels": "3"}`. |
| `data/map/casas.json` | Qué modelos de casa van en cada colonia, por número de pisos y con un peso. `"*"` son las demás colonias; `_proporcion` dice qué fracción de casas se cambia. |
| `data/map/colonias.json` | Corregir la colonia de una manzana: `"lat,lon de un punto de la manzana": "COLONIA"`. |
| `data/map/puntos.json` | Agregar tiendas o puestos con `{tipo, nombre, lat, lon}`, o quitar negocios mal ubicados con `"omitir"` (usa el `origen` de `resources/map/puntos_mapa.json`). |
| `scenes/map_test.tscn` → `Puntos` | Qué modelo usa cada giro (`prefabs`), cómo girarlo (`prefab_rotacion`) y cuántos metros de frente tiene (`prefab_ancho`). |
| `scenes/map_test.tscn` → `Casas` | Modelos de casa, escala, color de muro (`muro_key`) y distancias de carga. |
| `scenes/map_test.tscn` → `Minimapa` | Tamaño del radar (`tamano`) y cuánto se ve a pie y en dron (`radio_metros`, `radio_dron`). |
| `scenes/map_test.tscn` → `Dron` / `Player` | Altura y velocidad del dron, si se arranca en dron (`iniciar_en_dron`), y spawn y velocidad del jugador. |

Después de editar `overrides.json`, `puntos.json`, `casas.json` o `colonias.json` hay que regenerar el mapa.

## Regenerar el mapa

Se necesitan Java, Python 3 e ImageMagick (`magick`). El repo **no** incluye `models/zona_mapa.glb` (~10 MB, se genera) ni OSM2World (~450 MB, se baja solo). Lo que el juego carga, los cuadros, las texturas y los JSON de `resources/map/`, sí viene en el repo, así que solo hay que regenerar si cambias datos.

```bash
bash tools/map_import/fetch_osm.sh                         # OSM de la zona (opcional: ya viene en data/map/)
python3 -I tools/map_import/fetch_google_buildings.py      # casas de Google Open Buildings (opcional: ya viene)
python3 -I tools/map_import/fetch_denue.py                 # negocios y colonias del DENUE (opcional: ya viene)
bash tools/map_import/build_glb.sh                         # prepara el .osm, corre OSM2World y hace el minimapa (~30 s)
rm -f .godot/imported/zona_mapa.glb-* && godot --path . --headless --import
godot --path . --headless -s tools/map_import/split_cuadros.gd   # parte el mapa en resources/map/cuadros/
```

`build_glb.sh` también deja `data/map/colonias_debug.png`, con las manzanas pintadas por colonia, para revisar a ojo cómo quedaron las colonias.

Los modelos de Sketchfab ya vienen en `models/`. Para volver a bajarlos se necesita un token de Sketchfab, que nunca se guarda en el repo:

```bash
SKETCHFAB_TOKEN=xxxx python3 -I tools/map_import/fetch_sketchfab.py
```

`CLAUDE.md` tiene los detalles técnicos del pipeline y sus trampas, por ejemplo por qué Godot no reimporta el .glb solo.

## Pendientes

- Pasar las mecánicas de `world.tscn` (NPCs, inventario, objetos) al mapa real.
- Torres de departamentos: el modelo "Edificio multifamiliar" ya está bajado, pero falta ubicar las torres.
- Todos los puestos usan el mismo carrito de comida y las 33 tiendas el mismo modelo.
- Hay un tirón pequeño cuando se carga un cuadro.
- Una manzana central de Parques de Santa María sale enorme, porque un arroyo la deja sin calles que la corten.
- Takis, la moneda de 1 peso y los Jarritos están importados en `models/objetos/` pero todavía no se usan.

## Licencias

Datos de OpenStreetMap (ODbL), Google Open Buildings (CC BY 4.0) e INEGI DENUE; OSM2World (MIT), texturas de Poly Haven (CC0) y modelos de Sketchfab (CC BY). Los autores de cada modelo están en [`CREDITS.md`](../../CREDITS.md).
