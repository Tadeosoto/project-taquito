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

Los scripts leen la raiz del proyecto de la variable de entorno `TAQUITO_RAIZ` (si no esta, usan la ruta de Windows de Alan).

**Negocios.** `tiendas` del `.json` dice que negocio va y cerca de donde; `bloqueo.py` le da la casa libre mas cercana que mida entre `LOCAL_MIN` y `LOCAL_MAX` y cuyo frente de a una calle de verdad, la marca `local` (`colonia.py` no la arma: su fachada la pone `MapPuntos` en el juego, con la huella de la casa, sus alturas y los colores de su giro) y escribe el negocio en `negocios` (con `ajustado`). `puestos_calle` son los puestos de tacos y tejuino puestos a mano. Ambos salen en `resources/mapa/<colonia>/puntos.json`. Para volver a elegir las casas sin rehacer el resto del bloqueo: `REASIGNAR = True` antes de correr `bloqueo.py`.

**Arboles de Sketchfab.** `fetch_sketchfab.py arboles/arce arboles/realista arboles/roble` los baja, `extraer_arboles.gd` saca sus mallas y texturas a `resources/mapa/arboles_modelos.json` y `reducir_arboles.py` (en Blender, ruta absoluta) los baja de 12k/20k/7k caras a ~5.6k/7.2k/4k (corteza decimada, hojas con menos tarjetas y mas grandes). `exportar.py` escribe sus lugares en `resources/mapa/<colonia>/arboles_modelo.json` y `scripts/mapa/ArbolesModelo.gd` los dibuja con un MultiMesh por tipo (no van en el `.glb`). Si se vuelve a correr el extractor, hay que volver a correr el reductor.

**Arboles.** La pieza `ficus` usa los arboles de *Tacos_ Props*: `godot --headless --path . -s tools/blender/mapa/extraer_arbol_tacos.gd` escribe `modelos/arbol_tacos.json` y las dos texturas (hay que correrlo una vez, o si cambia el modelo).

**La Gotera** (`docs/mapa/colonias/la_gotera.md`): dos colonias, `la_gotera` (el tianguis lineal de la avenida) y `la_gotera_favela` (el laberinto). La favela la genera `favela.py` (Python puro, sin bpy) **después de `bloqueo.py` y antes de `colonia.py`**: `python3 tools/blender/mapa/favela.py la_gotera_favela`. Tira todo lo del bloqueo menos la muralla (la favela no respeta la traza de OSM) y siembra, con `"favela": true`, el laberinto de callejones, las casas de obra negra pegadas (juntas por `"grupo"` en una malla por bloque), patios, plazuelas, terrazas por bandas con escalinatas, tablones, escaleras, las bocas a las `reservas` y a las marcas `paso`, y los túneles (`tunel`, `tunel_cuarto`, hundidos con `abiertos` y su `bajada`). Opciones en `"favela"` del `.json` (`semilla`, `paso`, `callejon`, `theta`, `tuneles`) y `"callejones"` (`tendedero_cada`, `basura_cada`, `foco_cada`, `capilla_cada`, `bolsas`, `prendas`: la densidad de lo colgado y tirado). En esta PC todo corre con `~/gotera_work/run_colonia.py` (`COLONIA=la_gotera_favela PASOS=bloqueo,favela,colonia,exportar`).

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
  - `casa`: una huella con `pisos`, `color` (de `kit.PALETA`), `frente`, `desgaste`, `tienda`, `acabado` (`"ladrillo"` o `"block"`: obra negra sin enjarre con dalas y castillos; sin el, una de cada cinco `auto` de 2+ pisos sale de ladrillo), `obra` (`"castillos"`: el piso que falta, castillos con varilla sobre la azotea; `"losa"`: además media losa colada), `ventanal` (ventanal de herrería en la planta baja), `tapado` (0-1: ventanas de arriba con lona o tabla), `detalles` (false quita climas, rejas y lo de la azotea), `grupo` (las casas con el mismo grupo salen en una sola malla); fachada del atlas, pretil, azotea que se camina, tinaco y a veces un mural.
  - `tunel` (galería de ladrillo con bóveda bajo el piso: `largo` en x, `ancho`, `alto`, `huecos` [[x, ancho, lado]] en los muros, `cerrado` "a"/"b" tapa una punta; su `y` es el piso de la galería, −4.2) y `tunel_cuarto` (`tam`, `uso`: dormitorio, garrafones, armas, tienda, valvula; su puerta al frente +Z). Se entra por un `hundidos` con `"abiertos": [lado]` y una `bajada`. Los focos los escribe `exportar.py`.
  - Piezas armadas de `piezas.py`: `kiosco`, `parroquia`, `atrio`, `palacio`, `portal`, `ficus`, `banca`, `jardinera`, `fuente`, `puesto`, `cancha` (futbolito encajonado como el de la foto de AG: `tam` [ancho, largo] de las rayas, 11 × 18 por omision; muro azul de 2.2 m con murales, malla hasta 5 m con lonas, `entrada` `+x`/`-x`/`+z`/`-z` con reja, escalon para mirar y dos postes), `barda` (de block o lamina, con murales), `lote` (baldio con vida: `taller`, `juegos`, `fonda` o `baldio`), `carro` (`estado`: normal, ladrillos o quemado; `modelo`: vocho o combi; `colonia.carros_estacionados` pone solos los de las calles), `patio` (de atras, con tendederos), `escalera` (de fierro, choque en rampa), `espectacular` (anuncio de azotea por las dos caras: `anuncio`/`anuncio_atras` eligen la propaganda por nombre de archivo; con `y` va sobre una azotea), `antena_radio` (torre de tres patas roja y blanca con vientos), `base_gela` (reten de GelA de un carril: caseta, pipa, vallas, conos), `basamento` (losa con escalones al frente para subir un edificio), `plinto` (plataforma octagonal con escalones alrededor), `escalinata` (escalones de piedra a una terraza: la rampa llega justo a la altura en la orilla y sigue plana encima), `puente` (peatonal, con `escalera`s de cada lado: la rampa debe rebasar la orilla 0.1 m y quedar 0.15 m mas alta), `bajada` (zanja con escalones a un hundido), `tiendita` y `tortilleria` (negocios pegados a una fachada, frente a +Z; el letrero lo pone la marca `puerta`), `tablon`, `vecindad` (dos tiras de cuartos de dos pisos con patio largo, corredor, escalera, lavaderos y tendederos), los tapones de los bordes (`valla_gela`, `camion_volteado`, `escombro` y `nicho_virgen`, el altar de calle del borde `fieles`) y lo de la fortaleza: `muralla` (la barda subida a `alto` con lamina, tablones y tambos; `base`, `dentro` 1 o -1 segun de que lado queda adentro; lo chico va en `k.detalle`), `reja` (el porton de lamina con tranca; con `alto` < 3 sale la de barrotes, `reja_fierro`), `puesto_guardia` (caseta de los fieles con campana, frente a +Z) y `mirador_muro` (plataforma con escalera pegada a la muralla: origen en la cara de adentro, +Z hacia adentro, plataforma hacia +x y escalera hacia -x). `palacio` acepta `"uso": "escuela"`; `espectacular` y `puente` aceptan `anuncio` con el nombre de un mural (`virgen_sobre_gela`...).
