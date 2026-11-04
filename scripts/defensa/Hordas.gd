class_name Hordas
extends Node

# Las hordas de la defensa del tinaco (docs/misiones.md §0): salen por grupos desde la
# orilla de la escena, todos de un mismo lado, y corren al tinaco (Zombie._destino), cada
# uno por su hueco de la barricada. Tardan unos 10 s en llegar: ese rato es de la pistola, y
# al llegar se acaban con el machete. El siguiente grupo sale cuando del anterior quedan
# QUEDAN, asi va llegando mientras terminas (JJ: la pistola debilita, el machete mata), o a
# los ESPERA_MAX s aunque no hayas acabado. Rellenar en cuanto morian dejaba siempre zombis
# encima y no daba tiempo de sacar la pistola. Los sueltos y las turbas del Director estan
# apagados ahi (Zombis.espontaneos).
#
# Como el director de Left 4 Dead: el tamano del grupo sube con la hora (GRUPOS_*), y si te
# estan dando muy duro (la intensidad del Director de Zombis sube con el dano y con matar
# cerca) el siguiente se espera RESPIRO s mas. No se avisa por donde vienen: se oye un
# gemido lejano de ese lado. La hora va de 22:00 a 6:00 repartida en la noche de Ciclo.
#
# Tres modos (usar_modo, MODOS), de las partidas de prueba de JJ: facil (la 7), medio (la 6:
# grupos del final mas grandes, sin tope de dos grupos juntos, corredores al hueco mas
# cercano) y dificil (el medio con grupos 30 % mas grandes).
#
# `dificultad` multiplica el tamano de los grupos. En esta horda piloto es 1 y se gana con
# el machete y la pistola; despues, cada noche o colonia podra pedir mas y solo se ganara
# con mejores armas (docs/pruebas-balance.md).

const HORA_EMPIEZA := 22.0
const HORAS := 8.0
# [hora (24 = medianoche), zombis por grupo, fraccion de corredores], se interpola
const GRUPOS_FACIL := [
	[22.0, 3, 0.0],
	[23.0, 4, 0.0],
	[24.0, 7, 0.0],      # la grande de medianoche
	[24.8, 5, 0.1],
	[26.0, 6, 0.1],
	[27.0, 7, 0.4],      # los corredores de las 3
	[28.0, 6, 0.15],
	[29.0, 7, 0.2],      # la del final
]
# Como el facil, pero el final mas cargado (con 9 se atascaba en el facil, sin tope)
const GRUPOS_MEDIO := [
	[22.0, 3, 0.0],
	[23.0, 4, 0.0],
	[24.0, 7, 0.0],
	[24.8, 5, 0.1],
	[26.0, 6, 0.1],
	[27.0, 7, 0.4],
	[28.0, 7, 0.15],
	[29.0, 9, 0.2],
]
# grupos: la tabla; tope: a los ESPERA_MAX s sale otro solo si quedan menos de los que trae
# (nunca mas de dos grupos juntos); corredores_cercano: los corredores entran por el hueco
# mas cercano (llegan todos a la vez); dificultad: multiplica los grupos
const MODOS := {
	"facil": {"grupos": GRUPOS_FACIL, "tope": true, "corredores_cercano": false, "dificultad": 1.0},
	"medio": {"grupos": GRUPOS_MEDIO, "tope": false, "corredores_cercano": true, "dificultad": 1.0},
	"dificil": {"grupos": GRUPOS_MEDIO, "tope": false, "corredores_cercano": true, "dificultad": 1.3},
}
const ULTIMA := 29.5       # nada despues: lo que quede se cae al amanecer
const QUEDAN := 1          # con cuantos vivos sale el siguiente grupo
const ESPERA_MIN := 5.0    # s entre grupo y grupo, aunque los acabes rapido
const ESPERA_MAX := 20.0   # s: sale aunque no hayas acabado con el anterior, si quedan menos
                           # que los que trae (asi no se juntan mas de dos grupos)
