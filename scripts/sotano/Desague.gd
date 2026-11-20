extends Node3D

# El desague de abajo del bano del Sotano: la pelea con LA DESAGUADORA (Desaguadora.gd), a lo Silent
# Hill 2. Lo crea Sotano.gd (_bajar_al_desague) como hijo suyo, muy abajo del bano, y te pone en la
# escalera; al vencerla o al subir por la escalera te regresa al bano y se borra.
# - El cuarto: models/sotano/desague.glb (tools/blender/sotano/desague.py): oxido, carne en los
#   muros, rejas, tubos, cadenas, focos rojos enjaulados, la poza negra y cinco coladeras.
# - La niebla: prende la niebla volumetrica del Environment (densidad global 0) y pone una
#   FogVolume en el cuarto; al salir deja el Environment como estaba.
# - Al bajar suena la sirena (hecha aqui, como la de las pelis) y luego un zumbido grave en vuelta.
# - Con combate (CasaPropia lo apaga): Player.poner_sin_combate(false) al bajar y true al subir.
# - No te desmayas aqui: si un golpe te mataria, el agua te escupe de regreso al bano con poca vida
#   (herir_jugador) y ella te espera de nuevo.
# - Premio (una vez por partida, Fichas.desaguadora): PREMIO_FICHAS y la varilla (VARILLA).
# - Mas dura (AG 2026-11-19): perder cuesta la mitad de tus fichas; en fase 2 y 3 salen ahogados
#   (Zombie de verdad, gris azulados, AHOGADOS_MAX a la vez) por las coladeras; en la 3 sube el agua
#   negra (AGUA_ALTO en AGUA_TARDA s) y quema DANO_AGUA por segundo si estas en ella: dos tarimas
#   (TARIMAS) y la camilla quedan secas. (Sin frenarte en el agua: eso seria en player.gd, de JJ.)

const CUARTO := preload("res://models/sotano/desague.glb")
const JEFA := preload("res://scripts/sotano/Desaguadora.gd")
const VARILLA := "res://resources/productos/varilla_desague.tres"
const PREMIO_FICHAS := 300
const VIDA_RESCATE := 30
const NIEBLA_COLOR := Color(0.35, 0.33, 0.3)
const NIEBLA_DENSIDAD := 0.09
const LUZ_ROJA := Color(1.0, 0.18, 0.1)
const AHOGADOS_MAX := 4
const AHOGADO_TINTE := Color(0.55, 0.68, 0.78)
const AGUA_DESDE := -0.15            # m (escena) del agua al empezar a subir, y hasta donde llega
const AGUA_ALTO := 0.45
const AGUA_TARDA := 20.0
const DANO_AGUA := 4
const TARIMAS := [Vector3(-4.2, 0.0, 2.6), Vector3(4.0, 0.0, -2.8)]
const TARIMA := Vector3(1.4, 0.6, 1.4)

var sotano: Node3D                   # para avisar y para regresar
var _cuarto: Node3D
var _jefa: Desaguadora
var _player: Node3D
var _marcas := {}
var _luces: Array[OmniLight3D] = []
var _hud: CanvasLayer
var _barra: ProgressBar
var _env: Environment
var _env_antes := {}
var _niebla: FogVolume
var _zumbido: AudioStreamPlayer
var _aspas: Node3D
var _salida: Node3D
var _termino := false
var _ahogados: Array[Node] = []
var _agua: MeshInstance3D
var _agua_t := 0.0
var _agua_sube := false
var _agua_dano_t := 0.0
static var _mat_ahogado: ShaderMaterial


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("jugador") as Node3D
	_cuarto = CUARTO.instantiate()
	add_child(_cuarto)
	for n in _cuarto.find_children("Marca_*", "Node3D", true, false):
		_marcas[n.name.trim_prefix("Marca_")] = n as Node3D
	_aspas = _cuarto.find_child("Des_ventilador_aspas", true, false) as Node3D
	# Las luces: los focos rojos enjaulados (dos parpadean) y una luz fria, muy baja, desde arriba
	var k := 0
	while _marcas.has("Luz_des_%d" % k):
		var luz := OmniLight3D.new()
		luz.light_color = LUZ_ROJA
		luz.light_energy = 1.6
		luz.omni_range = 6.0
		luz.light_volumetric_fog_energy = 2.0
		luz.shadow_enabled = false
		add_child(luz)
		luz.global_position = (_marcas["Luz_des_%d" % k] as Node3D).global_position
		_luces.append(luz)
		k += 1
	var arriba := OmniLight3D.new()
	arriba.light_color = Color(0.6, 0.7, 0.75)
	arriba.light_energy = 0.6
	arriba.omni_range = 14.0
	add_child(arriba)
	arriba.position = Vector3(0, 3.8, 0)
	_armar_niebla()
	_armar_hud()
	# La jefa sale de la coladera de en medio
	_jefa = JEFA.new()
	_jefa.arena = self
	add_child(_jefa)
	_jefa.position = Vector3.ZERO
	_jefa.vida_cambio.connect(func(f: float) -> void: _barra.value = f * 100.0)
	_jefa.fase_cambio.connect(_fase)
	_jefa.murio.connect(_vencida)
	_armar_tarimas()
	_sirena()
	for i in [1, 4]:
		if i < _luces.size():
			_parpadear(_luces[i])


