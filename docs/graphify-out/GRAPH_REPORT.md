# Graph Report - docs  (2026-11-24)

## Corpus Check
- 3 files · ~63,690 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 543 nodes · 1312 edges · 26 communities
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 109 edges (avg confidence: 0.81)
- Token cost: 159,826 input · 0 output

## Community Hubs (Navigation)
- Celular, HUD y pantalla
- Armas, trofeos y el punto
- Tiendas y misiones de día
- Las aguas y el zombi
- Combate y arrojables
- Agua de noche y gremio
- Economía y capilla
- Taller y obra negra
- Fortalezas y facciones
- Premisa y régimen
- Decisiones grandes
- Director y hordas
- Ciclo e hitos de noche
- Tazos y personaje
- Gente y NPCs
- Lore y su idea
- Consumibles
- Inventario y mochilas
- Sed y salud
- Giros de negocios
- Misiones del tianguis
- Objetos y balance
- Muerte y guardado
- Drops, llaves y documentos
- Visión y referencias
- Galón y dinero

## God Nodes (most connected - your core abstractions)
1. `Guadalajaja — Especificaciones del juego` - 30 edges
2. `Guadalajaja — Lore` - 27 edges
3. `Serenol (G-7)` - 26 edges
4. `Guadalajaja — Revisión de la historia` - 23 edges
5. `Padre Jesús "Chuy" Arreola` - 23 edges
6. `Las misiones de día` - 22 edges
7. `El culto a la Virgen del Tinaco` - 21 edges
8. `Georgina "Gela" Lazcano` - 20 edges
9. `Defender el tinaco (antes Vela del tinaco, piloto P0)` - 20 edges
10. `Premisa: Historia y mundo (§2)` - 20 edges

## Surprising Connections (you probably didn't know these)
- `Regla: un querer, un secreto y un precio` --conceptually_related_to--> `3.1 Cinco personajes tienen el mismo secreto`  [INFERRED]
  personajes.md → revision-historia.md
- `Papel raro` --semantically_similar_to--> `El papel raro (drop de lore)`  [INFERRED] [semantically similar]
  items.md → lore.md
- `Encargo` --references--> `Padre Jesús "Chuy" Arreola`  [INFERRED]
  misiones.md → personajes.md
- `Preguntas abiertas (lore §22)` --semantically_similar_to--> `Preguntas abiertas (especificaciones §13)`  [INFERRED] [semantically similar]
  lore.md → especificaciones.md
- `El galón como cebo (beben y no se llenan)` --semantically_similar_to--> `Ruido que atrae zombis`  [INFERRED] [semantically similar]
  misiones.md → especificaciones.md

## Hyperedges (group relationships)
- **Cadena agua, enojo, verdad (la verdad solo la oye el que no toma de la llave)** — revision_historia_choque_final_verdad, revision_historia_idea_que_controla, lore_agua_viva, personajes_sofía, lore_la_valvula [EXTRACTED 1.00]
- **La compañía de agua: Gabriel, Chava y el Machetes (con Nacho al volante)** — personajes_el_gremio, personajes_gabriel_hinojosa, personajes_chava, personajes_el_nocturno, personajes_nacho_garrafón [EXTRACTED 1.00]
- **La sangre del Machetes: Germán, la Mojiganga, el Dr. López y los medios hermanos** — personajes_el_nocturno, personajes_germán_lazcano, lore_la_mojiganga, personajes_dr_lópez, personajes_georgina_gela_lazcano, personajes_gerardo_lazcano [EXTRACTED 1.00]
- **Receta del molotov (botella + gasolina + trapo)** — items_caguama_vacia, items_gasolina_limon_cereza, items_trapo, items_bomba_molotov [EXTRACTED 1.00]
- **Las tres fortalezas sin policía con agua sin Serenol** — lore_parques_de_santa_mugre, lore_la_gotera, lore_los_reservorios, lore_agua_en_fortalezas [EXTRACTED 1.00]
- **Los tres socios de la compañía de agua** — personajes_chava, personajes_gabriel_hinojosa, personajes_el_nocturno, lore_compania_de_agua [EXTRACTED 1.00]
- **La capilla en el juego: Chuy, filtro robado y trae la tuya** — lore_capilla_del_tinaco, personajes_padre_chuy_arreola, personajes_filtro_puri_gela_robado, lore_trae_la_tuya [EXTRACTED 1.00]
- **La capilla como fuente del agua (envases, cupo, filtro robado)** — especificaciones_capilla_fuente_de_agua, misiones_filtro_capilla, misiones_la_capilla, especificaciones_agua_segunda_moneda, personajes_padre_chuy_arreola [EXTRACTED 1.00]
- **Sandbox sin fin: muerte tipo Dark Souls, hitos y guardado (2026-11-23)** — especificaciones_sandbox_sin_fin, especificaciones_muerte_tipo_dark_souls, especificaciones_bolsa_cuidada_por_el_lider, especificaciones_hitos_de_noche, especificaciones_guardado_en_disco [EXTRACTED 1.00]
- **Progresión de Santa Mugre a La Gotera (guardia de la reja, cucarrata, entregas)** — misiones_guardia_de_la_reja, misiones_la_cucarrata, misiones_entregas_punto_a_punto, misiones_puerta_de_la_gotera, misiones_orden_de_la_campana [EXTRACTED 1.00]

