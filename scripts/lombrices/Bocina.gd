class_name Bocina
extends MeshInstance3D

# La bocina bluetooth: el señuelo que se avienta y atrae a los zombis con musica saturada (JJ).
# Por ahora el modelo y sus ondas (ondas()); el arma viene despues. Como la palomita, el nodo es
# solo la malla puesta en _init. La malla es una para todas: un cilindro acostado de rejilla de
# tela oscura, con tapas de hule de color en las puntas (con su radiador pasivo), una tira de hule
# arriba con tres botones y un foquito azul. Lo largo es X; arriba, Y; el origen, el centro.

const LARGO := 0.26          # m: mas grande que una de verdad (~18 cm), para que se lea como la palomita
const RADIO := 0.05          # m
const LADOS := 10            # del cilindro: PS1
const COLOR_HULE := Color(0.88, 0.22, 0.2)
const COLOR_RADIADOR := Color(0.18, 0.18, 0.2)
const COLOR_BOTON := Color(0.95, 0.93, 0.88)
const COLOR_FOCO := Color(0.3, 0.6, 1.0)
const COLOR_TELA := Color(0.16, 0.17, 0.19)
const COLOR_HOYO := Color(0.06, 0.06, 0.07)
const TAPA := 0.014          # m de grueso de cada tapa de hule
const SHADER := preload("res://shaders/ps1_combined.gdshader")
const SHADER_ONDAS := preload("res://shaders/ondas_bocina.gdshader")
const SHADER_AIRE := preload("res://shaders/aire_bocina.gdshader")
const ONDAS_TAMANO := 2.6    # m de lado de los aros del piso
const AIRE_TAMANO := 2.2     # m del cuadro del aire que tiembla
const AIRE_ALTO := 0.25      # m sobre el piso del centro del aire
# En la mano (RightHand: X el pulgar, Y los dedos, Z la palma, Player.ARMA_GIRO): agarrada de
# en medio como una lata, lo largo hacia el pulgar y recargada en la palma. En m del hueso, sin
# su escala
const EN_MANO := Vector3(0.0, 0.08, 0.02 + RADIO)
const GIRO_MANO := Vector3.ZERO

static var _malla: ArrayMesh
static var _material_ondas: ShaderMaterial
static var _material_aire: ShaderMaterial


func _init() -> void:
	mesh = malla()


