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

- `scripts/mapa/Tianguis.gd` y las carpas de `tools/blender/tianguis/carpas.py`. Ahora el tianguis lineal se genera **igual que el de Santa Mugre**: `pasillo` 2.6 m y **todos los giros y colores** en cada tramo (sin `giros`/`lona` por tramo), con los `libres` de las calles que cruzan y las bocas.
- **Seis tramos por giro, cada uno con su color de lona** (`"giros"` y `"lona"` del tramo, nuevos en `Tianguis.gd`), de la reja norte a la sur:

  | Tramo | Giro | Lona | Qué hay |
  |---|---|---|---|
  | Tianguis_Armas | general | — | Ya no es un tramo de un solo giro: usa los puestos variados de Santa Mugre. El Punto de La Gotera (la **tienda ilegal**, giro `punto`) sigue a media cuadra |
  | Tianguis_Agua | `agua` | azul | garrafones y botellas; el local **Agua del Yacimiento** (`purificadora`) |
  | Tianguis_Fayuca | `fayuca` | amarilla | bocinas, cintas, cigarros, patitos, llaves, monedas; **Fayuca El Pirata** |
  | Tianguis_Farmacia | `farmacia` | blanca | Vaporub, botiquines, tachas, cigarros; **Farmacia Sin Receta** |
  | Tianguis_Ropa | `ropa` | rosa | ropa y tenis piratas; **Vinos y Licores La Última Gota** |
  | Tianguis_Comida | `tacos`, `tejuino`, `fruta` | roja | fritangas; **Tacos El Gotero** |

- **Abierto las 24 horas y sin zombis** (JJ, 2026-11-13). El tianguis y la favela llevan `"abierto_24h": true` en su `.json`, que `exportar.py` copia a `marcas.json` y `MapaColonia.abierto_24h` lee al cargar. De noche los puestos siguen con su mercancía y su gente, y los focos del pasillo alumbran (una luz cada 9 m, solo de noche). Las tiendas no cierran ni bajan cortina, la gente de la banqueta se queda, no salen zombis sueltos ni el Saltabardas y no hay avisos de "Ya va a oscurecer" ni "Ya salieron". Las turbas que pide una misión sí salen. La bandera vuelve a false al salir de la escena, así que `map_test` y Santa Mugre siguen igual.

## La favela

- **Un solo laberinto en toda la zona** (JJ, 2026-11-13): la favela **no respeta la traza de OSM**, no deja huecos y se siente angosta. `tools/blender/mapa/favela.py` (Python puro, después de `bloqueo.py`; `~/gotera_work/run_colonia.py` lo corre en orden) lo genera determinista por semilla: cuadrícula de 7 m girada como las calles de Haciendas, DFS desde la boca del poniente más lazos, **callejones de 1.2 a 2.2 m** en tramos rectos que se quiebran, cada celda una **casa de obra negra pegada a la de al lado** (block o ladrillo sin enjarre, castillos con varilla, media losa, ventanales de herrería, lonas y tablas en las ventanas; una de cada ocho pintada de un color), casas dobles, **patios** con tendederos y **plazuelas** con puesto de lona, **tablones y puentes** entre azoteas, **escaleras** a las azoteas, **toldos de lona** sobre los callejones, tendederos, cables, focos y basura. Desde la tarde del 2026-11-13 es el **perfil detallado** (detalles de azotea y adornos de callejón por omisión); el `.glb` pesa ~56 MB y se sube en Git normal (GitHub avisa a partir de 50 MiB pero lo acepta; el tope duro son 100 MiB).
- **Favela plana:** todo el terreno al nivel del piso (sin terrazas, escalinatas ni rampas). Por ahora no hay escaleras a las azoteas ni bajada a túneles.
- **Lugares clave** (marcas `mision` para los dadores):

  | Lugar | Dónde | Marca |
  |---|---|---|
  | Plaza de los Gotera | Corazón de la favela (806, −222): cancha de futbolito encajonada, puestos, bancas, chamacos de día, reflectores de noche y dos de la casa parados | `Nemesio_Plaza` |
  | Casa de don Nemesio | Fondo, junto a la orilla (898, −246): la única con enjarre y pintura (mostaza, dos pisos) | `Nemesio_Casa` |
  | Plaza del Tinaco | El claro 3×3 más cercano al centro del recorte (~843, −218): tinaco comunitario de **50,000 L**, sin la Virgen, sin ofrenda y sin defensa; el mayor de los cuatro claros grandes | `Tinaco_Favela` |
  | Cuarto de garrafones | En el túnel, el cuarto `garrafones` (ya no es la Bodega del Agua) | `Garrafones_Tunel` |
  | Bocas de los túneles | Tres patios de la banda a nivel, con su zanja y escalones | `Tunel_Entrada_0..2` |
  | La válvula | En el túnel, cuarto `valvula`: el pozo con la rueda, tras un barandal | `Valvula` |
  | Boca final | El fin de la galería principal, tapada con block, "A los cárcamos. No pasar" | `Boca_Tuneles` |

