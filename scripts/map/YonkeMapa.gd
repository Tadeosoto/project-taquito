class_name YonkeMapa
extends Node3D

# El Yonke de Don Chava en el mundo (en map_test.tscn, en un baldio de Parques de Santa Mugre;
# en el safehouse y en la colonia de Blender, con su propia barda). El patio es un modelo hecho en
# Blender (tools/blender/negocios/yonke.py -> models/negocios/yonke/yonke_fuera.glb): carros
# deshuesados y encimados, llantas, tambos, un tejaban con refacciones y la oficina en un
# contenedor madreado, con el letrero pintado a mano sobre el porton. Aqui se le ponen los montones
# de Chatarra en sus marcas y la flecha amarilla en la banqueta que mete al interior
# (scenes/interiores/yonke.tscn, por Interiores.gd como cualquier tienda).
# +Z del nodo da a la calle (la flecha va de ese lado); el patio mide 28 x 40 m hacia -Z.
#
# La prensa trabaja (_prensa): la placa baja, aplasta el carro de abajo, sube, y el carro vuelve a
# estar entero para el siguiente ciclo; solo se mueve con el jugador cerca. Sus sonidos son
# "prensa_baja" y "prensa_sube" en Sonidos.ARCHIVOS (JJ los escoge; mientras no esten no suena nada).
# De dia trabajan los chalanes (_chalanes_poner) en las marcas "Marca_Chalan_<clip>_<n>" del modelo,
# con ese clip de Quaternius; uno carga cajas entre "Marca_Ruta_A" y "_B" y otro te habla en
# "Marca_Platica". Al anochecer se van (Ciclo.anochecio) y vuelven al amanecer.

const NOMBRE := "El Yonke de Don Chava"
const LEJOS := 140.0             # m hasta donde se dibuja
const MODELO := preload("res://models/negocios/yonke/yonke_fuera.glb")
const FLECHA_EN := Vector3(0.0, 0.0, 3.0)   # si el modelo no trae Marca_Flecha
const FLECHA_RADIO := 0.9
const PATIO := Rect2(-15.0, -41.0, 30.0, 42.0)   # x, z, ancho, largo (yonke.py PATIO con 1 m de orilla)
const NPC := "res://scenes/npc.tscn"   # con load(): este script lo cargan herramientas sin autoloads
# La prensa: segundos del ciclo y de cada tramo
const PRENSA_CICLO := 12.0
const PRENSA_BAJA := Vector2(2.0, 4.0)      # baja hasta tocar el carro
const PRENSA_APLASTA := Vector2(4.0, 7.5)   # lo aplasta
const PRENSA_SUBE := Vector2(9.0, 11.5)     # sube; el carro sigue aplastado hasta que acaba el ciclo
const PRENSA_APLASTADO := 0.35              # lo que queda del alto del carro
const PRENSA_CERCA := 70.0                  # m: mas lejos no se mueve
const PRENSA_OIDO := 35.0                   # m: mas lejos no suena
# Los chalanes
const CHALAN_SEMILLA := "yonke_chalan_%d"
const CARGADOR_VELOCIDAD := 1.1             # m/s
const DETALLE_LEJOS := 60.0                 # m: lo chico (Patio_detalle) solo de cerca
# La grua de electroiman, en el mismo ciclo que la prensa: segundos en que va a la fila, toma el
# carro y lo trae; lo suelta al acabar el ciclo, cuando el carro de la prensa vuelve a estar entero
const GRUA_VA := Vector2(1.0, 5.0)
const GRUA_TOMA_EN := 5.5
const GRUA_TRAE := Vector2(6.0, 11.0)
const PERRO_LADRA := 14.0                   # m: mas cerca, el perro del velador ladra (de noche)
const FUEGO_COLOR := Color(1.0, 0.55, 0.2)
const LUZ_REFLECTOR := Color(1.0, 0.93, 0.8)
const PLATICA := "¿Buscas a la Chava? Está en la oficina, en el contenedor. Yo nomás desarmo."

@export var puntos_path: NodePath
# La barda de lamina del modelo (los nodos "Barda_*"). Siempre, tambien en map_test: ahi el patio
# se aparta con ZonasLibres y MapBardas ya no pone la malla del baldio adentro
@export var con_barda := true

