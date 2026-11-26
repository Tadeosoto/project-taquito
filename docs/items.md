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
| **Jarritos** | *"De tamarindo, medio tibio."* | Recupera vida (25, igual que la caguama) | 20 | 🧱 `models/objetos/jarritos/` |
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
| **La Tinaquera** 💡 (propuesta de AG, 2026-11-11) | *"Escopeta de corredera con boca de trabuco. Trae su estampita de la Virgen del Tinaco, por si las dudas."* | Escopeta: 8 perdigones por tiro, de cerca; empuja y aturde, recarga cartucho por cartucho. Se compra en el mercado ilegal de la mafia (S7) | 900 | 🧱 `models/armas/la_tinaquera/` |
| **La Matraca** 💡 (propuesta de AG) | *"Suena como matraca de feria y no deja dormir a nadie. La herradura es contra las turbas."* | Ametralladora automática, cinta de 100, **mucho ruido**; gira antes de tirar, se calienta y pesa (no corres ni ruedas). Mercado ilegal (S7) | 2500 | 🧱 `models/armas/la_matraca/` |
| **La Chicharra** 💡 (propuesta de AG) | *"Chiquita, rosa y escandalosa. Cuando empieza no hay quien la calle."* | Subfusil automático, cargador de 30; desde la cadera rocía, apuntando junta. Mercado ilegal (S7) | 1200 | 🧱 `models/armas/la_chicharra/` |
| **Ballesta** | — | Silenciosa; se recuperan las flechas | 💡 | 🧱 `models/armas/ballesta/` |
| **Resortera** | — | Silenciosa; piedras infinitas pero débil | 💡 | 🧱 `models/armas/resortera/` |

---

## 3. Munición y arrojables

| Objeto | Descripción | Efecto | Precio | Modelo |
|---|---|---|---|---|
| **Balas** | — | Para pistola (¿y cuerno?); apilables | 💡 | 🧱 `models/armas/balas/` |
| **Bomba molotov** | *"Botella con gasolina de limón y un trapo. No es para tomar."* (la de cereza: *"Más brava que la de limón."*) | Fuego en área de 2 m por 5 s (de cereza, 3 m); mata al instante a toda lombriz que toca el fuego y los sacos de la Madre del Cárcamo; te quema si te metes. Se avienta con la tecla 3 (`Lanzador`): dejas apretado el clic y el área que va a quemar avanza en el piso hacia donde ves (de 3 a 16 m en 1.2 s); al soltar, la avientas por encima del hombro. ✅ en el juego: `resources/productos/molotov.tres`, receta botella con gasolina de limón + trapo (`resources/recetas/molotov.tres`); la de cereza (`molotov_cereza.tres`) quema 1.5 veces más lejos | Crafteo | 🧱 por ahora la caguama teñida; luego `models/objetos/botella/` + `trapo/` |
| **Bolsa de sal** (10 puñados) | *"Un kilo de sal. A las lombrices del cárcamo no les gusta nadita."* | Tecla 3 y clic: avientas un puño de sal con un barrido pesado (Sword_Heavy_A): enfrente queda un arco de humo blanco como la estela del machete, que sigue a la mano y suelta nubes de humo; toda lombriz que barre muere al instante, hasta 3.3 m enfrente (75° a cada lado), y quema las que traes pegadas. No deja nada en el piso (JJ, 2026-11-09; antes era una bolsa que dejaba un círculo de 1.5 m por 12 s). ✅ `resources/productos/sal.tres`, en la tiendita | $25 💡 | 🧱 por ahora la bolsa de Takis teñida de blanco |
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

### 4.1 El taller de La Chava 💡🧱 (propuesta de AG; `especificaciones.md` 4.13)

Los datos de verdad están en `scripts/Materiales.gd` (materiales) y `scripts/Recetas.gd` (recetas). Las recetas piden **tiliches** (materiales, que van en la cangurera) y pesos; Regateo baja los pesos.

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

Solo se hacen cosas que se equipan (amuletos y armas) y dos materiales; los remedios y las estampitas se quitaron del taller el 2026-11-25 porque eran demasiadas recetas (JJ).

