# Guadalajaja — Items

> El catálogo de objetos del juego: qué son, qué hacen, cuánto cuestan y si ya tienen modelo. Documento hermano de [`docs/especificaciones.md`](especificaciones.md) (las mecánicas), [`docs/lore.md`](lore.md) (el mundo) y [`docs/misiones.md`](misiones.md) (las misiones).
>
> Última actualización: 2026-11-02

## Cómo usar este documento

| Etiqueta | Significa |
|---|---|
| ✅ **Canon** | Ya está decidido. |
| 💡 **Propuesta** | Idea abierta. |
| 🧱 **Ya existe** | Hay modelo o recurso en el repo. |
| ❌ **Falta** | No hay modelo o no está implementado. |

**La regla de los items:** cada objeto ocupa **1 lugar** en el inventario (las armas grandes, 2), y si no cabe, se queda tirado. El inventario base es de **6 lugares**; las mochilas lo suben a 8, 10 o 14.

---

## 0. Cómo funciona

- **Inventario:** 6 lugares, comandos Examinar / Utilizar / Combinar (Tab lo abre y pausa el juego).
- **Mochilas:** no ocupan lugar, se equipan al recogerlas y no se pueden cambiar por una más chica.
- **Tipos:** consumible, arma, munición, arrojable, material, equipo, documento, llave y dinero.
- **Agua:** es un **recurso caro**, no una moneda. Se compra en pesos y se gasta bebiendo, curando la sed o truequeando.
- **Precios:** todos en **pesos**. Quedan dos excepciones en los datos (machete y vaporub, en agua) que hay que pasar a pesos.

---

## 1. Consumibles

| Objeto | Descripción | Efecto | Precio | Modelo |
|---|---|---|---|---|
| **Caguama** | *"Agua Mala, bien helada (o casi)."* | +25 vida y mareo ligero; la botella vacía sirve para molotov | 50 | 🧱 `models/aguamala.glb` |
| **Tacos al pastor** | *"Orden de tres, con todo."* | +30 vida | 45 | 🧱 `models/taco_pastor.glb` |
| **Gansito** | *"El de siempre. Recuérdame."* | +10 vida | 15 | 🧱 `models/objetos/gansito/` |
| **Mazapán** | *"Se desmorona nomás de verlo."* | +10 vida | 8 | 🧱 `models/objetos/mazapan/` |
| **Takis Fuego** | *"Pican hasta el alma."* | +daño de golpe por 30 s | 25 | 🧱 `models/objetos/takis/` |
| **Jarritos** | *"De tamarindo, medio tibio."* | Recupera estamina | 20 | 🧱 `models/objetos/jarritos/` |
| **Botiquín del Simi** | *"Trae de todo, menos doctor."* | +70 vida | 120 | 🧱 `models/objetos/botiquin/` |
| **Vaporub** | *"Lo cura todo, dice tu abuela."* | Cura 100 (raro) | 2 (agua → pasar a pesos) | 🧱 `models/objetos/vaporub/` |
| **Tachas** | *"No preguntes."* | Velocidad y estamina sin fin 20 s; luego el bajón | 80 | 🧱 `models/objetos/tachas/` |
| **Cigarros** | *"Cajetilla de los baratos."* | El humo te esconde del olfato unos segundos | 40 | 🧱 `models/objetos/cigarro/` (cajetilla) |
| **Tejuino** | *"Vaso con hielos, pintado café."* | Baja algo la sed | 💡 | 🧱 `models/objetos/tejuino/` |
| **Torta ahogada** | *"Cura mucho, pero pica."* | Cura mucho; pantalla roja unos segundos | 💡 | ❌ |
| **Galón de agua** | *"Purificada y sellada, de las últimas."* | Baja la sed | 35 | 🧱 `models/objetos/galon_agua/` |

---

## 2. Armas

