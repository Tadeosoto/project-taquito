extends Node

# Mide una noche de la defensa para revisar el balance (docs/pruebas-balance.md). Lo crea
# DefensaTinaco con `-- --monitor=<carpeta>`: cada CADA s de reloj real escribe un renglon en
# <carpeta>/monitor.csv (hora, zombis, vidas, dano hecho y recibido, golpes y tiros) y los
# golpes y curaciones en eventos.txt; al acabar la noche escribe resumen.txt. Tambien lo
# imprime en la consola. Corre siempre, pero no mide mientras el juego esta en pausa.

const CADA := 5.0
const CERCA := 8.0          # m del jugador para contar a un zombi como encima
const POCA_VIDA := 0.5      # fraccion: cuanto tiempo pasaste abajo de esto

var defensa: Node
var carpeta := ""

var _jugador: Player
var _tinaco: TinacoDefensa
var _hordas: Hordas
var _zombis: Zombis
var _salud: Node
var _pistola: Node
var _csv: FileAccess
var _eventos: FileAccess
var _desde := 0
var _siguiente := 0.0
var _vida_antes := 0
var _recibido := 0
var _curado := 0
var _curaciones := 0
var _golpes_recibidos := 0
var _vida_min := 100
var _poca_vida := 0.0
var _tinaco_antes := 0
var _por_hora := {}         # hora entera -> [suma de vivos, muestras, dano recibido]
var _empezo := false
var _termino := false
var _ultimo_tick := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_jugador = defensa.get_node("Player") as Player
	_tinaco = defensa._tinaco
	_zombis = defensa.get_node("Zombis") as Zombis
	_salud = get_node("/root/Salud")
	_pistola = _jugador._pistola
	DirAccess.make_dir_recursive_absolute(carpeta)
	_csv = FileAccess.open(carpeta.path_join("monitor.csv"), FileAccess.WRITE)
	_csv.store_line("seg,hora,vivos,grupo,respiro,atacan_tinaco,van_por_ti,cerca_de_ti,muertos,vida,vida_tinaco,dano_cuerpo,dano_pistola,recibido,curado,golpes,golpes_pegaron,tiros,aciertos,intensidad,fps")
	_eventos = FileAccess.open(carpeta.path_join("eventos.txt"), FileAccess.WRITE)
	_salud.cambio.connect(_cambio_vida)


func _process(_delta: float) -> void:
	if not _empezo:
		_hordas = defensa._hordas
		if not defensa._listo or not defensa._ciclo.es_noche():
			return
		_empezar()
	if _termino:
		return
	var ahora := Time.get_ticks_msec()
	var paso := (ahora - _ultimo_tick) / 1000.0
	_ultimo_tick = ahora
	if get_tree().paused and not defensa._terminado:
		return
	if float(_salud.vida) / _salud.vida_max < POCA_VIDA:
		_poca_vida += paso
	if (ahora - _desde) / 1000.0 >= _siguiente:
		_siguiente += CADA
		_renglon()
	if defensa._terminado:
		_renglon()
		_resumen()


func _empezar() -> void:
	_empezo = true
	_desde = Time.get_ticks_msec()
	_ultimo_tick = _desde
	Zombie.dano_cuerpo = 0
	Zombie.dano_pistola = 0
	Zombie.dano_cabeza = 0
	_jugador.golpes = 0
	_jugador.golpes_pegaron = 0
	_pistola.tiros = 0
	_pistola.aciertos = 0
	_vida_antes = _salud.vida
	_vida_min = _salud.vida
	_tinaco_antes = _tinaco.vida
	_evento("Empieza la noche. Vida %d, tinaco %d" % [_salud.vida, _tinaco.vida])


func _renglon() -> void:
	var h := _hordas.hora()
	var atacan_tinaco := 0
	var van_por_ti := 0
	var cerca := 0
	var vivos := 0
	for z in Zombie.activos:
		if z.estado == Zombie.Estado.MUERTO:
			continue
		vivos += 1
		if z._blanco == _tinaco and z.estado == Zombie.Estado.ATACA:
			atacan_tinaco += 1
		if z._blanco == _jugador:
			van_por_ti += 1
		if z.global_position.distance_to(_jugador.global_position) <= CERCA:
			cerca += 1
	var hora_entera := int(h) % 24
	var datos: Array = _por_hora.get(hora_entera, [0, 0, 0])
	datos[0] += vivos
	datos[1] += 1
	_por_hora[hora_entera] = datos
	var valores := [
		"%.0f" % ((Time.get_ticks_msec() - _desde) / 1000.0), Hordas.texto_hora(h), vivos, _hordas.grupo(h),
		1 if _hordas._respiro > 0.0 else 0, atacan_tinaco, van_por_ti, cerca, _hordas.muertos,
		_salud.vida, _tinaco.vida, Zombie.dano_cuerpo, Zombie.dano_pistola, _recibido, _curado,
		_jugador.golpes, _jugador.golpes_pegaron, _pistola.tiros, _pistola.aciertos,
		"%.2f" % _zombis.director.intensidad, Engine.get_frames_per_second(),
	]
	var linea := ",".join(valores.map(func(v: Variant) -> String: return str(v)))
	_csv.store_line(linea)
	_csv.flush()
	print("[monitor] ", linea)
	if _tinaco.vida < _tinaco_antes:
		_evento("%s el tinaco va en %d (%d %%)" % [Hordas.texto_hora(h), _tinaco.vida, roundi(_tinaco.fraccion() * 100.0)])
		_tinaco_antes = _tinaco.vida


