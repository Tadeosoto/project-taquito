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
| **Bomba molotov** | *"Botella con gasolina de limón y un trapo. No es para tomar."* (la de cereza: *"Más brava que la de limón."*) | Fuego en área de 2 m por 5 s (de cereza, 3 m); mata al instante a toda lombriz que toca el fuego y los sacos de la Madre del Cárcamo; te quema si te metes. Se avienta con la tecla 3 (`Lanzador`): dejas apretado el clic y el área que va a quemar avanza en el piso hacia donde ves (de 3 a 16 m en 1.2 s); al soltar, la avientas por encima del hombro. ✅ en el juego: `resources/productos/molotov.tres`, receta botella con gasolina de limón + trapo (`resources/recetas/molotov.tres`); la de cereza (`molotov_cereza.tres`) quema 1.5 veces más lejos | Crafteo | 🧱 por ahora la caguama teñida; luego `models/objetos/botella/` + `trapo/` |
| **Sal de grano** | *"Un kilo de sal. A las lombrices del cárcamo no les gusta nadita."* | Tecla 3 y clic: avientas un puño de sal con un barrido pesado (Sword_Heavy_A): enfrente queda un arco de humo blanco como la estela del machete, que sigue a la mano y suelta nubes de humo; toda lombriz que barre muere al instante, hasta 3.3 m enfrente (75° a cada lado), y quema las que traes pegadas. No deja nada en el piso (JJ, 2026-11-09; antes era una bolsa que dejaba un círculo de 1.5 m por 12 s). ✅ `resources/productos/sal.tres`, en la tiendita | $25 💡 | 🧱 por ahora la bolsa de Takis teñida de blanco |
| **Paloma (cohete)** | — | Aturde a los enemigos cercanos | 💡 | ❌ (el modelo bajado salía mal) |
| **Bocina con banda** | — | Atrae a todos los zombis cercanos; luego explota (o no) | 💡 | 🧱 `models/objetos/bocina/` |
| **Chancla** | *"La de tu jefa nunca falla."* | Aturde a uno; se recoge de nuevo | 💡 | 🧱 `models/objetos/chancla/` |

---

## 4. Materiales y crafteo

- **Alcohol del 96** (*"Para curaciones, dice la etiqueta."*): ya no hace molotov (la gasolina de la gasolinera la reemplazó). ✅ `resources/productos/alcohol.tres`, en la licorería, $40 💡.
- **Diente de la Madre** (*"Un colmillo de la Madre del Cárcamo, todavía tibio."*): trofeo de matar a la Madre del Cárcamo. ✅ `resources/productos/diente_madre.tres`. ❓ Quién lo compra y a cuánto.

| Objeto | Descripción | Efecto | Precio | Modelo |
|---|---|---|---|---|
| **Cinta canela** | *"Si no lo arregla la cinta, no tiene arreglo."* | Repara y mejora armas | 25 | 🧱 `models/objetos/cinta/` |
| **Tablas** | *"Para atrancar puertas y ventanas."* | Barricadas y reparación del tinaco | 35 | 🧱 `models/objetos/tablas/` |
| **Cloralex** | *"Cloro para todo."* | Agua sucia + Cloralex = agua limpia | 30 | 🧱 `models/objetos/cloralex/` |
| **Agua sucia** | — | Material; se junta de charcos o de la llave | — | ❌ |
| **Tequila / mezcal** | — | Combustible alternativo para molotov | — | ❌ |
| **Caguama vacía** | — | Botella para molotov | — | 🧱 |

**Recetas:**

- **Molotov** = botella vacía (de caguama o refresco) + **gasolina** (la gasolinera te llena la botella: **limón** $30 o **cereza** $40, la de cereza quema 1.5 veces más lejos) + **trapo** (ferretería, $10). Gasolinera: el despachador (un civil al azar) junto a una bomba; su flecha amarilla cambia el ángulo y te enseña los precios.
- **Machete reforzado** = machete + cinta canela.
- **Agua limpia** = agua sucia + Cloralex (es delito; el Decreto 47 lo prohíbe).

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
