extends Node

# La pistola del jugador (Player.gd la crea como hija). 1/2 (arma_1/arma_2) o RB (cambiar_arma)
# cambian entre ella y el arma de golpe, R (recargar) recarga; con ella el clic (attack) dispara hacia la mira, al centro de la
# pantalla: la opcion A de docs/especificaciones.md 1.4, que JJ quiso probar (la votacion
# sigue abierta). Si el centro no da en un zombi, se lo lleva el mas cercano a la mira
# dentro de AYUDA grados que se vea. Las bardas y barricadas (capa 1) tapan los tiros.
# Al zombi le pega por el mismo camino que el machete (Zombie.recibir_golpe), sin la
# congelada (a tiro rapido trababa), sin empujon y sin aturdir: la pistola debilita de lejos
# y el que mata es el machete. Balas sin fin, pero con cargador y recarga sola.
# Al tiro: fogonazo, dispersion, rayo que se desvanece, empujoncito atras, casquillo y tono
# al azar. En la cabeza (CABEZA_DESDE de la capsula para arriba) pega CABEZA_MULT veces.
# Como Player.gd, la cargan scripts de tools/ antes de los autoloads: nada de nombrarlos.

const DANO := 8               # cuatro tiros a un zombi de 30 (el machete, tres golpes)
const CADENCIA := 0.22        # s entre tiros
const CARGADOR := 12
const RECARGA := 1.5          # s, sola al vaciarse
const ALCANCE := 60.0         # m
const AYUDA := 2.5            # grados alrededor de la mira
const FUERZA := 0.5           # del salpicado y el impacto (el machete es 1)
const PECHO := 1.0            # m sobre los pies donde se apunta a un zombi
const SACUDE_TIRO := 0.025    # m de la camara al disparar
const SACUDE_PEGA := 0.04     # m si le dio a uno
const SACUDE_DURA := 0.08
const TRAZO_DURA := 50        # ms del destello
const TRAZO_FUNDE := 120      # ms en que se desvanece el rayo amarillo
const TRAZO_COLOR := Color(1.0, 0.85, 0.35)
const TRAZO_GRUESO := 0.025
const DESTELLO_ENERGIA := 4.0
const DESTELLO_RANGO := 6.0
const CAPA_ZOMBIS := 2
const DISPERSION := 0.012     # rad de desvio al azar por tiro
const APUNTA_DISPERSION := 0.004 # apuntando
const CABEZA_DESDE := 1.4     # m sobre los pies (por el tamano del zombi; la capsula mide 1.8)
const CABEZA_MULT := 3
const TONO_MIN := 0.9         # pitch_scale del disparo, al azar
const TONO_MAX := 1.1
const FOGONAZO_CHISPAS := 6
const FOGONAZO_DURA := 0.06   # s
const FOGONAZO_TAMANO := 0.08 # m
const CASQUILLOS := 8         # se reusan, el mas viejo primero
const CASQUILLO_DURA := 3.0   # s en el suelo antes de esconderse
const CASQUILLO_TAMANO := Vector3(0.012, 0.012, 0.03)
const CASQUILLO_COLOR := Color(0.85, 0.65, 0.2)
const MIRA_COLOR := Color(1.0, 0.95, 0.8, 0.9)
const TEXTO_COLOR := Color(1.0, 0.85, 0.1)

var jugador: Player
var activa := false
var balas := CARGADOR
var tiros := 0      # para medir el balance (MonitorDefensa)
var aciertos := 0

var _espera := 0.0
var _recargando := 0.0
var _trazo: MeshInstance3D
var _trazo_hasta := 0
var _destello: OmniLight3D
var _trazo_material: StandardMaterial3D
var _fogonazo: CPUParticles3D
var _casquillos: Array[RigidBody3D] = []
var _casquillo_vida: Array[float] = []
var _casquillo_sig := 0
var _mira: Control
var _texto: Label
var _capa: CanvasLayer


