extends CanvasLayer

# Lo que se siente del peligro: la barra de vida arriba a la izquierda (tambien se ve en el
# inventario), flash rojo al recibir un golpe, orillas rojas con poca vida, el aviso del
# atardecer y desmayarse. Al llegar a 0 de vida: tus objetos se quedan en una bolsa donde caiste
# (BolsaMuerte.gd; el dinero y la mochila puesta no), pantalla negra y reapareces en
# `punto_regreso` con algo de vida (el refugio, lo pone Partida.gd). Propuesta de
# docs/especificaciones.md 1.5.

const VIDA_AL_DESPERTAR := 50
const FUNDIDO := 1.0
const NEGRO_DURA := 2.0
const POCA_VIDA := 0.35   # fraccion de la vida con la que se pintan las orillas
const LIMPIO_AL_REGRESAR := 20.0   # m alrededor de donde reapareces sin zombis; los demas siguen
const TEXTO_AVISO := "Ya va a oscurecer..."
const TEXTO_NOCHE := "Ya salieron."
const TEXTO_TURBA := "¡Ahí vienen!"
const TEXTO_DIA := "Amaneció."
const TEXTO_DESMAYO := "Te desmayaste..."
const TEXTO_SEGUNDO_AIRE := "¡Segundo aire!"
const BARRA_LUGAR := Vector2(10.0, 10.0)
const BARRA_TAMANO := Vector2(110.0, 6.0)
const BARRA_COLOR := Color(0.85, 0.12, 0.08)
# Puro blanco y negro en pantalla completa: antes de publicar el juego esto tiene que ser una
# opcion, porque los destellos le pueden hacer dano a gente con epilepsia fotosensible
const IMPACTO_ACTIVO := true
const IMPACTO_CUADRO_MS := 17
const IMPACTO_UMBRAL_DIA := 0.36
const IMPACTO_UMBRAL_NOCHE := 0.22
const IMPACTO_SHADER := preload("res://shaders/impacto.gdshader")
const CALENTAR_CUADROS := 3
# Efectos de pixel (EfectosPixel): la tele que se apaga al desmayarte (la hoja queda en negro
# entre DESMAYO_APAGA y su final), rayos de luz al amanecer y gotas de sangre con poca vida
const DESMAYO_APAGA := 1.0
const DESMAYO_DURA := 2.0
const RAYOS_DURA := 30.0
const RAYOS_ALFA := 0.55
const RAYOS_FUNDIDO := 6.0
const RAYOS_RECORTE := 22.0   # px de abajo de la hoja: su piso iluminado
const GOTEO_CADA := Vector2(0.6, 1.2)
const GOTEO_GOTAS := Vector2i(1, 3)
const GOTEO_VELOCIDAD := Vector2(0.2, 0.9)
const GOTEO_ALTO := 0.9   # m sobre los pies: de las manos y el pecho

@export var jugador_path: NodePath
@export var ciclo_path: NodePath
@export var zombis_path: NodePath

var _jugador: Player
var _zombis: Zombis
var _salud: Node
var punto_regreso: Transform3D
var _bolsa: Node3D
var _ciclo: Ciclo
var _impacto: ColorRect
var _impacto_material: ShaderMaterial
var _impacto_desde := 0
var _vida_antes := 0
var _desmayado := false
var _flash: ColorRect
var _orillas: ColorRect
var _negro: ColorRect
var _barra: ColorRect
var _aviso: Label
var _centro: Label
var _voz: AudioStreamPlayer
var _aviso_tween: Tween
var _goteo := 0.0


