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

Antes la quinta entrega quitaba las hojas de la reja de la muralla. Ahora la muralla está abierta (el tianguis es de todos) y ese mismo requisito guarda las bocas de la favela. `FortalezasMapa` ya no escucha `Misiones.cambio`; `Misiones.favela_abierta()` se reusa tal cual. `docs/misiones.md` dice lo mismo. Prueba: `godot --path . --headless -s tools/mapa/probar_gotera.gd` (con `--favela` también la favela: llegadas por cada reja y boca, el guardia que regresa, el paso con cinco entregas, las rejas abiertas de `map_test` con su flecha).

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

- **Abierto las 24 horas y sin zombis** (JJ, 2026-11-13). El tianguis y la favela llevan `"abierto_24h": true` en su `.json`, que `exportar.py` copia a `marcas.json` y `MapaColonia.abierto_24h` lee al cargar. De noche los puestos siguen con su mercancía y su gente, y los focos del pasillo alumbran (una luz cada 9 m, solo de noche). Las tiendas no cierran ni bajan cortina, la gente de la banqueta se queda, no salen zombis sueltos ni el Saltabardas y no hay avisos de "Ya va a oscurecer" ni "Ya salieron". Las turbas que pide una misión sí salen. La bandera vuelve a false al salir de la escena, así que `map_test` y Santa Mugre siguen igual.

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
- Trazo: de cada boca una galería al oriente hasta una **espina** norte–sur; de la espina la **principal** al oriente con los cuartos alternando lados (dormitorio, garrafones, tienda "Fayuca del Túnel", armas, tienda "Balas y Veladoras", dormitorio, válvula) y la boca final tapada. Las dos tiendas llevan marca `puerta` con su giro propio (`favela.TIENDAS_TUNEL`) y su interior de cuarto de ladrillo con foco:
  - **Fayuca del Túnel** (`fayuca_tunel`, `scenes/interiores/tunel_fayuca.tscn`): cigarros, bocina, cinta, botiquín, Vaporub, caguama, alcohol y plata, a 0.85 del precio.
  - **Balas y Veladoras** (`armas_tunel`, `scenes/interiores/tunel_armas.tscn`): machete, bate, sal, trapo, gasolina y alcohol (lo del molotov), a 1.15 del precio, con un altarcito de veladoras. Balas no hay todavía: el objeto no existe (`docs/items.md`).
  Los precios son primera propuesta. Las dos están también en el safehouse.

## Decisiones de la noche (sin JJ)

- **Dos escenas, no una:** el tianguis es una franja (x 700–768) y la favela otra colonia que empieza en x 730; se traslapan 38 m para que las bocas queden en las dos. Barato y reversible: si se quiere una sola escena, se junta en un `.json`.
- **La muralla poniente del tianguis va a mano** (piezas `muralla` sesgadas por `FortalezasMapa.GOTERA`) y `bloqueo.py` no pone la del recorte por ese lado (`"sin_barda"`). Entre la muralla y la orilla del recorte queda una franja de piso de hasta 20 m que solo se ve desde arriba.
- **Muralla de puro block de 3.6 m** (`"muralla": {"base": 3.6}`) en vez de la de lámina y tambos de los fieles: la ficha pedía "barda alta de block con alambre".
- **Rejas de La Gotera de fierro de 3.2 m** (`reja_fierro`), `libre` (no piden la guardia de Chuy).
- **Guardias y vigías con los civiles `hombre_*`:** los `asesino_*` del pack PSX no están retargeteados (sin animación).
- **La favela ignora la traza de OSM** (JJ a media noche): `favela.py` tira calles, casas, lotes, tapones y postes del bloqueo y deja solo la muralla.
- **Casas de la favela sin detalles de azotea** (`detalles: false`) y los adornos de los callejones espaciados (`"callejones"` del `.json`: tendederos cada 13–22 m, focos cada 16–24 m, capillitas cada 13, basura desde 12 m): con 650 casas y 600 callejones el `.glb` se iba a 52 MB; así queda en 24 MiB, bajo el límite de 25 MB.
- **La favela es cerrada y con niebla** (JJ, 2026-11-13). Su `.json` lleva `"ambiente"`, que `exportar.py` copia a `marcas.json` y `MapaColonia._ambiente` aplica al cargar:
  - `niebla` 0.045 en vez de 0.0196: el 5 % se ve a unos 67 m en lugar de 150 m.
  - `lejos` 85 m: la cámara del jugador no dibuja más allá, porque la niebla ya lo tapa. El dron no cambia.
  - `gente`: hasta 16 caminantes que salen entre 12 y 38 m del jugador y se quitan a 50 m. El suelo cuenta como camino hasta 2 m de alto, por las terrazas de 0.75 y 1.5 m, y el rayo baja desde 4 m, abajo de los tablones. Antes solo caminaban por la franja de abajo.