func _process(delta: float) -> void:
	if _aspas:
		_aspas.rotate_x(delta * 0.8)
	# El agua negra de la fase 3: sube y quema si estas en ella
	if _agua and _agua_sube:
		_agua_t = minf(_agua_t + delta, AGUA_TARDA)
		_agua.position.y = lerpf(AGUA_DESDE, AGUA_ALTO, ease(_agua_t / AGUA_TARDA, 0.6))
		if _player and not _termino:
			var pies := to_local(_player.global_position).y
			if pies < _agua.position.y - 0.05:
				_agua_dano_t += delta
				if _agua_dano_t >= 1.0:
					_agua_dano_t = 0.0
					herir_jugador(DANO_AGUA, _player.global_position + Vector3.DOWN, 0.0)
			else:
				_agua_dano_t = 0.0


# Las coladeras por donde sale (en global)
func coladeras() -> Array:
	var r := []
	for k in 5:
		if _marcas.has("Coladera_%d" % k):
			r.append((_marcas["Coladera_%d" % k] as Node3D).global_position)
	return r


func entrada() -> Vector3:
	return (_marcas["Entrada"] as Node3D).global_position if _marcas.has("Entrada") else global_position


# --- El jugador ---

func herir_jugador(dano: int, desde: Vector3, empuje: float) -> void:
	if _termino or _player == null:
		return
	var salud := get_node_or_null("/root/Salud")
	if salud and salud.vida <= dano:
		_rescate()
		return
	if _player.has_method("recibir_dano"):
		_player.recibir_dano(dano, desde, empuje, _jefa)


# El agua te escupe al bano con poca vida y se queda con la mitad de tus fichas; ella se queda
# esperando (vuelve a llena)
func _rescate() -> void:
	var salud := get_node_or_null("/root/Salud")
	if salud:
		salud.vida = VIDA_RESCATE
	var f := get_node_or_null("/root/Fichas")
	var perdidas := 0
	if f:
		perdidas = int(f.fichas) / 2 + int(f.fichas) % 2
		f.fichas -= perdidas
	if sotano:
		sotano.call("avisar", "El agua negra te escupe de regreso al baño... y se queda con %d de tus fichas. Abajo, algo se ríe." % perdidas)
		sotano.call("_subir_del_desague")


func _vencida() -> void:
	_termino = true
	_hud.visible = false
	_matar_ahogados()
	_agua_sube = false
	if _agua:
		create_tween().tween_property(_agua, "position:y", AGUA_DESDE - 0.3, 3.0)
	var f := get_node_or_null("/root/Fichas")
	var primera: bool = f != null and not f.desaguadora
	if f:
		f.desaguadora = true
		if primera:
			f.fichas += PREMIO_FICHAS
	var texto := "La Desaguadora se hunde por la coladera y no vuelve a salir."
	if primera:
		var inventario := get_node_or_null("/root/Inventory")
		if inventario and ResourceLoader.exists(VARILLA):
			inventario.add_item(load(VARILLA))
		texto += " Te quedas con %d fichas y la varilla del desagüe." % PREMIO_FICHAS
		Sonidos.tocar(self, "slot_premio_mayor", -4.0)
	if sotano:
		sotano.call("avisar", texto)
	# Ya sin ella: luces frias, se va la niebla roja
	for luz in _luces:
		luz.light_color = Color(0.7, 0.6, 0.5)
	if _env:
		_env.volumetric_fog_albedo = Color(0.5, 0.5, 0.5)


