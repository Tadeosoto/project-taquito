# Graph Report - scripts  (2026-11-12)

## Corpus Check
- 226 files · ~0 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2756 nodes · 6797 edges · 113 communities (107 shown, 6 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `bd47768`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Rebuild after code changes: `"$(cat docs/graphify-out/.graphify_python)" tools/graphify_gdscript.py` (no API cost; `graphify update` can't read .gd).

## Community Hubs (Navigation)
- catrina/Catrina.gd
- scripts/Sonidos.gd
- map/Maquinita.gd
- lombrices/EnjambreLombrices.gd
- scripts/Personaje.gd
- defensa/DefensaTinaco.gd
- map/Zombie.gd
- map/Partida.gd
- lombrices/CampoDistancia.gd
- map/MisionesMundo.gd
- map/MapPuntos.gd
- map/Supervivencia.gd
- scripts/InventoryUI.gd
- scripts/Inventory.gd
- lombrices/MadreCarcamo.gd
- defensa/Barricada.gd
- scripts/character_animation.gd
- map/Saltabardas.gd
- mapa/Tianguis.gd
- lombrices/PruebaLombrices.gd
- scripts/Registro.gd
- map/Panzon.gd
- map/Safehouse.gd
- map/Zombis.gd
- interiores/TallerUI.gd
- scripts/player.gd
- map/MapBodegas.gd
- scripts/Mejoras.gd
- scripts/Tazos.gd
- map/MapCasas.gd
- map/Refugio.gd
- interiores/Interior.gd
- lombrices/CarcamoNivel.gd
- catrina/PruebaCatrina.gd
- mapa/Colonia.gd
- interiores/Mostrador.gd
- map/MapBardas.gd
- scripts/TazoRevelacion.gd
- scripts/Inicio.gd
- scripts/InventoryItemData.gd
- map/MapAlumbrado.gd
- map/RestosZombi.gd
- lombrices/Lanzador.gd
- scenes/defensa_tinaco.tscn
- scripts/AlbumTazos.gd
- scripts/HabilidadesUI.gd
- map/Gente.gd
- scripts/Pruebas.gd
- lombrices/Bocina.gd
- map/Ciclo.gd
- scripts/Bonos.gd
- interiores/MueblesCasa.gd
- map/CampoFlujo.gd
- scripts/Tiliches.gd
- scripts/player.gd (2)
- scripts/MenuTest.gd
- scripts/TilichesUI.gd
- map/LocalesPreview.gd
- interiores/CasaPropia.gd
- catrina/CatrinaProvisional.gd
- map/PiezaMapa.gd
- map/EfectosPixel.gd
- lombrices/BotellaMolotov.gd
- interiores/Estante.gd
- interiores/Refrigerador.gd
- lombrices/Arrojadizo.gd
- lombrices/ZonaLombrices.gd
- scripts/player.gd (3)
- scenes/npc.tscn
- scenes/map_test.tscn
- catrina/PruebaCatrina.gd (2)
- scripts/Habilidades.gd
- map/MuroColonia.gd
- interiores/Gasolinera.gd
- map/Deterioro.gd
- scripts/Materiales.gd
- map/Chatarra.gd
- scripts/npc.gd
- interiores/CasaVecino.gd
- scripts/MejorasUI.gd
- scripts/player.gd (4)
- scripts/player.gd (5)
- defensa/TinacoDefensa.gd
- map/Director.gd
- personajes/Civiles.gd
- map/MapArboles.gd
- scripts/player.gd (6)
- map/Senuelo.gd
- map/MapPostImport.gd
- scripts/player.gd (7)
- scripts/PruebasUI.gd
- interiores/Trompo.gd
- map/MapMinimapa.gd
- map/NinoTazos.gd
- mapa/CajaGela.gd
- mapa/Palomas.gd
- scripts/MariposaMonarca.gd
- interiores/Mesa.gd
- scenes/locales_preview.tscn
- lombrices/Palomita.gd
- catrina/Rompible.gd
- interiores/Vitrina.gd
- map/TiendaPostImport.gd
- scripts/CasaPersonaje.gd
- interiores/TiendaUI.gd
- mapa/MapaPostImport.gd
- mapa/Campana.gd
- personajes/UniformeGela.gd
- catrina/ArbolJardinera.gd
- mapa/LuzTrampa.gd

## God Nodes (most connected - your core abstractions)
1. `player.gd (Player)` - 150 edges
2. `tocar()` - 78 edges
3. `sonido()` - 71 edges
4. `Tazos.gd [autoload]` - 52 edges
5. `Registro.gd [autoload]` - 43 edges
6. `_a_wav()` - 42 edges
7. `Personaje.gd [autoload]` - 35 edges
8. `Inventory.gd [autoload]` - 34 edges
9. `_vacio()` - 34 edges
10. `_contar()` - 28 edges

## Surprising Connections (you probably didn't know these)
- `_mostrar_tazo()` --calls--> `texto_puntos()`  [EXTRACTED]
  scripts/AlbumTazos.gd → scripts/TazoData.gd
- `_reiniciar()` --calls--> `reiniciar()`  [EXTRACTED]
  scripts/map/Safehouse.gd → scripts/Bonos.gd
- `_utilizar()` --calls--> `usar_estampita()`  [EXTRACTED]
  scripts/InventoryUI.gd → scripts/Bonos.gd
- `_actualizar()` --calls--> `texto_estampitas()`  [EXTRACTED]
  scripts/HabilidadesUI.gd → scripts/Bonos.gd
- `_hacer()` --calls--> `linea_hecho()`  [EXTRACTED]
  scripts/interiores/TallerUI.gd → scripts/interiores/Yonke.gd

## Import Cycles
- None detected.

## Communities (113 total, 6 thin omitted)

### Community 0 - "catrina/Catrina.gd"
Cohesion: 0.07
Nodes (102): _adornar(), _agachada(), _agarrar(), _al_jugador(), _al_jugador_previsto(), _alcanzar(), _animar(), _aretes() (+94 more)

### Community 1 - "scripts/Sonidos.gd"
Cohesion: 0.07
Nodes (84): _guardar(), _init(), malla(), _material(), _physics_process(), _ready(), soltar(), _al_chocar() (+76 more)

### Community 2 - "map/Maquinita.gd"
Cohesion: 0.06
Nodes (70): Cartera.gd [autoload], signal cambio, chispas(), _cohete(), _disparar(), lanzar(), _voz(), _actualizar_aviso() (+62 more)

### Community 3 - "lombrices/EnjambreLombrices.gd"
Cohesion: 0.07
Nodes (71): firma(), _ancla(), _aplicar_ordenes(), apply_explosion_impulse(), _armar(), _armar_anillo(), _armar_bola(), _armar_latigo() (+63 more)

### Community 4 - "scripts/Personaje.gd"
Cohesion: 0.06
Nodes (64): _aceptar(), _actualizar(), _armar(), _boton(), _cambiar(), _deslizador(), _elegir(), _fila() (+56 more)

### Community 5 - "defensa/DefensaTinaco.gd"
Cohesion: 0.06
Nodes (58): _al_suelo(), _aplicar_godmode(), _aplicar_mejoras(), _aplicar_noche(), _armar_fundido(), _armar_hud(), _armar_paredes(), _avanzar_noche() (+50 more)

### Community 6 - "map/Zombie.gd"
Cohesion: 0.08
Nodes (62): la_que_oye(), alertar(), _animar(), _arder(), _armar_ancla(), _armar_barra(), _atacar(), _ataque_dura() (+54 more)

### Community 7 - "map/Partida.gd"
Cohesion: 0.07
Nodes (53): texto_hora(), _amanecio(), _trofeo(), zombi_muerto(), _armar_pantalla(), _ganar(), _lugares_de_piezas(), _otra_vez() (+45 more)

### Community 8 - "lombrices/CampoDistancia.gd"
Cohesion: 0.05
Nodes (44): Libreta.gd [autoload], _avisar(), _cargar(), _guardar(), leer(), llenar(), matar(), nivel() (+36 more)

### Community 9 - "map/MisionesMundo.gd"
Cohesion: 0.07
Nodes (51): _actualizar_signos(), _amanecio(), _anochecio(), _apuntar(), _apuntar_al_punto_cercano(), _armar_pantalla(), _cambio(), _cargar_datos() (+43 more)

### Community 10 - "map/MapPuntos.gd"
Cohesion: 0.08
Nodes (59): _achicar_calentando(), _animar(), _anuncio(), _armar_interior(), avisar(), _caja_detalle(), _caja_solida(), _calentar() (+51 more)

### Community 11 - "map/Supervivencia.gd"
Cohesion: 0.07
Nodes (49): _acercar(), _alejar(), _echar(), _entrar(), _fundir(), _label(), mostrar_afuera(), _mostrar_letrero() (+41 more)

### Community 12 - "scripts/InventoryUI.gd"
Cohesion: 0.09
Nodes (55): _get_active_model(), _process(), reset_for_new_item(), set_inspection_active(), _unhandled_input(), abrir(), _abrir_album(), _abrir_bolsa() (+47 more)

### Community 13 - "scripts/Inventory.gd"
Cohesion: 0.07
Nodes (43): Baul.gd [autoload], cabe(), guardar(), _lugar_de(), sacar(), signal cambio, _cerrar(), _datos() (+35 more)

### Community 14 - "lombrices/MadreCarcamo.gd"
Cohesion: 0.09
Nodes (55): _armar_mallas(), _pintar(), apply_explosion_impulse(), _apuntar_embestida(), bullet_hit(), _cabeza_a(), _cambiar(), _chocar() (+47 more)

### Community 15 - "defensa/Barricada.gd"
Cohesion: 0.08
Nodes (47): _acostado(), _afuera(), _anaquel(), _angulos_huecos(), _armar_anillo(), _caja(), _caja_cuerpo(), _caja_de() (+39 more)

### Community 16 - "scripts/character_animation.gd"
Cohesion: 0.06
Nodes (29): _apuntar(), _girar(), _process_modification_with_delta(), _abortar_accion(), accion(), _armar_arbol(), bloquear(), _clip() (+21 more)

### Community 17 - "map/Saltabardas.gd"
Cohesion: 0.11
Nodes (46): _brincar(), _buscar_suelo(), _cabe(), _chispa(), _cofre(), _cuad(), _entro(), _jalar() (+38 more)

### Community 18 - "mapa/Tianguis.gd"
Cohesion: 0.09
Nodes (40): _caja(), _calle(), _material(), _ready(), pieza(), _relativo(), _sacar(), _aabb() (+32 more)

### Community 19 - "lombrices/PruebaLombrices.gd"
Cohesion: 0.08
Nodes (37): explotar_en_mira(), rayo(), _armar_vida(), _arrojables(), _avisar(), _empezar(), _gano_pelea(), _nivel() (+29 more)

### Community 20 - "scripts/Registro.gd"
Cohesion: 0.10
Nodes (37): Registro.gd [autoload], _actualizar_contexto(), _ahora(), _cerrar_ola(), _clase(), compra(), _csv_linea(), emboscada() (+29 more)

### Community 21 - "map/Panzon.gd"
Cohesion: 0.16
Nodes (37): _acechar(), _agarrar(), _animar(), _arrancar(), _aventar(), _caer(), _cambiar(), _cargar() (+29 more)

### Community 22 - "map/Safehouse.gd"
Cohesion: 0.11
Nodes (35): poner_extras(), _actualizar_hud_carrera(), _armar_hud_carrera(), _armar_panel(), _carrera(), _casas(), _crear_personaje(), _efectos_demo() (+27 more)

### Community 23 - "map/Zombis.gd"
Cohesion: 0.11
Nodes (30): a_la_vista(), _aparecer(), aparecer_jefe(), aparecer_saltabardas(), aparecer_turba(), _armar(), _armar_reserva(), _atacado() (+22 more)

### Community 24 - "interiores/TallerUI.gd"
Cohesion: 0.16
Nodes (32): _actualizar(), decir(), _detalle(), _hacer(), _input(), _label(), _ready(), _sonar() (+24 more)

### Community 25 - "scripts/player.gd"
Cohesion: 0.08
Nodes (22): player.gd (Player), _ajustar_caida(), _arco_sal(), _camara_al_hombro(), canon(), cargador(), cargar(), corredera() (+14 more)

### Community 26 - "map/MapBodegas.gd"
Cohesion: 0.14
Nodes (30): _acomodar_adentro(), _agregar(), _armar_bodega(), _blanco(), _caja(), _colision(), _crear_celda(), _cuerpo() (+22 more)

### Community 27 - "scripts/Mejoras.gd"
Cohesion: 0.14
Nodes (25): agregar(), _de_agua(), _de_rayos(), estallar(), _modo(), _mover_nubes(), _process(), _soltar_nube() (+17 more)

### Community 28 - "scripts/Tazos.gd"
Cohesion: 0.12
Nodes (29): costo_total(), Tazos.gd [autoload], abrir_bolsa(), bajar(), cambiar(), dar_tazo(), es_repetido(), espacio_extra() (+21 more)

### Community 29 - "map/MapCasas.gd"
Cohesion: 0.14
Nodes (28): cargar(), grafiti(), medida(), quad(), _aabb_fachada(), _blanco(), _compactar(), _con_lods() (+20 more)

### Community 30 - "map/Refugio.gd"
Cohesion: 0.12
Nodes (24): abierta(), _actualizar(), armar(), _indice_tabla(), interact(), is_player_inside(), llena(), recibir_golpe() (+16 more)

### Community 31 - "interiores/Interior.gd"
Cohesion: 0.17
Nodes (27): activar(), _block(), _caja(), _calle(), camara(), _cambiar(), _comprar(), _cuarto() (+19 more)

### Community 32 - "lombrices/CarcamoNivel.gd"
Cohesion: 0.20
Nodes (27): _barandal(), _barandal_alberca(), _caja(), _cilindro(), _cuesta(), _decal(), _escaleras(), _gota_azul() (+19 more)

### Community 33 - "catrina/PruebaCatrina.gd"
Cohesion: 0.16
Nodes (26): _adornos(), _avisar(), _bot_fin_intento(), _bot_mirar(), _bot_preparar(), _bot_terminar(), _bot_zombi_cerca(), _capturar() (+18 more)

### Community 34 - "mapa/Colonia.gd"
Cohesion: 0.20
Nodes (23): _agregar_luz(), _botin(), _casa_propia(), _casa_vecino(), _enter_tree(), _foco(), _garrafon(), _letrero() (+15 more)

### Community 35 - "interiores/Mostrador.gd"
Cohesion: 0.25
Nodes (23): _anaquel(), _armar(), _caja(), _caja_registradora(), _cajonera(), _cilindro(), _disco(), _etiqueta() (+15 more)

### Community 36 - "map/MapBardas.gd"
Cohesion: 0.20
Nodes (22): _agregar(), _barda(), _blanco(), _bloque(), _brazo(), _caja(), _calcomania(), _caseta() (+14 more)

### Community 37 - "scripts/TazoRevelacion.gd"
Cohesion: 0.17
Nodes (21): _animar(), _armar_mundo(), _armar_pantalla(), _arriba_final(), _correr(), crear_disco(), _destello(), _en_pantalla() (+13 more)

### Community 38 - "scripts/Inicio.gd"
Cohesion: 0.21
Nodes (21): _abrir(), _activar(), _caja(), _crear_personaje(), _dither(), _empezar_ambiente(), _escena(), _fundir_ambiente() (+13 more)

### Community 39 - "scripts/InventoryItemData.gd"
Cohesion: 0.14
Nodes (9): _persona(), _ready(), _reconstruir(), _tela(), medir(), _ready(), _reconstruir(), crear_modelo() (+1 more)

### Community 40 - "map/MapAlumbrado.gd"
Cohesion: 0.19
Nodes (20): _process(), encendida(), estado(), _h(), noche(), parpadeo(), _por_zona(), armar_chispas() (+12 more)

### Community 41 - "map/RestosZombi.gd"
Cohesion: 0.18
Nodes (17): _acostado(), _agregar(), _armar_piezas(), _armar_rafaga(), _armar_solidos(), _barra(), _bolsa(), _caja() (+9 more)

### Community 42 - "lombrices/Lanzador.gd"
Cohesion: 0.19
Nodes (16): cuantos(), _desde_mano(), _destino_carga(), _dir_punado(), lanzar(), _modelo_en_mano(), _poner_en_mano(), _process() (+8 more)

### Community 43 - "scenes/defensa_tinaco.tscn"
Cohesion: 0.19
Nodes (15): _crear_celda(), _distancia(), _malla_mata(), _process(), _ready(), _valor(), _add(), _distance() (+7 more)

### Community 44 - "scripts/AlbumTazos.gd"
Cohesion: 0.16
Nodes (16): _actualizar(), _armar_vista(), _label(), manejar(), mostrar(), _mostrar_tazo(), _ready(), _process() (+8 more)

### Community 45 - "scripts/HabilidadesUI.gd"
Cohesion: 0.22
Nodes (18): orden(), _actualizar(), _apagar_cuadro(), _armar_detalle(), _armar_lista(), _bajar(), _brincar(), _es_derecha() (+10 more)

### Community 46 - "map/Gente.gd"
Cohesion: 0.24
Nodes (18): _altura(), _armar_reserva(), _caminar(), _cargar_banquetas(), _cargar_lugares(), _celda(), _fin_de_linea(), _guardar() (+10 more)

### Community 47 - "scripts/Pruebas.gd"
Cohesion: 0.16
Nodes (12): Pruebas.gd [autoload], _asegurar_carpeta(), carpeta_actual(), _carpeta_arg(), empezar_noche(), iniciar_godmode(), _nombre_modo(), nueva_carrera() (+4 more)

### Community 48 - "lombrices/Bocina.gd"
Cohesion: 0.21
Nodes (12): _init(), malla(), _material(), _textura_tela(), centro_botella(), _contorno(), _init(), malla_cinta() (+4 more)

### Community 49 - "map/Ciclo.gd"
Cohesion: 0.17
Nodes (10): _aplicar(), _process(), _ready(), reiniciar_noche(), saltar(), signal amanecio, signal anochecio, signal aviso_atardecer (+2 more)

### Community 50 - "scripts/Bonos.gd"
Cohesion: 0.18
Nodes (14): Bonos.gd [autoload], factor_alcance(), factor_fuerza(), factor_pesos(), factor_recibido(), luz(), petalos(), reiniciar() (+6 more)

### Community 51 - "interiores/MueblesCasa.gd"
Cohesion: 0.24
Nodes (14): _abrir_baul(), _avisar(), _caja(), _cilindro(), _dormir(), _mat(), _mueble(), _poner_altar() (+6 more)

### Community 52 - "map/CampoFlujo.gd"
Cohesion: 0.21
Nodes (13): adelante(), avanzar(), _celda(), _cruza_pared(), direccion(), direccion_suave(), _empezar(), _indice() (+5 more)

### Community 53 - "scripts/Tiliches.gd"
Cohesion: 0.26
Nodes (16): es_trofeo(), Tiliches.gd [autoload], alcanza(), avisar(), avisar_sin_cangurera(), _cargar_vitrina(), cuantos(), dar() (+8 more)

### Community 54 - "scripts/player.gd (2)"
Cohesion: 0.21
Nodes (17): _a_punos(), _atacar(), _barriendo(), _combo_desde(), _especiales(), _mirar_atras(), _nearby_interactable(), _ocupado() (+9 more)

### Community 55 - "scripts/MenuTest.gd"
Cohesion: 0.21
Nodes (13): _actualizar(), _boton(), _cargar(), _ciclar_dificultad(), _ciclar_duracion(), _economia(), _espacio(), _label() (+5 more)

### Community 56 - "scripts/TilichesUI.gd"
Cohesion: 0.23
Nodes (12): VitrinaTrofeos, de_clase(), signal cambio, _actualizar(), _armar_materiales(), _armar_vitrina(), _casilla(), _label() (+4 more)

### Community 57 - "map/LocalesPreview.gd"
Cohesion: 0.25
Nodes (14): _calle(), _captura(), _capturas(), _enter_tree(), _esperar(), _guardar(), _hilera(), _plano() (+6 more)

### Community 58 - "interiores/CasaPropia.gd"
Cohesion: 0.24
Nodes (10): _afuera(), _entrar(), _fundir(), _limpiar(), _marcador(), _mostrar_letrero(), _physics_process(), _poner_jugador() (+2 more)

### Community 59 - "catrina/CatrinaProvisional.gd"
Cohesion: 0.29
Nodes (9): _bola(), _brazo(), _caja(), _capsula(), _cono(), _marca(), _mat(), _ready() (+1 more)

### Community 60 - "map/PiezaMapa.gd"
Cohesion: 0.18
Nodes (9): _adornar_cielo(), _adornar_plaza(), _actualizar_aviso(), interact(), _ready(), cuadro_bucle(), _actualizar_aviso(), _ready() (+1 more)

### Community 61 - "map/EfectosPixel.gd"
Cohesion: 0.24
Nodes (12): cambiar(), hoja_de(), lanzar(), malla_quad(), material_bucle(), material_eje(), nombre_variante(), pantalla() (+4 more)

### Community 62 - "lombrices/BotellaMolotov.gd"
Cohesion: 0.22
Nodes (8): _agregar(), _init(), malla(), _material(), _textura_etiqueta(), _textura_trapo(), _tira_trapo(), _torno()

### Community 63 - "interiores/Estante.gd"
Cohesion: 0.26
Nodes (11): _armar(), _canastilla(), _carita(), _colgados(), _colgar_modelos(), _ganchos(), _rejilla(), _repisas() (+3 more)

### Community 64 - "interiores/Refrigerador.gd"
Cohesion: 0.30
Nodes (13): _botellas(), _caja(), _juntar(), malla_botella(), _modelos(), _niveles(), _plano(), _ps1() (+5 more)

### Community 65 - "lombrices/Arrojadizo.gd"
Cohesion: 0.27
Nodes (13): _armar_escupitajo(), _cebarse(), es_molotov(), _esfera(), fuego_radio(), lanzar(), letrero(), _mover_escupitajo() (+5 more)

### Community 66 - "lombrices/ZonaLombrices.gd"
Cohesion: 0.25
Nodes (11): _bucles(), _contorno_en(), crear(), _disco(), estallido(), lengua(), _llamas(), patear() (+3 more)

### Community 67 - "scripts/player.gd (3)"
Cohesion: 0.20
Nodes (14): atrapado(), atrapar(), aventar_molotov(), aventar_sal(), caer(), _cancelar_carga(), _cortar_estocada(), _empezar_clavado() (+6 more)

### Community 69 - "scenes/map_test.tscn"
Cohesion: 0.18
Nodes (3): _ready(), _set_active(), _unhandled_input()

### Community 70 - "catrina/PruebaCatrina.gd (2)"
Cohesion: 0.28
Nodes (13): _armar_rompibles(), _caja(), _jardinera(), _luces(), _luz_ofrenda(), _mat(), _nivel(), _nivel_cajas() (+5 more)

### Community 71 - "scripts/Habilidades.gd"
Cohesion: 0.27
Nodes (12): dato(), efecto_texto(), icono(), _actualizar_detalle(), _actualizar_fila(), _actualizar_puntos(), costo_siguiente(), disponible() (+4 more)

### Community 72 - "map/MuroColonia.gd"
Cohesion: 0.27
Nodes (11): _afuera(), _caja(), _enter_tree(), _flecha_de_entrada(), _material(), _pared(), _ready(), _reja() (+3 more)

### Community 73 - "interiores/Gasolinera.gd"
Cohesion: 0.38
Nodes (10): _cilindro(), _fondo(), _isla(), _liso(), _luz_dia(), _manguera(), _reconstruir(), _suelo() (+2 more)

### Community 74 - "map/Deterioro.gd"
Cohesion: 0.30
Nodes (9): configurar(), _hash(), relativo(), _ruido(), _setting(), tipo_pasto(), zona(), _enter_tree() (+1 more)

### Community 75 - "scripts/Materiales.gd"
Cohesion: 0.23
Nodes (7): activar(), linea_hecho(), _ready(), botin(), chatarra(), comun(), _sumar()

### Community 76 - "map/Chatarra.gd"
Cohesion: 0.24
Nodes (9): _actualizar_aviso(), interact(), _pieza(), _ready(), flecha(), _flecha_mesh(), _caja(), _marcador() (+1 more)

### Community 77 - "scripts/npc.gd"
Cohesion: 0.30
Nodes (10): _actualizar_pantallas(), _apply_prompt_key(), _apply_tint(), _input(), interact(), _on_body_entered(), _on_body_exited(), _play_idle() (+2 more)

### Community 78 - "interiores/CasaVecino.gd"
Cohesion: 0.24
Nodes (6): _avisar(), _botin(), _comprar(), _persona(), _ready(), elegir()

### Community 79 - "scripts/MejorasUI.gd"
Cohesion: 0.35
Nodes (9): _actualizar_dinero(), _catalogo_categoria(), comprar(), _label(), mover(), mover_item(), _ready(), _refrescar() (+1 more)

### Community 80 - "scripts/player.gd (4)"
Cohesion: 0.24
Nodes (11): _aplicar_cuerpo(), aplicar_habilidades(), aplicar_personaje(), _armar_estela(), _armar_mano(), cambiar_arma(), _cortar_corredera(), _esqueleto() (+3 more)

### Community 81 - "scripts/player.gd (5)"
Cohesion: 0.31
Nodes (11): _arma(), _brillo_carga(), _conto_espada(), _fogonazo(), _golpear(), _pegar_estocada(), _punta_arma(), _radio_de() (+3 more)

### Community 82 - "defensa/TinacoDefensa.gd"
Cohesion: 0.29
Nodes (8): armar(), fraccion(), _goteras(), recibir_golpe(), reiniciar(), signal aviso, signal cambio, signal cayo

### Community 83 - "map/Director.gd"
Cohesion: 0.24
Nodes (4): avanzar(), _cambiar(), _init(), reiniciar()

### Community 84 - "personajes/Civiles.gd"
Cohesion: 0.31
Nodes (8): _armar_caminante(), _process(), _punto(), _ready(), al_azar(), calentar(), _escena(), poner()

### Community 85 - "map/MapArboles.gd"
Cohesion: 0.42
Nodes (9): _crear_celda(), _crear_pendientes(), _esfera(), _malla_arbol(), _process(), _punto(), _ready(), _tri() (+1 more)

### Community 86 - "scripts/player.gd (6)"
Cohesion: 0.27
Nodes (10): aturdirte(), _congelar(), _dano_recibido(), efecto(), _parar_golpe(), _pintar_blanco(), recibir_dano(), _revisar_congelada() (+2 more)

### Community 87 - "map/Senuelo.gd"
Cohesion: 0.25
Nodes (6): ondas(), _apagar(), crear(), _process(), _ready(), ruido()

### Community 88 - "map/MapPostImport.gd"
Cohesion: 0.42
Nodes (8): _build_chunk(), _facade_material(), _ground_material(), _is_building(), _post_import(), _ps1_material(), _scene_transform(), _wants_collision()

### Community 89 - "scripts/player.gd (7)"
Cohesion: 0.28
Nodes (9): beber(), _curarse(), _doble_toque(), _es_direccion(), _guardar(), mirando_atras(), _pedir_accion(), _teclas_mover() (+1 more)

### Community 90 - "scripts/PruebasUI.gd"
Cohesion: 0.43
Nodes (6): _actualizar(), _boton(), _empezar(), _label(), _ready(), _texto_enemigos()

### Community 91 - "interiores/Trompo.gd"
Cohesion: 0.46
Nodes (6): _cilindro(), humo(), _material(), _ready(), _reconstruir(), _torno()

### Community 92 - "map/MapMinimapa.gd"
Cohesion: 0.43
Nodes (4): _a_pantalla(), _dibujar_marcas(), _dibujar_objetivo(), _dibujar_zombis()

### Community 93 - "map/NinoTazos.gd"
Cohesion: 0.29
Nodes (5): _hablar(), _ready(), _revelar(), texto_puntos(), abrir()

### Community 94 - "mapa/CajaGela.gd"
Cohesion: 0.46
Nodes (6): _armar_caja(), _avisar(), _de_noche(), interact(), is_player_inside(), _ready()

### Community 95 - "mapa/Palomas.gd"
Cohesion: 0.46
Nodes (6): _al_azar(), _atlas(), _espantar(), _poner(), _process(), _ready()

### Community 96 - "scripts/MariposaMonarca.gd"
Cohesion: 0.29
Nodes (6): _dibujo(), _ready(), soltar(), _estela_golpe(), _estela_puno(), _nudillos()

### Community 97 - "interiores/Mesa.gd"
Cohesion: 0.38
Nodes (3): _armar(), _centro(), _silla()

### Community 98 - "scenes/locales_preview.tscn"
Cohesion: 0.33
Nodes (3): configurar_noche(), _process(), _ready()

### Community 99 - "lombrices/Palomita.gd"
Cohesion: 0.48
Nodes (5): _init(), malla(), _material(), _textura(), _tri()

### Community 100 - "catrina/Rompible.gd"
Cohesion: 0.38
Nodes (3): romper(), _tirar_pedazos(), _tumbar()

### Community 101 - "interiores/Vitrina.gd"
Cohesion: 0.38
Nodes (4): _acomodar(), _deslizar(), mostrar(), mover()

### Community 102 - "map/TiendaPostImport.gd"
Cohesion: 0.52
Nodes (6): _contar_triangulos(), _convert(), _post_import(), _ps1_material(), _recortar(), _reducir()

### Community 103 - "scripts/CasaPersonaje.gd"
Cohesion: 0.60
Nodes (4): _igualar_madera(), _mallas(), _promedio(), _ready()

### Community 104 - "interiores/TiendaUI.gd"
Cohesion: 0.47
Nodes (3): _dinero(), _label(), _ready()

### Community 105 - "mapa/MapaPostImport.gd"
Cohesion: 0.80
Nodes (4): _material(), _por_nombre(), _post_import(), _transform_en_escena()

### Community 108 - "mapa/Campana.gd"
Cohesion: 0.67
Nodes (3): _process(), _ready(), repicar()

### Community 109 - "personajes/UniformeGela.gd"
Cohesion: 0.83
Nodes (3): _armar(), _colgar(), vestir()

## Knowledge Gaps
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `player.gd (Player)` connect `scripts/player.gd` to `catrina/Catrina.gd`, `scripts/Sonidos.gd`, `map/Maquinita.gd`, `defensa/DefensaTinaco.gd`, `map/Zombie.gd`, `map/Partida.gd`, `map/MisionesMundo.gd`, `map/MapPuntos.gd`, `map/Supervivencia.gd`, `scripts/InventoryUI.gd`, `scripts/Inventory.gd`, `map/Saltabardas.gd`, `lombrices/PruebaLombrices.gd`, `map/Panzon.gd`, `map/Safehouse.gd`, `map/Zombis.gd`, `scripts/Mejoras.gd`, `map/Refugio.gd`, `catrina/PruebaCatrina.gd`, `mapa/Colonia.gd`, `scripts/InventoryItemData.gd`, `lombrices/Lanzador.gd`, `scripts/player.gd (2)`, `interiores/CasaPropia.gd`, `map/PiezaMapa.gd`, `map/EfectosPixel.gd`, `scripts/player.gd (3)`, `scenes/npc.tscn`, `map/MuroColonia.gd`, `map/Chatarra.gd`, `scripts/npc.gd`, `scripts/player.gd (4)`, `scripts/player.gd (5)`, `scripts/player.gd (6)`, `scripts/player.gd (7)`, `mapa/CajaGela.gd`, `scripts/MariposaMonarca.gd`?**
  _High betweenness centrality (0.207) - this node is a cross-community bridge._
- **Should `catrina/Catrina.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.06519246519246519 - nodes in this community are weakly interconnected._
- **Why does `Tazos.gd [autoload]` connect `scripts/Tazos.gd` to `scripts/TazoRevelacion.gd`, `scripts/Habilidades.gd`, `scripts/InventoryUI.gd`, `scripts/AlbumTazos.gd`, `scripts/HabilidadesUI.gd`, `scripts/Inventory.gd`, `map/Safehouse.gd`, `map/NinoTazos.gd`?**
  _High betweenness centrality (0.037) - this node is a cross-community bridge._
- **Should `scripts/Sonidos.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.0671892497200448 - nodes in this community are weakly interconnected._
- **Why does `Personaje.gd [autoload]` connect `scripts/Personaje.gd` to `map/MisionesMundo.gd`, `scripts/InventoryUI.gd`, `map/Partida.gd`?**
  _High betweenness centrality (0.031) - this node is a cross-community bridge._
- **Should `map/Maquinita.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.05754385964912281 - nodes in this community are weakly interconnected._
- **Should `lombrices/EnjambreLombrices.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.07298245614035087 - nodes in this community are weakly interconnected._