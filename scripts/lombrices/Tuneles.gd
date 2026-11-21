extends Node3D
## Las cañerías del arroyo (scenes/tuneles.tscn, P6, JJ 2026-11-21): el previo antes de la Madre del
## Carcamo. Se entra siempre por la flecha del tubo del arroyo en map_test (EntradaJefe "tuneles"); al
## fondo, la puerta de GelA lleva a la pelea (PasoJefe.seguir a lombrices.tscn) y atras, la flecha del
## tubo te saca al arroyo. Las crias de aqui solo mueren con sal o fuego (EnjambreLombrices
## `solo_sal_y_fuego`): el machete, las balas y las explosiones solo las avientan. La sal la venden al
## avanzar en la historia, asi que sin ella las crias te alcanzan, se te pegan y te matan.
## Sin sal ni molotov de regalo ni nada infinito (eso es de la arena de prueba).
##
## Desmayarte desde el juego te saca al mapa (PasoJefe.volver, sin premio); como prueba suelta, vuelve
## a empezar. Correr solo: godot --path . scenes/tuneles.tscn   (-- --inmortal: vida infinita)

const LOMBRICES := "res://scenes/lombrices.tscn"
const AVISO_REBOTE := "El machete no les hace nada.\nSolo la sal o el fuego las matan."
const VIDA_ANCHO := 120.0
const CONTROLES := "3: sal (otra vez 3: molotov) · Alt + dirección: rodar (te quita las pegadas) · Q curar"

var _nivel: TunelesNivel
var _enjambre: EnjambreLombrices
var _jugador: Node3D
var _salud: Node
var _letrero: Label
var _aviso: Label
var _negro: ColorRect
var _vida_relleno: ColorRect
var _vida_texto: Label
var _saliendo := false
var _reiniciando := false
var _avisado := false
var inmortal := false


func _ready() -> void:
	# Lo que en el mapa crea Zombis y Partida: las hojas de pixel, las gotas y los sonidos del cuerpo
	if get_tree().get_first_node_in_group("liquido") == null:
		add_child(Liquido.new())
	if get_tree().get_first_node_in_group("efectos_pixel") == null:
		add_child(EfectosPixel.new())
	var cuerpo := SonidosJugador.new()
	cuerpo.name = "SonidosJugador"
	add_child(cuerpo)
	_nivel = TunelesNivel.new()
	add_child(_nivel)
	_jugador = $Player
	_jugador.global_position = TunelesNivel.ENTRADA - Vector3(0.0, 0.0, 1.5)
	_jugador.aplicar_personaje()
	_salud = get_node_or_null("/root/Salud")
	inmortal = "--inmortal" in OS.get_cmdline_user_args()
	# Las crias nacen en las bocas de tubo de los muros, con el campo de todo el tunel
	_enjambre = $EnjambreLombrices
	_enjambre.nidos = _nivel.nidos
	_enjambre.rebote.connect(_rebote)
	_enjambre.horneado.connect(func() -> void: _avisar("LAS CAÑERÍAS", 2.5))
	_enjambre.soltar(Vector3(0.0, 0.0, -TunelesNivel.LARGO / 2.0))
	_flecha(TunelesNivel.SALIDA, 0.0, "Salir al arroyo", _salir)
	_flecha(TunelesNivel.FONDO, PI, "Al cárcamo", _al_carcamo)
	_hud()


# --- Las flechas ---

# La flecha amarilla de los comercios: pisarla hace `accion`. `giro` vuelve su frente (+Z) hacia el tunel
func _flecha(donde: Vector3, giro: float, texto: String, accion: Callable) -> void:
	var area := Area3D.new()
	area.position = donde
	area.rotation.y = giro
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = MapPuntos.MARCADOR_RADIO
	cilindro.height = 2.0
	forma.shape = cilindro
	forma.position.y = 1.0
	area.add_child(forma)
	area.add_child(MapPuntos.flecha())
	var letrero := Label3D.new()
	letrero.text = texto
	letrero.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	letrero.pixel_size = 0.008
	letrero.font_size = 48
	letrero.outline_size = 12
	letrero.modulate = MapPuntos.MARCADOR_COLOR
	letrero.position = Vector3(0.0, 2.4, 0.0)
	letrero.visibility_range_end = 20.0
	area.add_child(letrero)
	area.body_entered.connect(func(c: Node3D) -> void:
		if c is Player and not _saliendo and not _reiniciando:
			accion.call())
	add_child(area)


func _salir() -> void:
	if not PasoJefe.desde_juego:
		_avisar("(Desde el juego, aquí sales al arroyo)", 2.0)
		return
	_saliendo = true
	PasoJefe.volver(self, false)


