class_name Desaguadora
extends Node3D

# LA DESAGUADORA: la jefa del desague de abajo del bano del Sotano (Desague.gd la pone; el modelo
# es models/sotano/desaguadora.glb de tools/blender/sotano/desague.py). Una mujer hinchada sin cara,
# de pelo de coladera y agua negra, que se hunde en una coladera y sale por otra.
# Sin rig: el codigo mueve sus vacios (Hombro_L/R, Cabeza, Pelo) y avisa cada ataque antes:
#   ZARPAZO  levanta el brazo derecho (AVISO_ZARPAZO s) y barre enfrente (cono, ZARPAZO_RADIO).
#   CHARCOS  marca circulos rojos donde estas (y dos mas cerca); al rato revientan de agua negra.
#   PELO     (fase 2+) una raya roja hacia ti y luego el latigo de pelo por esa raya.
#   GOTAS    (fase 3) del techo caen chorros donde estas, cada GOTAS_CADA s.
#   HUNDIRSE se va por una coladera lejos de ti y sale por otra.
# Despues del zarpazo se le abre el pecho (EXPUESTA_DURA s): el corazon brilla, el machete le pega
# x EXPUESTA_MULT y la pistola al corazon (PuntoDebil) x CORAZON_MULT. Al cuerpo la pistola le da
# por el PuntoDebil "cuerpo" (x1). El machete le llega porque esta en el grupo "zombis" con
# recibir_golpe y radio_golpe (como La Mojiganga).
# Fases por vida: FASE_2 y FASE_3 (grita, mas rapida). Te avisa Desague.gd con las senales.

signal vida_cambio(fraccion: float)
signal fase_cambio(fase: int)
signal murio

enum Estado { SALE, ESPERA, ZARPAZO, CHARCOS, PELO, HUNDE, EXPUESTA, MUERTA }

const MODELO := preload("res://models/sotano/desaguadora.glb")
const VIDA := 650
const FASE_2 := 0.6
const FASE_3 := 0.25
const AVISO_ZARPAZO := 0.75
const ZARPAZO_RADIO := 3.2
const ZARPAZO_CONO := 0.35           # dot minimo (unos 70 grados de cada lado)
const DANO_ZARPAZO := 20
const AVISO_CHARCO := 1.15
const CHARCO_RADIO := 1.0
const DANO_CHARCO := 14
const AVISO_PELO := 0.8
const PELO_LARGO := 7.0
const PELO_ANCHO := 0.7
const DANO_PELO := 16
const GOTAS_CADA := 2.6
const DANO_GOTA := 8
const EXPUESTA_DURA := 1.7
const EXPUESTA_MULT := 2.0
const CORAZON_MULT := 2.5
const VELOCIDAD := 0.7               # m/s (escena) cuando se te acerca
const SALE_DURA := 1.6
const HUNDE_DURA := 1.1
const PROFUNDO := 3.4                # lo que se hunde

var arena: Node3D                    # Desague.gd: coladeras, marcas, el jugador y el rescate
var estado := Estado.SALE
var vida := VIDA
var fase := 1
var radio_golpe := 0.75              # Player._radio_de: lo ancho del cuerpo
var es_jefe := true

var _modelo: Node3D
var _hombros: Array[Node3D] = []
var _cabeza: Node3D
var _pelo: Node3D
var _corazon_luz: Node3D
var _cuerpo_punto: PuntoDebil
var _corazon_punto: PuntoDebil
var _t := 0.0                        # tiempo en el estado
var _vivo := 0.0                     # tiempo total (respira, se mece)
var _gotas_t := 0.0
var _ataques := 0
var _jugador: Node3D
var _avisos: Array[Node3D] = []


