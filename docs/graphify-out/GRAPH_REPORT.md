# Graph Report - docs  (2026-11-18)

## Corpus Check
- 6 files · ~87,609 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 523 nodes · 1486 edges · 20 communities
- Extraction: 86% EXTRACTED · 14% INFERRED · 0% AMBIGUOUS · INFERRED: 212 edges (avg confidence: 0.85)
- Token cost: 458,198 input · 0 output

## Community Hubs (Navigation)
- Items, taller y crafteo
- Canon: GelA, Serenol y premisa
- La revelación y el cobalto
- Contratos de noche y el pozo
- La Gotera, la mafia y la válvula
- Giros, consumibles y mandados
- El régimen y el estado del mundo
- Marcial y la sangre Lazcano
- Revisión: lo decidido y pendiente
- Santa Mugre, culto y fortalezas
- Misiones de día
- Ciclo, celular y economía
- Decisiones grandes y plan
- Tazos, mapa y sandbox
- Tiendas, maquinitas y cruces
- Reparto de NPCs
- Especificaciones e interfaz
- Zombis, hordas y director
- Colorismo y creador de personaje
- Modo reto y la libreta

## God Nodes (most connected - your core abstractions)
1. `Guadalajaja — Lore` - 34 edges
2. `Serenol (G-7)` - 31 edges
3. `Defender el tinaco (antes Vela del tinaco, piloto P0)` - 29 edges
4. `Los Gotera` - 26 edges
5. `Marcial López, "el Machetes" (protagonista)` - 26 edges
6. `Parques de Santa Mugre` - 24 edges
7. `Guadalajaja — Misiones` - 23 edges
8. `Los blancos (la policía, a las órdenes de Buenrostro)` - 22 edges
9. `Nombres propios` - 22 edges
10. `Germán Lazcano` - 21 edges

## Surprising Connections (you probably didn't know these)
- `Repartir garrafones` --semantically_similar_to--> `Reparto (versión corta y repetible del reparto clandestino)`  [INFERRED] [semantically similar]
  especificaciones.md → misiones.md
- `Índice de deterioro = índice de infección` --semantically_similar_to--> `Índice de deterioro = índice de infección`  [INFERRED] [semantically similar]
  especificaciones.md → lore.md
- `El pozo del templo (solo de Chuy)` --conceptually_related_to--> `1.5b El pozo de doña Refugio es real`  [AMBIGUOUS]
  lore.md → revision-historia.md
- `Puri-GelA (purificadoras)` --semantically_similar_to--> `Purificadora (Puri-GelA)`  [INFERRED] [semantically similar]
  lore.md → especificaciones.md
- `Cruces de caca (calcomanía y NPC)` --semantically_similar_to--> `Las cruces de caca`  [INFERRED] [semantically similar]
  especificaciones.md → lore.md

