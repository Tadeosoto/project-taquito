@tool
class_name Trompo
extends Node3D

# Trompo de pastor: la carne torneada en una varilla (mas ancha arriba, quemada por
# fuera), la pina arriba, la base y, detras (+Z), la parrilla vertical encendida. La
# carne gira despacio en el juego. El origen es el centro de la base, sobre la cubierta.

const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")
const ANILLOS := 12
const LADOS := 12
# Carnes distintas que se tornean (la semilla escoge una): tornear es lo que mas
# tarda (~2 ms en GDScript) y en el mapa hay un trompo por taqueria y puesto
const VARIANTES := 4

static var _carnes := {}   # [alto, radio, variante] -> ArrayMesh
# El cuadro del humo con su material, compartido (Refrigerador.gd explica por que)
static var _cuadro_humo: QuadMesh

@export var alto := 0.58:
	set(valor):
		alto = valor
		_reconstruir()
@export var radio := 0.15:
	set(valor):
		radio = valor
		_reconstruir()
# Vueltas por segundo
@export var giro := 0.08
@export var semilla := 0:
	set(valor):
		semilla = valor
		_reconstruir()

var _partes: Node3D
var _carne: Node3D


func _ready() -> void:
	_reconstruir()


func _process(delta: float) -> void:
	if _carne and not Engine.is_editor_hint():
		_carne.rotate_y(TAU * giro * delta)


func _reconstruir() -> void:
	if not is_inside_tree():
		return
	if _partes:
		_partes.queue_free()
	_partes = Node3D.new()
	add_child(_partes, false, Node.INTERNAL_MODE_FRONT)
	var metal := _material(Color(0.6, 0.6, 0.62), 4)
	var base := 0.06
	_cilindro(0.16, 0.18, base, Vector3(0, base / 2, 0), metal, _partes)
	_cilindro(0.008, 0.008, alto + 0.35, Vector3(0, base + (alto + 0.35) / 2, 0), metal, _partes)
	_carne = Node3D.new()
	_carne.position.y = base + 0.04
	_partes.add_child(_carne)
	var carne := MeshInstance3D.new()
	var clave := [alto, radio, absi(semilla) % VARIANTES]
	if not _carnes.has(clave):
		_carnes[clave] = _torno(clave[2])
	carne.mesh = _carnes[clave]
	_carne.add_child(carne)
	# Pina: cilindro amarillo con su corona de hojas
	var pina := alto + 0.04
	_cilindro(0.045, 0.05, 0.09, Vector3(0, pina, 0), _material(Color(0.85, 0.7, 0.2), 0), _carne)
	var hoja := _material(Color(0.25, 0.45, 0.15), 0)
	for i in 5:
		var malla := BoxMesh.new()
		malla.size = Vector3(0.015, 0.09, 0.005)
		malla.material = hoja
		var h := MeshInstance3D.new()
		h.mesh = malla
		h.position = Vector3(0, pina + 0.08, 0)
		h.rotation = Vector3(0.35, TAU * i / 5.0, 0)
		_carne.add_child(h)
	# Parrilla: lamina con la cara al trompo al rojo
	var parrilla := Vector3(0.36, alto + 0.05, 0.05)
	var z := radio + 0.12
	var lamina := MeshInstance3D.new()
	lamina.mesh = BoxMesh.new()
	(lamina.mesh as BoxMesh).size = parrilla
	(lamina.mesh as BoxMesh).material = _material(Color(0.32, 0.32, 0.34), 4)
	lamina.position = Vector3(0, base + parrilla.y / 2, z)
	_partes.add_child(lamina)
	var brasa := _material(Color(1.0, 0.45, 0.12), 0)
	brasa.set_shader_parameter("sin_sombra", true)
	brasa.set_shader_parameter("deterioro_modo", 4)
	brasa.set_shader_parameter("desgaste", 0.4)
	for i in 4:
		var tira := MeshInstance3D.new()
		tira.mesh = BoxMesh.new()
		(tira.mesh as BoxMesh).size = Vector3(parrilla.x - 0.06, 0.035, 0.005)
		(tira.mesh as BoxMesh).material = brasa
		tira.position = Vector3(0, base + 0.06 + (parrilla.y - 0.1) * i / 3.0, z - parrilla.z / 2 - 0.003)
		_partes.add_child(tira)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.55, 0.25)
	luz.light_energy = 0.6
	luz.omni_range = 0.9
	luz.position = Vector3(0, base + alto * 0.5, z - 0.1)
	_partes.add_child(luz)
	# Humo de la carne y de la parrilla (no gira con la carne)
	var humo := Trompo.humo(Vector3(radio + 0.08, alto * 0.4, radio + 0.08), 36)
	humo.position = Vector3(0, base + alto * 0.6, z * 0.5)
	_partes.add_child(humo)