## Cuevas, casas abandonadas y callejones techados (JJ, 2026-11-13)

**Por ahora sin la red subterránea ni escaleras a las azoteas** (`favela.SUBTERRANEO = False`, `ESCALERAS_AZOTEA = 0`; el código de los túneles sigue en `favela._tuneles_mini` y `piezas.tunel*` por si vuelve). Lo de abajo de "Túneles" es historia de esa red. En su lugar, cosas que se cruzan por dentro a nivel de piso (`favela._abandonadas`, cantidades en `ABANDONADAS`; por ahora pocas y cerca del spawn):

- **Casas abandonadas** (pieza `abandonada`, `piezas.abandonada`): misma huella y pisos que la casa que sustituyen, muros de obra negra, **marcos de puerta abiertos** de 1.5 m (`puertas`: lado, posición, ancho), piso de tierra, **sin muebles ni gente**. Un foco colgado (marca `foco` con `"siempre": true`, prende también de día, y `"parpadea"` al azar).
- **Casas pasantes**: una casa sencilla con marco en dos lados que dan a callejones distintos: un atajo.
- **Cuevas (pasadizos)**: `PASADIZO_CASAS` (6) casas pegadas, sencillas o dobles, que dan vueltas por dentro de la manzana; se pasa de una a otra por un marco en el muro compartido (solo donde los dos muros están pegados de verdad, sin rendija) y la primera y la última salen a callejones. Sus focos fallan más (`PASADIZO_PARPADEA`). **Las dos tiendas del túnel** (Fayuca del Túnel y Balas y Veladoras, con su flecha e interior propio) van en casas de en medio de la primera cueva, en un muro sin puerta y viendo hacia adentro; el letrero se baja a 2.35 m (`letrero_alto` en la marca `puerta`) para no quedar en la losa.
- **Callejones techados** (pieza `techo_callejon`): losa de fachada a fachada y un marco en cada boca, en tramos de una sola arista con casa de los dos lados; se quedan `TECHADO_ESQUINA` (1.3 m) antes de cada esquina para no tapar las vueltas. Se quitan los toldos de encima.
- **La cámara adentro**: lo de arriba de la planta baja va en un objeto aparte `Techo_<nombre>` (`MapaPostImport` no lo funde) y sus choques se llaman `<nombre>_techo<i>`. Cada pieza deja una marca `interior` (rectángulo y techos de su grupo; una cueva es un grupo). Con el jugador adentro, `Colonia._camara_interior` acorta el brazo a 1.8 m (`INTERIOR_BRAZO`, `Player.brazo_interior`) y lleva el ángulo a −12° (`INTERIOR_PITCH`), y el resorte **sí choca con la losa y los muros**: la cámara se queda bajo el techo, a la altura de los ojos (JJ, 2026-11-13: antes se veía desde arriba como casa de muñecas, a −52° y con los techos escondidos). Al salir el ángulo regresa al de antes.

- **Ajustes (JJ, 2026-11-13, noche)**: `ABANDONADAS` sube a 8 pasantes, 5 pasadizos y 8 techados, **repartidos por todo el mapa** (orden al azar y `CUEVAS_SEPARACION` 28 m, ya no pegados al spawn); cada marca `interior` lleva su `clase` y, la primera de cada cueva, su `ruta` (boca, casas, boca); el minimapa y el mapa de papel la dibujan **punteada, como un callejón más** (`minimapa_colonia._punteada`). Pasantes y pasadizos solo se ponen donde unen callejones que por la red quedan lejos (`CUEVAS_DIST_MIN` 6 tramos para pasadizos, `PASANTE_DIST_MIN` 2 para una casa sola) y cada uno cuenta como atajo para el siguiente. **Sin tablones ni puentes** (`TABLONES = False`) y las casas de la favela salen `limpio` (sin panel solar ni tendedero de azotea). Los **tendederos** de los callejones solo cuelgan si hay casa de dos pisos a los dos lados (`colonia._paredes_favela`). **Balcones y segundos pisos volados** en ~22 % de las casas de dos pisos (`favela._balcones`, `kit._balcones_casa`; sin choque, van sobre la cabeza). **Altares** (capillitas blancas de techo azul): solo 8 en toda la favela (`CAPILLAS_FAVELA`), a 40 m entre sí y siempre con casa pegada a su espalda.

- **Texturas de fotos en las casas (JJ, 2026-11-13)**: el atlas `fachadas_kit` pasa a **6 filas** (fila 5 nueva) y sus celdas de obra negra son fotos de Poly Haven (CC0, `tools/blender/cache/<nombre>_diff_1k.jpg`, no va en Git): block = `concrete_block_wall` (aclarado a media 0.38), ladrillo = `brick_wall_005` o `broken_brick_wall` (una u otra por casa, por nombre), casas pintadas = `damaged_plaster` teñido (`YESO`), tablas que tapan ventanas = `old_planks_02` (`TABLA`). Como cambió el tamaño del atlas hubo que **reexportar las tres colonias** (Santa Mugre, La Gotera y la favela) para que sus UV cuadren. `kit.atlas()` las reconstruye (en Blender: exec de `kit.py` con `SOLO_FUNCIONES` y `atlas()`). `tools/mapa/captura_colonia.gd --colonia=la_gotera_favela` saca fotos de la favela.