func _fase(fase: int) -> void:
	# Mas roja y mas espesa la niebla con cada fase
	if _niebla and _niebla.material:
		(_niebla.material as FogMaterial).density = NIEBLA_DENSIDAD * (1.0 + (fase - 1) * 0.5)
		(_niebla.material as FogMaterial).albedo = NIEBLA_COLOR.lerp(Color(0.5, 0.15, 0.12), (fase - 1) * 0.45)
	for luz in _luces:
		luz.light_energy = 1.6 + (fase - 1) * 0.6
	if sotano:
		sotano.call("avisar", "¡La Desaguadora se enoja!" if fase == 2 else "Del techo empieza a caer agua negra.")


# --- Niebla, sirena, barra ---

func _armar_niebla() -> void:
	var mundo := get_viewport().world_3d
	_env = mundo.environment if mundo else null
	if _env == null:
		var we := get_tree().root.find_children("*", "WorldEnvironment", true, false)
		if not we.is_empty():
			_env = (we[0] as WorldEnvironment).environment
	if _env:
		_env_antes = {"vf": _env.volumetric_fog_enabled, "vfd": _env.volumetric_fog_density, "vfa": _env.volumetric_fog_albedo}
		_env.volumetric_fog_enabled = true
		_env.volumetric_fog_density = 0.0
		_env.volumetric_fog_albedo = NIEBLA_COLOR
	_niebla = FogVolume.new()
	_niebla.size = Vector3(16, 4, 16)
	var fm := FogMaterial.new()
	fm.density = NIEBLA_DENSIDAD
	fm.albedo = NIEBLA_COLOR
	fm.height_falloff = 0.4
	_niebla.material = fm
	add_child(_niebla)
	_niebla.position = Vector3(0, 1.6, 0)


# --- Los ahogados y el agua ---

# Salen `n` ahogados por coladeras al azar (sin pasar de AHOGADOS_MAX vivos): Zombie de verdad, en
# la escena (sin la escala del Sotano), alertas y tras de ti
func soltar_ahogados(n: int) -> void:
	if _termino or _player == null:
		return
	_ahogados = _ahogados.filter(func(z: Node) -> bool: return is_instance_valid(z))
	var lugares := coladeras()
	lugares.shuffle()
	for k in mini(n, AHOGADOS_MAX - _ahogados.size()):
		if lugares.is_empty():
			break
		var z := Zombie.new()
		z.jugador = _player as Player
		get_tree().current_scene.add_child(z)
		z.termino.connect(z.queue_free)
		z.despertar(lugares[k % lugares.size()], true)
		z.alerta = true
		_tenir(z)
		_ahogados.append(z)
	if not _ahogados.is_empty():
		Sonidos.tocar(self, "rugido", -10.0, 0.7)


# Gris azulado, mojado (el mismo shader que las variantes de Zombie)
func _tenir(z: Zombie) -> void:
	if _mat_ahogado == null:
		_mat_ahogado = ShaderMaterial.new()
		_mat_ahogado.shader = Zombie.JEFE_SHADER
		_mat_ahogado.set_shader_parameter("tint", AHOGADO_TINTE)
	for m in z.get("_mallas"):
		(m as MeshInstance3D).material_override = _mat_ahogado


func _matar_ahogados() -> void:
	for z in _ahogados:
		if is_instance_valid(z):
			z.queue_free()
	_ahogados.clear()


func subir_agua() -> void:
	if _agua == null:
		_agua = MeshInstance3D.new()
		var plano := PlaneMesh.new()
		plano.size = Vector2(16.0, 16.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.02, 0.025, 0.03, 0.92)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.08
		mat.metallic_specular = 1.0
		plano.material = mat
		_agua.mesh = plano
		add_child(_agua)
		_agua.position = Vector3(0, AGUA_DESDE, 0)
	_agua_sube = true
	if sotano:
		sotano.call("avisar", "¡Sube el agua negra! Busca dónde subirte.")


# Dos tarimas de lamina oxidada para escapar del agua
func _armar_tarimas() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.25, 0.15)
	mat.roughness = 0.8
	if ResourceLoader.exists("res://textures/sotano/oxido.png"):
		mat.albedo_texture = load("res://textures/sotano/oxido.png")
		mat.albedo_color = Color.WHITE
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for p: Vector3 in TARIMAS:
		var cuerpo := StaticBody3D.new()
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = TARIMA
		forma.shape = caja
		cuerpo.add_child(forma)
		var malla := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = TARIMA
		bm.material = mat
		malla.mesh = bm
		cuerpo.add_child(malla)
		add_child(cuerpo)
		cuerpo.position = p + Vector3.UP * TARIMA.y * 0.5