var _puntos: MapPuntos
var _placa: Node3D
var _carro_prensa: Node3D
var _vastagos: Array[Node3D] = []
var _placa_abajo := 0.0       # y de abajo de la placa arriba (en reposo)
var _placa_alto := 0.0        # de abajo de la placa a la punta de sus costillas
var _carro_piso := 0.0
var _carro_alto := 1.0
var _vastago_largo := 1.0
var _tiempo := 0.0
var _jugador: Node3D
var _chalanes: Node3D
var _cargador: Node3D
var _ruta: Array[Vector3] = []
var _hacia := 1
var _pluma: Node3D
var _carga: Node3D
var _angulo_toma := 0.0
var _angulo_suelta := 0.0
var _noche: Node3D
var _perro: Node3D
var _ladrido := 0.0
var _fuego: OmniLight3D


# El patio (con 1 m de orilla) se aparta antes de que MapCasas cargue: en map_test no cabia entre las
# casas modelo y se quitan las que lo pisan (ZonasLibres)
func _enter_tree() -> void:
	ZonasLibres.agregar(self, PATIO)


func _exit_tree() -> void:
	ZonasLibres.quitar(self)


func _ready() -> void:
	add_to_group("yonke")
	_puntos = get_node_or_null(puntos_path) as MapPuntos
	var patio := MODELO.instantiate()
	patio.name = "Patio"
	add_child(patio)
	if not con_barda:
		for nodo in patio.find_children("Barda_*", "", true, false):
			nodo.queue_free()
	for malla in patio.find_children("*", "GeometryInstance3D", true, false):
		(malla as GeometryInstance3D).visibility_range_end = DETALLE_LEJOS if String(malla.name).begins_with("Patio_detalle") else LEJOS
	var flecha_en := FLECHA_EN
	for marca in patio.find_children("Marca_*", "", true, false):
		var m := marca as Node3D
		if m.name.begins_with("Marca_Chatarra"):
			var monton := Chatarra.new()
			monton.adorno = true
			monton.position = m.position
			monton.scale = Vector3.ONE * 1.8
			monton.rotation.y = m.position.x
			add_child(monton)
		elif m.name == "Marca_Flecha":
			flecha_en = m.position
	_marcador(flecha_en)
	_preparar_prensa(patio)
	_preparar_grua(patio)
	_chalanes_poner(patio)
	_vida(patio)


# La flecha de las tiendas (MapPuntos.flecha) y su area: al pisarla se entra
func _marcador(en: Vector3) -> void:
	var area := Area3D.new()
	area.name = "Marcador"
	area.position = en
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = FLECHA_RADIO
	cilindro.height = 2.0
	forma.shape = cilindro
	forma.position.y = 1.0
	area.add_child(forma)
	area.add_child(MapPuntos.flecha())
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is Player and _puntos:
			_puntos.entrar_negocio.emit("yonke", "yonke", NOMBRE, false, area))


# --- La prensa

func _preparar_prensa(patio: Node) -> void:
	_placa = patio.find_child("Prensa_mov_placa", true, false) as Node3D
	_carro_prensa = patio.find_child("Prensa_mov_carro", true, false) as Node3D
	for nombre in ["Prensa_mov_vastago0", "Prensa_mov_vastago1"]:
		var v := patio.find_child(nombre, true, false) as Node3D
		if v:
			_vastagos.append(v)
	if _placa == null or _carro_prensa == null:
		return
	# Las medidas salen del modelo (yonke.py PRENSA_*): asi no se descuadran si cambia
	var caja := _aabb(_placa)
	_placa_abajo = caja.position.y
	_placa_alto = caja.size.y
	_carro_piso = _carro_prensa.position.y
	_carro_alto = maxf(_aabb(_carro_prensa).end.y, 0.5)
	if not _vastagos.is_empty():
		_vastago_largo = maxf(_aabb(_vastagos[0]).size.y, 0.01)


func _aabb(nodo: Node3D) -> AABB:
	var malla := nodo as MeshInstance3D
	if malla == null:
		for hijo in nodo.find_children("*", "MeshInstance3D", true, false):
			malla = hijo
			break
	return malla.get_aabb() if malla and malla.mesh else AABB()


