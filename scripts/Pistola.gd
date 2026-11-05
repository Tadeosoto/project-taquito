extends Node

# La pistola del jugador (Player.gd la crea como hija). 1/2 (arma_1/arma_2) o RB (cambiar_arma)
# cambian entre ella y el arma de golpe, R (recargar) recarga; con ella el clic (attack) dispara hacia la mira, al centro de la
# pantalla: la opcion A de docs/especificaciones.md 1.4, que JJ quiso probar (la votacion
# sigue abierta). Si el centro no da en un zombi, se lo lleva el mas cercano a la mira
# dentro de AYUDA grados que se vea. Las bardas y barricadas (capa 1) tapan los tiros.
# Al zombi le pega por el mismo camino que el machete (Zombie.recibir_golpe), sin la
# congelada (a tiro rapido trababa), sin empujon y sin aturdir: la pistola debilita de lejos
# y el que mata es el machete. Balas sin fin, pero con cargador y recarga sola.
# Al tiro: fogonazo, dispersion (mas con los nervios: la intensidad del Director), una bala de
# pixelfx que vuela de la boca a donde pego, chispas si pego en pared, casquillo de pixelfx,
# empujoncito atras y uno de DISPAROS sonidos con tono al azar. En la cabeza (CABEZA_DESDE de la capsula para arriba) pega CABEZA_MULT veces.
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
const TRAZO_COLOR := Color(1.0, 0.85, 0.35)
# La bala que se ve (pixelfx bala_trazo, shaders/sprite_eje.gdshader): el tiro ya pego al
# disparar (rayo); esto solo la dibuja volando hasta ahi
const BALAS_TRAZO := 6        # se reusan, la mas vieja primero
const BALA_VELOCIDAD := 150.0 # m/s
const BALA_LARGO := 1.2       # m de la estela
const BALA_LARGO_PX := 120.0  # px de la estela en la hoja
const BALA_IMPACTO_ALTO := 0.56 # m: la hoja bala_impacto pega 24 px arriba de su piso (a escala 0.5)
const DESTELLO_ENERGIA := 4.0
const DESTELLO_RANGO := 6.0
const CAPA_ZOMBIS := 2
const DISPERSION := 0.012     # rad de desvio al azar por tiro
const APUNTA_DISPERSION := 0.004 # apuntando
const CABEZA_DESDE := 1.4     # m sobre los pies (por el tamano del zombi; la capsula mide 1.8)
const CABEZA_MULT := 3
const TONO_MIN := 0.85        # pitch_scale del disparo, al azar
const TONO_MAX := 1.15
const DISPAROS := 4           # disparo_1..disparo_4 (Sonidos), uno al azar
# Nervios: la intensidad del Director (0-1) abre la mira y el desvio
const NERVIOS_SIGUE := 2.0    # por segundo que la mira alcanza la intensidad
const NERVIOS_DISPERSION := 1.5 # con intensidad 1, el desvio es x2.5
const NERVIOS_MIRA := 6.0     # px mas de hueco en la mira con intensidad 1
const MIRA_HUECO := 3.0       # px del centro a cada raya
const MIRA_PATADA := 0.6      # grados que sube la camara por tiro (Player.patear_mira)
const APUNTA_PATADA := 0.35
const MIRA_FLORECE := 4.0     # px que se abre la mira por tiro
const MIRA_CIERRA := 30.0     # px/s que se vuelve a cerrar
const MIRA_RAYA := 5.0
const FOGONAZO_CHISPAS := 6
const FOGONAZO_DURA := 0.06   # s
const FOGONAZO_TAMANO := 0.08 # m
const MIRA_COLOR := Color(1.0, 0.95, 0.8, 0.9)
const TEXTO_COLOR := Color(1.0, 0.85, 0.1)

var jugador: Player
var activa := false
var balas := CARGADOR
var tiros := 0      # para medir el balance (MonitorDefensa)
var aciertos := 0

var _espera := 0.0
var _recargando := 0.0
var _destello: OmniLight3D
var _destello_hasta := 0
var _fogonazo: CPUParticles3D
var _balas: Array[MeshInstance3D] = []
var _bala_desde: Array[Vector3] = []
var _bala_hasta: Array[Vector3] = []
var _bala_va: Array[float] = []     # m andados; < 0 = guardada
var _bala_sig := 0
var _nervios := 0.0
var _hueco := MIRA_HUECO
var _floracion := 0.0
var _mira: Control
var _texto: Label
var _capa: CanvasLayer