| Objeto | Descripción | Efecto | Precio | Modelo |
|---|---|---|---|---|
| **Machete** | *"Recién afilado."* | 12 de daño, silencioso; arma inicial | 2 (agua → pasar a pesos) | 🧱 `models/armas/machete/` |
| **Machete reforzado** | *"Con cinta canela en el mango. Ya no se te resbala."* | 18 de daño, silencioso | Crafteo | 🧱 `models/armas/machete/` |
| **Bate** | *"De aluminio, ya abollado."* | Cuerpo a cuerpo | 150 | 🧱 `models/armas/bate/` |
| **Pistola** | — | Daño medio, poco ruido relativo | 💡 | 🧱 `models/armas/pistola_mk23/`, `pistola_colt/` |
| **Cuerno de chivo** | — | Automática, mucho daño y **mucho ruido**; rara | 💡 | 🧱 `models/armas/cuerno_de_chivo/` |
| **Ballesta** | — | Silenciosa; se recuperan las flechas | 💡 | 🧱 `models/armas/ballesta/` |
| **Resortera** | — | Silenciosa; piedras infinitas pero débil | 💡 | 🧱 `models/armas/resortera/` |

---

## 3. Munición y arrojables

| Objeto | Descripción | Efecto | Precio | Modelo |
|---|---|---|---|---|
| **Balas** | — | Para pistola (¿y cuerno?); apilables | 💡 | 🧱 `models/armas/balas/` |
| **Bomba molotov** | — | Fuego en área; se craftea | Crafteo | 🧱 `models/objetos/botella/` + `trapo/` |
| **Paloma (cohete)** | — | Aturde a los enemigos cercanos | 💡 | ❌ (el modelo bajado salía mal) |
| **Bocina con banda** | — | Atrae a todos los zombis cercanos; luego explota (o no) | 💡 | 🧱 `models/objetos/bocina/` |
| **Chancla** | *"La de tu jefa nunca falla."* | Aturde a uno; se recoge de nuevo | 💡 | 🧱 `models/objetos/chancla/` |

---

## 4. Materiales y crafteo

| Objeto | Descripción | Efecto | Precio | Modelo |
|---|---|---|---|---|
| **Cinta canela** | *"Si no lo arregla la cinta, no tiene arreglo."* | Repara y mejora armas | 25 | 🧱 `models/objetos/cinta/` |
| **Tablas** | *"Para atrancar puertas y ventanas."* | Barricadas y reparación del tinaco | 35 | 🧱 `models/objetos/tablas/` |
| **Cloralex** | *"Cloro para todo."* | Agua sucia + Cloralex = agua limpia | 30 | 🧱 `models/objetos/cloralex/` |
| **Agua sucia** | — | Material; se junta de charcos o de la llave | — | ❌ |
| **Tequila / mezcal** | — | Combustible alternativo para molotov | — | ❌ |
| **Caguama vacía** | — | Botella para molotov | — | 🧱 |

**Recetas:**

- **Molotov** = botella + trapo + **gasolina** (gasolinera) o **alcohol** (tequila/caguama vacía, más flojo).
- **Machete reforzado** = machete + cinta canela.
- **Agua limpia** = agua sucia + Cloralex (es delito; el Decreto 47 lo prohíbe).

### 4.1 El taller de La Chava 💡🧱 (propuesta de AG; `especificaciones.md` 4.13)

Los datos de verdad están en `scripts/Materiales.gd` (materiales) y `scripts/Recetas.gd` (recetas). Las recetas piden materiales del **Morral** y pesos; Regateo baja los pesos.

**Materiales comunes:** seis familias en tres niveles. Se pierden al reiniciar.

| Familia | Suelto | Bueno | Fino |
|---|---|---|---|
| Fierro | Rebaba | Tuerca | Engrane |
| Trapo | Hilacha | Trapo | Cuero |
| Cable | Alambrito | Cable | Cobre |
| Lumbre | Cerillo | Thinner | Pólvora |
| Agua | Agua sucia | Agua de la llave | Agua destilada |
| Vela | Pabilo | Veladora | Agua bendita |

**Especiales:**
- **Varilla corta:** de la chatarra y de los zombis.
- **Alambrón:** de las obras negras.
- **Plata de Taxco:** se compra en el punto, a $120.
- **Baba verde:** de matar a un zombi quemándose.
- **Polvo de Serenol:** del zombi de GelA.
- **Varilla armada** y **Varilla del 84:** se hacen en el taller.