- **Marcas.** No van al `.glb`; `scripts/mapa/Colonia.gd` las arma en Godot.
  - `spawn`: donde aparece el jugador.
  - `puerta`: la flecha amarilla de un negocio o casa. Su `giro` es la llave de `Interiores.escenas` y su +Z da a la calle. Sin interior dice "Próximamente".
  - `yonke`: el Yonke de Don Chava (`YonkeMapa`, con su barda), su +Z a la calle.
  - `reflector`: una luz de reflector a la altura `y`, viendo a su +Z e inclinada `baja` grados; se prende de noche (`Ciclo.valor()`). Los de la cancha van en sus postes.
  - `mision`: un punto con nombre para `MisionData.donde` y los pasos `RECOGER` ("marca:<nombre>").
  - `ninos`: chamacos jugando de dia (`NinosCancha`) en `tam` [ancho, largo], `cuantos`.
  - `vecino`: un civil parado (`clip`, `modelo`, `uniforme`: `gela` le pone chaleco y gorra azules y `fiel` chaleco verde y paliacate; `escala`; `garrafon`: uno azul a sus pies; `veladora`: una prendida enfrente; `cuando`: `dia` por omision, `noche` o `siempre`; `y` para subirlo a un mirador).
  - `campana`: suena sola (`de`: `templo`, al amanecer y con el aviso del atardecer; `escuela`, a media manana y a mediodia).
  - `palomas`: parvada que picotea en `tam` [ancho, largo] y sale volando si pasas corriendo (`cuantas`).
  - `perro`: un perro echado.
  - `procesion`: la procesion del atardecer; `puntos` [[x, z], ...] es su camino en metros del mundo (sale con el aviso de Ciclo).
  - `caja_gela`: la caja que da 1-2 cosas una vez por noche (`de`: `gela` u `ofrendas`).
  - `casa_vecino`: una casa que se camina (`escena`, `texto`, `abierto`: `siempre`, `dia` o `noche`, `cerrado`); las de los vecinos las pone `bloqueo.py`, la del templo va a mano.
  - `letrero`: un letrero de texto (`texto`) viendo a su +Z.
  - `trampa`: lugar iluminado que de noche atrae zombis si estas adentro (`tam`, `radio`).
  - `paso`: una flecha a otra escena (`PasoColonia`): `a` (otra colonia de Blender o `"mapa_grande"`), `lado` (el mismo nombre en las dos escenas), `llegada` [x, z] (donde apareces al volver por ella), `texto`, `requiere` (`"favela"`: solo con `Misiones.favela_abierta()`, si no `cerrado` sale en pantalla y el guardia te regresa). Las bocas de la favela de La Gotera. Las rejas de la muralla (`rejas`) pueden llevar `texto`, `libre` (no piden la guardia de Chuy), `tipo` (`reja_fierro`) y `alto`.
  - `botin`: tampoco se escribe a mano; `exportar.py` pone uno por ruta de azoteas y en `colonia.BOTIN_EXTRA` (`que`: `chatarra`, `bolsa` o `curacion`).
  - `placa`: tampoco a mano: `exportar.py` pone las placas de las calles que tengan nombre en `nombres_calles` (pieza -> nombre).
  - `foco`: no se escribe a mano; `exportar.py` agrega uno por cada foco colgado de los callejones (`colonia.focos_callejones`).
  - `tianguis`: tampoco a mano; `exportar.tianguis_marcas` pone una por tramo de `tianguis` (abajo).
