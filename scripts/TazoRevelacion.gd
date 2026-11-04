class_name TazoRevelacion
extends CanvasLayer

# Abrir una bolsa especial de Takis (InventoryUI, "Abrir"): sale el tazo con su show, segun
# su rareza (TazoData.Rareza). Propuesta de AG:
#   1. la bolsa aparece y tiembla
#   2. se abre y el tazo sale girando y temblando; el giro se frena hasta quedar de cara (mas
#      vueltas entre mas raro; holografico: le sale oro, se ladea y le entra el arcoiris)
#   3. comun: destello (flash, aro y chispas) y ya
#   4. raro y holo: el retumbo crece mientras frena, se te viene encima y todo revienta junto
#      en el boom: destello, carga, chispas y, en el holo, arcoiris completo y rayos de sol
# De pixelfx: chispas del color de la rareza, la carga del boom, los rayos y el confeti al
# completar serie. Con EfectosPixel.extras apagado solo salen las chispas de siempre.
# Al final su nombre, rareza y puntos. Enter se salta el show; ya terminado, Enter o Esc lo
# cierran. Corre con el juego en pausa (encima del inventario) y en tiempo real.

signal termino

const CAPA := 12
const BOLSA := "res://resources/productos/takis_tazo.tres"
const REVERSO := preload("res://textures/tazos/reverso.png")
const SHADER := preload("res://shaders/tazo.gdshader")
const RADIO := 0.55          # m del tazo
const GRUESO := 0.035
const LADOS := 30
const ARRIBA := 0.12         # donde flota el tazo
const BOLSA_EN := -0.35
const VOLUMEN := -4.0        # dB
const AMARILLO := Color(1.0, 0.85, 0.1)
const ORO_LADO := 0.035      # m de cada pizca de oro
const RENGLON_EXTRA := 0.1   # m que sube el tazo al final por cada renglon de mas
const LADEO := 0.3           # rad que se ladea el holografico para que corra el arcoiris
const GIRO := [1.6, 2.1, 2.5]   # s que tarda en salir girando, por rareza
const VUELTAS := [1, 2, 3]      # vueltas completas antes de quedar de cara, por rareza
const ABRIR := 0.6           # s en que la bolsa termina de abrirse y el tazo de subir
const ARCOIRIS_DESDE := 0.55 # parte del giro en que empieza a entrar el arcoiris (holo)
const RETUMBO_DESDE := 0.6   # parte del giro en que empieza a crecer el retumbo (raro y holo)
const ZUMBIDO := 0.28        # s que tarda en venirse encima
const ACERCA := 1.5          # m que se acerca a la camara
const BOOM_RARO := 0.7       # s del boom
const BOOM_HOLO := 1.4       # s del boom del holo, con el ladeo
const SUBIDA := 0.5          # s que tarda en subir a su lugar final, si hay renglones de mas
const CARGA_SUELTA := 0.22   # s en que revienta la hoja tazo_carga_* (GATHER de mana-burst)
const PIXEL_CHISPAS := 3.0   # pixeles de pantalla por pixel de cada hoja
const PIXEL_RAYOS := 5.0
const PIXEL_CARGA := 3.0
const PIXEL_CONFETI := 3.2   # 640 px: de orilla a orilla
const CHISPAS := ["tazo_brillo_comun", "tazo_brillo_raro", "tazo_brillo_holo"]

var tazo: TazoData
var repetido := false
var serie := -1                  # la serie que completo este tazo, o -1
var ir_a_habilidades := false    # lo cerraron con H: InventoryUI abre la pagina

var _saltar := false
var _listo := false
var _t := 0.0                # s desde que termino el show, para que siga meciendose
var _subida_desde := 0.0     # altura en que acabo el show, de ahi sube a _arriba_final()
var _vista: SubViewport
var _camara: Camera3D
var _pivote: Node3D
var _cara: ShaderMaterial
var _bolsas: Array[Node3D] = []
var _oro: CPUParticles3D
var _flash: ColorRect
var _aro: ColorRect
# Hojas de pixelfx en 2D (_hoja_2d): { rect, hoja, escala, desde, en }; vacias si no hay hoja
var _chispas: Dictionary
var _rayos: Dictionary
var _carga: Dictionary
var _confeti: Dictionary
var _activas: Array[Dictionary] = []
var _textos: VBoxContainer


