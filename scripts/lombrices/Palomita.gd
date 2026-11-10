class_name Palomita
extends MeshInstance3D

# La palomita: el cohete de papel doblado en triangulo con su mecha, la granada aturdidora.
# Se avienta con el Lanzador (tecla 3, InventoryItemData.arrojar 3) como la molotov, y al caer
# truena y aturde a los zombis (Arrojadizo.PALOMITA). Como nodo es solo la malla, puesta en
# _init para que InventoryItemData.crear_modelo la alcance a medir (scenes/palomita.tscn).
# La malla (malla) es una para todas, como Cargador.malla: un triangulo de papel de revista
# inflado en medio (la polvora) y aplanado en las orillas, con la mecha amarilla saliendo
# de la mitad del lado largo. El triangulo esta en XY con la punta hacia +Y y lo gordo en Z;
# el origen es el centro del triangulo.

# El doble de una de verdad (JJ): de 11 cm no se leia en la mano
const ANCHO := 0.26          # m del lado largo (la base)
const ALTO := 0.13           # m de la base a la punta
const GRUESO := 0.06         # m en medio, de cara a cara
const PASOS := 6             # subdivisiones de cada lado: con menos se ve tienda de campana
const MECHA_LARGO := 0.08    # m
const MECHA_GRUESO := 0.007  # m
const COLOR_MECHA := Color(0.95, 0.82, 0.12)
# Tiras de papel de revista, como las de verdad: crema, rosa mexicano, lila y cafe
const TIRAS := [Color(0.92, 0.9, 0.84), Color(0.88, 0.28, 0.5), Color(0.55, 0.53, 0.7),
		Color(0.92, 0.9, 0.84), Color(0.42, 0.36, 0.32), Color(0.22, 0.2, 0.42)]
const SHADER := preload("res://shaders/ps1_combined.gdshader")
# En la mano (RightHand: X el pulgar, Y los dedos, Z la palma, Player.ARMA_GIRO): agarrada de
# una esquina de la base dentro del puño y volteada (GIRO_MANO) para que lo demas salga hacia -X;
# hacia el pulgar se metia en la pierna. En m del hueso, sin su escala
const EN_MANO := Vector3(-ANCHO * 0.5, 0.08 + ALTO / 3.0, 0.03)
const GIRO_MANO := Vector3(0.0, 180.0, 0.0)

static var _malla: ArrayMesh


func _init() -> void:
	mesh = malla()


static func malla() -> ArrayMesh:
	if _malla:
		return _malla
	_malla = ArrayMesh.new()
	var papel := SurfaceTool.new()
	papel.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector2(-ANCHO * 0.5, -ALTO / 3.0)
	var b := Vector2(ANCHO * 0.5, -ALTO / 3.0)
	var c := Vector2(0.0, ALTO * 2.0 / 3.0)
	for lado in [1.0, -1.0]:
		for i in PASOS:
			for j in PASOS - i:
				_tri(papel, lado, a, b, c, Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, j + 1))
				if j < PASOS - i - 1:
					_tri(papel, lado, a, b, c, Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1))
	papel.generate_normals()
	papel.commit(_malla)
	var material := _material(Color.WHITE)
	material.set_shader_parameter("albedo_texture", _textura())
	_malla.surface_set_material(0, material)
	# La mecha: de la mitad de la base hacia abajo, tantito chueca
	var mecha := SurfaceTool.new()
	mecha.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tubo := CylinderMesh.new()
	tubo.top_radius = MECHA_GRUESO * 0.5
	tubo.bottom_radius = MECHA_GRUESO * 0.5
	tubo.height = MECHA_LARGO
	tubo.radial_segments = 4
	tubo.rings = 1
	var giro := Basis(Vector3.BACK, deg_to_rad(8.0))
	mecha.append_from(tubo, 0, Transform3D(giro, Vector3(0.0, a.y, 0.0) + giro * Vector3(0.0, -MECHA_LARGO * 0.45, 0.0)))
	mecha.commit(_malla)
	_malla.surface_set_material(1, _material(COLOR_MECHA))
	return _malla


# Un triangulo de la cara `lado` (+1 adelante, -1 atras) con los puntos de la reja (i, j)
static func _tri(st: SurfaceTool, lado: float, a: Vector2, b: Vector2, c: Vector2, p: Vector2i, q: Vector2i, r: Vector2i) -> void:
	var puntos := [p, q, r] if lado > 0.0 else [p, r, q]
	for k: Vector2i in puntos:
		var u := float(k.x) / PASOS
		var v := float(k.y) / PASOS
		var w := 1.0 - u - v
		var plano := a * w + b * u + c * v
		# Lo gordo crece con la distancia a la orilla mas cercana: en las orillas es papel
		var orilla := clampf(minf(minf(u, v), w) * 3.0, 0.0, 1.0)
		var z := lado * GRUESO * 0.5 * pow(orilla, 0.55)
		st.set_uv(Vector2(plano.x / ANCHO + 0.5 + (0.37 if lado < 0.0 else 0.0), 0.5 - plano.y / ANCHO))
		st.add_vertex(Vector3(plano.x, plano.y, z))


# Las tiras en diagonal, de pocos pixeles como todo lo PS1
static func _textura() -> ImageTexture:
	var imagen := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			var tira := int(floor((x + y * 0.7) / 6.0)) % TIRAS.size()
			var color: Color = TIRAS[tira]
			# Tantito de grano de impresion
			color = color.darkened(0.06 if (x * 7 + y * 13) % 5 == 0 else 0.0)
			imagen.set_pixel(x, y, color)
	return ImageTexture.create_from_image(imagen)


static func _material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("affine_enabled", false)
	# El bamboleo va en una reja de 2.5 cm: a una cosa de este tamaño la deshacia
	material.set_shader_parameter("wobble_enabled", false)
	return material