func _ready() -> void:
	add_to_group("zombis")
	_modelo = MODELO.instantiate()
	add_child(_modelo)
	for nombre in ["Hombro_L", "Hombro_R"]:
		_hombros.append(_modelo.find_child(nombre, true, false) as Node3D)
	_cabeza = _modelo.find_child("Cabeza", true, false) as Node3D
	_pelo = _modelo.find_child("Pelo", true, false) as Node3D
	_corazon_luz = _modelo.find_child("Corazon_luz", true, false) as Node3D
	if _corazon_luz:
		_corazon_luz.visible = false
	var corazon := _modelo.find_child("Corazon", true, false) as Node3D
	var rojo := StandardMaterial3D.new()
	rojo.albedo_color = Color(0, 0, 0, 0)
	rojo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cuerpo_punto = PuntoDebil.new()
	_cuerpo_punto.armar(self, "cuerpo", 0.65, rojo)
	add_child(_cuerpo_punto)
	_cuerpo_punto.position = Vector3(0, 1.75, 0)
	_corazon_punto = PuntoDebil.new()
	_corazon_punto.armar(self, "corazon", 0.2, rojo)
	if corazon:
		corazon.add_child(_corazon_punto)
	else:
		add_child(_corazon_punto)
	_corazon_punto.activo(false)
	_cuerpo_punto.malla.visible = false
	_corazon_punto.malla.visible = false
	_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	_cambiar(Estado.SALE)


func _process(delta: float) -> void:
	_vivo += delta
	_t += delta
	_mecer()
	if estado == Estado.MUERTA:
		return
	match estado:
		Estado.SALE:
			_modelo.position.y = lerpf(-PROFUNDO, 0.0, ease(clampf(_t / SALE_DURA, 0.0, 1.0), 0.4))
			if _t >= SALE_DURA:
				_cambiar(Estado.ESPERA)
		Estado.ESPERA:
			_esperar(delta)
		Estado.ZARPAZO:
			_zarpazo()
		Estado.CHARCOS:
			_charcos()
		Estado.PELO:
			_latigo()
		Estado.HUNDE:
			_hundir()
		Estado.EXPUESTA:
			_inclinar(-0.25)
			if _t >= EXPUESTA_DURA * (0.8 if fase == 3 else 1.0):
				_exponer(false)
				_cambiar(Estado.ESPERA)
	# Fase 3: le llueve agua negra del techo encima de ti
	if fase >= 3 and estado != Estado.SALE:
		_gotas_t += delta
		if _gotas_t >= GOTAS_CADA:
			_gotas_t = 0.0
			_aviso_circulo(_al_jugador(Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))), 0.8, 0.9, DANO_GOTA, true)


# --- Estados ---

func _cambiar(nuevo: Estado) -> void:
	estado = nuevo
	_t = 0.0


func _esperar(delta: float) -> void:
	_mirar_al_jugador(delta, 2.0)
	_brazos(0.0, 0.0, delta)
	var lejos := _distancia()
	if lejos > ZARPAZO_RADIO * 0.85:
		var hacia := (_jugador.global_position - global_position) if _jugador else Vector3.ZERO
		hacia.y = 0.0
		if hacia.length() > 0.01:
			global_position += hacia.normalized() * VELOCIDAD * (1.4 if fase == 3 else 1.0) * delta * global_basis.get_scale().x
	var pausa := 1.1 if fase == 1 else (0.8 if fase == 2 else 0.55)
	if _t < pausa:
		return
	_ataques += 1
	if _ataques % 5 == 0 or lejos > 7.0:
		_cambiar(Estado.HUNDE)
	elif lejos <= ZARPAZO_RADIO:
		_cambiar(Estado.ZARPAZO)
	elif fase >= 2 and randf() < 0.5:
		_cambiar(Estado.PELO)
	else:
		_cambiar(Estado.CHARCOS)


