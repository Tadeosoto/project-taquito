# Graph Report - docs  (2026-11-11)

## Corpus Check
- 6 files · ~45,101 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 458 nodes · 1182 edges · 22 communities
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 125 edges (avg confidence: 0.82)
- Token cost: 750,544 input · 0 output

## Community Hubs (Navigation)
- GelA, Serenol y el culto
- Catálogo de items
- Cobalto, giros y crafteo
- Misiones de noche y Santa Mugre
- Reparto y facciones
- Revisión de la historia y la verdad
- La revelación (pistas)
- Los Gotera y el agua
- Misiones de día
- Estado del mundo y modos
- Detalles por decidir (los diez)
- Sed, salud y muerte
- Tazos, avatar y colorismo
- Especificaciones e interfaz
- Premisa e índice de deterioro
- Decisiones grandes y plan
- Taxonomía zombi y oleadas
- Jefes: Madre del Cárcamo y Mojiganga
- Los zombis y el agua
- Hordas y director
- Tiendas e interiores
- Taller de La Chava

## God Nodes (most connected - your core abstractions)
1. `Guadalajaja — Personajes` - 48 edges
2. `Guadalajaja — Lore` - 36 edges
3. `Serenol (G-7)` - 29 edges
4. `Guadalajaja — Especificaciones del juego` - 29 edges
5. `Vela del tinaco (piloto P0)` - 25 edges
6. `Guadalajaja — Revisión de la historia` - 23 edges
7. `Georgina "Gela" Lazcano` - 22 edges
8. `La capilla del Tinaco` - 21 edges
9. `Los Gotera` - 21 edges
10. `Las misiones de día` - 21 edges

## Surprising Connections (you probably didn't know these)
- `La Chava — la del yonke` --semantically_similar_to--> `Chava — el nieto`  [AMBIGUOUS] [semantically similar]
  personajes.md → lore.md
- `El sandbox se sostiene solo (el lore no bloquea nada)` --semantically_similar_to--> `Sandbox sin fin`  [INFERRED] [semantically similar]
  lore.md → especificaciones.md
- `El botín de los zombis (oficios)` --semantically_similar_to--> `Oficio y botín del zombi`  [INFERRED] [semantically similar]
  lore.md → especificaciones.md
- `Taxonomía del barrio (flaco, corredor, hinchado, cargador, escupidor, botarga)` --semantically_similar_to--> `Tipos de zombi (Flaco, Corredor, Hinchado, Escupidor, Cargador, Botarga)`  [INFERRED] [semantically similar]
  lore.md → especificaciones.md
- `Sofía — la radio pirata` --conceptually_related_to--> `La IA del celular (Sofía)`  [AMBIGUOUS]
  lore.md → especificaciones.md

## Hyperedges (group relationships)
- **Cambio de zona: agua viva, enojo, verdad** — lore_agua_viva, lore_capilla_del_tinaco, lore_la_valvula, lore_radio_pirata, lore_estado_del_mundo [EXTRACTED 1.00]
- **Control por agua: Serenol, voto de la llave, Decreto 47** — lore_serenol, lore_voto_de_la_llave, lore_decreto_47, lore_agua_cero, lore_gela [INFERRED 0.85]
- **Jefes y especiales propuestos por AG (sin votar)** — lore_madre_del_cárcamo, lore_la_mojiganga, lore_saltabardas, lore_panzon [EXTRACTED 1.00]
- **La casa Lazcano (Germán, Georgina, Gerardo, Buenrostro)** — personajes_germán_lazcano, personajes_georgina_gela_lazcano, personajes_gerardo_lazcano, personajes_saúl_buenrostro, lore_casa_lazcano [EXTRACTED 1.00]
- **Voces en riesgo por tomar de la llave** — personajes_beto_ríos, personajes_yolanda, personajes_tito, personajes_lalo, personajes_inspector_nava, lore_tentacion_llave [INFERRED 0.85]
- **Fuentes de pruebas para la revelación** — personajes_güero, personajes_elena, personajes_dr_lópez, personajes_sofía, personajes_marisol, lore_la_revelacion [INFERRED 0.75]
- **Propuestas de trabajo de AG para el piloto (3 noches, refugio, bolsa, cierre nocturno)** — especificaciones_partida_de_3_noches_modo_reto, especificaciones_refugio_con_barricadas, especificaciones_bolsa_recuperable_al_morir, especificaciones_tiendas_cierran_de_noche [EXTRACTED 1.00]
- **Rarezas del barrio contadas por NPCs (obra negra, lámparas del 84, cruces de caca)** — especificaciones_casas_en_obra_negra, lore_lamparas_84, especificaciones_cruces_de_caca_mecanica [EXTRACTED 1.00]
- **Progresión propuesta por AG (tazos, taller, libreta)** — especificaciones_tazos_y_habilidades, especificaciones_taller_yonke_don_chava, especificaciones_libreta_del_nocturno [INFERRED 0.75]
- **Cadena de pistas de La revelación (H1-H5)** — misiones_el_agua_sabe_distinto, misiones_los_zombis_eran_vecinos, misiones_el_g_7, misiones_el_decreto_47, misiones_la_presa_esta_llena [EXTRACTED 1.00]
- **Cadena del molotov (botella, gasolina, trapo)** — items_receta_molotov, items_caguama_vacia, items_gasolina_limon_cereza, items_trapo, items_bomba_molotov [EXTRACTED 1.00]
- **Motivo de la cartera: los mismos nombres** — revision_historia_tres_motivos, misiones_hoja_de_conteo, personajes_marisol, lore_botin_zombi [INFERRED 0.85]