# Lo pone encima de todo y empieza el show; `termino` cuando lo cierras
static func abrir(padre: Node, que: TazoData, es_repetido: bool, completo := -1) -> TazoRevelacion:
	var r := TazoRevelacion.new()
	r.tazo = que
	r.repetido = es_repetido
	r.serie = completo
	padre.add_child(r)
	return r


func _ready() -> void:
	layer = CAPA
	process_mode = Node.PROCESS_MODE_ALWAYS
	_armar_pantalla()
	_armar_mundo()
	_correr()


# --- El show ---

func _correr() -> void:
	var raro := tazo.rareza >= TazoData.Rareza.RARO
	var holo := tazo.rareza == TazoData.Rareza.HOLO
	var bolsa := _bolsas[0]
	# 1. La bolsa aparece y tiembla
	await _animar(0.25, func(e: float) -> void: bolsa.scale = Vector3.ONE * lerpf(0.5, 1.0, _salida(e)))
	_sonar("tazo_tiembla")
	await _animar(0.85, func(e: float) -> void:
		bolsa.rotation.z = sin(e * 40.0) * 0.1 * e
		bolsa.position.x = sin(e * 57.0) * 0.025 * e)
	_sonar("bolsa_abrir")
	_bolsas[1].visible = true
	_pivote.visible = true
	_oro.emitting = holo
	# 2. Sale girando y temblando: la bolsa se abre, el tazo sube y el giro se va frenando hasta
	# quedar de cara. Raro y holo: el retumbo crece en la ultima parte del giro. Holo: se ladea y
	# el arcoiris le va entrando conforme frena
	var giro: float = GIRO[tazo.rareza]
	var vueltas: float = PI + TAU * VUELTAS[tazo.rareza]
	var sono := {"retumbo": false, "brillo": false}
	await _animar(giro, func(e: float) -> void:
		var t := e * giro
		var abre := _salida(minf(t / ABRIR, 1.0))
		for i in 2:
			var lado := -1.0 if i == 0 else 1.0
			_bolsas[i].position = Vector3(lado * 1.0 * abre, BOLSA_EN - 0.7 * abre, 0.0)
			_bolsas[i].rotation = Vector3(0.0, 0.0, -lado * 0.9 * abre)
			_bolsas[i].scale = Vector3.ONE * (1.0 - 0.5 * abre)
			_bolsas[i].visible = abre < 1.0
		_pivote.position.y = lerpf(BOLSA_EN, ARRIBA, abre)
		_pivote.scale = Vector3.ONE * lerpf(0.35, 1.0, abre)
		_pivote.rotation.y = vueltas * (1.0 - _salida(e))
		# El temblor de salir de la bolsa se apaga mientras gira
		var tiembla := pow(1.0 - e, 1.5)
		_pivote.rotation.z = sin(t * 50.0) * 0.12 * tiembla
		_pivote.position.x = sin(t * 61.0) * 0.02 * tiembla
		if raro:
			var r := clampf((e - RETUMBO_DESDE) / (1.0 - RETUMBO_DESDE), 0.0, 1.0)
			if r > 0.0 and not sono["retumbo"]:
				sono["retumbo"] = true
				_sonar("retumbo")
			_camara.h_offset = randf_range(-1.0, 1.0) * 0.035 * r
			_camara.v_offset = randf_range(-1.0, 1.0) * 0.035 * r
			_pivote.rotation.z += sin(t * 90.0) * 0.04 * r
		if holo:
			var k := clampf((e - ARCOIRIS_DESDE) / (1.0 - ARCOIRIS_DESDE), 0.0, 1.0)
			_pivote.rotation.x = LADEO * _suave(k)
			_cara.set_shader_parameter("foil", _suave(k))
			_cara.set_shader_parameter("barrido", lerpf(-0.4, 0.5, k))
			if k > 0.2 and not sono["brillo"]:
				sono["brillo"] = true
				_sonar("brillo"))
	for b in _bolsas:
		b.visible = false
	_pivote.position.x = 0.0
	_pivote.rotation.z = 0.0
	# 3. Comun: el destello y ya
	if not raro:
		_sonar("destello")
		_lanzar(_chispas, _chispas.get("en", Vector2.ZERO))
		await _animar(0.6, _destello)
		_final()
		return
	# 4. Raro y holo: se te viene encima mientras la carga entra al tazo y todo revienta junto en
	# el boom (destello, aro, chispas, carga, arcoiris completo y rayos); el holo se ladea
	# mientras se apaga y acaba donde empieza a mecerse (_process)
	_sonar("zumbido")
	_lanzar(_carga, _en_pantalla() + Vector2(0.0, -_carga.get("cy", 0.0)), ZUMBIDO - CARGA_SUELTA)
	await _animar(ZUMBIDO, func(e: float) -> void:
		_pivote.position.z = ACERCA * e * e
		_camara.h_offset = randf_range(-1.0, 1.0) * 0.035
		_camara.v_offset = randf_range(-1.0, 1.0) * 0.035)
	_sonar("boom")
	_lanzar(_chispas, _chispas.get("en", Vector2.ZERO))
	if holo:
		_cara.set_shader_parameter("foil", 1.0)
		_lanzar(_rayos, _en_pantalla())
	var boom: float = BOOM_HOLO if holo else BOOM_RARO
	await _animar(boom, func(e: float) -> void:
		var t := e * boom
		var f := minf(t / 0.6, 1.0)
		_pivote.position.z = ACERCA * (1.0 - _salida(minf(t / 0.55, 1.0)))
		_flash.color.a = 1.0 - f
		_poner_aro(f * 1.9, 1.0 - f, Color.WHITE)
		_cara.set_shader_parameter("luz", 1.4 * (1.0 - f))
		_camara.h_offset = randf_range(-1.0, 1.0) * 0.05 * (1.0 - f)
		_camara.v_offset = randf_range(-1.0, 1.0) * 0.05 * (1.0 - f)
		if holo:
			_pivote.rotation.x = LADEO * (1.0 - e) * cos(e * TAU)
			_pivote.rotation.y = sin(e * TAU) * 0.45 * (1.0 - e)
			_cara.set_shader_parameter("barrido", lerpf(0.5, 1.5, e))
			if not _rayos.is_empty():
				_rayos["rect"].modulate.a = f)
	_pivote.rotation = Vector3.ZERO
	_final()


