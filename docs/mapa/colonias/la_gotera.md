# La Gotera (fortaleza de la mafia) — plan de diseño

💡 **Borrador** (JJ, 2026-11-12), para hacerlo después en Blender. Bloque **F4** de `docs/plan-noche.md`. La historia de los Gotera está en `docs/lore.md` §11; la zona del contenido, en [`../zona-enfoque.md`](../zona-enfoque.md).

## Dónde

- **Cambia el canon:** La Gotera ya **no** está "al sureste, detrás de la autopista". Está en **Haciendas de San José** (Haciendas de San Jodido en el juego), pegada a la orilla oriente del mapa. Falta pasarlo a `lore.md` (§11, §13 y la tabla de las tres fortalezas), a `especificaciones.md` y a `ZonasMapa.gd`.
- **La barda va por las calles** (JJ, 2026-11-12), para no partir casas, siempre por el lado de la banqueta, a 5.5 m del eje de la calle:
  - **poniente:** por la banqueta poniente de la **Av. del Cedro**: la avenida queda adentro y las casas del otro lado, afuera, viendo a la barda;
  - **norte:** por la banqueta sur de la calle **Primavera**;
  - **sur:** por la banqueta norte de la calle **Nogal**;
  - **oriente:** la orilla del mapa.
  Mide unos 195 m de ancho (de x ≈ 705–723 a 914) y 230 m de fondo (de z ≈ −341 a −96). Los vértices están en `FortalezasMapa.GOTERA`.
- **La única entrada es la Av. del Cedro:** **reja norte** en la esquina con Primavera (728, −341) y **reja sur** en la esquina con Nogal (710, −114), las dos de 11 m. Son ~228 m de avenida entre las dos.

## La idea: Tepito con favela

1. **El tianguis lineal** es la avenida entre las dos rejas. **Cualquiera entra y sale** por ahí. Es la fortaleza que se ve.
2. **A los lados no se pasa sin permiso.** Del lado poniente está la barda; la favela queda **solo al oriente** del tianguis, entre la avenida y la orilla del mapa. El tianguis es un pasillo con muro de un lado y favela del otro.

## El tianguis

- Se reutilizan `scripts/mapa/Tianguis.gd` y las carpas de `tools/blender/tianguis/carpas.py`: una entrada `tianguis` con `a`/`b` sobre la avenida, más apretada que en Santa Mugre (`pasillo` ~1.8 m, pocos `libres`) y con las lonas encimadas que casi tapen el cielo.
- **Tramos por giro**, cada uno con su color de lona, para que se lea como Tepito:
  - armas y fierros;
  - agua del yacimiento y garrafones (lo único que se vende a precio justo);
  - fayuca y electrónica;
  - farmacia "sin receta";
  - ropa y tenis piratas;
  - comida (fritangas, tejuino, tacos).
- La **tienda ilegal** (balas, tachas, lo que en la tienda no hay) es un local de la avenida, no un puesto.
- De noche el tianguis sigue abierto: es el mercado clandestino del lore (§14), con todo ×2 o ×3.

## La favela

- **Laberinto de casas de obra negra.** Los callejones salen del lado oriente del tianguis y se meten hacia la barda oriente.
- **Callejones de Guanajuato o São Paulo, en horizontal:**
  - de 1.2 a 2.5 m de ancho, quebrados, muchos sin salida;
  - escalones y rampas que suben y bajan sobre `terrazas` de 0.75 a 1.5 m, porque no hay cerro;
  - tendederos, cables colgando y puentecitos de lámina entre azoteas.
- **Permiso por escalones** (`misiones.md`: afuera, mandadero, de confianza, de la casa). Cada boca de callejón tiene un Gotera de guardia, y cada escalón abre un pedazo más del laberinto. Sin permiso, el guardia te regresa; si te metes, "no sales".
- Para que el minimapa no mienta, conviene **conservar la traza real de Haciendas** como callejones principales y meter el laberinto dentro de cada manzana.

## Lugares clave

| Lugar | Dónde | Qué es |
|---|---|---|
| Rejas norte y sur | Avenida | Vigilancia, puestos de vigía en las azoteas de junto |
| Tienda ilegal | Avenida, tramo de armas | La tienda de la mafia |
| Agua del yacimiento | Avenida, a media cuadra | Venta a precio justo |
| Plaza o cancha de los Gotera | Corazón de la favela | Donde se juntan; dador de misiones |
| Casa de don Nemesio | Fondo de la favela, junto a la orilla | La única con enjarre y pintura; escalón "de la casa" |
| Bodega del agua | Junto a la barda poniente o al fondo | Garrafones del yacimiento |
| La válvula / bajada al acueducto | Escondida en la favela | La palanca contra los Lazcano (lore §11) |
| Boca de los túneles | Tapada, para después | Los túneles salen fuera de la ciudad (lore) |

## En Blender

1. **Ficha aprobada** (esta) → JJ y AG.
2. **La casa de obra negra** en `tools/blender/mapa/kit.py`, junto a `casa_malla`:
   - block gris sin enjarre y castillos con varilla saliendo;
   - losa a medias y ventanas sin marco, con lona o tabla;
   - tinaco negro viejo en la azotea;
   - de 1 a 3 pisos, el tercero solo con castillos.
   Sirve también para el zombi de cobalto ("zonas con obra negra"). Antes de seguir, enseñar capturas.
3. **`tools/blender/mapa/colonias/la_gotera.json`** con:
   - `recorte` [704, −342, 914, −95] (la caja que la contiene; la barda sigue los vértices de `FortalezasMapa.GOTERA`);
   - `bordes`: oriente = la orilla del mapa (barda alta de block con alambre, sin tapones de calle), sur = sobre la calle Nogal, poniente = barda (o la avenida si se pega), norte y sur = barda con reja en la avenida;
   - `reservas` para la avenida, la plaza y la casa del jefe;
   - `tianguis`, `marcas` (rejas, guardias, dadores, tienda ilegal, válvula, túneles) y `tiendas`;
   - `nombres_calles` parodiados (la Av. del Cedro necesita nombre: p. ej. "Av. del Cedro Seco").
4. **Generador del laberinto** (nuevo, en `bloqueo.py` o en su propio script):
   - cuadrícula de ~4 m con un DFS de una sola semilla (la favela está de un solo lado);
   - abrir algunos muros para que haya lazos y no sea un árbol perfecto;
   - meter lotes de 4 a 6 m de frente a los lados de cada pasillo;
   - las `terrazas` de los escalones salen de la distancia a la avenida (más adentro, más alto).
5. `colonia.py` → `referencia.py` (comparar con OSM) → ajustar → `exportar.py` (con `~/run_exportar.py` en esta PC) → `godot --headless --import` → probar en `mapa.tscn`.
6. **Medir**:
   - el tianguis ya cuesta +3 a 5 ms de GPU (`tools/tianguis/medir_tianguis.gd`);
   - el laberinto denso es el riesgo, así que van pocas mallas por manzana (una por bloque de casas, no una por casa);
   - las casas de adentro se esconden con `visibility_range`.
7. Trabajar en **rama propia**, aparte de `Map-Blender-Creation` de Alan.

## Pendiente de decidir

- Nombre parodia de la Av. del Cedro y de las calles de adentro.
- Qué pasa con la zona "La Gotera" del sureste en el mapa de papel (renombrarla; el mapa no se recorta).
- Si los Gotera dejan entrar al tianguis de noche (la regla común de las fortalezas dice que dentro no hay zombis).
