# Guadalajaja

Prototipo 3D en tercera persona con look de PS1, hecho en **Godot 4.7** (Forward+, física Jolt) y GDScript.

Hay dos escenas principales:

| Escena | Qué es |
|---|---|
| `scenes/world.tscn` | La escena principal del juego (la que abre `godot --path .`): jugador, NPCs con diálogo, objetos e inventario. |
| `scenes/map_test.tscn` | **Nuevo:** un pedazo real de Zapopan (~1.7 × 1.7 km) con casas, calles, tiendas, farmacias y puestos, para recorrer a pie o volando. |

La idea es que, con el tiempo, las mecánicas de `world.tscn` (NPCs, inventario, objetos) se pasen al mapa real.

## Cómo correrlo

```bash
godot --path . --editor                    # abrir el editor
godot --path .                             # jugar la escena principal (world.tscn)
godot --path . scenes/map_test.tscn        # recorrer el mapa real
```

La primera vez, abre el proyecto en el editor (o corre `godot --path . --headless --import`) para que Godot importe los modelos.

### Controles

| Acción | Teclado |
|---|---|
| Moverse | WASD / flechas |
| Cámara | Mouse |
| Correr | Shift |
| Saltar / hablar con NPC | Espacio |
| Inventario: anterior / siguiente | Q / E |
| Inventario: inspeccionar / regresar | Enter / Esc |

En `map_test.tscn` además:

| Acción | Teclado |
|---|---|
| Cambiar entre **dron** y jugador | V |
| Dron: moverse (15 m/s, a 30 m de altura) | WASD / flechas |
| Dron: girar | Mouse o Q / E |
| Dron: ir al triple de rápido | Shift |

La escena arranca en modo dron. Al presionar V el jugador aterriza justo debajo del dron (en la calle o en una azotea).

## El mapa real (`scenes/map_test.tscn`)

La zona va de **20.606286, −103.423463** a **20.590700, −103.406515** (Zapopan, Jalisco).

<!-- TODO: agregar una captura del mapa desde el dron -->