func _zarpazo() -> void:
	var aviso := AVISO_ZARPAZO * (0.8 if fase == 3 else 1.0)
	if _t < aviso:
		_mirar_al_jugador(get_process_delta_time(), 3.0)
		_brazos(0.0, lerpf(0.0, 2.4, _t / aviso), get_process_delta_time(), true)
		return
	var golpe := (_t - aviso) / 0.25
	_brazos(0.0, lerpf(2.4, 0.6, clampf(golpe, 0.0, 1.0)), get_process_delta_time(), true)
	if golpe >= 0.5 and not get_meta("pego", false):
		set_meta("pego", true)
		Sonidos.tocar(self, "golpe", -2.0, 0.6)
		if _jugador and _distancia() <= ZARPAZO_RADIO:
			var frente := -global_basis.z
			frente.y = 0.0
			var hacia := _jugador.global_position - global_position
			hacia.y = 0.0
			if hacia.length() < 0.6 or frente.normalized().dot(hacia.normalized()) >= ZARPAZO_CONO:
				_herir_jugador(DANO_ZARPAZO, 1.6)
	if golpe >= 1.0:
		remove_meta("pego")
		_exponer(true)
		_cambiar(Estado.EXPUESTA)


func _charcos() -> void:
	if _t == get_process_delta_time() or not has_meta("charcos"):
		set_meta("charcos", true)
		_brazos(1.2, 1.2, 0.0, true)
		Sonidos.tocar(self, "rugido", -10.0, 0.6)
		var n := 3 if fase == 1 else 5
		for k in n:
			var p := _al_jugador(Vector3.ZERO if k == 0 else Vector3(randf_range(-2.2, 2.2), 0, randf_range(-2.2, 2.2)))
			_aviso_circulo(p, CHARCO_RADIO, AVISO_CHARCO * (0.85 if fase == 3 else 1.0), DANO_CHARCO, false)
	_brazos(1.2, 1.2, get_process_delta_time(), true)
	if _t >= 1.4:
		remove_meta("charcos")
		_cambiar(Estado.ESPERA)


func _latigo() -> void:
	if not has_meta("raya"):
		var hacia := (_jugador.global_position - global_position) if _jugador else -global_basis.z
		hacia.y = 0.0
		set_meta("raya", hacia.normalized())
		_aviso_raya(hacia.normalized(), AVISO_PELO)
	var dir: Vector3 = get_meta("raya")
	_girar_a(dir, get_process_delta_time(), 6.0)
	if _pelo:
		_pelo.rotation.x = lerpf(0.0, -1.2, clampf((_t - AVISO_PELO) / 0.15, 0.0, 1.0)) if _t > AVISO_PELO else -0.15 * sin(_t * 20.0)
	if _t >= AVISO_PELO + 0.1 and not get_meta("pego", false):
		set_meta("pego", true)
		Sonidos.tocar(self, "golpe", -4.0, 1.3)
		if _jugador:
			var p := _jugador.global_position - global_position
			p.y = 0.0
			var largo := p.dot(dir)
			var lado := (p - dir * largo).length()
			var escala := global_basis.get_scale().x
			if largo > 0.0 and largo <= PELO_LARGO * escala and lado <= PELO_ANCHO * escala:
				_herir_jugador(DANO_PELO, 1.2)
	if _t >= AVISO_PELO + 0.6:
		remove_meta("raya")
		remove_meta("pego")
		if _pelo:
			_pelo.rotation.x = 0.0
		_cambiar(Estado.ESPERA)


func _hundir() -> void:
	if _t < HUNDE_DURA:
		_modelo.position.y = lerpf(0.0, -PROFUNDO, ease(_t / HUNDE_DURA, 2.0))
		return
	# Sale por la coladera mas lejos de ti
	if arena:
		var mejor: Vector3 = global_position
		var lejos := -1.0
		for p: Vector3 in arena.call("coladeras"):
			var d := p.distance_to(_jugador.global_position) if _jugador else 0.0
			if d > lejos:
				lejos = d
				mejor = p
		global_position = mejor
	Sonidos.tocar(self, "rugido", -8.0, 0.5)
	_cambiar(Estado.SALE)


# --- Golpes que recibe ---