# Todo en su lugar final, se haya visto el show o se lo hayan saltado
func _final() -> void:
	for b in _bolsas:
		b.visible = false
	_pivote.visible = true
	# Visto el show sube suave de donde quedo; saltado, aparece ya en su lugar
	_subida_desde = _arriba_final() if _saltar else _pivote.position.y
	_t = 0.0
	_pivote.position = Vector3(0.0, _subida_desde, 0.0)
	_pivote.rotation = Vector3.ZERO
	_pivote.scale = Vector3.ONE
	_camara.h_offset = 0.0
	_camara.v_offset = 0.0
	_flash.color.a = 0.0
	_poner_aro(0.0, 0.0, AMARILLO)
	_cara.set_shader_parameter("luz", 0.0)
	_cara.set_shader_parameter("foil", 1.0 if tazo.rareza == TazoData.Rareza.HOLO else 0.0)
	_oro.emitting = tazo.rareza == TazoData.Rareza.HOLO
	if _saltar:
		for h in _activas:
			h["rect"].visible = false
		_activas.clear()
	if tazo.rareza == TazoData.Rareza.HOLO and not _rayos.is_empty():
		_rayos["rect"].modulate.a = 1.0
		if not _activas.has(_rayos):
			_lanzar(_rayos, _en_pantalla(), 0.0, true)
	if serie >= 0:
		_lanzar(_confeti, Vector2(320.0, 480.0), 0.0, true)
	_textos.visible = true
	create_tween().tween_property(_textos, "modulate:a", 1.0, 0.35)
	_listo = true