## Hyperedges (group relationships)
- **Las tres fortalezas (Santa Mugre, La Gotera, los Reservorios)** — lore_tres_fortalezas, lore_parques_de_santa_mugre, lore_la_gotera, lore_los_reservorios, lore_agua_en_fortalezas, lore_quien_sabe_que [EXTRACTED 1.00]
- **Las palancas que cambian la ciudad (la cura, la válvula, la verdad)** — lore_cambio_ciudad, lore_capilla_del_tinaco, lore_la_valvula, lore_radio_pirata, lore_estado_del_mundo [EXTRACTED 1.00]
- **Las tres aguas (Agua Cero, GelA Total, agua viva)** — lore_tres_aguas, lore_agua_cero, lore_gela_total, lore_agua_viva, lore_serenol [EXTRACTED 1.00]
- **La compañía de agua: tres socios y su chofer** — personajes_el_nocturno, personajes_chava, personajes_gabriel_hinojosa, personajes_nacho_garrafón, personajes_el_gremio [EXTRACTED 1.00]
- **La sangre de Marcial (Germán, la Mojiganga, Dr. López, medios hermanos)** — personajes_el_nocturno, personajes_germán_lazcano, lore_la_mojiganga, personajes_dr_lópez, personajes_georgina_gela_lazcano, personajes_gerardo_lazcano [EXTRACTED 1.00]
- **Los cinco choques del canon (§1)** — revision_historia_choque_gotera_venden_agua, revision_historia_choque_zombis_beben, revision_historia_choque_final_verdad, revision_historia_choque_pista_5, revision_historia_choque_nocturno_botín [EXTRACTED 1.00]
- **Kit del piloto: lo que se lleva a defender el tinaco** — misiones_vela_del_tinaco, items_tablas, items_cinta_canela, items_machete, items_bomba_molotov, items_bocina_con_banda, items_lampara_celular, items_galon_de_agua [EXTRACTED 1.00]
- **Cadena de desbloqueo: reja → cucarrata → mafia → La Gotera → cacerías** — misiones_guardia_de_la_reja, misiones_al_medico, misiones_la_cucarrata, misiones_entregas_punto_a_punto, misiones_puerta_de_la_gotera, misiones_cacerias_de_la_gotera [EXTRACTED 1.00]
- **Molotov: gasolinera, botella y trapo** — items_receta_molotov, items_caguama_vacia, items_trapo, items_gasolina_limon_cereza, items_bomba_molotov, especificaciones_giro_gasolinera [EXTRACTED 1.00]

## Communities (20 total, 0 thin omitted)

### Community 0 - "Items, taller y crafteo"
Cohesion: 0.05
Nodes (67): §1.4 Cómo se apunta y dispara, Amuletos y estampitas, Armas de fuego, Arrojables (lanzamiento en arco), Cartera (autoload: pesos y agua), Combate cuerpo a cuerpo, Crafteo mínimo, Ferretería (+59 more)

### Community 1 - "Canon: GelA, Serenol y premisa"
Cohesion: 0.08
Nodes (41): Agua limpia como recurso caro, Economía: una moneda, pesos, La idea en un párrafo (survival-shooter PS1 en Zapopan real), El mundo en dos capas, Premisa: Historia y mundo (§2), Credencial de GelA, Dinero y agua, Documentos y llaves (+33 more)

### Community 2 - "La revelación y el cobalto"
Cohesion: 0.08
Nodes (47): Casas en obra negra (contaminadas), Acta de ausencia nocturna, Las camadas (zombis dormidos en bodegas de día), Casas en obra negra, Centro de Innovación Hídrica (planta vieja), El cobalto (la varilla del 84), Concesión de Rescate Hídrico (2028), Documento interno G-7 (Ensayo 4) (+39 more)

### Community 3 - "Contratos de noche y el pozo"
Cohesion: 0.10
Nodes (44): Misiones (resumen §6), Oficio y botín del zombi, Refugio con barricadas y tinaco, Sistema de misiones (MisionData, §6.3), Tablas, El agua clandestina, El agua de noche (el negocio del gremio), El botín de los zombis (oficios) (+36 more)

### Community 4 - "La Gotera, la mafia y la válvula"
Cohesion: 0.10
Nodes (43): Bolsa de sal (10 puñados), Diente de la Madre (trofeo), Los colmillos de la Madre (¿quién los compra? sin decidir), Las crías de lombriz (se parten y regeneran; sal, fuego, cabeza), Los cárcamos de GelA (lodo turquesa de Serenol), La diócesis, Entregas de la mafia (punto a punto), La cucarrata (primer jefe) (+35 more)

### Community 5 - "Giros, consumibles y mandados"
Cohesion: 0.09
Nodes (36): Abarrotes, El punto, Farmacia (Guadalaraja / Dr Simio), Gasolinera (Perez), OXO, Purificadora (Puri-GelA), Taquería, Tejuino (carrito) (+28 more)

### Community 6 - "El régimen y el estado del mundo"
Cohesion: 0.11
Nodes (32): La noche sin ley (Ley de Convivencia Nocturna), Policías (solo de día), Agua para Todos (movimiento), La casa de la gobernadora (dentro de los Reservorios), Programa Contención, El régimen, El estado del mundo (cura, enojo, escalón, confianza), Cómo se gobierna con una llave (agua según el voto) (+24 more)