- **Ventanas, tendederos y nada flotando (JJ, 2026-11-13)**: en las casas `limpio` las celdas de ventana del atlas se vuelven muro y la ventana es geometría (`kit._ventanas_obra`: vidrio oscuro, marco, repisa y cortina en una de cada cuatro). Tendederos, toldos y cables de focos **llegan a los muros de verdad**: se mide desde el eje del callejón hasta la pared de cada lado (`colonia._entre_paredes`, `favela._limpiar_toldos`) y si un lado no tiene casa de dos pisos o el hueco pasa de 4 m, no se pone. La ropa es variada (`colonia._prenda`: camisa, pantalón, sábana, vestido, calcetines). Se quitaron las bancas azules de la plaza del tinaco y lo azul de los patios.
- **Árboles de modelo y jardineras (JJ, 2026-11-13)**: los árboles de la favela son solo los de la librería (arce, realista, roble; `kit.arbol_tipo` ≥ 1, los dibuja `ArbolesModelo.gd`), nunca el arbolito de código. `favela._arboles`: en patios y claros chicos van **sin jardinera**, en una esquina, para no estorbar el paso; en las **plazas grandes** (≥ 18 m: los tres `Claro_Grande` y la del tinaco) van **dos jardineras de La Mojiganga** (pieza `jardinera_plaza`, la misma forma que `plaza.py` `jardinera()`: 2.6 × 7.2 m, 1.1 de alto, con choque) cada una con **dos árboles**, retexturizadas al entorno (block sin aplanar y borde de concreto).
- **Casas cueva por dentro (JJ, 2026-11-13)**: hay **7 cuevas largas** (`ABANDONADAS["pasadizos"]`, de 6 casas; se escogen separadas entre sí y, si no caben, con una vuelta más permisiva de separación y atajo) y 8 pasantes.
  - **Pasantes** (cuevas cortas, sin cuartos): pasillo angosto recto/en L de puerta a puerta por el centro (`favela._pasillos`, `PASILLO_ANCHO` 1.4 m) y lo demás macizo (`piezas._relleno_cueva`).
  - **Pasadizos** (cuevas largas): el pasillo **bordea los muros** de puerta a puerta (`favela._cuartos_cueva`, `CUEVA_PASILLO` 1.3 m, en L o en U por los lados que hacen falta, `_arco`) y adentro va un **cuarto chico y atiborrado** (`CUARTO_FRENTE` 3.3 × `CUARTO_FONDO` 2.8 m; dos si cabe) contra el pasillo; lo que sobra es macizo. Son los cuartos de los túneles de antes (pieza `tunel_cuarto` con `"cueva"`: muros de 0.2 m con choque, puerta al centro y ventana con barrotes a cada lado si cabe; sin techo propio). Cupos de JJ (`CUARTOS_CUPO`): **11 dormitorios, 11 cuartos de casa, 4 bodegas de garrafones y 4 tienditas**; el primero de garrafones lleva la marca `Garrafones_Tunel`. Frente a cada tienda del túnel el pasillo se ensancha a un zaguán de 3 m (`CUEVA_ZAGUAN`) para que al salir no quedes en un cuarto.
  - **Muebles: modelos de la librería, no de código** (`favela._muebles`): cama, ropero, silla, mesa, sillón y tele de `models/casa_personaje`, garrafón y despachador de agua, anaquel oxidado, y del pack de tacos refri, mesa (mostrador), cajas de refresco y cubeta. Cada uno lleva su caja máxima `[largo en planta, alto]` porque los modelos sueltos vienen en escalas muy distintas (la mesa en cm, el tinaco ×1000).
  - En los pasillos y en los callejones techados van props del pack de tacos arrimados a un lado y **sin choque**. Todo sale en `datos["props"]` como `[x, z, giro, pack o ruta, nodo, y, choca, medida]` → `resources/mapa/la_gotera_favela/props_modelo.json` → `scripts/mapa/PropsColonia.gd` (lo crea `MapaColonia` si existe el archivo; `TianguisPiezas.pieza` acepta una ruta de escena como pack).
  - Las puertas de las cuevas no salen frente a una tienda ni pegadas a una casa-tienda (el negocio de `MapPuntos` mide 7.1 m de fondo y se metía al callejón: la farmacia tapaba una salida), y una casa larga que no es doble ya no se queda con la celda de al lado (`dueno`).

## Túneles