| Juego (se abre con) | Materiales | Amuletos | Armas |
|---|---|---|---|
| **1** (desde el inicio) | — | Pulsera de hilo rojo (+10 vida), Cadena de fantasía (+5 % fuerza), Rodilleras (−5 % daño), Medalla de San Judas (+20 % pesos; pide 4 trofeos) | Tubo de fierro (14, empuja más) |
| **2** (3 hechas) | — | Lámpara de pilas (alumbra), Escapulario (−10 %), Pulsera de San Benito (+25 vida), Cadena gruesa (+10 % fuerza, −5 %), Coderas (−10 %, +5 % alcance) | Antorcha de thinner (10, quema), Bate con alambre de púas (17, empuja más) |
| **3** (8) | Varilla armada | Rosario de semillas (−20 % de noche), Medalla de la Virgen (más tazos raros y holo), Faja de cargador (+40 vida), Cadena de oro (+20 % fuerza) | Coa afilada (20, más alcance) |
| **4** (13) | — | Ojo de venado (−20 % de cazadores y jefe, +15 vida), Herradura (−20 % de turbas), Brazalete de cobre (arrojables, todavía sin uso), Corona de lata (de todo un poco) | Machete de cañero (24, golpe rápido) |
| **5** (16) | Varilla del 84 | Chamarra del Machetes (+30 vida, −10 %, +10 % pesos), Medalla de GelA (+30 % pesos, −5 %), Listón de la Virgen (−20 % de todo) | Marro (20 a varios a la vez, golpe lento, el tercero avienta) |
| **6** (las 28 anteriores y su plano) | — | — | Machetón del 84 (40, rápido), Lanza de varilla (30, mucho alcance), Bate con clavos de cobalto (32, empuja muchísimo) |

---

### 4.2 Rediseño por tiers ✅ (JJ, 2026-11-25; falta programarlo, el 4.1 de arriba es lo que hay en el código)

**Por qué:** eran demasiadas recetas, los materiales del inicio dejaban de servir al final y abrir los juegos contando "cosas distintas hechas" no se entendía. Ahora hay una sola regla.

**Lo que equipas:** un arma, una armadura, unas botas y dos amuletos.

**Materiales:** cuatro familias, una por espacio, en tres niveles. Se van Cable, Lumbre, Agua y Vela; entran Hule y la de los amuletos. La **Tela** es el tilich; el **Trapo** sigue siendo el objeto de la ferretería para el molotov (JJ, 2026-11-25).

| Espacio | Suelto | Bueno | Fino |
|---|---|---|---|
| Arma (metal) | Lata | Varilla | Cobalto 84 |
| Armadura | Hilacha | Tela | Cuero |
| Botas | Liga | Hule | Llanta |
| Amuletos | Frijol rojo | Obsidiana | Cuarzo |

- Especial que queda: **Plata de Taxco** (se compra en el punto). Se quitan la varilla corta, el alambrón, la varilla armada, la Varilla del 84, la baba verde y el polvo de Serenol.
- **Cobalto 84** es el drop del final: cae como los demás finos (y sale del cambalache); el zombi de cobalto (la variante que brilla en las obras negras) se quita.
- **Cambalache de La Chava:** 3 sueltos = 1 bueno y 3 buenos = 1 fino de la misma familia. Así lo del inicio sirve hasta el final.
- **Cómo caen (todo por cambalache):** el botín no cambia en todo el juego. Cada zombi suelta un material el 75 % de las veces, de una familia al azar: **90 % suelto, 9 % bueno, 1 % fino**. Lo bueno y lo fino se arman con el cambalache; el 1 % de fino directo es la sorpresa (un Cobalto 84 la primera noche).
  - Los **cazadores** sueltan 2 materiales en vez de 1. El **Ojo de venado** pasa 10 puntos de suelto a bueno (80 / 19 / 1).
  - El cambalache convierte **todo lo que alcance de un jalón**, no de 3 en 3.
  - La chatarra de los postes sigue dando de 2 a 4 sueltos.
  - Costo, en sueltos: una línea de I a IV ~123 (6 + 18 + 54 + 45); arma, armadura y botas ~370; los 8 amuletos ~250; todo ~620, unos 800 zombis. Medirlo jugando (`docs/pruebas-balance.md`).

**Fórmula de las recetas:** mucho de la familia de la pieza (principal) y un poco de otra (secundaria, la del mango, la hebilla o el hilo).

| Tier | Principal | Secundaria | Además | $ |
|---|---|---|---|---|
| I | 4 sueltos | 2 sueltos | — | 30 |
| II | 4 buenos | 2 buenos | la pieza I | 80 |
| III | 4 finos | 2 finos | la pieza II + 1 Plata de Taxco | 150 |
| IV | 3 finos | 2 finos | la pieza III + su trofeo | 300 |

