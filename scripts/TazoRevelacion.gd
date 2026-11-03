class_name TazoRevelacion
extends CanvasLayer

# Abrir una bolsa especial de Takis (InventoryUI, "Abrir"): sale el tazo con su show, segun
# su rareza (TazoData.Rareza). Propuesta de AG:
#   1. la bolsa se abre y el tazo sube temblando (holografico: le sale oro)
#   2. se voltea despacio para ensenar su cara
#   3. destello: flash, un aro que cruza la pantalla y chispas
#   4. holografico: el arcoiris le corre encima mientras se ladea
#   5. raro y holografico: retumbo, zumbido hacia la camara y boom
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

var tazo: TazoData
var repetido := false
var serie := -1                  # la serie que completo este tazo, o -1
var ir_a_habilidades := false    # lo cerraron con H: InventoryUI abre la pagina

var _saltar := false
var _listo := false
var _t := 0.0                # s desde que termino el show, para que siga meciendose
var _vista: SubViewport
var _camara: Camera3D
var _pivote: Node3D
var _cara: ShaderMaterial
var _bolsas: Array[Node3D] = []
var _oro: CPUParticles3D
var _flash: ColorRect
var _aro: ColorRect
var _chispas: TextureRect
var _chispas_hoja: Dictionary
var _chispas_desde := -1
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
	# 1. La bolsa aparece, tiembla, se rompe y el tazo sube temblando
	await _animar(0.25, func(e: float) -> void: bolsa.scale = Vector3.ONE * lerpf(0.5, 1.0, _salida(e)))
	_sonar("tazo_tiembla")
	await _animar(0.85, func(e: float) -> void:
		bolsa.rotation.z = sin(e * 40.0) * 0.1 * e
		bolsa.position.x = sin(e * 57.0) * 0.025 * e)
	_sonar("bolsa_abrir")
	_bolsas[1].visible = true
	_pivote.visible = true
	_oro.emitting = holo
	await _animar(0.6, func(e: float) -> void:
		var s := _salida(e)
		for i in 2:
			var lado := -1.0 if i == 0 else 1.0
			_bolsas[i].position = Vector3(lado * 1.0 * s, BOLSA_EN - 0.7 * s, 0.0)
			_bolsas[i].rotation = Vector3(0.0, 0.0, -lado * 0.9 * s)
			_bolsas[i].scale = Vector3.ONE * (1.0 - 0.5 * s)
		_pivote.position.y = lerpf(BOLSA_EN, ARRIBA, s)
		_pivote.scale = Vector3.ONE * lerpf(0.35, 1.0, s)
		_pivote.rotation.z = sin(e * 50.0) * 0.12 * (1.0 - e))
	for b in _bolsas:
		b.visible = false
	await _animar(0.7, func(e: float) -> void:
		_pivote.rotation.z = sin(e * 63.0) * 0.07
		_pivote.position.y = ARRIBA + sin(e * PI) * 0.04)
	_pivote.rotation.z = 0.0
	# 2. Se voltea despacio: de la cara de atras a la de adelante
	await _animar(1.3, func(e: float) -> void: _pivote.rotation.y = PI * (1.0 - _suave(e)))
	# 3. Destello: flash, aro y chispas
	_sonar("destello")
	_chispas_desde = Time.get_ticks_msec()
	await _animar(0.6, func(e: float) -> void:
		_flash.color.a = 0.85 * (1.0 - e)
		_poner_aro(_salida(e) * 1.7, 1.0 - e, AMARILLO)
		_cara.set_shader_parameter("luz", 1.4 * (1.0 - e)))
	# 4. Holografico: se ladea y el arcoiris le corre encima
	if holo:
		_sonar("brillo")
		_cara.set_shader_parameter("foil", 1.0)
		await _animar(1.8, func(e: float) -> void:
			_pivote.rotation.x = sin(e * TAU) * 0.35
			_pivote.rotation.y = sin(e * TAU * 0.5) * 0.45
			_cara.set_shader_parameter("barrido", lerpf(-0.4, 1.4, e)))
		_pivote.rotation = Vector3.ZERO
	# 5. Raro y holografico: retumbo, zumbido hacia la camara y boom
	if raro:
		_sonar("retumbo")
		await _animar(0.8, func(e: float) -> void:
			_camara.h_offset = randf_range(-1.0, 1.0) * 0.035 * e
			_camara.v_offset = randf_range(-1.0, 1.0) * 0.035 * e
			_pivote.rotation.z = sin(e * 90.0) * 0.04 * e)
		_camara.h_offset = 0.0
		_camara.v_offset = 0.0
		_pivote.rotation.z = 0.0
		_sonar("zumbido")
		await _animar(0.28, func(e: float) -> void: _pivote.position.z = 1.5 * e * e)
		_sonar("boom")
		await _animar(0.55, func(e: float) -> void:
			_pivote.position.z = 1.5 * (1.0 - _salida(e))
			_flash.color.a = 1.0 - e
			_poner_aro(e * 1.9, 1.0 - e, Color.WHITE)
			_camara.h_offset = randf_range(-1.0, 1.0) * 0.05 * (1.0 - e)
			_camara.v_offset = randf_range(-1.0, 1.0) * 0.05 * (1.0 - e))
	_final()


