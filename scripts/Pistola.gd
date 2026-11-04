extends Node

# La pistola del jugador (Player.gd la crea como hija). R (accion cambiar_arma) cambia entre
# ella y el arma de golpe; con ella el clic (attack) dispara hacia la mira, al centro de la
# pantalla: la opcion A de docs/especificaciones.md 1.4, que JJ quiso probar (la votacion
# sigue abierta). Si el centro no da en un zombi, se lo lleva el mas cercano a la mira
# dentro de AYUDA grados que se vea. Las bardas y barricadas (capa 1) tapan los tiros.
# Al zombi le pega por el mismo camino que el machete (Zombie.recibir_golpe), sin la
# congelada: a tiro rapido trababa. Balas sin fin, pero con cargador y recarga sola.
# Como Player.gd, la cargan scripts de tools/ antes de los autoloads: nada de nombrarlos.

const DANO := 15              # dos tiros a un zombi de 30
const CADENCIA := 0.22        # s entre tiros
const CARGADOR := 12
const RECARGA := 1.5          # s, sola al vaciarse
const ALCANCE := 60.0         # m
const AYUDA := 4.0            # grados alrededor de la mira
const FUERZA := 0.5           # del salpicado y el impacto (el machete es 1)
const PECHO := 1.0            # m sobre los pies donde se apunta a un zombi
const SACUDE_TIRO := 0.025    # m de la camara al disparar
const SACUDE_PEGA := 0.04     # m si le dio a uno
const SACUDE_DURA := 0.08
const TRAZO_DURA := 50        # ms del rayo amarillo
const TRAZO_COLOR := Color(1.0, 0.85, 0.35)
const TRAZO_GRUESO := 0.025
const DESTELLO_ENERGIA := 4.0
const DESTELLO_RANGO := 6.0
const CAPA_ZOMBIS := 2
const MIRA_COLOR := Color(1.0, 0.95, 0.8, 0.9)
const TEXTO_COLOR := Color(1.0, 0.85, 0.1)

var jugador: Player
var activa := false
var balas := CARGADOR

var _espera := 0.0
var _recargando := 0.0
var _trazo: MeshInstance3D
var _trazo_hasta := 0
var _destello: OmniLight3D
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
	material.disable_fog = true
	caja.material = material
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
	balas -= 1
	var centro := get_viewport().get_visible_rect().size / 2.0
	var origen := camara.project_ray_origin(centro)
	var hacia := camara.project_ray_normal(centro)
	var espacio := jugador.get_world_3d().direct_space_state
	var excluir: Array[RID] = [jugador.get_rid()]
	var rayo := PhysicsRayQueryParameters3D.create(origen, origen + hacia * ALCANCE, 1 | CAPA_ZOMBIS, excluir)
	var pego := espacio.intersect_ray(rayo)
	var punto: Vector3 = pego.position if pego else origen + hacia * ALCANCE
	var blanco: Zombie = pego.collider as Zombie if pego else null
	if blanco == null:
		blanco = _ayuda(espacio, excluir, origen, hacia)
		if blanco:
			punto = blanco.global_position + Vector3.UP * PECHO
	var dano := maxi(roundi(DANO * jugador._factor_dano), 1)
	var sacude := SACUDE_TIRO
	if blanco and blanco.recibir_golpe(dano, jugador.global_position, FUERZA) != 0:
		sacude = SACUDE_PEGA
		Sonidos.tocar(self, "whack", -10.0)
	Sonidos.tocar(self, "disparo", -4.0)
	jugador._sacude_fuerza = sacude
	jugador._sacude_hasta = Time.get_ticks_msec() + int(SACUDE_DURA * 1000.0)
	jugador.pose_tiro()
	_dibujar_tiro(punto)
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


func _recargar() -> void:
	if _recargando > 0.0:
		return
	_recargando = RECARGA
	Sonidos.tocar(self, "recarga", -6.0)


# De la boca de la pistola a donde pego
func _dibujar_tiro(punto: Vector3) -> void:
	var canon := jugador.canon()
	var largo := canon.distance_to(punto)
	if largo > 0.05:
		_trazo.global_transform = Transform3D(Basis.looking_at(punto - canon).scaled_local(Vector3(1.0, 1.0, largo)), (canon + punto) / 2.0)
		_trazo.visible = true
	_destello.global_position = canon
	_destello.visible = true
	_trazo_hasta = Time.get_ticks_msec() + TRAZO_DURA


func _process(delta: float) -> void:
	if _trazo_hasta > 0 and Time.get_ticks_msec() >= _trazo_hasta:
		_trazo_hasta = 0
		_trazo.visible = false
		_destello.visible = false
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


func _texto_arma() -> String:
	if activa:
		return "Pistola  recargando..." if _recargando > 0.0 else "Pistola  %d/%d" % [balas, CARGADOR]
	var inventario := get_node_or_null("/root/Inventory")
	var arma: InventoryItemData = inventario.arma() if inventario else null
	return arma.item_name if arma else "Puño"


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