## Communities (26 total, 0 thin omitted)

### Community 0 - "Celular, HUD y pantalla"
Cohesion: 0.07
Nodes (48): El celular, Grupo del barrio, Interfaz (HUD), La IA del celular (Sofía), Pantalla de inicio ('No te tomes el agua.'), Policías (solo de día), Lámpara / celular, Agua Cero (el caldo) (+40 more)

### Community 1 - "Armas, trofeos y el punto"
Cohesion: 0.08
Nodes (46): El punto, Diente de la Madre (trofeo), La Chicharra (subfusil, propuesta de AG), La Matraca (ametralladora, propuesta de AG), La Tinaquera (escopeta, propuesta de AG), Los colmillos de la Madre (¿quién los compra? sin decidir), Cuarto VIP del Sótano, Los cárcamos de GelA (lodo turquesa de Serenol) (+38 more)

### Community 2 - "Tiendas y misiones de día"
Cohesion: 0.06
Nodes (45): Puesto de tacos, Maquinitas de frutas (Cóctel de Frutas), Misiones (resumen §6), Misiones que ya hay (6.0), La noche sin ley (Ley de Convivencia Nocturna), Sistema de misiones (MisionData, §6.3), Acta de ausencia nocturna, El estado del mundo (cura, enojo, escalón, confianza) (+37 more)

### Community 3 - "Las aguas y el zombi"
Cohesion: 0.08
Nodes (44): La tentación (tomar agua de la llave), La libreta del Machetes (antes del Nocturno, bestiario), El agua no siempre se deja tomar (voluntad de la Virgen), Agua viva, Las dos hambres del zombi (carne y agua sin Serenol), El jefe (hinchado grande), GelA Total, La Florida Marchita (+36 more)

### Community 4 - "Combate y arrojables"
Cohesion: 0.08
Nodes (38): §1.4 Cómo se apunta y dispara, Armas de fuego, Arrojables (lanzamiento en arco), Crafteo mínimo, Gasolinera (Perez), Lock-on automático, Agua sucia, Alcohol del 96 (+30 more)

### Community 5 - "Agua de noche y gremio"
Cohesion: 0.10
Nodes (38): El agua clandestina, El agua de noche (el negocio del gremio), El agua en las fortalezas (sin Serenol y sin sobreprecio), Camioneta de reparto, La compañía de agua (tres socios: Chava, Gabriel y el Machetes), Los contratos de la noche, Defensa del tinaco (la antigua Vela, ahora afuera), La cuadrilla (el gremio del agua) (+30 more)

### Community 6 - "Economía y capilla"
Cohesion: 0.12
Nodes (37): Agua limpia como recurso caro, El agua se queda como segunda moneda (por ahora, sin fuente), La capilla del templo como fuente de agua (envases con el padre Chuy, cupo 2/3), Cartera (autoload: pesos y agua), Economía: una moneda, pesos, Purificadora (Puri-GelA), Interiores armados (escena fija en primera persona), Marcador amarillo (flecha estilo GTA SA) (+29 more)

### Community 7 - "Taller y obra negra"
Cohesion: 0.10
Nodes (30): Amuletos y estampitas, Casas en obra negra (contaminadas), Cruces de caca (calcomanía y NPC), Recetas del taller (39 en seis juegos, planos), El taller: El Yonke de Don Chava, Tiliches (materiales) en la cangurera, Trofeos de hazañas y vitrina de La Chava, Juegos de recetas 1-6 (remedios, amuletos, armas) (+22 more)

### Community 8 - "Fortalezas y facciones"
Cohesion: 0.13
Nodes (28): Facciones para misiones, Mapa de papel (9 pedazos), Tres fortalezas (Santa Mugre, La Gotera, los Reservorios), La gente de fuera (bajo Serenol, no dan misiones), Haciendas de San Jodido, Los Reservorios (fortaleza de los Lazcano, sobre el ITESO), Las nueve zonas, Parques de Santa Mugre (+20 more)

