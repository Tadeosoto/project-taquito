# Graph Report - docs  (2026-11-03)

## Corpus Check
- Corpus is ~41,578 words - fits in a single context window. You may not need a graph.

## Summary
- 367 nodes · 810 edges · 12 communities (11 shown, 1 thin omitted)
- Extraction: 82% EXTRACTED · 18% INFERRED · 0% AMBIGUOUS · INFERRED: 142 edges (avg confidence: 0.84)
- Token cost: 318,782 input · 0 output

## Community Hubs (Navigation)
- Reparto y misiones de historia
- Catálogo de items
- Contratos de noche y zombis
- Especificaciones y votos
- Núcleo del lore: GelA y Lazcano
- Misiones de día y tiendas
- La Palmada, el pozo y los Gotera
- Revisión de la historia
- Deterioro, cobalto y lámparas
- Reglas para escribir personajes
- Documentos y llaves
- Colorismo

## God Nodes (most connected - your core abstractions)
1. `Guadalajaja — Personajes` - 42 edges
2. `Guadalajaja — Especificaciones del juego` - 29 edges
3. `Guadalajaja — Revisión de la historia` - 27 edges
4. `Vela del tinaco (piloto P0)` - 27 edges
5. `Guadalajaja — Lore` - 22 edges
6. `Las misiones de día` - 20 edges
7. `Los Gotera` - 19 edges
8. `Serenol (G-7)` - 18 edges
9. `Georgina "Gela" Lazcano` - 18 edges
10. `GelA (Grupo Hídrico GelA)` - 16 edges

## Surprising Connections (you probably didn't know these)
- `El agua no es moneda: es un recurso caro` --semantically_similar_to--> `Agua limpia como recurso caro`  [INFERRED] [semantically similar]
  items.md → especificaciones.md
- `La IA del celular (Sofía)` --references--> `Sofía — la radio pirata`  [INFERRED]
  especificaciones.md → personajes.md
- `Guadalajaja — Revisión de la historia` --references--> `Guadalajaja — Lore`  [INFERRED]
  revision-historia.md → lore.md
- `El mundo en dos capas` --references--> `GelA (Grupo Hídrico GelA)`  [EXTRACTED]
  especificaciones.md → lore.md
- `Credencial de GelA` --references--> `GelA (Grupo Hídrico GelA)`  [EXTRACTED]
  items.md → lore.md

## Hyperedges (group relationships)
- **Las tres aguas** — lore_agua_cero, lore_gela_total, lore_agua_viva [EXTRACTED 1.00]
- **El estado-empresa: agua, ley y voto** — personajes_germán_lazcano, personajes_georgina_gela_lazcano, lore_gela, lore_voto_de_la_llave, lore_serenol [INFERRED 0.85]
- **Fuentes de agua sin Serenol** — lore_capilla_del_tinaco, lore_pozo_de_los_abuelos, lore_la_valvula [EXTRACTED 1.00]
- **Espejos de la tentación de la llave** — personajes_el_nocturno, personajes_beto_ríos, personajes_yolanda, personajes_tentación_de_la_llave [INFERRED 0.85]
- **El régimen responde en escalones** — personajes_georgina_gela_lazcano, personajes_saúl_buenrostro, personajes_inspector_nava, personajes_respuesta_del_régimen_en_escalones, revision_historia_régimen_no_reacciona [EXTRACTED 1.00]
- **La disputa por el pozo de La Palmada** — personajes_doña_refugio, personajes_chava, personajes_pozo_de_refugio, personajes_el_tinaco_que_no_se_vacía [EXTRACTED 1.00]
- **Kit y bucle del piloto Vela del tinaco** — misiones_vela_del_tinaco, misiones_tres_oleadas, misiones_tinaco_con_vida, items_tablas, items_cinta_canela, items_bocina_con_banda, items_galon_de_agua, items_bomba_molotov [EXTRACTED 1.00]
- **Economía del agua: recurso caro, purificar es delito** — especificaciones_agua_limpia_recurso_caro, items_receta_agua_limpia, items_cloralex, items_agua_sucia, items_galon_de_agua, especificaciones_giro_purificadora, lore_decreto_47 [INFERRED 0.85]
- **Cadena de pistas de La revelación** — misiones_el_agua_sabe_distinto, misiones_los_zombis_eran_vecinos, misiones_el_g_7, misiones_el_decreto_47, misiones_la_presa_esta_llena, misiones_la_verdad [EXTRACTED 1.00]

## Communities (12 total, 1 thin omitted)

### Community 0 - "Reparto y misiones de historia"
Cohesion: 0.07
Nodes (60): Mapa de papel (9 pedazos), La casa de la gobernadora, Centro de Innovación Hídrica (planta vieja), El celular, El Mante Tieso, El Último Trago, El estado del mundo (cura, enojo, escalón, confianza), El grupo del barrio (+52 more)

