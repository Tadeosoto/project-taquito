class_name FortalezasMapa
extends Node3D
## Lo que se pone en el mapa completo fuera de las bardas: las cinco defensas del tinaco (SitiosTinaco: solo
## el tinaco, sin barricada; Chava los ofrece de dia y la defensa es la escena defensa_tinaco), la torre de
## la antena (M4) y la enfermeria (M5). Las fortalezas amuralladas (Santa Mugre, La Gotera y Los Reservorios)
## son nodos MuroColonia leidos de resources/map/fortalezas.json (S9).
## Todo choca en la capa 1, como las casas.

const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")
const MODELO_TINACO := preload("res://models/props/tinaco/tinaco.scn")

const TINACO_ALTO := 2.8                # Barricada.TINACO_ALTO
const TINACO_PIEZAS := ["Tinaco_3er_capa", "Bomba_1", "Tapa"]   # Barricada.TINACO_PIEZAS

## La torre de la antena de Sofia (M4): no hay torre de luz de OSM a <=250 m de una reja, asi que se pone una a
## ~140 m afuera de la reja poniente de Santa Mugre, en un llano junto a la avenida. Un piloon de celosia hecho
## en codigo; la mision "antena_sofia" defiende su pie (MisionesMundo, `lugar = "torre_antena"`)
const TORRE_ANTENA := Vector2(-516.0, 348.0)
const TORRE_ALTO := 30.0
const TORRE_BASE := 3.0           # medio ancho abajo (m)
const TORRE_PUNTA := 0.7          # medio ancho arriba
const TORRE_NIVELES := 6
const TORRE_COLOR := Color(0.55, 0.57, 0.6)

## La enfermeria de "Al medico" (M5): una casa de la calle de abajo de Santa Mugre, a ~150 m de las dos rejas, con una cruz
## verde luminosa en la fachada (la casa es de casas_mapa.json; aqui solo se marca). `CLINICA_LLEGADA` es donde termina la
## escolta, en la banqueta frente a la casa
const CLINICA_CASA := Vector2(-297.6, 560.1)
const CLINICA_GIRO := 3.0        # rotacion_y de la casa: su frente mira hacia (sin, cos)
const CLINICA_FONDO := 12.0
const CLINICA_LLEGADA := Vector2(-296.3, 551.0)
const CRUZ_VERDE := Color(0.1, 0.9, 0.35)

func _ready() -> void:
	add_to_group("fortalezas")
	_torre()
	_clinica()
	for sitio: Dictionary in SitiosTinaco.SITIOS:
		_tinaco(sitio["pos"])


# --- Tinacos ---

func _tinaco(donde: Vector2) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "TinacoDefensa"
	cuerpo.position = Vector3(donde.x, 0.0, donde.y)
	add_child(cuerpo)
	var modelo := MODELO_TINACO.instantiate() as Node3D
	# El modelo trae tres tinacos: se deja uno completo (como Barricada._tinaco)
	for pieza in modelo.find_children("*", "Node3D"):
		if pieza.name.begins_with("Tinaco_") and pieza.get_parent().name == "Tinaco" and not pieza.name in TINACO_PIEZAS:
			pieza.get_parent().remove_child(pieza)
			pieza.queue_free()
	var caja := Barricada._caja_de(modelo)
	var escala := TINACO_ALTO / caja.size.y
	var sosten := Node3D.new()
	sosten.scale = Vector3.ONE * escala
	sosten.position = Vector3(-caja.get_center().x * escala, -caja.position.y * escala, -caja.get_center().z * escala)
	sosten.add_child(modelo)
	cuerpo.add_child(sosten)
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = maxf(caja.size.x, caja.size.z) * escala / 2.0
	cilindro.height = TINACO_ALTO
	forma.shape = cilindro
	forma.position.y = TINACO_ALTO / 2.0
	cuerpo.add_child(forma)


# --- La enfermeria ---