- **Geometría aparte en la misma escena, bajo el piso** (no un hundido abierto): piezas `tunel` (galería de ladrillo con bóveda, piso de tierra, tubería y focos) y `tunel_cuarto` (dormitorio, garrafones, armas, tienda con mostrador y lona, válvula) a `y = −4.2`. Se baja por un `hundidos` con `"abiertos": [lado]` (nuevo: esa orilla no se tapa) y una `bajada` de 5 m a 40°. Por qué así: el piso del recorte sigue siendo una sola malla triangulada con tres huecos chicos (nada que rompa el piso ni la física), y lo de abajo son cajas y quads baratos que `MapaPostImport` junta por cuadro; un hundido abierto habría sido una zanja a cielo abierto, no un túnel.
- Trazo: de cada boca una galería al oriente hasta una **espina** norte–sur; de la espina la **principal** al oriente con los cuartos alternando lados (dormitorio, garrafones, tienda "Fayuca del Túnel", armas, tienda "Balas y Veladoras", dormitorio, válvula) y la boca final tapada. Las dos tiendas llevan marca `puerta` con su giro propio (`favela.TIENDAS_TUNEL`) y su interior de cuarto de ladrillo con foco:
  - **Fayuca del Túnel** (`fayuca_tunel`, `scenes/interiores/tunel_fayuca.tscn`): cigarros, bocina, cinta, botiquín, Vaporub, caguama, alcohol y plata, a 0.85 del precio.
  - **Balas y Veladoras** (`armas_tunel`, `scenes/interiores/tunel_armas.tscn`): machete, bate, sal, trapo, gasolina y alcohol (lo del molotov), a 1.15 del precio, con un altarcito de veladoras. Balas no hay todavía: el objeto no existe (`docs/items.md`).
  Los precios son primera propuesta. Las dos están también en el safehouse.

## Cambios de la tarde (JJ, 2026-11-13)

- **Sin Bodega del Agua**: se quitó su reserva, su casa-local, su puerta, su negocio `purificadora` y la marca `Bodega_Agua`; el cuarto de garrafones del túnel sigue como `Garrafones_Tunel`. El laberinto se reacomoda en el hueco que dejó la reserva.
- **Plaza del Tinaco**: el claro **3×3** (unos 21×21 m) más cercano al centro del recorte, el mayor de los cuatro claros grandes. Tinaco de **50,000 L** (~4.79 m de alto, ~3.74 m de diámetro) con `TinacoComunitario.armar(litros, con_virgen, comunitario)`: **sin** mancha de la Virgen, sin ofrenda, sin veladoras y sin grupo de defensa. La variante `lote` "tinaco" tiene piso de concreto, bancas, macetas y una pared baja; su poste de luz va en una esquina.
- **Tres claros grandes más** de 3×3 (unos 21×21 m) repartidos a ≥45 m del tinaco y entre sí, y **cuatro claros pequeños** de 2×2 (unos 14×14 m), con variantes `juegos`, `basquet`, `fonda`, `baldio`/`taller`. Total: **4 grandes** (tinaco + 3) y **4 pequeños**.
- **Puertas de las tiendas** (JJ, 2026-11-13): todas dan a un **patio, plazuela o claro**, nunca a un callejón: al salir, `Interiores._salir` te deja 3 m delante de la fachada y en un callejón eso caía dentro de la casa de enfrente. `favela._lado_a_patio` pide que el punto a `SALIDA_TIENDA` (3.6 m) delante de la puerta caiga en un patio, pegado a la casa o del otro lado del callejón; la puerta va en ese lado (`frente`). Cada punto guarda `puerta_transitable: true` y `frente_lado`.
- **Seis tiendas de favela**, una por giro de `MapPuntos.GIROS_LOCAL` (abarrotes, licorería, farmacia, ferretería, OXO, taquería), en casas de una celda de un piso, a ≥35 m entre sí, con `casa local` + `puerta local` + `negocio` (`y` de su banda, `favela: true`, `sin_gente: true`). `MapPuntos` las dibuja con paleta de obra negra, sin banda/botarga/maquinita/puesto de taquería, con letrero pintado y cortina de lona; el interior es el de siempre. La gasolinera queda fuera y la purificadora ya no existe.
- **Puentes**: los 4 tablones más anchos (1.8–2.3 m de hueco) se ensanchan a 1.1 m y llevan barandales de fierro; los 143 tablones restantes se ensanchan a 0.95 m. Las 5 escaleras dejan subir a la red de azoteas.
- **Toldos**: 203 lonas de fachada a fachada sobre los callejones, a 3.0–3.4 m, con caída y cables; sin choque. Para que `Gente` no los tome como techo, su rayo baja desde 2.6 m.
- **Focos**: 443 en total (cada 10–15 m), bombilla de 0.11 m con pantalla cónica, alcance 8 m y energía 1.8; un poste de luz por claro (5).
- **Minimapa propio**: `tools/blender/mapa/minimapa_colonia.py` escribe `textures/map/minimapa_la_gotera_favela.png` (0.5 m/px) y `resources/mapa/la_gotera_favela/minimapa.json` (radio 55 m, iconos). `MapMinimapa` pinta callejones, casas, claros, túneles punteados, tablones y los iconos **T** (entradas de túnel), **A** (azoteas), **S** (salidas) y la gota azul del tinaco. `MapaColonia` cambia `Minimapa.mapa`/`datos_path`; si falta el PNG o el JSON se queda el minimapa real.
- **Cámara de callejón**: `scripts/mapa/GiroFavela.gd` pone `Player.giro_con_wasd` solo en `la_gotera_favela` y en el piso por debajo de 3.2 m. Con W, A/D giran la cámara; en azoteas, tianguis y demás colonias A/D vuelven a ser strafe y la cámara se gira con el ratón. En el safehouse, F11 lo prende/apaga para probarlo.
- **Gente**: `une_a` 2.2 en la favela; camina por callejones planos, sin escalinatas ni cambios de banda. Se saltan las tiendas `sin_gente`.