func _ready() -> void:
	_destello = OmniLight3D.new()
	_destello.light_color = TRAZO_COLOR
	_destello.light_energy = DESTELLO_ENERGIA
	_destello.omni_range = DESTELLO_RANGO
	_destello.top_level = true
	_destello.visible = false
	add_child(_destello)
	_armar_fogonazo()
	_armar_balas()
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
	var desvio := (APUNTA_DISPERSION if jugador._apuntando else DISPERSION) * (1.0 + NERVIOS_DISPERSION * _nervios)
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
	Sonidos.tocar(self, "disparo_%d" % randi_range(1, DISPAROS), -4.0, randf_range(TONO_MIN, TONO_MAX))
	jugador._sacude_fuerza = sacude
	jugador._sacude_hasta = Time.get_ticks_msec() + int(SACUDE_DURA * 1000.0)
	jugador.pose_tiro()
	jugador.empujar_tiro(hacia)
	jugador.patear_mira(APUNTA_PATADA if jugador._apuntando else MIRA_PATADA)
	_floracion += MIRA_FLORECE
	_dibujar_tiro(punto)
	var efectos := get_tree().get_first_node_in_group("efectos_pixel") as EfectosPixel
	if efectos:
		# Pared o suelo: chispas (al zombi ya lo salpica su agua)
		if pego and blanco == null:
			efectos.lanzar("bala", punto - Vector3.UP * BALA_IMPACTO_ALTO, hacia)
		# El casquillo cae a los pies, bajo la boca, hacia la derecha de la camara
		var canon := jugador.canon()
		efectos.lanzar("casquillo", Vector3(canon.x, jugador.global_position.y, canon.z), -camara.global_basis.x)
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
	if canon.distance_to(punto) > 0.05 and not _balas.is_empty():
		var i := _bala_sig
		_bala_sig = (_bala_sig + 1) % _balas.size()
		_bala_desde[i] = canon
		_bala_hasta[i] = punto
		_bala_va[i] = 0.0
		_balas[i].set_instance_shader_parameter("eje", (punto - canon).normalized())
		_balas[i].set_instance_shader_parameter("largo", 0.01)
		_balas[i].global_position = canon
		_balas[i].visible = true
	_destello.global_position = canon
	_destello.visible = true
	_destello_hasta = Time.get_ticks_msec() + TRAZO_DURA
	var hacia := punto - canon
	if hacia.length_squared() > 0.0025:
		_fogonazo.global_transform = Transform3D(Basis.looking_at(hacia), canon)
	else:
		_fogonazo.global_position = canon
	_fogonazo.restart()


func _process(delta: float) -> void:
	if _destello_hasta > 0 and Time.get_ticks_msec() >= _destello_hasta:
		_destello_hasta = 0
		_destello.visible = false
	_volar_balas(delta)
	_sentir_nervios(delta)
	var libre := jugador.is_physics_processing() and jugador.can_process()
	_mira.visible = activa and libre
	_texto.visible = libre
	_texto.text = _texto_arma()


func _physics_process(delta: float) -> void:
	_espera = maxf(_espera - delta, 0.0)
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


# --- Fogonazo, balas y nervios ---

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


# Unos cuadros reusados que dibujan la bala (pixelfx bala_trazo) a lo largo de su linea
func _armar_balas() -> void:
	var material := EfectosPixel.material_eje("bala_trazo", BALA_LARGO_PX)
	if material == null:
		return
	for i in BALAS_TRAZO:
		var bala := MeshInstance3D.new()
		bala.mesh = EfectosPixel.malla_quad()
		bala.material_override = material
		bala.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# El shader la estira hasta un par de metros hacia atras
		bala.custom_aabb = AABB(Vector3(-3.0, -3.0, -3.0), Vector3(6.0, 6.0, 6.0))
		bala.top_level = true
		bala.visible = false
		bala.set_instance_shader_parameter("fase", randf())
		add_child(bala)
		_balas.append(bala)
		_bala_desde.append(Vector3.ZERO)
		_bala_hasta.append(Vector3.ZERO)
		_bala_va.append(-1.0)


# La punta avanza a BALA_VELOCIDAD hasta donde pego; la cola la alcanza y se guarda
func _volar_balas(delta: float) -> void:
	for i in _balas.size():
		if _bala_va[i] < 0.0:
			continue
		var total := _bala_desde[i].distance_to(_bala_hasta[i])
		_bala_va[i] += BALA_VELOCIDAD * delta
		var punta := minf(_bala_va[i], total)
		var cola := maxf(_bala_va[i] - BALA_LARGO, 0.0)
		if cola >= total:
			_bala_va[i] = -1.0
			_balas[i].visible = false
			continue
		var dir := (_bala_hasta[i] - _bala_desde[i]) / total
		_balas[i].global_position = _bala_desde[i] + dir * punta
		_balas[i].set_instance_shader_parameter("largo", maxf(punta - cola, 0.01))


# La mira se abre con la intensidad del Director (Zombis.director), que sube con el dano y
# las muertes cerca; sin Zombis en la escena, nada
func _sentir_nervios(delta: float) -> void:
	var mando := get_tree().get_first_node_in_group("zombis_mando") as Zombis
	var meta: float = clampf(mando.director.intensidad, 0.0, 1.0) if mando and mando.director else 0.0
	_nervios = move_toward(_nervios, meta, NERVIOS_SIGUE * delta)
	_floracion = move_toward(_floracion, 0.0, MIRA_CIERRA * delta)
	var hueco := MIRA_HUECO + NERVIOS_MIRA * _nervios + _floracion
	if roundi(hueco) != roundi(_hueco):
		_hueco = hueco
		_mira.queue_redraw()


# --- La mira y el arma en pantalla ---

func _armar_pantalla() -> void:
	_capa = CanvasLayer.new()
	_capa.layer = 4
	add_child(_capa)
	_mira = Control.new()
	_mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mira.set_anchors_preset(Control.PRESET_CENTER)
	_mira.draw.connect(func() -> void:
		var hueco := float(roundi(_hueco))
		for lado: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_mira.draw_line(lado * hueco, lado * (hueco + MIRA_RAYA), Color.BLACK, 3.0)
			_mira.draw_line(lado * hueco, lado * (hueco + MIRA_RAYA), MIRA_COLOR, 1.0))
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
