# Graph Report - docs  (2026-11-23)

## Corpus Check
- 6 files · ~63,483 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 542 nodes · 1162 edges · 28 communities (27 shown, 1 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 56 edges (avg confidence: 0.84)
- Token cost: 452,192 input · 0 output

## Community Hubs (Navigation)
- Misiones y agua de noche
- Premisa, sed y salud
- Deterioro y estado del mundo
- La Madre, cárcamos y Sótano
- Tiendas e interiores
- Tazos y personaje
- Celular, HUD y récord
- Culto del Tinaco y la reja
- Fortalezas y zonas
- Combate y armas
- Taller de La Chava
- Gente, NPCs y cruces
- Las tres aguas
- Visión del juego
- Director y hordas
- Objetos y agua en galón
- Economía y segunda moneda
- Arrojables
- Giros de negocios
- Consumibles
- Fuentes del lore
- Molotov y gasolinera
- Drops, llaves y documentos
- Sandbox sin fin y guardado
- Inventario y mochilas
- Muerte y bolsa cuidada
- Ciclo e hitos de noche
- Movimiento y cámara

## God Nodes (most connected - your core abstractions)
1. `Guadalajaja — Lore` - 29 edges
2. `Guadalajaja — Revisión de la historia` - 24 edges
3. `Serenol (G-7)` - 23 edges
4. `Los contratos de la noche` - 20 edges
5. `Las misiones de día` - 20 edges
6. `Georgina "Gela" Lazcano` - 19 edges
7. `El culto a la Virgen del Tinaco` - 18 edges
8. `Guadalajaja — Personajes` - 18 edges
9. `Padre Jesús "Chuy" Arreola` - 18 edges
10. `Guadalajaja — Misiones` - 18 edges

## Surprising Connections (you probably didn't know these)
- `Policías (solo de día)` --conceptually_related_to--> `Los blancos (la policía, a las órdenes de Buenrostro)`  [INFERRED]
  especificaciones.md → lore.md
- `Índice de deterioro = índice de infección` --semantically_similar_to--> `Índice de deterioro = índice de infección`  [INFERRED] [semantically similar]
  especificaciones.md → lore.md
- `Oficio y botín del zombi` --semantically_similar_to--> `El botín de los zombis (oficios)`  [INFERRED] [semantically similar]
  especificaciones.md → lore.md
- `Defensa del tinaco (la antigua Vela, ahora afuera)` --semantically_similar_to--> `Defender el tinaco (antes Vela del tinaco, piloto P0)`  [INFERRED] [semantically similar]
  lore.md → misiones.md
- `La cuadrilla` --semantically_similar_to--> `La cuadrilla (el gremio del agua)`  [INFERRED] [semantically similar]
  personajes.md → lore.md

## Hyperedges (group relationships)
- **Las tres fortalezas (sin policía, agua sin Serenol)** — lore_parques_de_santa_mugre, lore_la_gotera, lore_los_reservorios, lore_agua_en_fortalezas [EXTRACTED 1.00]
- **El secreto de la sangre del Machetes** — personajes_el_nocturno, personajes_germán_lazcano, lore_la_mojiganga, personajes_dr_lópez, lore_origen_serenol [EXTRACTED 1.00]
- **Lo que el Serenol le hace a todo lo demás (lombrices, cucarrata, los de en medio)** — lore_madre_del_cárcamo, lore_la_cucarrata, lore_los_de_en_medio, lore_serenol [INFERRED 0.85]
- **La compañía de agua: Gabriel, Chava y el Machetes (con Nacho al volante)** — personajes_el_gremio, personajes_gabriel_hinojosa, personajes_chava, personajes_el_nocturno, personajes_nacho_garrafón [EXTRACTED 1.00]
- **La sangre del Machetes: Germán, la Mojiganga, el Dr. López y los medios hermanos** — personajes_el_nocturno, personajes_germán_lazcano, lore_la_mojiganga, personajes_dr_lópez, personajes_georgina_gela_lazcano, personajes_gerardo_lazcano [EXTRACTED 1.00]
- **Cadena agua, enojo, verdad (la verdad solo la oye el que no toma de la llave)** — revision_historia_choque_final_verdad, revision_historia_idea_que_controla, lore_agua_viva, personajes_sofía, lore_la_valvula [EXTRACTED 1.00]
- **Defensa externa al servicio del reparto de agua de noche** — misiones_vela_del_tinaco, misiones_defender_la_camioneta, misiones_reparto, lore_agua_de_noche_gremio, personajes_chava [EXTRACTED 1.00]
- **Decisiones del sandbox sin fin (2026-11-23)** — especificaciones_sandbox_sin_fin, especificaciones_hitos_de_noche, especificaciones_muerte_tipo_dark_souls, especificaciones_guardado_en_disco, especificaciones_tazos_unica_progresion [EXTRACTED 1.00]
- **Receta del molotov (botella + gasolina + trapo)** — items_caguama_vacia, items_gasolina_limon_cereza, items_trapo, items_bomba_molotov [EXTRACTED 1.00]

## Communities (28 total, 1 thin omitted)

### Community 0 - "Misiones y agua de noche"
Cohesion: 0.06
Nodes (54): Misiones (resumen §6), Sistema de misiones (MisionData, §6.3), El agua clandestina, El agua de noche (el negocio del gremio), El agua en las fortalezas (sin Serenol y sin sobreprecio), Las camadas (zombis dormidos en bodegas de día), Camioneta de reparto, La compañía de agua (tres socios: Chava, Gabriel y el Machetes) (+46 more)

### Community 1 - "Premisa, sed y salud"
Cohesion: 0.09
Nodes (47): Facciones para misiones, La sed, La tentación (tomar agua de la llave), Premisa: Historia y mundo (§2), Salud y estados, Vida inicial 60 de 100 (Salud.VIDA_INICIO), La casa Lazcano, Centro de Innovación Hídrica (planta vieja) (+39 more)

### Community 2 - "Deterioro y estado del mundo"
Cohesion: 0.10
Nodes (36): Índice de deterioro = índice de infección, Bandas del índice (Sana, Mixta, Tomada, Podrida, Perdida), El estado del mundo (cura, enojo, escalón, confianza), La Florida Marchita, Los blancos (la policía, a las órdenes de Buenrostro), La mentira y la verdad del Machetes, Las venas del Serenol (várices sutiles, afuera sí, adentro no), Hoja de conteo (+28 more)

### Community 3 - "La Madre, cárcamos y Sótano"
Cohesion: 0.09
Nodes (37): Diente de la Madre (trofeo), Los colmillos de la Madre (¿quién los compra? sin decidir), Cuarto VIP del Sótano, Los cárcamos de GelA (lodo turquesa de Serenol), El jefe (hinchado grande), El Sótano (casino clandestino de los Gotera bajo Santa Mugre), El giro político (la gobernadora fabricó el poder con el agua), La Desaguadora (jefa secreta del desagüe del Sótano, propuesta de AG) (+29 more)

### Community 4 - "Tiendas e interiores"
Cohesion: 0.08
Nodes (28): Puesto de tacos, Interiores armados (escena fija en primera persona), Maquinitas de frutas (Cóctel de Frutas), Marcador amarillo (flecha estilo GTA SA), Marcas parodia, Misiones que ya hay (6.0), De noche todo cierra y te sacan, Tiendas e interiores (+20 more)

### Community 5 - "Tazos y personaje"
Cohesion: 0.07
Nodes (20): §1.3 Qué pasa de noche, Álbum de tazos, Bolsas especiales de Takis, Creador de personaje (Marcial López, el Machetes), Modelos 3D: qué hay y qué falta, El niño de los tazos (cambia 3 repetidos por uno que falte), Página de habilidades (Cuerpo, Sobrevivir, Negocio), Refugio con barricadas y tinaco (+12 more)

### Community 6 - "Celular, HUD y récord"
Cohesion: 0.09
Nodes (26): El celular, Grupo del barrio, Interfaz (HUD), La IA del celular (Sofía), Cuenta de noches sin fin y récord (user://noches.cfg), Pantalla de inicio ('No te tomes el agua.'), Lámpara / celular, La economía de las dos ciudades (+18 more)

### Community 7 - "Culto del Tinaco y la reja"
Cohesion: 0.13
Nodes (26): El agua no siempre se deja tomar (voluntad de la Virgen), La capilla del Tinaco, La cura: agua limpia durante semanas, La diócesis, La noche que falla la reja (defensa del tinaco de Santa Mugre), Los Garrafones, Parques de Santa Mugre, La política de la capilla (diócesis, GelA, Gotera, barrio, jugador) (+18 more)

### Community 8 - "Fortalezas y zonas"
Cohesion: 0.13
Nodes (25): Mapa de papel (9 pedazos), Tres fortalezas (Santa Mugre, La Gotera, los Reservorios), La casa de la gobernadora (dentro de los Reservorios), El Último Trago, Haciendas de San Jodido, La Gotera (favela amurallada de la mafia), Los Reservorios (fortaleza de los Lazcano, sobre el ITESO), Las nueve zonas (+17 more)

### Community 9 - "Combate y armas"
Cohesion: 0.14
Nodes (18): §1.4 Cómo se apunta y dispara, Armas de fuego, Combate cuerpo a cuerpo, Lock-on automático, Armas, Ballesta, Bate, Cuerno de chivo (+10 more)

### Community 10 - "Taller de La Chava"
Cohesion: 0.19
Nodes (18): Amuletos y estampitas, Casas en obra negra (contaminadas), Recetas del taller (39 en seis juegos, planos), El taller: El Yonke de Don Chava, Tiliches (materiales) en la cangurera, Trofeos de hazañas y vitrina de La Chava, Juegos de recetas 1-6 (remedios, amuletos, armas), Materiales comunes (6 familias × 3 niveles) (+10 more)

### Community 11 - "Gente, NPCs y cruces"
Cohesion: 0.15
Nodes (15): Cruces de caca (calcomanía y NPC), Gente de día, NPCs, Comportamiento seguir al jugador, Las cruces de caca, Barks, Guadalajaja — Personajes, El de las cruces (+7 more)

### Community 12 - "Las tres aguas"
Cohesion: 0.16
Nodes (15): La libreta del Machetes (antes del Nocturno, bestiario), Agua Cero (el caldo), Agua viva, GelA Total, Las tres aguas, 4.5 Agua Cero: el caldo, la de la llave, 4.6 La botarga zombi: de día bailaba, 4. Detalles (los diez) (+7 more)

### Community 13 - "Visión del juego"
Cohesion: 0.15
Nodes (14): §1.1 Plataforma y multijugador, Enemigos, Guadalajaja — Especificaciones del juego, Juegos de referencia, La idea en un párrafo (survival-shooter PS1 en Zapopan real), Look PS1, Multijugador en navegador: implicaciones técnicas, Música y sonidos (+6 more)

### Community 14 - "Director y hordas"
Cohesion: 0.15
Nodes (13): Campo de flujo (flow field), Director (estilo Left 4 Dead), Niveles de detalle de zombis (MultiMesh), Ruido que atrae zombis, Los zombis y las hordas, El culto a la empresa, Defensa del tinaco (la antigua Vela, ahora afuera), Las dos hambres del zombi (carne y agua sin Serenol) (+5 more)

### Community 15 - "Objetos y agua en galón"
Cohesion: 0.18
Nodes (13): Tortillería, Objetos (resumen §5), Costal de chiles (objeto de misión), Dinero y agua, Galón de agua, Guadalajaja — Items, Kilo de tortillas (propuesta de AG), Moneda de peso (+5 more)

### Community 16 - "Economía y segunda moneda"
Cohesion: 0.23
Nodes (11): Agua limpia como recurso caro, El agua se queda como segunda moneda (por ahora, sin fuente), Cartera (autoload: pesos y agua), Crafteo mínimo, Economía: una moneda, pesos, Purificadora (Puri-GelA), El agua no es moneda: es un recurso caro, Cómo funciona (inventario, mochilas, tipos, precios en pesos) (+3 more)

### Community 17 - "Arrojables"
Cohesion: 0.24
Nodes (12): Arrojables (lanzamiento en arco), Balas, Bocina con banda, Bolsa de sal (10 puñados), Bomba molotov, Chancla, Cinta canela, Molotov de cereza (quema 1.5 veces más lejos) (+4 more)

### Community 18 - "Giros de negocios"
Cohesion: 0.17
Nodes (12): Abarrotes, El punto, Farmacia (Guadalaraja / Dr Simio), Ferretería, OXO, Taquería, Tejuino (carrito), Giros de negocios (DENUE) (+4 more)

### Community 19 - "Consumibles"
Cohesion: 0.17
Nodes (12): Balance actual (datos de los .tres), Caguama, Cigarros, Consumibles, Gansito, Jarritos, Mazapán, Pendiente de código (machete y vaporub a pesos, sed, zombis, mochilón) (+4 more)

### Community 20 - "Fuentes del lore"
Cohesion: 0.18
Nodes (8): Guadalajaja — Lore, Enganches al diseño, El Heraldo de México (16 oct 2026): Lemus no privatizará el agua, La Tercera (2019): Yonke Fénix, el Chernobyl mexicano, Nombres propios, Nota de realidad (Chapala, El Zapotillo, CMRO, cobalto-60), Referencias (Dying Light, Snowpiercer, The Water Knife, Blade Runner, GTA SA, 7 Days to Die, RE/Silent Hill), Reglas del canon

### Community 21 - "Molotov y gasolinera"
Cohesion: 0.27
Nodes (11): Gasolinera (Perez), Agua sucia, Alcohol del 96, Caguama vacía, Cloralex, Gasolina limón / cereza (la gasolinera llena la botella), Materiales y crafteo, Receta: Agua limpia = agua sucia + Cloralex (delito) (+3 more)

### Community 22 - "Drops, llaves y documentos"
Cohesion: 0.20
Nodes (11): Oficio y botín del zombi, Credencial de GelA, Documentos y llaves, Drops raros (36 escondites, 6 sorteados al amanecer), Llave de un coto, Objetos que faltan o están pendientes, Papel raro, Acta de ausencia nocturna (+3 more)

### Community 23 - "Sandbox sin fin y guardado"
Cohesion: 0.24
Nodes (6): Guardado en disco (user://partida.cfg, Continuar y Partida nueva), Jefes que se repiten cada 3 noches (×1.25 de aguante por vuelta), El mundo en dos capas, La noche sin ley (Ley de Convivencia Nocturna), Registro de decisiones, Ley de Convivencia Nocturna

### Community 24 - "Inventario y mochilas"
Cohesion: 0.28
Nodes (9): Inventario estilo Resident Evil (inspirado en Silent Hill 2), Mochilas (6 base; 8/10/14), Voto: ranuras vs cuadrícula tipo Tetris, Equipo, Mochila del Partido Verde, Mochila escolar, Mochilón del nocturno, La regla de los items (1 lugar, 6 base) (+1 more)

### Community 25 - "Muerte y bolsa cuidada"
Cohesion: 0.29
Nodes (7): §1.2 Estructura / meta del juego, §1.5 Qué pasa al morir, §1.6 Alcance de la primera versión jugable, Bolsa cuidada por el zombi líder (3-5 guardias, cazador desde la noche 6), Bolsa recuperable al morir, Decisiones grandes (por votar), Partida de 3 noches con jefe (modo reto / piloto de prueba)

### Community 26 - "Ciclo e hitos de noche"
Cohesion: 0.29
Nodes (8): Ciclo día/noche (12 min día + 8 min noche), Ciclo principal (core loop), Hitos de noche (resources/noches/hitos.tres: garrafonero 3, Saltabardas 5, Panzón 7, Madre 10, Mojiganga 15), Tipos de zombi (Flaco, Corredor, Hinchado, Escupidor, Cargador, Botarga), El desfile de Día de Muertos de la colonia, El panzón (propuesta de AG para el gordo), El saltabardas (propuesta de AG), Taxonomía del barrio (flaco, corredor, hinchado, cargador, escupidor, botarga)

## Knowledge Gaps
- **105 isolated node(s):** `El chiste del título (Guadalajara + jaja)`, `Referencias (Dying Light, Snowpiercer, The Water Knife, Blade Runner, GTA SA, 7 Days to Die, RE/Silent Hill)`, `"Cuando el agua sabía a agua" (medida del tiempo)`, `La casa de la gobernadora (dentro de los Reservorios)`, `Bandas del índice (Sana, Mixta, Tomada, Podrida, Perdida)` (+100 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 109 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Guadalajaja — Lore` connect `Fuentes del lore` to `Misiones y agua de noche`, `Premisa, sed y salud`, `Deterioro y estado del mundo`, `La Madre, cárcamos y Sótano`, `Tazos y personaje`, `Celular, HUD y récord`, `Culto del Tinaco y la reja`, `Fortalezas y zonas`, `Gente, NPCs y cruces`, `Visión del juego`, `Director y hordas`, `Economía y segunda moneda`, `Sandbox sin fin y guardado`?**
  _High betweenness centrality (0.198) - this node is a cross-community bridge._
- **What connects `El chiste del título (Guadalajara + jaja)`, `Referencias (Dying Light, Snowpiercer, The Water Knife, Blade Runner, GTA SA, 7 Days to Die, RE/Silent Hill)`, `"Cuando el agua sabía a agua" (medida del tiempo)` to the rest of the system?**
  _105 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Misiones y agua de noche` be split into smaller, more focused modules?**
  _Cohesion score 0.06168831168831169 - nodes in this community are weakly interconnected._
- **Why does `Guadalajaja — Misiones` connect `Misiones y agua de noche` to `La Madre, cárcamos y Sótano`, `Tiendas e interiores`, `Celular, HUD y récord`, `Objetos y agua en galón`, `Fuentes del lore`?**
  _High betweenness centrality (0.118) - this node is a cross-community bridge._
- **Should `Premisa, sed y salud` be split into smaller, more focused modules?**
  _Cohesion score 0.08928571428571429 - nodes in this community are weakly interconnected._
- **Why does `Guadalajaja — Especificaciones del juego` connect `Visión del juego` to `Misiones y agua de noche`, `Premisa, sed y salud`, `Tazos y personaje`, `Celular, HUD y récord`, `Las tres aguas`, `Objetos y agua en galón`, `Fuentes del lore`, `Sandbox sin fin y guardado`, `Muerte y bolsa cuidada`, `Ciclo e hitos de noche`?**
  _High betweenness centrality (0.110) - this node is a cross-community bridge._
- **Should `Deterioro y estado del mundo` be split into smaller, more focused modules?**
  _Cohesion score 0.1039136302294197 - nodes in this community are weakly interconnected._