### Community 1 - "Catálogo de items"
Cohesion: 0.05
Nodes (58): §1.4 Cómo se apunta y dispara, Armas de fuego, Arrojables (lanzamiento en arco), Combate cuerpo a cuerpo, Crafteo mínimo, Gasolinera (Perez), Inventario estilo Resident Evil (inspirado en Silent Hill 2), Lock-on automático (+50 more)

### Community 2 - "Contratos de noche y zombis"
Cohesion: 0.06
Nodes (48): Campo de flujo (flow field), Cartera (autoload: pesos y agua), El celular, Director (estilo Left 4 Dead), Economía: una moneda, pesos, Grupo del barrio, La IA del celular (Sofía), Índice de deterioro = índice de infección (+40 more)

### Community 3 - "Especificaciones y votos"
Cohesion: 0.05
Nodes (42): §1.1 Plataforma y multijugador, §1.2 Estructura / meta del juego, §1.3 Qué pasa de noche, §1.5 Qué pasa al morir, §1.6 Alcance de la primera versión jugable, Álbum de tazos, Bolsa recuperable al morir, Bolsas especiales de Takis (+34 more)

### Community 4 - "Núcleo del lore: GelA y Lazcano"
Cohesion: 0.12
Nodes (32): Facciones para misiones, Premisa: Historia y mundo (§2), Agua Cero (el caldo), Agua para Todos (movimiento), La casa Lazcano, Concesión de Rescate Hídrico (2028), El consentimiento fabricado, Programa Contención (+24 more)

### Community 5 - "Misiones de día y tiendas"
Cohesion: 0.06
Nodes (34): Enemigos, Abarrotes, El punto, Farmacia (Guadalaraja / Dr Simio), Ferretería, OXO, Puesto de tacos, Purificadora (Puri-GelA) (+26 more)

### Community 6 - "La Palmada, el pozo y los Gotera"
Cohesion: 0.16
Nodes (27): Agua limpia como recurso caro, El agua clandestina, Agua viva, La capilla del Tinaco, La diócesis, La Gotera (zona), La Palmada, La válvula (+19 more)

### Community 7 - "Revisión de la historia"
Cohesion: 0.21
Nodes (3): Beto Ríos, El Nocturno, Guadalajaja — Revisión de la historia

### Community 8 - "Deterioro, cobalto y lámparas"
Cohesion: 0.18
Nodes (12): Casas en obra negra (contaminadas), Cruces de caca (calcomanía y NPC), Las lámparas del 84 ('la luz que te chupa'), Bandas del índice (Sana, Mixta, Tomada, Podrida, Perdida), Casas en obra negra, El cobalto (la varilla del 84), Las cruces de caca, El jefe (hinchado grande) (+4 more)

### Community 9 - "Reglas para escribir personajes"
Cohesion: 0.22
Nodes (5): Barks, El del colchón (el punto), El franquiciatario de la purificadora, Recurso Persona (.tres), Los vendedores (10 arquetipos por giro)

### Community 10 - "Documentos y llaves"
Cohesion: 0.33
Nodes (6): Credencial de GelA, Documentos y llaves, Llave de un coto, Papel raro, Acta de ausencia, Manifiesto (de la planta)

## Knowledge Gaps
- **71 isolated node(s):** `Bandas del índice (Sana, Mixta, Tomada, Podrida, Perdida)`, `Teoría: 'le echan algo al agua'`, `La diócesis`, `GelA Total`, `El grupo del barrio` (+66 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 74 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Guadalajaja — Especificaciones del juego` connect `Especificaciones y votos` to `Reparto y misiones de historia`, `Catálogo de items`, `Contratos de noche y zombis`, `Núcleo del lore: GelA y Lazcano`, `Misiones de día y tiendas`, `Deterioro, cobalto y lámparas`?**
  _High betweenness centrality (0.328) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `Guadalajaja — Revisión de la historia` (e.g. with `La idea que controla la historia` and `Guadalajaja — Lore`) actually correct?**
  _`Guadalajaja — Revisión de la historia` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Bandas del índice (Sana, Mixta, Tomada, Podrida, Perdida)`, `Teoría: 'le echan algo al agua'`, `La diócesis` to the rest of the system?**
  _71 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Reparto y misiones de historia` be split into smaller, more focused modules?**
  _Cohesion score 0.0675990675990676 - nodes in this community are weakly interconnected._
- **Why does `Guadalajaja — Misiones` connect `Contratos de noche y zombis` to `Reparto y misiones de historia`, `Catálogo de items`, `Especificaciones y votos`, `Misiones de día y tiendas`, `Revisión de la historia`?**
  _High betweenness centrality (0.141) - this node is a cross-community bridge._
- **Are the 4 inferred relationships involving `Vela del tinaco (piloto P0)` (e.g. with `Director (estilo Left 4 Dead)` and `Refugio con barricadas y tinaco`) actually correct?**
  _`Vela del tinaco (piloto P0)` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Should `Catálogo de items` be split into smaller, more focused modules?**
  _Cohesion score 0.05310734463276836 - nodes in this community are weakly interconnected._