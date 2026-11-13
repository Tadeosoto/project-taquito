# La Gotera (fortaleza de la mafia) — ficha y lo que quedó hecho

💡 Borrador (JJ, 2026-11-12) → ✅ **primera versión en Blender (Claude, noche del 2026-11-13, rama `gotera-blender`)**. Bloque **F4** de `docs/plan-noche.md`. La historia de los Gotera está en `docs/lore.md` §11; la zona del contenido, en [`../zona-enfoque.md`](../zona-enfoque.md). Lo que se decidió sin JJ está en "Decisiones de la noche", abajo.

## Dónde

- **Cambia el canon:** La Gotera ya **no** está "al sureste, detrás de la autopista". Está en **Haciendas de San José** (Haciendas de San Jodido en el juego), pegada a la orilla oriente del mapa. Falta pasarlo a `lore.md` (§11, §13 y la tabla de las tres fortalezas), a `especificaciones.md` y a `ZonasMapa.gd`.
- **La barda va por las calles** (JJ, 2026-11-12), para no partir casas, siempre por el lado de la banqueta, a 5.5 m del eje de la calle:
  - **poniente:** por la banqueta poniente de la **Av. del Cedro**: la avenida queda adentro y las casas del otro lado, afuera, viendo a la barda;
  - **norte:** por la banqueta sur de la calle **Primavera**;
  - **sur:** por la banqueta norte de la calle **Nogal**;
  - **oriente:** la orilla del mapa.
  Mide unos 195 m de ancho (de x ≈ 705–723 a 914) y 230 m de fondo (de z ≈ −341 a −96). Los vértices están en `FortalezasMapa.GOTERA`.
- **La única entrada es la Av. del Cedro:** **reja norte** en la esquina con Primavera (728, −341) y **reja sur** en la esquina con Nogal (710, −114), las dos de 11 m. Son ~228 m de avenida entre las dos.

## Cómo está armada (dos escenas de Blender)

Como Santa Mugre: muralla en `map_test` → reja con flecha amarilla → escena de Blender. `scenes/mapa.tscn` ya sirve para cualquier colonia (`MapaColonia.gd` apunta los datos a `resources/mapa/<colonia>/` según `PasoColonia.colonia` o `--colonia=`).