func _clinica() -> void:
	var frente := Vector2(sin(CLINICA_GIRO), cos(CLINICA_GIRO))
	var punto := CLINICA_CASA + frente * (CLINICA_FONDO / 2.0 + 0.45)
	var nodo := Node3D.new()
	nodo.name = "Enfermeria"
	nodo.position = Vector3(punto.x, 0.0, punto.y)
	nodo.rotation.y = atan2(frente.x, frente.y)   # +Z hacia la calle
	add_child(nodo)
	var verde := StandardMaterial3D.new()
	verde.albedo_color = CRUZ_VERDE
	verde.emission_enabled = true
	verde.emission = CRUZ_VERDE
	verde.emission_energy_multiplier = 2.2
	verde.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for tam in [Vector3(0.38, 1.5, 0.1), Vector3(1.5, 0.38, 0.1)]:
		var barra := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = tam
		caja.material = verde
		barra.mesh = caja
		barra.position = Vector3(0.0, 3.4, 0.0)
		barra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nodo.add_child(barra)
	var letrero := Label3D.new()
	letrero.text = "Enfermería"
	letrero.pixel_size = 0.006
	letrero.font_size = 48
	letrero.outline_size = 12
	letrero.modulate = Color(0.75, 1.0, 0.8)
	letrero.position = Vector3(0.0, 2.45, 0.1)
	letrero.visibility_range_end = 30.0
	nodo.add_child(letrero)
	var luz := OmniLight3D.new()
	luz.light_color = CRUZ_VERDE
	luz.light_energy = 1.6
	luz.omni_range = 12.0
	luz.position = Vector3(0.0, 3.2, 1.2)
	luz.shadow_enabled = false
	nodo.add_child(luz)


# --- La torre de la antena ---

func _torre() -> void:
	var nodo := Node3D.new()
	nodo.name = "TorreAntena"
	nodo.position = Vector3(TORRE_ANTENA.x, 0.0, TORRE_ANTENA.y)
	add_child(nodo)
	var barras: Array[Transform3D] = []   # cada una una caja unitaria estirada de a a b
	var nivel := func(j: int) -> float: return TORRE_ALTO * j / float(TORRE_NIVELES)
	var ancho := func(y: float) -> float: return lerpf(TORRE_BASE, TORRE_PUNTA, y / TORRE_ALTO)
	var esquinas := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for j in TORRE_NIVELES:
		var y0: float = nivel.call(j)
		var y1: float = nivel.call(j + 1)
		var w0: float = ancho.call(y0)
		var w1: float = ancho.call(y1)
		for k in 4:
			var a: Vector2 = esquinas[k]
			var b: Vector2 = esquinas[(k + 1) % 4]
			# Pata y aro del nivel de arriba
			barras.append(_barra(Vector3(a.x * w0, y0, a.y * w0), Vector3(a.x * w1, y1, a.y * w1), 0.22))
			barras.append(_barra(Vector3(a.x * w1, y1, a.y * w1), Vector3(b.x * w1, y1, b.y * w1), 0.12))
			# Una diagonal por cara
			barras.append(_barra(Vector3(a.x * w0, y0, a.y * w0), Vector3(b.x * w1, y1, b.y * w1), 0.1))
	# Dos brazos arriba
	for brazo in [[TORRE_ALTO - 1.6, 4.6], [TORRE_ALTO - 5.2, 3.6]]:
		barras.append(_barra(Vector3(-brazo[1], brazo[0], 0.0), Vector3(brazo[1], brazo[0], 0.0), 0.2))
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = caja
	multi.instance_count = barras.size()
	for i in barras.size():
		multi.set_instance_transform(i, barras[i])
	var malla := MultiMeshInstance3D.new()
	malla.multimesh = multi
	malla.material_override = _material(TORRE_COLOR)
	nodo.add_child(malla)
	# Choque: solo las cuatro patas de abajo
	for esquina: Vector2 in esquinas:
		_choque(nodo, Vector3(esquina.x * TORRE_BASE, 1.5, esquina.y * TORRE_BASE), Vector3(0.6, 3.0, 0.6))


# La transformacion de una caja unitaria que va de `a` a `b` con `grosor` de lado
static func _barra(a: Vector3, b: Vector3, grosor: float) -> Transform3D:
	var largo := a.distance_to(b)
	var dir := (b - a) / largo
	var arriba := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	var base := Basis.looking_at(dir, arriba)
	return Transform3D(base.scaled_local(Vector3(grosor, grosor, largo)), (a + b) / 2.0)


# --- Piezas ---

func _material(base: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PS1_SHADER
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("deterioro_modo", 2)
	material.set_shader_parameter("affine_enabled", false)
	material.set_shader_parameter("jitter_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	return material


func _choque(padre: Node3D, donde: Vector3, tam: Vector3) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.position = donde
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tam
	forma.shape = caja
	cuerpo.add_child(forma)
	padre.add_child(cuerpo)
