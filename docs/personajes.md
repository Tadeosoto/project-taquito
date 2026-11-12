# Guadalajaja — Personajes

> Quién es quién en la ciudad: los que te venden, los que te usan y los que te esconden algo. Documento hermano de [`docs/lore.md`](lore.md) (el mundo) y [`docs/especificaciones.md`](especificaciones.md) (las mecánicas).
>
> Última actualización: 2026-11-12 (bloque L7 del megaplan "Noches de fuera": Gerardo rebelde, Chuy calla, sin Doña Refugio, Chava y Nacho en el gremio, Nemesio protector, policías sin cara)

## Cómo usar este documento

Cada personaje lleva etiqueta, igual que en la spec:

| Etiqueta | Significa |
|---|---|
| ✅ **Canon** | Ya está decidido; no se cambia sin hablarlo con el equipo. |
| 💡 **Propuesta** | Se puede cambiar, cortar o fusionar. |
| ❓ **Abierto** | Falta decidir; está en [Preguntas abiertas](#11-preguntas-abiertas). |

**La regla de todo personaje:** cada uno tiene **un querer, un secreto y un precio**.

- **Quiere** algo (agua, dinero, que su hijo no se muera y se levante, quedarse en el poder).
- **Esconde** algo (el filtro, la firma, el miedo, el nombre del que lo compró).
- **Cuesta** algo (si te ayuda, algo te cobra: dinero, agua, un favor, un silencio).

Si un personaje no tiene las tres, no es personaje: es decorado. Y el decorado se hace con habitantes sin diálogo, no con voces.

### Los tres niveles

| Nivel | Qué es | Cuántos | Cómo se reconoce |
|---|---|---|---|
| **Voz** | Personaje con nombre, historia, horario y conversación | 30 | "Espacio: hablar" |
| **Vendedor** | Un arquetipo por giro, reusado en todas las franquicias | 10 arquetipos, 110 tiendas | Te atiende en la tienda |
| **Habitante** | Gente de la calle, con rutina y barks | 20-30 a la vez | Burbuja al pasar, sin conversación |

### La regla de las tres preguntas

Para decidir si alguien es **voz** o **habitante**:

1. ¿Te da algo? (compra, misión, llave, agua) → **voz**.
2. ¿Te enseña algo? (lore, pista, precio, peligro) → **voz**.
3. ¿Te cambia el día? (horario, facción, riesgo, ruta) → **voz**.

Si no cumple ninguna: **habitante**. Y si solo llena la calle de lejos: **silueta** (sin diálogo, sin lógica, MultiMesh).

### El reparto en números

- **30 voces** (2 por zona + 9 de facción + 3 de historia).
- **10 vendedores** (abarrotes, taquería, ferretería, farmacia, licorería, purificadora, OXXO, gasolinera, puesto, punto).
- **20-30 habitantes** a la vez, más siluetas lejanas.
- **~600 líneas** de texto en total.

> El porqué de estos números está en [El reparto en números](#9-el-reparto-en-números).

### Índice

- [1. El protagonista](#1-el-protagonista)
- [2. La casa Lazcano](#2-la-casa-lazcano)
- [3. La cuadrilla](#3-la-cuadrilla)
- [4. El culto](#4-el-culto)
- [5. Las nueve zonas](#5-las-nueve-zonas)
- [6. Las facciones](#6-las-facciones)
- [7. Los vendedores](#7-los-vendedores)
- [8. Las leyendas](#8-las-leyendas)
- [9. El reparto en números](#9-el-reparto-en-números)
- [10. Cómo se implementan](#10-cómo-se-implementan)
- [11. Preguntas abiertas](#11-preguntas-abiertas)

---

## 1. El protagonista

### El Nocturno

| | |
|---|---|
| **Quién** | El jugador. Avatar silencioso, sin nombre fijo. |
| **Oficio** | Cazarecompensas de la noche y contrabandista por necesidad: toma contratos que nadie quiere. |
| **Quiere** | Vivir un día más sin volverse uno de los que salen de noche. |
| **Esconde** | Nada fijo: no tiene historia, así que lo que calla lo pone el jugador. |
| **Precio** | Su lista de contratos, su machete, su lugar en la cuadrilla. |

**Historia.** No hay una: cada jugador la pone. El mundo solo le da tres cosas: **una lista de contratos** (vela, recolección, reparto, cacería), **un lugar en la cuadrilla** (deudas, favores) y **un machete**. No es inmune, no es el elegido: es **el que sale cuando ya no anda nadie**, y eso también lo vuelve culpable.

**Rol en el juego.** Es el cuerpo del jugador y el único que no habla. El barrio lo llama **"el Nocturno"**; los NPCs le hablan a él, no a un nombre. Su arco no es "salvar la ciudad": es **decidir qué hace con lo que sabe**, y si sigue tomando contratos o se mete a cambiarlo.

**La tentación.** Puede tomar agua de la llave para ahorrar. Le sale gratis, le quita la sed del momento y le sube la "sed" de verdad: de día se vuelve más dócil (le fían, le creen, le bajan precios) y, si se llena, **se muere y se levanta**. Es la decisión central: **ahorrar agua o ahorrarte el monstruo**.


## 2. La casa Lazcano

La familia que tiene el agua y el gobierno. No son monstruos de caricatura: son gente que descubrió que el agua **no se puede dejar de comprar** y construyó un país alrededor de eso.

### Germán Lazcano

| | |
|---|---|
| **Zona** | La fortaleza GelA (vive), El Mante Tieso (la planta vieja) |
| **Horario** | Día; de noche no sale |
| **Oficio** | Fundador de GelA; dueño del agua |
| **Te da** | Nada directo: sale en spots, en el periódico y en la radio |
| **Quiere** | Que la empresa dure cien años y que su hija la herede entera (y que su hijo menor lo quiera, ver Gerardo) |
| **Teme** | Que el secreto del Serenol salga a la luz, no por moral, sino porque lo obligaría a regalar el agua |
| **Secreto** | Sabe perfectamente qué le hace el agua a la gente |
| **Precio** | Un favor político, una firma, un silencio |

**Historia.** Setenta y tantos, guayabera, sombrero de palma para las fotos, uñas limpias de tanto lavarse las manos. Empezó llenando garrafones en una purificadora de la colonia y le puso a la marca las iniciales de su apellido: **GelA**. De ahí a las franquicias **Puri-GelA**, los refrescos **GelA-Cola** y las farmacias **FarmagelA**. No es un genio del mal: es un comerciante que entendió que el agua es el único producto que no se puede dejar de comprar, y que la gente con sed es gente agradecida.

**Rol en el juego.** Es el **origen** de todo y el **techo** del poder. No es un enemigo al que le pegas: es una firma, un spot, una voz en la radio. Aparece en la revelación (el manifiesto, el expediente) y en el final, cuando hay que decidir si se le puede tocar. 💡 Tiene un detalle humano que lo vuelve peor: **regala agua en los funerales**. Le gusta que lo quieran.

### Georgina "Gela" Lazcano

| | |
|---|---|
| **Zona** | Palacio (afuera, cerca de la plaza de la Catrina) y la fortaleza GelA (donde vive) |
| **Horario** | Día; de noche manda, no sale |
| **Oficio** | Gobernadora; la cara de GelA |
| **Te da** | Nada: te quita (el agua, el voto, la calle) |
| **Quiere** | Quedarse. La Reforma Hídrica le permite reelegirse sin límite |
| **Teme** | La capilla del tinaco: es lo único que le quita el agua a la gente sin cobrarle |
| **Secreto** | Sabe que su agua vuelve dóciles a los que no pagan y levanta a uno de cada diez; lo usa como excusa |
| **Precio** | No hay precio: no se compra, se negocia con ella desde el poder |

**Historia.** Cuarenta y pocos, traje claro, sonrisa de campaña, el pelo siempre perfecto. Es la hija de Germán y la cara de la empresa **y** la gobernadora. Su padre construyó el agua; ella construyó el estado que la protege. Ganó con el **voto de la llave**: el electorado infectado es agradecido y dócil, y al que no vota le falta el agua. No hace falta hacer trampa: la dependencia ya es la trampa.

**Rol en el juego.** Es la **antagonista visible**: la que sale en la tele, la que firma el Decreto 47, la que manda a los blancos a cerrar la capilla. No la enfrentas con un machete: la enfrentas **desmontando su historia**, y eso se hace con papeles, testigos y agua. 💡 Cuando la ciudad se le pone difícil, **corta el agua a todos** y el gobierno federal queda como el malo; ella queda como la única que puede resolverlo.

✅ **Cómo responde al jugador** (con Buenrostro como su mano; ver [`docs/revision-historia.md`](revision-historia.md) §2.2). El régimen no persigue: **sube un escalón** cada vez que el jugador mueve agua limpia o verdad.

| El jugador… | El régimen… |
|---|---|
| Reparte agua, ayuda a la capilla | Spots nuevos de la Gota; el noticiero habla de "agua contaminada del mercado negro" |
| Hace que la capilla cure a más gente | Los blancos la clausuran una noche; Nava pide nombres |
| Organiza la zona (Lalo, la marcha) | Corte de agua a la colonia entera; "fue una falla" |
| Junta pruebas | **Buenrostro le ofrece un contrato**: el mejor pagado del juego, para "arreglar" justo lo que está destapando |

Lo último es la mejor escena del antagonista: el régimen no te caza, **te contrata**.

### Gerardo Lazcano

| | |
|---|---|
| **Zona** | La fortaleza GelA (los Reservorios): siempre ha vivido ahí, en el coto de los Lazcano |
| **Horario** | Día (el heredero modelo, se deja ver); noche (la resistencia) |
| **Oficio** | El hijo menor de Germán, **medio hermano de Georgina**, veintidós; el **hijo rebelde** de GelA |
| **Te da** | Información de la fortaleza, acceso a los Reservorios y a la fábrica, una firma que no debería tener |
| **Quiere** | Tirar la fortaleza desde adentro: abrir el agua limpia para todos |
| **Teme** | Que su padre abra los ojos y tenga que elegir; que Georgina lo descubra |
| **Secreto** | ✅ **Ya sabe lo del Serenol** (lo supo hace poco) y filtra a la resistencia. 💡 Todavía no sabe lo de "Contención" (los conteos de los que no vuelven), y firmó sin leer algo que sirvió para la fábrica o los Reservorios |
| **Precio** | Que no lo expongas, y la verdad sobre su familia |

**Historia.** Creció dentro de los muros, estudió fuera, volvió con ideas y, hace poco, entendió **qué lleva el agua y por qué todos en la fortaleza lo callan**. Es el hijo tardío de Germán y el único Lazcano que no le debe nada a la llave. De cara a la fortaleza es el **heredero modelo**: sale en las fotos, firma lo que le ponen delante y Georgina lo cree manejable. En secreto **filtra** lo que ve a la resistencia, y duda: acaba de descubrir que su familia hizo esto y todavía no sabe cuánto está dispuesto a perder.

**Germán se hace el ciego.** ✅ Su padre sospecha de la doble cara de su hijo y **prefiere no ver**: es el único de la familia que lo quiere sin deberle agua. Es una palanca: si alguien (Georgina, o el jugador por un error) lo obliga a mirar, Germán tiene que elegir entre su hijo y su imperio.

**Rol en el juego.** Es el **contacto de alto riesgo** de la resistencia y el espejo de la revelación: lo que le cuentas le cambia la cara. ✅ **Riesgo del jugador:** cada misión que haces para él puede delatarlo. 💡 Sigue abierto si termina aliado (si lo cuidas), víctima (si Georgina lo descubre) o enemigo (si elige a la familia). No es un jefe: es una **decisión**.

**Cómo llegas a él.** ✅ No entras por Gerardo: entras a la fortaleza **contratado como guardia**, porque se les metieron zombis y los ricos necesitan músculo. **Arturo**, el jardinero, te recluta por debajo y, cuando confía, te lleva a Gerardo.

### Lic. Saúl Buenrostro

| | |
|---|---|
| **Zona** | Vive en la fortaleza GelA; despacha en el palacio (afuera) y el "Centro de Innovación Hídrica" |
| **Horario** | Día y noche (no duerme, no tiene por qué) |
| **Oficio** | Director de "Contención" y **jefe de la policía** (los blancos); el operador real del régimen |
| **Te da** | Contratos, acceso, la letra chica del Decreto 47 |
| **Quiere** | Orden: que la ciudad funcione como un reloj |
| **Teme** | El desorden, la prensa, los números que no cuadran |
| **Secreto** | Firma las hojas de conteo: sabe cuántos salen y cuántos no vuelven |
| **Precio** | Un trámite, un favor, una firma: todo se puede, nada es gratis |

**Historia.** Abogado de la vieja escuela, el que le pone la letra fina a las decisiones de Gela. ✅ (2026-11-12) **Manda a los blancos**, el brazo armado de Gela, y vive dentro de la fortaleza GelA, donde la resistencia lo tiene a unos pasos. No es un villano de risa: es el que **hace que el sistema funcione**. Él redactó la Ley de Convivencia Nocturna, él firma las actas de ausencia, él sabe que el agua se llama "estabilizador organoléptico". Si la gobernadora es la cara, Buenrostro es el **cerebro frío**.

**Rol en el juego.** Es el **antagonista de escritorio**: el que te da una misión para "arreglar" algo y en realidad te está usando. Es el mejor interlocutor para la revelación: si lo aprietas con papeles, suelta más de lo que quiere. 💡 Si cae él, cae la estructura; si cae Gela, la estructura sigue.

---

## 3. La cuadrilla

La **cuadrilla** es la central de contratos del barrio: reparte los mandados de la noche, cobra su parte y decide quién entra. No es una pandilla: es una **agencia**.

### Gabriel "el Patrón" Hinojosa

| | |
|---|---|
| **Zona** | ✅ (2026-11-12) **Santa Mugre** (donde está el jugador; antes, el mercado de Los Garrafones), toda la ciudad |
| **Horario** | Día y madrugada |
| **Oficio** | Líder de la cuadrilla |
| **Te da** | Contratos, pagos, contactos, la ficha |
| **Quiere** | Que la cuadrilla siga siendo la que reparte el trabajo |
| **Teme** | Que GelA lo compre (o lo mate) y que la cuadrilla se deshaga |
| **Secreto** | Le debe favores a los Gotera |
| **Precio** | Una cuota, un favor, un silencio |

**Historia.** Empezó repartiendo mandados cuando GelA todavía no era GelA. Inventó **la ficha**: un papelito con un número que dice quién pidió el trabajo, cuánto paga y qué se lleva. Sin ficha, el contrato no existe. Por eso la cuadrilla no es una pandilla: es una **agencia de trabajo**. Gabriel es el que decide quién entra, quién sale y quién cobra.

**Rol en el juego.** Es el **jefe del jugador**: le da los contratos y las fichas. También es el que puede **quitarle la ficha** (y con eso, el trabajo). 💡 Su debilidad es el pacto con los Gotera: si el jugador la descubre, puede usarla o chantajearlo.

### Beto Ríos

| | |
|---|---|
| **Zona** | Los Garrafones / la colonia del jugador |
| **Horario** | Día (duerme); noche (sale a los contratos) |
| **Oficio** | Novato de la cuadrilla, diecinueve años |
| **Te da** | Su ayuda, su entusiasmo, su ruta |
| **Quiere** | Ser como tú: tener contratos, tener respeto |
| **Teme** | Que lo vean "pandillero", que lo agarre la caminata |
| **Secreto** | A veces toma agua de la llave porque no le alcanza |
| **Precio** | Nada: es el único que te da sin cobrar... hasta que no puede |

**Historia.** Es el vecino que te ve salir con el machete y te dice "enséñame". Tiene diecinueve, una mochila rota y una mamá que le dice que no salga de noche. Es el **espejo del jugador**: mismo oficio, menos suerte. Y es el que está en riesgo: si toma mucha agua de la llave, **se muere y se levanta**.

**Rol en el juego.** Es el **tutorial humano**: te enseña los contratos, la ficha y el precio. Y es la **consecuencia moral**: si lo descuidas, lo pierdes; si lo cuidas, te saca de un apuro. 💡 Puede morirse y levantarse, y el jugador puede encontrarlo de noche sin saber que es él.

### Nacho Garrafón — el chofer

| | |
|---|---|
| **Zona** | La Palmada (el pozo de Chava) y la ruta de reparto |
| **Horario** | Noche (el reparto); de día duerme |
| **Oficio** | Chofer de la camioneta del gremio, cincuenta y tantos |
| **Te da** | El viaje: maneja la camioneta que defiendes en cada reparto |
| **Quiere** | Terminar el reparto y volver a casa con sus hijas |
| **Teme** | Quedarse parado: la camioneta quieta de noche |
| **Secreto** | Fue chofer de reparto de GelA, de los que llevaban el agua con Serenol. Sabe cuántas colonias la recibieron y no se lo ha dicho a nadie, ni a Chava |
| **Precio** | Que no lo dejes solo con la camioneta |

**Historia.** 💡 (nombre propuesto, 2026-11-12) Ignacio "Nacho" Garrafón, bigote, gorra de la purificadora de su barrio, manos grandes de cargar garrafones. Maneja con una cumbia bajita y habla poco, casi nada si hay zombis. Es de los que **nunca se quedan a pelear**: tiene hijas.

**Rol en el juego.** Compañero fijo de las misiones de **defender la camioneta**: si él cae, la misión falla. Es el personaje al que el jugador teme perder en una escolta. Su secreto da pie a una misión suya más adelante (L9/L10).


## 4. El culto

La fe del barrio. No es una religión organizada: es un tinaco manchado, una señora que reza y un cura que filtra agua a escondidas.

### Padre Jesús "Chuy" Arreola

| | |
|---|---|
| **Zona** | Parques de Santa Mugre (el templo; antes, la capilla de Los Garrafones) |
| **Horario** | Madrugada (4-7) y misa de 7; de noche no abre |
| **Oficio** | Cura de barrio; administra el pozo bajo el templo |
| **Te da** | Agua limpia (con cupo), techo, la misión del filtro |
| **Quiere** | Que su gente no se muera y que nadie le cierre el templo |
| **Teme** | Que la diócesis venda el filtro, que GelA lo clausure o que alguien le diga qué le quita el agua a la gente |
| **Secreto** | Él filtra el agua: no hay milagro. ✅ **Sospecha que el agua les quita *algo*** (quien la toma no se "apaga") y **lo calla**: el culto y su gente dependen de que el milagro siga siendo milagro |
| **Precio** | Que no le digas a nadie, y que le lleves tu agua sucia |

**Historia.** Cincuenta y tantos, flaco, con una camisa que fue blanca. Vio a su gente apagarse (dormir mal, no quejarse de nada, morirse) y encontró la única forma que tenía de ayudar: un **filtro Puri-GelA robado** escondido debajo del altar. Cada madrugada saca agua del pozo del cuarto subterráneo, la filtra y la reparte "bendita". Lleva dos años así. No dice que hace milagros: deja que la gente lo crea, porque la fe sostiene más que la verdad. Cuida el pozo **solo**: nadie más baja.

**Rol en el juego.** Es la **fuente de agua gratis** (con cupo) y el **mejor punto de lore**: sabe del filtro, del delito y de la gente. ✅ **Nunca habla.** Nadie le saca lo que sospecha: su silencio es su pecado, y el jugador decide si lo **delata** o lo **deja**. Si GelA lo cierra, la ciudad pierde la única cura gratuita.

### Doña Rosa "la del tinaco"

| | |
|---|---|
| **Zona** | Parques de Santa Mugre (la plaza, junto al tinaco manchado) |
| **Horario** | Día y madrugada |
| **Oficio** | La primera creyente; la dueña de la casa donde amaneció la mancha |
| **Te da** | La historia del milagro, la llave del patio, el rezo |
| **Quiere** | Que el milagro sea verdad |
| **Teme** | Que alguien le diga que no lo es |
| **Secreto** | Sospecha que el cura limpia el agua, y prefiere no saberlo |
| **Precio** | Que le reces con ella, aunque no creas |

**Historia.** Es la señora de la casa donde amaneció la mancha con forma de la Virgen. Lo contó en el mercado, el barrio fue a ver y en una semana la calle estaba llena de veladoras. Su fe es real y su miedo también: si el milagro es un filtro, se le cae el mundo.

**Rol en el juego.** Es la **voz del culto** y la que sostiene la capilla cuando el cura no está. 💡 Puede ser la que delata al cura sin querer (a la diócesis o a los blancos) si la presionan.

### Karla — la beata

| | |
|---|---|
| **Zona** | Parques de Santa Mugre y las peregrinaciones |
| **Horario** | Día y noche (la vigilia) |
| **Oficio** | La mano derecha de la capilla |
| **Te da** | Información, veladoras benditas, la lista de los que ayudan |
| **Quiere** | Que la capilla crezca y que GelA pague |
| **Teme** | Que la fe se vuelva negocio... o que no |
| **Secreto** | Es los ojos del obispo: le pasa las cuentas de la capilla y la lista de los que ayudan |
| **Precio** | Una limosna, una vela, un chisme |

**Historia.** La que organiza la vigilia, la que consigue la cera, la que conoce a todos. Es devota de verdad, pero también es la que descubrió que la fe puede dar de comer. No es mala: es **lista**.

**Rol en el juego.** Es la **administradora del culto**: te da la información de quién entra y quién sale. ✅ Su doble juego con el obispo es la pista de que la diócesis quiere el filtro: por Karla, Marín sabe más de lo que debería.

### Obispo Marín

| | |
|---|---|
| **Zona** | La catedral (fuera del mapa jugable) y la capilla |
| **Horario** | Día (visitas) |
| **Oficio** | Obispo de la diócesis |
| **Te da** | Nada: te pide |
| **Quiere** | Una parte del milagro: donativos, control, imagen |
| **Teme** | Que el escándalo lo salpique |
| **Secreto** | Quiere vender el filtro (o el "milagro") a GelA |
| **Precio** | Un donativo, una firma, una foto |

**Historia.** Llega en camioneta buena, bendice, sonríe y pide cuentas, que ya le pasó Karla. No cree en el milagro, pero cree en el negocio. Es el puente entre la fe del barrio y el poder de la gobernadora.

**Rol en el juego.** Es el **antagonista de la capilla**: si el jugador no lo frena, la diócesis se queda con el filtro y la cura se vuelve negocio.

---

## 5. Las nueve zonas

Dos voces por zona: una de día y una de noche. Los Garrafones ya tiene a los suyos en [El culto](#4-el-culto): el padre Chuy y doña Rosa.

### El Mante Tieso

#### Armando — el obrero del turno

| | |
|---|---|
| **Horario** | Día (turno de 6 a 6) |
| **Te da** | La ruta de la planta, lo que se ve adentro, agua para su familia |
| **Quiere** | Que su hijo no entre a la planta |
| **Teme** | Que lo corran (o algo peor) |
| **Secreto** | Vio los tambos con la etiqueta G-7 |
| **Precio** | Agua limpia para su casa |

**Historia.** Lleva quince años cargando trailer en la bodega. Conoce la planta vieja como su casa: los tanques, las básculas, el cuarto donde entran los tambos sin etiqueta. No es un héroe: es un padre que no quiere que su hijo termine igual.

**Rol.** Es la **primera pista** de que el agua se "arregla" en la planta. Te da el mapa y la misión de entrar de noche a ver los tanques.

#### Martín — el velador

| | |
|---|---|
| **Horario** | Noche (6 a 6) |
| **Te da** | Acceso a la planta de noche, planos, silencio |
| **Quiere** | Compañía y una radio que sirva |
| **Teme** | La noche: dice que "los que salen" lo conocen |
| **Secreto** | Deja pasar a los de la cuadrilla por una cuota |
| **Precio** | Una cerveza, un cigarro, una plática |

**Historia.** Sesenta y tantos, solo, con una silla de plástico y un radio que solo da estática. Ve las camionetas de GelA salir al amanecer y nunca pregunta. Sabe más de lo que dice, pero no quiere saber.

**Rol.** Es la **puerta de la planta** y el que te enseña la frase del régimen: *"no los matamos: los dejamos salir"* (la oficial es "los guardamos"; la suya es la de verdad, ver lore §5). Si lo cuidas, te abre la bodega; si lo asustas, te cierra la ciudad.

### La Florida Marchita

#### Marisol — la maestra

| | |
|---|---|
| **Horario** | Día (escuela) |
| **Te da** | La lista de los que "no despertaron", la llave de la cisterna |
| **Quiere** | Que la escuela tenga agua y que los niños no se pierdan |
| **Teme** | Que uno de sus alumnos se muera y se levante |
| **Secreto** | Tiene a un sobrino amarrado en su casa |
| **Precio** | Libros, agua, una mano con los papás |

**Historia.** Treinta y tantos, la maestra de la primaria con la cisterna vacía. Se acuerda del nombre de cada niño que dejó de venir. Lleva una lista en el cajón: los que se "pusieron raros", los que ya no juegan, los que no duermen.

**Rol.** Es la **conciencia de la zona**: te enseña que los zombis son los niños. Su lista es una pista de la revelación (los nombres coinciden con los de la hoja de conteo).

#### Lalo — el papá del comité

| | |
|---|---|
| **Horario** | Día y tarde |
| **Te da** | La marcha, el grupo de vecinos, la bronca |
| **Quiere** | Hacer una manifestación que sirva |
| **Teme** | Que le corten el agua otra vez |
| **Secreto** | Su hijo toma de la llave |
| **Precio** | Que lo apoyes en la marcha |

**Historia.** Cuarenta y tantos, papá de dos, organiza el comité de la escuela. Es el que dice "hay que hacer algo" en cada junta. Lo han callado dos veces con un corte de agua; la tercera no sabe si va a aguantar.

**Rol.** Es el **organizador**: te da la misión de la manifestación y te enseña el precio de protestar. Es el que puede convertir el descontento en algo, si alguien lo ayuda.

### La Palmada

> ✅ (2026-11-12) **Doña Refugio y la leyenda del "tinaco que no se vacía" se eliminan.** El pozo de los abuelos de La Palmada ya no es de una abuela: es de Chava y es **otro pozo**, fuera de las fortalezas, distinto al del templo de Santa Mugre. La gente de Santa Mugre le rinde culto a un tinaco manchado en su plaza.

#### Chava — el del pozo

| | |
|---|---|
| **Horario** | Día (el pozo, la fila) y noche (el reparto) |
| **Te da** | El agua limpia del reparto, los contratos de defender el tinaco y la camioneta, un trato |
| **Quiere** | Proteger a la gente de fuera de las fortalezas: que el agua limpia les llegue |
| **Teme** | Que GelA selle el pozo o que los Gotera se lo cobren; perder a alguien del gremio en una noche |
| **Secreto** | Ya habló con un blanco: le ofrecieron comprarle el pozo "por seguridad" y no ha dicho que no del todo |
| **Precio** | Dinero para el gremio, una noche de vela, un favor |

**Historia.** Veinte y pocos, de La Palmada, cansado de cargar cubetas desde niño. Heredó el **pozo de los abuelos**, agua viva de verdad, fuera de las fortalezas, y en vez de venderlo lo puso al servicio del gremio de reparto de agua y defensa del tinaco. Es **parte de la cuadrilla**: de su pozo sale el agua limpia que llevas de noche a la gente de fuera, y su camioneta la maneja Nacho.

**Rol.** Es la **base del reparto nocturno** y el conflicto de la zona: el pozo lo quieren GelA (para sellarlo), los Gotera (para cobrarlo) y el régimen (para clausurarlo). El jugador puede ayudarlo a defenderlo, comprarlo o dejar que lo vendan. Lo que decida cambia el agua de la gente de fuera para siempre.

### Parques de Santa Mugre

#### Toño — el tianguista

| | |
|---|---|
| **Horario** | Día (tianguis) |
| **Te da** | Información de quién es quién, objetos, encargos |
| **Quiere** | Que el tianguis siga |
| **Teme** | La policía y el palacio |
| **Secreto** | Le paga a un empleado del palacio por los papeles |
| **Precio** | Una compra, un chisme, un favor |

**Historia.** Cincuenta y tantos, puesto de fruta y de lo que caiga. Conoce a todo el barrio: quién debe, quién paga, quién se está poniendo raro. Es el **google humano** de la zona.

**Rol.** Es el **informante**: te dice dónde está cada quien y qué le puedes vender. Si lo respetas, te abre puertas; si lo estafas, te cierra el tianguis.

#### Güero — el empleado del palacio

| | |
|---|---|
| **Horario** | Día (oficina) |
| **Te da** | Copias del Decreto 47, actas, nombres |
| **Quiere** | Un ascenso o que no lo descubran |
| **Teme** | A Buenrostro |
| **Secreto** | Vende copias de los expedientes |
| **Precio** | Dinero, agua, una firma |

**Historia.** Treinta y tantos, piel muy oscura, camisa de manga larga, sello de goma. Le dicen **el Güero** precisamente por eso: en el barrio los apodos van al revés, y en la oficina es el más moreno de todos. Es el que tramita las "actas de ausencia nocturna" de las familias. Sabe exactamente cuántos desaparecen y no quiere saber más.

**Rol.** Es la **fuente de los papeles**: por él se consigue el Decreto 47, la hoja de conteo y las firmas. Es el eslabón débil de la estructura de Buenrostro.

### Parques del Mosco

#### Elena — la drenajera

| | |
|---|---|
| **Horario** | Día (cuadrillas) |
| **Te da** | Acceso al drenaje, lo que encuentra, la ruta de los zombis |
| **Quiere** | Que el drenaje no se desborde |
| **Teme** | Lo que sale del drenaje |
| **Secreto** | Encontró el expediente del cobalto (y un cuerpo con etiqueta G-7) |
| **Precio** | Botas, una linterna, agua |

**Historia.** Cuarenta y tantos, botas de hule, pala. Trabaja en las cuadrillas que destapan el drenaje. Ha encontrado de todo: animales, papeles, cuerpos. Lo que encontró el año pasado la dejó callada: un legajo con un sello viejo y un nombre.

**Rol.** Es la **puerta al drenaje** y la que tiene la pista del cobalto. Si el jugador se gana su confianza, le enseña el expediente.

#### Tito — el niño

| | |
|---|---|
| **Horario** | Día (juega en el agua) |
| **Te da** | La ruta de la caminata, avisos, un favor |
| **Quiere** | Un juguete y agua que no le haga daño |
| **Teme** | La noche |
| **Secreto** | Sabe dónde se junta la caminata |
| **Precio** | Un dulce, un garrafón, un rato de juego |

**Historia.** Diez años, descalzo, siempre mojado. Su mamá le dice que no tome de la llave, pero él toma. Es el **canario** de la zona: si Tito se pone mal, la cuadra se pone mal.

**Rol.** Es el **aviso temprano**: te dice por dónde va a salir la caminata esa noche. Si lo cuidas, te salva la vida; si no, lo pierdes.

### Haciendas de San Jodido y la fortaleza GelA

> ✅ (2026-11-11) Haciendas de San Jodido queda como colonia común de casas chicas; los Lazcano viven en la fortaleza GelA. Arturo, Sergio y la resistencia pasan a trabajar ahí.

#### Arturo — el jardinero

| | |
|---|---|
| **Horario** | Día (jardines, campos de golf); noche (la resistencia) |
| **Te da** | La entrada por el servicio, el mapa de la fortaleza, el acceso a Gerardo |
| **Quiere** | Que no lo corran y que el servicio salga vivo |
| **Teme** | A la gobernadora |
| **Secreto** | Es el puente de la resistencia: su esposa es del barrio, su hijo es amigo de Gerardo, y tiene la llave del sótano |
| **Precio** | Agua para su familia |

**Historia.** Cincuenta y tantos, poda, riega, barre. Riega el pasto de la fortaleza con agua que afuera no alcanza ni para tomar. Los ricos no lo ven, y por eso **ve todo**. Sabe lo que hay en el sótano de la casa de Villalobos y no lo dice.

**Rol.** ✅ Es el **contacto del jugador** en la resistencia. Cuando los zombis se meten a la fortaleza y los ricos te contratan de guardia, él te recluta por debajo: te abre el servicio, te deja ver cómo se vive adentro (albercas, golf, reservorios) y, cuando confía, te lleva a Gerardo. 💡 Su sótano puede esconder al "zombi del coto": el hijo de algún vecino que nadie saca a la calle.

La **resistencia** (✅ 2026-11-12) la forman **gente de servicio** (jardineros, choferes, cocineras, guardias) y **familias ricas con algún hijo arrepentido**. Los de servicio saben qué pasa, los ricos saben por qué, y **ninguno se fía del otro**: Gerardo es el puente. Estar contratado para defender los muros es la contradicción del jugador: mantiene viva la fortaleza que la resistencia quiere que caiga.

#### Sergio — el guardia del coto

| | |
|---|---|
| **Horario** | Noche (caseta) |
| **Te da** | Acceso, avisos, silencio |
| **Quiere** | Su quincena |
| **Teme** | Que lo maten por un sueldo |
| **Secreto** | Deja pasar a los de la cuadrilla por una cuota |
| **Precio** | Dinero |

**Historia.** Treinta y tantos, uniforme negro, radio. Es el que pregunta *"¿y usted qué hace aquí? ¿es de la empresa?"*. No es malo: es el que abre la pluma por doscientos pesos.

**Rol.** Es el **control de acceso** al coto: se puede sobornar, convencer o evitar. Si lo tratas bien, te avisa cuándo sale la gobernadora.

### El Último Trago

#### Don Silverio — el cantinero

| | |
|---|---|
| **Horario** | Noche (hasta la última) |
| **Te da** | Información, contactos, la mesa de los Gotera |
| **Quiere** | Que la cantina siga abierta |
| **Teme** | Que la cierren o que le caiga la noche |
| **Secreto** | Guarda las armas de los Gotera |
| **Precio** | Una copa, un chisme, un favor |

**Historia.** Sesenta y tantos, trapo al hombro, memoria de elefante. Ha visto pasar a todos: a los que suben, a los que caen, a los que no vuelven. Su cantina es el **despacho** de la zona.

**Rol.** Es el **informante de la noche** y el que te presenta a los Gotera. 💡 Si le pagas la cuenta, te deja dormir en el cuarto de atrás (un refugio temporal).

#### Yolanda — la mesera

| | |
|---|---|
| **Horario** | Noche (turno de 8 a 2) |
| **Te da** | Avisos, nombres, agua para el camino |
| **Quiere** | Salir de la noche |
| **Teme** | Amanecer mansa: a veces ya no duerme |
| **Secreto** | Toma de la llave cuando no le alcanza |
| **Precio** | Una propina, un favor, una salida |

**Historia.** Treinta y tantos, dos turnos, una hija. Sabe quién entra y quién sale, quién paga y quién no. Es la **amiga** que el jugador puede perder: está a una mala racha de ser la próxima.

**Rol.** Es el **espejo de Beto** en el otro extremo de la ciudad: la que aguanta. Si la ayudas, te avisa de las redadas; si no, te la encuentras de noche.

### La Gotera

#### Don Nemesio

| | |
|---|---|
| **Horario** | Día y noche (no se esconde) |
| **Te da** | Encargos (entregas punto a punto), protección, armas, información, agua limpia a precio justo |
| **Quiere** | Que su gente coma y beba, y que el negocio siga |
| **Teme** | Que GelA descubra el yacimiento y lo tome o lo sabotee |
| **Secreto** | Tiene un hermano en el gobierno (o un hijo en el coto) |
| **Precio** | Un favor, un silencio, una vida |

**Historia.** Sesenta y tantos, camioneta buena, playera limpia, tenis blancos. Manda en la **fortaleza de la Gotera**, la ciudad amurallada tipo favela donde viven los pobres. ✅ (2026-11-12) Es **el protector de los pobres, con las manos sucias**: sigue en drogas y armas, pero su gente come y bebe gracias a él. Descubrieron un **yacimiento subterráneo**, notaron que quien bebe de ahí no cambia de personalidad y levantaron su propia barricada; venden agua limpia a **precio justo**. Controla además la toma clandestina del acueducto (cerrada: su palanca contra GelA, ver lore §11). **No está infectado** y sabe que el agua de la llave "tiene algo". Para el barrio es un santo; para quien entra de fuera, un delincuente. Su frase: *"¿Nosotros? Nosotros vendemos cosas. El agua se la chuparon otros."*

**Rol.** Es el **poder paralelo**: te da las misiones peligrosas (entregas de punto a punto, cacerías), las armas y la información que GelA esconde. No es aliado ni enemigo: es una **transacción**. Si lo traicionas, no sales de La Gotera.

#### El Primo

| | |
|---|---|
| **Horario** | Noche (cobranza) |
| **Te da** | Misiones menores, chismes, un mal trato |
| **Quiere** | Subir en la organización |
| **Teme** | Al Gotera |
| **Secreto** | Le tiene miedo a la capilla (dice que "la Virgen lo mira") |
| **Precio** | Dinero, cerveza, una paliza que no le des |

**Historia.** Treinta y tantos, cadena de oro, pistola al cinto. Es el que va a cobrar la cuota quincenal a la capilla. Se cree importante y no lo es; don Nemesio lo manda a los encargos sucios.

**Rol.** Es el **cobrador**: el que conecta la capilla con el crimen y el que se puede sobornar, engañar o usar para llegar al Gotera.

---

## 6. Las facciones

### Quién está con quién

💡 Las relaciones entre bandos, en un solo lugar. Cada cruce es algo que el jugador puede **usar**: un favor que cobrar, un secreto que vender o un pleito que aprovechar.

| | **Régimen** (Gela, Buenrostro, blancos) | **Cuadrilla** (Gabriel, Beto) | **Culto** (Chuy, Rosa) | **Diócesis** (Marín, Karla) | **Gotera** (Nemesio, el Primo) | **Coto** (Villalobos) |
|---|---|---|---|---|---|---|
| **Cuadrilla** | La tolera mientras no estorbe; Gabriel teme que lo compren | | Aliados: la cuadrilla llena en la capilla | — | Gabriel les debe favores | Villalobos es cliente |
| **Culto** | Enemigos: la capilla es la cura gratis | Aliados | | Tensos: el obispo quiere el filtro y Karla lo espía | Les cobran cuota (el Primo) | — |
| **Diócesis** | Socios: Marín quiere venderle el filtro a GelA | — | Tensos | | — | Donativos |
| **Gotera** | **El pacto**: la válvula cerrada es su rehén | Acreedores | Cobran cuota; el Primo le teme a la Virgen | — | | Nemesio tiene un hijo en el coto (o un hermano en el gobierno) |
| **Coto** | Clientes de GelA Total | Le compran agua al Nocturno | — | Dan donativos | Vecinos incómodos | |
| **Radio y ciencia** (Sofía, López) | Enemigos: los buscan | — | — | — | — | — |

**Las palancas del jugador:** la deuda de Gabriel con los Gotera, el espionaje de Karla, el pacto de la válvula, el hijo de Nemesio en el coto, el sótano de Villalobos, el silencio de Chuy, la doble cara de Gerardo y el secreto de Nacho. Cada uno es un secreto que se puede cobrar, vender o callar.

#### Las tres fortalezas y el gremio (✅ 2026-11-12)

| | **Santa Mugre** (la Virgen) | **La Gotera** (la mafia) | **Fortaleza GelA** (los Lazcano) | **El gremio** (Gabriel, Chava, Nacho) |
|---|---|---|---|---|
| **Quién manda** | Chuy (calla lo que sospecha) | Nemesio (protector con manos sucias) | Georgina y Germán (que se hace el ciego) | Gabriel (la ficha); Chava (el pozo) |
| **Qué sabe del Serenol** | Solo la fe: "los de fuera están poseídos" | "Algo hay en el agua de la llave"; sabe que GelA esconde algo | Todo, adentro; la resistencia lo sabe | Gente de fuera pide agua limpia y el gremio se la lleva |
| **Con Santa Mugre** | — | Cobra cuota (el Primo) | Enemigos: el tinaco es una fuga en su negocio | Aliados: la reja y el tinaco de la plaza |
| **Con la Gotera** | Cuota | — | La válvula cerrada es su rehén | Gabriel le debe favores; Nemesio quiere cobrar el pozo de Chava |
| **Con GelA** | Enemigos | Sabe que el yacimiento los puede delatar | — | Los blancos (la policía de Buenrostro) los persiguen de día |
| **Dentro** | Fieles y dóciles mezclados que no saben | Los pobres lo respetan como a un santo | **Resistencia**: servicio (Arturo) + ricos arrepentidos (Gerardo); no se fían entre sí | Nacho calla su pasado de chofer de GelA |

#### Los policías

✅ (2026-11-12) **Los policías son los blancos**: el brazo armado de Gela, con **Buenrostro de jefe**. Anónimos y sin cara: traje blanco, casco, nada que decir, una amenaza y no personajes (la excepción con nombre es el Inspector Nava, ver abajo). Solo salen **de día**, en las colonias de fuera (de noche el Estado se retira), y **disparan a quien reparte agua**. Sin nombre, sin diálogo y sin horario más allá de ese: son un sistema, no una voz (ver S3 en `docs/plan-noche.md`).

### Arq. Villalobos — el del coto

| | |
|---|---|
| **Zona** | Haciendas de San Jodido |
| **Horario** | Día (casa, alberca) |
| **Te da** | Dinero, contactos, un cliente |
| **Quiere** | Que no le falte el agua para la casa y el pasto |
| **Teme** | Que la ciudad se le meta |
| **Secreto** | Su esposa es del barrio; su hijo es amigo de Gerardo; lo que guarda en el sótano |
| **Precio** | Dinero |

**Historia.** Cincuenta y tantos, arquitecto, casa blanca, alberca. Compra agua para la alberca sin culpa: para él, el agua es un servicio, no un derecho. No es malo: es **cómodo**, que en esta ciudad es peor.

**Rol.** Es el **cliente rico**: te compra agua, te paga bien y te enseña el otro lado. Arturo fue su jardinero antes de pasar a los Reservorios y conserva la llave del sótano: por él se entra a la casa y al sótano. Villalobos vive en Haciendas, **fuera** de la fortaleza. 💡 Puede ser el puente con Gerardo, o el que te venda a los blancos.

### Inspector Nava — el blanco

| | |
|---|---|
| **Zona** | Toda la ciudad (operativos) |
| **Horario** | Día (de noche el Estado se retira) |
| **Te da** | Avisos, multas, una tregua, la misión de su hija |
| **Quiere** | **Terminar con su sufrimiento**: que su hija lo mate a él, no que otro la mate a ella |
| **Teme** | Que Buenrostro se entere de su hija; que otro la mate antes que él llegue |
| **Secreto** | ✅ **Su hija se volvió zombi** (por el agua de la llave) y anda perdida entre los de la noche |
| **Precio** | Una prueba, un favor, un nombre; y lo que hagas con su hija |

**Historia.** Cuarenta y tantos, traje blanco, credencial, esposas. Es **el único blanco con nombre**, el mismo que clausura tomas y cierra la capilla "por sanitario". Sabe que lo que hace está mal y lo hace igual. ✅ (2026-11-12) Hace tiempo que **su hija se levantó**: tomaba de la llave, como todos los que él cuida con su placa, y ahora es una de esos que él persigue de día. Se le escapó y anda perdida entre los zombis de la noche. Es el castigo de la historia para un policía: **sufre lo que le hace al barrio**.

**Rol.** Es el **policía que sufre**: el que te persigue de día y el que, de noche, no puede ni mirarse en el espejo.

✅ **Su misión (2026-11-12):** te pone a **buscar a su hija**. Te da su **vestimenta y descripción**, y de noche la **encuentras por la ropa** entre los zombis. **No la matas: si la matas, fallas la misión.** Nava **te lo dice claro**: quiere que lo **lleves con ella para terminar con su sufrimiento**. Él se deja matar por su hija **en lugar de que tú la mates**: el policía muere a manos de su hija y ella sigue siendo su hija hasta el final. **Te paga igual** (la paga no depende de que él sobreviva). Es un policía normal: **no pasa nada con su puesto** entre los blancos, y nadie lo extraña. Se diseña en L9 (`misiones.md`). Pide un zombi con atuendo propio en la horda que **no se pueda matar por accidente** (los demás zombis y tú) y a Nava como acompañante en una escolta de noche (sistema S: ESCOLTAR).

### Sofía — la radio pirata

| | |
|---|---|
| **Zona** | Escondida (un taller de Santa Mugre) |
| **Horario** | Noche (transmite) |
| **Te da** | Difusión, pruebas, contactos |
| **Quiere** | Que la ciudad despierte |
| **Teme** | Que la encuentren |
| **Secreto** | Tiene el manifiesto del G-7 |
| **Precio** | Una grabación, una prueba, un favor |

**Historia.** Treinta y tantos, voz de radio, manos de soldador. Transmite desde un taller con una antena hecha con tubos. Es la única que dice en voz alta lo que el noticiero calla.

**Rol.** Es el **canal de la verdad**: si le llevas las pruebas, la revelación se vuelve pública. Sin ella, la verdad se queda en un cajón.

### Dr. López — el químico desertor

| | |
|---|---|
| **Zona** | Escondido (una casa de La Florida) |
| **Horario** | Día y noche (no sale) |
| **Te da** | La fórmula, la prueba del agua, el testimonio |
| **Quiere** | Que se sepa lo que hizo |
| **Teme** | Que lo maten |
| **Secreto** | Diseñó el G-7 y renunció cuando vio el ensayo 4 |
| **Precio** | Un laboratorio, agua limpia, una salida |

**Historia.** Cincuenta y tantos, lentes, manos temblorosas. Trabajó en la "Dirección de Innovación Hídrica" y firmó el ensayo que volvió dócil a medio barrio. Renunció cuando leyó los resultados adversos. Lleva dos años escondido, tomando agua de garrafón y escribiendo lo que sabe.

**Rol.** Es la **prueba viva**: el que puede explicar el Serenol y confirmar la revelación. Es el objetivo de GelA y la llave del final.

### La Chava — la del yonke 💡 (propuesta de AG)

| | |
|---|---|
| **Zona** | Parques de Santa Mugre (El Yonke de Don Chava, en un baldío) |
| **Horario** | Día (de noche cierra, como todos) |
| **Te da** | Lo que le pidas, si le traes el material (el taller, `especificaciones.md` 4.13) |
| **Quiere** | Que el yonke de su abuelo no se muera con él |
| **Teme** | La varilla que brilla |
| **Secreto** | Su tío abuelo tenía el taller de chatarra donde llegó la máquina del 84; la familia sabe de dónde salió el cobalto |
| **Precio** | Material y unos pesos |

**Historia.** Veintitantos, overol negro, manos de soldadora. Se quedó con el yonke de su abuelo, Don Chava, cuando él ya no pudo con el soplete. Arma de todo con lo que le traen y no hace preguntas. Bueno, casi no.

**Rol.** Es **el taller**: con ella los materiales se vuelven remedios, amuletos y armas. Se acuerda de ti aunque empieces de nuevo: el rango del taller, los planos y la vitrina de trofeos no se pierden. Con la Varilla del 84 se pone seria.

---

## 7. Los vendedores

Un arquetipo por giro, reusado en todas las franquicias. No tienen nombre propio (o tienen uno por ciudad): son **la cara de la tienda**. Su diálogo es funcional: una línea, el menú y el chisme del día.

| Giro | Quién atiende | Lo que te dice | Secreto |
|---|---|---|---|
| **Abarrotes** | La encargada | *"¿Qué le doy?"* | Conoce a los de la llave por la cara y por las manos |
| **Taquería** | El taquero | *"¿Con todo?"* | Le sobra agua buena del puesto y la vende de noche |
| **Ferretería** | El ferretero | *"¿Para qué es?"* | Sabe que las tablas y la cinta son para barricadas |
| **Farmacia** | La farmacéutica | *"¿Tiene receta?"* | Sabe quién se está poniendo "raro" por lo que compra |
| **Licorería** | El licorero | *"¿La de siempre?"* | Rellena garrafones con la llave y los vende como "de garrafón" |
| **Purificadora** | El franquiciatario | *"El precio es el de la empresa."* | Está atrapado: si baja el precio, GelA lo castiga |
| **OXXO** | El cajero | *"¿Algo más?"* | Tiene cámaras y no puede hacer excepciones |
| **Gasolinera** | El despachador | *"¿Con gasolina?"* | Vende gasolina para molotov sin preguntar |
| **Puesto** | El taquero de la banqueta | *"¿Con todo?"* | Es el que cierra más tarde y el que sabe dónde está la caminata |
| **El punto** | El del colchón | *"Pasa, no hay nadie."* | Vende tachas y agua cara; tiene a alguien tirado en el piso |

**La purificadora** es el vendedor más triste: el franquiciatario es un vecino que puso su dinero y le compra el agua a GelA. No es el villano: es el que también se lleva su parte y también tiene miedo. **El punto** es el más oscuro: un cuarto en obra negra con un colchón, alguien tirado y el que te atiende a un lado.

---

## 8. Las leyendas

No son parte del reparto principal: son rumores con cara que el jugador se puede encontrar.

### El de las cruces

| | |
|---|---|
| **Zona** | Una colonia al azar por partida |
| **Horario** | Noche (3-5 de la mañana) |
| **Oficio** | Vecino no infectado, "loco" |
| **Te da** | Una plática, un "bendición", un rumor |
| **Quiere** | "Bendecir" la colonia |
| **Teme** | Que la colonia no se deje |
| **Secreto** | No es ningún culto: solo está loco y es inofensivo |
| **Precio** | Nada: te bendice gratis |

**Historia.** Un señor que sale de noche con su bote y su brocha a pintar cruces hechas con popó en las paredes. Está seguro de que así protege a la colonia. No le hace daño a nadie; solo apesta.

**Rol.** Es el **recordatorio de que no todo lo que anda de noche es un zombi**. El barrio lo culpa de todo (el diablo, los zombis, un culto rival). Se puede platicar con él: es amable y está completamente ido.

### El tinaco manchado

✅ (2026-11-12) Sustituye a la leyenda del "tinaco que no se vacía" (que desaparece junto con Doña Refugio). No es una persona: es el **tinaco manchado de la plaza de Santa Mugre**, al que la gente le rinde culto como a la Virgen. El jugador lo ve cada día; solo el que baja al pozo del templo entiende de dónde sale el agua.

---

## 9. El reparto en números

### Las 30 voces

| Grupo | Personajes | Total |
|---|---|---|
| Zonas | Armando, Martín, Chuy, Rosa, Marisol, Lalo, Chava, Toño, Güero, Elena, Tito, Arturo, Sergio, Silverio, Yolanda, Nemesio, Primo | **17** |
| La casa Lazcano | Germán, Georgina, Gerardo, Buenrostro | **4** |
| La cuadrilla | Gabriel, Beto, Nacho | **3** |
| El culto | Karla, obispo Marín | **2** |
| Facciones | Villalobos, Nava, Sofía, López | **4** |
| **Total** | | **30** |

Más **1 leyenda** (el de las cruces), **10 vendedores** y **20-30 habitantes** a la vez.

### El presupuesto de texto

| Tipo | Cuántos | Líneas por uno | Total |
|---|---|---|---|
| Voces | 30 | 10-25 | ~450 |
| Vendedores | 10 | 4-6 | ~50 |
| Leyendas | 1 | 10-15 | ~12 |
| Barks (habitantes) | ~30 | 1-3 | ~90 |
| **Total** | | | **~600 líneas** |

Para 4 personas, es un fin de semana de escritura por grupo. El cuello de botella no es el texto: es **la lógica de las misiones**.

### La distribución en el mapa

- **3.3 voces por zona** (30 ÷ 9).
- **Una voz cada ~110,000 m²**: caminando a 1.5 m/s, te topas una cada **~2 minutos**.
- **Una tienda cada ~30,000 m²** (110 interactivas en 3.3 km²): el jugador ve un vendedor cada 30-60 segundos.
- **20-30 habitantes** en un radio de 60-80 m: la calle se siente viva sin tumbar los frames.

### El horario

Cada voz tiene un horario (día, noche o ambos). Con 30 voces repartidas, **en pantalla hay ~15 a la vez**: la mitad de día, la otra de noche. Eso duplica la sensación de ciudad sin duplicar el trabajo.

---

## 10. Cómo se implementan

### El recurso `Persona`

Un `.tres` por personaje, como los `InventoryItemData`:

```
Persona (Resource)
  nombre: String
  oficio: String
  bando: String            # cuadrilla, culto, gotera, coto, gela, gobierno, prensa, ciencia
  modelo: PackedScene      # de models/personajes/ o el ninja provisional
  tinte: Color             # variación de ropa/piel
  horario: int             # 0 día, 1 noche, 2 ambos
  zona: String             # una de las 9
  lugar: Vector3           # dónde se para
  ruta: Array[Vector3]     # por dónde camina (ambientales)
  dialogo: DialogoData     # null = sin diálogo
  barks: Array[String]     # frases sueltas (día/noche/zona)
  mision: MisionData       # opcional
```

### Los tres niveles en código

| Nivel | Script / sistema | Qué hace |
|---|---|---|
| **Voz** | `scripts/npc.gd` + `DialogoData` | Se queda en su lugar; "Espacio: hablar"; conversación |
| **Habitante** | `scripts/map/Gente.gd` | Camina, se va, vuelve; bark al pasar; sin conversación |
| **Silueta** | `MultiMeshInstance3D` | Relleno de multitud lejos; sin lógica, sin diálogo |

**La decisión es el dato:** si `dialogo` es `null`, es habitante. Si no, es voz. **El mismo modelo** puede ser las dos cosas: el mismo modelo puede ser el taquero (voz) o un caminante (habitante). La diferencia está en el `.tres`, no en la escena.

### Los barks

Una lista de frases por contexto, que se elige al pasar cerca:

- **Día**: *"¿Ya viste el precio del agua?"*, *"No salgas, mijo."*, *"¿Traes garrafón?"*
- **Noche**: *"Vámonos antes de que oscurezca."*, *"Yo no abro."*
- **Zona tomada**: *"Aquí ya no."*
- **Evento**: si hay un zombi muerto cerca, si llueve, si es la hora del cierre.

### El spawn y el rendimiento

- Las **voces** se colocan fijas, como las tiendas.
- Los **habitantes** se spawnean alrededor del jugador (60-80 m) con el presupuesto por frame de `scripts/map/CargaCuadro.gd`, como las casas y los árboles.
- Las **siluetas** van en MultiMesh, sin esqueleto, más lejos.
- Meta: 20-30 NPCs con esqueleto cerca + 50-100 siluetas lejos. Si no aguanta, `godot --path . tools/medir_mapa.tscn`.

### Cómo se agrega un personaje sin tocar código

1. Creas `resources/personas/<nombre>.tres` con los campos de arriba.
2. Si tiene `dialogo`, creas `resources/dialogos/<nombre>.tres` con los nodos.
3. Si tiene `mision`, usas el `MisionData` de `resources/misiones/`.
4. Lo colocas en el mapa (o en el JSON de la zona).
5. Listo: el sistema lo trata como voz o habitante según el dato.

---

## 11. Preguntas abiertas

- [x] ✅ (2026-11-12) Gerardo es el **medio hermano** de Georgina (hijo menor de Germán) y el hijo rebelde de GelA; ya sabe del Serenol.
- [ ] 💡 La edad de Gerardo (22) con Germán de setenta y tantos: ¿su madre es una segunda esposa? Falta decidir si se menciona.
- [ ] 💡 Nombre del chofer: Nacho Garrafón (propuesto por Claude, 2026-11-12); confirmar.
- [ ] 💡 ¿Gerardo llega a saber lo de "Contención" (los conteos)? Sería la segunda revelación suya.
- [ ] 💡 ¿Quién queda de Doña Refugio en La Palmada? Nadie: el pozo es de Chava. Confirmar que Chava y Nacho viven ahí.
- [ ] 💡 ¿El sótano de la casa del coto esconde a un "zombi del coto"? Sería un giro fuerte: el rico también tiene su monstruo.
- [ ] 💡 ¿Yolanda amanece mansa si el jugador no la ayuda, o se salva siempre?
- [ ] 💡 ¿Beto se puede salvar del todo o es una tragedia anunciada?
- [ ] 💡 ¿El obispo Marín se queda con el filtro en algún final, o siempre pierde?
- [ ] 💡 ¿Sofía alcanza a transmitir la verdad o la callan antes?
- [ ] 💡 ¿Don Nemesio es aliado, cliente o solo una transacción?
- [ ] 💡 ¿Dos voces por zona alcanzan, o las zonas grandes (Parques de Santa Mugre, La Gotera) piden tres?
- [ ] 💡 ¿Los vendedores tienen nombre propio (doña Chayo, don Beto) o se quedan como arquetipos?
- [ ] 💡 ¿El protagonista tiene nombre en el guardado/HUD, o siempre es "el Nocturno"?

---

*Este documento es un reparto vivo: si un personaje no tiene querer, secreto y precio, no entra. Si entra y no cambia nada, se corta.*