## Communities (22 total, 0 thin omitted)

### Community 0 - "GelA, Serenol y el culto"
Cohesion: 0.08
Nodes (57): Agua limpia como recurso caro, Facciones para misiones, Purificadora (Puri-GelA), El mundo en dos capas, La noche sin ley (Ley de Convivencia Nocturna), Premisa: Historia y mundo (§2), Acta de ausencia nocturna, El agua no siempre se deja tomar (voluntad de la Virgen) (+49 more)

### Community 1 - "Catálogo de items"
Cohesion: 0.06
Nodes (55): §1.4 Cómo se apunta y dispara, Armas de fuego, Arrojables (lanzamiento en arco), Combate cuerpo a cuerpo, Inventario estilo Resident Evil (inspirado en Silent Hill 2), Lock-on automático, Mochilas (6 base; 8/10/14), Objetos (resumen §5) (+47 more)

### Community 2 - "Cobalto, giros y crafteo"
Cohesion: 0.06
Nodes (48): Amuletos y estampitas, Cartera (autoload: pesos y agua), Casas en obra negra (contaminadas), Crafteo mínimo, Economía: una moneda, pesos, Abarrotes, El punto, Farmacia (Guadalaraja / Dr Simio) (+40 more)

### Community 3 - "Misiones de noche y Santa Mugre"
Cohesion: 0.09
Nodes (41): Ciclo día/noche (12 min día + 8 min noche), Ciclo principal (core loop), Tortillería, Refugio con barricadas y tinaco, Costal de chiles (objeto de misión), Kilo de tortillas (propuesta de AG), El botín de los zombis (oficios), El ciclo del día (+33 more)

### Community 4 - "Reparto y facciones"
Cohesion: 0.09
Nodes (40): Cruces de caca (calcomanía y NPC), Gente de día, NPCs, Comportamiento seguir al jugador, La casa de la gobernadora, Las cruces de caca, La diócesis, El Último Trago (+32 more)

### Community 5 - "Revisión de la historia y la verdad"
Cohesion: 0.09
Nodes (38): El celular, Grupo del barrio, La IA del celular (Sofía), La libreta del Nocturno (bestiario), Tipos de zombi (Flaco, Corredor, Hinchado, Escupidor, Cargador, Botarga), Botiquín del Simi, El consentimiento fabricado, El grupo del barrio (+30 more)

### Community 6 - "La revelación (pistas)"
Cohesion: 0.13
Nodes (25): Oficio y botín del zombi, Credencial de GelA, Documentos y llaves, Llave de un coto, Papel raro, Centro de Innovación Hídrica (planta vieja), Los cuatro canales (ambiente, conversación, papeles, misiones), Documento interno G-7 (Ensayo 4) (+17 more)

### Community 7 - "Los Gotera y el agua"
Cohesion: 0.23
Nodes (22): El agua clandestina, Agua viva, La Gotera (zona), La Palmada, La válvula, La lluvia (legal juntarla, ilegal tomarla), Los Gotera, Pacto Gotera-gobernadora (+14 more)