## Decisiones de la noche (sin JJ)

- **Dos escenas, no una:** el tianguis es una franja (x 700–768) y la favela otra colonia que empieza en x 730; se traslapan 38 m para que las bocas queden en las dos. Barato y reversible: si se quiere una sola escena, se junta en un `.json`.
- **La muralla poniente del tianguis va a mano** (piezas `muralla` sesgadas por `FortalezasMapa.GOTERA`) y `bloqueo.py` no pone la del recorte por ese lado (`"sin_barda"`). Entre la muralla y la orilla del recorte queda una franja de piso de hasta 20 m que solo se ve desde arriba.
- **Muralla de puro block de 3.6 m** (`"muralla": {"base": 3.6}`) en vez de la de lámina y tambos de los fieles: la ficha pedía "barda alta de block con alambre".
- **Rejas de La Gotera de fierro de 3.2 m** (`reja_fierro`), `libre` (no piden la guardia de Chuy).
- **Guardias y vigías con los civiles `hombre_*`:** los `asesino_*` del pack PSX no están retargeteados (sin animación).
- **La favela ignora la traza de OSM** (JJ a media noche): `favela.py` tira calles, casas, lotes, tapones y postes del bloqueo y deja solo la muralla.
- **Perfil detallado** (JJ, 2026-11-13 tarde): se quitaron `detalles: false` y el perfil `"callejones"` espaciado; vuelven los detalles de azotea y los adornos por omisión (tendedero cada 4.5–8 m, basura cada 8–16, foco cada 10–15, capillita cada 2). El `.glb` queda en **~56 MB** y se sube con Git normal (no LFS): GitHub acepta hasta 100 MiB y avisa a partir de 50 MiB. El repo ya pesaba ~516 MB; conviene commitear solo la versión final del `.glb`.
- **La favela es cerrada y con niebla** (JJ, 2026-11-13). Su `.json` lleva `"ambiente"`, que `exportar.py` copia a `marcas.json` y `MapaColonia._ambiente` aplica al cargar:
  - `niebla` 0.045 en vez de 0.0196: el 5 % se ve a unos 67 m en lugar de 150 m.
  - `lejos` 85 m: la cámara del jugador no dibuja más allá, porque la niebla ya lo tapa. El dron no cambia.
  - `gente`: hasta 16 caminantes que salen entre 12 y 38 m del jugador y se quitan a 50 m. El suelo cuenta como camino hasta 2 m de alto, por las terrazas de 0.75 y 1.5 m; el rayo baja desde **2.6 m** (arriba de las terrazas y abajo de toldos, tablones y focos). `une_a` 2.2: solo cambian de línea si el tramo es piso caminable y no salta de banda más de 0.35 m.
- **Escaleras de fierro solo donde caben a lo largo de la fachada** (unos 6.6 m con su rampa): con fachadas más cortas se salían de la esquina y tapaban el callejón de al lado. Por eso la generación anterior solo dejó una: casi ninguna fachada de 2 pisos llega a 7.1 m útiles. Ahora hay **5**: 2 en casas de 2 pisos largas/dobles (azotea a 5.55 m) y 2 en casas de 1 piso (azotea a 3.2 m), más la original.
- **Las casas van juntas por bloques de 6×6 celdas** (`"grupo"` → una malla por bloque, `colonia._juntar_grupos`) para que el `.glb` y la importación pesen menos.
- **Nombres parodia** (`"nombres_parodia"`, real → juego): Av. del Cedro Seco, Calle Primavera Marchita, Calle Nogal Hueco, Calle Roble Torcido, Av. Parota Sin Sombra, Calle Caobilla Apolillada, Privada Roble Quebrado, Privada del Chorro, Privada de la Fuga, Calle Sin Número, Calle Tres Cuartos, Privada del Gotero, Calle Monte Caramelo, Privada Monte Caramelo, Calle Ébano Quemado, Calle Seis Cerrada. En la favela ya no hay placas (no hay calles).
- **El LSD de las tiendas (M7c) no se tocó**, como se pidió.

## Qué falta / pide decisión de JJ