const DE_DOS_LADOS := 7    # un grupo de este tamano o mas llega por dos lados
# Si la intensidad llega a TOPE, el siguiente grupo se espera un poco mas
const TOPE := 0.8
const RESPIRO := 6.0       # s
const DESPUES_DEL_RESPIRO := 0.45   # la intensidad con la que se queda
const BAJA_POR_SEGUNDO := 0.05
const DISTANCIA := Vector2(41.0, 46.0)  # m del centro donde salen (el campo de flujo cubre 47)
const ABRE := 0.35         # rad alrededor del angulo del grupo
const CADA := 0.2          # s entre uno y otro del mismo grupo
const SEPARADO := 1.2      # m entre zombis al salir
const ALTO_CALLE := 0.6    # m sobre el centro: mas alto es una azotea
const INTENTOS := 6
# El gemido lejano al salir un grupo: grave, apagado por la distancia
const GEMIDO_TONO := Vector2(0.7, 0.85)
const GEMIDO_VOLUMEN := 4.0
const GEMIDO_HASTA := 80.0
const GEMIDO_FILTRO := 1800.0   # Hz: atenuacion de AudioStreamPlayer3D, suena lejos

var centro := Vector3.ZERO
var zombis: Zombis
var ciclo: Ciclo
var dificultad := 1.0
var _grupos: Array = GRUPOS_FACIL
var _tope := true
var muertos := 0            # para la pantalla final
var mas_juntos := 0         # el maximo de vivos a la vez
var hora_mas_juntos := HORA_EMPIEZA

var _espera := 0.0
var _respiro := 0.0
var _desde_grupo := INF     # s desde que salio el ultimo grupo
var _pendientes: Array[float] = []   # el angulo de cada uno que falta por salir
var _corredores := 0.0


# 22.0 a 30.0: llega a las 6 justo al amanecer (Ciclo.amanecio, a media transicion)
func hora() -> float:
	var t := ciclo.tiempo() - ciclo.dia_duracion
	if t < 0.0:
		return HORA_EMPIEZA + HORAS
	return HORA_EMPIEZA + HORAS * clampf(t / (ciclo.noche_duracion - ciclo.transicion / 2.0), 0.0, 1.0)


static func texto_hora(h: float) -> String:
	var minutos := int(h * 60.0) % (24 * 60)
	return "%d:%02d" % [minutos / 60, minutos % 60]


func reiniciar() -> void:
	muertos = 0
	mas_juntos = 0
	_respiro = 0.0
	_desde_grupo = INF
	_pendientes.clear()


# Cuantos trae el grupo que sale a esta hora
func grupo(h: float) -> int:
	if h >= ULTIMA:
		return 0
	return mini(maxi(roundi(_curva(h).x * dificultad), 1), zombis.max_total)


# x = zombis por grupo, y = fraccion de corredores
func _curva(h: float) -> Vector2:
	if h <= _grupos[0][0]:
		return Vector2(_grupos[0][1], _grupos[0][2])
	for i in range(1, _grupos.size()):
		if h < _grupos[i][0]:
			var t := inverse_lerp(_grupos[i - 1][0], _grupos[i][0], h)
			return Vector2(lerpf(_grupos[i - 1][1], _grupos[i][1], t), lerpf(_grupos[i - 1][2], _grupos[i][2], t))
	return Vector2(_grupos[-1][1], _grupos[-1][2])


func usar_modo(nombre: String) -> void:
	var modo: Dictionary = MODOS[nombre]
	_grupos = modo["grupos"]
	_tope = modo["tope"]
	dificultad = modo["dificultad"]
	zombis.corredores_al_cercano = modo["corredores_cercano"]


