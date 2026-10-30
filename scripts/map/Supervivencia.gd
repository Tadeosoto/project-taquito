extends CanvasLayer

# Lo que se siente del peligro, sin barra de vida (la vida se ve en el inventario): flash
# rojo al recibir un golpe, orillas rojas con poca vida, el aviso del atardecer y
# desmayarse. Al llegar a 0 de vida: pantalla negra y reapareces donde empezaste con algo
# de vida, sin perder nada (docs/especificaciones.md 1.5 sigue por votar).

const VIDA_AL_DESPERTAR := 50
const FUNDIDO := 1.0
const NEGRO_DURA := 2.0
const POCA_VIDA := 0.35   # fraccion de la vida con la que se pintan las orillas
const TEXTO_AVISO := "Ya va a oscurecer..."
const TEXTO_NOCHE := "Ya salieron."
const TEXTO_DIA := "Amaneció."
const TEXTO_DESMAYO := "Te desmayaste..."

@export var jugador_path: NodePath
@export var ciclo_path: NodePath
@export var zombis_path: NodePath

var _jugador: Player
var _zombis: Zombis
var _salud: Node
var _inicio: Transform3D
var _vida_antes := 0
var _desmayado := false
var _flash: ColorRect
var _orillas: ColorRect
var _negro: ColorRect
var _aviso: Label
var _centro: Label
var _voz: AudioStreamPlayer
var _aviso_tween: Tween


func _ready() -> void:
	layer = 8
	_jugador = get_node(jugador_path) as Player
	_zombis = get_node(zombis_path) as Zombis
	_inicio = _jugador.global_transform
	_salud = get_node("/root/Salud")
	_vida_antes = _salud.vida
	_salud.cambio.connect(_cambio_vida)
	var ciclo := get_node(ciclo_path) as Ciclo
	ciclo.aviso_atardecer.connect(func() -> void:
		_avisar(TEXTO_AVISO)
		_sonar("campana"))
	ciclo.anochecio.connect(func() -> void: _avisar(TEXTO_NOCHE))
	ciclo.amanecio.connect(func() -> void: _avisar(TEXTO_DIA))
	_flash = _pantalla(Color(0.7, 0.0, 0.0, 0.0))
	_orillas = _pantalla(Color(1, 1, 1, 0))
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nuniform float fuerza = 0.0;\nvoid fragment() {\n\tfloat d = distance(UV, vec2(0.5)) * 1.41;\n\tCOLOR = vec4(0.55, 0.0, 0.0, smoothstep(0.55, 1.0, d) * fuerza);\n}\n"
	material.shader = shader
	_orillas.material = material
	_negro = _pantalla(Color(0, 0, 0, 0))
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


func _process(_delta: float) -> void:
	var fraccion: float = float(_salud.vida) / _salud.vida_max
	var fuerza := 0.0
	if fraccion < POCA_VIDA and not _desmayado:
		var latido := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.005)
		fuerza = (1.0 - fraccion / POCA_VIDA) * latido
	(_orillas.material as ShaderMaterial).set_shader_parameter("fuerza", fuerza)


func _cambio_vida() -> void:
	var vida: int = _salud.vida
	if vida < _vida_antes:
		_flash.color.a = 0.45
		create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
	_vida_antes = vida
	if vida <= 0 and not _desmayado:
		_desmayarse()


func _desmayarse() -> void:
	_desmayado = true
	_jugador.detener()
	_jugador.caer()
	var tween := create_tween()
	tween.tween_property(_negro, "color:a", 1.0, FUNDIDO)
	await tween.finished
	_centro.text = TEXTO_DESMAYO
	_centro.modulate.a = 1.0
	_zombis.limpiar()
	_jugador.global_transform = _inicio
	_jugador.velocity = Vector3.ZERO
	_salud.vida = VIDA_AL_DESPERTAR
	await get_tree().create_timer(NEGRO_DURA).timeout
	_jugador.reanudar()
	_centro.modulate.a = 0.0
	tween = create_tween()
	tween.tween_property(_negro, "color:a", 0.0, FUNDIDO)
	await tween.finished
	_desmayado = false


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


func _label(tamano: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	return label