# Todo en su lugar final, se haya visto el show o se lo hayan saltado
func _final() -> void:
	for b in _bolsas:
		b.visible = false
	_pivote.visible = true
	_pivote.position = Vector3(0.0, _arriba_final(), 0.0)
	_pivote.rotation = Vector3.ZERO
	_pivote.scale = Vector3.ONE
	_camara.h_offset = 0.0
	_camara.v_offset = 0.0
	_flash.color.a = 0.0
	_poner_aro(0.0, 0.0, AMARILLO)
	_cara.set_shader_parameter("luz", 0.0)
	_cara.set_shader_parameter("foil", 1.0 if tazo.rareza == TazoData.Rareza.HOLO else 0.0)
	_oro.emitting = tazo.rareza == TazoData.Rareza.HOLO
	_textos.visible = true
	create_tween().tween_property(_textos, "modulate:a", 1.0, 0.35)
	_listo = true


func _process(delta: float) -> void:
	if _chispas_desde >= 0 and not _chispas_hoja.is_empty():
		var cuadro := int((Time.get_ticks_msec() - _chispas_desde) / 1000.0 * _chispas_hoja["fps"])
		if cuadro >= _chispas_hoja["cuadros"]:
			_chispas_desde = -1
			_chispas.visible = false
		else:
			var lado: Vector2 = _chispas_hoja["tamano"]
			(_chispas.texture as AtlasTexture).region = Rect2(Vector2(cuadro % _chispas_hoja["columnas"], cuadro / _chispas_hoja["columnas"]) * lado, lado)
			_chispas.visible = true
	if _listo:
		# Ya mostrado: se mece y el holografico sigue brillando
		_t += delta
		_pivote.rotation.y = sin(_t * 0.9) * 0.25
		_pivote.position.y = _arriba_final() + sin(_t * 1.7) * 0.02
		if tazo.rareza == TazoData.Rareza.HOLO:
			_cara.set_shader_parameter("barrido", fmod(_t * 0.4, 2.0) - 0.4)


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
	_vista = SubViewport.new()
	_vista.own_world_3d = true
	_vista.transparent_bg = true
	marco.add_child(_vista)
	# Chispas de pixelfx detras del tazo, en el centro
	_chispas_hoja = EfectosPixel.hoja_de("recoger_brillo")
	_chispas = TextureRect.new()
	_chispas.visible = false
	_chispas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_chispas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _chispas_hoja.is_empty():
		var region := AtlasTexture.new()
		region.atlas = _chispas_hoja["textura"]
		_chispas.texture = region
		var lado: Vector2 = _chispas_hoja["tamano"] * 3.0
		_chispas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_chispas.size = lado
		_chispas.set_anchors_preset(Control.PRESET_CENTER)
		_chispas.position = Vector2(320.0, 225.0) - lado * Vector2(0.5, 0.8)
	add_child(_chispas)
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
	_texto("+%d %s de habilidad%s" % [tazo.puntos, "punto" if tazo.puntos == 1 else "puntos", "  (repetido)" if repetido else ""], 16, Color.WHITE)
	var desbloqueo := tazo.desbloquea != "" and not repetido
	if desbloqueo:
		_texto("¡Desbloqueaste: %s!" % Habilidades.dato(tazo.desbloquea)["nombre"], 14, AMARILLO)
	if serie >= 0:
		_texto("¡Serie completa: %s! +%d puntos" % [TazoData.SERIES[serie], Tazos.PUNTOS_SERIE], 14, AMARILLO)
	# Con algo nuevo que gastar, H lleva directo a la pagina (y a la habilidad desbloqueada)
	if desbloqueo or serie >= 0:
		_texto("Enter: seguir · H: ir a habilidades", 11, Color(0.75, 0.75, 0.75))
	else:
		_texto("Enter: seguir · H en el inventario: habilidades", 11, Color(0.6, 0.6, 0.6))


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
