@tool
class_name Refrigerador
extends Node3D

# Refrigerador de tienda con puerta de vidrio, armado de cajas: cuerpo de color con
# letrero arriba, fondo y repisas blancas iluminadas por dentro, manija de tubo y
# tiras de luz, como los de refrescos de las tiendas de la esquina (copia el
# "Refrigerador de minisuper" de la UNAM en Sketchfab, que no se puede descargar).
# Adentro van botellas de verdad (`botella_abajo`/`botella_arriba`, p. ej. caguamas
# y Jarritos) o, sin modelos, cilindros de colores. El origen es el centro de su base
# y el frente ve a +Z (como Mueble).

const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")
# Refresco de cola, naranja, limon, toronja, agua, cerveza, jugo
const BEBIDAS := [Color(0.25, 0.1, 0.06), Color(0.95, 0.5, 0.1), Color(0.4, 0.75, 0.2),
	Color(0.95, 0.85, 0.3), Color(0.6, 0.8, 0.95), Color(0.75, 0.55, 0.15), Color(0.85, 0.2, 0.2)]
const BOTELLA_RADIO := 0.035
const BOTELLA_PASO := 0.085
# Modelos con mas triangulos que esto (el Jarritos escaneado: 19 mil) no se repiten
# tal cual: se tornean en una botella de TORNO_ANILLOS x TORNO_LADOS con sus colores
const BOTELLA_TRIANGULOS_MAX := 600
const TORNO_ANILLOS := 16
const TORNO_LADOS := 10
# Filas de botellas hacia atras (desde la puerta solo se ven las primeras)
const BOTELLA_FILAS := 3

# [ruta del modelo, sabor] -> malla de botella de 1 m de alto, base en y = 0
static var _mallas := {}

@export var ancho := 0.9:
	set(valor):
		ancho = valor
		_reconstruir()
@export var alto := 2.0:
	set(valor):
		alto = valor
		_reconstruir()
@export var fondo := 0.7:
	set(valor):
		fondo = valor
		_reconstruir()
@export_range(1, 2) var puertas := 1:
	set(valor):
		puertas = valor
		_reconstruir()
@export var color := Color(0.75, 0.1, 0.1):
	set(valor):
		color = valor
		_reconstruir()
@export var color_letrero := Color(0.95, 0.95, 0.95):
	set(valor):
		color_letrero = valor
		_reconstruir()
@export var repisas := 6:
	set(valor):
		repisas = valor
		_reconstruir()
# Cambia el acomodo y los colores de las botellas
@export var semilla := 0:
	set(valor):
		semilla = valor
		_reconstruir()
# Botellas de abajo (las primeras `repisas_abajo` repisas) y de arriba; su alto en m.
# Si falta una se usa la otra; sin ninguna, cilindros de colores
@export var botella_abajo: PackedScene:
	set(valor):
		botella_abajo = valor
		_reconstruir()
@export var repisas_abajo := 2:
	set(valor):
		repisas_abajo = valor
		_reconstruir()
@export var alto_abajo := 0.29:
	set(valor):
		alto_abajo = valor
		_reconstruir()
@export var botella_arriba: PackedScene:
	set(valor):
		botella_arriba = valor
		_reconstruir()
@export var alto_arriba := 0.235:
	set(valor):
		alto_arriba = valor
		_reconstruir()
# Sabores de las botellas de arriba: su color verde se repinta de cada uno, por
# bloques de columnas. Vacio = como viene el modelo
@export var sabores := PackedColorArray():
	set(valor):
		sabores = valor
		_reconstruir()
# Luz blanca de adentro (energia de su OmniLight; 0 = sin luz)
@export var luz := 0.6:
	set(valor):
		luz = valor
		_reconstruir()

var _partes: Node3D


func _ready() -> void:
	_reconstruir()