func _cambio_vida() -> void:
	if not _empezo or _termino:
		return
	var vida: int = _salud.vida
	var diferencia := vida - _vida_antes
	_vida_antes = vida
	_vida_min = mini(_vida_min, vida)
	var h := Hordas.texto_hora(_hordas.hora())
	if diferencia < 0:
		_recibido -= diferencia
		_golpes_recibidos += 1
		var datos: Array = _por_hora.get(int(_hordas.hora()) % 24, [0, 0, 0])
		datos[2] -= diferencia
		_por_hora[int(_hordas.hora()) % 24] = datos
		_evento("%s te pegaron %d, vida %d" % [h, -diferencia, vida])
	elif diferencia > 0 and vida - diferencia > 0:
		_curado += diferencia
		_curaciones += 1
		_evento("%s te curaste %d, vida %d" % [h, diferencia, vida])


func _evento(texto: String) -> void:
	_eventos.store_line(texto)
	_eventos.flush()
	print("[monitor] ", texto)


func _resumen() -> void:
	_termino = true
	var segundos := (Time.get_ticks_msec() - _desde) / 1000.0
	var gano: bool = _tinaco.vida > 0 and _salud.vida > 0 and _hordas.hora() >= Hordas.HORA_EMPIEZA + Hordas.HORAS - 0.01
	var dano := Zombie.dano_cuerpo + Zombie.dano_pistola
	var lineas: Array[String] = [
		"Modo: %s" % defensa.modo,
		"Resultado: %s" % ("aguantó la noche" if gano else ("te desmayaste" if _vida_min <= 0 else "rompieron el tinaco")),
		"Hora final: %s, %.0f s de noche" % [Hordas.texto_hora(_hordas.hora()), segundos],
		"Vida final: %d de %d (%d %%), la más baja: %d" % [_salud.vida, _salud.vida_max, roundi(100.0 * _salud.vida / _salud.vida_max), _vida_min],
		"Tiempo con menos de %d %% de vida: %.0f s" % [roundi(POCA_VIDA * 100.0), _poca_vida],
		"Daño recibido: %d en %d golpes. Curado: %d con %d curaciones" % [_recibido, _golpes_recibidos, _curado, _curaciones],
		"Tinaco: %d de %d (%d %%)" % [_tinaco.vida, TinacoDefensa.VIDA, roundi(_tinaco.fraccion() * 100.0)],
		"Zombis matados: %d. Más a la vez: %d, a las %s" % [_hordas.muertos, _hordas.mas_juntos, Hordas.texto_hora(_hordas.hora_mas_juntos)],
		"Daño hecho: %d (cuerpo a cuerpo %d, pistola %d, a la cabeza %d)" % [dano, Zombie.dano_cuerpo, Zombie.dano_pistola, Zombie.dano_cabeza],
		"Golpes: %d, pegaron %d (%d %%)" % [_jugador.golpes, _jugador.golpes_pegaron, roundi(100.0 * _jugador.golpes_pegaron / maxi(_jugador.golpes, 1))],
		"Tiros: %d, pegaron %d (%d %%)" % [_pistola.tiros, _pistola.aciertos, roundi(100.0 * _pistola.aciertos / maxi(_pistola.tiros, 1))],
		"Por hora (vivos en promedio, daño recibido):",
	]
	for hora: int in [22, 23, 0, 1, 2, 3, 4, 5]:
		if _por_hora.has(hora):
			var datos: Array = _por_hora[hora]
			lineas.append("  %d:00  %.1f vivos, %d de daño" % [hora, float(datos[0]) / maxi(datos[1], 1), datos[2]])
	var archivo := FileAccess.open(carpeta.path_join("resumen.txt"), FileAccess.WRITE)
	for linea in lineas:
		archivo.store_line(linea)
		print("[monitor] ", linea)
	archivo.close()
	_csv.close()
	_eventos.close()
