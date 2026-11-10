class_name BotellaMolotov
extends MeshInstance3D

# La botella de la molotov (JJ, como su foto de referencia): vidrio transparente con una etiqueta
# vieja de licor y el cuello rojo. En tres etapas (Inventory: tomas, combinas, combinas): VACIA (la
# que te queda del refresco o la caguama), GASOLINA (con liquido naranja adentro) y MOLOTOV (ademas
# el trapo metido en la boca, que sale, se dobla y cuelga por un lado). Parada en Y, el origen en
# el centro de la base. La malla se pone en _init y al cambiar `etapa` (las escenas
# scenes/botella_vacia.tscn, botella_gasolina.tscn y molotov.tscn la ponen al instanciarse, antes de
# que InventoryItemData.crear_modelo la mida). Tambien es lo que vuela (Arrojadizo) y lo que traes
# en la mano (Lanzador).

enum { VACIA, GASOLINA, MOLOTOV }

const RADIO := 0.038
const LADOS := 12
# El contorno del vidrio (radio, altura) de abajo hacia la boca
const PERFIL := [Vector2(0.0, 0.006), Vector2(0.035, 0.0), Vector2(0.038, 0.005), Vector2(0.038, 0.17),
		Vector2(0.035, 0.19), Vector2(0.025, 0.208), Vector2(0.016, 0.228), Vector2(0.0135, 0.25),
		Vector2(0.0135, 0.29), Vector2(0.0165, 0.294), Vector2(0.0165, 0.304), Vector2(0.012, 0.308)]
const LLENA := 0.14            # m de alto de la gasolina
const ETIQUETA := Vector2(0.04, 0.13)    # de que altura a cual
const CUELLO_ROJO := Vector2(0.232, 0.29)
# El trapo: por donde pasa (x, y), de adentro del cuello a la punta que cuelga
const TRAPO := [Vector2(0.0, 0.26), Vector2(0.0, 0.31), Vector2(0.006, 0.333), Vector2(0.022, 0.343),
		Vector2(0.036, 0.332), Vector2(0.043, 0.3), Vector2(0.046, 0.25), Vector2(0.044, 0.2), Vector2(0.047, 0.17)]
const TRAPO_ANCHO := 0.03
const TRAPO_GRUESO := 0.009
const COLOR_VIDRIO := Color(0.8, 0.95, 0.85, 0.22)
const COLOR_GASOLINA := Color(1.0, 0.42, 0.0)
const COLOR_ROJO := Color(0.58, 0.07, 0.05)
const COLOR_PAPEL := Color(0.9, 0.86, 0.74)
const COLOR_TRAPO := Color(0.42, 0.4, 0.37)
# En la mano: acostada en X (el pulgar), agarrada del cuerpo con la boca saliendo por el pulgar
const EN_MANO := Vector3(-0.09, 0.08, 0.02 + RADIO)
const GIRO_MANO := Vector3(0.0, 0.0, -90.0)
# La punta de arriba del trapo, donde va la lumbre al volar
const MECHA := Vector3(0.022, 0.343, 0.0)

static var _mallas := {}

@export_enum("Vacía", "Gasolina", "Molotov") var etapa: int = VACIA:
	set(valor):
		etapa = valor
		mesh = malla(etapa)


func _init() -> void:
	mesh = malla(etapa)


static func malla(cual: int) -> ArrayMesh:
	if _mallas.has(cual):
		return _mallas[cual]
	var nueva := ArrayMesh.new()
	if cual >= GASOLINA:
		var liquido := SurfaceTool.new()
		liquido.begin(Mesh.PRIMITIVE_TRIANGLES)
		var r := RADIO * 0.9
		_torno(liquido, [Vector2(0.0, 0.008), Vector2(r, 0.008), Vector2(r, LLENA), Vector2(0.0, LLENA)])
		_agregar(nueva, liquido, _material(COLOR_GASOLINA))
	# La etiqueta y el cuello rojo, pegados por fuera del vidrio
	var etiqueta := SurfaceTool.new()
	etiqueta.begin(Mesh.PRIMITIVE_TRIANGLES)
	_torno(etiqueta, [Vector2(RADIO * 1.03, ETIQUETA.x), Vector2(RADIO * 1.03, ETIQUETA.y)], true)
	var papel := _material(Color.WHITE)
	papel.set_shader_parameter("albedo_texture", _textura_etiqueta())
	_agregar(nueva, etiqueta, papel)
	var cuello := SurfaceTool.new()
	cuello.begin(Mesh.PRIMITIVE_TRIANGLES)
	_torno(cuello, [Vector2(0.0152, CUELLO_ROJO.x), Vector2(0.0152, CUELLO_ROJO.y)])
	_agregar(nueva, cuello, _material(COLOR_ROJO))
	if cual == MOLOTOV:
		var trapo := SurfaceTool.new()
		trapo.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tira_trapo(trapo)
		var tela := _material(Color.WHITE)
		tela.set_shader_parameter("albedo_texture", _textura_trapo())
		_agregar(nueva, trapo, tela)
	# El vidrio al final, transparente encima de lo demas
	var vidrio := SurfaceTool.new()
	vidrio.begin(Mesh.PRIMITIVE_TRIANGLES)
	_torno(vidrio, PERFIL)
	var cristal := StandardMaterial3D.new()
	cristal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cristal.albedo_color = COLOR_VIDRIO
	# Sin luz: con brillo y reflejos el vidrio deslavaba de blanco la gasolina y la etiqueta
	cristal.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cristal.cull_mode = BaseMaterial3D.CULL_DISABLED
	_agregar(nueva, vidrio, cristal)
	_mallas[cual] = nueva
	return nueva