# Igual que Zombie.recibir_golpe (el machete): 0 nada, 1 pego, 2 mato
func recibir_golpe(dano: int, desde: Vector3, _fuerza := 1.0, _truena_en := 80, cuerpo_a_cuerpo := true, _cabeza_ := false, _fuente := "", _revienta := false) -> int:
	return _herir(int(dano * (EXPUESTA_MULT if estado == Estado.EXPUESTA and cuerpo_a_cuerpo else 1.0)), desde)


# Los PuntoDebil (la pistola): "cuerpo" x1, "corazon" x CORAZON_MULT
func golpe_punto(id: String, dano: int, desde: Vector3, _cuerpo_a_cuerpo: bool) -> int:
	return _herir(int(dano * (CORAZON_MULT if id == "corazon" else 1.0)), desde)


func _herir(dano: int, _desde: Vector3) -> int:
	if estado == Estado.MUERTA or estado == Estado.SALE and _t < SALE_DURA * 0.5 or estado == Estado.HUNDE and _t > HUNDE_DURA * 0.5:
		return 0
	vida = maxi(vida - dano, 0)
	vida_cambio.emit(float(vida) / VIDA)
	_parpadeo()
	if vida <= 0:
		_morir()
		return 2
	var fr := float(vida) / VIDA
	var nueva := 1 if fr > FASE_2 else (2 if fr > FASE_3 else 3)
	if nueva != fase:
		fase = nueva
		fase_cambio.emit(fase)
		Sonidos.tocar(self, "rugido", 0.0, 0.45)
	return 1


func _morir() -> void:
	estado = Estado.MUERTA
	_exponer(false)
	_cuerpo_punto.activo(false)
	for a in _avisos:
		if is_instance_valid(a):
			a.queue_free()
	Sonidos.tocar(self, "rugido", 2.0, 0.4)
	var t := create_tween()
	t.tween_property(_modelo, "position:y", -PROFUNDO, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void: murio.emit())


# --- Movimiento y poses ---

func _mecer() -> void:
	var temblor := 0.0 if estado != Estado.MUERTA else sin(_vivo * 40.0) * 0.03
	if _cabeza:
		_cabeza.rotation = Vector3(0.15 + sin(_vivo * 0.9) * 0.08, sin(_vivo * 0.6) * 0.12, sin(_vivo * 1.3) * 0.05 + temblor)
	if _pelo and estado != Estado.PELO:
		_pelo.rotation.z = sin(_vivo * 1.1) * 0.06
	_modelo.rotation.z = sin(_vivo * 0.7) * 0.03


func _brazos(izq: float, der: float, delta: float, rapido := false) -> void:
	var v := 1.0 if rapido else minf(delta * 3.0, 1.0)
	for k in 2:
		var h := _hombros[k]
		if h == null:
			continue
		var meta := (izq if k == 0 else der) + sin(_vivo * 1.4 + k) * 0.06
		h.rotation.x = lerpf(h.rotation.x, meta, v)


func _inclinar(cuanto: float) -> void:
	_modelo.rotation.x = lerpf(_modelo.rotation.x, cuanto, 0.1)


func _mirar_al_jugador(delta: float, rapidez: float) -> void:
	if _jugador == null:
		return
	var hacia := _jugador.global_position - global_position
	hacia.y = 0.0
	_girar_a(hacia, delta, rapidez)


func _girar_a(hacia: Vector3, delta: float, rapidez: float) -> void:
	if hacia.length() < 0.01:
		return
	var meta := atan2(-hacia.x, -hacia.z)
	rotation.y = lerp_angle(rotation.y, meta, minf(delta * rapidez, 1.0))


func _distancia() -> float:
	if _jugador == null:
		return 99.0
	var d := _jugador.global_position - global_position
	d.y = 0.0
	return d.length() / global_basis.get_scale().x