func _process(delta: float) -> void:
	if _listo:
		# Ya mostrado: se mece y el holografico sigue brillando
		_t += delta
		_pivote.rotation.y = sin(_t * 0.9) * 0.25
		_pivote.position.y = lerpf(_subida_desde, _arriba_final(), _suave(minf(_t / SUBIDA, 1.0))) + sin(_t * 1.7) * 0.02
		if tazo.rareza == TazoData.Rareza.HOLO:
			_cara.set_shader_parameter("barrido", fmod(_t * 0.4, 2.0) - 0.4)
	# Las hojas de pixelfx, en tiempo real (el arbol esta en pausa); los rayos siguen al tazo
	if _activas.has(_rayos):
		_rayos["en"] = _en_pantalla()
	for h in _activas.duplicate():
		var hoja: Dictionary = h["hoja"]
		var rect: TextureRect = h["rect"]
		var t: float = (Time.get_ticks_msec() - h["desde"]) / 1000.0
		if t < 0.0:
			continue
		var cuadro := int(t * hoja["fps"])
		if hoja["loop"]:
			cuadro %= hoja["cuadros"]
		elif cuadro >= hoja["cuadros"]:
			rect.visible = false
			_activas.erase(h)
			continue
		var lado: Vector2 = hoja["tamano"]
		(rect.texture as AtlasTexture).region = Rect2(Vector2(cuadro % hoja["columnas"], cuadro / hoja["columnas"]) * lado, lado)
		rect.position = h["en"] - hoja["pivote"] * h["escala"]
		rect.visible = true


func _input(event: InputEvent) -> void:
	var ir := _listo and event.is_action_pressed("inventory_skills")
	if not (ir or event.is_action_pressed("inventory_confirm") or event.is_action_pressed("inventory_back") or event.is_action_pressed("jump")):
		return
	get_viewport().set_input_as_handled()
	if not _listo:
		_saltar = true
		return
	if ir:
		ir_a_habilidades = true
	termino.emit()
	queue_free()


# Corre `paso(e)` con e de 0 a 1 durante `segundos` de reloj real; se corta si te lo saltas
func _animar(segundos: float, paso: Callable) -> void:
	var desde := Time.get_ticks_msec()
	while not _saltar:
		var e := clampf((Time.get_ticks_msec() - desde) / (segundos * 1000.0), 0.0, 1.0)
		paso.call(e)
		if e >= 1.0:
			return
		await get_tree().process_frame


# Flash, aro y destello en la cara, de e = 0 (todo) a 1 (apagado)
func _destello(e: float) -> void:
	_flash.color.a = 0.85 * (1.0 - e)
	_poner_aro(_salida(e) * 1.7, 1.0 - e, AMARILLO)
	_cara.set_shader_parameter("luz", 1.4 * (1.0 - e))


# Donde se ve el centro del tazo en la pantalla (la vista ocupa toda la pantalla)
func _en_pantalla() -> Vector2:
	return _camara.unproject_position(_pivote.global_position)


# Una hoja de pixelfx en 2D dentro de `padre`, escondida hasta _lanzar; {} si no esta la hoja
func _hoja_2d(nombre: String, escala: float, padre: Control) -> Dictionary:
	var hoja := EfectosPixel.hoja_de(nombre)
	if hoja.is_empty():
		return {}
	var rect := TextureRect.new()
	rect.visible = false
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var region := AtlasTexture.new()
	region.atlas = hoja["textura"]
	rect.texture = region
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.size = hoja["tamano"] * escala
	padre.add_child(rect)
	return {"rect": rect, "hoja": hoja, "escala": escala, "desde": 0, "en": Vector2.ZERO}