func _reconstruir() -> void:
	if not is_inside_tree():
		return
	if _partes:
		_partes.queue_free()
	_partes = Node3D.new()
	add_child(_partes, false, Node.INTERNAL_MODE_FRONT)
	var cuerpo := _ps1(color)
	var pared := 0.04
	var techo := 0.3
	var zoclo := 0.12
	var hueco := alto - techo - zoclo
	# Cuerpo: zoclo, fondo, lados y cabecera con letrero
	_caja(Vector3(ancho, zoclo, fondo), Vector3(0, zoclo / 2, 0), _ps1(color.darkened(0.4)))
	for signo in [-1.0, 1.0]:
		_caja(Vector3(pared, alto, fondo), Vector3(signo * (ancho - pared) / 2, alto / 2, 0), cuerpo)
	_caja(Vector3(ancho, techo, fondo), Vector3(0, alto - techo / 2, 0), cuerpo)
	_caja(Vector3(ancho - 0.12, techo * 0.45, 0.01), Vector3(0, alto - techo / 2, fondo / 2 + 0.005), _plano(color_letrero))
	# Fondo iluminado (es la pared de atras: una placa delante de ella se perdia con el
	# temblor de vertices del shader PS1) y repisas blancas con filo de precios
	_caja(Vector3(ancho, alto, pared), Vector3(0, alto / 2, -fondo / 2 + pared / 2), _plano(Color(0.92, 0.96, 1.0)))
	var repisa := _ps1(Color(0.86, 0.88, 0.9))
	var filo := _ps1(Color(0.97, 0.97, 0.95))
	# Forro claro por dentro de los lados (de lado se ven mas que el fondo)
	for signo in [-1.0, 1.0]:
		_caja(Vector3(0.01, hueco, fondo - 0.1), Vector3(signo * (ancho / 2 - pared - 0.015), zoclo + hueco / 2, -0.03), _plano(Color(0.82, 0.86, 0.9)))
	var niveles := _niveles(zoclo, hueco)
	for nivel in niveles:
		_caja(Vector3(ancho - 2 * pared, 0.015, fondo - 0.12), Vector3(0, nivel[0], -0.03), repisa)
		_caja(Vector3(ancho - 2 * pared, 0.03, 0.008), Vector3(0, nivel[0] - 0.005, fondo / 2 - 0.09), filo)
	if botella_abajo or botella_arriba:
		_modelos(niveles, pared)
	else:
		var alturas := []
		for nivel in niveles:
			alturas.append(nivel[0])
		_botellas(alturas, hueco / repisas)
	# Luz blanca por dentro: tira arriba y una OmniLight que alumbra las botellas
	var led := _plano(Color(0.85, 0.95, 1.0))
	_caja(Vector3(ancho - 2 * pared, 0.02, 0.03), Vector3(0, zoclo + hueco - 0.02, fondo / 2 - 0.08), led)
	if luz > 0.0:
		var foco := OmniLight3D.new()
		foco.light_color = Color(0.92, 0.96, 1.0)
		foco.light_energy = luz
		foco.omni_range = hueco * 1.1
		foco.omni_attenuation = 1.2
		foco.position = Vector3(0, zoclo + hueco - 0.06, fondo / 2 - 0.1)
		_partes.add_child(foco)
	# Puertas: marco ancho del color del cuerpo, vidrio, tira de luz junto a la bisagra
	# y manija de tubo cromado del otro lado
	var vidrio := StandardMaterial3D.new()
	vidrio.albedo_color = Color(0.75, 0.9, 1.0, 0.07)
	vidrio.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vidrio.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var marco := _ps1(color.darkened(0.15))
	var cromo := _ps1(Color(0.72, 0.74, 0.78))
	var puerta_ancho := ancho / puertas
	var z := fondo / 2 + 0.015
	for i in puertas:
		var x := -ancho / 2 + puerta_ancho * (i + 0.5)
		var y := zoclo + hueco / 2
		_caja(Vector3(puerta_ancho - 0.1, hueco - 0.1, 0.01), Vector3(x, y, z), vidrio)
		_caja(Vector3(puerta_ancho, 0.06, 0.03), Vector3(x, zoclo + hueco - 0.03, z), marco)
		_caja(Vector3(puerta_ancho, 0.06, 0.03), Vector3(x, zoclo + 0.03, z), marco)
		for signo in [-1.0, 1.0]:
			_caja(Vector3(0.06, hueco, 0.03), Vector3(x + signo * (puerta_ancho / 2 - 0.03), y, z), marco)
		var bisagra := -1.0 if i == 0 else 1.0
		_caja(Vector3(0.015, hueco - 0.12, 0.01), Vector3(x + bisagra * (puerta_ancho / 2 - 0.065), y, z + 0.012), led)
		var manija := x - bisagra * (puerta_ancho / 2 - 0.03)
		_caja(Vector3(0.022, 0.5, 0.022), Vector3(manija, y + 0.05, z + 0.06), cromo)
		for dy in [-0.22, 0.22]:
			_caja(Vector3(0.015, 0.02, 0.05), Vector3(manija, y + 0.05 + dy, z + 0.035), cromo)
	if not Engine.is_editor_hint():
		var solido := StaticBody3D.new()
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(ancho, alto, fondo + 0.06)
		forma.shape = box
		forma.position = Vector3(0, alto / 2, 0.03)
		solido.add_child(forma)
		_partes.add_child(solido)