- **Tianguis** (`tianguis`): tramos de calle con dos filas de carpas de lona que casi se tocan sobre el pasillo (`scripts/mapa/Tianguis.gd`, giros llenos con piezas del proyecto, gente cerca de la camara, de noche quedan los fierros y las mesas). Cada tramo: `nombre`, `a` y `b` (los extremos sobre el eje de la calle), `arroyo` (de banqueta a banqueta), `banqueta`, `pasillo` (libre entre los tubos de enfrente), `semilla` y `libres` [[x, z, ancho]] (huecos a mano: las calles que cruzan). Los huecos frente a las puertas (marcas `puerta`, `casa_vecino`, `casa_propia`, `yonke` y la entrada de cada negocio, `PUESTO_LIBRE` m a cada lado) salen solos. Un `puestos_calle` con `"bajo_carpa": true` queda dentro del tramo con una carpa vacia encima (el de tacos sin su toldo); va a unos 2.9 m del eje, con su frente al pasillo. En Blender se ve donde van las lonas en la coleccion `Vista`.
- **Terrazas** (`terrazas`): rectangulos (`puntos`, `alto`) o un `poligono` [[x, z]...] (las bandas de la favela) donde una manzana sube sobre su muro de contencion; lo que cae adentro sube solo al armar (no se escribe en el `.json`) y se llega con piezas `escalinata`.
- **Hundidos** (`hundidos`): donde el piso baja `fondo` m. La forma es un `poligono` [[x, z]...], el rectangulo de `puntos` [[x0, z0], [x1, z1]] o la huella de una `pieza`; `borde` > 0 hace la orilla en talud de esos metros (si no, vertical) y `bajar_piezas` baja lo que cae adentro (si no, lo de adentro lleva su `y` a mano, como la cancha). El piso del recorte es una malla triangulada con esos huecos y choque de malla. La pieza `bajada` hace una zanja con escalones para llegar.
- **Rutas** (`rutas`): tramos de frente de calle (`a`, `b`, `lado`, `fondo`) que `bloqueo.py` reserva y llena con una fila de casas de dos pisos con la azotea pareja y una `escalera` en la punta `a`: por ahi se escapa de los zombis de noche.
- **Bordes y muralla** (`bloqueo.py`): `sin_barda` [lados] no pone la muralla del recorte por ese lado (La Gotera la lleva a mano, sesgada); `muralla` {`alto`, `base`, `murales`} cambia la muralla (con `base` = `alto` es puro block); `nombres_parodia` {nombre real de OSM: nombre del juego} llena `nombres_calles` solo; las `calles` de una reja pueden ser el nombre real.
- **Postes** (`postes`, los pone `bloqueo.py`): uno cada 26 m por calle, turnando la banqueta, con el esquema de `resources/map/alumbrado_mapa.json`. `exportar.py` los escribe en `resources/mapa/<colonia>/alumbrado.json` y en Godot los arma `MapAlumbrado` (con su luz de noche); en Blender salen de vista en la coleccion `Vista`, que no se exporta, y los cables colgados de poste a poste si van al .glb.
- **Callejones:** calles de `empedrado` sin banqueta puestas a mano (con su reserva y un `patio`); `bloqueo.py` les pone casas que les dan el frente.
- **Murales:** `kit.murales()` junta en `textures/mapa/murales.png` los grafitis, la propaganda y las pintas de la Virgen de `textures/map/grafitis/`, `textures/map/propaganda/` y `textures/map/virgen/` (estas ultimas, tipo `virgen`, solo salen en el mapa de Blender; las dibuja `tools/map_import/make_murales_virgen.py`) (se agregan diseños poniendo imagenes ahi y corriendo `murales()` otra vez); las casas y las bardas los pintan.
- **Negocios.** Van tal cual a `puntos.json`, con el esquema de `MapPuntos` (ver `scripts/map/Safehouse.gd`). Los leen el minimapa, la gente, las misiones y Partida.

## Probar

`godot --path . scenes/mapa.tscn` para caminarla.

`godot --path . --headless -s tools/mapa/probar_colonia.gd` revisa sin ventana:
- que el jugador aparece en el `Spawn` y en el piso;
- que la primera puerta con interior mete a él, y que al salir te deja frente a ella;
- que está el yonke (si la colonia tiene su marca).