**Trofeos:** se quedan entre partidas, en la vitrina.
- **Marca de cazador:** matar a un cazador.
- **Ojo de turba:** matar a 5 cazadores en 10 s.
- **Ceniza:** matar con fuego.
- **Tapa del tinaco:** una noche sin que le peguen al tinaco.
- **Diente del jefe:** matar al jefe.
- **Chancla de oro:** matar sin arma.
- **Casco de GelA:** del zombi de GelA.
- **Cobalto:** del zombi que brilla.

| Juego (se abre con) | Remedios y estampitas | Amuletos | Armas |
|---|---|---|---|
| **1** (desde el inicio) | Caldo de pollo (+60), Remedio de la abuela (cura todo) | Pulsera de hilo rojo (+10 vida), Cadena de fantasía (+5 % fuerza), Rodilleras (−5 % daño), Medalla de San Judas (+20 % pesos; pide 4 trofeos) | Tubo de fierro (14, empuja más) |
| **2** (3 hechas) | Suero oral (+40) | Lámpara de pilas (alumbra), Escapulario (−10 %), Pulsera de San Benito (+25 vida), Cadena gruesa (+10 % fuerza, −5 %), Coderas (−10 %, +5 % alcance) | Antorcha de thinner (10, quema), Bate con alambre de púas (17, empuja más) |
| **3** (9) | Estampita de San Expedito (+1 punto de habilidad), Varilla armada (material) | Rosario de semillas (−20 % de noche), Medalla de la Virgen (más tazos raros y holo), Faja de cargador (+40 vida), Cadena de oro (+20 % fuerza) | Coa afilada (20, más alcance) |
| **4** (15) | Té de la Virgen (cura todo), Estampita del Santo Niño (−5 % daño la partida) | Ojo de venado (−20 % de cazadores y jefe, +15 vida), Herradura (−20 % de turbas), Brazalete de cobre (arrojables, todavía sin uso), Corona de lata (de todo un poco) | Machete de cañero (24, golpe rápido) |
| **5** (21) | Milagro del tinaco (cura todo y recarga Segundo aire), Estampita de San Miguel (+5 % fuerza la partida), Varilla del 84 (material) | Chamarra del Nocturno (+30 vida, −10 %, +10 % pesos), Medalla de GelA (+30 % pesos, −5 %), Listón de la Virgen (−20 % de todo) | Marro (30, empuja mucho, golpe lento) |
| **6** (las 36 anteriores y su plano) | — | — | Machetón del 84 (40, rápido), Lanza de varilla (30, mucho alcance), Bate con clavos de cobalto (32, empuja muchísimo) |

---

## 5. Equipo

| Objeto | Descripción | Efecto | Precio | Modelo |
|---|---|---|---|---|
| **Mochila escolar** | *"Todavía trae la tarea de alguien."* | 8 lugares | — | 🧱 `models/objetos/mexican_starter_pack/mochila.scn` (tinte rojo) |
| **Mochila del Partido Verde** | *"La regalaron en campaña. Es lo único que cumplieron."* | 10 lugares | — | 🧱 mismo modelo (tinte verde) |
| **Mochilón del nocturno** | *"Hecho para cargar garrafones. Huele a humedad."* | 14 lugares | — | 🧱 mismo modelo (tinte azul) |
| **Lámpara / celular** | — | Luz de noche (con batería, si se implementa) | — | ❌ |
| **Veladora** | — | Ilumina un rato; el fuego los hace dudar | — | ❌ |

> **Pendiente:** el `mochilon.tres` todavía se llama *"Mochilón del garrafonero"*; hay que renombrarlo a *"del nocturno"*.

---

## 6. Documentos y llaves

| Objeto | Descripción | Efecto | Precio | Modelo |
|---|---|---|---|---|
| **Papel raro** | Un recibo de Agua Cero, una hoja del manifiesto, un acta de ausencia o un aviso de corte | Drop raro de los zombis: cuenta un pedazo del lore | — | ❌ (texto) |
| **Credencial de GelA** | Nombre y puesto de un trabajador de la empresa | Abre una puerta de la empresa (no la sueltan los zombis) | — | ❌ (texto) |
| **Llave de un coto** | — | Abre una zona cerrada del mapa | — | 🧱 `models/objetos/llave/` |