# [y, separacion] de cada repisa: las de abajo a la medida de `botella_abajo`, las
# demas parejas en lo que sobra
func _niveles(zoclo: float, hueco: float) -> Array:
	var abajo := 0
	var separacion_abajo := 0.0
	if botella_abajo and botella_arriba:
		abajo = mini(repisas_abajo, repisas - 1)
		separacion_abajo = minf(alto_abajo + 0.06, hueco / repisas * 1.6)
	var separacion := (hueco - abajo * separacion_abajo) / (repisas - abajo)
	var niveles := []
	var y := zoclo + 0.03
	for i in repisas:
		var paso := separacion_abajo if i < abajo else separacion
		niveles.append([y, paso, i < abajo])
		y += paso
	return niveles


# Botellas de modelo, en bloques de columnas del mismo sabor y hasta BOTELLA_FILAS
# hacia atras; alguna columna sin la de enfrente, donde ya se vendio
func _modelos(niveles: Array, pared: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([semilla, ancho, puertas, repisas])
	var grupos := {}
	for nivel in niveles:
		var de_abajo: bool = nivel[2] or botella_arriba == null
		var escena: PackedScene = botella_abajo if de_abajo and botella_abajo else botella_arriba
		var alto_botella := minf(alto_abajo if de_abajo else alto_arriba, nivel[1] - 0.04)
		var base := Refrigerador.malla_botella(escena, Color(0, 0, 0, 0))
		var caja := base.get_aabb()
		var diametro := maxf(caja.size.x, caja.size.z) * alto_botella
		var paso := diametro + 0.006
		var columnas := int((ancho - 2 * pared - 0.04) / paso)
		var filas := mini(BOTELLA_FILAS, int((fondo - 0.16) / paso))
		var bloque := 0
		var malla: Mesh = base
		for c in columnas:
			if bloque == 0:
				bloque = rng.randi_range(2, 4)
				if not de_abajo and not sabores.is_empty():
					malla = Refrigerador.malla_botella(escena, sabores[rng.randi() % sabores.size()])
			bloque -= 1
			var desde := 1 if rng.randf() < 0.1 else 0
			for f in range(desde, filas):
				var x := -(columnas - 1) * paso / 2 + c * paso
				var z := fondo / 2 - 0.1 - diametro / 2 - f * paso
				var giro := Basis(Vector3.UP, rng.randf_range(-0.4, 0.4))
				var xform := Transform3D(giro.scaled(Vector3.ONE * alto_botella), Vector3(x, nivel[0] + 0.008, z))
				if not grupos.has(malla):
					grupos[malla] = []
				grupos[malla].append(xform)
	for malla in grupos:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = malla
		multi.instance_count = grupos[malla].size()
		for i in multi.instance_count:
			multi.set_instance_transform(i, grupos[malla][i])
		var instancia := MultiMeshInstance3D.new()
		instancia.multimesh = multi
		_partes.add_child(instancia)


# Malla de una botella del modelo `escena`, de 1 m de alto, centrada y parada en
# y = 0, con material PS1. Si es pesada se tornea (ver _tornear); `sabor` (alfa > 0)
# repinta sus verdes de ese color. Se guarda para los demas refrigeradores.
static func malla_botella(escena: PackedScene, sabor: Color) -> Mesh:
	var clave := [escena.resource_path, sabor]
	if _mallas.has(clave):
		return _mallas[clave]
	var raiz := escena.instantiate() as Node3D
	var caja := Mueble.medir(raiz)
	var partes := []
	var triangulos := 0
	for nodo in raiz.find_children("*", "MeshInstance3D", true, false):
		var instancia := nodo as MeshInstance3D
		if instancia.mesh == null:
			continue
		var xform := instancia.transform
		var padre := instancia.get_parent()
		while padre != raiz:
			if padre is Node3D:
				xform = (padre as Node3D).transform * xform
			padre = padre.get_parent()
		partes.append([instancia.mesh, xform])
		for s in instancia.mesh.get_surface_count():
			var arrays := instancia.mesh.surface_get_arrays(s)
			var indices = arrays[Mesh.ARRAY_INDEX]
			triangulos += (indices.size() if indices else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	raiz.free()
	# A 1 m de alto, centrada en x/z y con la base en y = 0
	var normal := Transform3D(Basis().scaled(Vector3.ONE / caja.size.y), Vector3.ZERO) \
		* Transform3D(Basis(), -Vector3(caja.get_center().x, caja.position.y, caja.get_center().z))
	var malla: Mesh
	if triangulos > BOTELLA_TRIANGULOS_MAX:
		malla = _tornear(partes, normal, sabor)
	else:
		malla = _juntar(partes, normal)
	_mallas[clave] = malla
	return malla


# Las mallas del modelo tal cual, en una sola, con su textura en el shader PS1
static func _juntar(partes: Array, normal: Transform3D) -> ArrayMesh:
	var malla := ArrayMesh.new()
	for parte in partes:
		var origen: Mesh = parte[0]
		var xform: Transform3D = normal * parte[1]
		for s in origen.get_surface_count():
			var arrays := origen.surface_get_arrays(s)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				vertices[i] = xform * vertices[i]
			arrays[Mesh.ARRAY_VERTEX] = vertices
			if arrays[Mesh.ARRAY_NORMAL]:
				var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for i in normales.size():
					normales[i] = (xform.basis * normales[i]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = normales
			arrays[Mesh.ARRAY_TANGENT] = null
			for custom in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
				arrays[custom] = null
			malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var material := ShaderMaterial.new()
			material.shader = PS1_SHADER
			material.set_shader_parameter("wobble_enabled", false)
			material.set_shader_parameter("affine_enabled", false)
			material.set_shader_parameter("deterioro_modo", 4)
			material.set_shader_parameter("desgaste", 0.3)
			var textura := _textura(origen.surface_get_material(s))
			if textura:
				material.set_shader_parameter("albedo_texture", textura)
			malla.surface_set_material(malla.get_surface_count() - 1, material)
	return malla


# Una botella de revolucion con la silueta y los colores del modelo: por cada anillo
# de altura, el radio de su superficie exterior (percentil 85 de los vertices, que en
# un escaneo traen basura adentro) y, por cada gajo, el color promedio de la textura
# ahi. Queda en ~300 triangulos con color de vertice.
static func _tornear(partes: Array, normal: Transform3D, sabor: Color) -> ArrayMesh:
	var muestras := []
	var radios := []
	for a in TORNO_ANILLOS:
		radios.append(PackedFloat32Array())
	for parte in partes:
		var origen: Mesh = parte[0]
		var xform: Transform3D = normal * parte[1]
		for s in origen.get_surface_count():
			var imagen: Image = null
			var textura := _textura(origen.surface_get_material(s))
			if textura:
				imagen = textura.get_image()
				if imagen and imagen.is_compressed():
					imagen.decompress()
			var arrays := origen.surface_get_arrays(s)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uvs = arrays[Mesh.ARRAY_TEX_UV]
			for i in vertices.size():
				var p := xform * vertices[i]
				var anillo := clampi(int(p.y * TORNO_ANILLOS), 0, TORNO_ANILLOS - 1)
				var r := Vector2(p.x, p.z).length()
				var lado := int(fposmod(atan2(p.z, p.x) / TAU, 1.0) * TORNO_LADOS) % TORNO_LADOS
				var tinte := Color.WHITE
				if imagen and uvs:
					var tam := imagen.get_size()
					var uv: Vector2 = uvs[i]
					tinte = imagen.get_pixel(clampi(int(fposmod(uv.x, 1.0) * tam.x), 0, tam.x - 1),
						clampi(int(fposmod(uv.y, 1.0) * tam.y), 0, tam.y - 1))
				radios[anillo].append(r)
				muestras.append([anillo, lado, r, tinte])
	var radio := PackedFloat32Array()
	for a in TORNO_ANILLOS:
		var lista: PackedFloat32Array = radios[a]
		lista.sort()
		radio.append(lista[int(lista.size() * 0.85)] if lista.size() > 0 else 0.0)
	# Anillos sin vertices: el radio del vecino
	for a in TORNO_ANILLOS:
		if radio[a] == 0.0:
			radio[a] = radio[a - 1] if a > 0 else 0.1
	# Color por gajo con solo la superficie exterior
	var suma := {}
	for m in muestras:
		if m[2] < radio[m[0]] * 0.8:
			continue
		var gajo := Vector2i(m[0], m[1])
		if not suma.has(gajo):
			suma[gajo] = [Color(0, 0, 0, 0), 0]
		suma[gajo][0] += m[3]
		suma[gajo][1] += 1
	var colores := []
	for a in TORNO_ANILLOS:
		var fila := []
		var anillo_suma := Color(0, 0, 0, 0)
		var anillo_n := 0
		for l in TORNO_LADOS:
			var gajo := Vector2i(a, l)
			if suma.has(gajo):
				anillo_suma += suma[gajo][0]
				anillo_n += suma[gajo][1]
		var promedio := anillo_suma / anillo_n if anillo_n > 0 else Color(0.5, 0.5, 0.5)
		for l in TORNO_LADOS:
			var gajo := Vector2i(a, l)
			var c: Color = suma[gajo][0] / suma[gajo][1] if suma.has(gajo) else promedio
			fila.append(_repintar(c, sabor))
		colores.append(fila)
	# Anillos de vertices: la base, el centro de cada anillo y la boca
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var alturas := [0.0]
	var cual := [0]
	for a in TORNO_ANILLOS:
		alturas.append((a + 0.5) / TORNO_ANILLOS)
		cual.append(a)
	alturas.append(1.0)
	cual.append(TORNO_ANILLOS - 1)
	for k in alturas.size():
		for l in TORNO_LADOS:
			var angulo := (l + 0.5) / TORNO_LADOS * TAU
			st.set_color(colores[cual[k]][l])
			st.add_vertex(Vector3(cos(angulo) * radio[cual[k]], alturas[k], sin(angulo) * radio[cual[k]]))
	var n := alturas.size() * TORNO_LADOS
	st.set_color(colores[0][0])
	st.add_vertex(Vector3.ZERO)
	st.set_color(colores[TORNO_ANILLOS - 1][0])
	st.add_vertex(Vector3(0, 1, 0))
	for k in alturas.size() - 1:
		for l in TORNO_LADOS:
			var a := k * TORNO_LADOS + l
			var b := k * TORNO_LADOS + (l + 1) % TORNO_LADOS
			var c := a + TORNO_LADOS
			var d := b + TORNO_LADOS
			for i in [a, c, b, b, c, d]:
				st.add_index(i)
	var arriba := (alturas.size() - 1) * TORNO_LADOS
	for l in TORNO_LADOS:
		for i in [n, l, (l + 1) % TORNO_LADOS, n + 1, arriba + (l + 1) % TORNO_LADOS, arriba + l]:
			st.add_index(i)
	st.generate_normals()
	var malla := st.commit()
	var material := ShaderMaterial.new()
	material.shader = PS1_SHADER
	material.set_shader_parameter("wobble_enabled", false)
	material.set_shader_parameter("affine_enabled", false)
	material.set_shader_parameter("use_vertex_color", true)
	material.set_shader_parameter("deterioro_modo", 4)
	material.set_shader_parameter("desgaste", 0.3)
	malla.surface_set_material(0, material)
	return malla


# Los verdes del modelo (vidrio y refresco del Jarritos de limon) pasan al tono del
# sabor, con saturacion minima porque el escaneo trae brillos blancos horneados; la
# etiqueta (naranja, blanca) se queda
static func _repintar(c: Color, sabor: Color) -> Color:
	if sabor.a == 0.0 or c.s < 0.25 or c.h < 0.17 or c.h > 0.5:
		return c
	return Color.from_hsv(sabor.h, lerpf(0.65, 1.0, c.s) * sabor.s, clampf(c.v * sabor.v, 0.0, 1.0))


static func _textura(material: Material) -> Texture2D:
	if material is ShaderMaterial:
		return (material as ShaderMaterial).get_shader_parameter("albedo_texture") as Texture2D
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).albedo_texture
	return null


# Dos filas de botellas por repisa, en bloques de marcas del mismo color
func _botellas(alturas: Array, separacion: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([semilla, ancho, puertas])
	var botella := CylinderMesh.new()
	botella.top_radius = BOTELLA_RADIO * 0.55
	botella.bottom_radius = BOTELLA_RADIO
	botella.height = 1.0
	botella.radial_segments = 6
	botella.rings = 1
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	botella.material = material
	var columnas := int((ancho - 0.12) / BOTELLA_PASO)
	var transformes := []
	var colores := []
	for y in alturas:
		var alto_botella := minf(rng.randf_range(0.17, 0.26), separacion - 0.05)
		var bloque := 0
		var tinte: Color
		for c in columnas:
			if bloque == 0:
				bloque = rng.randi_range(2, 5)
				tinte = BEBIDAS[rng.randi() % BEBIDAS.size()]
			bloque -= 1
			# Algun hueco donde ya se vendieron
			if rng.randf() < 0.08:
				continue
			for fila in [0.12, -0.05]:
				var x: float = -(columnas - 1) * BOTELLA_PASO / 2 + c * BOTELLA_PASO
				var base := Transform3D(Basis().scaled(Vector3(1, alto_botella, 1)), Vector3(x, y + 0.01 + alto_botella / 2, fila))
				transformes.append(base)
				colores.append(tinte)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = botella
	multi.instance_count = transformes.size()
	for i in transformes.size():
		multi.set_instance_transform(i, transformes[i])
		multi.set_instance_color(i, colores[i])
	var instancia := MultiMeshInstance3D.new()
	instancia.multimesh = multi
	_partes.add_child(instancia)


func _caja(tamano: Vector3, pos: Vector3, material: Material) -> void:
	var malla := BoxMesh.new()
	malla.size = tamano
	malla.material = material
	var instancia := MeshInstance3D.new()
	instancia.mesh = malla
	instancia.position = pos
	_partes.add_child(instancia)


func _ps1(tinte: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PS1_SHADER
	material.set_shader_parameter("tint", tinte)
	material.set_shader_parameter("affine_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	# Fierro pintado con uso (ps1_gastado): manchas, mugre, rayones, despostillado
	material.set_shader_parameter("deterioro_modo", 4)
	material.set_shader_parameter("metal", true)
	return material


# Sin sombreado: luces, vidrio, letrero, tambien
# con mugre y manchas para que no sean de un color parejo
func _plano(tinte: Color) -> ShaderMaterial:
	var material := _ps1(tinte)
	material.set_shader_parameter("metal", false)
	material.set_shader_parameter("desgaste", 0.3)
	material.set_shader_parameter("sin_sombra", true)
	return material