func _ready() -> void:
	layer = 8
	_jugador = get_node(jugador_path) as Player
	_zombis = get_node(zombis_path) as Zombis
	punto_regreso = _jugador.global_transform
	_salud = get_node("/root/Salud")
	_vida_antes = _salud.vida
	_salud.cambio.connect(_cambio_vida)
	var ciclo := get_node(ciclo_path) as Ciclo
	_ciclo = ciclo
	ciclo.aviso_atardecer.connect(func() -> void:
		_avisar(TEXTO_AVISO)
		_sonar("campana"))
	_zombis.turba_cerca.connect(func() -> void:
		_avisar(TEXTO_TURBA)
		_sonar("gemido"))
	ciclo.anochecio.connect(func() -> void: _avisar(TEXTO_NOCHE))
	ciclo.amanecio.connect(func() -> void:
		_avisar(TEXTO_DIA)
		var efectos := _efectos()
		if efectos:
			efectos.pantalla("amanecer_rayos", 0.0, RAYOS_DURA, true, RAYOS_ALFA, RAYOS_FUNDIDO, RAYOS_RECORTE))
	_flash = _pantalla(Color(0.7, 0.0, 0.0, 0.0))
	_orillas = _pantalla(Color(1, 1, 1, 0))
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nuniform float fuerza = 0.0;\nvoid fragment() {\n\tfloat d = distance(UV, vec2(0.5)) * 1.41;\n\tCOLOR = vec4(0.55, 0.0, 0.0, smoothstep(0.55, 1.0, d) * fuerza);\n}\n"
	material.shader = shader
	_orillas.material = material
	_armar_barra()
	_negro = _pantalla(Color(0, 0, 0, 0))
	_armar_impacto()
	_aviso = _label(18, Color(1.0, 0.85, 0.1))
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso.offset_top = 40.0
	_aviso.modulate.a = 0.0
	add_child(_aviso)
	_centro = _label(24, Color.WHITE)
	_centro.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_centro.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_centro.grow_vertical = Control.GROW_DIRECTION_BOTH
	_centro.modulate.a = 0.0
	add_child(_centro)
	_voz = AudioStreamPlayer.new()
	add_child(_voz)


# Dos cuadros de un juego a 60: en reloj real, porque a 200 FPS dos cuadros de verdad no
# se alcanzarian a ver. El inventario pausa el juego, por eso esta capa corre siempre.
func _armar_impacto() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_impacto_material = ShaderMaterial.new()
	_impacto_material.shader = IMPACTO_SHADER
	_impacto = ColorRect.new()
	_impacto.material = _impacto_material
	_impacto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Un pixel unos cuadros, para que el primer golpe no trabe compilando
	_impacto.position = Vector2.ZERO
	_impacto.size = Vector2.ONE
	add_child(_impacto)
	_jugador.golpeado.connect(_golpe_recibido)
	for i in CALENTAR_CUADROS:
		await get_tree().process_frame
	if not is_inside_tree() or _impacto_desde > 0:
		return
	_impacto.visible = false


func _golpe_recibido() -> void:
	if not IMPACTO_ACTIVO:
		return
	_impacto.size = get_viewport().get_visible_rect().size
	_impacto_material.set_shader_parameter("umbral", lerpf(IMPACTO_UMBRAL_DIA, IMPACTO_UMBRAL_NOCHE, _ciclo.valor()))
	_impacto_material.set_shader_parameter("invertido", false)
	_impacto.visible = true
	_impacto_desde = Time.get_ticks_msec()


func _revisar_impacto() -> void:
	if _impacto_desde == 0:
		return
	var pasaron := Time.get_ticks_msec() - _impacto_desde
	if pasaron >= IMPACTO_CUADRO_MS * 2:
		_impacto_desde = 0
		_impacto.visible = false
	elif pasaron >= IMPACTO_CUADRO_MS:
		_impacto_material.set_shader_parameter("invertido", true)


func _process(delta: float) -> void:
	_revisar_impacto()
	var fraccion: float = float(_salud.vida) / _salud.vida_max
	_barra.scale.x = clampf(fraccion, 0.0, 1.0)
	var fuerza := 0.0
	if fraccion < POCA_VIDA and not _desmayado:
		var latido := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.005)
		fuerza = (1.0 - fraccion / POCA_VIDA) * latido
		_gotear(delta)
	(_orillas.material as ShaderMaterial).set_shader_parameter("fuerza", fuerza)


# Con poca vida se te van cayendo gotas de sangre (el Liquido de siempre). Esta capa corre
# aun en pausa: ahi no, que el liquido esta detenido
func _gotear(delta: float) -> void:
	if get_tree().paused or not EfectosPixel.extras:
		return
	_goteo -= delta
	if _goteo > 0.0:
		return
	_goteo = randf_range(GOTEO_CADA.x, GOTEO_CADA.y)
	var liquido := get_tree().get_first_node_in_group("liquido")
	if liquido:
		var pies := _jugador.global_position + Vector3.DOWN
		liquido.salpicar(pies + Vector3.UP * GOTEO_ALTO, 0.2, pies.y, Vector3.DOWN,
			randi_range(GOTEO_GOTAS.x, GOTEO_GOTAS.y), Player.COLOR_SANGRE, GOTEO_VELOCIDAD, 0.6)


# Los efectos de pixel, si estan prendidos (F9 en el safehouse los apaga)
func _efectos() -> Node:
	return get_tree().get_first_node_in_group("efectos_pixel") if EfectosPixel.extras else null