- Nombre definitivo de la Av. del Cedro Seco y de las bocas (las de la favela ya llevan nombre: ver "Orientarse").
- Los dadores de la mafia dentro de la favela (Nemesio, el Primo, el gremio) son marcas `mision` sin misión todavía (M8/M9 y S7, el mercado ilegal).
- ~~Interior de la tienda ilegal de La Gotera~~ (resuelto: es un segundo `punto`).
- Revisar en ventana la Plaza del Tinaco (50,000 L, sin Virgen) y las 6 tiendas de favela; el `.glb` detallado (~56 MB) hay que medirlo en la GPU.
- Si las balas de la pistola se venden en "Balas y Veladoras": falta el objeto.
- Zombi de cobalto en "zonas con obra negra": la casa ya existe en el kit.

## Vuelta de navegación y adornos (JJ, 2026-11-14)

JJ pidió que la favela **se sienta favela y sea divertida de caminar**. Lo que cambió:

- **La barda ahora rodea las casas** (`favela._muro_contorno`). Antes la ponía `bloqueo.py` recta sobre el recorte y, como la cuadrícula va girada `theta` (5°), quedaba una franja vacía en diente de sierra de **hasta 14 m** entre el muro y las casas, caminable y fuera del laberinto. Ahora `favela.py` tira también la muralla del bloqueo y traza la suya siguiendo el contorno de las celdas ocupadas, a `MURO_SEPARA` 0.3 m de las fachadas (hueco real: 0.3 m). Un *flood fill* desde la orilla decide qué celdas vacías son "afuera": las **reservas** (plaza de los Gotera, casa de don Nemesio) cuentan como colonia y **no** se amurallan — si no, quedaban encerradas en un cuadro sin paso.
- **Las bocas son rejas** (`piezas.reja_fierro` con `cerrar_hasta`, que tapa de la reja al alto de la barda). Se llega **adentro del laberinto** (`BOCA_LLEGADA` 3.2 m) con la reja atrás; antes se aterrizaba afuera del muro y había un pasillo de entrada de varios metros. Cada boca fuerza abierto su callejón hacia adentro, para no llegar dentro de una casa.
- **Sin los lotes muertos de túnel**: `"tuneles": false` (y el valor por omisión). Reservaban tres pares de celdas junto a las bocas y nadie las usaba (`_tuneles()` no se llama), así que eran huecos de 15 × 8 m pegados al spawn.
- **Claros más chicos** (JJ): el del tinaco y los tres medianos son de **2×2 celdas** (`TINACO_CELDAS`, `CLAROS_GRANDES_CELDAS`) y los otros siete de **una sola celda** (`CLAROS_EXTRA_CELDAS`). Con los de 3×3 el laberinto perdía callejones y cuevas. El **tinaco va al medio de un cuadrante**, no al centro: por el centro del claro cruzan los callejones de la cuadrícula y el tanque (1.9 m de radio) los tapaba.
- **Las cuevas unen partes lejanas**: `CUEVAS_DIST_MIN` 9 (antes 6) y `PASANTE_DIST_MIN` 3, con una segunda vuelta más permisiva si no salen las ocho casas pasantes. Una cueva que sólo evitaba rodear una esquina ya no vale.
- **Pasillos que sí se pasan**: callejones de **2.0 a 2.8 m** (antes 1.7–2.6), pasillos de cueva `PASILLO_ANCHO` 1.8 / `CUEVA_PASILLO` 1.7 (antes 1.4/1.3; la retícula de 0.2 m de `_relleno_cueva` se comía hasta 0.2 m más, y `_relleno_cueva` ahora redondea a favor del pasillo), y los postes de los callejones techados pasaron de 0.24 m con choque a 0.1 m empotrados.
- **Tiendas del túnel con puerta**: iban en un muro **sin** hueco, así que era una flecha contra pared ciega. Ahora `_cuartos_cueva` las pone en la puerta de un cuarto de uso `tienda` (con su mostrador, anaquel y foco a la vista desde el pasillo) y el **+Z de la marca va a lo largo del pasillo**, hacia el lado con más corrida recta: cruzándolo, `Interiores._salir` (2.2 m al +Z) te dejaba dentro del muro de enfrente.
- **La cancha, al aire libre** (JJ): `piezas.cancha` acepta `"abierta": true` (sólo la de la favela; la de Santa Mugre sigue encajonada): sin muro de block ni malla ciclónica, con guarnición baja, dos gradas de concreto y las porterías. Era "un edificio sin paso gigante" en medio de la plaza.
- **La Plaza de los Gotera llena**: papel picado cruzado, dos lonas de sombra, tres puestos más, dos bancas y cuatro árboles (piezas a mano en el `.json`). Piezas nuevas reutilizables: `papel_picado` y `lona_sombra`.
- **Techos con textura**: las losas de las casas cueva y de los callejones techados usan la textura del muro (`foto_block`/`foto_ladrillo_rojo`); en `concreto` liso se veían blancas desde abajo.
- **Ropa y cartón con textura**: `kit.TELAS` (ocho colores de la misma tela dibujada, `_tela`) y `foto_carton` (`_carton`). `piezas.prenda` da forma a la ropa del patio (camiseta, pantalón, sábana, calcetines) con sus pinzas, y los tendederos de callejón cuelgan también entre casas de un piso (`TENDEDERO_BAJO`).
- **Props**: `_props_callejones` pone montones de 2 a 3 cosas arrimadas a la pared de verdad de cada callejón ≥ 2.2 m, nunca junto a un patio o claro. La mezcla es sobre todo garrafones y cubetas, más manguera, carretilla, tablas, tinaco, botes y sillas; las carteras de refresco bajaron a 2 de 11 (JJ: "hay demasiadas carteras de refrescos en todos lados") y salió el pack `cajas`.
- **Árboles**: 75 (antes 33). Más patios (`PATIO` 0.09), hasta dos árboles por patio, las cuatro esquinas de los claros medianos y separación más corta. Ninguno cae en un callejón: `_en_callejon` descarta árboles y jardineras encima del arroyo (una jardinera partía en dos el `Callejon_182`).
- **Noche más clara**: `ambiente.noche` del `.json` (niebla 0.028, ambiente 0.62 y colores menos negros) y `ambiente.focos` [2.5, 11] para las marcas `foco`. `MapaColonia._ambiente` se los pasa a `Ciclo` antes de que lea los valores de día; `Ciclo.niebla_densidad` interpola la niebla hacia la de noche.
- **Caminantes**: `Gente._pared` tira un rayo horizontal a la cintura. El de `_altura` nace a 2.6 m, o sea **dentro** de los muros de 2.75 m, y les pegaba por abajo: todo le parecía piso y la gente atravesaba las casas. Además `caminos.py` recorta contra las casas abandonadas y las piezas armadas, y su `_ensanchar` es un *offset* real por lado (el radial dejaba los lados largos casi sin margen).