### Community 8 - "Misiones de día"
Cohesion: 0.17
Nodes (13): Puesto de tacos, Acompañar a alguien, Carrera, Cocinar tacos, Corretear a alguien, Defender el puesto, Encontrar cosas, Las misiones de día (+5 more)

### Community 9 - "Estado del mundo y modos"
Cohesion: 0.21
Nodes (12): §1.2 Estructura / meta del juego, Partida de 3 noches con jefe (modo reto / piloto de prueba), Sandbox sin fin, Cómo cambia la ciudad (agua → enojo → verdad → GelA contesta), El estado del mundo (cura, enojo, escalón, confianza), Modo reto de 3 noches, Regla de oro: ¿qué gana GelA?, Reglas del canon (+4 more)

### Community 10 - "Detalles por decidir (los diez)"
Cohesion: 0.21
Nodes (12): Agua Cero (el caldo), GelA Total, Las tres aguas, 4.5 Agua Cero: el caldo, la de la llave, 4. Detalles (los diez), 4.4 GelA Total: sin Serenol, 4.10 El jefe de la partida es alguien, 4.13 Corazonadas de la libreta del Nocturno (por votar) (+4 more)

### Community 11 - "Sed, salud y muerte"
Cohesion: 0.20
Nodes (11): §1.5 Qué pasa al morir, Bolsa recuperable al morir, Enemigos, La sed, La tentación (tomar agua de la llave), Opción para apagar destellos (epilepsia fotosensible), Policías (solo de día), Preguntas abiertas (especificaciones §13) (+3 more)

### Community 12 - "Tazos, avatar y colorismo"
Cohesion: 0.20
Nodes (11): Álbum de tazos, Bolsas especiales de Takis, Creador de personaje (avatar silencioso), Modelos 3D: qué hay y qué falta, Página de habilidades (Cuerpo, Sobrevivir, Negocio), Revelación del tazo por rareza, 48 tazos en 4 series (La colonia, La noche, Los vecinos, GelA), Tazos y habilidades (+3 more)

### Community 13 - "Especificaciones e interfaz"
Cohesion: 0.22
Nodes (11): Guadalajaja — Especificaciones del juego, Interfaz (HUD), Look PS1, Mapa de papel (9 pedazos), Marcas parodia, Movimiento y cámara, Música y sonidos, Pantalla de inicio ('No te tomes el agua.') (+3 more)

### Community 14 - "Premisa e índice de deterioro"
Cohesion: 0.24
Nodes (10): Juegos de referencia, La idea en un párrafo (survival-shooter PS1 en Zapopan real), Bandas del índice (Sana, Mixta, Tomada, Podrida, Perdida), Guadalajaja — Lore, Enganches al diseño, Índice de deterioro = índice de infección, Nombres propios, Referencias (Dying Light, Snowpiercer, The Water Knife, Blade Runner, GTA SA, 7 Days to Die, RE/Silent Hill) (+2 more)

### Community 15 - "Decisiones grandes y plan"
Cohesion: 0.25
Nodes (9): §1.1 Plataforma y multijugador, §1.3 Qué pasa de noche, §1.6 Alcance de la primera versión jugable, Decisiones grandes (por votar), Multijugador en navegador: implicaciones técnicas, Plan de trabajo (hitos 0-7), Prueba chica web/red (1-2 semanas), Sistema de misiones (MisionData, §6.3) (+1 more)

### Community 16 - "Taxonomía zombi y oleadas"
Cohesion: 0.25
Nodes (8): Misiones (resumen §6), Misiones que ya hay (6.0), El panzón (propuesta de AG para el gordo), El saltabardas (propuesta de AG), Taxonomía del barrio (flaco, corredor, hinchado, cargador, escupidor, botarga), Encargo de compras, La noche en tres oleadas (22:00, 0:00, 3:00, amanecer), 4.6 La botarga zombi: de día bailaba

### Community 17 - "Jefes: Madre del Cárcamo y Mojiganga"
Cohesion: 0.25
Nodes (8): Los colmillos de la Madre (¿quién los compra? sin decidir), Las crías de lombriz (se parten y regeneran; sal, fuego, cabeza), Los cárcamos de GelA (lodo turquesa de Serenol), El desfile de Día de Muertos de la colonia, Fémur del armazón y flores que no se marchitan, La Mojiganga (catrina gigante de cartonería), La Madre del Cárcamo, Por qué 'zombi' es una injusticia (el zombi es la víctima)