### Community 7 - "Marcial y la sangre Lazcano"
Cohesion: 0.15
Nodes (30): Facciones para misiones, La sed, La tentación (tomar agua de la llave), Salud y estados, La casa Lazcano, El desfile de Día de Muertos de la colonia, Fémur del armazón y flores que no se marchitan, Haciendas de San Jodido (+22 more)

### Community 8 - "Revisión: lo decidido y pendiente"
Cohesion: 0.12
Nodes (27): Tipos de zombi (Flaco, Corredor, Hinchado, Escupidor, Cargador, Botarga), El culto a la empresa, Las dos hambres del zombi (carne y agua sin Serenol), La Gota, Motivos: el tinaco y la Gota, El panzón (propuesta de AG para el gordo), El saltabardas (propuesta de AG), Taxonomía del barrio (flaco, corredor, hinchado, cargador, escupidor, botarga) (+19 more)

### Community 9 - "Santa Mugre, culto y fortalezas"
Cohesion: 0.16
Nodes (26): Tres fortalezas (Santa Mugre, La Gotera, los Reservorios), El agua en las fortalezas (sin Serenol y sin sobreprecio), El agua no siempre se deja tomar (voluntad de la Virgen), La capilla del Tinaco, La noche que falla la reja (defensa del tinaco de Santa Mugre), La gente de fuera (bajo Serenol, no dan misiones), Guardia de la reja (tutorial de la primera horda), Los Garrafones (+18 more)

### Community 10 - "Misiones de día"
Cohesion: 0.10
Nodes (23): Puesto de tacos, Misiones que ya hay (6.0), Comportamiento seguir al jugador, La caminata (procesión nocturna de muertos), Acompañar a alguien, Al médico (Karla, el herido en carretilla), Buscar al perro, Carrera (+15 more)

### Community 11 - "Ciclo, celular y economía"
Cohesion: 0.17
Nodes (14): El celular, Ciclo día/noche (12 min día + 8 min noche), Ciclo principal (core loop), Grupo del barrio, La IA del celular (Sofía), La economía de las dos ciudades, El Último Trago, El grupo del barrio (+6 more)

### Community 12 - "Decisiones grandes y plan"
Cohesion: 0.20
Nodes (10): §1.1 Plataforma y multijugador, §1.3 Qué pasa de noche, §1.5 Qué pasa al morir, §1.6 Alcance de la primera versión jugable, Bolsa recuperable al morir, Decisiones grandes (por votar), Multijugador en navegador: implicaciones técnicas, Plan de trabajo (hitos 0-7) (+2 more)

### Community 13 - "Tazos, mapa y sandbox"
Cohesion: 0.18
Nodes (10): §1.2 Estructura / meta del juego, Álbum de tazos, Bolsas especiales de Takis, Mapa de papel (9 pedazos), Página de habilidades (Cuerpo, Sobrevivir, Negocio), Registro de decisiones, Revelación del tazo por rareza, Sandbox sin fin (+2 more)

### Community 14 - "Tiendas, maquinitas y cruces"
Cohesion: 0.24
Nodes (10): Cruces de caca (calcomanía y NPC), Interiores armados (escena fija en primera persona), Maquinitas de frutas (Cóctel de Frutas), De noche todo cierra y te sacan, Tiendas e interiores, Las cruces de caca, Enganches al diseño, Sacar dinero de máquinas (+2 more)

### Community 15 - "Reparto de NPCs"
Cohesion: 0.31
Nodes (8): Gente de día, NPCs, Barks, Guadalajaja — Personajes, Recurso Persona (.tres), El reparto en números (30 voces, ~600 líneas), Los tres niveles (voz, vendedor, habitante), El veredicto corto

### Community 16 - "Especificaciones e interfaz"
Cohesion: 0.25
Nodes (9): Enemigos, Guadalajaja — Especificaciones del juego, Interfaz (HUD), Look PS1, Música y sonidos, Opción para apagar destellos (epilepsia fotosensible), Pantalla de inicio ('No te tomes el agua.'), Preguntas abiertas (especificaciones §13) (+1 more)