func _physics_process(delta: float) -> void:
	if ciclo == null or not ciclo.es_noche():
		return
	var vivos := zombis.vivos()
	var h := hora()
	if vivos > mas_juntos:
		mas_juntos = vivos
		hora_mas_juntos = h
	_respirar(delta)
	_desde_grupo += delta
	if _pendientes.is_empty():
		var cuantos := grupo(h)
		var listo := vivos <= QUEDAN or (_desde_grupo >= ESPERA_MAX and (vivos < cuantos or not _tope))
		if cuantos > 0 and _respiro <= 0.0 and _desde_grupo >= ESPERA_MIN and listo and vivos + cuantos <= zombis.max_total:
			_soltar(cuantos, _curva(h).y)
		return
	_espera -= delta
	if _espera > 0.0:
		return
	_espera = CADA
	var lugar := _lugar(_pendientes[0])
	if lugar == Vector3.INF:
		# Ese lado esta tapado (casas): que salga de otro
		_pendientes[0] = randf() * TAU
		return
	_pendientes.pop_front()
	var zombi := zombis.sacar(lugar, randf() < _corredores)
	if not zombi.murio.is_connected(_murio):
		zombi.murio.connect(_murio)


# Un grupo de `cuantos`, de un lado (o de dos lados opuestos si es grande)
func _soltar(cuantos: int, corredores: float) -> void:
	_desde_grupo = 0.0
	_corredores = corredores
	var angulo := randf() * TAU
	var lados := 2 if cuantos >= DE_DOS_LADOS else 1
	for i in cuantos:
		_pendientes.append(angulo + (i % lados) * PI)
	for l in lados:
		var lugar := _lugar(angulo + l * PI)
		if lugar != Vector3.INF:
			_gemir(lugar)


# Los que se caen al amanecer no cuentan
func _murio() -> void:
	if ciclo.es_noche():
		muertos += 1


# La intensidad del Director sube con el dano y matando cerca (Zombis.gd); aqui baja sola
# y, si llega a TOPE, el siguiente grupo se espera RESPIRO s
func _respirar(delta: float) -> void:
	var director := zombis.director
	director.intensidad = maxf(director.intensidad - BAJA_POR_SEGUNDO * delta, 0.0)
	if _respiro > 0.0:
		_respiro -= delta
		if _respiro <= 0.0:
			director.intensidad = minf(director.intensidad, DESPUES_DEL_RESPIRO)
	elif director.intensidad >= TOPE:
		_respiro = RESPIRO


# Un gemido grave y lejano de donde sale el grupo: el aviso, sin texto
func _gemir(lugar: Vector3) -> void:
	var voz := AudioStreamPlayer3D.new()
	voz.stream = Sonidos.sonido("gemido")
	voz.pitch_scale = randf_range(GEMIDO_TONO.x, GEMIDO_TONO.y)
	voz.volume_db = GEMIDO_VOLUMEN
	voz.max_distance = GEMIDO_HASTA
	voz.attenuation_filter_cutoff_hz = GEMIDO_FILTRO
	voz.finished.connect(voz.queue_free)
	zombis.add_child(voz)
	voz.global_position = lugar + Vector3.UP * 1.5
	voz.play()


# En el suelo, a DISTANCIA del centro de ese lado; INF si no hubo lugar
func _lugar(angulo: float) -> Vector3:
	var espacio := zombis.get_world_3d().direct_space_state
	for i in INTENTOS:
		var a := angulo + randf_range(-ABRE, ABRE)
		var punto := centro + Vector3(sin(a), 0.0, -cos(a)) * randf_range(DISTANCIA.x, DISTANCIA.y)
		if _encima_de_otro(punto):
			continue
		var rayo := PhysicsRayQueryParameters3D.create(Vector3(punto.x, centro.y + 30.0, punto.z), Vector3(punto.x, centro.y - 2.0, punto.z), 1)
		var pego := espacio.intersect_ray(rayo)
		if pego and pego.position.y < centro.y + ALTO_CALLE:
			return pego.position + Vector3.UP * 0.05
	return Vector3.INF


func _encima_de_otro(punto: Vector3) -> bool:
	for z in Zombie.activos:
		if Vector2(z.global_position.x - punto.x, z.global_position.z - punto.z).length_squared() < SEPARADO * SEPARADO:
			return true
	return false