func _al_carcamo() -> void:
	_saliendo = true
	PasoJefe.seguir(self, LOMBRICES)


func _rebote() -> void:
	if _avisado:
		return
	_avisado = true
	_avisar(AVISO_REBOTE, 3.5)


# --- Vida, desmayo y avisos ---

func _process(_delta: float) -> void:
	_pintar_vida()
	if _enjambre.horneando:
		_letrero.text = "Cargando las cañerías..."
		return
	_letrero.text = _arrojables() + "\n" + CONTROLES
	if inmortal and _salud and _salud.vida < _salud.vida_max:
		_salud.vida = _salud.vida_max
	if _salud and _salud.vida <= 0 and not _reiniciando and not _saliendo:
		if PasoJefe.desde_juego:
			_saliendo = true
			PasoJefe.volver(self, false)
		else:
			_otra_vez()


# Como prueba suelta: negro, vida llena, al principio del tunel y las crias otra vez en sus bocas
func _otra_vez() -> void:
	_reiniciando = true
	var tween := create_tween()
	tween.tween_property(_negro, "color:a", 1.0, 0.6)
	tween.tween_callback(func() -> void:
		for zona in get_tree().get_nodes_in_group("zonas_lombriz"):
			if zona.dura > 0.0:
				zona.queue_free()
		if _salud:
			_salud.vida = _salud.vida_max
		_jugador.global_position = TunelesNivel.ENTRADA - Vector3(0.0, 0.0, 1.5)
		_jugador.velocity = Vector3.ZERO
		_enjambre.rearmar())
	tween.tween_property(_negro, "color:a", 0.0, 0.8)
	tween.tween_callback(func() -> void:
		_reiniciando = false
		_avisar("Otra vez", 1.5))


# Cuantas sales y molotovs traes de verdad (aqui no son infinitas)
func _arrojables() -> String:
	var inventario := get_node_or_null("/root/Inventory")
	if inventario == null:
		return ""
	var cuenta := [0, 0, 0]
	for item: InventoryItemData in inventario.items:
		if item and item.arrojar > 0 and item.arrojar < cuenta.size():
			cuenta[item.arrojar] += 1
	return "Sal %d · Molotov %d" % [cuenta[1], cuenta[2]]


func _hud() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 5
	add_child(capa)
	var caja := VBoxContainer.new()
	caja.position = Vector2(8, 8)
	caja.theme = BarraMadre.TEMA
	caja.add_theme_constant_override("separation", 2)
	capa.add_child(caja)
	_vida_texto = Label.new()
	_vida_texto.add_theme_font_size_override("font_size", 10)
	_vida_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_vida_texto.add_theme_constant_override("outline_size", 3)
	caja.add_child(_vida_texto)
	var fondo := ColorRect.new()
	fondo.color = Color(0.05, 0.05, 0.05, 0.85)
	fondo.custom_minimum_size = Vector2(VIDA_ANCHO + 4.0, 10.0)
	caja.add_child(fondo)
	_vida_relleno = ColorRect.new()
	_vida_relleno.position = Vector2(2, 2)
	_vida_relleno.size = Vector2(VIDA_ANCHO, 6.0)
	fondo.add_child(_vida_relleno)
	_jugador.estamina.lugar = Vector2(10.0, 40.0)
	_letrero = Label.new()
	_letrero.position = Vector2(8, 480 - 34)
	_letrero.add_theme_font_size_override("font_size", 10)
	_letrero.add_theme_color_override("font_outline_color", Color.BLACK)
	_letrero.add_theme_constant_override("outline_size", 4)
	capa.add_child(_letrero)
	_aviso = Label.new()
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso.theme = BarraMadre.TEMA
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 5)
	_aviso.modulate.a = 0.0
	capa.add_child(_aviso)
	_negro = ColorRect.new()
	_negro.color = Color(0, 0, 0, 0)
	_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_negro)


func _pintar_vida() -> void:
	if _salud == null:
		return
	var f := clampf(float(_salud.vida) / maxf(float(_salud.vida_max), 1.0), 0.0, 1.0)
	_vida_relleno.size.x = VIDA_ANCHO * f
	_vida_relleno.color = Color(0.85, 0.15, 0.12) if f < 0.35 else (Color(0.95, 0.75, 0.15) if f < 0.65 else Color(0.35, 0.85, 0.3))
	_vida_texto.text = "Vida %d / %d%s" % [_salud.vida, _salud.vida_max, "  (infinita)" if inmortal else ""]


func _avisar(texto: String, dura: float) -> void:
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(dura)
	tween.tween_property(_aviso, "modulate:a", 0.0, 0.6)
