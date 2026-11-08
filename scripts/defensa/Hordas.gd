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
# emboscadas: grupitos aparte que salen de tu lado y van por ti (no en facil)
const MODOS := {
	"facil": {"grupos": GRUPOS_FACIL, "tope": true, "corredores_cercano": false, "dificultad": 1.0, "emboscadas": false, "panzon": 0.0},
	"medio": {"grupos": GRUPOS_MEDIO, "tope": false, "corredores_cercano": true, "dificultad": 1.25, "emboscadas": true, "panzon": 0.35},
	"dificil": {"grupos": GRUPOS_MEDIO, "tope": false, "corredores_cercano": true, "dificultad": 1.6, "emboscadas": true, "panzon": 0.6},
}
const ULTIMA := 29.5       # nada despues: lo que quede se cae al amanecer
# Emboscadas: fuera de las oleadas, 2-3 cazadores que salen del lado donde andas (fuera de la
# camara, como todos) y van por ti, no por el tinaco: castigan alejarse de el. No cuentan para
# que salga el siguiente grupo y no avisan con gemido
const EMBOSCADA_CADA := Vector2(35.0, 60.0)  # s entre una y otra, al azar
const EMBOSCADA_GRUPO := Vector2i(2, 3)
const EMBOSCADA_DESDE := 23.0                # la primera, no antes de esta hora
const QUEDAN := 1          # con cuantos vivos sale el siguiente grupo
# El Panzon (Panzon.gd, propuesta de AG): desde medianoche, cada hora se tira el dado
# (MODOS["panzon"]); nunca dos vivos; si a las 3:00 no ha salido y el modo lo trae, sale
const PANZON_DESDE := 24.0
const PANZON_SEGURO := 27.0
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
const GEMIDO_VOLUMEN := 0.0   # el rugido ya es mas fuerte que el gemido de antes
const GEMIDO_HASTA := 80.0
const GEMIDO_FILTRO := 1800.0   # Hz: atenuacion de AudioStreamPlayer3D, suena lejos

var centro := Vector3.ZERO
var zombis: Zombis
var ciclo: Ciclo
var dificultad := 1.0
var _grupos: Array = GRUPOS_FACIL
var _tope := true
var emboscadas := true
var emboscadas_salieron := 0   # cuantas emboscadas hubo y cuantos de ellas cayeron
var emboscados_muertos := 0
var muertos := 0            # para la pantalla final
var mas_juntos := 0         # el maximo de vivos a la vez
var hora_mas_juntos := HORA_EMPIEZA

var _espera := 0.0
var _respiro := 0.0
var _desde_grupo := INF     # s desde que salio el ultimo grupo
var _pendientes: Array[float] = []   # el angulo de cada uno que falta por salir
var _corredores := 0.0
var _emboscada_en := EMBOSCADA_CADA.x  # s para la siguiente emboscada
var _emboscados: Array[Zombie] = []
var panzon_prob := 0.0
var panzones := 0            # cuantos salieron esta noche
var _panzon_hora := -1        # la ultima hora en que se tiro el dado
var _panzon_pendiente := false # ya toco, falta un lugar libre


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
	_emboscados.clear()
	_emboscada_en = randf_range(EMBOSCADA_CADA.x, EMBOSCADA_CADA.y)
	emboscadas_salieron = 0
	emboscados_muertos = 0
	panzones = 0
	_panzon_hora = -1
	_panzon_pendiente = false


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
	emboscadas = modo["emboscadas"]
	panzon_prob = modo["panzon"]


func _physics_process(delta: float) -> void:
	if ciclo == null or not ciclo.es_noche():
		return
	var vivos := zombis.vivos()
	var h := hora()
	if vivos > mas_juntos:
		mas_juntos = vivos
		hora_mas_juntos = h
	_respirar(delta)
	_emboscadas(delta, vivos, h)
	_panzon(h)
	# Las oleadas no esperan a los emboscados
	var de_oleada := vivos - _emboscados.size()
	_desde_grupo += delta
	if _pendientes.is_empty():
		var cuantos := grupo(h)
		var listo := de_oleada <= QUEDAN or (_desde_grupo >= ESPERA_MAX and (de_oleada < cuantos or not _tope))
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
	# Pasado el cupo del tinaco, este va por el jugador (se cuenta antes de sacarlo)
	var de_mas := zombis.cupo_tinaco > 0 and zombis.al_tinaco() >= zombis.cupo_tinaco
	var zombi := zombis.sacar(lugar, randf() < _corredores)
	zombi.por_jugador = de_mas
	if not zombi.murio.is_connected(_murio):
		zombi.murio.connect(_murio)