### Herramientas nuevas

| Comando | Para qué |
|---|---|
| `tools/mapa/rehacer_colonia.sh <colonia> [--rapido]` | favela.py → Blender → import en un comando. `--rapido` se salta el `.blend` y el minimapa: **52 s** en vez de ~3 min (antes de commitear, una vuelta sin `--rapido`). |
| `godot --path . --headless -s tools/mapa/atorones.gd` | Busca por dónde **no se pasa** sin caminar el mapa: planta la cápsula del jugador cada 0.35 m sobre el eje de cada callejón, cada pasillo de cueva y frente a cada flecha de tienda, y sólo reporta donde no cabe en **ningún** corrimiento lateral. Mucho más rápido y exhaustivo que `recorrer_favela.gd`. |
| `python3 tools/blender/mapa/variantes.py <colonia> [--semillas=..] [--usar=N]` | Varios trazados con su minimapa (~6 s cada uno), **sin Blender ni render**, para escoger semilla. `--usar=N` la fija en el `.json`. |
| `recorrer_favela.gd -- --solo=callejones,cuevas,gente,noche` | Correr sólo unas pruebas en vez de la vuelta completa. |

La semilla en uso es la **73**, escogida por JJ entre ocho minimapas de `variantes.py`. Las imágenes no se guardan en el repo (se regeneran en ~6 s cada una, por omisión en `capturas_favela/`).

## Orientarse y adornos de los claros (JJ, 2026-11-14)

JJ pidió que el laberinto sea divertido y no frustrante, sin depender de ninguna misión. Quedaron los nombres de las bocas y un callejón principal por boca en el minimapa.