- **Escaleras de fierro solo donde caben a lo largo de la fachada** (unos 6.6 m con su rampa): con fachadas más cortas se salían de la esquina y tapaban el callejón de al lado. Hoy queda una. Si dos callejones llegan al mismo borde de banda, ponen una sola escalinata.
- **Las casas van juntas por bloques de 6×6 celdas** (`"grupo"` → una malla por bloque, `colonia._juntar_grupos`) para que el `.glb` y la importación pesen menos.
- **Nombres parodia** (`"nombres_parodia"`, real → juego): Av. del Cedro Seco, Calle Primavera Marchita, Calle Nogal Hueco, Calle Roble Torcido, Av. Parota Sin Sombra, Calle Caobilla Apolillada, Privada Roble Quebrado, Privada del Chorro, Privada de la Fuga, Calle Sin Número, Calle Tres Cuartos, Privada del Gotero, Calle Monte Caramelo, Privada Monte Caramelo, Calle Ébano Quemado, Calle Seis Cerrada. En la favela ya no hay placas (no hay calles).
- **El LSD de las tiendas (M7c) no se tocó**, como se pidió.

## Qué falta / pide decisión de JJ

- Nombre definitivo de la Av. del Cedro Seco y de las bocas; si la favela debe tener placas de sus callejones.
- Los dadores de la mafia dentro de la favela (Nemesio, el Primo, el gremio) son marcas `mision` sin misión todavía (M8/M9 y S7, el mercado ilegal).
- Interior de la tienda ilegal de La Gotera (hoy es un segundo `punto`).
- Si las balas de la pistola se venden en "Balas y Veladoras": falta el objeto.
- Zombi de cobalto en "zonas con obra negra": la casa ya existe en el kit.

## Probar sin restricciones

`scenes/prueba_gotera.tscn` entra directo al tianguis con las bocas abiertas, sin las entregas de la mafia (`PasoColonia.sin_candados`, que dura hasta volver a la pantalla de inicio). Se puede ir y venir por cualquier boca y salir a `map_test` por las rejas.

```bash
godot --path . scenes/prueba_gotera.tscn               # en el tianguis, de día
godot --path . scenes/prueba_gotera.tscn -- --favela   # en la favela
godot --path . scenes/prueba_gotera.tscn -- --noche    # de noche
```

## Rendimiento y capturas

Las capturas están en `~/casa_psm/gotera/` con su lista en `00_resumen.md` (fuera del repo). Números de `godot --path . -s tools/mapa/medir_gotera.gd -- --colonia=<colonia>` (mediana del tiempo de GPU, Intel HD 520, 640×480). El presupuesto es no pasar de ~5 ms sobre el tianguis de Santa Mugre.

| Lugar | GPU día | GPU noche | Llamadas día |
|---|---|---|---|
| Santa Mugre, tianguis a lo largo (referencia) | 10.1 ms | 8.3 ms | 786 |
| Santa Mugre, tianguis de lado (referencia) | 10.7 ms | 9.3 ms | 905 |
| La Gotera, tianguis de armas | 8.4 ms | 7.3 ms | 324 |
| La Gotera, tramo del agua | 12.9 ms | 8.5 ms | 933 |
| La Gotera, tramo de comida | 10.5 ms | 8.3 ms | 1321 |
| Favela, boca | 7.0 ms | 8.4 ms | 519 |
| Favela, callejón | 6.9 ms | 8.5 ms | 703 |
| Favela, plaza | 6.8 ms | 7.8 ms | 613 |
| Favela, fondo | 7.8 ms | 8.9 ms | 690 |
| Favela, túnel | 5.2 ms | 5.4 ms | 444 |

Lo más caro es el tramo del agua del tianguis, 2.2 ms sobre Santa Mugre. La favela se midió con el modelo final, su niebla, la cámara a 85 m y 16 caminantes (2026-11-13). Con la niebla de la escena y la cámara sin límite de noche llegaba a 10.1 ms. Pruebas: `tools/mapa/probar_gotera.gd -- --favela` y `tools/mapa/recorrer_favela.gd -- --cuantos=120` (120 callejones sin atorarse, escalinatas, bajada al túnel, focos de noche).