func _al_jugador(corre: Vector3) -> Vector3:
	var p := _jugador.global_position if _jugador else global_position
	return p + corre * global_basis.get_scale().x


func _exponer(si: bool) -> void:
	if _corazon_luz:
		_corazon_luz.visible = si
	_corazon_punto.activo(si)
	_corazon_punto.malla.visible = false
	if not si:
		_modelo.rotation.x = 0.0


func _parpadeo() -> void:
	var t := create_tween()
	t.tween_property(_modelo, "scale", Vector3.ONE * 1.04, 0.05)
	t.tween_property(_modelo, "scale", Vector3.ONE, 0.1)


func _herir_jugador(dano: int, empuje: float) -> void:
	if arena and arena.has_method("herir_jugador"):
		arena.call("herir_jugador", dano, global_position, empuje)


# --- Avisos en el piso (rojos) y lo que revienta ---

# Un circulo rojo que crece en `donde`; al acabar revienta de agua negra y hiere si sigues adentro
func _aviso_circulo(donde: Vector3, radio: float, espera: float, dano: int, del_techo: bool) -> void:
	var escala := global_basis.get_scale().x
	var disco := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radio
	m.bottom_radius = radio
	m.height = 0.01
	m.radial_segments = 20
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.9, 0.05, 0.05, 0.35)
	m.material = mat
	disco.mesh = m
	get_parent().add_child(disco)
	disco.global_position = Vector3(donde.x, global_position.y + 0.03, donde.z)
	disco.scale = Vector3(0.2, 1, 0.2) * escala
	_avisos.append(disco)
	var t := create_tween()
	t.tween_property(disco, "scale", Vector3(1, 1, 1) * escala, espera).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void:
		if estado == Estado.MUERTA:
			disco.queue_free()
			return
		_chorro(disco.global_position, radio * escala, del_techo)
		if _jugador:
			var d := _jugador.global_position - disco.global_position
			d.y = 0.0
			if d.length() <= radio * escala:
				_herir_jugador(dano, 0.6)
		disco.queue_free())


# La raya roja del latigo de pelo
func _aviso_raya(dir: Vector3, espera: float) -> void:
	var escala := global_basis.get_scale().x
	var raya := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(PELO_ANCHO * 2.0, PELO_LARGO)
	q.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.9, 0.05, 0.05, 0.3)
	q.material = mat
	raya.mesh = q
	get_parent().add_child(raya)
	raya.global_position = global_position + dir * PELO_LARGO * 0.5 * escala + Vector3.UP * 0.03
	raya.global_basis = Basis(Vector3.UP, atan2(dir.x, dir.z)).scaled(Vector3.ONE * escala)
	_avisos.append(raya)
	var t := create_tween()
	t.tween_interval(espera + 0.3)
	t.tween_callback(raya.queue_free)


# Un chorro de agua negra que sube (o cae del techo) y se deshace
func _chorro(donde: Vector3, radio: float, del_techo: bool) -> void:
	var chorro := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radio * 0.5
	c.bottom_radius = radio * 0.8
	c.height = 1.0
	c.radial_segments = 10
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.025, 0.03)
	mat.roughness = 0.1
	mat.metallic_specular = 1.0
	c.material = mat
	chorro.mesh = c
	get_parent().add_child(chorro)
	var alto := 3.2 * global_basis.get_scale().x
	chorro.global_position = donde + Vector3.UP * (alto * 0.5 if del_techo else 0.0)
	chorro.scale = Vector3(1, 0.05, 1)
	Sonidos.tocar(chorro, "paso", -2.0, 0.4)
	var t := create_tween()
	t.tween_property(chorro, "scale:y", alto if del_techo else alto * 0.6, 0.12)
	t.tween_property(chorro, "position:y", chorro.position.y + (0.0 if del_techo else alto * 0.3), 0.12)
	t.tween_property(chorro, "scale", Vector3(0.2, 0.05, 0.2), 0.35)
	t.tween_callback(chorro.queue_free)
