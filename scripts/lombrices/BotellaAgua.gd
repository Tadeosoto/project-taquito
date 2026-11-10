class_name BotellaAgua
extends MeshInstance3D

# La botella de agua de PET (JJ): para armar la bocina encintada (BocinaEncintada, receta de
# resources/recetas/bocina_encintada.tres). Acostada en X con la boca hacia +X: el agua adentro
# (llena de abajo), la etiqueta blanca con franja azul, la tapa azul y el plastico transparente
# encima. El origen es el centro del cuerpo, sin el cuello. Como la palomita, la malla se pone en
# _init para que InventoryItemData.crear_modelo la mida (scenes/botella_agua.tscn).

const RADIO := 0.036
const LARGO := 0.2           # m del cuerpo, sin el cuello
const CUELLO := 0.035        # m del hombro a la boca
const TAPA_LARGO := 0.014
const LLENA := 0.82          # del cuerpo con agua
const LADOS := 10
const COLOR_AGUA := Color(0.45, 0.7, 0.95)
const COLOR_PET := Color(0.8, 0.92, 1.0, 0.35)
const COLOR_TAPA := Color(0.15, 0.35, 0.85)
const COLOR_ETIQUETA := Color(0.95, 0.96, 0.98)
const COLOR_ETIQUETA_FRANJA := Color(0.2, 0.5, 0.9)

static var _malla: ArrayMesh


func _init() -> void:
	mesh = malla()


static func malla() -> ArrayMesh:
	if _malla:
		return _malla
	_malla = ArrayMesh.new()
	var acostado := Basis(Vector3.BACK, PI / 2.0)   # el eje de los cilindros (Y) pasa a X
	var frente := LARGO * 0.5
	# El agua, por dentro; acostada, el agua llena de abajo: se aplana arriba
	var agua := SurfaceTool.new()
	agua.begin(Mesh.PRIMITIVE_TRIANGLES)
	var liquido := CylinderMesh.new()
	liquido.top_radius = RADIO * 0.92
	liquido.bottom_radius = RADIO * 0.92
	liquido.height = LARGO * 0.97
	liquido.radial_segments = LADOS
	liquido.rings = 1
	var aplana := Basis().scaled(Vector3(1.0, LLENA, 1.0))
	agua.append_from(liquido, 0, Transform3D(aplana * acostado, Vector3(0.0, -RADIO * (1.0 - LLENA) * 0.9, 0.0)))
	agua.commit(_malla)
	_malla.surface_set_material(0, Bocina._material(COLOR_AGUA))
	# La etiqueta, una franja alrededor a media botella
	var etiqueta := SurfaceTool.new()
	etiqueta.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anillo := CylinderMesh.new()
	anillo.top_radius = RADIO * 1.01
	anillo.bottom_radius = RADIO * 1.01
	anillo.height = LARGO * 0.4
	anillo.radial_segments = LADOS
	anillo.rings = 1
	anillo.cap_top = false
	anillo.cap_bottom = false
	etiqueta.append_from(anillo, 0, Transform3D(acostado, Vector3(LARGO * 0.05, 0.0, 0.0)))
	etiqueta.commit(_malla)
	var material_etiqueta := Bocina._material(Color.WHITE)
	material_etiqueta.set_shader_parameter("albedo_texture", _textura_etiqueta())
	_malla.surface_set_material(1, material_etiqueta)
	# La tapa azul en la boca
	var tapa := SurfaceTool.new()
	tapa.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rosca := CylinderMesh.new()
	rosca.top_radius = RADIO * 0.42
	rosca.bottom_radius = RADIO * 0.42
	rosca.height = TAPA_LARGO
	rosca.radial_segments = 8
	rosca.rings = 1
	tapa.append_from(rosca, 0, Transform3D(acostado, Vector3(frente + CUELLO + TAPA_LARGO * 0.5, 0.0, 0.0)))
	tapa.commit(_malla)
	_malla.surface_set_material(2, Bocina._material(COLOR_TAPA))
	# El PET: el cuerpo, el hombro y el cuello, transparente encima del agua
	var pet := SurfaceTool.new()
	pet.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cuerpo := CylinderMesh.new()
	cuerpo.top_radius = RADIO
	cuerpo.bottom_radius = RADIO
	cuerpo.height = LARGO
	cuerpo.radial_segments = LADOS
	cuerpo.rings = 2
	cuerpo.cap_top = false
	pet.append_from(cuerpo, 0, Transform3D(acostado, Vector3.ZERO))
	var hombro := CylinderMesh.new()
	hombro.top_radius = RADIO * 0.4
	hombro.bottom_radius = RADIO
	hombro.height = CUELLO
	hombro.radial_segments = LADOS
	hombro.rings = 1
	hombro.cap_top = false
	hombro.cap_bottom = false
	pet.append_from(hombro, 0, Transform3D(acostado, Vector3(frente + CUELLO * 0.5, 0.0, 0.0)))
	pet.commit(_malla)
	var plastico := StandardMaterial3D.new()
	plastico.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plastico.albedo_color = COLOR_PET
	plastico.roughness = 0.2
	plastico.metallic_specular = 0.8
	plastico.cull_mode = BaseMaterial3D.CULL_DISABLED
	_malla.surface_set_material(3, plastico)
	return _malla


# La etiqueta: blanca con una franja azul y unas gotas, sin marca
static func _textura_etiqueta() -> ImageTexture:
	var imagen := Image.create(32, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		for x in 32:
			var color := COLOR_ETIQUETA
			if y >= 6 and y <= 9:
				color = COLOR_ETIQUETA_FRANJA
			elif (x % 8 == 3) and (y == 3 or y == 12):
				color = COLOR_ETIQUETA_FRANJA
			imagen.set_pixel(x, y, color)
	return ImageTexture.create_from_image(imagen)