### Community 9 - "Premisa y régimen"
Cohesion: 0.16
Nodes (28): Premisa: Historia y mundo (§2), Centro de Innovación Hídrica (planta vieja), Programa Contención, El culto a la empresa, El desfile de Día de Muertos de la colonia, Los dóciles, Documento interno G-7 (Ensayo 4), El Mante Tieso (+20 more)

### Community 10 - "Decisiones grandes"
Cohesion: 0.15
Nodes (17): §1.1 Plataforma y multijugador, §1.3 Qué pasa de noche, §1.6 Alcance de la primera versión jugable, Combate cuerpo a cuerpo, Decisiones grandes (por votar), Enemigos, Guadalajaja — Especificaciones del juego, Look PS1 (+9 more)

### Community 11 - "Director y hordas"
Cohesion: 0.19
Nodes (16): Campo de flujo (flow field), Director (estilo Left 4 Dead), Niveles de detalle de zombis (MultiMesh), Oficio y botín del zombi, Plan de trabajo (hitos 0-7), Ruido que atrae zombis, Los zombis y las hordas, El botín de los zombis (oficios) (+8 more)

### Community 12 - "Ciclo e hitos de noche"
Cohesion: 0.18
Nodes (14): §1.2 Estructura / meta del juego, Ciclo día/noche (12 min día + 8 min noche), Ciclo principal (core loop), Hitos de noche (resources/noches/hitos.tres: garrafonero 3, Saltabardas 5, Panzón 7, Madre 10, Mojiganga 15), Jefes que se repiten cada 3 noches (×1.25 de aguante por vuelta), Cuenta de noches sin fin y récord (user://noches.cfg), Sandbox sin fin, Tipos de zombi (Flaco, Corredor, Hinchado, Escupidor, Cargador, Botarga) (+6 more)

### Community 13 - "Tazos y personaje"
Cohesion: 0.15
Nodes (14): Álbum de tazos, Bolsas especiales de Takis, Creador de personaje (Marcial López, el Machetes), Modelos 3D: qué hay y qué falta, El niño de los tazos (cambia 3 repetidos por uno que falte), Página de habilidades (Cuerpo, Sobrevivir, Negocio), Revelación del tazo por rareza, 48 tazos en 4 series (La colonia, La noche, Los vecinos, GelA) (+6 more)

### Community 14 - "Gente y NPCs"
Cohesion: 0.20
Nodes (12): Gente de día, NPCs, Comportamiento seguir al jugador, Barks, Guadalajaja — Personajes, El del colchón (el punto), El franquiciatario de la purificadora, Preguntas abiertas (personajes) (+4 more)

### Community 15 - "Lore y su idea"
Cohesion: 0.21
Nodes (13): Bandas del índice (Sana, Mixta, Tomada, Podrida, Perdida), El consentimiento fabricado, Guadalajaja — Lore, Enganches al diseño, La idea que controla la historia, Índice de deterioro = índice de infección, Nombres propios, El prejuicio como cortina (+5 more)

### Community 16 - "Consumibles"
Cohesion: 0.17
Nodes (12): Botiquín del Simi, Caguama, Cigarros, Consumibles, Gansito, Jarritos, Mazapán, Tachas (+4 more)

### Community 17 - "Inventario y mochilas"
Cohesion: 0.28
Nodes (9): Inventario estilo Resident Evil (inspirado en Silent Hill 2), Mochilas (6 base; 8/10/14), Voto: ranuras vs cuadrícula tipo Tetris, Equipo, Mochila del Partido Verde, Mochila escolar, Mochilón del nocturno, La regla de los items (1 lugar, 6 base) (+1 more)

### Community 18 - "Sed y salud"
Cohesion: 0.25
Nodes (8): La sed, Partida de 3 noches con jefe (modo reto / piloto de prueba), Salud y estados, Vida inicial 60 de 100 (Salud.VIDA_INICIO), Cómo cambia la ciudad (agua → enojo → verdad → GelA contesta), La cura: agua limpia durante semanas, Modo reto de 3 noches, Preguntas abiertas (lore §22)

### Community 19 - "Giros de negocios"
Cohesion: 0.29
Nodes (7): Abarrotes, Farmacia (Guadalaraja / Dr Simio), Ferretería, OXO, Taquería, Tejuino (carrito), Giros de negocios (DENUE)

### Community 20 - "Misiones del tianguis"
Cohesion: 0.33
Nodes (7): Tortillería, Costal de chiles (objeto de misión), Kilo de tortillas (propuesta de AG), Agua para la fila, Chiles para el mercado, Mandados de Santa Mugre (propuesta de AG), Tortillas para la vecina

### Community 21 - "Objetos y balance"
Cohesion: 0.33
Nodes (7): Objetos (resumen §5), Balance actual (datos de los .tres), Cómo funciona (inventario, mochilas, tipos, precios en pesos), Guadalajaja — Items, Pendiente de código (machete y vaporub a pesos, sed, zombis, mochilón), Preguntas abiertas (items §10), Vaporub

### Community 22 - "Muerte y guardado"
Cohesion: 0.47
Nodes (6): §1.5 Qué pasa al morir, Bolsa cuidada por el zombi líder (3-5 guardias, cazador desde la noche 6), Bolsa recuperable al morir, Guardado en disco (user://partida.cfg, Continuar y Partida nueva), Muerte tipo Dark Souls (decidido 2026-11-23), Registro de decisiones

### Community 23 - "Drops, llaves y documentos"
Cohesion: 0.33
Nodes (6): Credencial de GelA, Documentos y llaves, Drops raros (36 escondites, 6 sorteados al amanecer), Llave de un coto, Objetos que faltan o están pendientes, Papel raro

### Community 24 - "Visión y referencias"
Cohesion: 0.40
Nodes (5): Juegos de referencia, La idea en un párrafo (survival-shooter PS1 en Zapopan real), El mundo en dos capas, El mundo en capas (lo que se juega, por qué, la verdad), Referencias (Dying Light, Snowpiercer, The Water Knife, Blade Runner, GTA SA, 7 Days to Die, RE/Silent Hill)

### Community 25 - "Galón y dinero"
Cohesion: 0.50
Nodes (4): Dinero y agua, Galón de agua, Moneda de peso, El galón como cebo (beben y no se llenan)

## Knowledge Gaps
- **77 isolated node(s):** `Barks`, `El del colchón (el punto)`, `Preguntas abiertas (personajes)`, `4.6 La botarga zombi: de día bailaba`, `4.7 Regla 7: en la calle no ser visto; en casa, la llave` (+72 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 77 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Guadalajaja — Especificaciones del juego` connect `Decisiones grandes` to `Celular, HUD y pantalla`, `Tiendas y misiones de día`, `Las aguas y el zombi`, `Economía y capilla`, `Taller y obra negra`, `Fortalezas y facciones`, `Premisa y régimen`, `Director y hordas`, `Ciclo e hitos de noche`, `Tazos y personaje`, `Gente y NPCs`, `Lore y su idea`, `Inventario y mochilas`, `Sed y salud`, `Objetos y balance`, `Muerte y guardado`, `Visión y referencias`?**
  _High betweenness centrality (0.210) - this node is a cross-community bridge._
- **What connects `Barks`, `El del colchón (el punto)`, `Preguntas abiertas (personajes)` to the rest of the system?**
  _77 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Celular, HUD y pantalla` be split into smaller, more focused modules?**
  _Cohesion score 0.07397959183673469 - nodes in this community are weakly interconnected._
- **Why does `Guadalajaja — Lore` connect `Lore y su idea` to `Celular, HUD y pantalla`, `Tiendas y misiones de día`, `Las aguas y el zombi`, `Agua de noche y gremio`, `Economía y capilla`, `Taller y obra negra`, `Fortalezas y facciones`, `Premisa y régimen`, `Decisiones grandes`, `Director y hordas`, `Ciclo e hitos de noche`, `Gente y NPCs`, `Sed y salud`, `Visión y referencias`?**
  _High betweenness centrality (0.136) - this node is a cross-community bridge._
- **Should `Armas, trofeos y el punto` be split into smaller, more focused modules?**
  _Cohesion score 0.08309178743961353 - nodes in this community are weakly interconnected._
- **Why does `Serenol (G-7)` connect `Premisa y régimen` to `Celular, HUD y pantalla`, `Tiendas y misiones de día`, `Las aguas y el zombi`, `Taller y obra negra`, `Fortalezas y facciones`, `Director y hordas`, `Lore y su idea`, `Sed y salud`, `Muerte y guardado`?**
  _High betweenness centrality (0.067) - this node is a cross-community bridge._
- **Should `Tiendas y misiones de día` be split into smaller, more focused modules?**
  _Cohesion score 0.06464646464646465 - nodes in this community are weakly interconnected._