### Community 18 - "Los zombis y el agua"
Cohesion: 0.36
Nodes (8): Las dos hambres del zombi (carne y agua sin Serenol), El jefe (hinchado grande), La caminata (procesión nocturna de muertos), La puerta cerrada (el zombi empuja, no abre), Los zombis, La ficha completa de la vela (/game-quest), El galón como cebo (beben y no se llenan), 1.2 ¿Los zombis beben o no?

### Community 19 - "Hordas y director"
Cohesion: 0.38
Nodes (7): Campo de flujo (flow field), Director (estilo Left 4 Dead), Índice de deterioro = índice de infección, Niveles de detalle de zombis (MultiMesh), Los zombis y las hordas, Las camadas (zombis dormidos en bodegas de día), Limpiar una camada

### Community 20 - "Tiendas e interiores"
Cohesion: 0.33
Nodes (6): Interiores armados (escena fija en primera persona), Maquinitas de frutas (Cóctel de Frutas), Marcador amarillo (flecha estilo GTA SA), De noche todo cierra y te sacan, Tiendas e interiores, Sacar dinero de máquinas

### Community 21 - "Taller de La Chava"
Cohesion: 0.40
Nodes (5): Diente de la Madre (trofeo), Juegos de recetas 1-6 (remedios, amuletos, armas), Materiales comunes (6 familias × 3 niveles), El taller de La Chava (propuesta de AG), Trofeos (se quedan entre partidas, en la vitrina)

## Ambiguous Edges - Review These
- `Padre Jesús "Chuy" Arreola` → `Los colmillos de la Madre (¿quién los compra? sin decidir)`  [AMBIGUOUS]
  lore.md · relation: references
- `Sofía — la radio pirata` → `La IA del celular (Sofía)`  [AMBIGUOUS]
  personajes.md · relation: conceptually_related_to
- `Chava — el nieto` → `La Chava — la del yonke`  [AMBIGUOUS]
  personajes.md · relation: semantically_similar_to

## Knowledge Gaps
- **70 isolated node(s):** `Las tres reglas del mundo (agua es poder, la noche es de los muertos, nadie es puro)`, `El chiste del título (Guadalajara + jaja)`, `"Cuando el agua sabía a agua" (medida del tiempo)`, `Agua para Todos (movimiento)`, `Cómo se gobierna con una llave (agua según el voto)` (+65 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 70 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Guadalajaja — Especificaciones del juego` connect `Especificaciones e interfaz` to `GelA, Serenol y el culto`, `Catálogo de items`, `Cobalto, giros y crafteo`, `Misiones de noche y Santa Mugre`, `Reparto y facciones`, `Revisión de la historia y la verdad`, `Sed, salud y muerte`, `Tazos, avatar y colorismo`, `Premisa e índice de deterioro`, `Decisiones grandes y plan`, `Taxonomía zombi y oleadas`, `Hordas y director`, `Tiendas e interiores`?**
  _High betweenness centrality (0.188) - this node is a cross-community bridge._
- **What connects `Las tres reglas del mundo (agua es poder, la noche es de los muertos, nadie es puro)`, `El chiste del título (Guadalajara + jaja)`, `"Cuando el agua sabía a agua" (medida del tiempo)` to the rest of the system?**
  _70 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `GelA, Serenol y el culto` be split into smaller, more focused modules?**
  _Cohesion score 0.08333333333333333 - nodes in this community are weakly interconnected._
- **Why does `Guadalajaja — Personajes` connect `Reparto y facciones` to `GelA, Serenol y el culto`, `Cobalto, giros y crafteo`, `Misiones de noche y Santa Mugre`, `Revisión de la historia y la verdad`, `La revelación (pistas)`, `Los Gotera y el agua`, `Especificaciones e interfaz`, `Premisa e índice de deterioro`?**
  _High betweenness centrality (0.181) - this node is a cross-community bridge._
- **Should `Catálogo de items` be split into smaller, more focused modules?**
  _Cohesion score 0.05723905723905724 - nodes in this community are weakly interconnected._

### Low-confidence Hints
_AMBIGUOUS edges — the extractor was unsure. Verify before acting on these._

- **What is the exact relationship between `Padre Jesús "Chuy" Arreola` and `Los colmillos de la Madre (¿quién los compra? sin decidir)`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `Sofía — la radio pirata` and `La IA del celular (Sofía)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._