static func malla() -> ArrayMesh:
	if _malla:
		return _malla
	_malla = ArrayMesh.new()
	var acostado := Basis(Vector3.BACK, PI / 2.0)   # el eje del cilindro (Y) pasa a X
	# La rejilla de tela
	var tela := SurfaceTool.new()
	tela.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cuerpo := CylinderMesh.new()
	cuerpo.top_radius = RADIO
	cuerpo.bottom_radius = RADIO
	cuerpo.height = LARGO - TAPA * 2.0
	cuerpo.radial_segments = LADOS
	cuerpo.rings = 1
	cuerpo.cap_top = false
	cuerpo.cap_bottom = false
	tela.append_from(cuerpo, 0, Transform3D(acostado, Vector3.ZERO))
	tela.commit(_malla)
	var material_tela := _material(Color.WHITE)
	material_tela.set_shader_parameter("albedo_texture", _textura_tela())
	_malla.surface_set_material(0, material_tela)
	# Las tapas de hule y la tira de arriba
	var hule := SurfaceTool.new()
	hule.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lado in [-1.0, 1.0]:
		var tapa := CylinderMesh.new()
		tapa.top_radius = RADIO * 1.06
		tapa.bottom_radius = RADIO * 1.06
		tapa.height = TAPA
		tapa.radial_segments = LADOS
		tapa.rings = 1
		hule.append_from(tapa, 0, Transform3D(acostado, Vector3(lado * (LARGO - TAPA) * 0.5, 0.0, 0.0)))
	var tira := BoxMesh.new()
	tira.size = Vector3(LARGO * 0.62, RADIO * 0.18, RADIO * 0.62)
	hule.append_from(tira, 0, Transform3D(Basis(), Vector3(0.0, RADIO * 0.95, 0.0)))
	hule.commit(_malla)
	_malla.surface_set_material(1, _material(COLOR_HULE))
	# Los radiadores pasivos, un disco oscuro en cada punta
	var radiador := SurfaceTool.new()
	radiador.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lado in [-1.0, 1.0]:
		var disco := CylinderMesh.new()
		disco.top_radius = RADIO * 0.68
		disco.bottom_radius = RADIO * 0.68
		disco.height = 0.004
		disco.radial_segments = LADOS
		disco.rings = 1
		radiador.append_from(disco, 0, Transform3D(acostado, Vector3(lado * (LARGO * 0.5 + 0.001), 0.0, 0.0)))
	radiador.commit(_malla)
	_malla.surface_set_material(2, _material(COLOR_RADIADOR))
	# Los botones (-, play, +) sobre la tira
	var botones := SurfaceTool.new()
	botones.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var boton := BoxMesh.new()
		boton.size = Vector3(RADIO * 0.32, RADIO * 0.08, RADIO * 0.32)
		botones.append_from(boton, 0, Transform3D(Basis(), Vector3((k - 1) * RADIO * 0.6, RADIO * 1.07, 0.0)))
	botones.commit(_malla)
	_malla.surface_set_material(3, _material(COLOR_BOTON))
	# El foquito: sin sombra, siempre prendido
	var foco := SurfaceTool.new()
	foco.begin(Mesh.PRIMITIVE_TRIANGLES)
	var punto := BoxMesh.new()
	punto.size = Vector3(RADIO * 0.12, RADIO * 0.06, RADIO * 0.12)
	foco.append_from(punto, 0, Transform3D(Basis(), Vector3(RADIO * 1.4, RADIO * 1.06, 0.0)))
	foco.commit(_malla)
	var material_foco := StandardMaterial3D.new()
	material_foco.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_foco.albedo_color = COLOR_FOCO
	_malla.surface_set_material(4, material_foco)
	return _malla


# La tela de la rejilla: hoyitos en reja de pocos pixeles
static func _textura_tela() -> ImageTexture:
	# X le da la vuelta y Y va a lo largo: casi igual de pixeles por metro en las dos, o salen rayas
	var imagen := Image.create(40, 30, false, Image.FORMAT_RGB8)
	for y in 30:
		for x in 40:
			var hoyo := x % 2 == 0 and (y + (x / 2) % 2) % 2 == 0
			imagen.set_pixel(x, y, COLOR_HOYO if hoyo else COLOR_TELA)
	return ImageTexture.create_from_image(imagen)


static func _material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("affine_enabled", false)
	# El bamboleo va en una reja de 2.5 cm: a una cosa de este tamaño la deshacia (Palomita)
	material.set_shader_parameter("wobble_enabled", false)
	return material


# Las ondas de sonido que suelta mientras suena (JJ escogio dos de cuatro): aros pixelados que
# crecen en el piso desde la bocina (shaders/ondas_bocina.gdshader) y, encima, el aire que tiembla
# en ondas (shaders/aire_bocina.gdshader). El nodo va en el piso, debajo de la bocina. Un material
# de cada uno para todas; `desfase` separa a una bocina de otra
static func ondas(desfase := 0.0) -> Node3D:
	if _material_ondas == null:
		_material_ondas = ShaderMaterial.new()
		_material_ondas.shader = SHADER_ONDAS
		_material_aire = ShaderMaterial.new()
		_material_aire.shader = SHADER_AIRE
	var ondas_nodo := Node3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2.ONE * ONDAS_TAMANO
	var piso := MeshInstance3D.new()
	piso.mesh = plano
	piso.position.y = 0.01
	piso.material_override = _material_ondas
	piso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piso.set_instance_shader_parameter("desfase", desfase)
	ondas_nodo.add_child(piso)
	var cuadro := QuadMesh.new()
	cuadro.size = Vector2.ONE * AIRE_TAMANO
	var aire := MeshInstance3D.new()
	aire.mesh = cuadro
	aire.position.y = AIRE_ALTO
	aire.material_override = _material_aire
	aire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aire.set_instance_shader_parameter("desfase", desfase)
	ondas_nodo.add_child(aire)
	return ondas_nodo