1. **`la_gotera`, el tianguis lineal** (`tools/blender/mapa/colonias/la_gotera.json`, recorte x 700–768, z −343–−110): solo la avenida y la primera hilera de casas de cada lado. **Abierto para cualquiera**, de día y de noche: las dos rejas de la muralla en `map_test` están **abiertas** (hojas giradas contra el muro, `FortalezasMapa`) y su flecha "Entrar a La Gotera" te mete por ese lado; adentro, la flecha "Salir de La Gotera" de cada reja (`salida_colonia` con `libre`: no pide la guardia de Chuy) te saca. La muralla poniente va a mano, sesgada por la banqueta de la avenida (`FortalezasMapa.GOTERA`), con un **mirador con vigía** junto a cada reja; la del norte, sur y oriente las pone `bloqueo.py` (`"muralla": alto 3.6, puro block, sin lámina).
2. **`la_gotera_favela`** (`la_gotera_favela.json`, recorte x 730–914, z −336–−104): **otra escena**. Se entra por las **cinco bocas** del lado oriente del tianguis (las calles reales que salían de la avenida: Privada de la Fuga, Privada Roble Quebrado, Av. Parota Sin Sombra, Calle Caobilla Apolillada y Calle Sin Número), cada una con su guardia, su letrero "Solo gente de la casa", un reflector y la flecha "Entrar a la favela". **No te dejan pasar si no has hecho las misiones de la mafia:** la marca `paso` lleva `"requiere": "favela"` y `Colonia.gd` consulta `Misiones.favela_abierta()` (la misma función de M7a: cinco entregas); sin permiso el guardia te regresa un paso y sale el aviso. Al salir de la favela apareces en la boca por la que entraste (`lado` de la marca, el mismo en las dos escenas, y su `llegada`).

### Cambio de lógica respecto a M7a

Antes la quinta entrega quitaba las hojas de la reja de la muralla. Ahora la muralla está abierta (el tianguis es de todos) y ese mismo requisito guarda las bocas de la favela. `FortalezasMapa` ya no escucha `Misiones.cambio`; `Misiones.favela_abierta()` se reusa tal cual. `docs/misiones.md` dice lo mismo. Prueba: `godot --path . --headless -s tools/mapa/probar_gotera.gd` (18/18: llegadas por cada reja y boca, el guardia que regresa, el paso con cinco entregas, las rejas abiertas de `map_test` con su flecha).

## El tianguis

- `scripts/mapa/Tianguis.gd` y las carpas de `tools/blender/tianguis/carpas.py`, con `pasillo` 1.8 m y pocos `libres` (solo las calles que cruzan y las bocas).
- **Seis tramos por giro, cada uno con su color de lona** (`"giros"` y `"lona"` del tramo, nuevos en `Tianguis.gd`), de la reja norte a la sur:

  | Tramo | Giro | Lona | Qué hay |
  |---|---|---|---|
  | Tianguis_Armas | `armas` | negra | machetes, bates, resorteras, balas, una Colt; El Punto de La Gotera (la **tienda ilegal**, giro `punto`) a media cuadra |
  | Tianguis_Agua | `agua` | azul | garrafones y botellas; el local **Agua del Yacimiento** (`purificadora`) |
  | Tianguis_Fayuca | `fayuca` | amarilla | bocinas, cintas, cigarros, patitos, llaves, monedas; **Fayuca El Pirata** |
  | Tianguis_Farmacia | `farmacia` | blanca | Vaporub, botiquines, tachas, cigarros; **Farmacia Sin Receta** |
  | Tianguis_Ropa | `ropa` | rosa | ropa y tenis piratas; **Vinos y Licores La Última Gota** |
  | Tianguis_Comida | `tacos`, `tejuino`, `fruta` | roja | fritangas; **Tacos El Gotero** |

- De noche el tianguis sigue abierto en el lore (§14); en el juego quedan los fierros y las mesas como en Santa Mugre (los marchantes de noche son S7, pendiente).

## La favela

- **Un solo laberinto en toda la zona** (JJ, 2026-11-13): la favela **no respeta la traza de OSM**, no deja huecos y se siente angosta. `tools/blender/mapa/favela.py` (Python puro, después de `bloqueo.py`; `~/gotera_work/run_colonia.py` lo corre en orden) lo genera determinista por semilla: cuadrícula de 7 m girada como las calles de Haciendas, DFS desde la boca del poniente más lazos, **callejones de 1.2 a 2.2 m** en tramos rectos que se quiebran, cada celda una **casa de obra negra pegada a la de al lado** (block o ladrillo sin enjarre, castillos con varilla, media losa, ventanales de herrería, lonas y tablas en las ventanas; una de cada ocho pintada de un color), casas dobles, **patios** con tendederos y **plazuelas** con puesto de lona, **tablones** entre azoteas, **escaleras** a las azoteas, tendederos, cables, focos y basura en los callejones (`colonia.py`, con la densidad bajada en `"callejones"`).
- **Terrazas por distancia a la avenida:** tres bandas (a nivel hasta 55 m, +0.75 m hasta 115 m, +1.5 m el fondo) con una **escalinata** donde un callejón cruza de banda.
- **Lugares clave** (marcas `mision` para los dadores):

  | Lugar | Dónde | Marca |
  |---|---|---|
  | Plaza de los Gotera | Corazón de la favela (806, −222): cancha de futbolito encajonada, puestos, bancas, chamacos de día, reflectores de noche y dos de la casa parados | `Nemesio_Plaza` |
  | Casa de don Nemesio | Fondo, junto a la orilla (898, −246): la única con enjarre y pintura (mostaza, dos pisos) | `Nemesio_Casa` |
  | Bodega del agua | (760, −300): local `purificadora` "Bodega del Agua"; abajo, el cuarto de garrafones del túnel | `Bodega_Agua` |
  | Bocas de los túneles | Tres patios de la banda a nivel, con su zanja y escalones | `Tunel_Entrada_0..2` |
  | La válvula | En el túnel, cuarto `valvula`: el pozo con la rueda, tras un barandal | `Valvula` |
  | Boca final | El fin de la galería principal, tapada con block, "A los cárcamos. No pasar" | `Boca_Tuneles` |

## Túneles

- **Geometría aparte en la misma escena, bajo el piso** (no un hundido abierto): piezas `tunel` (galería de ladrillo con bóveda, piso de tierra, tubería y focos) y `tunel_cuarto` (dormitorio, garrafones, armas, tienda con mostrador y lona, válvula) a `y = −4.2`. Se baja por un `hundidos` con `"abiertos": [lado]` (nuevo: esa orilla no se tapa) y una `bajada` de 5 m a 40°. Por qué así: el piso del recorte sigue siendo una sola malla triangulada con tres huecos chicos (nada que rompa el piso ni la física), y lo de abajo son cajas y quads baratos que `MapaPostImport` junta por cuadro; un hundido abierto habría sido una zanja a cielo abierto, no un túnel.
- Trazo: de cada boca una galería al oriente hasta una **espina** norte–sur; de la espina la **principal** al oriente con los cuartos alternando lados (dormitorio, garrafones, tienda "Fayuca del Túnel", armas, tienda "Balas y Veladoras", dormitorio, válvula) y la boca final tapada. Las tiendas llevan marca `puerta` (giro `tiendita`, "Próximamente" hasta que tengan interior).

## Decisiones de la noche (sin JJ)

- **Dos escenas, no una:** el tianguis es una franja (x 700–768) y la favela otra colonia que empieza en x 730; se traslapan 38 m para que las bocas queden en las dos. Barato y reversible: si se quiere una sola escena, se junta en un `.json`.
- **La muralla poniente del tianguis va a mano** (piezas `muralla` sesgadas por `FortalezasMapa.GOTERA`) y `bloqueo.py` no pone la del recorte por ese lado (`"sin_barda"`). Entre la muralla y la orilla del recorte queda una franja de piso de hasta 20 m que solo se ve desde arriba.
- **Muralla de puro block de 3.6 m** (`"muralla": {"base": 3.6}`) en vez de la de lámina y tambos de los fieles: la ficha pedía "barda alta de block con alambre".
- **Rejas de La Gotera de fierro de 3.2 m** (`reja_fierro`), `libre` (no piden la guardia de Chuy).
- **Guardias y vigías con los civiles `hombre_*`:** los `asesino_*` del pack PSX no están retargeteados (sin animación).
- **La favela ignora la traza de OSM** (JJ a media noche): `favela.py` tira calles, casas, lotes, tapones y postes del bloqueo y deja solo la muralla.
- **Casas de la favela sin detalles de azotea** (`detalles: false`) y tendederos cada 9–15 m: con 600 casas y 550 callejones el `.glb` se iba a 40 MB.
- **Las casas van juntas por bloques de 6×6 celdas** (`"grupo"` → una malla por bloque, `colonia._juntar_grupos`) para que el `.glb` y la importación pesen menos.
- **Nombres parodia** (`"nombres_parodia"`, real → juego): Av. del Cedro Seco, Calle Primavera Marchita, Calle Nogal Hueco, Calle Roble Torcido, Av. Parota Sin Sombra, Calle Caobilla Apolillada, Privada Roble Quebrado, Privada del Chorro, Privada de la Fuga, Calle Sin Número, Calle Tres Cuartos, Privada del Gotero, Calle Monte Caramelo, Privada Monte Caramelo, Calle Ébano Quemado, Calle Seis Cerrada. En la favela ya no hay placas (no hay calles).
- **El LSD de las tiendas (M7c) no se tocó**, como se pidió.

## Qué falta / pide decisión de JJ

- Nombre definitivo de la Av. del Cedro Seco y de las bocas; si la favela debe tener placas de sus callejones.
- Los dadores de la mafia dentro de la favela (Nemesio, el Primo, el gremio) son marcas `mision` sin misión todavía (M8/M9 y S7, el mercado ilegal).
- Interiores de las tiendas del túnel y de la tienda ilegal de La Gotera (hoy es un segundo `punto`).
- Si los Gotera dejan entrar al tianguis de noche con zombis o sin ellos (`Zombis.espontaneos` es false en `mapa.tscn`: dentro no hay).
- Zombi de cobalto en "zonas con obra negra": la casa ya existe en el kit.

## Rendimiento y capturas

Ver `~/casa_psm/gotera/00_resumen.md` (la lista de capturas) y la sección de números al final de este archivo cuando se midió.