- El tier anterior es la llave del siguiente: no hay juegos, umbrales ni planos.
- Los amuletos no se mejoran: cada uno se hace solo, con la fórmula de su tier sin la pieza anterior.

**Armas** (principal: metal). Números para afinar; el machete de hoy hace 12.

| Tier | Filo (rápido) | Secundaria | Pesadas (empujan, lentas) | Secundaria |
|---|---|---|---|---|
| I | Machete oxidado: 10 | Tela | Tubo: 12, empuja | Hule |
| II | Machete reforzado: 16 | Hule | Marro: 16, en área, muy lento (JJ: primero el tubo, luego el marro) | Tela |
| III | Machete de cañero: 22, más rápido | Tela | Bate con clavos: 22, empuja más | Hule |
| IV | Machetón del 84: 32, rápido, más alcance | Cuarzo + Escama de la Madre | Fémur de Mojiganga con púas de cobalto: 32, empuja muchísimo, el cargado tumba a todos alrededor | Cuarzo + Corona de flores |

**Armadura** (principal: tela):

| Tier | Pieza | Secundaria | Buff |
|---|---|---|---|
| I | Coderas y rodilleras | Hule | +10 vida, −5 % daño |
| II | Faja de cargador | Metal | +25 vida, −10 % daño |
| III | Chaleco de llanta | Hule | +40 vida, −15 % daño, al bloquear te arrastran 30 % menos |
| IV | Chamarra del Machetes | Metal + Tapa del tinaco | +80 vida, −25 % daño |

**Botas** (principal: hule):

| Tier | Pieza | Secundaria | Buff |
|---|---|---|---|
| I | Tenis de tianguis | Tela | +5 % velocidad |
| II | Botas de obra | Tela | +10 % velocidad, ruedas más seguido (0.3 s en vez de 0.4) |
| III | Botas de casquillo | Metal | +10 % velocidad, cada especial gasta 1/4 de aguante en vez de 1/3 |
| IV | Botas del 84 | Metal + Ojo de turba | +15 % velocidad, especiales a 1/4, la roda esquiva más tiempo |

**Amuletos** (principal: frijol rojo, obsidiana o cuarzo según el tier). Los zombis solo salen de noche, así que no hay efectos "de noche".

| Tier | Amuleto | Secundaria | Efecto |
|---|---|---|---|
| I | Escapulario | Tela | −10 % daño |
| I | Ojo de venado | Tela | Mejores drops: +10 % de que un zombi suelte un material bueno |
| II | Collar de obsidiana | Tela | Cada zombi que matas te cura 2 |
| II | Medalla de la Virgen | Metal | Más tazos raros y holo |
| III | Medalla de San Judas | Metal | +20 % pesos |
| III | Pulsera de San Benito | Tela | +25 vida y regeneras de a poco fuera de pelea |
| IV | Listón de la Virgen | Tela + Marca de cazador | Curarte (Q) cura 50 % más y tarda la mitad |
| IV | Collar de la Santa Muerte | Metal + Casco de GelA | Si caes, te levantas con 30 % de vida una vez por noche (sin lore: solo amuleto) |

**Trofeos que quedan:** Marca de cazador, Ojo de turba, Tapa del tinaco, Diente del jefe, Chancla de oro y Casco de GelA (la Ceniza se quita), más dos de jefe (JJ, 2026-11-25): la **Escama de la Madre** (una placa del lomo de la Madre del Cárcamo; reemplaza al Diente de la Madre de `diente_madre.tres`) y la **Corona de flores** (de la Mojiganga, al vencerla). Chancla de oro y Diente del jefe ya no los pide ninguna receta.

**Lo que se va:** la combinación machete + cinta (el machete reforzado pasa al taller), la Lámpara, las cadenas, la Herradura, el Brazalete de cobre, la Corona de lata, el Rosario, la Medalla de GelA, el Ojo de venado viejo, la Lanza de varilla, la Coa, la Antorcha y los planos, el trofeo Ceniza y el zombi de cobalto.

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

### Drops raros (S5, 2026-11-13) ⏸️ lista por llenar