# Empieza la hoja con su pivote en `en` (pixeles de pantalla), `retraso` s despues. Con el show
# saltado no sale nada, salvo lo del final (`aunque_saltes`)
func _lanzar(h: Dictionary, en: Vector2, retraso := 0.0, aunque_saltes := false) -> void:
	if h.is_empty() or (_saltar and not aunque_saltes):
		return
	h["desde"] = Time.get_ticks_msec() + int(retraso * 1000.0)
	h["en"] = en
	if not _activas.has(h):
		_activas.append(h)


# Ya mostrado sube un poco por cada renglon de mas (desbloqueo, serie) para que no lo tapen
func _arriba_final() -> float:
	return ARRIBA + RENGLON_EXTRA * maxi(_textos.get_child_count() - 4, 0)


func _salida(e: float) -> float:
	return 1.0 - pow(1.0 - e, 3.0)


func _suave(e: float) -> float:
	return e * e * (3.0 - 2.0 * e)


func _sonar(nombre: String) -> void:
	if not _saltar:
		Sonidos.tocar(self, nombre, VOLUMEN)


# --- Armado ---

func _armar_pantalla() -> void:
	var fondo := ColorRect.new()
	# Negro completo: a 0.9 se alcanzaban a leer los textos del inventario detras
	fondo.color = Color.BLACK
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)
	var marco := SubViewportContainer.new()
	marco.stretch = true
	marco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marco)
	# Lo que va detras del tazo (rayos del holografico, confeti), entre el fondo y la vista 3D
	var detras := Control.new()
	detras.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(detras)
	move_child(detras, marco.get_index())
	_vista = SubViewport.new()
	_vista.own_world_3d = true
	_vista.transparent_bg = true
	marco.add_child(_vista)
	# Hojas de pixelfx encima del tazo: chispas del color de la rareza en el destello y la carga
	# del boom
	var delante := Control.new()
	delante.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	delante.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(delante)
	_chispas = _hoja_2d(CHISPAS[tazo.rareza] if EfectosPixel.extras else "recoger_brillo", PIXEL_CHISPAS, delante)
	if not _chispas.is_empty():
		# Mismo lugar que antes: el centro del brillo cae detras del tazo
		var lado: Vector2 = _chispas["hoja"]["tamano"] * PIXEL_CHISPAS
		_chispas["en"] = Vector2(320.0, 225.0) - lado * Vector2(0.5, 0.8) + _chispas["hoja"]["pivote"] * PIXEL_CHISPAS
	if EfectosPixel.extras:
		if tazo.rareza == TazoData.Rareza.HOLO:
			_rayos = _hoja_2d("tazo_rayos", PIXEL_RAYOS, detras)
		if tazo.rareza >= TazoData.Rareza.RARO:
			_carga = _hoja_2d("tazo_carga_holo" if tazo.rareza == TazoData.Rareza.HOLO else "tazo_carga_raro", PIXEL_CARGA, delante)
			if not _carga.is_empty():
				_carga["cy"] = -28.0 * PIXEL_CARGA   # el estallido va 28 px arriba del pivote
		if serie >= 0:
			# Detras del tazo y de los textos, para que se sigan leyendo
			_confeti = _hoja_2d("tazo_confeti", PIXEL_CONFETI, detras)
	_aro = ColorRect.new()
	_aro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_aro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float radio = 0.0;