### Community 17 - "Zombis, hordas y director"
Cohesion: 0.29
Nodes (7): Campo de flujo (flow field), Director (estilo Left 4 Dead), Índice de deterioro = índice de infección, Marcador amarillo (flecha estilo GTA SA), Movimiento y cámara, Niveles de detalle de zombis (MultiMesh), Los zombis y las hordas

### Community 18 - "Colorismo y creador de personaje"
Cohesion: 0.33
Nodes (3): Creador de personaje (Marcial López, el Machetes), Modelos 3D: qué hay y qué falta, Tono de piel como sátira del colorismo

### Community 19 - "Modo reto y la libreta"
Cohesion: 0.47
Nodes (6): La libreta del Machetes (antes del Nocturno, bestiario), Partida de 3 noches con jefe (modo reto / piloto de prueba), El jefe (hinchado grande), Modo reto de 3 noches, 4.10 El jefe de la partida es alguien, 4.13 Corazonadas de la libreta del Nocturno (por votar)

## Ambiguous Edges - Review These
- `El pozo del templo (solo de Chuy)` → `1.5b El pozo de doña Refugio es real`  [AMBIGUOUS]
  lore.md · relation: conceptually_related_to

## Knowledge Gaps
- **31 isolated node(s):** `Referencias (Dying Light, Snowpiercer, The Water Knife, Blade Runner, GTA SA, 7 Days to Die, RE/Silent Hill)`, `Cómo se gobierna con una llave (agua según el voto)`, `Teoría: 'le echan algo al agua'`, `Bandas del índice (Sana, Mixta, Tomada, Podrida, Perdida)`, `El saltabardas (propuesta de AG)` (+26 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 32 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Guadalajaja — Lore` connect `Canon: GelA, Serenol y premisa` to `Items, taller y crafteo`, `La revelación y el cobalto`, `Contratos de noche y el pozo`, `La Gotera, la mafia y la válvula`, `El régimen y el estado del mundo`, `Marcial y la sangre Lazcano`, `Revisión: lo decidido y pendiente`, `Santa Mugre, culto y fortalezas`, `Ciclo, celular y economía`, `Tazos, mapa y sandbox`, `Tiendas, maquinitas y cruces`, `Reparto de NPCs`, `Especificaciones e interfaz`, `Colorismo y creador de personaje`?**
  _High betweenness centrality (0.158) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `Serenol (G-7)` (e.g. with `H1 El agua sabe distinto` and `H3 El G-7`) actually correct?**
  _`Serenol (G-7)` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Referencias (Dying Light, Snowpiercer, The Water Knife, Blade Runner, GTA SA, 7 Days to Die, RE/Silent Hill)`, `Cómo se gobierna con una llave (agua según el voto)`, `Teoría: 'le echan algo al agua'` to the rest of the system?**
  _31 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Items, taller y crafteo` be split into smaller, more focused modules?**
  _Cohesion score 0.05004389815627744 - nodes in this community are weakly interconnected._
- **Why does `Guadalajaja — Items` connect `Items, taller y crafteo` to `Especificaciones e interfaz`, `Canon: GelA, Serenol y premisa`, `Contratos de noche y el pozo`, `Giros, consumibles y mandados`?**
  _High betweenness centrality (0.136) - this node is a cross-community bridge._
- **Are the 5 inferred relationships involving `Defender el tinaco (antes Vela del tinaco, piloto P0)` (e.g. with `Defensa del tinaco (la antigua Vela, ahora afuera)` and `Director (estilo Left 4 Dead)`) actually correct?**
  _`Defender el tinaco (antes Vela del tinaco, piloto P0)` has 5 INFERRED edges - model-reasoned connections that need verification._

### Low-confidence Hints
_AMBIGUOUS edges — the extractor was unsure. Verify before acting on these._

- **What is the exact relationship between `El pozo del templo (solo de Chuy)` and `1.5b El pozo de doña Refugio es real`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._