func _ready() -> void:
	_trazo = MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(TRAZO_GRUESO, TRAZO_GRUESO, 1.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = TRAZO_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.disable_fog = true
	caja.material = material
	_trazo_material = material
	_trazo.mesh = caja
	_trazo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trazo.top_level = true
	_trazo.visible = false
	add_child(_trazo)
	_destello = OmniLight3D.new()
	_destello.light_color = TRAZO_COLOR
	_destello.light_energy = DESTELLO_ENERGIA
	_destello.omni_range = DESTELLO_RANGO
	_destello.top_level = true
	_destello.visible = false
	add_child(_destello)
	_armar_fogonazo()
	_armar_casquillos()
	_armar_pantalla()


func cambiar() -> void:
	activa = not activa
	Sonidos.tocar(self, "boton", -6.0)


func disparar() -> void:
	if _espera > 0.0 or _recargando > 0.0:
		return
	if balas <= 0:
		_recargar()
		return
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		return
	_espera = CADENCIA
	tiros += 1
	balas -= 1
	# Hace ruido: despierta a los zombis de alrededor (la ballesta, cuando la haya, no)
	Zombie.ruido(jugador.global_position, Zombie.OYE_DISPARO)
	var centro := get_viewport().get_visible_rect().size / 2.0
	var origen := camara.project_ray_origin(centro)
	var mira := camara.project_ray_normal(centro)
	var desvio := APUNTA_DISPERSION if jugador._apuntando else DISPERSION
	var hacia := mira.rotated(camara.global_basis.y, randf_range(-desvio, desvio)) \
		.rotated(camara.global_basis.x, randf_range(-desvio, desvio))
	var espacio := jugador.get_world_3d().direct_space_state
	var excluir: Array[RID] = [jugador.get_rid()]
	var rayo := PhysicsRayQueryParameters3D.create(origen, origen + hacia * ALCANCE, 1 | CAPA_ZOMBIS, excluir)
	var pego := espacio.intersect_ray(rayo)
	var punto: Vector3 = pego.position if pego else origen + hacia * ALCANCE
	var blanco: Zombie = pego.collider as Zombie if pego else null
	# Solo un tiro que de de veras arriba de la capsula es a la cabeza; la ayuda nunca
	var cabeza := blanco != null and punto.y - blanco.global_position.y >= CABEZA_DESDE * blanco._tamano
	if blanco == null:
		blanco = _ayuda(espacio, excluir, origen, mira)
		if blanco:
			punto = blanco.global_position + Vector3.UP * PECHO
	var dano := maxi(roundi(DANO * jugador._factor_dano), 1) * (CABEZA_MULT if cabeza else 1)
	var sacude := SACUDE_TIRO
	if blanco and blanco.recibir_golpe(dano, jugador.global_position, FUERZA, 80, false, cabeza) != 0:
		sacude = SACUDE_PEGA
		aciertos += 1
		Sonidos.tocar(self, "whack", -4.0 if cabeza else -10.0)
	Sonidos.tocar(self, "disparo", -4.0, randf_range(TONO_MIN, TONO_MAX))
	jugador._sacude_fuerza = sacude
	jugador._sacude_hasta = Time.get_ticks_msec() + int(SACUDE_DURA * 1000.0)
	jugador.pose_tiro()
	jugador.empujar_tiro(hacia)
	_dibujar_tiro(punto)
	_soltar_casquillo(hacia, camara.global_basis.x)
	if balas <= 0:
		_recargar()


# El zombi vivo mas cercano a la mira, dentro de AYUDA grados, que se vea desde la camara
func _ayuda(espacio: PhysicsDirectSpaceState3D, excluir: Array[RID], origen: Vector3, hacia: Vector3) -> Zombie:
	var mejor: Zombie = null
	var mejor_angulo := deg_to_rad(AYUDA)
	for zombi: Zombie in Zombie.activos:
		var pecho := zombi.global_position + Vector3.UP * PECHO
		var a := pecho - origen
		if a.length() > ALCANCE or zombi.estado == Zombie.Estado.MUERTO:
			continue
		var angulo := a.angle_to(hacia)
		if angulo >= mejor_angulo:
			continue
		var vista := PhysicsRayQueryParameters3D.create(origen, pecho, 1, excluir)
		if espacio.intersect_ray(vista):
			continue
		mejor = zombi
		mejor_angulo = angulo
	return mejor


# R: recarga antes de vaciar el cargador
func recargar() -> void:
	if balas < CARGADOR:
		_recargar()


func _recargar() -> void:
	if _recargando > 0.0:
		return
	_recargando = RECARGA
	Sonidos.tocar(self, "recarga", -6.0)
	if jugador.has_method("pose_recarga"):
		jugador.pose_recarga()


# De la boca de la pistola a donde pego
func _dibujar_tiro(punto: Vector3) -> void:
	var canon := jugador.canon()
	var largo := canon.distance_to(punto)
	if largo > 0.05:
		_trazo.global_transform = Transform3D(Basis.looking_at(punto - canon).scaled_local(Vector3(1.0, 1.0, largo)), (canon + punto) / 2.0)
		_trazo.visible = true
	_destello.global_position = canon
	_destello.visible = true
	_trazo_material.albedo_color.a = 1.0
	_trazo_hasta = Time.get_ticks_msec() + TRAZO_FUNDE
	var hacia := punto - canon
	if hacia.length_squared() > 0.0025:
		_fogonazo.global_transform = Transform3D(Basis.looking_at(hacia), canon)
	else:
		_fogonazo.global_position = canon
	_fogonazo.restart()


func _process(delta: float) -> void:
	if _trazo_hasta > 0:
		var queda := _trazo_hasta - Time.get_ticks_msec()
		_trazo_material.albedo_color.a = clampf(float(queda) / TRAZO_FUNDE, 0.0, 1.0)
		if queda <= TRAZO_FUNDE - TRAZO_DURA:
			_destello.visible = false
		if queda <= 0:
			_trazo_hasta = 0
			_trazo.visible = false
	var libre := jugador.is_physics_processing() and jugador.can_process()
	_mira.visible = activa and libre
	_texto.visible = libre
	_texto.text = _texto_arma()


func _physics_process(delta: float) -> void:
	_espera = maxf(_espera - delta, 0.0)
	for i in CASQUILLOS:
		if _casquillo_vida[i] > 0.0:
			_casquillo_vida[i] -= delta
			if _casquillo_vida[i] <= 0.0:
				_casquillos[i].freeze = true
				_casquillos[i].visible = false
	if _recargando > 0.0:
		_recargando -= delta
		if _recargando <= 0.0:
			_recargando = 0.0
			balas = CARGADOR


# El arma (1/2 la cambian) y cuantas curaciones traes (Q, Player._curarse)
func _texto_arma() -> String:
	var inventario := get_node_or_null("/root/Inventory")
	var curar := "\nQ curar (%d)" % (inventario.curaciones() if inventario else 0)
	if activa:
		return ("Pistola  recargando..." if _recargando > 0.0 else "Pistola  %d/%d" % [balas, CARGADOR]) + curar
	var arma: InventoryItemData = inventario.arma() if inventario else null
	return (arma.item_name if arma else "Puño") + curar


# --- Fogonazo y casquillos ---

# Chispas amarillas de la boca, una rafaga por tiro
func _armar_fogonazo() -> void:
	_fogonazo = CPUParticles3D.new()
	_fogonazo.emitting = false
	_fogonazo.one_shot = true
	_fogonazo.amount = FOGONAZO_CHISPAS
	_fogonazo.lifetime = FOGONAZO_DURA
	_fogonazo.explosiveness = 1.0
	_fogonazo.local_coords = false
	_fogonazo.direction = Vector3.FORWARD
	_fogonazo.spread = 25.0
	_fogonazo.gravity = Vector3.ZERO
	_fogonazo.initial_velocity_min = 3.0
	_fogonazo.initial_velocity_max = 6.0
	_fogonazo.scale_amount_min = 0.5
	_fogonazo.scale_amount_max = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * FOGONAZO_TAMANO
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = TRAZO_COLOR
	material.disable_fog = true
	quad.material = material
	_fogonazo.mesh = quad
	_fogonazo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fogonazo.top_level = true
	add_child(_fogonazo)


# Un monton fijo de casquillos que se reusan: nada de new/queue_free por tiro
func _armar_casquillos() -> void:
	var caja := BoxMesh.new()
	caja.size = CASQUILLO_TAMANO
	var material := StandardMaterial3D.new()
	material.albedo_color = CASQUILLO_COLOR
	material.metallic = 0.6
	material.roughness = 0.4
	caja.material = material
	var forma := BoxShape3D.new()
	forma.size = CASQUILLO_TAMANO * 1.5  # tan chico se colaba por el suelo
	for i in CASQUILLOS:
		var cuerpo := RigidBody3D.new()
		cuerpo.collision_layer = 0
		cuerpo.collision_mask = 1
		cuerpo.mass = 0.01
		cuerpo.continuous_cd = true
		cuerpo.freeze = true
		cuerpo.visible = false
		cuerpo.top_level = true
		var colision := CollisionShape3D.new()
		colision.shape = forma
		cuerpo.add_child(colision)
		var malla := MeshInstance3D.new()
		malla.mesh = caja
		malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cuerpo.add_child(malla)
		add_child(cuerpo)
		_casquillos.append(cuerpo)
		_casquillo_vida.append(0.0)


# Sale por la derecha y para arriba, girando
func _soltar_casquillo(hacia: Vector3, derecha: Vector3) -> void:
	var i := _casquillo_sig
	_casquillo_sig = (_casquillo_sig + 1) % CASQUILLOS
	var cuerpo := _casquillos[i]
	cuerpo.freeze = true
	cuerpo.global_transform = Transform3D(Basis.looking_at(hacia), jugador.canon() - hacia * 0.08)
	cuerpo.freeze = false
	cuerpo.visible = true
	cuerpo.linear_velocity = jugador.velocity + derecha * randf_range(1.5, 2.5) + Vector3.UP * randf_range(1.2, 2.0)
	cuerpo.angular_velocity = Vector3(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
	_casquillo_vida[i] = CASQUILLO_DURA


# --- La mira y el arma en pantalla ---

func _armar_pantalla() -> void:
	_capa = CanvasLayer.new()
	_capa.layer = 4
	add_child(_capa)
	_mira = Control.new()
	_mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mira.set_anchors_preset(Control.PRESET_CENTER)
	_mira.draw.connect(func() -> void:
		for lado: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_mira.draw_line(lado * 3.0, lado * 8.0, Color.BLACK, 3.0)
			_mira.draw_line(lado * 3.0, lado * 8.0, MIRA_COLOR, 1.0))
	_capa.add_child(_mira)
	_texto = Label.new()
	_texto.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_texto.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_texto.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_texto.offset_right = -10.0
	_texto.offset_bottom = -6.0
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_texto.add_theme_font_size_override("font_size", 14)
	_texto.add_theme_color_override("font_color", TEXTO_COLOR)
	_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_texto.add_theme_constant_override("outline_size", 4)
	_capa.add_child(_texto)