# Como los de la bocina, pero sin el brinco de vertices: la etiqueta y el cuello van a un pelo del
# vidrio y con el brinco quedaban detras de el, deslavados
static func _material(color: Color) -> ShaderMaterial:
	var material := Bocina._material(color)
	material.set_shader_parameter("jitter_enabled", false)
	return material


static func _agregar(malla_: ArrayMesh, st: SurfaceTool, material: Material) -> void:
	st.generate_normals()
	st.commit(malla_)
	malla_.surface_set_material(malla_.get_surface_count() - 1, material)


# Gira `perfil` (radio, altura) alrededor de Y. Con `uv` la textura da una vuelta en U y va de
# arriba (V 0) a abajo (V 1)
static func _torno(st: SurfaceTool, perfil: Array, uv := false) -> void:
	var y0: float = perfil[0].y
	var y1: float = perfil[-1].y
	for i in perfil.size() - 1:
		var a: Vector2 = perfil[i]
		var b: Vector2 = perfil[i + 1]
		for k in LADOS:
			var u0 := float(k) / LADOS
			var u1 := float(k + 1) / LADOS
			var d0 := Vector3(cos(u0 * TAU), 0.0, -sin(u0 * TAU))
			var d1 := Vector3(cos(u1 * TAU), 0.0, -sin(u1 * TAU))
			var p := [d0 * a.x + Vector3.UP * a.y, d1 * a.x + Vector3.UP * a.y,
					d1 * b.x + Vector3.UP * b.y, d0 * b.x + Vector3.UP * b.y]
			var t := [Vector2(u0, inverse_lerp(y1, y0, a.y)), Vector2(u1, inverse_lerp(y1, y0, a.y)),
					Vector2(u1, inverse_lerp(y1, y0, b.y)), Vector2(u0, inverse_lerp(y1, y0, b.y))]
			for j: int in [0, 1, 2, 0, 2, 3]:
				if uv:
					st.set_uv(t[j])
				st.add_vertex(p[j])


# El trapo: una tira gruesa por TRAPO, un poco mas ancha y chueca hacia la punta
static func _tira_trapo(st: SurfaceTool) -> void:
	var anillos := []
	for i in TRAPO.size():
		var p: Vector2 = TRAPO[i]
		var antes: Vector2 = TRAPO[maxi(i - 1, 0)]
		var despues: Vector2 = TRAPO[mini(i + 1, TRAPO.size() - 1)]
		var tangente := (despues - antes).normalized()
		var normal := Vector3(-tangente.y, tangente.x, 0.0) * TRAPO_GRUESO * 0.5
		var f := float(i) / (TRAPO.size() - 1)
		var ancho := Vector3(0.0, 0.0, TRAPO_ANCHO * (1.0 + f * 0.35) * 0.5)
		var centro := Vector3(p.x, p.y, sin(f * 5.0) * 0.004)
		anillos.append([centro + normal + ancho, centro + normal - ancho, centro - normal - ancho, centro - normal + ancho])
	for i in anillos.size() - 1:
		var v0: float = float(i) / (anillos.size() - 1)
		var v1: float = float(i + 1) / (anillos.size() - 1)
		for lado in 4:
			var a: Vector3 = anillos[i][lado]
			var b: Vector3 = anillos[i][(lado + 1) % 4]
			var c: Vector3 = anillos[i + 1][(lado + 1) % 4]
			var d: Vector3 = anillos[i + 1][lado]
			var u := lado * 0.25
			for par: Array in [[a, Vector2(u, v0)], [b, Vector2(u + 0.25, v0)], [c, Vector2(u + 0.25, v1)],
					[a, Vector2(u, v0)], [c, Vector2(u + 0.25, v1)], [d, Vector2(u, v1)]]:
				st.set_uv(par[1])
				st.add_vertex(par[0])
	# La punta que cuelga, cerrada
	var punta: Array = anillos[-1]
	for j: int in [0, 1, 2, 0, 2, 3]:
		st.set_uv(Vector2(0.5, 1.0))
		st.add_vertex(punta[j])


# Una etiqueta vieja de licor sin marca: franja roja arriba con una corona crema, papel crema con
# unas rayas de letras, un sello rojo abajo y manchas
static func _textura_etiqueta() -> ImageTexture:
	var imagen := Image.create(48, 24, false, Image.FORMAT_RGB8)
	var ruido := RandomNumberGenerator.new()
	ruido.seed = 40
	for y in 24:
		for x in 48:
			var color := COLOR_PAPEL
			# La etiqueta solo da media vuelta; atras se ve el vidrio (aqui, papel mas oscuro)
			if x >= 24:
				color = COLOR_PAPEL.darkened(0.15)
			elif y < 8:
				color = COLOR_ROJO
				if y >= 2 and y <= 5 and x >= 9 and x <= 14 and (y > 3 or x % 2 == 1):
					color = COLOR_PAPEL
			elif (y == 11 or y == 13) and x >= 4 and x <= 19 and x % 3 != 0:
				color = COLOR_ROJO.darkened(0.3)
			elif y >= 16 and y <= 20 and Vector2(x, y).distance_to(Vector2(11.5, 18)) < 2.6:
				color = COLOR_ROJO
			color = color.darkened(ruido.randf() * 0.12)
			imagen.set_pixel(x, y, color)
	return ImageTexture.create_from_image(imagen)


static func _textura_trapo() -> ImageTexture:
	var imagen := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var ruido := RandomNumberGenerator.new()
	ruido.seed = 7
	for y in 16:
		for x in 16:
			var color := COLOR_TRAPO.darkened(ruido.randf() * 0.25)
			if y % 4 == 0:
				color = color.darkened(0.1)
			imagen.set_pixel(x, y, color)
	return ImageTexture.create_from_image(imagen)