uniform float alfa = 0.0;
uniform vec4 color : source_color = vec4(1.0);
void fragment() {
	vec2 p = (UV - vec2(0.5, 0.47)) * vec2(1.333, 1.0);
	float d = abs(length(p) - radio);
	float aro = step(d, 0.012 + radio * 0.025);
	COLOR = vec4(color.rgb, aro * alfa);
}
"""
	material.shader = shader
	_aro.material = material
	add_child(_aro)
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 1.0, 0.95, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_textos = VBoxContainer.new()
	_textos.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_textos.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_textos.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_textos.offset_bottom = -22.0
	_textos.alignment = BoxContainer.ALIGNMENT_END
	_textos.visible = false
	_textos.modulate.a = 0.0
	add_child(_textos)
	_texto("No. %02d · %s" % [tazo.numero, tazo.nombre], 22, AMARILLO)
	_texto(TazoData.RAREZAS[tazo.rareza], 14, TazoData.COLORES_RAREZA[tazo.rareza])
	_texto(texto_puntos(tazo, repetido), 16, Color.WHITE)
	var desbloqueo := tazo.desbloquea != "" and not repetido
	if desbloqueo:
		_texto("¡Desbloqueaste: %s!" % Habilidades.dato(tazo.desbloquea)["nombre"], 14, AMARILLO)
	if serie >= 0:
		_texto("¡Serie completa: %s!" % TazoData.SERIES[serie], 14, AMARILLO)
	# Con algo nuevo que gastar, H lleva directo a la pagina (y a la habilidad desbloqueada)
	if desbloqueo or serie >= 0:
		_texto("Enter: seguir · H: ir a habilidades", 11, Color(0.75, 0.75, 0.75))
	else:
		_texto("Enter: seguir · H en el inventario: habilidades", 11, Color(0.6, 0.6, 0.6))


# Lo que dio el tazo (Tazos.ultimos_puntos): nada si es repetido, el avance de los comunes
static func texto_puntos(que: TazoData, es_repetido: bool) -> String:
	if es_repetido:
		return "Repetido: cámbialo con el niño de los tazos"
	var dio: int = Tazos.ultimos_puntos
	if dio > 0:
		return "+%d %s de habilidad" % [dio, "punto" if dio == 1 else "puntos"]
	return "Común: %d de %d para un punto" % [Tazos.progreso_comun(), Tazos.COMUNES_POR_PUNTO]


func _texto(texto: String, tamano: int, color: Color) -> void:
	var label := Label.new()
	label.text = texto
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	_textos.add_child(label)


func _poner_aro(radio: float, alfa: float, color: Color) -> void:
	var m := _aro.material as ShaderMaterial
	m.set_shader_parameter("radio", radio)
	m.set_shader_parameter("alfa", alfa)
	m.set_shader_parameter("color", color)


func _armar_mundo() -> void:
	var mundo := Node3D.new()
	_vista.add_child(mundo)
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_CLEAR_COLOR
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color(0.85, 0.82, 0.9)
	ambiente.environment.ambient_light_energy = 0.7
	mundo.add_child(ambiente)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	sol.light_energy = 1.1
	mundo.add_child(sol)
	_camara = Camera3D.new()
	_camara.position = Vector3(0.0, 0.0, 3.0)
	_camara.fov = 38.0
	mundo.add_child(_camara)
	_camara.current = true
	# La bolsa: dos copias del modelo dorado que se separan al romperse
	var item := load(BOLSA) as InventoryItemData
	for i in 2:
		var bolsa: Node3D = item.crear_modelo(1.25) if item else Node3D.new()
		bolsa.position.y = BOLSA_EN
		bolsa.visible = i == 0
		mundo.add_child(bolsa)
		_bolsas.append(bolsa)
	# El tazo: empieza adentro de la bolsa, con el reverso hacia ti
	_pivote = Node3D.new()
	_pivote.position.y = BOLSA_EN
	_pivote.rotation.y = PI
	_pivote.scale = Vector3.ONE * 0.35
	_pivote.visible = false
	mundo.add_child(_pivote)
	var disco := crear_disco(tazo)
	_cara = disco.get_surface_override_material(0)
	_pivote.add_child(disco)
	_oro = _particulas_oro()
	_pivote.add_child(_oro)


# El tazo en 3D: la malla (compartida) con cara, reverso y canto del color de su rareza. La
# superficie 0 es la cara (ShaderMaterial de shaders/tazo.gdshader: foil, barrido, luz). Lo
# usan este show y el album (AlbumTazos.gd)
static var _malla_compartida: ArrayMesh

static func crear_disco(que: TazoData) -> MeshInstance3D:
	if _malla_compartida == null:
		_malla_compartida = _malla()
	var disco := MeshInstance3D.new()
	disco.mesh = _malla_compartida
	disco.set_surface_override_material(0, _material(que.cara, false, que.rareza))
	disco.set_surface_override_material(1, _material(REVERSO, false, que.rareza))
	disco.set_surface_override_material(2, _material(null, true, que.rareza))
	return disco


static func _material(textura: Texture2D, orilla: bool, rareza: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	if textura:
		m.set_shader_parameter("cara", textura)
	m.set_shader_parameter("es_orilla", orilla)
	m.set_shader_parameter("color_orilla", TazoData.COLORES_RAREZA[rareza].darkened(0.2))
	return m


# Un disco con cara (+Z), reverso (-Z) y canto; cada uno su superficie
static func _malla() -> ArrayMesh:
	var malla := ArrayMesh.new()
	for lado in [1.0, -1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3(0.0, 0.0, lado))
		var z: float = GRUESO * 0.5 * lado
		for i in LADOS:
			var a0 := TAU * i / LADOS
			var a1 := TAU * (i + 1) / LADOS
			# El reverso se ve al voltearlo: su textura va en espejo para que se lea
			var u0 := Vector2(0.5 + cos(a0) * 0.5 * lado, 0.5 - sin(a0) * 0.5)
			var u1 := Vector2(0.5 + cos(a1) * 0.5 * lado, 0.5 - sin(a1) * 0.5)
			var p0 := Vector3(cos(a0) * RADIO, sin(a0) * RADIO, z)
			var p1 := Vector3(cos(a1) * RADIO, sin(a1) * RADIO, z)
			var centro := Vector3(0.0, 0.0, z)
			var tri := [[centro, Vector2(0.5, 0.5)], [p0, u0], [p1, u1]] if lado < 0.0 else [[centro, Vector2(0.5, 0.5)], [p1, u1], [p0, u0]]
			for v: Array in tri:
				st.set_uv(v[1])
				st.add_vertex(v[0])
		st.commit(malla)
	var canto := SurfaceTool.new()
	canto.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in LADOS:
		var a0 := TAU * i / LADOS
		var a1 := TAU * (i + 1) / LADOS
		var n0 := Vector3(cos(a0), sin(a0), 0.0)
		var n1 := Vector3(cos(a1), sin(a1), 0.0)
		var adelante := Vector3(0.0, 0.0, GRUESO * 0.5)
		for v: Array in [[n0, -adelante], [n1, -adelante], [n1, adelante], [n0, -adelante], [n1, adelante], [n0, adelante]]:
			canto.set_normal(v[0])
			canto.add_vertex(v[0] * RADIO + v[1])
		canto.commit(malla)
	return malla


# El oro que se le sale al holografico, del canto hacia abajo
func _particulas_oro() -> CPUParticles3D:
	var oro := CPUParticles3D.new()
	oro.emitting = false
	oro.amount = 70
	oro.lifetime = 1.3
	oro.local_coords = false
	oro.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	oro.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	oro.emission_ring_radius = RADIO
	oro.emission_ring_inner_radius = RADIO * 0.9
	oro.emission_ring_height = GRUESO
	oro.direction = Vector3(0.0, -1.0, 0.0)
	oro.spread = 35.0
	oro.gravity = Vector3(0.0, -1.6, 0.0)
	oro.initial_velocity_min = 0.1
	oro.initial_velocity_max = 0.5
	oro.scale_amount_min = 0.6
	oro.scale_amount_max = 1.3
	# El tamano va en la malla: con un cuadro de 1 m y escala de particula chica salian de 1 m
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * ORO_LADO
	var brillo := StandardMaterial3D.new()
	brillo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# BILLBOARD_PARTICLES respeta el tamano de cada particula (con ENABLED salian de 1 m)
	brillo.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	brillo.vertex_color_use_as_albedo = true
	brillo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = brillo
	oro.mesh = quad
	var colores := Gradient.new()
	colores.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	colores.set_color(1, Color(0.85, 0.5, 0.05, 0.0))
	oro.color_ramp = colores
	return oro