✅ **Dónde:** 36 escondites fijos en `map_test` (`resources/map/escondites.json`: atrás de bodegas y en callejones; 24 en las orillas del mapa y 12 dentro del cuadro del contenido; nunca en las fortalezas). **No hay drop en todos:** cada amanecer se sortean 6 y solo esos tienen algo; lo que recoges ya no sale hasta el siguiente sorteo. No salen en los mapas.

⏸️ **Qué sale: pendiente (JJ).** Mientras la lista esté vacía sale **"Algo raro"**, un paquete morado de relleno (`resources/drops_raros/pendiente.tres`). Para agregar uno: su `.tres` en `resources/` y su ruta en `DropsRaros.LISTA`.

| Drop | Qué es | Qué tan raro | `.tres` |
|---|---|---|---|
| _(por llenar)_ | | | |

💡 Ideas que ya están en los docs: el **papel raro** (§6, recibos y hojas del lore), un **tazo raro**, piezas del taller.

### Equipo escondido en el mapa 💡 (lista tentativa, 2026-11-26; JJ la va a trabajar en otra sesión)

Viene de la maqueta de la pantalla de **Equipo**: filas por tipo (Filo, Pesadas, De fuego ×2, Armadura, Botas, Amuletos ×2), columnas de tier I-IV y **dos columnas ★ por fila** para lo que se encuentra en el mapa (16 en total; salen como "?" hasta encontrarlos y caen en la fila de su tipo). Te equipas **dos amuletos** (seis puestos: arma, de fuego, armadura, botas, amuleto 1 y 2). A diferencia de los drops raros de arriba, cada uno es único y tiene su lugar fijo. **Nada es canon:** nombres, efectos y lugares son propuestas; falta revisar choques con el lore (sobre todo el Llavero del Voto con "El voto de la llave" de `lore.md` §5, y la Pistolita de agua bendita con que el agua es ilegal, §10).

| Fila | Nombre | Idea | Dónde |
|---|---|---|---|
| Filo | **El Cebollero** | Cuchillo de taquero, corto y rapidísimo | Una taquería cerrada |
| Filo | **Machete del Velador** | El de Martín, con el mango gastado de tantas rondas | El Mante Tieso |
| Pesadas | **La Stillson de Elena** | Llave de tubo de la drenajera; pesa como marro | Parques del Mosco, en las cañerías |
| Pesadas | **La Coa del Jardinero** | La de Arturo; barre a los que tienes enfrente | Haciendas de San Jodido |
| De fuego | **La Resortera de Tito** | Con canicas en vez de piedras | Parques del Mosco |
| De fuego | **La Hechiza** | Escopeta de tubo armada a mano; truena feo | Las cañerías |
| De fuego | **El Castillo** | Lanzacohetes hecho con un castillo de feria | El templo de Santa Mugre |
| De fuego | **La Pistolita de agua bendita** | Pistola de agua del padre Chuy; aturde zombis (y el agua es ilegal: te puede meter en broncas) | La capilla |
| Armadura | **Chaleco del Coto** | El de Sergio, el guardia de la fortaleza GelA | Fortaleza GelA |
| Armadura | **La Sotana del Padre Chuy** | Tela gruesa con estampitas cosidas por dentro | El templo |
| Botas | **Huaraches de llanta** | Ligeros, para correr | El tianguis de Toño |
| Botas | **Botas del Garrafonero** | Las de Nacho; aguantan cargando | La purificadora |
| Amuleto | **Rosario de tapitas** | Hecho por Doña Rosa con tapas de garrafón | Santa Mugre |
| Amuleto | **La Ficha del Sótano** | Una ficha de EL GORDO que nunca pierde | El Sótano (La Gotera) |
| Amuleto | **El Destapador de Don Silverio** | El de la cantina, colgado de un cordón | El Último Trago |
| Amuleto | **Llavero del Voto** | Una copia de la llave, de cuando se votaba con ella | La Florida Marchita |

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
| Jarritos | 20 | pesos | +25 vida | — | — | — |
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

## Kilo de tortillas (propuesta de AG, 2026-11-11)

Se compra en la Tortilleria La Lupita de Santa Mugre ($22). Cura poco (15) y se apila: la curacion barata del barrio. Archivo: `resources/productos/tortillas.tres`.

## Costal de chiles (objeto de mision)

No se vende: es lo que se recoge en el tianguis para la mision "Chiles para el mercado". Archivo: `resources/productos/costal_chiles.tres`.