func _process(delta: float) -> void:
	if _jugador == null:
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	var distancia := global_position.distance_to(_jugador.global_position) if _jugador else 0.0
	if _cargador and _cargador.is_visible_in_tree():
		_caminar(delta)
	if _placa == null or distancia > PRENSA_CERCA:
		return
	var antes := _tiempo
	_tiempo = fmod(_tiempo + delta, PRENSA_CICLO)
	if distancia < PRENSA_OIDO:
		if antes < PRENSA_BAJA.x and _tiempo >= PRENSA_BAJA.x:
			_sonar("prensa_baja")
		elif antes < PRENSA_SUBE.x and _tiempo >= PRENSA_SUBE.x:
			_sonar("prensa_sube")
	_prensa(_tiempo)
	_grua(_tiempo)
	if _perro and _noche.visible and distancia < PERRO_LADRA and _ladrido <= 0.0:
		_ladrido = randf_range(4.0, 8.0)
		_sonar("perro_ladra")
	_ladrido -= delta


# Solo si ya esta en Sonidos.ARCHIVOS: un nombre que no esta truena en Sonidos (sus cupos)
func _sonar(nombre: String) -> void:
	if Sonidos.ARCHIVOS.has(nombre):
		Sonidos.tocar(self, nombre, -4.0)


# La placa y el carro en el segundo t del ciclo
func _prensa(t: float) -> void:
	var techo := _carro_piso + _carro_alto              # techo del carro entero
	var aplastado := _carro_piso + _carro_alto * PRENSA_APLASTADO
	var abajo := _placa_abajo                           # donde va lo de abajo de la placa
	var alto_carro := 1.0
	if t >= PRENSA_BAJA.x and t < PRENSA_BAJA.y:
		abajo = lerpf(_placa_abajo, techo, _suave(inverse_lerp(PRENSA_BAJA.x, PRENSA_BAJA.y, t)))
	elif t >= PRENSA_APLASTA.x and t < PRENSA_SUBE.x:
		abajo = lerpf(techo, aplastado, clampf(inverse_lerp(PRENSA_APLASTA.x, PRENSA_APLASTA.y, t), 0.0, 1.0))
		alto_carro = (abajo - _carro_piso) / _carro_alto
	elif t >= PRENSA_SUBE.x and t < PRENSA_SUBE.y:
		abajo = lerpf(aplastado, _placa_abajo, _suave(inverse_lerp(PRENSA_SUBE.x, PRENSA_SUBE.y, t)))
		alto_carro = PRENSA_APLASTADO
	elif t >= PRENSA_SUBE.y:
		alto_carro = PRENSA_APLASTADO
	_placa.position.y = abajo - _placa_abajo
	_carro_prensa.scale.y = alto_carro
	# El carro aplastado tambien se ensancha un poco
	_carro_prensa.scale.z = 1.0 + (1.0 - alto_carro) * 0.12
	for v in _vastagos:
		v.scale.y = maxf((v.position.y - (abajo + _placa_alto)) / _vastago_largo, 0.01)


func _suave(x: float) -> float:
	return smoothstep(0.0, 1.0, clampf(x, 0.0, 1.0))


# --- Los chalanes (de dia)

