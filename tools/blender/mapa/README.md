# tools/blender/mapa: el mapa hecho en Blender, colonia por colonia

Scripts de Python que se corren dentro de Blender 5.2 (con el MCP de Blender o desde el editor de
texto de Blender). La ficha de diseño de cada colonia está en `docs/mapa/colonias/`; el detalle
técnico, en `docs/mapa/tecnico.md` ("Mapa en Blender").

**La fuente de cada colonia es su `.json`** (`colonias/<colonia>.json`), no el `.blend`: la escena
se tira y se rehace desde el `.json` cuando sea. Lo que se mueve a mano en Blender regresa al
`.json` con `leer()` (y `exportar.py` lo hace solo antes de exportar).

Todo va en metros del juego, en el mismo marco que `resources/map/minimapa.json`: cada colonia
se queda en su lugar real, así que el minimapa, el mapa de papel y las zonas no cambian. Los
giros van en radianes, como en Godot. Godot (x, y, z) = Blender (x, -z, y).

## En orden

Cada script se corre con `exec`, diciéndole la colonia:

```python
R = r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender\mapa"
exec(open(R + r"\colonia.py", encoding="utf-8").read(), {"__name__": "colonia", "COLONIA": "santa_mugre"})
```

1. `colonia.py`: arma la escena `Colonia_<colonia>` desde el `.json`:
   - `Mundo`: el piso del recorte y las piezas, cada una con su caja de choque `-colonly`. Es lo único que se exporta.
   - `Marcas`: un vacío con flecha por marca. La flecha apunta al frente (+Z de Godot).
2. `bloqueo.py` (una vez por colonia, o para rehacer lo automático; después, otra vez `colonia.py` para verlo): siembra en el `.json` el bloqueo gris desde lo real: las calles de OSM, los parques y plazas, las huellas de Google como edificios de 1 a 3 pisos, la barda alrededor y un tapón donde sale cada calle (`bordes`). Lo que pone lleva `"auto": true` y es lo único que rehace; lo puesto a mano (los lugares de la ficha) se queda. Las `reservas` del `.json` son áreas donde no pone edificios reales.
3. `referencia.py`: agrega la colección `Referencia` con lo que cae en el recorte:
   - las calles de OSM (ejes amarillos y franjas de su ancho);
   - las huellas de Google Open Buildings (rojo).
   Es solo de guía para bloquear; nunca se exporta.
4. `exportar.py`: primero `leer()`, luego escribe:
   - `models/mapa/<colonia>/<colonia>.glb`;
   - `models/mapa/<colonia>/fuente/<colonia>.blend`;
   - `resources/mapa/<colonia>/marcas.json`;
   - `resources/mapa/<colonia>/puntos.json`.
   Después, en Godot: `godot --path . --headless --import`.

`comun.py` tiene lo compartido: conversión de coordenadas, cajas, cajas de choque, vacíos, materiales y el guardado del `.json`.

## El `.json` de una colonia

```json
{
	"nombre": "santa_mugre",
	"recorte": [x1, z1, x2, z2],
	"piezas": [{"nombre": "CasaPrueba", "tipo": "caja", "x": -262, "z": 444, "rot": 0, "tam": [8, 4, 10], "color": [0.6, 0.6, 0.6]}],
	"marcas": [
		{"nombre": "Spawn", "tipo": "spawn", "x": -262, "z": 455, "rot": 0},
		{"nombre": "Puerta_oxxo_0", "tipo": "puerta", "giro": "oxxo", "texto": "OXO", "x": -262, "z": 449.8, "rot": 0}
	],
	"negocios": []
}
```