func _exit_tree() -> void:
	_matar_ahogados()
	if _env and not _env_antes.is_empty():
		_env.volumetric_fog_enabled = _env_antes["vf"]
		_env.volumetric_fog_density = _env_antes["vfd"]
		_env.volumetric_fog_albedo = _env_antes["vfa"]
	if _hud:
		_hud.queue_free()


func _armar_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 6
	get_tree().current_scene.add_child(_hud)
	var caja := VBoxContainer.new()
	caja.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	caja.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caja.grow_vertical = Control.GROW_DIRECTION_BEGIN
	caja.offset_bottom = -30.0
	_hud.add_child(caja)
	var nombre := Label.new()
	nombre.text = "LA DESAGUADORA"
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre.add_theme_font_size_override("font_size", 16)
	nombre.add_theme_color_override("font_color", Color(0.85, 0.8, 0.75))
	nombre.add_theme_color_override("font_outline_color", Color.BLACK)
	nombre.add_theme_constant_override("outline_size", 4)
	caja.add_child(nombre)
	_barra = ProgressBar.new()
	_barra.custom_minimum_size = Vector2(360, 10)
	_barra.show_percentage = false
	_barra.value = 100.0
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.05, 0.03, 0.03, 0.8)
	var lleno := StyleBoxFlat.new()
	lleno.bg_color = Color(0.45, 0.05, 0.06)
	_barra.add_theme_stylebox_override("background", fondo)
	_barra.add_theme_stylebox_override("fill", lleno)
	caja.add_child(_barra)


# La sirena al llegar: un tono que sube y baja lento (2 vueltas) y luego un zumbido grave en vuelta
func _sirena() -> void:
	var sirena := AudioStreamPlayer.new()
	sirena.stream = _tono_sirena()
	sirena.volume_db = -8.0
	add_child(sirena)
	sirena.play()
	sirena.finished.connect(func() -> void:
		sirena.queue_free()
		_zumbido = AudioStreamPlayer.new()
		_zumbido.stream = _tono_zumbido()
		_zumbido.volume_db = -14.0
		add_child(_zumbido)
		_zumbido.play())


static func _tono_sirena() -> AudioStreamWAV:
	var muestras := 22050
	var dura := 7.0
	var datos := PackedByteArray()
	datos.resize(int(muestras * dura) * 2)
	var fase := 0.0
	for i in int(muestras * dura):
		var t := float(i) / muestras
		var f := 260.0 + 340.0 * (0.5 - 0.5 * cos(t / dura * TAU * 2.0))
		fase += f / muestras
		var onda := sin(fase * TAU) * 0.6 + sin(fase * TAU * 2.0) * 0.2
		var envolvente := clampf(t * 2.0, 0.0, 1.0) * clampf((dura - t) * 1.5, 0.0, 1.0)
		datos.encode_s16(i * 2, int(onda * envolvente * 12000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = muestras
	wav.data = datos
	return wav


static func _tono_zumbido() -> AudioStreamWAV:
	var muestras := 22050
	var dura := 4.0
	var datos := PackedByteArray()
	datos.resize(int(muestras * dura) * 2)
	var azar := RandomNumberGenerator.new()
	azar.seed = 13
	for i in int(muestras * dura):
		var t := float(i) / muestras
		var onda := sin(t * TAU * 55.0) * 0.4 + sin(t * TAU * 82.5) * 0.2 + azar.randf_range(-0.08, 0.08)
		onda *= 0.7 + 0.3 * sin(t * TAU / dura)
		datos.encode_s16(i * 2, int(onda * 9000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = muestras
	wav.data = datos
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = int(muestras * dura)
	return wav


func _parpadear(luz: OmniLight3D) -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(0.5, 3.0)).timeout
		for k in randi_range(2, 6):
			if not is_inside_tree():
				return
			luz.visible = false
			await get_tree().create_timer(randf_range(0.03, 0.1)).timeout
			if not is_inside_tree():
				return
			luz.visible = true
			await get_tree().create_timer(randf_range(0.03, 0.12)).timeout