func _cambio_vida() -> void:
	var vida: int = _salud.vida
	if vida < _vida_antes:
		# Menos fuerte que antes: si no, no se ve la sangre del golpe
		_flash.color.a = 0.25
		create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
	_vida_antes = vida
	if vida <= 0 and not _desmayado:
		if _segundo_aire():
			return
		_desmayarse()


# Segundo aire (Tazos.gd): una vez por noche te levantas en vez de desmayarte
func _segundo_aire() -> bool:
	var tazos := get_node_or_null("/root/Tazos")
	if tazos == null or not tazos.tiene("segundo_aire") or tazos.segundo_aire_usado:
		return false
	tazos.segundo_aire_usado = true
	var vida := maxi(roundi(_salud.vida_max * Habilidades.SEGUNDO_AIRE_VIDA), 1)
	_vida_antes = vida
	_salud.vida = vida
	_flash.color = Color(1.0, 0.9, 0.5, 0.6)
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.8)
	tween.tween_callback(func() -> void: _flash.color = Color(0.7, 0.0, 0.0, 0.0))
	_avisar(TEXTO_SEGUNDO_AIRE)
	_sonar("destello")
	return true


func _desmayarse() -> void:
	_desmayado = true
	_jugador.detener()
	_jugador.caer()
	_soltar_bolsa()
	# La imagen se aprieta en una raya y se apaga como tele vieja; sin efectos, se funde a negro
	var efectos := _efectos()
	if efectos:
		await efectos.pantalla("desmayo", 0.0, DESMAYO_APAGA)
		_negro.color.a = 1.0
	else:
		var tween := create_tween()
		tween.tween_property(_negro, "color:a", 1.0, FUNDIDO)
		await tween.finished
	_centro.text = TEXTO_DESMAYO
	_centro.modulate.a = 1.0
	_zombis.limpiar_cerca(punto_regreso.origin, LIMPIO_AL_REGRESAR)
	_jugador.global_transform = punto_regreso
	_jugador.velocity = Vector3.ZERO
	_salud.vida = VIDA_AL_DESPERTAR
	await get_tree().create_timer(NEGRO_DURA).timeout
	_jugador.reanudar()
	_centro.modulate.a = 0.0
	if efectos and is_instance_valid(efectos):
		# La segunda mitad de la hoja arranca en negro: se quita el negro de abajo y se prende
		efectos.pantalla("desmayo", DESMAYO_APAGA, DESMAYO_DURA)
		_negro.color.a = 0.0
		await get_tree().create_timer(DESMAYO_DURA - DESMAYO_APAGA).timeout
	else:
		var tween := create_tween()
		tween.tween_property(_negro, "color:a", 0.0, FUNDIDO)
		await tween.finished
	_desmayado = false


# Sin nada encima no hay bolsa nueva, y la que dejaste sigue ahi
func _soltar_bolsa() -> void:
	var inventario := get_node("/root/Inventory")
	if inventario.items.is_empty():
		return
	if is_instance_valid(_bolsa):
		_bolsa.queue_free()
	_bolsa = load("res://scripts/map/BolsaMuerte.gd").new()
	_bolsa.items = inventario.items.duplicate()
	inventario.items.clear()
	inventario.inventory_changed.emit()
	get_parent().add_child(_bolsa)
	# El origen del jugador esta a 1 m del piso
	_bolsa.global_position = _jugador.global_position + Vector3.DOWN


func avisar(texto: String) -> void:
	_avisar(texto)


func _avisar(texto: String) -> void:
	_aviso.text = texto
	if _aviso_tween and _aviso_tween.is_valid():
		_aviso_tween.kill()
	_aviso.modulate.a = 1.0
	_aviso_tween = create_tween()
	_aviso_tween.tween_interval(3.0)
	_aviso_tween.tween_property(_aviso, "modulate:a", 0.0, 1.0)


func _sonar(nombre: String) -> void:
	_voz.stream = Sonidos.sonido(nombre)
	_voz.play()


func _pantalla(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


# Abajo del negro del desmayo, para que se apague con el
func _armar_barra() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.6)
	fondo.position = BARRA_LUGAR - Vector2.ONE
	fondo.size = BARRA_TAMANO + Vector2.ONE * 2.0
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)
	_barra = ColorRect.new()
	_barra.color = BARRA_COLOR
	_barra.position = BARRA_LUGAR
	_barra.size = BARRA_TAMANO
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_barra)
	var nombre := _label(10, BARRA_COLOR)
	nombre.text = "vida"
	nombre.position = BARRA_LUGAR + Vector2(BARRA_TAMANO.x + 8.0, -6.0)
	add_child(nombre)


func _label(tamano: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	return label