func _chalanes_poner(patio: Node) -> void:
	_chalanes = Node3D.new()
	_chalanes.name = "Chalanes"
	add_child(_chalanes)
	var n := 0
	for marca in patio.find_children("Marca_*", "", true, false):
		var m := marca as Node3D
		var nombre := String(m.name)
		if nombre.begins_with("Marca_Chalan_"):
			var clip := nombre.trim_prefix("Marca_Chalan_")
			clip = clip.substr(0, clip.rfind("_"))
			var chalan := Node3D.new()
			chalan.name = "Chalan_%d" % n
			chalan.transform = m.transform
			_chalanes.add_child(chalan)
			Civiles.poner(chalan, _modelo_hombre(n), clip)
			n += 1
		elif nombre.begins_with("Marca_Ruta_"):
			_ruta.append(m.position)
		elif nombre == "Marca_Platica":
			var npc := (load(NPC) as PackedScene).instantiate()
			npc.set("modelo", _modelo_hombre(n + 7))
			npc.set("nombre", "Chalán")
			npc.set("dialogue", PLATICA)
			npc.set("serenol", 0)
			(npc as Node3D).transform = m.transform
			_chalanes.add_child(npc)
	if _ruta.size() >= 2:
		_cargador = Node3D.new()
		_cargador.name = "Cargador"
		_cargador.position = _ruta[0]
		_chalanes.add_child(_cargador)
		Civiles.poner(_cargador, _modelo_hombre(n + 3), "Walk_Carry")
		# La caja que carga, entre las manos (el chalan ve hacia -Z)
		var caja := MeshInstance3D.new()
		var forma := BoxMesh.new()
		forma.size = Vector3(0.45, 0.32, 0.35)
		caja.mesh = forma
		var carton := StandardMaterial3D.new()
		carton.albedo_color = Color(0.62, 0.45, 0.28)
		caja.material_override = carton
		caja.position = Vector3(0.0, 1.0, -0.35)
		_cargador.add_child(caja)
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	if ciclo:
		ciclo.anochecio.connect(func() -> void: _de_dia(false))
		ciclo.amanecio.connect(func() -> void: _de_dia(true))
		if ciclo.has_method("es_noche"):
			_de_dia(not ciclo.es_noche())


func _de_dia(si: bool) -> void:
	_chalanes.visible = si
	_chalanes.process_mode = Node.PROCESS_MODE_INHERIT if si else Node.PROCESS_MODE_DISABLED


# Siempre los mismos hombres del pack (Civiles.elegir con una semilla fija), nunca mujeres: son
# los chalanes del yonke
func _modelo_hombre(n: int) -> String:
	for k in 50:
		var nombre := Civiles.elegir(CHALAN_SEMILLA % (n * 31 + k))
		if nombre.begins_with("hombre_"):
			return nombre
	return "hombre_01"


func _caminar(delta: float) -> void:
	var meta := _ruta[1] if _hacia > 0 else _ruta[0]
	var falta := meta - _cargador.position
	falta.y = 0.0
	if falta.length() < 0.1:
		_hacia = -_hacia
		return
	var paso := falta.normalized() * CARGADOR_VELOCIDAD * delta
	_cargador.position += paso if paso.length() < falta.length() else falta
	# Ve hacia donde camina (el modelo ve hacia -Z)
	_cargador.rotation.y = atan2(-falta.x, -falta.z)


# --- La grua de electroiman

func _preparar_grua(patio: Node) -> void:
	_pluma = patio.find_child("Grua_mov_pluma", true, false) as Node3D
	_carga = patio.find_child("Grua_mov_carga", true, false) as Node3D
	var toma := patio.find_child("Marca_Grua_toma", true, false) as Node3D
	var suelta := patio.find_child("Marca_Grua_suelta", true, false) as Node3D
	if _pluma == null or toma == null or suelta == null:
		_pluma = null
		return
	# La pluma sale hacia +X de su eje: el angulo en Y que la apunta a cada lugar
	_angulo_toma = _angulo_a(toma.position)
	_angulo_suelta = _angulo_a(suelta.position)


func _angulo_a(lugar: Vector3) -> float:
	var d := lugar - _pluma.position
	return atan2(-d.z, d.x)


func _grua(t: float) -> void:
	if _pluma == null:
		return
	var angulo := _angulo_suelta
	if t >= GRUA_VA.x and t < GRUA_VA.y:
		angulo = lerp_angle(_angulo_suelta, _angulo_toma, _suave(inverse_lerp(GRUA_VA.x, GRUA_VA.y, t)))
	elif t >= GRUA_VA.y and t < GRUA_TRAE.x:
		angulo = _angulo_toma
	elif t >= GRUA_TRAE.x and t < GRUA_TRAE.y:
		angulo = lerp_angle(_angulo_toma, _angulo_suelta, _suave(inverse_lerp(GRUA_TRAE.x, GRUA_TRAE.y, t)))
	_pluma.rotation.y = angulo
	if _carga:
		_carga.rotation.y = angulo
		_carga.visible = t >= GRUA_TOMA_EN


# --- Vida: chispas del soldador y moscas (de dia), y de noche el velador con su lumbre y su
# radio, el perro y los reflectores