- **Piezas.** Todas con `nombre`, `tipo`, `x`, `z`, `rot` y opcionales `color`, `y` (altura de la base) y `auto`. El frente de una pieza es su +Z (en Blender, -Y).
  - `caja`: `tam` es ancho (x), alto (y) y fondo (z). Con choque.
  - `cilindro`: `radio` y `alto`. Con choque.
  - `edificio`: `puntos` (la huella, relativa a x/z) y `alto`. Con choque.
  - `suelo`: `puntos`, una mancha plana (pasto, baldío). Sin choque.
  - `calle`: `puntos` (el eje), `ancho` y `banqueta`. Pintada sobre el piso, sin choque.
  - `casa`: una huella con `pisos`, `color` (de `kit.PALETA`), `frente`, `desgaste`, `tienda`, `acabado` (`"ladrillo"`: obra negra con dalas y castillos; sin el, una de cada cinco `auto` de 2+ pisos sale de ladrillo), `detalles` (false quita climas, rejas y lo de la azotea); fachada del atlas, pretil, azotea que se camina, tinaco y a veces un mural.
  - Piezas armadas de `piezas.py`: `kiosco`, `parroquia`, `atrio`, `palacio`, `portal`, `ficus`, `banca`, `jardinera`, `fuente`, `puesto`, `cancha` (futbolito encajonado como el de la foto de AG: `tam` [ancho, largo] de las rayas, 11 × 18 por omision; muro azul de 2.2 m con murales, malla hasta 5 m con lonas, `entrada` `+x`/`-x`/`+z`/`-z` con reja, escalon para mirar y dos postes), `barda` (de block o lamina, con murales), `lote` (baldio con vida: `taller`, `juegos`, `fonda` o `baldio`), `carro`, `patio` (de atras, con tendederos), `escalera` (de fierro, choque en rampa), `espectacular` (anuncio de azotea por las dos caras: `anuncio`/`anuncio_atras` eligen la propaganda por nombre de archivo; con `y` va sobre una azotea), `antena_radio` (torre de tres patas roja y blanca con vientos), `base_gela` (reten de GelA de un carril: caseta, pipa, vallas, conos), `tablon`, `vecindad` (dos tiras de cuartos de dos pisos con patio largo, corredor, escalera, lavaderos y tendederos) y los tapones de los bordes: `valla_gela`, `camion_volteado` y `escombro`.
- **Marcas.** No van al `.glb`; `scripts/mapa/Colonia.gd` las arma en Godot.
  - `spawn`: donde aparece el jugador.
  - `puerta`: la flecha amarilla de un negocio o casa. Su `giro` es la llave de `Interiores.escenas` y su +Z da a la calle. Sin interior dice "Próximamente".
  - `yonke`: el Yonke de Don Chava (`YonkeMapa`, con su barda), su +Z a la calle.
  - `reflector`: una luz de reflector a la altura `y`, viendo a su +Z e inclinada `baja` grados; se prende de noche (`Ciclo.valor()`). Los de la cancha van en sus postes.
  - `foco`: no se escribe a mano; `exportar.py` agrega uno por cada foco colgado de los callejones (`colonia.focos_callejones`).
- **Rutas** (`rutas`): tramos de frente de calle (`a`, `b`, `lado`, `fondo`) que `bloqueo.py` reserva y llena con una fila de casas de dos pisos con la azotea pareja y una `escalera` en la punta `a`: por ahi se escapa de los zombis de noche.
- **Postes** (`postes`, los pone `bloqueo.py`): uno cada 26 m por calle, turnando la banqueta, con el esquema de `resources/map/alumbrado_mapa.json`. `exportar.py` los escribe en `resources/mapa/<colonia>/alumbrado.json` y en Godot los arma `MapAlumbrado` (con su luz de noche); en Blender salen de vista en la coleccion `Vista`, que no se exporta, y los cables colgados de poste a poste si van al .glb.
- **Callejones:** calles de `empedrado` sin banqueta puestas a mano (con su reserva y un `patio`); `bloqueo.py` les pone casas que les dan el frente.
- **Murales:** `kit.murales()` junta en `textures/mapa/murales.png` los grafitis y la propaganda de `textures/map/grafitis/` y `textures/map/propaganda/` (se agregan diseños poniendo imagenes ahi y corriendo `murales()` otra vez); las casas y las bardas los pintan.
- **Negocios.** Van tal cual a `puntos.json`, con el esquema de `MapPuntos` (ver `scripts/map/Safehouse.gd`). Los leen el minimapa, la gente, las misiones y Partida.

## Probar

`godot --path . scenes/mapa.tscn` para caminarla.

`godot --path . --headless -s tools/mapa/probar_colonia.gd` revisa sin ventana:
- que el jugador aparece en el `Spawn` y en el piso;
- que la primera puerta con interior mete a él, y que al salir te deja frente a ella;
- que está el yonke (si la colonia tiene su marca).