# La carne: anillos de radio que crece hacia arriba (ahi se ponen las capas grandes) y
# se cierra en las puntas; color rojo pastor con quemado oscuro y franjas de grasa
func _torno(variante: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = variante
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anillos: Array = []
	for a in ANILLOS + 1:
		var t := float(a) / ANILLOS
		var r := radio * (0.55 + 0.45 * t)
		if a == 0 or a == ANILLOS:
			r *= 0.55
		var vuelta: Array = []
		for l in LADOS:
			var tono := Color(0.95, 0.3, 0.06).lerp(Color(0.4, 0.12, 0.04), rng.randf() * 0.6)
			if rng.randf() < 0.15:
				tono = Color(0.85, 0.55, 0.3)
			vuelta.append([r * (0.9 + 0.2 * rng.randf()), tono])
		anillos.append([t * alto, vuelta])
	for a in ANILLOS:
		for l in LADOS:
			var esquinas := []
			for d in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var anillo: Array = anillos[a + d[0]]
				var lado: int = (l + d[1]) % LADOS
				var punto: Array = anillo[1][lado]
				var ang: float = TAU * (l + d[1]) / LADOS
				esquinas.append([Vector3(cos(ang) * punto[0], anillo[0], sin(ang) * punto[0]), punto[1]])
			for i in [0, 2, 1, 0, 3, 2]:
				st.set_color(esquinas[i][1])
				st.add_vertex(esquinas[i][0])
	# Tapas
	for a in [0, ANILLOS]:
		var anillo: Array = anillos[a]
		for l in LADOS:
			var orden := [0, l, (l + 1) % LADOS] if a == ANILLOS else [0, (l + 1) % LADOS, l]
			for k in 3:
				var p := Vector3(0, anillo[0], 0)
				var tono: Color = anillo[1][l][1]
				if k > 0:
					var lado: int = orden[k]
					var ang: float = TAU * lado / LADOS
					p = Vector3(cos(ang) * anillo[1][lado][0], anillo[0], sin(ang) * anillo[1][lado][0])
				st.set_color(tono)
				st.add_vertex(p)
	st.generate_normals()
	var malla := st.commit()
	var material := _material(Color.WHITE, 4)
	material.set_shader_parameter("use_vertex_color", true)
	material.set_shader_parameter("metal", false)
	material.set_shader_parameter("desgaste", 0.0)
	malla.surface_set_material(0, material)
	return malla


func _cilindro(arriba: float, abajo: float, alto_c: float, pos: Vector3, material: Material, padre: Node3D) -> void:
	var malla := CylinderMesh.new()
	malla.top_radius = arriba
	malla.bottom_radius = abajo
	malla.height = alto_c
	malla.radial_segments = 10
	malla.rings = 1
	malla.material = material
	var instancia := MeshInstance3D.new()
	instancia.mesh = malla
	instancia.position = pos
	padre.add_child(instancia)


func _material(tinte: Color, modo: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PS1_SHADER
	material.set_shader_parameter("tint", tinte)
	material.set_shader_parameter("affine_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	material.set_shader_parameter("deterioro_modo", modo)
	material.set_shader_parameter("metal", modo == 4)
	material.set_shader_parameter("desgaste", 0.4)
	return material


# Humo que sube y se abre hasta desvanecerse: cuadros de frente a la camara con una
# mancha redonda en cuadritos (PS1). `caja` = medias medidas de donde sale. Tambien lo
# usa el comal del puesto (Mostrador._puesto)
static func humo(caja: Vector3, cantidad: int) -> CPUParticles3D:
	var particulas := CPUParticles3D.new()
	particulas.amount = cantidad
	# Corto: el toldo esta ~0.6 m arriba del trompo
	particulas.lifetime = 2.0
	particulas.preprocess = 2.0
	particulas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particulas.emission_box_extents = caja
	particulas.direction = Vector3.UP
	particulas.spread = 12.0
	particulas.initial_velocity_min = 0.2
	particulas.initial_velocity_max = 0.35
	particulas.gravity = Vector3(0.03, 0.06, 0)
	particulas.damping_min = 0.05
	particulas.damping_max = 0.1
	particulas.angle_min = 0.0
	particulas.angle_max = 360.0
	particulas.scale_amount_min = 0.7
	particulas.scale_amount_max = 1.1
	var crece := Curve.new()
	crece.add_point(Vector2(0, 0.35))
	crece.add_point(Vector2(1, 1.8))
	particulas.scale_amount_curve = crece
	var tono := Gradient.new()
	tono.set_color(0, Color(0.75, 0.73, 0.7, 0.0))
	tono.set_color(1, Color(0.6, 0.6, 0.6, 0.0))
	tono.add_point(0.15, Color(0.8, 0.78, 0.74, 0.6))
	tono.add_point(0.6, Color(0.72, 0.72, 0.72, 0.35))
	particulas.color_ramp = tono
	if _cuadro_humo == null:
		var mancha := GradientTexture2D.new()
		mancha.width = 16
		mancha.height = 16
		mancha.fill = GradientTexture2D.FILL_RADIAL
		mancha.fill_from = Vector2(0.5, 0.5)
		mancha.fill_to = Vector2(0.5, 0.0)
		var borde := Gradient.new()
		borde.set_color(0, Color(1, 1, 1, 1))
		borde.set_color(1, Color(1, 1, 1, 0))
		mancha.gradient = borde
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo = true
		material.albedo_texture = mancha
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		var cuadro := QuadMesh.new()
		cuadro.size = Vector2(0.22, 0.22)
		cuadro.material = material
		_cuadro_humo = cuadro
	var cuadro := _cuadro_humo
	particulas.mesh = cuadro
	particulas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particulas