func _panzon(h: float) -> void:
	if panzon_prob <= 0.0 or h < PANZON_DESDE or h >= ULTIMA:
		return
	if get_tree().get_first_node_in_group("panzon") != null:
		return
	var hora_entera := int(floor(h))
	if hora_entera != _panzon_hora:
		_panzon_hora = hora_entera
		if randf() < panzon_prob:
			_panzon_pendiente = true
	if panzones == 0 and h >= PANZON_SEGURO:
		_panzon_pendiente = true
	if not _panzon_pendiente:
		return
	var lugar := _lugar(randf() * TAU)
	if lugar == Vector3.INF:
		return   # todo ese lado se ve o esta tapado: otro lado en el siguiente cuadro
	_panzon_pendiente = false
	var panzon := zombis.aparecer_panzon(lugar)
	panzon.murio.connect(_murio)
	panzones += 1
	print("El Panzon sale a las %s" % texto_hora(h))


func _emboscadas(delta: float, vivos: int, h: float) -> void:
	# Los que ya cayeron (o volvieron a la reserva) dejan de contar
	for z in _emboscados.duplicate():
		if not z.despierto or not z.emboscada or z.estado == Zombie.Estado.MUERTO:
			if z.estado == Zombie.Estado.MUERTO:
				emboscados_muertos += 1
			_emboscados.erase(z)
	if not emboscadas or h < EMBOSCADA_DESDE or h >= ULTIMA:
		return
	_emboscada_en -= delta
	if _emboscada_en > 0.0:
		return
	var cuantos := randi_range(EMBOSCADA_GRUPO.x, EMBOSCADA_GRUPO.y)
	if _respiro > 0.0 or vivos + cuantos > zombis.max_total:
		return
	_emboscada_en = randf_range(EMBOSCADA_CADA.x, EMBOSCADA_CADA.y)
	_emboscar(cuantos)


# `cuantos` cazadores del lado donde esta el jugador, que van por el
func _emboscar(cuantos: int) -> void:
	var jugador := zombis.get_tree().get_first_node_in_group("jugador") as Node3D
	if jugador == null:
		return
	var a := jugador.global_position - centro
	# Al reves de _lugar: punto = centro + (sin, -cos) * distancia
	var lado := atan2(a.x, -a.z)
	var salieron := 0
	for i in cuantos:
		var lugar := _lugar(lado + randf_range(-ABRE, ABRE))
		if lugar == Vector3.INF:
			lugar = _lugar(lado + PI)
		if lugar == Vector3.INF:
			continue
		var zombi := zombis.sacar(lugar, true)
		zombi.emboscada = true
		zombi.alertar(false)
		if not zombi.murio.is_connected(_murio):
			zombi.murio.connect(_murio)
		_emboscados.append(zombi)
		salieron += 1
	if salieron > 0:
		emboscadas_salieron += 1
		print("Emboscada %d: %d a las %s (emboscados muertos hasta ahora: %d)" % [emboscadas_salieron, salieron, texto_hora(hora()), emboscados_muertos])


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
	var tono := randf_range(GEMIDO_TONO.x, GEMIDO_TONO.y)
	if not Sonidos.turno("rugido", tono):
		return
	var voz := AudioStreamPlayer3D.new()
	voz.stream = Sonidos.sonido("rugido")
	voz.pitch_scale = tono
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
	var camara := zombis.get_viewport().get_camera_3d()
	for i in INTENTOS:
		var a := angulo + randf_range(-ABRE, ABRE)
		var punto := centro + Vector3(sin(a), 0.0, -cos(a)) * randf_range(DISTANCIA.x, DISTANCIA.y)
		# Que nunca salgan frente a la camara (si todo ese lado se ve, sale de otro)
		if Zombis.a_la_vista(camara, punto) or _encima_de_otro(punto):
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