func _vida(patio: Node) -> void:
	_noche = Node3D.new()
	_noche.name = "Noche"
	add_child(_noche)
	for marca in patio.find_children("Marca_*", "", true, false):
		var m := marca as Node3D
		var nombre := String(m.name)
		if nombre == "Marca_Chispas" and _chalanes:
			var chispas := _particulas(Color(1.0, 0.8, 0.3), 24, 0.5, 2.5, 0.025, Vector3(0, -9.8, 0))
			chispas.position = m.position
			_chalanes.add_child(chispas)
			_sonido_3d("soldadora", m.position, _chalanes)
		elif nombre.begins_with("Marca_Moscas"):
			var moscas := _particulas(Color(0.05, 0.05, 0.05), 8, 3.0, 0.3, 0.015, Vector3.ZERO)
			moscas.position = m.position
			add_child(moscas)
		elif nombre == "Marca_Fuego":
			var lumbre := _particulas(FUEGO_COLOR, 30, 0.8, 1.2, 0.08, Vector3(0, 1.5, 0))
			lumbre.position = m.position
			_noche.add_child(lumbre)
			_fuego = OmniLight3D.new()
			_fuego.light_color = FUEGO_COLOR
			_fuego.light_energy = 2.0
			_fuego.omni_range = 7.0
			_fuego.position = m.position + Vector3.UP * 0.4
			_noche.add_child(_fuego)
		elif nombre == "Marca_Velador":
			var asiento := Node3D.new()
			asiento.transform = m.transform
			asiento.position += -m.transform.basis.z * 0.38      # Sitting_Idle: la cadera sobre la cubeta
			_noche.add_child(asiento)
			Civiles.poner(asiento, _modelo_hombre(40), "Sitting_Idle")
		elif nombre == "Marca_Radio":
			_sonido_3d("yonke_radio", m.position, _noche)
		elif nombre == "Marca_Perro":
			_perro = Node3D.new()
			_perro.transform = m.transform
			_noche.add_child(_perro)
			Gente.poner_modelo(_perro, Gente.PERRO, Gente.ALTO_PERRO)
		elif nombre.begins_with("Marca_Luz_"):
			var luz := SpotLight3D.new()
			luz.light_color = LUZ_REFLECTOR
			luz.light_energy = 3.0
			luz.spot_range = 16.0
			luz.spot_angle = 55.0
			luz.position = m.position
			luz.rotation_degrees = Vector3(-90, 0, 0)
			_noche.add_child(luz)
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	if ciclo:
		ciclo.anochecio.connect(func() -> void: _de_noche(true))
		ciclo.amanecio.connect(func() -> void: _de_noche(false))
		_de_noche(ciclo.es_noche())
	else:
		_de_noche(false)


func _de_noche(si: bool) -> void:
	_noche.visible = si
	_noche.process_mode = Node.PROCESS_MODE_INHERIT if si else Node.PROCESS_MODE_DISABLED


# Particulas sencillas (chispas, moscas, lumbre): cuadritos sin luz que salen de un punto
func _particulas(color: Color, cuantas: int, vida: float, velocidad: float, tamano: float, gravedad: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = cuantas
	p.lifetime = vida
	var proceso := ParticleProcessMaterial.new()
	proceso.direction = Vector3(0, 1, 0)
	proceso.spread = 70.0 if gravedad.y < 0.0 else 180.0
	proceso.initial_velocity_min = velocidad * 0.5
	proceso.initial_velocity_max = velocidad
	proceso.gravity = gravedad
	proceso.color = color
	p.process_material = proceso
	var quad := QuadMesh.new()
	quad.size = Vector2(tamano, tamano)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	return p


# Un sonido que se oye de cerca y en su lugar (el radio con banda, la soldadora), en loop; solo si
# JJ ya lo puso en Sonidos.ARCHIVOS (mientras, nada)
func _sonido_3d(nombre: String, en: Vector3, padre: Node) -> void:
	if not Sonidos.ARCHIVOS.has(nombre):
		return
	var voz := AudioStreamPlayer3D.new()
	voz.stream = Sonidos.sonido(nombre)
	voz.position = en
	voz.unit_size = 4.0
	voz.max_distance = 30.0
	voz.autoplay = true
	voz.finished.connect(voz.play)
	padre.add_child(voz)