---

## 7. Dinero y agua

| Objeto | Tipo | Efecto | Modelo |
|---|---|---|---|
| **Moneda de peso** | Dinero | La moneda del juego; todo se paga en pesos | 🧱 `models/objetos/moneda_peso/` |
| **Galón de agua** | Recurso | Baja la sed; se compra caro o se consigue en la capilla con cupo | 🧱 `models/objetos/galon_agua/` |

> El agua **no es moneda**: es un recurso caro. El trueque con agua existe en dos o tres NPCs, pero no es el sistema.

---

## 8. Objetos que faltan o están pendientes

- ❌ **Botella de agua** y **garrafón**: los modelos bajados salían mal. Se usan el galón y el `despachador_agua` como referencia.
- ❌ **Agua sucia**: sin modelo; es un material de crafteo.
- ❌ **Paloma (cohete)**, **veladora**, **lámpara/celular**, **torta ahogada**, **tequila**.
- 🧱 **Modelos que sí existen** y no están en inventario: `models/objetos/` tiene llave, cinta, tablas, botiquín, cloralex, galón, cigarros, gansito, mazapán, tacos, tejuino, vaporub, tachas, takis, jarritos, moneda, chancla, bocina, y las mochilas.

---

## 9. Balance actual (datos de los `.tres`)

| Producto | Precio | Moneda | Efecto | Curación | Capacidad | Daño |
|---|---|---|---|---|---|---|
| Caguama | 50 | pesos | +25 vida, mareo | 25 | — | — |
| Tacos al pastor | 45 | pesos | +30 vida | 30 | — | — |
| Gansito | 15 | pesos | +10 vida | 10 | — | — |
| Mazapán | 8 | pesos | +10 vida | 10 | — | — |
| Takis Fuego | 25 | pesos | +daño 30 s | — | — | — |
| Jarritos | 20 | pesos | +estamina | — | — | — |
| Botiquín del Simi | 120 | pesos | +70 vida | 70 | — | — |
| Vaporub | 2 | **agua** | cura 100 | 100 | — | — |
| Tachas | 80 | pesos | velocidad 20 s | — | — | — |
| Cigarros | 40 | pesos | humo | — | — | — |
| Galón de agua | 35 | pesos | baja la sed | — | — | — |
| Machete | 2 | **agua** | 12 de daño | — | — | 12 |
| Machete reforzado | — | — | 18 de daño | — | — | 18 |
| Bate | 150 | pesos | cuerpo a cuerpo | — | — | — |
| Mochila escolar | — | — | 8 lugares | — | 8 | — |
| Mochila del Partido Verde | — | — | 10 lugares | — | 10 | — |
| Mochilón del nocturno | — | — | 14 lugares | — | 14 | — |

**Pendiente de código:** pasar **machete** y **vaporub** a pesos; cambiar el efecto del galón de *"baja la infección"* a *"baja la sed"*; cambiar *"zombies"* por *"zombis"* en los cigarros; renombrar el mochilón.

---

## 10. Preguntas abiertas

- [ ] 💡 ¿El inventario base son 6 lugares o 8?
- [ ] 💡 ¿Las armas grandes ocupan 2 lugares o todas ocupan 1?
- [ ] 💡 ¿El agua se puede beber desde el inventario (gasta un galón) o solo con un comando aparte?
- [ ] 💡 ¿La lámpara/celular gasta batería o es infinita?
- [ ] 💡 ¿Los documentos (el papel raro, la credencial) se pueden leer en el inventario o solo aparecen en un diálogo?
- [ ] 💡 ¿El agua sucia se junta de los charcos o solo de la llave?
- [ ] 💡 ¿La torta ahogada y el tejuino entran al catálogo o se quedan como sugerencia?
- [ ] 💡 ¿Los precios de arriba se quedan o se rebalancean?