- **Casas y calles**: ~7,900 edificios.
  - La geometría sale de [OpenStreetMap](https://www.openstreetmap.org), convertida a 3D con [OSM2World](https://osm2world.org).
  - OSM solo tiene ~970 casas en la zona; el resto viene de [Google Open Buildings](https://sites.research.google/open-buildings/) (huellas detectadas por satélite).
  - Las casas sin datos salen de 1–2 pisos, con techo plano y un color de fachada.
- **Fachadas mexicanas**: un shader pinta en cada tramo de pared ventanas con herrería, puertas, cortinas metálicas y zaguanes, del color de cada casa. Las azoteas salen con impermeabilizante rojo o losa gris. Las texturas salen de `tools/map_import/make_textures.py`: con `--estilo fotos` (el actual) usa fotos CC0 de [Poly Haven](https://polyhaven.com) para aplanado, puertas, cortinas y azoteas; con `--estilo dibujado` todo es dibujo propio. El suelo de tierra y las banquetas también son fotos de Poly Haven.
- **Negocios reales**: 85 negocios del [DENUE del INEGI](https://www.inegi.org.mx/app/descarga/?ti=6) (tiendas, taquerías, OXXO, farmacias, tortillerías, puestos y una gasolinera).
  - De varios negocios del mismo giro muy juntos, solo se deja uno: a menos de 80 m, o 150 m en tiendas de abarrotes.
  - Cada tienda ocupa el lote de una casa y mira hacia la calle.
  - Los OXXO, tiendas, farmacias, puestos, puestos de tacos y la gasolinera usan modelos low-poly de Sketchfab (CC BY), con sus proporciones originales y un tamaño fijo por giro (pueden encimarse en las casas de al lado).
  - Las taquerías y tortillerías son locales armados en código: cortina abierta, mostrador, letrero con su nombre y, en taquerías, lona.
- **Carga por partes (streaming)**: el mapa está partido en cuadros de 128 m y solo se cargan los cercanos al jugador (o al dron), en segundo plano. Lo mismo con las tiendas. Hay unos 40 de 201 cuadros en memoria a la vez.

No se usan imágenes ni datos de Google Maps o Street View: sus términos lo prohíben. Street View solo sirve como referencia visual para corregir cosas a mano.

### Corregir o agregar cosas a mano

| Archivo | Para qué |
|---|---|
| `data/map/overrides.json` | Cambiar etiquetas de una casa de OSM, por ejemplo pisos o color: `"way/<id>": {"building:levels": "3"}`. |
| `data/map/puntos.json` | Agregar tiendas o puestos con `{tipo, nombre, lat, lon}`, o quitar negocios mal ubicados con `"omitir"` (usa el `origen` que sale en `resources/map/puntos_mapa.json`). |
| `scenes/map_test.tscn` → nodo `Puntos` | Elegir qué modelo usa cada tipo de negocio (`prefabs`), cómo girarlo (`prefab_rotacion`) y cuántos metros de frente tiene (`prefab_ancho`). |
| `scenes/map_test.tscn` → nodo `Dron` | Altura, velocidad e inclinación del dron. |

Después de editar `overrides.json` o `puntos.json` hay que regenerar el mapa (ver abajo).

### Regenerar el mapa

Se necesitan Java, Python 3 e ImageMagick (`magick`). El repo **no** incluye `models/zona_mapa.glb` (47 MB) ni OSM2World: se generan con estos pasos.

```bash
bash tools/map_import/fetch_osm.sh                          # baja OSM de la zona (opcional: ya viene en data/map/)
python3 -I tools/map_import/fetch_google_buildings.py       # casas de Google Open Buildings (opcional: ya viene)
python3 -I tools/map_import/fetch_denue.py                  # negocios del DENUE (opcional: ya viene)
bash tools/map_import/build_glb.sh                          # baja OSM2World y genera models/zona_mapa.glb
rm -f .godot/imported/zona_mapa.glb-* && godot --path . --headless --import
godot --path . --headless -s tools/map_import/split_cuadros.gd   # parte el mapa en resources/map/cuadros/
```

Los modelos de tiendas ya vienen en `models/tiendas/`. Para volver a bajarlos se necesita un token de Sketchfab:

```bash
SKETCHFAB_TOKEN=xxxx python3 -I tools/map_import/fetch_sketchfab.py
```

`CLAUDE.md` tiene los detalles técnicos del pipeline y sus trampas, por ejemplo por qué Godot no reimporta solo.

## Estructura

```
scenes/         escenas (.tscn)
scripts/        GDScript del juego
scripts/map/    mapa real: post-import, streaming, tiendas, dron
shaders/        shaders PS1 (ps1_combined, ps1_facade, ps1_suelo y ps1_vertex.gdshaderinc, compartido)
models/         modelos 3D; models/tiendas/ = modelos de Sketchfab
resources/      items del inventario (.tres); resources/map/ = mapa generado
data/map/       datos de entrada del mapa (OSM, Google, DENUE, correcciones a mano)
textures/map/   texturas de fachadas, azoteas, suelo y banquetas
tools/map_import/  scripts para generar el mapa
```

## Pendientes conocidos

- `InventoryUI.tscn` todavía no está en `world.tscn`, y el jugador solo interactúa con NPCs (no con `WorldItem`).
- Mapa:
  - Pasar las mecánicas de `world.tscn` al mapa real.
  - Todos los puestos (frutas, ropa, llantera...) usan el mismo carrito de comida.
  - Las 33 tiendas usan el mismo modelo.
  - Hay un pequeño tirón cuando se carga un cuadro.

## Créditos

Ver [`CREDITS.md`](CREDITS.md): OpenStreetMap (ODbL), Google Open Buildings (CC BY 4.0), INEGI DENUE, OSM2World (MIT) y los autores de los modelos de Sketchfab (CC BY).