- **Nombre de cada boca**, de la calle real que salía de la avenida: La Fuga, Roble Quebrado, La Parota, Caobilla y Sin Número (`favela.NOMBRES_BOCAS`). Va pintado en la tapa de block encima de su reja, del lado de adentro ("Boca de la Fuga", a 3.85 m), para encontrar la salida al regresar. A menos de 7 m de una boca ya no hay tendederos (`colonia.TENDEDERO_SIN_BOCA`): la ropa tapaba el nombre.
- **Callejones principales**: de cada boca, el camino más corto por callejones a la Plaza del Tinaco (`favela._orientarse`: grafo de las piezas `calle`, Dijkstra). Donde dos se juntan cerca de la plaza, el tramo se queda con el más corto. Los caminos quedan en `"principales"` del `.json` y solo se ven en el minimapa.
- **Sin placas en los callejones**: hubo 44 placas pintadas en los cruces de los callejones principales, con flechas a la salida y al tinaco; JJ las quitó el mismo día.
- **"Plaza del Tinaco"** pintado en las dos caras de su pared baja de cal.
- **Minimapa**: los callejones principales van más claros y cada salida lleva la inicial de su boca (F, R, P, C, N) en lugar de la S.
- **Props** (lo que JJ vio en ventana):
  - **Fuera los cubos de colores sin textura**: el pack `cajas` de los cuartos (ahora cajas de refresco), la silla de cajas rojas de los patios (ahora la silla plegable de la librería), el colchón y el bloque de los baldíos, y las mesas, sillas y carrito de cajas de las fondas.
  - **Las fondas llevan las mesas de la taquería** (`Mesa.gd`: cubierta roja, sillas plegables, salseros) con su caja de choque, una a tres bajo la lona. Las pone `exportar.mesas_fondas` para cualquier colonia, así que Santa Mugre y el tianguis también las tendrán al rehacerse (hoy sus `.glb` todavía traen las de cajas).
  - **Fuera los patios y plazuelas encimados en un claro** (`favela._quitar_dentro_de_claros`): los claros se hacen después y solo quitaban casas, y había una fonda dentro de la Plaza del Tinaco. Se fueron 5; quedan 2 fondas con 3 mesas.
  - **Tambos de fierro con fuego** (`MapAlumbrado.armar_tambos`, con choque y luz naranja siempre prendida) en los callejones abiertos: 59, pegados a la pared de verdad, uno por callejón de 6 m o más, a 20 m uno de otro, lejos de bocas, patios, claros y techados (`favela._tambos_fuego`). Primero iban dentro de las casas abandonadas y bajo los techados, y JJ no los quería en lo cerrado. En las esquinas de las plazas también hay con fuego; en la Plaza del Tinaco y el taller, el mismo tambo apagado (marca `tambo`, `piezas._tambo`). Su MultiMesh va sin alcance de dibujo: abarca toda la favela y el alcance se mide al centro de su caja, así que con 60 m no salían.
  - **El garrafón azul de 50 L mide 60 cm** (antes 0.38 a 0.5 m): los de la librería en la favela y el tianguis, el del garrafonero de `Gente`, los horneados de la fila del agua de la Plaza del Tinaco y el de los vecinos (`Colonia._garrafon`). Los de la ventana de la purificadora y la casa del protagonista se quedaron como estaban.

  - **Fuera los props hechos por código que quedaban** (JJ, 2026-11-14): las bolsas de basura y las llantas son modelos CC0 de Poly Haven (`models/props/bolsa_basura`, `models/props/llanta`, `tools/map_import/fetch_polyhaven.py`, reducidos a 280 y 360 triángulos). Las bolsas van amontonadas pegadas a la pared (una fila en el piso y las demás encima), en los callejones (`colonia._basura`, que busca la pared de verdad), los baldíos y los montones de `PROPS_CALLE`. Las llantas van acostadas en pila (campo `tumbada` de `PropsColonia`). La fila de garrafones, las cubetas y el tinaco de los patios son los de la librería; las veladoras de las capillas, el modelo de veladora. Fuera el tinaco de 46 cm de los callejones y la manguera. Quedan hechos por código, a propósito, la capilla, los tambos de la muralla y las cajas de cartón (con textura de foto).
  - **Las piezas ponen props y marcas**: `piezas._prop` y `piezas._marca_pieza` los anotan en locales, `colonia.py` los lleva al mundo (`PROPS_PIEZA`, `MARCAS_PIEZA`, como los carros) y `exportar.py` los suma a `props_modelo.json` y `marcas.json`. Sirve para todas las colonias.
  - **Menos jitter en los props**: `PropsColonia` les quita el wobble y les pone el snap a 320 (un pixel), con una copia por material y por malla, no por instancia. Son 3 mil props (1,600 bolsas), así que van en MultiMesh por cuadro de 24 m y no como nodos.

Pruebas: `probar_gotera.gd -- --favela` **48/48** y `atorones.gd` **0 atorones** con los tambos, las mesas y la basura puestos; capturas con ventana de cada cosa. **Falta:** jugarlo en ventana y medir los FPS con las 59 luces de los tambos (`medir_gotera.gd`).

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

Lo más caro es el tramo del agua del tianguis, 2.2 ms sobre Santa Mugre. La tabla es del **perfil simplificado** (24 MiB); el detallado (~56 MB, 203 toldos, 443 focos y 5 escaleras) está pendiente de medir en ventana con `medir_gotera.gd`. Pruebas: `tools/mapa/probar_gotera.gd -- --favela` (**48/48**: tiendas, entrar y salir de cada una a su patio, las dos tiendas del túnel dentro de la cueva, minimapa propio, tinaco sin Virgen y giro con WASD) y `tools/mapa/recorrer_favela.gd -- --cuantos=30` (**9/9**: callejones planos, cruzar cada casa abandonada y callejón techado, la cámara adentro, gente y focos de noche; las pruebas de escaleras y túnel se saltan mientras no haya). Quien dice si de verdad se pasa por todos lados es `tools/mapa/atorones.gd` (**0 atorones**: 395 tramos de callejón, 50 cuevas, 100 marcos y 8 flechas de tienda con la cápsula del jugador); `recorrer_favela` camina en línea recta y en una vuelta cerrada de pasillo se queda corto sin que el paso esté tapado, por eso admite una cueva de diferencia.
