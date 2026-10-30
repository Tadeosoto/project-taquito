# Guadalajaja

Prototipo 3D en tercera persona con look de PS1, hecho en **Godot 4.7** (Forward+, física Jolt) y GDScript.

Hay tres escenas principales:

| Escena | Qué es |
|---|---|
| `scenes/world.tscn` | La escena principal del juego (la que abre `godot --path .`): jugador, NPCs con diálogo, objetos e inventario. |
| `scenes/safehouse.tscn` | **Dev safehouse:** un patio para probar todo sin caminar el mapa: un negocio de cada giro, maquinitas en cada estado, todos los objetos, zombis y el día y la noche. Las teclas de prueba salen en pantalla. |
| `scenes/map_test.tscn` | **Nuevo:** un pedazo real de Zapopan (~1.7 × 1.7 km) con casas, calles, tiendas, farmacias y puestos, para recorrer a pie o volando. |

La idea es que, con el tiempo, las mecánicas de `world.tscn` (NPCs, inventario, objetos) se pasen al mapa real.

Las mecánicas, objetos, misiones y decisiones pendientes del juego están en **[`docs/especificaciones.md`](docs/especificaciones.md)**.

## Cómo correrlo

```bash
godot --path . --editor                    # abrir el editor
godot --path .                             # jugar la escena principal (world.tscn)
godot --path . scenes/map_test.tscn        # recorrer el mapa real
godot --path . scenes/safehouse.tscn       # probar todo en el dev safehouse
```

La primera vez, abre el proyecto en el editor (o corre `godot --path . --headless --import`) para que Godot importe los modelos.

### Controles

| Acción | Teclado |
|---|---|
| Moverse | WASD / flechas |
| Cámara | Mouse (en `map_test.tscn` también Q / E) |
| Correr | Shift |
| Saltar / hablar con NPC / recoger | Espacio |
| Atacar (de noche salen zombis) | Clic izquierdo o F |

En `map_test.tscn` además:

| Acción | Teclado |
|---|---|
| Cambiar entre **dron** y jugador | V |
| Dron: moverse (15 m/s, a 30 m de altura) | WASD / flechas |
| Dron: girar | Mouse o Q / E |
| Dron: ir al triple de rápido | Shift |
| Saltar al siguiente atardecer o amanecer | N |
| Abrir / cerrar inventario | Tab |
| Inventario: cambiar de objeto | ← / → o Q / E |
| Inventario: elegir comando (Examinar, Utilizar, Combinar) | ↑ / ↓ |
| Inventario: confirmar / regresar | Enter / Esc |
| Recoger objeto o mochila (más mochila = más espacio) | Espacio |
| Maquinita de frutas (afuera de algunas tienditas): jugar | Espacio |
| Maquinita: cambiar de fruta / apostar o quitar $1 | ← → o Q / E / ↑ ↓ |
| Maquinita: tirar / salir | Espacio / S o Esc |
| Examinar: girar / acercar | Flechas / Rueda o RePág / AvPág |

La escena arranca a pie. Al presionar V para dejar el dron, el jugador aterriza justo debajo (en la calle o en una azotea).

## El mapa real (`scenes/map_test.tscn`)

Un pedazo real de Zapopan (~1.7 × 1.7 km) hecho con OpenStreetMap, Google Open Buildings y el DENUE del INEGI. Tiene casas modelo por colonia, negocios reales, señales de alto, minimapa estilo GTA y modo dron.

![El mapa a pie, enfrente de una farmacia](docs/mapa/pie.png)

Todo lo del mapa (qué tiene, cómo corregirlo y cómo regenerarlo) está en **[`docs/mapa/README.md`](docs/mapa/README.md)**.

`models/zona_mapa.glb` no está en GitHub **a propósito**: el juego no lo usa, carga los cuadros de `resources/map/cuadros/`, que sí están. Para jugar el mapa no hay que generar nada. Solo quien cambie el mapa necesita regenerarlo; ver [¿Por qué `zona_mapa.glb` no está en GitHub?](docs/mapa/README.md#por-qué-modelszona_mapaglb-no-está-en-github).

## Estructura

```
scenes/         escenas (.tscn)
scripts/        GDScript del juego
scripts/map/    mapa real: post-import, streaming, tiendas, casas modelo, dron, minimapa
shaders/        shaders PS1 (ps1_combined, ps1_facade, ps1_casa, ps1_suelo, ps1_arbol, ps1_pasto, minimapa y ps1_vertex.gdshaderinc, compartido)
models/         modelos 3D; tiendas/, casas/, props/ y objetos/ = modelos de Sketchfab
resources/      items del inventario (.tres); resources/map/ = mapa generado
data/map/       datos de entrada del mapa (OSM, Google, DENUE, correcciones a mano)
textures/map/   texturas de fachadas, azoteas, suelo, pasto, asfalto, banquetas, árboles y minimapa
tools/map_import/  scripts para generar el mapa
docs/mapa/      README y capturas del mapa
```

## Pendientes conocidos

- El inventario solo está en `map_test.tscn`, no en `world.tscn`.
- Mapa: ver [`docs/mapa/README.md`](docs/mapa/README.md#pendientes).

## Créditos

Ver [`CREDITS.md`](CREDITS.md): OpenStreetMap (ODbL), Google Open Buildings (CC BY 4.0), INEGI DENUE, OSM2World (MIT), Poly Haven (CC0) y los autores de los modelos de Sketchfab (CC BY).
