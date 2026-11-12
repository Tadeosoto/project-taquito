# Graph Report - scripts  (2026-11-12)

## Corpus Check
- 220 files · ~0 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2726 nodes · 6729 edges · 114 communities (109 shown, 5 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `24cd8b3`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Rebuild after code changes: `"$(cat docs/graphify-out/.graphify_python)" tools/graphify_gdscript.py` (no API cost; `graphify update` can't read .gd).

## Community Hubs (Navigation)
- catrina/Catrina.gd
- scripts/Sonidos.gd
- map/Panzon.gd
- map/Maquinita.gd
- scripts/Personaje.gd
- defensa/DefensaTinaco.gd
- map/Zombie.gd
- mapa/Colonia.gd
- map/Partida.gd
- defensa/Barricada.gd
- map/MisionesMundo.gd
- map/MapPuntos.gd
- scripts/InventoryUI.gd
- scripts/Inventory.gd
- scripts/character_animation.gd
- map/Saltabardas.gd
- mapa/Tianguis.gd
- scripts/Registro.gd
- map/Safehouse.gd
- lombrices/EnjambreLombrices.gd
- scripts/player.gd
- map/Zombis.gd
- map/MapBodegas.gd
- scripts/Mejoras.gd
- map/Refugio.gd
- lombrices/PruebaLombrices.gd
- map/MapCasas.gd
- scripts/Tazos.gd
- interiores/Interior.gd
- lombrices/CarcamoNivel.gd
- scripts/Taller.gd
- catrina/PruebaCatrina.gd
- map/MapBardas.gd
- scripts/InventoryItemData.gd
- interiores/Mostrador.gd
- scripts/TazoRevelacion.gd
- scripts/Inicio.gd
- map/MapAlumbrado.gd
- lombrices/EnjambreLombrices.gd (2)
- map/EfectosPixel.gd
- lombrices/Lanzador.gd
- lombrices/MadreCarcamo.gd
- map/RestosZombi.gd
- map/Ciclo.gd
- scripts/AlbumTazos.gd
- interiores/MueblesCasa.gd
- map/Gente.gd
- map/Liquido.gd
- map/Supervivencia.gd
- scripts/Pruebas.gd
- lombrices/Bocina.gd
- lombrices/MallaLombriz.gd
- lombrices/MadreCarcamo.gd (2)
- interiores/TallerUI.gd
- map/CampoFlujo.gd
- scripts/Materiales.gd
- scripts/Tiliches.gd
- scripts/player.gd (2)
- scripts/MenuTest.gd
- scripts/Bonos.gd
- scripts/Habilidades.gd
- lombrices/CampoDistancia.gd
- lombrices/EnjambreLombrices.gd (3)
- map/LocalesPreview.gd
- map/MapStreamer.gd
- scenes/mapa.tscn
- catrina/CatrinaProvisional.gd
- map/CargaCuadro.gd
- lombrices/BotellaMolotov.gd
- interiores/CasaVecino.gd
- scripts/HabilidadesUI.gd
- interiores/Refrigerador.gd
- lombrices/Arrojadizo.gd
- lombrices/ZonaLombrices.gd
- scripts/player.gd (3)
- interiores/Interiores.gd
- catrina/PruebaCatrina.gd (2)
- map/Chatarra.gd
- mapa/CarrosModelo.gd
- scenes/map_test.tscn
- map/Deterioro.gd
- personajes/Civiles.gd
- scripts/npc.gd
- interiores/Gasolinera.gd
- lombrices/SolverLombrices.gd
- scripts/MejorasUI.gd
- scripts/player.gd (4)
- scripts/player.gd (5)
- map/NinoTazos.gd
- interiores/Estante.gd
- map/Director.gd
- scripts/player.gd (6)
- scenes/defensa_tinaco.tscn
- interiores/TiendaUI.gd
- map/MapPostImport.gd
- scripts/player.gd (7)
- scripts/PruebasUI.gd
- interiores/Trompo.gd
- scripts/MariposaMonarca.gd
- interiores/Mesa.gd
- scenes/locales_preview.tscn
- lombrices/Palomita.gd
- catrina/Rompible.gd
- interiores/Vitrina.gd
- map/Senuelo.gd
- map/TiendaPostImport.gd
- scripts/CasaPersonaje.gd
- scripts/Tazos.gd (2)
- map/BolsaMuerte.gd
- interiores/purificadora.tscn
- catrina/ArbolJardinera.gd

## God Nodes (most connected - your core abstractions)
1. `player.gd (Player)` - 150 edges
2. `tocar()` - 78 edges
3. `sonido()` - 69 edges
4. `Tazos.gd [autoload]` - 52 edges
5. `Registro.gd [autoload]` - 43 edges
6. `_a_wav()` - 41 edges
7. `Personaje.gd [autoload]` - 35 edges
8. `Inventory.gd [autoload]` - 34 edges
9. `_vacio()` - 33 edges
10. `_contar()` - 28 edges

## Surprising Connections (you probably didn't know these)
- `_utilizar()` --calls--> `usar_estampita()`  [EXTRACTED]
  scripts/InventoryUI.gd → scripts/Bonos.gd
- `_actualizar()` --calls--> `texto_estampitas()`  [EXTRACTED]
  scripts/HabilidadesUI.gd → scripts/Bonos.gd
- `_ready()` --calls--> `poner_modelo()`  [EXTRACTED]
  scripts/interiores/Yonke.gd → scripts/map/Gente.gd
- `_abrir_bolsa()` --calls--> `es_repetido()`  [EXTRACTED]
  scripts/InventoryUI.gd → scripts/Tazos.gd
- `sonar_punado()` --calls--> `tocar()`  [EXTRACTED]
  scripts/lombrices/Lanzador.gd → scripts/Sonidos.gd

## Import Cycles
- None detected.

## Communities (114 total, 5 thin omitted)

### Community 0 - "catrina/Catrina.gd"
Cohesion: 0.07
Nodes (102): _adornar(), _agachada(), _agarrar(), _al_jugador(), _al_jugador_previsto(), _alcanzar(), _animar(), _aretes() (+94 more)

### Community 1 - "scripts/Sonidos.gd"
Cohesion: 0.07
Nodes (85): _guardar(), _init(), malla(), _material(), _physics_process(), _ready(), soltar(), _al_chocar() (+77 more)

### Community 2 - "map/Panzon.gd"
Cohesion: 0.07
Nodes (65): Libreta.gd [autoload], _avisar(), _cargar(), _guardar(), leer(), llenar(), matar(), nivel() (+57 more)

### Community 3 - "map/Maquinita.gd"
Cohesion: 0.06
Nodes (68): chispas(), _cohete(), _disparar(), lanzar(), _voz(), _actualizar_aviso(), _al_entrar(), _al_salir() (+60 more)

### Community 4 - "scripts/Personaje.gd"
Cohesion: 0.06
Nodes (64): _aceptar(), _actualizar(), _armar(), _boton(), _cambiar(), _deslizador(), _elegir(), _fila() (+56 more)

### Community 5 - "defensa/DefensaTinaco.gd"
Cohesion: 0.06
Nodes (58): _al_suelo(), _aplicar_godmode(), _aplicar_mejoras(), _aplicar_noche(), _armar_fundido(), _armar_hud(), _armar_paredes(), _avanzar_noche() (+50 more)

### Community 6 - "map/Zombie.gd"
Cohesion: 0.08
Nodes (62): la_que_oye(), alertar(), _animar(), _arder(), _armar_ancla(), _armar_barra(), _atacar(), _ataque_dura() (+54 more)

### Community 7 - "mapa/Colonia.gd"
Cohesion: 0.07
Nodes (55): _afuera(), _entrar(), _fundir(), _limpiar(), _marcador(), _mostrar_letrero(), _physics_process(), _poner_jugador() (+47 more)

### Community 8 - "map/Partida.gd"
Cohesion: 0.07
Nodes (52): _amanecio(), _trofeo(), zombi_muerto(), _armar_pantalla(), _ganar(), _lugares_de_piezas(), _otra_vez(), _perder() (+44 more)

### Community 9 - "defensa/Barricada.gd"
Cohesion: 0.07
Nodes (55): _acostado(), _afuera(), _anaquel(), _angulos_huecos(), _armar_anillo(), _caja(), _caja_cuerpo(), _caja_de() (+47 more)

### Community 10 - "map/MisionesMundo.gd"
Cohesion: 0.07
Nodes (51): _actualizar_signos(), _amanecio(), _anochecio(), _apuntar(), _apuntar_al_punto_cercano(), _armar_pantalla(), _cambio(), _cargar_datos() (+43 more)

### Community 11 - "map/MapPuntos.gd"
Cohesion: 0.08
Nodes (59): _achicar_calentando(), _animar(), _anuncio(), _armar_interior(), avisar(), _caja_detalle(), _caja_solida(), _calentar() (+51 more)

### Community 12 - "scripts/InventoryUI.gd"
Cohesion: 0.09
Nodes (55): _get_active_model(), _process(), reset_for_new_item(), set_inspection_active(), _unhandled_input(), abrir(), _abrir_album(), _abrir_bolsa() (+47 more)

### Community 13 - "scripts/Inventory.gd"
Cohesion: 0.06
Nodes (44): Baul.gd [autoload], cabe(), guardar(), _lugar_de(), sacar(), signal cambio, _cerrar(), _datos() (+36 more)

### Community 14 - "scripts/character_animation.gd"
Cohesion: 0.06
Nodes (29): _apuntar(), _girar(), _process_modification_with_delta(), _abortar_accion(), accion(), _armar_arbol(), bloquear(), _clip() (+21 more)

### Community 15 - "map/Saltabardas.gd"
Cohesion: 0.11
Nodes (46): _brincar(), _buscar_suelo(), _cabe(), _chispa(), _cofre(), _cuad(), _entro(), _jalar() (+38 more)

### Community 16 - "mapa/Tianguis.gd"
Cohesion: 0.09
Nodes (40): _caja(), _calle(), _material(), _ready(), pieza(), _relativo(), _sacar(), _aabb() (+32 more)

### Community 17 - "scripts/Registro.gd"
Cohesion: 0.10
Nodes (37): Registro.gd [autoload], _actualizar_contexto(), _ahora(), _cerrar_ola(), _clase(), compra(), _csv_linea(), emboscada() (+29 more)

### Community 18 - "map/Safehouse.gd"
Cohesion: 0.11
Nodes (34): reiniciar(), _actualizar_hud_carrera(), _armar_hud_carrera(), _armar_panel(), _carrera(), _casas(), _crear_personaje(), _efectos_demo() (+26 more)

### Community 19 - "lombrices/EnjambreLombrices.gd"
Cohesion: 0.10
Nodes (31): firma(), _aplicar_ordenes(), _armar(), _armar_anillo(), _armar_sangre(), _calidad(), _chorro(), _crecer() (+23 more)

### Community 20 - "scripts/player.gd"
Cohesion: 0.08
Nodes (22): player.gd (Player), _ajustar_caida(), _arco_sal(), _camara_al_hombro(), canon(), cargador(), cargar(), corredera() (+14 more)

### Community 21 - "map/Zombis.gd"
Cohesion: 0.12
Nodes (28): _aparecer(), aparecer_jefe(), aparecer_saltabardas(), aparecer_turba(), _armar(), _armar_reserva(), _atacado(), _campo_tinaco() (+20 more)

### Community 22 - "map/MapBodegas.gd"
Cohesion: 0.14
Nodes (30): _acomodar_adentro(), _agregar(), _armar_bodega(), _blanco(), _caja(), _colision(), _crear_celda(), _cuerpo() (+22 more)

### Community 23 - "scripts/Mejoras.gd"
Cohesion: 0.14
Nodes (25): agregar(), _de_agua(), _de_rayos(), estallar(), _modo(), _mover_nubes(), _process(), _soltar_nube() (+17 more)

### Community 24 - "map/Refugio.gd"
Cohesion: 0.12
Nodes (24): abierta(), _actualizar(), armar(), _indice_tabla(), interact(), is_player_inside(), llena(), recibir_golpe() (+16 more)

### Community 25 - "lombrices/PruebaLombrices.gd"
Cohesion: 0.12
Nodes (22): lanzar(), explotar_en_mira(), rayo(), _escupir(), _armar_vida(), _arrojables(), _avisar(), _empezar() (+14 more)

### Community 26 - "map/MapCasas.gd"
Cohesion: 0.14
Nodes (27): grafiti(), medida(), quad(), _aabb_fachada(), _blanco(), _compactar(), _con_lods(), _cortar() (+19 more)

### Community 27 - "scripts/Tazos.gd"
Cohesion: 0.13
Nodes (28): Tazos.gd [autoload], abrir_bolsa(), bajar(), cambiar(), costo_siguiente(), dar_tazo(), es_repetido(), espacio_extra() (+20 more)

### Community 28 - "interiores/Interior.gd"
Cohesion: 0.18
Nodes (26): activar(), _block(), _caja(), _calle(), camara(), _cambiar(), _comprar(), _cuarto() (+18 more)

### Community 29 - "lombrices/CarcamoNivel.gd"
Cohesion: 0.20
Nodes (27): _barandal(), _barandal_alberca(), _caja(), _cilindro(), _cuesta(), _decal(), _escaleras(), _gota_azul() (+19 more)

### Community 30 - "scripts/Taller.gd"
Cohesion: 0.21
Nodes (25): _actualizar(), _detalle(), mostrar(), dato(), icono(), nombre(), dato(), de_juego() (+17 more)

### Community 31 - "catrina/PruebaCatrina.gd"
Cohesion: 0.16
Nodes (25): _adornos(), _avisar(), _bot_fin_intento(), _bot_mirar(), _bot_preparar(), _bot_terminar(), _bot_zombi_cerca(), _capturar() (+17 more)

### Community 32 - "map/MapBardas.gd"
Cohesion: 0.19
Nodes (23): cargar(), _agregar(), _barda(), _blanco(), _bloque(), _brazo(), _caja(), _calcomania() (+15 more)

### Community 33 - "scripts/InventoryItemData.gd"
Cohesion: 0.13
Nodes (9): _persona(), _ready(), _reconstruir(), _tela(), medir(), _ready(), _reconstruir(), crear_modelo() (+1 more)

### Community 34 - "interiores/Mostrador.gd"
Cohesion: 0.25
Nodes (23): _anaquel(), _armar(), _caja(), _caja_registradora(), _cajonera(), _cilindro(), _disco(), _etiqueta() (+15 more)

### Community 35 - "scripts/TazoRevelacion.gd"
Cohesion: 0.17
Nodes (21): _animar(), _armar_mundo(), _armar_pantalla(), _arriba_final(), _correr(), crear_disco(), _destello(), _en_pantalla() (+13 more)

### Community 36 - "scripts/Inicio.gd"
Cohesion: 0.21
Nodes (21): _abrir(), _activar(), _caja(), _crear_personaje(), _dither(), _empezar_ambiente(), _escena(), _fundir_ambiente() (+13 more)

### Community 37 - "map/MapAlumbrado.gd"
Cohesion: 0.18
Nodes (21): _process(), _process(), encendida(), estado(), _h(), noche(), parpadeo(), _por_zona() (+13 more)

### Community 38 - "lombrices/EnjambreLombrices.gd (2)"
Cohesion: 0.15
Nodes (23): _ancla(), _armar_bola(), _armar_latigo(), _buscar_zombi(), _colocar_bola(), _empezar_subida(), _escribir(), _fx() (+15 more)

### Community 39 - "map/EfectosPixel.gd"
Cohesion: 0.15
Nodes (19): _adornar_cielo(), _adornar_plaza(), _plaza_en_frenesi(), cambiar(), cuadro_bucle(), hoja_de(), lanzar(), malla_quad() (+11 more)

### Community 40 - "lombrices/Lanzador.gd"
Cohesion: 0.19
Nodes (17): cuantos(), _desde_mano(), _destino_carga(), _dir_punado(), lanzar(), _modelo_en_mano(), _poner_en_mano(), _process() (+9 more)

### Community 41 - "lombrices/MadreCarcamo.gd"
Cohesion: 0.23
Nodes (19): apply_explosion_impulse(), bullet_hit(), _chocar(), _esfera(), _expuesto(), golpe_cuerpo(), _herir(), _liquido() (+11 more)

### Community 42 - "map/RestosZombi.gd"
Cohesion: 0.18
Nodes (17): _acostado(), _agregar(), _armar_piezas(), _armar_rafaga(), _armar_solidos(), _barra(), _bolsa(), _caja() (+9 more)

### Community 43 - "map/Ciclo.gd"
Cohesion: 0.15
Nodes (12): _aplicar(), _process(), _ready(), reiniciar_noche(), saltar(), signal amanecio, signal anochecio, signal aviso_atardecer (+4 more)

### Community 44 - "scripts/AlbumTazos.gd"
Cohesion: 0.17
Nodes (15): _actualizar(), _armar_vista(), _label(), manejar(), mostrar(), _mostrar_tazo(), _ready(), texto_puntos() (+7 more)

### Community 45 - "interiores/MueblesCasa.gd"
Cohesion: 0.20
Nodes (14): _avisar(), _caja(), _cilindro(), _dormir(), _mat(), _mueble(), _poner_altar(), _poner_baul() (+6 more)

### Community 46 - "map/Gente.gd"
Cohesion: 0.24
Nodes (18): _altura(), _armar_reserva(), _caminar(), _cargar_banquetas(), _cargar_lugares(), _celda(), _fin_de_linea(), _guardar() (+10 more)

### Community 47 - "map/Liquido.gd"
Cohesion: 0.22
Nodes (17): _al_azar(), _apagar_manchas(), _atlas_manchas(), _caer(), limpiar(), _mancha(), _mover(), _multimesh() (+9 more)

### Community 48 - "map/Supervivencia.gd"
Cohesion: 0.22
Nodes (16): _apagar(), _armar_barra(), _armar_impacto(), avisar(), _cambio_vida(), _desmayarse(), _efectos(), _gotear() (+8 more)

### Community 49 - "scripts/Pruebas.gd"
Cohesion: 0.16
Nodes (12): Pruebas.gd [autoload], _asegurar_carpeta(), carpeta_actual(), _carpeta_arg(), empezar_noche(), iniciar_godmode(), _nombre_modo(), nueva_carrera() (+4 more)

### Community 50 - "lombrices/Bocina.gd"
Cohesion: 0.21
Nodes (12): _init(), malla(), _material(), _textura_tela(), centro_botella(), _contorno(), _init(), malla_cinta() (+4 more)

### Community 51 - "lombrices/MallaLombriz.gd"
Cohesion: 0.24
Nodes (17): _armar_mallas(), _pintar(), _pintar(), _ready(), _siguiente_saco(), aleta(), _anillos(), cabeza() (+9 more)

### Community 52 - "lombrices/MadreCarcamo.gd (2)"
Cohesion: 0.22
Nodes (18): _apuntar_embestida(), _cabeza_a(), _cambiar(), _dentro(), _descansar(), _en_alberca(), _fase(), _fx() (+10 more)

### Community 53 - "interiores/TallerUI.gd"
Cohesion: 0.17
Nodes (11): decir(), _hacer(), _input(), _label(), _ready(), _sonar(), activar(), linea_hecho() (+3 more)

### Community 54 - "map/CampoFlujo.gd"
Cohesion: 0.21
Nodes (13): adelante(), avanzar(), _celda(), _cruza_pared(), direccion(), direccion_suave(), _empezar(), _indice() (+5 more)

### Community 55 - "scripts/Materiales.gd"
Cohesion: 0.25
Nodes (14): botin(), chatarra(), comun(), de_clase(), _sumar(), _actualizar(), _armar_materiales(), _armar_vitrina() (+6 more)

### Community 56 - "scripts/Tiliches.gd"
Cohesion: 0.26
Nodes (16): es_trofeo(), Tiliches.gd [autoload], alcanza(), avisar(), avisar_sin_cangurera(), _cargar_vitrina(), cuantos(), dar() (+8 more)

### Community 57 - "scripts/player.gd (2)"
Cohesion: 0.21
Nodes (17): _a_punos(), _atacar(), _barriendo(), _combo_desde(), _especiales(), _mirar_atras(), _nearby_interactable(), _ocupado() (+9 more)

### Community 58 - "scripts/MenuTest.gd"
Cohesion: 0.21
Nodes (13): _actualizar(), _boton(), _cargar(), _ciclar_dificultad(), _ciclar_duracion(), _economia(), _espacio(), _label() (+5 more)

### Community 59 - "scripts/Bonos.gd"
Cohesion: 0.19
Nodes (13): Bonos.gd [autoload], factor_alcance(), factor_fuerza(), factor_pesos(), factor_recibido(), luz(), petalos(), signal cambio (+5 more)

### Community 60 - "scripts/Habilidades.gd"
Cohesion: 0.18
Nodes (15): costo_total(), dato(), efecto_texto(), icono(), orden(), _actualizar_detalle(), _armar_detalle(), _armar_lista() (+7 more)

### Community 61 - "lombrices/CampoDistancia.gd"
Cohesion: 0.18
Nodes (8): cargar(), _hay_algo(), hornear_paso(), _llegar(), _ocupar(), _repartir(), _sembrar(), _terminar()

### Community 62 - "lombrices/EnjambreLombrices.gd (3)"
Cohesion: 0.35
Nodes (16): apply_explosion_impulse(), bullet_hit(), _cortar(), _es_bola(), golpe_cuerpo(), _herir_bola(), _limpiar_bloque(), _limpiar_tramo() (+8 more)

### Community 63 - "map/LocalesPreview.gd"
Cohesion: 0.25
Nodes (14): _calle(), _captura(), _capturas(), _enter_tree(), _esperar(), _guardar(), _hilera(), _plano() (+6 more)

### Community 64 - "map/MapStreamer.gd"
Cohesion: 0.23
Nodes (13): _add(), _distance(), _poll_requests(), _process(), _quitar_brinco(), _ready(), capa(), configurar() (+5 more)

### Community 65 - "scenes/mapa.tscn"
Cohesion: 0.16
Nodes (5): _ready(), _set_active(), _unhandled_input(), _malla(), _ready()

### Community 66 - "catrina/CatrinaProvisional.gd"
Cohesion: 0.29
Nodes (9): _bola(), _brazo(), _caja(), _capsula(), _cono(), _marca(), _mat(), _ready() (+1 more)

### Community 67 - "map/CargaCuadro.gd"
Cohesion: 0.23
Nodes (9): _crear_celda(), _crear_pendientes(), _esfera(), _malla_arbol(), _process(), _punto(), _ready(), _tri() (+1 more)

### Community 68 - "lombrices/BotellaMolotov.gd"
Cohesion: 0.22
Nodes (8): _agregar(), _init(), malla(), _material(), _textura_etiqueta(), _textura_trapo(), _tira_trapo(), _torno()

### Community 69 - "interiores/CasaVecino.gd"
Cohesion: 0.18
Nodes (5): _avisar(), _botin(), _comprar(), _ready(), crear()

### Community 70 - "scripts/HabilidadesUI.gd"
Cohesion: 0.32
Nodes (13): _actualizar(), _actualizar_fila(), _apagar_cuadro(), _bajar(), _brincar(), _es_derecha(), _es_izquierda(), manejar() (+5 more)

### Community 71 - "interiores/Refrigerador.gd"
Cohesion: 0.30
Nodes (13): _botellas(), _caja(), _juntar(), malla_botella(), _modelos(), _niveles(), _plano(), _ps1() (+5 more)

### Community 72 - "lombrices/Arrojadizo.gd"
Cohesion: 0.25
Nodes (13): _armar_escupitajo(), _cebarse(), es_molotov(), _esfera(), fuego_radio(), letrero(), _mover_escupitajo(), _physics_process() (+5 more)

### Community 73 - "lombrices/ZonaLombrices.gd"
Cohesion: 0.25
Nodes (11): _bucles(), _contorno_en(), crear(), _disco(), estallido(), lengua(), _llamas(), patear() (+3 more)

### Community 74 - "scripts/player.gd (3)"
Cohesion: 0.20
Nodes (14): atrapado(), atrapar(), aventar_molotov(), aventar_sal(), caer(), _cancelar_carga(), _cortar_estocada(), _empezar_clavado() (+6 more)

### Community 75 - "interiores/Interiores.gd"
Cohesion: 0.33
Nodes (11): _acercar(), _alejar(), _echar(), _entrar(), _fundir(), _label(), mostrar_afuera(), _mostrar_letrero() (+3 more)

### Community 76 - "catrina/PruebaCatrina.gd (2)"
Cohesion: 0.28
Nodes (13): _armar_rompibles(), _caja(), _jardinera(), _luces(), _luz_ofrenda(), _mat(), _nivel(), _nivel_cajas() (+5 more)

### Community 77 - "map/Chatarra.gd"
Cohesion: 0.21
Nodes (7): _actualizar_aviso(), interact(), _pieza(), _ready(), _actualizar_aviso(), _ready(), _poner_pieza_prueba()

### Community 78 - "mapa/CarrosModelo.gd"
Cohesion: 0.33
Nodes (11): _multimesh(), _ready(), base(), crear(), _limpias(), _llave(), malla(), quemado() (+3 more)

### Community 79 - "scenes/map_test.tscn"
Cohesion: 0.26
Nodes (9): _crear_celda(), _distancia(), _malla_mata(), _process(), _ready(), _valor(), _caja(), _marcador() (+1 more)

### Community 80 - "map/Deterioro.gd"
Cohesion: 0.30
Nodes (9): configurar(), _hash(), relativo(), _ruido(), _setting(), tipo_pasto(), zona(), _enter_tree() (+1 more)

### Community 81 - "personajes/Civiles.gd"
Cohesion: 0.26
Nodes (10): _persona(), _armar_caminante(), _process(), _punto(), _ready(), al_azar(), calentar(), elegir() (+2 more)

### Community 82 - "scripts/npc.gd"
Cohesion: 0.30
Nodes (10): _actualizar_pantallas(), _apply_prompt_key(), _apply_tint(), _input(), interact(), _on_body_entered(), _on_body_exited(), _play_idle() (+2 more)

### Community 83 - "interiores/Gasolinera.gd"
Cohesion: 0.44
Nodes (10): _cilindro(), _fondo(), _isla(), _liso(), _luz_dia(), _manguera(), _reconstruir(), _suelo() (+2 more)

### Community 84 - "lombrices/SolverLombrices.gd"
Cohesion: 0.31
Nodes (8): _campo_aprox(), _hilos(), _integrar(), _jalar(), _juntar_parejas(), _limites(), _separar(), step()

### Community 85 - "scripts/MejorasUI.gd"
Cohesion: 0.35
Nodes (9): _actualizar_dinero(), _catalogo_categoria(), comprar(), _label(), mover(), mover_item(), _ready(), _refrescar() (+1 more)

### Community 86 - "scripts/player.gd (4)"
Cohesion: 0.24
Nodes (11): _aplicar_cuerpo(), aplicar_habilidades(), aplicar_personaje(), _armar_estela(), _armar_mano(), cambiar_arma(), _cortar_corredera(), _esqueleto() (+3 more)

### Community 87 - "scripts/player.gd (5)"
Cohesion: 0.31
Nodes (11): _arma(), _brillo_carga(), _conto_espada(), _fogonazo(), _golpear(), _pegar_estocada(), _punta_arma(), _radio_de() (+3 more)

### Community 88 - "map/NinoTazos.gd"
Cohesion: 0.22
Nodes (4): _hablar(), _ready(), _revelar(), abrir()

### Community 89 - "interiores/Estante.gd"
Cohesion: 0.42
Nodes (9): _armar(), _canastilla(), _carita(), _colgados(), _colgar_modelos(), _ganchos(), _rejilla(), _repisas() (+1 more)

### Community 90 - "map/Director.gd"
Cohesion: 0.24
Nodes (4): avanzar(), _cambiar(), _init(), reiniciar()

### Community 91 - "scripts/player.gd (6)"
Cohesion: 0.27
Nodes (10): aturdirte(), _congelar(), _dano_recibido(), efecto(), _parar_golpe(), _pintar_blanco(), recibir_dano(), _revisar_congelada() (+2 more)

### Community 92 - "scenes/defensa_tinaco.tscn"
Cohesion: 0.36
Nodes (4): _a_pantalla(), _dibujar_marcas(), _dibujar_objetivo(), _dibujar_zombis()

### Community 93 - "interiores/TiendaUI.gd"
Cohesion: 0.31
Nodes (5): Cartera.gd [autoload], signal cambio, _dinero(), _label(), _ready()

### Community 94 - "map/MapPostImport.gd"
Cohesion: 0.42
Nodes (8): _build_chunk(), _facade_material(), _ground_material(), _is_building(), _post_import(), _ps1_material(), _scene_transform(), _wants_collision()

### Community 95 - "scripts/player.gd (7)"
Cohesion: 0.28
Nodes (9): beber(), _curarse(), _doble_toque(), _es_direccion(), _guardar(), mirando_atras(), _pedir_accion(), _teclas_mover() (+1 more)

### Community 96 - "scripts/PruebasUI.gd"
Cohesion: 0.43
Nodes (6): _actualizar(), _boton(), _empezar(), _label(), _ready(), _texto_enemigos()

### Community 97 - "interiores/Trompo.gd"
Cohesion: 0.46
Nodes (6): _cilindro(), humo(), _material(), _ready(), _reconstruir(), _torno()

### Community 98 - "scripts/MariposaMonarca.gd"
Cohesion: 0.29
Nodes (6): _dibujo(), _ready(), soltar(), _estela_golpe(), _estela_puno(), _nudillos()

### Community 99 - "interiores/Mesa.gd"
Cohesion: 0.38
Nodes (3): _armar(), _centro(), _silla()

### Community 100 - "scenes/locales_preview.tscn"
Cohesion: 0.33
Nodes (3): configurar_noche(), _process(), _ready()

### Community 101 - "lombrices/Palomita.gd"
Cohesion: 0.48
Nodes (5): _init(), malla(), _material(), _textura(), _tri()

### Community 102 - "catrina/Rompible.gd"
Cohesion: 0.38
Nodes (3): romper(), _tirar_pedazos(), _tumbar()

### Community 103 - "interiores/Vitrina.gd"
Cohesion: 0.38
Nodes (4): _acomodar(), _deslizar(), mostrar(), mover()

### Community 104 - "map/Senuelo.gd"
Cohesion: 0.33
Nodes (4): ondas(), _apagar(), _process(), _ready()

### Community 105 - "map/TiendaPostImport.gd"
Cohesion: 0.52
Nodes (6): _contar_triangulos(), _convert(), _post_import(), _ps1_material(), _recortar(), _reducir()

### Community 106 - "scripts/CasaPersonaje.gd"
Cohesion: 0.60
Nodes (4): _igualar_madera(), _mallas(), _promedio(), _ready()

### Community 107 - "scripts/Tazos.gd (2)"
Cohesion: 0.50
Nodes (5): _actualizar_puntos(), _process(), distintos(), gastados(), libres()

### Community 108 - "map/BolsaMuerte.gd"
Cohesion: 0.60
Nodes (3): _actualizar_aviso(), interact(), _ready()

## Knowledge Gaps
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `player.gd (Player)` connect `scripts/player.gd` to `catrina/Catrina.gd`, `scripts/Sonidos.gd`, `map/Panzon.gd`, `map/Maquinita.gd`, `defensa/DefensaTinaco.gd`, `map/Zombie.gd`, `mapa/Colonia.gd`, `map/Partida.gd`, `map/MisionesMundo.gd`, `map/MapPuntos.gd`, `scripts/InventoryUI.gd`, `scripts/Inventory.gd`, `map/Saltabardas.gd`, `map/Safehouse.gd`, `map/Zombis.gd`, `scripts/Mejoras.gd`, `map/Refugio.gd`, `lombrices/PruebaLombrices.gd`, `catrina/PruebaCatrina.gd`, `scripts/InventoryItemData.gd`, `map/EfectosPixel.gd`, `lombrices/Lanzador.gd`, `map/Supervivencia.gd`, `scripts/player.gd (2)`, `interiores/CasaVecino.gd`, `scripts/player.gd (3)`, `interiores/Interiores.gd`, `map/Chatarra.gd`, `scenes/map_test.tscn`, `scripts/npc.gd`, `scripts/player.gd (4)`, `scripts/player.gd (5)`, `scripts/player.gd (6)`, `scripts/player.gd (7)`, `scripts/MariposaMonarca.gd`, `map/BolsaMuerte.gd`?**
  _High betweenness centrality (0.206) - this node is a cross-community bridge._
- **Should `catrina/Catrina.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.06519246519246519 - nodes in this community are weakly interconnected._
- **Why does `Tazos.gd [autoload]` connect `scripts/Tazos.gd` to `scripts/TazoRevelacion.gd`, `scripts/HabilidadesUI.gd`, `scripts/Tazos.gd (2)`, `scripts/AlbumTazos.gd`, `scripts/InventoryUI.gd`, `scripts/Inventory.gd`, `map/Safehouse.gd`, `scripts/Habilidades.gd`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._
- **Should `scripts/Sonidos.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.06578947368421052 - nodes in this community are weakly interconnected._
- **Why does `Registro.gd [autoload]` connect `scripts/Registro.gd` to `map/Zombie.gd`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **Should `map/Panzon.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.06702702702702702 - nodes in this community are weakly interconnected._
- **Should `map/Maquinita.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.060882800608828 - nodes in this community are weakly interconnected._