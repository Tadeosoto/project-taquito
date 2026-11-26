extends SceneTree

# Los tiliches que no hay en Sketchfab (Fase T de docs/plan-noche.md) se arman aqui en
# codigo: malla + textura pintada pixel por pixel, con el shader PS1. Guarda
# models/tiliches/<id>/<id>.scn, que es lo que ven tools/map_import/capturas.gd y el juego.
# Lo que se hace en el taller (armas, armaduras, amuletos: T3 a T5) va en models/taller/<id>/.
#
#   godot --path . --headless -s tools/taller/tiliches_codigo.gd             # todos
#   godot --path . --headless -s tools/taller/tiliches_codigo.gd -- --solo=varilla

const SALIDA := "res://models/%s/%s/%s.scn"
const SHADER := preload("res://shaders/ps1_combined.gdshader")

# id -> funcion que regresa el Node3D del modelo
var _tiliches := {
	"varilla": _varilla,
	"cobalto_84": _cobalto_84,
	"hilacha": _hilacha,
	"tela": _tela,
	"cuero": _cuero,
	"liga": _liga,
	"hule": _hule,
	"llanta": _llanta,
	"frijol_rojo": _frijol_rojo,
	"obsidiana": _obsidiana,
	"cuarzo": _cuarzo,
	"plata_taxco": _plata_taxco,
	# Trofeos (T2)
	"marca_cazador": _marca_cazador,
	"ojo_turba": _ojo_turba,
	"tapa_tinaco": _tapa_tinaco,
	"diente_jefe": _diente_jefe,
	"chancla_oro": _chancla_oro,
	"casco_gela": _casco_gela,
	"escama_madre": _escama_madre,
	"corona_flores": _corona_flores,
}

# Lo que se hace en el taller: id -> funcion (se guarda en models/taller/)
var _taller := {
	# Armas (T3)
	"machete_oxidado": _machete_oxidado,
	"machete_reforzado": _machete_reforzado,
	"machete_canero": _machete_canero,
	"macheton_84": _macheton_84,
	"tubo": _tubo_fierro,
	"marro": _marro,
	"bate_clavos": _bate_clavos,
	"femur_cobalto": _femur_cobalto,
	# Armadura y botas (T4)
	"coderas_rodilleras": _coderas_rodilleras,
	"faja": _faja_cargador,
	"chaleco_llanta": _chaleco_llanta,
	"chamarra_machetes": _chamarra_machetes,
	"botas_84": _botas_84,
	# Amuletos (T5)
	"escapulario": _escapulario,
	"ojo_venado": _ojo_venado,
	"collar_obsidiana": _collar_obsidiana,
	"medalla_virgen": _medalla_virgen,
	"medalla_san_judas": _medalla_san_judas,
	"pulsera_san_benito": _pulsera_san_benito,
	"liston_virgen": _liston_virgen,
	"collar_santa_muerte": _collar_santa_muerte,
}


func _init() -> void:
	var solo := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--solo="):
			solo = arg.trim_prefix("--solo=")
	for grupo in ["tiliches", "taller"]:
		var lista: Dictionary = _tiliches if grupo == "tiliches" else _taller
		for id: String in lista:
			if solo != "" and id != solo:
				continue
			var modelo: Node3D = lista[id].call()
			_guardar(modelo, id, grupo)
			print(grupo, " ", id)
	quit()


# --- Varilla: un tramo corto de varilla corrugada, oxidada y un poco doblada ---

const VARILLA_LARGO := 0.45
const VARILLA_RADIO := 0.012
const VARILLA_LADOS := 8
const VARILLA_ANILLOS := 36      # las corrugaciones: un anillo gordo y uno flaco
const VARILLA_DOBLEZ := 0.35     # rad que se dobla a la mitad


func _varilla() -> Node3D:
	return _malla(_malla_varilla(), _oxido())


# --- Cobalto 84: la misma varilla, azul y brillando sola (sin_sombra del shader PS1) ---

func _cobalto_84() -> Node3D:
	var m := _malla(_malla_varilla(), _cobalto())
	(m.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("sin_sombra", true)
	# Luz azul chica: alumbra el piso de noche. Es solo para cuando esta tirado: quien lo muestre
	# en el inventario o en la mano debe quitar el nodo "LuzPiso" (cuesta frames y no se ve ahi)
	var luz := OmniLight3D.new()
	luz.name = "LuzPiso"
	luz.light_color = Color(0.3, 0.6, 1.0)
	luz.light_energy = 1.2
	luz.omni_range = 2.0
	luz.shadow_enabled = false
	m.add_child(luz)
	return m


func _malla_varilla() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Eje: recto la primera mitad y doblado la segunda (alrededor de Z)
	var puntos: Array[Vector3] = []
	var frentes: Array[Vector3] = []
	for i in VARILLA_ANILLOS + 1:
		var t := float(i) / VARILLA_ANILLOS
		var ang := maxf(0.0, t - 0.5) * 2.0 * VARILLA_DOBLEZ
		var dir := Vector3(sin(ang), cos(ang), 0.0)
		frentes.append(dir)
		if i == 0:
			puntos.append(Vector3(0, -VARILLA_LARGO * 0.5, 0))
		else:
			puntos.append(puntos[i - 1] + frentes[i - 1] * VARILLA_LARGO / VARILLA_ANILLOS)
	for i in VARILLA_ANILLOS:
		for k in VARILLA_LADOS:
			var a := _aro(puntos, frentes, i, k)
			var b := _aro(puntos, frentes, i, k + 1)
			var c := _aro(puntos, frentes, i + 1, k + 1)
			var d := _aro(puntos, frentes, i + 1, k)
			var u0 := float(k) / VARILLA_LADOS
			var u1 := float(k + 1) / VARILLA_LADOS
			var v0 := float(i) / VARILLA_ANILLOS
			var v1 := float(i + 1) / VARILLA_ANILLOS
			# Godot toma como frente el orden horario visto desde afuera
			for par in [[a, Vector2(u0, v0)], [c, Vector2(u1, v1)], [b, Vector2(u1, v0)],
					[a, Vector2(u0, v0)], [d, Vector2(u0, v1)], [c, Vector2(u1, v1)]]:
				st.set_uv(par[1])
				st.add_vertex(par[0])
	st.generate_normals()
	return st.commit()


# Vertice k del anillo i: los anillos pares son mas gordos (la corrugacion)
func _aro(puntos: Array[Vector3], frentes: Array[Vector3], i: int, k: int) -> Vector3:
	var radio := VARILLA_RADIO * (1.18 if i % 2 == 0 else 1.0)
	var adelante := frentes[i]
	var lado := adelante.cross(Vector3.BACK).normalized()
	var arriba := lado.cross(adelante).normalized()
	var ang := TAU * float(k) / VARILLA_LADOS
	return puntos[i] + (lado * cos(ang) + arriba * sin(ang)) * radio


# Oxido: cafe rojizo con manchas naranjas y rayas diagonales oscuras (las corrugaciones)
func _oxido() -> Texture2D:
	var img := Image.create(32, 64, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 84
	for y in 64:
		for x in 32:
			var raya := 0.75 if (x + y * 2) % 8 < 2 else 1.0
			var mancha := rnd.randf()
			var c := Color(0.42, 0.24, 0.14)
			if mancha > 0.86:
				c = Color(0.68, 0.36, 0.14)
			elif mancha < 0.08:
				c = Color(0.25, 0.2, 0.18)
			c = c.lightened(rnd.randf_range(-0.05, 0.08))
			img.set_pixel(x, y, Color(c.r * raya, c.g * raya, c.b * raya))
	return ImageTexture.create_from_image(img)


# Cobalto: azul profundo con vetas cian que brillan y las corrugaciones mas oscuras
func _cobalto() -> Texture2D:
	var img := Image.create(32, 64, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 1984
	for y in 64:
		for x in 32:
			var raya := 0.7 if (x + y * 2) % 8 < 2 else 1.0
			var c := Color(0.1, 0.25, 0.75).lightened(rnd.randf_range(-0.08, 0.08))
			# Vetas: una onda que serpentea a lo largo
			if absf(x - 16.0 - 9.0 * sin(y * 0.35)) < 1.5 or rnd.randf() > 0.93:
				c = Color(0.45, 0.9, 1.0)
			img.set_pixel(x, y, Color(c.r * raya, c.g * raya, c.b * raya))
	return ImageTexture.create_from_image(img)


# --- Hilacha: una marana de hilos sueltos de colores deslavados ---

const HILACHA_COLORES := [Color(0.85, 0.82, 0.72), Color(0.3, 0.4, 0.6), Color(0.7, 0.25, 0.22), Color(0.85, 0.82, 0.72), Color(0.45, 0.5, 0.35)]


func _hilacha() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Hilos"
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 7
	for i in 9:
		var aro := TorusMesh.new()
		var r := rnd.randf_range(0.025, 0.045)
		aro.outer_radius = r
		aro.inner_radius = r - 0.004
		aro.rings = 14
		aro.ring_segments = 3
		var m := _malla(aro, _liso(HILACHA_COLORES[i % HILACHA_COLORES.size()], i))
		m.name = "Hilo%d" % i
		m.rotation = Vector3(rnd.randf() * TAU, rnd.randf() * TAU, rnd.randf() * TAU)
		m.position = Vector3(rnd.randf_range(-0.012, 0.012), rnd.randf_range(-0.012, 0.012), rnd.randf_range(-0.012, 0.012))
		raiz.add_child(m)
	return raiz


# Un color con un poco de ruido (sin textura el shader daria negro)
func _liso(color: Color, semilla: int) -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = semilla
	for y in 8:
		for x in 8:
			img.set_pixel(x, y, color.lightened(rnd.randf_range(-0.12, 0.1)))
	return ImageTexture.create_from_image(img)


# --- Tela: la toalla de models/objetos/trapo (el trapo de la ferreteria, el del molotov) hecha franela amarilla ---

const TRAPO_BASE := "res://models/objetos/trapo/trapo.scn"


func _tela() -> Node3D:
	var modelo := (load(TRAPO_BASE) as PackedScene).instantiate() as Node3D
	var tela := _franela()
	for malla: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		for s in malla.mesh.get_surface_count():
			var material := ShaderMaterial.new()
			material.shader = SHADER
			material.set_shader_parameter("albedo_texture", tela)
			material.set_shader_parameter("base_color", Color.WHITE)
			material.set_shader_parameter("affine_enabled", false)
			material.set_shader_parameter("wobble_enabled", false)
			malla.set_surface_override_material(s, material)
		malla.material_override = null
	return modelo


# Franela amarilla: tejido de cuadritos (hilos que cruzan) con pelusa y una orilla roja cosida
func _franela() -> Texture2D:
	const T := 128
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 23
	for y in T:
		for x in T:
			var c := Color(0.95, 0.78, 0.18)
			# Trama de 1 px: los hilos de un sentido un poco mas oscuros que los del otro
			if (x + y) % 2 == 0:
				c = c.darkened(0.07)
			c = c.lightened(rnd.randf_range(-0.04, 0.05))
			# La orilla: una costura roja a 5 px del borde
			if (x == 5 or x == T - 6 or y == 5 or y == T - 6) and (x + y) % 4 != 0:
				c = Color(0.75, 0.15, 0.12)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Cuero: un pedazo irregular recortado de una chamarra, ondulado, con costura en una orilla ---

const CUERO_PUNTAS := 14
const CUERO_RADIO := 0.09
const CUERO_GROSOR := 0.006


func _cuero() -> Node3D:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 31
	# Orilla: un circulo deformado, mas largo que ancho
	var orilla: Array[Vector2] = []
	for i in CUERO_PUNTAS:
		var ang := TAU * i / CUERO_PUNTAS
		var r := CUERO_RADIO * rnd.randf_range(0.7, 1.05)
		orilla.append(Vector2(cos(ang) * r * 1.4, sin(ang) * r))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var alto := func(p: Vector2) -> float: return sin(p.x * 30.0) * 0.008 + cos(p.y * 25.0) * 0.005
	var uv := func(p: Vector2) -> Vector2: return p / (CUERO_RADIO * 3.0) + Vector2(0.5, 0.5)
	for i in CUERO_PUNTAS:
		var a := orilla[i]
		var b := orilla[(i + 1) % CUERO_PUNTAS]
		var centro := Vector2.ZERO
		# Cara de arriba y de abajo (abanico desde el centro), y el canto
		for cara: float in [1.0, -1.0]:
			var dy := CUERO_GROSOR * 0.5 * cara
			var tri := [centro, b, a] if cara > 0.0 else [centro, a, b]
			for q: Vector2 in tri:
				st.set_uv(uv.call(q))
				st.add_vertex(Vector3(q.x, float(alto.call(q)) + dy, q.y))
		var a1 := Vector3(a.x, float(alto.call(a)) + CUERO_GROSOR * 0.5, a.y)
		var b1 := Vector3(b.x, float(alto.call(b)) + CUERO_GROSOR * 0.5, b.y)
		var a0 := a1 - Vector3(0, CUERO_GROSOR, 0)
		var b0 := b1 - Vector3(0, CUERO_GROSOR, 0)
		for v in [a1, b1, b0, a1, b0, a0]:
			st.set_uv(Vector2(0.02, 0.02))
			st.add_vertex(v)
	st.generate_normals()
	return _malla(st.commit(), _piel())


# Piel cafe: grano con manchitas, mas oscura hacia la orilla y una costura beige en diagonal
func _piel() -> Texture2D:
	const T := 64
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 5
	for y in T:
		for x in T:
			var orilla := Vector2(x - T / 2.0, y - T / 2.0).length() / (T / 2.0)
			var c := Color(0.42, 0.25, 0.13).darkened(clampf(orilla - 0.4, 0.0, 0.5))
			c = c.lightened(rnd.randf_range(-0.07, 0.07))
			if rnd.randf() > 0.95:
				c = c.darkened(0.2)
			# Costura: puntadas sobre una linea diagonal
			if absi(x - y - 10) <= 1 and x % 5 < 3:
				c = Color(0.85, 0.75, 0.55)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Liga: tres ligas de hule (de las del mercado) tiradas una sobre otra ---

const LIGA_COLORES := [Color(0.85, 0.55, 0.25), Color(0.8, 0.15, 0.12), Color(0.3, 0.6, 0.25)]


func _liga() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Ligas"
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 12
	for i in LIGA_COLORES.size():
		var aro := TorusMesh.new()
		aro.outer_radius = 0.035
		aro.inner_radius = 0.03
		aro.rings = 16
		aro.ring_segments = 4
		var m := _malla(aro, _liso(LIGA_COLORES[i], 40 + i))
		m.name = "Liga%d" % i
		# Aplastadas (una liga es plana) y torcidas como caen
		m.scale = Vector3(rnd.randf_range(1.0, 1.4), 0.5, rnd.randf_range(0.7, 1.0))
		m.rotation = Vector3(rnd.randf_range(-0.25, 0.25), rnd.randf() * TAU, rnd.randf_range(-0.25, 0.25))
		m.position = Vector3(rnd.randf_range(-0.015, 0.015), i * 0.004, rnd.randf_range(-0.015, 0.015))
		raiz.add_child(m)
	return raiz


# --- Hule: un pedazo cortado de llanta (la banda de rodamiento), con dibujo afuera, costados
# lisos y las cuerdas de la tela expuestas por dentro ---

const HULE_RADIO := 0.2       # m del centro de la llanta a la banda
const HULE_ARCO := 0.55       # rad del pedazo
const HULE_ANCHO := 0.09
const HULE_GRUESO := 0.022
const HULE_PASOS := 8
const LLANTA_COSTADO := 0.075   # m de costado de la llanta entera (el pedazo solo trae la banda)


func _hule() -> Node3D:
	return _llanta_arco(HULE_ARCO, HULE_PASOS, true, HULE_GRUESO)


# --- Llanta: la misma llanta del Hule, entera (una vuelta completa, sin cortes) ---

func _llanta() -> Node3D:
	var m := _llanta_arco(TAU, 24, false, LLANTA_COSTADO)
	# Parada como llanta tirada recargada: de canto, un poco inclinada
	m.rotation = Vector3(0.0, 0.0, deg_to_rad(80.0))
	return m


func _llanta_arco(arco: float, pasos: int, cortes: bool, grueso: float) -> MeshInstance3D:
	var caras := {"banda": SurfaceTool.new(), "costado": SurfaceTool.new(), "dentro": SurfaceTool.new()}
	for st: SurfaceTool in caras.values():
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r_fuera := HULE_RADIO
	var r_dentro := HULE_RADIO - grueso
	var w := HULE_ANCHO * 0.5
	# El pedazo se centra en el origen: el arco va alrededor del eje X, abajo del centro de la llanta
	var baja := HULE_RADIO - grueso * 0.5 if cortes else 0.0
	var en := func(ang: float, r: float, x: float) -> Vector3:
		return Vector3(x, cos(ang) * r - baja, sin(ang) * r)
	for i in pasos:
		var a0 := -arco * 0.5 + arco * i / pasos
		var a1 := -arco * 0.5 + arco * (i + 1) / pasos
		# La textura se repite cada ~0.07 rad de banda, igual en el pedazo y en la llanta entera
		var v0 := a0 / HULE_ARCO * 2.0
		var v1 := a1 / HULE_ARCO * 2.0
		_cuad(caras["banda"], en.call(a0, r_fuera, -w), en.call(a0, r_fuera, w), en.call(a1, r_fuera, w), en.call(a1, r_fuera, -w), v0, v1)
		_cuad(caras["dentro"], en.call(a0, r_dentro, w), en.call(a0, r_dentro, -w), en.call(a1, r_dentro, -w), en.call(a1, r_dentro, w), v0, v1)
		_cuad(caras["costado"], en.call(a0, r_dentro, w), en.call(a1, r_dentro, w), en.call(a1, r_fuera, w), en.call(a0, r_fuera, w), v0, v1)
		_cuad(caras["costado"], en.call(a0, r_fuera, -w), en.call(a1, r_fuera, -w), en.call(a1, r_dentro, -w), en.call(a0, r_dentro, -w), v0, v1)
	# Los dos cortes, como costado
	for a in ([-arco * 0.5, arco * 0.5] if cortes else []):
		var q := [en.call(a, r_dentro, -w), en.call(a, r_dentro, w), en.call(a, r_fuera, w), en.call(a, r_fuera, -w)]
		if a > 0.0:
			q.reverse()
		_cuad(caras["costado"], q[0], q[1], q[2], q[3], 0.0, 0.2)
	var malla := ArrayMesh.new()
	var texturas := {"banda": _dibujo_llanta(), "costado": _costado_llanta() if not cortes else _liso(Color(0.14, 0.14, 0.15), 70), "dentro": _cuerdas() if cortes else _liso(Color(0.1, 0.1, 0.11), 74)}
	var m := MeshInstance3D.new()
	m.name = "Malla"
	var n := 0
	for nombre: String in caras:
		var st: SurfaceTool = caras[nombre]
		st.generate_normals()
		st.commit(malla)
		m.mesh = malla
		m.set_surface_override_material(n, _material(texturas[nombre]))
		n += 1
	return m


# Un cuadrilatero a-b-c-d (frente: antihorario visto desde afuera) con u de 0 a 1 y v de v0 a v1
func _cuad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, v0: float, v1: float) -> void:
	for par in [[a, Vector2(0, v0)], [b, Vector2(1, v0)], [c, Vector2(1, v1)],
			[a, Vector2(0, v0)], [c, Vector2(1, v1)], [d, Vector2(0, v1)]]:
		st.set_uv(par[1])
		st.add_vertex(par[0])


# Banda de rodamiento: hule negro con surcos en zigzag y una ranura al centro, gastado
func _dibujo_llanta() -> Texture2D:
	const T := 64
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 71
	for y in T:
		for x in T:
			var c := Color(0.16, 0.16, 0.17).lightened(rnd.randf_range(-0.03, 0.04))
			var zig := absi(((y + absi(x - T / 2) / 2) % 12) - 6) < 2
			if zig or absi(x - T / 2) < 2 or x < 3 or x > T - 4:
				c = Color(0.05, 0.05, 0.055)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Costado de la llanta entera: hule liso con dos lineas en relieve (donde iria la marca)
func _costado_llanta() -> Texture2D:
	const T := 32
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 73
	for y in T:
		for x in T:
			var c := Color(0.14, 0.14, 0.15).lightened(rnd.randf_range(-0.03, 0.03))
			# En el costado la u corre a lo largo de la vuelta y la v hacia afuera: anillos = v fija
			if y == 20 or y == 26 or (y > 21 and y < 25 and x % 6 < 3):
				c = Color(0.24, 0.24, 0.25)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Por dentro: las cuerdas de la tela de la llanta, cafe grisaceo en lineas, con hule pegado
func _cuerdas() -> Texture2D:
	const T := 32
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 72
	for y in T:
		for x in T:
			var c := Color(0.42, 0.37, 0.3) if x % 3 != 0 else Color(0.28, 0.25, 0.2)
			if rnd.randf() > 0.8:
				c = Color(0.14, 0.14, 0.15)
			img.set_pixel(x, y, c.lightened(rnd.randf_range(-0.05, 0.05)))
	return ImageTexture.create_from_image(img)


# Un tubo a lo largo de `puntos` (sin tapas); `radios` (uno por punto) lo adelgaza
# `adentro`: las caras miran hacia adentro (el forro de una manga abierta)
func _tubo(puntos: Array[Vector3], radio: float, lados: int, radios: Array = [], adentro := false) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anillos: Array = []
	for i in puntos.size():
		var adelante := (puntos[mini(i + 1, puntos.size() - 1)] - puntos[maxi(i - 1, 0)]).normalized()
		var lado := adelante.cross(Vector3.UP)
		if lado.length() < 0.01:
			lado = adelante.cross(Vector3.RIGHT)
		lado = lado.normalized()
		var arriba := lado.cross(adelante).normalized()
		var anillo: Array[Vector3] = []
		for k in lados + 1:
			var ang := TAU * k / lados
			var r: float = radios[i] if i < radios.size() else radio
			anillo.append(puntos[i] + (lado * cos(ang) + arriba * sin(ang)) * r)
		anillos.append(anillo)
	for i in puntos.size() - 1:
		for k in lados:
			var a: Vector3 = anillos[i][k]
			var b: Vector3 = anillos[i][k + 1]
			var c: Vector3 = anillos[i + 1][k + 1]
			var d: Vector3 = anillos[i + 1][k]
			var u0 := float(k) / lados
			var u1 := float(k + 1) / lados
			var v0 := float(i) / (puntos.size() - 1)
			var v1 := float(i + 1) / (puntos.size() - 1)
			var tris := [[a, Vector2(u0, v0)], [b, Vector2(u1, v0)], [c, Vector2(u1, v1)],
					[a, Vector2(u0, v0)], [c, Vector2(u1, v1)], [d, Vector2(u0, v1)]]
			if adentro:
				tris = [tris[0], tris[2], tris[1], tris[3], tris[5], tris[4]]
			for par in tris:
				st.set_uv(par[1])
				st.add_vertex(par[0])
	st.generate_normals()
	var m := st.commit()
	return m


# --- Frijol rojo: un punado de frijoles rojos amontonados ---

func _frijol_rojo() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Frijoles"
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 9
	var piel := _frijol_piel()
	for i in 11:
		var grano := SphereMesh.new()
		grano.radius = 0.008
		grano.height = 0.016
		grano.radial_segments = 8
		grano.rings = 4
		var m := MeshInstance3D.new()
		m.name = "Frijol%d" % i
		m.mesh = grano
		m.set_surface_override_material(0, _material(piel))
		# Alargado y aplastado como frijol, cada uno girado a su modo
		m.scale = Vector3(1.6, 0.8, 1.0)
		m.rotation = Vector3(rnd.randf_range(-0.4, 0.4), rnd.randf() * TAU, rnd.randf_range(-0.4, 0.4))
		var ang := rnd.randf() * TAU
		var dist := rnd.randf_range(0.012, 0.04) if i > 1 else 0.004
		m.position = Vector3(cos(ang) * dist, (0.01 if i < 2 else 0.0) + rnd.randf_range(0.0, 0.002), sin(ang) * dist)
		raiz.add_child(m)
	return raiz


# Rojo vino brillante con una manchita blanca (el ojo del frijol)
func _frijol_piel() -> Texture2D:
	const T := 16
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 10
	for y in T:
		for x in T:
			var c := Color(0.36, 0.05, 0.07).lightened(rnd.randf_range(-0.04, 0.06))
			if y < 2:
				c = c.lightened(0.15)
			if x == 8 and (y == 8 or y == 9):
				c = Color(0.9, 0.88, 0.8)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Obsidiana: una piedra negra con facetas (como lasca tallada) y reflejos verdosos ---

func _obsidiana() -> Node3D:
	var m := _malla(_piedra(0.05, Vector3(1.3, 0.75, 1.0), 66), _vidrio_negro())
	# Vidrio: reflejo especular en cada faceta (uniform `brillo` de ps1_combined)
	(m.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.85)
	return m


# Piedra de caras planas: un icosaedro con cada vertice movido al azar
func _piedra(radio: float, forma: Vector3, semilla: int) -> Mesh:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = semilla
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in v.size():
		v[i] = v[i].normalized() * radio * rnd.randf_range(0.7, 1.15) * forma
	var caras := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11],
		[6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)   # caras planas: que se vean las facetas
	for cara in caras:
		# El icosaedro viene en sentido antihorario: Godot quiere el frente horario
		for k in [0, 2, 1]:
			var p: Vector3 = v[cara[k]]
			st.set_uv(Vector2(p.x, p.z) / (radio * 2.5) + Vector2(0.5, 0.5))
			st.add_vertex(p)
	st.generate_normals()
	return st.commit()


# Vidrio volcanico: casi negro con vetas verde botella y unos brillos blancos
func _vidrio_negro() -> Texture2D:
	const T := 32
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 67
	for y in T:
		for x in T:
			var c := Color(0.13, 0.14, 0.15).lightened(rnd.randf_range(0.0, 0.03))
			if absf(y - 10.0 - 4.0 * sin(x * 0.4)) < 1.2 or absf(y - 24.0 - 3.0 * sin(x * 0.3 + 1.0)) < 0.8:
				c = Color(0.08, 0.22, 0.16)
			# Destellos: rayitas diagonales claras, como luz corriendo por el vidrio
			if (x + y) % 11 == 0 and rnd.randf() > 0.55:
				c = Color(0.55, 0.62, 0.62)
			if rnd.randf() > 0.985:
				c = Color(0.85, 0.9, 0.9)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Cuarzo: un racimo de cristales blancos de seis caras con punta, que brillan ---

func _cuarzo() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Racimo"
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 88
	var textura := _cristal()
	# [alto, inclinacion en x, inclinacion en z, giro]
	var cristales := [[0.09, 0.0, 0.0], [0.065, 0.45, 0.1], [0.06, -0.4, 0.3], [0.05, 0.15, -0.55], [0.04, -0.2, -0.5], [0.035, 0.6, 0.6]]
	for i in cristales.size():
		var datos: Array = cristales[i]
		var m := _malla(_prisma(0.012 + datos[0] * 0.12, datos[0]), textura)
		m.name = "Cristal%d" % i
		m.rotation = Vector3(datos[1], rnd.randf() * TAU, datos[2])
		var mat := m.get_surface_override_material(0) as ShaderMaterial
		mat.set_shader_parameter("brillo", 0.9)
		raiz.add_child(m)
	return raiz


# Prisma de seis caras con punta piramidal, parado sobre el origen
func _prisma(radio: float, alto: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var cuerpo := alto * 0.75
	var punta := Vector3(0, alto, 0)
	for k in 6:
		var a0 := TAU * k / 6.0
		var a1 := TAU * (k + 1) / 6.0
		var b0 := Vector3(cos(a0) * radio, 0, sin(a0) * radio)
		var b1 := Vector3(cos(a1) * radio, 0, sin(a1) * radio)
		var t0 := b0 + Vector3(0, cuerpo, 0)
		var t1 := b1 + Vector3(0, cuerpo, 0)
		var u0 := k / 6.0
		var u1 := (k + 1) / 6.0
		# Cara del costado y triangulo de la punta (frente: horario visto desde afuera)
		for par in [[b0, Vector2(u0, 1)], [b1, Vector2(u1, 1)], [t1, Vector2(u1, 0.25)],
				[b0, Vector2(u0, 1)], [t1, Vector2(u1, 0.25)], [t0, Vector2(u0, 0.25)],
				[t0, Vector2(u0, 0.25)], [t1, Vector2(u1, 0.25)], [punta, Vector2((u0 + u1) * 0.5, 0)]]:
			st.set_uv(par[1])
			st.add_vertex(par[0])
	st.generate_normals()
	return st.commit()


# Cuarzo: gris lila translucido con destellos; el reflejo (`brillo`) resalta sobre el tono medio
func _cristal() -> Texture2D:
	const T := 32
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 89
	for y in T:
		for x in T:
			# Gris lila como cristal que deja ver lo de atras; mas claro hacia la punta
			var c := Color(0.5, 0.48, 0.58).lerp(Color(0.78, 0.78, 0.86), 1.0 - float(y) / T)
			c = c.darkened(rnd.randf_range(0.0, 0.06))
			if x % 6 == 0 and rnd.randf() > 0.5:
				c = c.darkened(0.12)
			# Destellos: rayitas diagonales claras (como la obsidiana) y unos puntos blancos
			if (x + y) % 9 == 0 and rnd.randf() > 0.5:
				c = Color(0.92, 0.94, 1.0)
			if rnd.randf() > 0.985:
				c = Color.WHITE
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Plata de Taxco: una barrita (lingote) con el sello 925, brillando como la obsidiana ---

const PLATA_LARGO := 0.08
const PLATA_ANCHO := 0.035
const PLATA_ALTO := 0.014
const PLATA_ANGOSTA := 0.8     # la cara de arriba es mas chica que la de abajo


func _plata_taxco() -> Node3D:
	var abajo := Vector2(PLATA_LARGO, PLATA_ANCHO) * 0.5
	var arriba := abajo * PLATA_ANGOSTA
	var y0 := -PLATA_ALTO * 0.5
	var y1 := PLATA_ALTO * 0.5
	var b := [Vector3(-abajo.x, y0, -abajo.y), Vector3(abajo.x, y0, -abajo.y), Vector3(abajo.x, y0, abajo.y), Vector3(-abajo.x, y0, abajo.y)]
	var t := [Vector3(-arriba.x, y1, -arriba.y), Vector3(arriba.x, y1, -arriba.y), Vector3(arriba.x, y1, arriba.y), Vector3(-arriba.x, y1, arriba.y)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# Arriba (con el sello: toda la textura), abajo y los cuatro lados (una franja lisa de la textura)
	_cara(st, [t[0], t[1], t[2], t[3]], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	_cara(st, [b[3], b[2], b[1], b[0]], [Vector2(0, 0.9), Vector2(0.1, 0.9), Vector2(0.1, 1), Vector2(0, 1)])
	for i in 4:
		var j := (i + 1) % 4
		_cara(st, [b[i], b[j], t[j], t[i]], [Vector2(0, 0.9), Vector2(0.1, 0.9), Vector2(0.1, 1), Vector2(0, 1)])
	st.generate_normals()
	var m := _malla(st.commit(), _plata())
	(m.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.85)
	return m


# Cara de cuatro esquinas en orden horario visto desde afuera (el frente de Godot)
func _cara(st: SurfaceTool, q: Array, uv: Array) -> void:
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uv[k])
		st.add_vertex(q[k])


# Lo mismo con las esquinas en orden antihorario visto desde afuera
func _cara_ccw(st: SurfaceTool, q: Array, uv: Array) -> void:
	for k in [0, 2, 1, 0, 3, 2]:
		st.set_uv(uv[k])
		st.add_vertex(q[k])


# Plata: gris claro frio con rayitas de pulido, y el sello "925" en un recuadro hundido
func _plata() -> Texture2D:
	const W := 48
	const H := 24
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 925
	for y in H:
		for x in W:
			var c := Color(0.62, 0.64, 0.68).lightened(rnd.randf_range(-0.04, 0.06))
			if (x * 2 + y) % 13 == 0:
				c = c.lightened(0.18)
			# Recuadro del sello
			if (x == 12 or x == 35) and y >= 7 and y <= 16 or (y == 7 or y == 16) and x >= 12 and x <= 35:
				c = Color(0.4, 0.42, 0.46)
			img.set_pixel(x, y, c)
	# 925 en pixeles de 3 x 5 (cada digito: filas de arriba a abajo)
	var digitos := {"9": ["111", "101", "111", "001", "111"], "2": ["111", "001", "111", "100", "111"], "5": ["111", "100", "111", "001", "111"]}
	var x0 := 17
	for d in "925":
		for fila in 5:
			for col in 3:
				if digitos[d][fila][col] == "1":
					img.set_pixel(x0 + col, 9 + fila, Color(0.32, 0.34, 0.38))
		x0 += 5
	return ImageTexture.create_from_image(img)


# --- Marca de cazador (trofeo): placa de fierro oxidado con una calavera rayada y su cordon ---

func _marca_cazador() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Marca"
	var placa := _malla(_caja(Vector3(0.045, 0.06, 0.004)), _placa_calavera())
	raiz.add_child(placa)
	var cordon := TorusMesh.new()
	cordon.outer_radius = 0.012
	cordon.inner_radius = 0.009
	cordon.rings = 10
	cordon.ring_segments = 4
	var c := _malla(cordon, _liso(Color(0.3, 0.2, 0.12), 81))
	c.name = "Cordon"
	c.rotation.x = PI / 2.0
	c.position.y = 0.036
	raiz.add_child(c)
	return raiz


# Caja centrada; la cara de enfrente (+Z) lleva toda la textura, las demas una franja de la orilla
func _caja(tam: Vector3) -> Mesh:
	var h := tam * 0.5
	var p := func(x: float, y: float, z: float) -> Vector3: return Vector3(x * h.x, y * h.y, z * h.z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var todo := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	var orilla := [Vector2(0, 1), Vector2(0.05, 1), Vector2(0.05, 0.95), Vector2(0, 0.95)]
	_cara_ccw(st, [p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1)], todo)
	_cara_ccw(st, [p.call(1, -1, -1), p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(1, 1, -1)], orilla)
	_cara_ccw(st, [p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, 1, -1), p.call(-1, 1, -1)], orilla)
	_cara_ccw(st, [p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1), p.call(-1, -1, 1)], orilla)
	_cara_ccw(st, [p.call(1, -1, 1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(1, 1, 1)], orilla)
	_cara_ccw(st, [p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1)], orilla)
	st.generate_normals()
	return st.commit()


# Fierro oxidado, gris con manchas cafe, una calavera rayada en claro y tres rayas de cuenta
func _placa_calavera() -> Texture2D:
	const W := 30
	const H := 40
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 82
	for y in H:
		for x in W:
			var c := Color(0.35, 0.34, 0.33).lightened(rnd.randf_range(-0.05, 0.05))
			if rnd.randf() > 0.8:
				c = Color(0.45, 0.26, 0.14)
			img.set_pixel(x, y, c)
	var calavera := ["0111110", "1111111", "1001001", "1001001", "1111111", "0110110", "0101010"]
	for fila in calavera.size():
		for col in 7:
			if calavera[fila][col] == "1":
				for d in 2:
					for e in 2:
						img.set_pixel(8 + col * 2 + d, 10 + fila * 2 + e, Color(0.78, 0.76, 0.7))
	for k in 3:
		for y in range(28, 35):
			img.set_pixel(10 + k * 4 + (y - 28) / 3, y, Color(0.7, 0.68, 0.62))
	# El hoyo del cordon
	for y in range(2, 5):
		for x in range(13, 17):
			img.set_pixel(x, y, Color(0.08, 0.08, 0.08))
	return ImageTexture.create_from_image(img)


# --- Ojo de turba (trofeo): un ojo de zombi lechoso y con venas en un frasquito con tapa ---

func _ojo_turba() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Frasco"
	var ojo := SphereMesh.new()
	ojo.radius = 0.016
	ojo.height = 0.032
	ojo.radial_segments = 12
	ojo.rings = 6
	var o := _malla(ojo, _ojo_zombi())
	o.name = "Ojo"
	# Que la pupila (la u = 0.25 de la esfera) vea hacia el frente y un poco arriba
	o.rotation = Vector3(-0.3, -PI * 0.5 + 0.5, 0.0)
	o.position.y = 0.002
	raiz.add_child(o)
	var nervio: Array[Vector3] = [Vector3(0, -0.004, -0.014), Vector3(0.004, -0.014, -0.018), Vector3(0.0, -0.022, -0.012)]
	var n := _malla(_tubo(nervio, 0.003, 5), _liso(Color(0.55, 0.25, 0.25), 91))
	n.name = "Nervio"
	raiz.add_child(n)
	# El frasco: vidrio transparente (el shader PS1 no tiene transparencia: material aparte)
	var vidrio := CylinderMesh.new()
	vidrio.top_radius = 0.026
	vidrio.bottom_radius = 0.026
	vidrio.height = 0.06
	vidrio.radial_segments = 10
	var v := MeshInstance3D.new()
	v.name = "Vidrio"
	v.mesh = vidrio
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.9, 0.8, 0.22)
	mat.roughness = 0.1
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	v.material_override = mat
	v.position.y = 0.0
	raiz.add_child(v)
	var tapa := CylinderMesh.new()
	tapa.top_radius = 0.028
	tapa.bottom_radius = 0.028
	tapa.height = 0.01
	tapa.radial_segments = 10
	var t := _malla(tapa, _liso(Color(0.5, 0.45, 0.3), 92))
	t.name = "Tapa"
	t.position.y = 0.035
	raiz.add_child(t)
	return raiz


# Ojo: blanco amarillento con venas rojas, iris gris verdoso nublado y pupila lechosa
func _ojo_zombi() -> Texture2D:
	const W := 48
	const H := 24
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 93
	var centro := Vector2(W * 0.25, H * 0.5)
	for y in H:
		for x in W:
			var c := Color(0.88, 0.85, 0.72).darkened(rnd.randf_range(0.0, 0.08))
			var d := Vector2((x - centro.x) * 0.75, y - centro.y).length()
			if d < 3.6:
				c = Color(0.45, 0.55, 0.5).lightened(rnd.randf_range(0.0, 0.15))
			if d < 1.6:
				c = Color(0.75, 0.78, 0.75)
			img.set_pixel(x, y, c)
	# Venas: caminitos rojos que salen de atras hacia el iris
	for k in 7:
		var p := Vector2(rnd.randf_range(W * 0.55, W * 0.95), rnd.randf_range(0, H))
		for paso in 22:
			if p.x >= 0 and p.x < W and p.y >= 0 and p.y < H:
				img.set_pixel(int(p.x), int(p.y), Color(0.65, 0.1, 0.1))
			p += Vector2(-1.0, rnd.randf_range(-1.0, 1.0))
	return ImageTexture.create_from_image(img)


# --- Tapa del tinaco (trofeo): la tapa negra de rosca, con estrias y una estampita de la Virgen ---

const TAPA_RADIO := 0.11
const TAPA_ALTO := 0.03
const TAPA_LADOS := 24


func _tapa_tinaco() -> Node3D:
	var arriba := SurfaceTool.new()
	var lado := SurfaceTool.new()
	for st in [arriba, lado]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y1 := TAPA_ALTO * 0.5
	var y0 := -y1
	for k in TAPA_LADOS:
		var a0 := TAU * k / TAPA_LADOS
		var a1 := TAU * (k + 1) / TAPA_LADOS
		var p0 := Vector2(cos(a0), sin(a0))
		var p1 := Vector2(cos(a1), sin(a1))
		# Cara de arriba (abanico) con la textura acostada encima, y la de abajo igual
		for tri in [[Vector2.ZERO, p0, p1]]:
			for q: Vector2 in tri:
				arriba.set_uv(q * 0.5 + Vector2(0.5, 0.5))
				arriba.add_vertex(Vector3(q.x * TAPA_RADIO, y1, q.y * TAPA_RADIO))
			for q: Vector2 in [tri[0], tri[2], tri[1]]:
				arriba.set_uv(Vector2(0.02, 0.02))
				arriba.add_vertex(Vector3(q.x * TAPA_RADIO, y0, q.y * TAPA_RADIO))
		var b0 := Vector3(p0.x * TAPA_RADIO, y0, p0.y * TAPA_RADIO)
		var b1 := Vector3(p1.x * TAPA_RADIO, y0, p1.y * TAPA_RADIO)
		var t0 := Vector3(p0.x * TAPA_RADIO, y1, p0.y * TAPA_RADIO)
		var t1 := Vector3(p1.x * TAPA_RADIO, y1, p1.y * TAPA_RADIO)
		var u0 := float(k) / TAPA_LADOS * 6.0
		var u1 := float(k + 1) / TAPA_LADOS * 6.0
		for par in [[b0, Vector2(u0, 1)], [b1, Vector2(u1, 1)], [t1, Vector2(u1, 0)], [b0, Vector2(u0, 1)], [t1, Vector2(u1, 0)], [t0, Vector2(u0, 0)]]:
			lado.set_uv(par[1])
			lado.add_vertex(par[0])
	var malla := ArrayMesh.new()
	var m := MeshInstance3D.new()
	m.name = "Tapa"
	var n := 0
	for par in [[arriba, _tapa_arriba()], [lado, _tapa_estrias()]]:
		var st: SurfaceTool = par[0]
		st.generate_normals()
		st.commit(malla)
		m.mesh = malla
		var mat := _material(par[1])
		m.set_surface_override_material(n, mat)
		n += 1
	return m


# Plastico negro: anillos concentricos, costillas que salen del centro y una estampita de la Virgen
func _tapa_arriba() -> Texture2D:
	const T := 64
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 101
	for y in T:
		for x in T:
			var p := Vector2(x - T / 2.0 + 0.5, y - T / 2.0 + 0.5)
			var r := p.length()
			var c := Color(0.1, 0.1, 0.11).lightened(rnd.randf_range(0.0, 0.04))
			if int(r) in [12, 22, 29]:
				c = Color(0.2, 0.2, 0.21)
			elif r > 12.0 and r < 29.0 and int(rad_to_deg(p.angle()) + 360.0) % 30 < 3:
				c = Color(0.17, 0.17, 0.18)
			# Polvo: manchas cafe claro
			if rnd.randf() > 0.93:
				c = Color(0.35, 0.3, 0.24)
			img.set_pixel(x, y, c)
	# Estampita: ovalo azul con la silueta clara de la Virgen, pegada al centro (ocupa casi el
	# anillo de adentro, para que se vea desde lejos)
	for y in range(14, 50):
		for x in range(20, 44):
			var e := Vector2((x - 31.5) / 11.0, (y - 31.5) / 16.0).length()
			if e < 1.0:
				var c := Color(0.15, 0.3, 0.65)
				var manto := Vector2((x - 31.5) / (2.0 + (y - 24.0) * 0.17), (y - 36.0) / 10.0).length() < 1.0 and y > 25
				var cara := Vector2(x - 31.5, y - 22.0).length() < 2.4
				# Rayos dorados alrededor de la figura
				var rayo := e > 0.62 and int(rad_to_deg(Vector2(x - 31.5, y - 31.5).angle()) + 360.0) % 24 < 6
				if rayo:
					c = Color(0.95, 0.8, 0.3)
				if manto or cara:
					c = Color(0.92, 0.88, 0.72)
				if e > 0.9:
					c = Color(0.85, 0.7, 0.25)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Lado: estrias verticales para agarrarla al girar
func _tapa_estrias() -> Texture2D:
	const T := 16
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	for y in T:
		for x in T:
			img.set_pixel(x, y, Color(0.18, 0.18, 0.19) if x % 4 < 2 else Color(0.07, 0.07, 0.08))
	return ImageTexture.create_from_image(img)


# --- Diente del jefe (trofeo): el colmillo del garrafonero, curvo, amarillo y con sangre en la raiz ---

func _diente_jefe() -> Node3D:
	var puntos: Array[Vector3] = []
	var radios: Array = []
	const N := 10
	for i in N:
		var t := float(i) / (N - 1)
		# Curvo hacia adelante, como colmillo; la raiz mas gruesa y la punta casi en cero
		puntos.append(Vector3(0.0, t * 0.07, sin(t * 1.4) * 0.025))
		radios.append(lerpf(0.012, 0.0008, pow(t, 0.8)))
	var m := _malla(_tubo(puntos, 0.01, 7, radios), _colmillo())
	m.name = "Colmillo"
	# Acostado como cuando se tira al piso
	m.rotation = Vector3(0.0, 0.0, deg_to_rad(70.0))
	return m


# A lo largo (v): raiz con sangre seca, cuerpo amarillo sarro con grietas, punta mas blanca
func _colmillo() -> Texture2D:
	const W := 16
	const H := 32
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 111
	for y in H:
		for x in W:
			var t := float(y) / H
			var c := Color(0.78, 0.7, 0.45).lerp(Color(0.92, 0.9, 0.8), clampf((t - 0.5) * 2.0, 0.0, 1.0))
			c = c.darkened(rnd.randf_range(0.0, 0.08))
			if t < 0.22 + rnd.randf_range(-0.05, 0.05):
				c = Color(0.35, 0.08, 0.06).lightened(rnd.randf_range(0.0, 0.1))
			elif x % 5 == 0 and rnd.randf() > 0.5:
				c = c.darkened(0.25)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Chancla de oro (trofeo): la chancla de models/objetos/chancla, dorada y brillando ---

const CHANCLA_BASE := "res://models/objetos/chancla/chancla.scn"


func _chancla_oro() -> Node3D:
	var modelo := (load(CHANCLA_BASE) as PackedScene).instantiate() as Node3D
	var oro := _oro()
	for malla: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		for s in malla.mesh.get_surface_count():
			var mat := _material(oro)
			mat.set_shader_parameter("brillo", 0.9)
			malla.set_surface_override_material(s, mat)
		malla.material_override = null
	return modelo


# Oro: amarillo dorado con franjas suaves de luz y unos destellos
func _oro() -> Texture2D:
	const T := 128
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 121
	for y in T:
		for x in T:
			# Franjas suaves de luz y sombra en diagonal, como metal pulido
			var franja := 0.5 + 0.5 * sin((x + y) * 0.12)
			var c := Color(0.72, 0.5, 0.1).lerp(Color(0.98, 0.82, 0.35), franja)
			c = c.lightened(rnd.randf_range(-0.025, 0.025))
			if rnd.randf() > 0.996:
				c = Color(1.0, 0.97, 0.8)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Casco de GelA (trofeo): casco de obra blanco con franja azul marino y La Gota (lore.md) ---

func _casco_gela() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Casco"
	var copa := SphereMesh.new()
	copa.radius = 0.11
	copa.height = 0.13
	copa.is_hemisphere = true
	copa.radial_segments = 14
	copa.rings = 5
	var c := _malla(copa, _casco_textura())
	c.name = "Copa"
	c.scale = Vector3(1.0, 1.0, 1.15)
	raiz.add_child(c)
	var ala := CylinderMesh.new()
	ala.top_radius = 0.125
	ala.bottom_radius = 0.13
	ala.height = 0.008
	ala.radial_segments = 14
	var a := _malla(ala, _liso(Color(0.88, 0.9, 0.93), 131))
	a.name = "Ala"
	a.scale = Vector3(1.0, 1.0, 1.25)
	a.position = Vector3(0.0, 0.0, 0.012)
	raiz.add_child(a)
	return raiz


# Blanco azulado con una cresta y una franja azul marino, y La Gota a los dos lados
func _casco_textura() -> Texture2D:
	const W := 64
	const H := 32
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 132
	for y in H:
		for x in W:
			var c := Color(0.9, 0.92, 0.95).darkened(rnd.randf_range(0.0, 0.05))
			# Raspones y mugre de obra
			if rnd.randf() > 0.97:
				c = Color(0.55, 0.5, 0.45)
			# La media esfera solo usa la mitad de arriba de la textura (v de 0 a 0.5): franja abajo de eso
			if y >= H / 2 - 3 and y < H / 2 - 1:
				c = Color(0.16, 0.24, 0.4)
			img.set_pixel(x, y, c)
	for centro_u in [0.125, 0.375, 0.625, 0.875]:
		_gota(img, Vector2(W * centro_u, H * 0.3))
	return ImageTexture.create_from_image(img)


# La Gota: una gota azul con dos ojitos blancos (la mascota de GelA)
func _gota(img: Image, centro: Vector2) -> void:
	# En la esfera la u se estira: la gota se dibuja la mitad de ancha y la esfera la ensancha
	# y la v tambien (la media esfera usa solo la mitad de la textura): la gota va aplastada
	for y in range(-4, 3):
		for x in range(-3, 4):
			# Circulo abajo y punta arriba
			var abajo := Vector2(x * 1.6, (y - 0.5) * 2.2).length() < 4.5
			var punta := y < -1 and absf(x * 1.6) < (y + 4) * 1.6
			if abajo or punta:
				var p := Vector2i(int(centro.x) + x, int(centro.y) + y)
				var color := Color(0.15, 0.45, 0.85)
				if absi(x) == 1 and y == 0:
					color = Color.WHITE
				if y == 1 and x == 0:
					color = Color(0.05, 0.15, 0.35)
				img.set_pixelv(p, color)


# --- Escama de la Madre (trofeo): una placa del lomo de la Madre del Carcamo, con su piel
# (shaders/madre.gdshader: carbon queloide con grietas cian de Serenol) y una espina de punta azul ---

const ESCAMA_LARGO := 0.11
const ESCAMA_ANCHO := 0.08
const ESCAMA_PASOS := 8


func _escama_madre() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Escama"
	var arriba := SurfaceTool.new()
	var abajo := SurfaceTool.new()
	for st in [arriba, abajo]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Rejilla en (u, v) de 0 a 1; la orilla redonda atras y en punta adelante, abombada
	var punto := func(u: float, v: float, lado: float) -> Vector3:
		var ancho := sin(v * PI * 0.85 + 0.15) * (1.0 - v * 0.35)
		var x := (u - 0.5) * ESCAMA_ANCHO * ancho
		var z := (v - 0.5) * ESCAMA_LARGO
		var y := 0.012 * (1.0 - pow((u - 0.5) * 2.0, 2.0)) * sin(v * PI) + lado * 0.003
		return Vector3(x, y, z)
	for i in ESCAMA_PASOS:
		for j in ESCAMA_PASOS:
			var u0 := float(i) / ESCAMA_PASOS
			var u1 := float(i + 1) / ESCAMA_PASOS
			var v0 := float(j) / ESCAMA_PASOS
			var v1 := float(j + 1) / ESCAMA_PASOS
			var esquinas := [[u0, v0], [u1, v0], [u1, v1], [u0, v1]]
			for par in [[arriba, 1.0, [0, 1, 2, 0, 2, 3]], [abajo, -1.0, [0, 2, 1, 0, 3, 2]]]:
				for k: int in par[2]:
					var e: Array = esquinas[k]
					par[0].set_uv(Vector2(e[0], e[1]))
					par[0].add_vertex(punto.call(e[0], e[1], par[1]))
	var malla := ArrayMesh.new()
	var m := MeshInstance3D.new()
	m.name = "Placa"
	var texturas := [_piel_madre(), _liso(Color(0.3, 0.12, 0.12), 141)]
	for n in 2:
		var st: SurfaceTool = [arriba, abajo][n]
		st.generate_normals()
		st.commit(malla)
		m.mesh = malla
		m.set_surface_override_material(n, _material(texturas[n]))
	raiz.add_child(m)
	# La espina: un cono carbon con la punta azul que brilla (sin_sombra)
	var espina := CylinderMesh.new()
	espina.top_radius = 0.0
	espina.bottom_radius = 0.009
	espina.height = 0.035
	espina.radial_segments = 6
	var cuerpo := _malla(espina, _espina_madre())
	cuerpo.name = "Espina"
	cuerpo.rotation.x = -0.6
	cuerpo.position = Vector3(0.0, 0.025, 0.005)
	raiz.add_child(cuerpo)
	return raiz


# Piel de la Madre: celdas de queloide carbon (Voronoi en la rejilla) con grietas cian entre celdas
func _piel_madre() -> Texture2D:
	const T := 48
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 142
	var centros: Array[Vector2] = []
	for k in 14:
		centros.append(Vector2(rnd.randf() * T, rnd.randf() * T))
	for y in T:
		for x in T:
			var p := Vector2(x, y)
			var d1 := INF
			var d2 := INF
			for c in centros:
				var d := p.distance_to(c)
				if d < d1:
					d2 = d1
					d1 = d
				elif d < d2:
					d2 = d
			var color := Color(0.25, 0.27, 0.28).lightened(clampf(d1 / 14.0, 0.0, 0.25) * -1.0 + 0.12)
			if d2 - d1 < 1.3:
				color = Color(0.18, 0.77, 1.0)   # #2EC4FF
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


# Espina: carbon abajo y azul brillante en la punta (la v de CylinderMesh va de arriba a abajo)
func _espina_madre() -> Texture2D:
	var img := Image.create(8, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		for x in 8:
			img.set_pixel(x, y, Color(0.35, 0.8, 1.0) if y < 5 else Color(0.2, 0.22, 0.23))
	return ImageTexture.create_from_image(img)


# --- Corona de flores (trofeo de la Mojiganga): aro de alambre con cempasuchiles, terciopelo
# morado y hojas. La de su modelo (catrina/corona.glb) trae una textura deslavada que no se lee ---

const CORONA_RADIO := 0.09
const CORONA_FLORES := 10


func _corona_flores() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Corona"
	var aro := TorusMesh.new()
	aro.inner_radius = CORONA_RADIO - 0.004
	aro.outer_radius = CORONA_RADIO + 0.004
	aro.rings = 16
	aro.ring_segments = 4
	var a := _malla(aro, _liso(Color(0.22, 0.3, 0.14), 151))
	a.name = "Aro"
	raiz.add_child(a)
	var petalos := [_petalos(Color(1.0, 0.55, 0.05), 152), _petalos(Color(1.0, 0.78, 0.1), 153), _petalos(Color(0.62, 0.1, 0.4), 154)]
	var hoja := _liso(Color(0.2, 0.42, 0.15), 155)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 156
	for k in CORONA_FLORES:
		var ang := TAU * k / CORONA_FLORES
		var centro := Vector3(cos(ang), 0.0, sin(ang)) * CORONA_RADIO
		var flor := SphereMesh.new()
		var grande := 0.022 if k % 3 != 2 else 0.016
		flor.radius = grande
		flor.height = grande * 1.5
		flor.radial_segments = 7
		flor.rings = 4
		# Cempasuchil naranja y amarillo; cada tercera, una mano de leon morada
		var f := _malla(flor, petalos[2] if k % 3 == 2 else petalos[k % 2])
		f.name = "Flor%d" % k
		f.position = centro + Vector3(0.0, 0.01, 0.0)
		f.rotation = Vector3(rnd.randf_range(-0.3, 0.3), rnd.randf() * TAU, rnd.randf_range(-0.3, 0.3))
		raiz.add_child(f)
		# Dos hojas entre flor y flor
		var hm := BoxMesh.new()
		hm.size = Vector3(0.028, 0.002, 0.012)
		var h := _malla(hm, hoja)
		h.name = "Hoja%d" % k
		var entre := ang + TAU / CORONA_FLORES * 0.5
		h.position = Vector3(cos(entre), 0.0, sin(entre)) * CORONA_RADIO
		h.rotation = Vector3(0.0, -entre, 0.35)
		raiz.add_child(h)
	return raiz


# Petalos: el color con anillitos de sombra (las capas de la flor) y puntos claros
func _petalos(color: Color, semilla: int) -> Texture2D:
	const T := 16
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = semilla
	for y in T:
		for x in T:
			var c := color.darkened(0.25) if (x + y * 2) % 4 == 0 else color
			if rnd.randf() > 0.85:
				c = color.lightened(0.3)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Machetes (armas de filo I a IV): un machete propio en codigo, de hoja larga y ancha que
# se ensancha hacia la punta (el de models/armas/machete parece cuchillo de cocina). Cada tier
# cambia la hoja (largo, ancho, oxido) y le pone lo suyo al mango ---

const MACHETE_MANGO := 0.13
const MACHETE_GRUESO := 0.005


func _machete_oxidado() -> Node3D:
	return _machete({"largo": 0.4, "ancho": 0.05, "oxido": 0.5, "semilla": 171})


# Reforzado: sin oxido, un tramo de varilla soldado al lomo y el mango forrado de cinta de aislar
func _machete_reforzado() -> Node3D:
	return _machete({"largo": 0.42, "ancho": 0.052, "semilla": 181, "lomo": true, "cinta": true})


# Cañero (JJ, con foto de un machete de sierra de ferreteria): hoja recta negra con el filo
# plateado que al final sube a la punta, dientes de sierra en el lomo, mango de hule negro con
# tapa naranja, tornillos y cordon negro para la muñeca
func _machete_canero() -> Node3D:
	return _machete({"largo": 0.48, "ancho": 0.048, "semilla": 191, "forma": "sierra", "brillo": 0.6,
		"acero": Color(0.09, 0.09, 0.1), "mango": "hule", "remache": Color(0.6, 0.62, 0.65), "correa": true})


# Machetón del 84 (JJ): el cañero de sierra mas grande, con la hoja de cobalto 60 (el de Juarez
# del 84): carbon con vetas azules que brillan solas (sin_sombra), el filo y los dientes azul
# claro, tapa amarilla con el trebol de radiacion y la misma luz chica del Cobalto 84 tirado
func _macheton_84() -> Node3D:
	var m := _machete({"largo": 0.6, "ancho": 0.062, "semilla": 84, "forma": "sierra", "cobalto": true,
		"acero": Color(0.12, 0.13, 0.15), "mango": "hule", "remache": Color(0.6, 0.62, 0.65), "correa": true,
		"tapa": Color(0.95, 0.8, 0.1)})
	var luz := OmniLight3D.new()
	luz.name = "LuzPiso"   # quitarla en el inventario y en la mano, como la del Cobalto 84
	luz.light_color = Color(0.3, 0.6, 1.0)
	luz.light_energy = 1.0
	luz.omni_range = 1.5
	luz.shadow_enabled = false
	luz.position.x = 0.3
	m.add_child(luz)
	return m


# Hoja en el plano XY (x a lo largo, y hacia el lomo); el mango en x negativa
func _machete(estilo: Dictionary) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Machete"
	var largo: float = estilo["largo"]
	var ancho: float = estilo["ancho"]
	# Contorno antihorario: filo abajo (casi recto), punta curva arriba, lomo que baja al mango
	var contorno := PackedVector2Array([
		Vector2(0.0, -ancho * 0.45), Vector2(largo * 0.5, -ancho * 0.55), Vector2(largo * 0.85, -ancho * 0.6),
		Vector2(largo, -ancho * 0.2), Vector2(largo * 0.97, ancho * 0.25), Vector2(largo * 0.85, ancho * 0.45),
		Vector2(largo * 0.5, ancho * 0.4), Vector2(0.0, ancho * 0.35)])
	var marco := Rect2(0.0, -ancho * 0.6, largo, ancho * 1.05)
	var filo: Array = []   # si la forma lo pide, el filo claro va aparte siguiendo estos puntos
	if estilo.get("forma", "") == "canero":
		var w := ancho * 0.5
		# Filo (y negativa): recto y al final se curva hacia atras hasta la punta; lomo (y positiva):
		# la panza ancha que da la vuelta y baja a la punta (JJ, con foto de un cañero de ferreteria)
		contorno = PackedVector2Array([
			Vector2(0.0, -w), Vector2(largo * 0.5, -w), Vector2(largo * 0.76, -w * 1.1),
			Vector2(largo * 0.86, -w * 1.7), Vector2(largo * 0.92, -w * 2.8), Vector2(largo * 0.955, -w * 4.6),
			Vector2(largo * 0.995, -w * 2.6), Vector2(largo, -w * 0.4), Vector2(largo * 0.98, w * 1.4),
			Vector2(largo * 0.93, w * 2.7), Vector2(largo * 0.86, w * 3.4), Vector2(largo * 0.76, w * 3.4),
			Vector2(largo * 0.66, w * 2.8), Vector2(largo * 0.55, w * 2.0), Vector2(largo * 0.4, w * 1.3),
			Vector2(0.0, w)])
		filo = [contorno[0], contorno[1], contorno[2], contorno[3], contorno[4], contorno[5]]
		marco = Rect2(0.0, -w * 4.7, largo, w * 8.2)
	elif estilo.get("forma", "") == "sierra":
		# Filo (y negativa) recto y en el ultimo tramo sube curvo a la punta, que queda en el lomo;
		# el lomo recto con dientes de sierra de la guarda a casi la punta
		var w := ancho * 0.5
		var puntos: Array[Vector2] = [Vector2(0.0, -w), Vector2(largo * 0.8, -w)]
		for k in range(1, 7):
			var a := PI * 0.5 * k / 6.0
			puntos.append(Vector2(largo * 0.8 + largo * 0.2 * sin(a), -w + w * 2.0 * (1.0 - cos(a))))
		filo = puntos.duplicate()
		var diente := 0.014
		var x := largo * 0.9
		while x > largo * 0.08:
			puntos.append(Vector2(x, w))
			puntos.append(Vector2(x - diente * 0.5, w + 0.006))
			x -= diente
		puntos.append(Vector2(0.0, w))
		contorno = PackedVector2Array(puntos)
		marco = Rect2(0.0, -w, largo, w * 2.0 + 0.006)
	var hoja := _extruir(contorno, MACHETE_GRUESO, marco)
	var mh := _malla(hoja, _hoja_machete(estilo))
	(mh.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", estilo.get("brillo", 0.0))
	if estilo.get("cobalto", false):
		(mh.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("sin_sombra", true)
	raiz.add_child(mh)
	if not filo.is_empty():
		var puntos: Array[Vector3] = []
		for p: Vector2 in filo:
			puntos.append(Vector3(p.x, p.y, 0.0))
		var cobalto: bool = estilo.get("cobalto", false)
		var f := _malla(_tubo(puntos, MACHETE_GRUESO * 0.6, 4), _liso(Color(0.55, 0.85, 1.0) if cobalto else Color(0.9, 0.92, 0.95), 193))
		f.name = "Filo"
		(f.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.9)
		(f.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("sin_sombra", cobalto)
		raiz.add_child(f)
	# Mango de madera con dos remaches, y la guarda (un tope de fierro entre hoja y mango)
	var hule: bool = estilo.get("mango", "") == "hule"
	var tam_mango := Vector3(MACHETE_MANGO, ancho * 0.75, MACHETE_GRUESO * 5.0) if hule else Vector3(MACHETE_MANGO, ancho * 0.6, MACHETE_GRUESO * 4.0)
	var mango := _malla(_caja(tam_mango), _hule_mango() if hule else _madera_mango(estilo))
	mango.name = "Mango"
	mango.position.x = -MACHETE_MANGO * 0.5
	raiz.add_child(mango)
	# Los remaches quedan abajo de la cinta cuando el mango va forrado
	for k in (0 if estilo.get("cinta", false) else 2):
		var remache := CylinderMesh.new()
		remache.top_radius = 0.004
		remache.bottom_radius = 0.004
		remache.height = tam_mango.z + 0.0008
		remache.radial_segments = 6
		var r := _malla(remache, _liso(estilo.get("remache", Color(0.7, 0.68, 0.62)), 172))
		r.rotation.x = PI / 2.0
		r.position.x = -MACHETE_MANGO * (0.3 + k * 0.45)
		raiz.add_child(r)
	if estilo.get("cinta", false):
		# Vueltas de cinta de aislar: tiras un poco mas gruesas que el mango, inclinadas como espiral
		# y encimadas, dejando ver la madera en las puntas; la ultima con la punta suelta colgando
		var negra := _cinta_aislar()
		const VUELTAS := 9
		for k in VUELTAS:
			var tira := _malla(_caja(Vector3(0.016, ancho * 0.6 + 0.002, MACHETE_GRUESO * 4.0 + 0.002)), negra)
			tira.name = "Cinta%d" % k
			tira.position.x = -MACHETE_MANGO * (0.12 + 0.76 * k / (VUELTAS - 1))
			tira.rotation.z = 0.15
			raiz.add_child(tira)
		var suelta := _malla(_caja(Vector3(0.012, 0.026, 0.0008)), negra)
		suelta.name = "CintaSuelta"
		suelta.position = Vector3(-MACHETE_MANGO * 0.88, -ancho * 0.3 - 0.012, MACHETE_GRUESO * 2.0 + 0.0015)
		suelta.rotation = Vector3(0.25, 0.0, 0.35)
		raiz.add_child(suelta)
	if estilo.get("correa", false):
		# Correa de cuero para colgarlo de la muñeca, pasada por un hoyo en la cola del mango
		var correa := TorusMesh.new()
		correa.inner_radius = 0.016
		correa.outer_radius = 0.02
		correa.rings = 10
		correa.ring_segments = 4
		var c := _malla(correa, _liso(Color(0.06, 0.06, 0.07) if hule else Color(0.35, 0.2, 0.1), 192))
		c.name = "Correa"
		c.rotation = Vector3(PI / 2.0, 0.0, 0.3)
		c.position = Vector3(-MACHETE_MANGO - 0.014, 0.0, 0.0)
		if hule:
			# Cordon largo que sale de la tapa y cuelga en un ojo alargado: el aro va en un nodo
			# girado, para estirarlo a lo largo y luego colgarlo hacia abajo y atras
			correa.inner_radius = 0.015
			correa.outer_radius = 0.018
			var cuelga := Node3D.new()
			cuelga.name = "Cordon"
			cuelga.position = Vector3(-MACHETE_MANGO - 0.014, 0.0, 0.0)
			cuelga.rotation.z = 0.9
			raiz.add_child(cuelga)
			c.scale = Vector3(2.4, 1.0, 1.0)
			c.rotation = Vector3(PI / 2.0, 0.0, 0.0)
			c.position = Vector3(-0.04, 0.0, 0.0)
			cuelga.add_child(c)
		else:
			raiz.add_child(c)
	if estilo.get("lomo", false):
		# La varilla soldada sigue el lomo, de la guarda a antes de la punta, con cordon de soldadura
		var lomo: Array[Vector3] = []
		for p: Vector2 in [Vector2(0.005, ancho * 0.35), Vector2(largo * 0.5, ancho * 0.4), Vector2(largo * 0.82, ancho * 0.45)]:
			lomo.append(Vector3(p.x, p.y + 0.002, 0.0))
		var v := _malla(_tubo(lomo, 0.0035, 6), _soldadura())
		v.name = "Refuerzo"
		raiz.add_child(v)
	var guarda := _malla(_caja(Vector3(0.008, ancho * 0.8, MACHETE_GRUESO * 5.0)), _liso(Color(0.3, 0.3, 0.3), 173))
	guarda.name = "Guarda"
	if hule:
		guarda = _malla(_caja(Vector3(0.012, ancho * 0.85, MACHETE_GRUESO * 5.5)), _liso(Color(0.08, 0.08, 0.09), 174))
		guarda.name = "Guarda"
		# La tapa naranja en la cola del mango, un poco mas gruesa
		var tapa := _malla(_caja(Vector3(0.018, ancho * 0.85, MACHETE_GRUESO * 5.8)), _tapa_mango(estilo))
		tapa.name = "TapaNaranja"
		tapa.position.x = -MACHETE_MANGO - 0.006
		raiz.add_child(tapa)
	raiz.add_child(guarda)
	return raiz


# --- Tubo (linea pesada I, antes del marro: JJ): un tramo de tubo galvanizado de 3/4 ("ya no
# lleva agua") con un codo de fierro enroscado en la punta, que le da el peso, y el agarre
# amarrado con tiras de camara de llanta (la secundaria es Hule). Agarre en x negativa, el codo
# en el origen ---

const TUBO_LARGO := 0.42
const TUBO_RADIO := 0.0134
const TUBO_HUECO := 0.0105      # radio de adentro: se ve hueco por las puntas


func _tubo_fierro() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Tubo"
	var puntos: Array[Vector3] = []
	const PASOS := 12
	for i in PASOS + 1:
		puntos.append(Vector3(-TUBO_LARGO + TUBO_LARGO * i / PASOS, 0.0, 0.0))
	var cuerpo := _malla(_tubo(puntos, TUBO_RADIO, 10), _galvanizado())
	cuerpo.name = "Cuerpo"
	(cuerpo.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.2)
	raiz.add_child(cuerpo)
	# El codo: un cuarto de vuelta mas grueso (fierro colado) y un pedacito de tubo que sale de el
	# (la curva se arma acostada en xz y se para con el nodo: _tubo tuerce los anillos cuando el
	# tramo apunta hacia arriba)
	var curva: Array[Vector3] = []
	const R := 0.026
	for k in 7:
		var a := PI * 0.5 * k / 6.0
		curva.append(Vector3(sin(a) * R, 0.0, -(R - cos(a) * R)))
	var codo := _malla(_tubo(curva, TUBO_RADIO * 1.4, 10), _fierro_colado())
	codo.name = "Codo"
	codo.rotation.x = PI / 2.0
	(codo.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.2)
	raiz.add_child(codo)
	# Las bocas del codo, un poco mas anchas (donde enrosca)
	for boca: Array in [[Vector3(-0.004, 0.0, 0.0), Vector3(0.006, 0.0, 0.0)], [Vector3(R, R - 0.006, 0.0), Vector3(R, R + 0.004, 0.0)]]:
		var b := _malla(_tubo([boca[0], boca[1]] as Array[Vector3], TUBO_RADIO * 1.55, 10), _fierro_colado())
		b.name = "Boca"
		raiz.add_child(b)
	var salida: Array[Vector3] = [Vector3(R, R, 0.0), Vector3(R, R + 0.035, 0.0)]
	var niple := _malla(_tubo(salida, TUBO_RADIO, 10), _galvanizado())
	niple.name = "Niple"
	raiz.add_child(niple)
	# Lo hueco: un disco oscuro metido en cada punta abierta
	for hueco: Array in [[Vector3(-TUBO_LARGO + 0.003, 0.0, 0.0), Vector3(0.0, 0.0, PI / 2.0)], [Vector3(R, R + 0.032, 0.0), Vector3.ZERO]]:
		var disco := CylinderMesh.new()
		disco.top_radius = TUBO_HUECO
		disco.bottom_radius = TUBO_HUECO
		disco.height = 0.004
		disco.radial_segments = 10
		var d := _malla(disco, _liso(Color(0.08, 0.07, 0.06), 241))
		d.name = "Hueco"
		d.position = hueco[0]
		d.rotation = hueco[1]
		raiz.add_child(d)
	# Agarre: vueltas de camara de llanta, cada una un anillo corto un poco inclinado y encimado
	var hule := _camara_llanta()
	const VUELTAS := 8
	for k in VUELTAS:
		var x := -TUBO_LARGO + 0.012 + 0.017 * k
		var vuelta := _malla(_tubo([Vector3(-0.0105, 0.0, 0.0), Vector3(0.0105, 0.0, 0.0)] as Array[Vector3], TUBO_RADIO + 0.0022, 10), hule)
		vuelta.name = "Hule%d" % k
		vuelta.rotation.z = 0.12 if k % 2 == 0 else -0.08
		vuelta.position.x = x
		raiz.add_child(vuelta)
	# El amarre: la punta de la tira que cuelga del ultimo nudo
	var punta := _malla(_caja(Vector3(0.012, 0.04, 0.0015)), hule)
	punta.name = "Amarre"
	punta.position = Vector3(-TUBO_LARGO + 0.012 + 0.017 * VUELTAS, -TUBO_RADIO - 0.016, TUBO_RADIO * 0.6)
	punta.rotation = Vector3(0.3, 0.0, -0.25)
	raiz.add_child(punta)
	return raiz


# Galvanizado: gris claro con las manchas del zinc (claras y oscuras), polvo blanco del zinc
# oxidado, puntos de oxido y la cuerda oxidada en las puntas (v cerca de 0 y 1)
func _galvanizado() -> Texture2D:
	const W := 16
	const H := 48
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 251
	var zinc := FastNoiseLite.new()
	zinc.seed = 251
	zinc.frequency = 0.25
	for y in H:
		var v := float(y) / (H - 1)
		for x in W:
			var c := Color(0.47, 0.48, 0.48).lightened(zinc.get_noise_2d(x, y) * 0.15 + rnd.randf_range(-0.03, 0.03))
			if rnd.randf() > 0.96:
				c = Color(0.7, 0.7, 0.67)
			if rnd.randf() > 0.97 or ((v < 0.04 or v > 0.96) and rnd.randf() > 0.4):
				c = Color(0.48, 0.26, 0.1).lerp(Color(0.6, 0.34, 0.14), rnd.randf())
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Fierro colado del codo: gris oscuro rugoso con algo de oxido
func _fierro_colado() -> Texture2D:
	const T := 16
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 261
	for y in T:
		for x in T:
			var c := Color(0.25, 0.25, 0.26).lightened(rnd.randf_range(-0.05, 0.07))
			if rnd.randf() > 0.82:
				c = Color(0.42, 0.22, 0.09).lerp(Color(0.55, 0.3, 0.12), rnd.randf())
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Camara de llanta: hule negro mate con rayitas grises de tanto uso
func _camara_llanta() -> Texture2D:
	const T := 16
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 271
	for y in T:
		for x in T:
			var c := Color(0.07, 0.07, 0.075).lightened(rnd.randf_range(0.0, 0.04))
			if y % 5 == 0 and rnd.randf() > 0.5:
				c = Color(0.2, 0.2, 0.21)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Bate con clavos (linea pesada III): bate de madera barnizada, gastado y manchado, con
# clavos atravesados en la parte gruesa (las puntas afuera, algunos doblados) y el agarre
# forrado con un trapo de franela mugroso (la secundaria es Tela). Agarre en x negativa ---

const BATE_CLAVOS := 14


func _bate_clavos() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Bate"
	# [x, radio]: la perilla, el puño delgado y el barril que engorda hacia la punta
	var perfil := [[-0.4, 0.017], [-0.396, 0.022], [-0.386, 0.022], [-0.376, 0.013], [-0.3, 0.012],
		[-0.2, 0.0125], [-0.1, 0.015], [-0.02, 0.019], [0.06, 0.024], [0.14, 0.028], [0.22, 0.03],
		[0.29, 0.03], [0.315, 0.027], [0.325, 0.02]]
	var puntos: Array[Vector3] = []
	var radios: Array = []
	# Puntos cada ~2 cm (la v de _tubo va por punto: si no, la textura se estira en el barril)
	for i in perfil.size() - 1:
		var a: Array = perfil[i]
		var b: Array = perfil[i + 1]
		var n := maxi(1, int((b[0] - a[0]) / 0.02))
		for j in n:
			var t := float(j) / n
			puntos.append(Vector3(lerpf(a[0], b[0], t), 0.0, 0.0))
			radios.append(lerpf(a[1], b[1], t))
	puntos.append(Vector3(perfil[-1][0], 0.0, 0.0))
	radios.append(perfil[-1][1])
	var cuerpo := _malla(_tubo(puntos, 0.02, 10, radios), _madera_bate())
	cuerpo.name = "Cuerpo"
	(cuerpo.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.3)
	raiz.add_child(cuerpo)
	# Tapas de las dos puntas (el tubo sale abierto)
	for tapa: Array in [[-0.4, 0.017], [0.325, 0.02]]:
		var disco := CylinderMesh.new()
		disco.top_radius = tapa[1]
		disco.bottom_radius = tapa[1]
		disco.height = 0.002
		disco.radial_segments = 10
		var d := _malla(disco, _liso(Color(0.5, 0.34, 0.18), 281))
		d.name = "Tapa"
		d.rotation.z = PI / 2.0
		d.position.x = tapa[0]
		raiz.add_child(d)
	# Clavos: salen del barril en angulos al azar; los doblados llevan un tercer punto chueco
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 291
	var fierro := _clavo()
	for k in BATE_CLAVOS:
		var x := 0.07 + 0.22 * (k + rnd.randf_range(-0.3, 0.3)) / (BATE_CLAVOS - 1)
		var radio := 0.024 + 0.006 * clampf((x - 0.06) / 0.16, 0.0, 1.0)
		var ang := k * 2.4 + rnd.randf_range(-0.3, 0.3)
		var sale := Vector3(0.0, cos(ang), sin(ang))
		var largo := rnd.randf_range(0.04, 0.055)
		var clavo: Array[Vector3] = [Vector3(x, 0.0, 0.0) + sale * radio * 0.6, Vector3(x, 0.0, 0.0) + sale * (radio + largo * 0.6)]
		var gruesos := [0.0028, 0.0028, 0.0009]
		if k % 4 == 1:
			clavo.append(clavo[1] + (sale * 0.4 + Vector3(rnd.randf_range(-1.0, 1.0), 0.0, 0.0)).normalized() * largo * 0.45)
		else:
			clavo.append(Vector3(x, 0.0, 0.0) + sale * (radio + largo))
		var c := _malla(_tubo(clavo, 0.0028, 4, gruesos), fierro)
		c.name = "Clavo%d" % k
		(c.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.5)
		raiz.add_child(c)
		# La cabeza del clavo del otro lado, al ras de la madera
		var cabeza := CylinderMesh.new()
		cabeza.top_radius = 0.005
		cabeza.bottom_radius = 0.005
		cabeza.height = 0.0012
		cabeza.radial_segments = 6
		var h := _malla(cabeza, fierro)
		h.name = "Cabeza%d" % k
		h.position = Vector3(x, 0.0, 0.0) - sale * (radio - 0.0002)
		h.basis = Basis(Quaternion(Vector3.UP, -sale))
		h.position = Vector3(x, 0.0, 0.0) - sale * (radio - 0.0002)
		raiz.add_child(h)
	# Agarre: vueltas de trapo encimadas sobre el puño, y la punta del trapo colgando
	var trapo := _trapo_bate()
	const VUELTAS := 7
	for k in VUELTAS:
		var x := -0.37 + 0.022 * k
		var vuelta := _malla(_tubo([Vector3(-0.013, 0.0, 0.0), Vector3(0.013, 0.0, 0.0)] as Array[Vector3], 0.0155, 10), trapo)
		vuelta.name = "Trapo%d" % k
		vuelta.rotation.z = 0.14 if k % 2 == 0 else -0.1
		vuelta.position.x = x
		raiz.add_child(vuelta)
	var cola := _malla(_caja(Vector3(0.018, 0.055, 0.0015)), trapo)
	cola.name = "PuntaTrapo"
	cola.position = Vector3(-0.37 + 0.022 * VUELTAS, -0.035, 0.012)
	cola.rotation = Vector3(0.35, 0.0, -0.3)
	raiz.add_child(cola)
	return raiz


# Madera de bate: clara barnizada (u alrededor, v a lo largo por punto del perfil), vetas a lo
# largo, raspones claros donde ha pegado y manchas oscuras de sangre seca hacia el barril
func _madera_bate() -> Texture2D:
	const W := 16
	const H := 48
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 301
	var mancha := FastNoiseLite.new()
	mancha.seed = 302
	mancha.frequency = 0.18
	var vetas: Array[float] = []
	for x in W:
		vetas.append(rnd.randf_range(-0.06, 0.06))
	for y in H:
		var v := float(y) / (H - 1)
		for x in W:
			var c := Color(0.62, 0.42, 0.22).lightened(vetas[x] + rnd.randf_range(-0.03, 0.03))
			if (x * 3 + y / 5) % 6 == 0:
				c = c.darkened(0.15)
			if v > 0.55 and rnd.randf() > 0.97:
				c = Color(0.8, 0.68, 0.5)
			if v > 0.5 and mancha.get_noise_2d(x, y) > 0.5:
				c = Color(0.3, 0.07, 0.05).lightened(rnd.randf_range(0.0, 0.08))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Fierro del clavo: gris con oxido
func _clavo() -> Texture2D:
	const T := 8
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 311
	for y in T:
		for x in T:
			var c := Color(0.55, 0.56, 0.58).lightened(rnd.randf_range(-0.08, 0.08))
			if rnd.randf() > 0.7:
				c = Color(0.5, 0.27, 0.11)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Trapo del agarre: franela amarilla (la Tela) ya mugrosa, con la trama y manchas de mugre
func _trapo_bate() -> Texture2D:
	const T := 16
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 321
	for y in T:
		for x in T:
			var c := Color(0.78, 0.62, 0.2)
			if (x + y) % 2 == 0:
				c = c.darkened(0.08)
			c = c.darkened(rnd.randf_range(0.05, 0.35))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Fémur de Mojiganga con púas de cobalto (linea pesada IV): el femur de carrizo y papel
# mache de La Mojiganga (femur_catrina.tres), hueso pintado con el periodico asomando en las
# cuarteaduras (cafe de hueso viejo: JJ), con puas de cobalto 60 clavadas en la punta gruesa (los condilos), que brillan
# solas como el Cobalto 84, y tres cempasuchiles amarrados en el cuello (la Corona de flores de
# la receta). Se agarra de la cabeza del femur (x negativa); los condilos pegan ---

const FEMUR_PUAS := 18


func _femur_cobalto() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Femur"
	var hueso := _hueso_mache()
	var bola_tex := _hueso_bola()
	# La cana del hueso: delgada en medio, ensanchando hacia las dos puntas
	var perfil := [[-0.3, 0.026], [-0.26, 0.022], [-0.18, 0.019], [-0.06, 0.0175], [0.06, 0.019],
		[0.16, 0.023], [0.24, 0.03], [0.28, 0.036]]
	var puntos: Array[Vector3] = []
	var radios: Array = []
	for i in perfil.size() - 1:
		var a: Array = perfil[i]
		var b: Array = perfil[i + 1]
		var n := maxi(1, int((b[0] - a[0]) / 0.02))
		for j in n:
			var t := float(j) / n
			puntos.append(Vector3(lerpf(a[0], b[0], t), 0.0, 0.0))
			radios.append(lerpf(a[1], b[1], t))
	puntos.append(Vector3(perfil[-1][0], 0.0, 0.0))
	radios.append(perfil[-1][1])
	var cana := _malla(_tubo(puntos, 0.015, 8, radios), hueso)
	cana.name = "Cana"
	raiz.add_child(cana)
	# Condilos: dos bolas lado a lado en la punta que pega, y la cabeza del femur con su cuello
	# chueco y el trocanter en la otra
	for bola: Array in [[Vector3(0.3, 0.021, 0.0), 0.033], [Vector3(0.3, -0.021, 0.0), 0.031],
			[Vector3(-0.36, 0.034, 0.0), 0.029], [Vector3(-0.3, -0.016, 0.0), 0.025]]:
		var esfera := SphereMesh.new()
		esfera.radius = bola[1]
		esfera.height = bola[1] * 2.0
		esfera.radial_segments = 8
		esfera.rings = 5
		var m := _malla(esfera, bola_tex)
		m.name = "Bola"
		m.position = bola[0]
		raiz.add_child(m)
	var cuello := _malla(_tubo([Vector3(-0.3, 0.0, 0.0), Vector3(-0.355, 0.032, 0.0)] as Array[Vector3], 0.017, 8), hueso)
	cuello.name = "Cuello"
	raiz.add_child(cuello)
	# Puas de cobalto: prismas con punta (los del cuarzo) clavados hacia afuera en la punta gruesa
	var cobalto := _cobalto()
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 331
	for k in FEMUR_PUAS:
		var x := 0.06 + 0.23 * k / (FEMUR_PUAS - 1)
		var ang := k * 2.4 + rnd.randf_range(-0.25, 0.25)
		var sale := Vector3(rnd.randf_range(0.0, 0.35), cos(ang), sin(ang)).normalized()
		var radio := 0.019 + 0.017 * clampf((x - 0.06) / 0.23, 0.0, 1.0)
		var alto := rnd.randf_range(0.028, 0.042)   # cortas (JJ)
		var pua := _malla(_prisma(0.008, alto), cobalto)
		pua.name = "Pua%d" % k
		var mat := pua.get_surface_override_material(0) as ShaderMaterial
		mat.set_shader_parameter("sin_sombra", true)
		mat.set_shader_parameter("brillo", 0.8)
		pua.basis = Basis(Quaternion(Vector3.UP, sale))
		pua.position = Vector3(x, 0.0, 0.0) + sale * (radio * 0.6)
		raiz.add_child(pua)
	# Una pua grande en la punta, entre los condilos
	var grande := _malla(_prisma(0.01, 0.045), cobalto)
	grande.name = "PuaPunta"
	(grande.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("sin_sombra", true)
	grande.basis = Basis(Quaternion(Vector3.UP, Vector3.RIGHT))
	grande.position = Vector3(0.32, 0.0, 0.0)
	raiz.add_child(grande)
	# Tres cempasuchiles amarrados con un cordon verde en el cuello del femur
	var amarre := TorusMesh.new()
	amarre.inner_radius = 0.0205
	amarre.outer_radius = 0.0235
	amarre.rings = 10
	amarre.ring_segments = 4
	var cordon := _malla(amarre, _liso(Color(0.22, 0.3, 0.14), 341))
	cordon.name = "Cordon"
	cordon.rotation.z = PI / 2.0
	cordon.position.x = -0.24
	raiz.add_child(cordon)
	var petalos := [_petalos(Color(1.0, 0.55, 0.05), 342), _petalos(Color(1.0, 0.78, 0.1), 343)]
	for k in 3:
		var flor := SphereMesh.new()
		flor.radius = 0.016
		flor.height = 0.022
		flor.radial_segments = 7
		flor.rings = 4
		var f := _malla(flor, petalos[k % 2])
		f.name = "Flor%d" % k
		var ang := -0.6 + k * 1.1
		f.position = Vector3(-0.24 + (k - 1) * 0.006, cos(ang) * 0.03, sin(ang) * 0.03)
		f.rotation = Vector3(ang, 0.0, 0.3)
		raiz.add_child(f)
	var luz := OmniLight3D.new()
	luz.name = "LuzPiso"   # quitarla en el inventario y en la mano, como la del Cobalto 84
	luz.light_color = Color(0.3, 0.6, 1.0)
	luz.light_energy = 1.0
	luz.omni_range = 1.5
	luz.shadow_enabled = false
	luz.position.x = 0.25
	raiz.add_child(luz)
	return raiz


# Papel mache pintado de hueso viejo (cafe: JJ). Larga (u alrededor, v a lo largo de la cana)
# para que no se estire: fibras del hueso a lo largo, las tiras de papel encimadas en diagonal
# con su orilla, la linea aspera (la cresta de atras del femur), poros cerca de las puntas,
# manchas de agua, parches de periodico rotos y cuarteaduras
func _hueso_mache() -> Texture2D:
	const W := 32
	const H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	_pintar_hueso(img, 351, true)
	return ImageTexture.create_from_image(img)


# Las bolas (condilos, cabeza, trocanter): hueso esponjoso, con mas poros y sin la cresta
func _hueso_bola() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	_pintar_hueso(img, 361, false)
	return ImageTexture.create_from_image(img)


func _pintar_hueso(img: Image, semilla: int, cana: bool) -> void:
	var W := img.get_width()
	var H := img.get_height()
	var rnd := RandomNumberGenerator.new()
	rnd.seed = semilla
	var agua := FastNoiseLite.new()
	agua.seed = semilla + 1
	agua.frequency = 0.06
	var fibra := FastNoiseLite.new()
	fibra.seed = semilla + 2
	fibra.frequency = 0.15
	var tira := 11
	for y in H:
		var v := float(y) / (H - 1)
		for x in W:
			# Fibras: ruido estirado a lo largo
			var f := fibra.get_noise_2d(x * 3.0, y * 0.4) if cana else fibra.get_noise_2d(x, y)
			var c := Color(0.55, 0.4, 0.25).lightened(f * 0.12 + rnd.randf_range(-0.035, 0.035))
			# Tiras de papel en diagonal: cada una de otro tono, con la orilla oscura
			var banda := posmod(x + y, tira)
			var cual := int(floor(float(x + y) / tira))
			c = c.lightened(((cual * 37) % 7 - 3) * 0.015)
			if banda == 0:
				c = c.darkened(0.22)
			elif banda == 1 and (cual + y / 7) % 3 == 0:
				c = c.lightened(0.1)   # la orilla que se levanto
			# Linea aspera: una cresta oscura con un borde claro, por un lado de la cana
			if cana and v > 0.15 and v < 0.85:
				if x == W / 2:
					c = c.darkened(0.25)
				elif x == W / 2 + 1:
					c = c.lightened(0.12)
			# Mas oscuro y con poros hacia las puntas (hueso esponjoso); las bolas, todas
			var punta := 1.0 if not cana else clampf(1.0 - minf(v, 1.0 - v) / 0.18, 0.0, 1.0)
			c = c.darkened(punta * 0.15)
			if rnd.randf() < 0.08 * punta + (0.06 if not cana else 0.0):
				c = Color(0.18, 0.11, 0.06)
			# Manchas de agua
			var n := agua.get_noise_2d(x, y)
			if n > 0.2:
				c = c.lerp(Color(0.32, 0.21, 0.11), clampf((n - 0.2) * 2.5, 0.0, 0.7))
			img.set_pixel(x, y, c)
	# Parches de periodico, con la orilla rota (pixeles salteados) y renglones
	for k in (4 if cana else 1):
		var pw := rnd.randi_range(6, 10)
		var ph := rnd.randi_range(5, 8)
		var px := rnd.randi_range(0, W - pw - 1)
		var py := rnd.randi_range(int(H * 0.2), int(H * 0.8) - ph) if cana else rnd.randi_range(0, H - ph - 1)
		for y in ph:
			for x in pw:
				var orilla := x == 0 or y == 0 or x == pw - 1 or y == ph - 1
				if orilla and rnd.randf() > 0.5:
					continue
				var c := Color(0.58, 0.55, 0.47).darkened(rnd.randf_range(0.0, 0.08))
				if y % 2 == 1 and not orilla and rnd.randf() > 0.3:
					c = Color(0.22, 0.2, 0.18)
				img.set_pixel(px + x, py + y, c)
	# Cuarteaduras: caminitos oscuros con un pixel claro al lado (la pintura levantada)
	for k in (9 if cana else 3):
		var p := Vector2i(rnd.randi_range(0, W - 1), rnd.randi_range(0, H - 1))
		for paso in rnd.randi_range(6, 16):
			img.set_pixel(posmod(p.x, W), posmod(p.y, H), Color(0.16, 0.1, 0.06))
			img.set_pixel(posmod(p.x + 1, W), posmod(p.y, H), img.get_pixel(posmod(p.x + 1, W), posmod(p.y, H)).lightened(0.12))
			p += Vector2i(rnd.randi_range(-1, 1), 1)
	# Venas azules del cobalto (JJ): salen de la punta de las puas (v alta) y suben serpenteando
	# hacia el agarre, cada vez mas delgadas, con alguna rama; claras al centro y azul oscuro a los
	# lados. En las bolas van por todos lados
	for k in (8 if cana else 4):
		var x := float(rnd.randi_range(0, W - 1))
		var y := float(H - 1) if cana else float(rnd.randi_range(0, H - 1))
		var largo := rnd.randi_range(int(H * 0.45), int(H * 0.85)) if cana else rnd.randi_range(12, 24)
		var rumbo := rnd.randf_range(-0.6, 0.6)
		for paso in largo:
			var q := Vector2i(posmod(int(x), W), posmod(int(y), H))
			var gruesa := paso < largo * 0.5
			img.set_pixel(q.x, q.y, Color(0.45, 0.85, 1.0) if gruesa else Color(0.25, 0.55, 0.95))
			if gruesa:
				for lado in [-1, 1]:
					img.set_pixel(posmod(q.x + lado, W), q.y, Color(0.08, 0.2, 0.55))
			rumbo = clampf(rumbo + rnd.randf_range(-0.35, 0.35), -1.0, 1.0)
			x += rumbo
			y -= 1.0 if cana else (1.0 if k % 2 == 0 else -1.0)
			# Una rama corta de vez en cuando
			if rnd.randf() < 0.04:
				var r := Vector2(x, y)
				var dir := 1.0 if rnd.randf() > 0.5 else -1.0
				for j in rnd.randi_range(4, 9):
					r += Vector2(dir, -0.6)
					img.set_pixel(posmod(int(r.x), W), posmod(int(r.y), H), Color(0.25, 0.55, 0.95))


# --- Coderas y rodilleras (armadura I: tela + hule): la rodillera y la codera de neopreno de
# Sketchfab que escogio JJ (models/taller/rodillera y codera, de WCG847, en cm), juntas y a
# escala. La version hecha en codigo (manga de mezclilla con llanta y cinchos) se queda abajo
# en _rodillera por si se usa ---

const RODILLERA_RADIO := 0.05
const RODILLERA_LARGO := 0.13
const PIEZAS_PAR := [
	# [escena, donde va, giro en y]: cada una se centra sola con la caja de sus mallas
	["res://models/taller/rodillera/rodillera.scn", Vector3(-0.12, 0.0, 0.0), 0.0],
	["res://models/taller/codera/codera.scn", Vector3(0.12, 0.0, 0.02), 0.4],
]


func _coderas_rodilleras() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Par"
	for datos: Array in PIEZAS_PAR:
		var pieza: Node3D = (load(datos[0]) as PackedScene).instantiate()
		# Que se guarde como nodos sueltos y no como instancia: si no, _guardar le pone dueño a lo de
		# adentro y al cargar salen dos veces
		pieza.scene_file_path = ""
		var lugar := Node3D.new()
		lugar.name = (datos[0] as String).get_file().get_basename().capitalize()
		lugar.position = datos[1]
		lugar.rotation.y = datos[2]
		var caja := _caja_mallas(pieza, Transform3D.IDENTITY)
		pieza.scale = Vector3.ONE * 0.01
		pieza.position = -caja.get_center() * 0.01
		# Sin el wobble del PS1: a este tamaño la rejilla de 1/40 m las deja hechas bloques
		for malla: MeshInstance3D in pieza.find_children("*", "MeshInstance3D", true, false):
			for k in malla.mesh.get_surface_count():
				var mat := malla.get_active_material(k)
				if mat is ShaderMaterial:
					mat = mat.duplicate()
					(mat as ShaderMaterial).set_shader_parameter("wobble_enabled", false)
					malla.set_surface_override_material(k, mat)
		lugar.add_child(pieza)
		raiz.add_child(lugar)
	return raiz


# La caja de todas las mallas de `nodo`, en el espacio de quien lo tiene (sin estar en el arbol)
func _caja_mallas(nodo: Node3D, padre: Transform3D) -> AABB:
	var t := padre * nodo.transform
	var caja := AABB()
	var hay := false
	if nodo is MeshInstance3D and (nodo as MeshInstance3D).mesh:
		caja = t * (nodo as MeshInstance3D).mesh.get_aabb()
		hay = true
	for hijo in nodo.get_children():
		if hijo is Node3D:
			var c := _caja_mallas(hijo, t)
			if c.size != Vector3.ZERO:
				caja = c if not hay else caja.merge(c)
				hay = true
	return caja


# Manga a lo largo de z con el pedazo de llanta arriba (+y)
func _rodillera() -> Node3D:
	var pieza := Node3D.new()
	var centro := -RODILLERA_RADIO - 0.008
	var afuera: Array[Vector3] = []
	for i in 7:
		var z := -RODILLERA_LARGO * 0.5 + RODILLERA_LARGO * i / 6.0
		afuera.append(Vector3(0.0, centro, z))
	var manga := _malla(_tubo(afuera, RODILLERA_RADIO, 12), _mezclilla())
	manga.name = "Manga"
	pieza.add_child(manga)
	# Lo de adentro: el mismo tubo con las caras hacia adentro
	var forro := _malla(_tubo(afuera, RODILLERA_RADIO - 0.002, 12, [], true), _liso(Color(0.12, 0.17, 0.3), 371))
	forro.name = "Adentro"
	pieza.add_child(forro)
	# El pedazo de llanta: su largo (el arco) va a lo largo de la manga
	var llanta := _llanta_arco(HULE_ARCO, HULE_PASOS, true, HULE_GRUESO)
	llanta.name = "Llanta"
	llanta.scale = Vector3(0.9, 1.0, 0.95)
	pieza.add_child(llanta)
	# Cinchos: abrazan la manga y pasan por arriba de la llanta (la vuelta se arma acostada en xz
	# y se para con el nodo: _tubo tuerce los anillos cuando el tramo apunta hacia arriba)
	var vuelta: Array[Vector3] = []
	var arriba := -centro + HULE_GRUESO * 0.5 + 0.002   # lo alto de la llanta, desde el centro
	for k in 21:
		var t := TAU * k / 20.0
		var p := Vector2(cos(t), sin(t)) * (RODILLERA_RADIO + 0.002)
		if p.y > RODILLERA_RADIO * 0.55:
			p = Vector2(clampf(p.x * 1.15, -HULE_ANCHO * 0.47, HULE_ANCHO * 0.47), arriba)
		vuelta.append(Vector3(p.x, 0.0, p.y))
	for z: float in [-0.04, 0.04]:
		var cincho := _malla(_tubo(vuelta, 0.0016, 4), _liso(Color(0.88, 0.87, 0.82), 372))
		cincho.name = "Cincho"
		cincho.rotation.x = -PI / 2.0
		cincho.position = Vector3(0.0, centro, z)
		pieza.add_child(cincho)
		var cabeza := _malla(_caja(Vector3(0.009, 0.007, 0.007)), _liso(Color(0.85, 0.84, 0.78), 373))
		cabeza.name = "CabezaCincho"
		cabeza.position = Vector3(RODILLERA_RADIO + 0.003, centro + 0.01, z)
		pieza.add_child(cabeza)
	return pieza


# Mezclilla: azul con la diagonal del tejido, deslavada en franjas, una costura con hilo naranja
# a lo largo y las orillas deshilachadas (v cerca de 0 y 1) donde se corto la pierna del pantalon
func _mezclilla() -> Texture2D:
	const W := 48
	const H := 32
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 381
	var deslave := FastNoiseLite.new()
	deslave.seed = 382
	deslave.frequency = 0.08
	for y in H:
		var v := float(y) / (H - 1)
		for x in W:
			var c := Color(0.2, 0.3, 0.52)
			if (x + y) % 3 == 0:
				c = c.darkened(0.18)
			c = c.lightened(deslave.get_noise_2d(x * 0.6, y) * 0.18 + rnd.randf_range(-0.03, 0.03))
			# La costura: dos lineas de puntadas naranja junto a la orilla doblada
			if x == 4 or x == 6:
				if y % 3 != 0:
					c = Color(0.85, 0.55, 0.2)
			elif x == 5:
				c = c.darkened(0.25)
			# Orillas cortadas: hilos claros sueltos
			if (v < 0.07 or v > 0.93) and rnd.randf() > 0.45:
				c = Color(0.75, 0.78, 0.82).darkened(rnd.randf_range(0.0, 0.2))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Faja de cargador (armadura II: tela + metal), con la foto de JJ de una faja de levantar de
# nylon negro: ancha atras y angosta adelante, acolchada, con la orilla ribeteada; la correa de
# velcro cruza el frente y pasa por un aro de fierro, y en medio lleva una etiqueta (CARGA) ---

const FAJA_A := 0.15        # m: medio ancho de la cintura (elipse en xz)
const FAJA_B := 0.11
const FAJA_BAJO := -0.04    # la orilla de abajo, pareja
const FAJA_ADELANTE := 0.075
const FAJA_ATRAS := 0.15
const FAJA_GRUESO := 0.008
const FAJA_PASOS := 48


func _faja_cargador() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Faja"
	# Cuerpo: vuelta entera; adelante es t = -PI/2 (z negativa), atras t = PI/2
	var alto := func(t: float) -> float:
		return lerpf(FAJA_ADELANTE, FAJA_ATRAS, pow((1.0 + sin(t)) * 0.5, 1.5))
	var cuerpo := _malla(_banda(-PI * 0.5, PI * 1.5, FAJA_PASOS, 0.0, func(_t: float) -> float: return FAJA_BAJO,
		func(t: float) -> float: return FAJA_BAJO + alto.call(t), FAJA_GRUESO), _nylon_faja())
	cuerpo.name = "Cuerpo"
	raiz.add_child(cuerpo)
	# La correa de velcro: por fuera, de lado a lado del frente
	const CORREA := 1.35   # rad a cada lado del frente
	var abajo := FAJA_BAJO + 0.014
	var correa := _malla(_banda(-PI * 0.5 - CORREA, -PI * 0.5 + CORREA, 24, FAJA_GRUESO * 0.9,
		func(_t: float) -> float: return abajo, func(_t: float) -> float: return abajo + 0.048, 0.004), _velcro())
	correa.name = "Correa"
	raiz.add_child(correa)
	# El aro de fierro por donde entra la correa, de un lado
	var aro := TorusMesh.new()
	aro.inner_radius = 0.026
	aro.outer_radius = 0.031
	aro.rings = 12
	aro.ring_segments = 4
	var a := _malla(aro, _liso(Color(0.62, 0.63, 0.66), 391))
	a.name = "Aro"
	(a.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.7)
	var t_aro := -PI * 0.5 - CORREA
	a.position = Vector3(cos(t_aro) * (FAJA_A + 0.016), abajo + 0.024, sin(t_aro) * (FAJA_B + 0.016))
	a.rotation = Vector3(0.0, -t_aro, PI / 2.0)
	a.scale = Vector3(1.0, 1.0, 0.75)
	raiz.add_child(a)
	# La etiqueta en medio del frente, encima de la correa
	var etiqueta := _malla(_caja(Vector3(0.07, 0.03, 0.003)), _etiqueta_faja())
	etiqueta.name = "Etiqueta"
	etiqueta.position = Vector3(0.0, abajo + 0.024, -FAJA_B - FAJA_GRUESO * 0.9 - 0.0055)
	etiqueta.rotation.y = PI
	raiz.add_child(etiqueta)
	# Que la captura y el inventario la vean de frente (la etiqueta), no de la espalda
	raiz.rotation.y = PI
	return raiz


# Banda alrededor de la elipse de la cintura, de t0 a t1, separada `fuera` m hacia afuera, con la
# orilla de abajo y la de arriba que da cada funcion de t y `grueso` de espesor: cara de afuera,
# de adentro, las dos orillas y, si no da la vuelta entera, las dos puntas. u a lo largo, v de
# abajo (0) a arriba (1)
func _banda(t0: float, t1: float, pasos: int, fuera: float, abajo: Callable, arriba: Callable, grueso: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var en := func(t: float, r: float, y: float) -> Vector3:
		return Vector3(cos(t) * (FAJA_A + r), y, sin(t) * (FAJA_B + r))
	var cuad := func(q: Array, uv: Array, normal: Vector3) -> void:
		# Frente horario visto desde afuera (Godot): si la normal de q sale hacia `normal`, se voltea
		var orden := [0, 1, 2, 0, 2, 3]
		if (q[1] - q[0]).cross(q[2] - q[0]).dot(normal) > 0.0:
			orden = [0, 2, 1, 0, 3, 2]
		for k in orden:
			st.set_uv(uv[k])
			st.add_vertex(q[k])
	var ri := fuera
	var ro := fuera + grueso
	for i in pasos:
		var ta := lerpf(t0, t1, float(i) / pasos)
		var tb := lerpf(t0, t1, float(i + 1) / pasos)
		var ua := float(i) / pasos
		var ub := float(i + 1) / pasos
		var ya0: float = abajo.call(ta)
		var ya1: float = arriba.call(ta)
		var yb0: float = abajo.call(tb)
		var yb1: float = arriba.call(tb)
		var sale := Vector3(cos((ta + tb) * 0.5) / FAJA_A, 0.0, sin((ta + tb) * 0.5) / FAJA_B).normalized()
		cuad.call([en.call(ta, ro, ya0), en.call(tb, ro, yb0), en.call(tb, ro, yb1), en.call(ta, ro, ya1)],
			[Vector2(ua, 1), Vector2(ub, 1), Vector2(ub, 0), Vector2(ua, 0)], sale)
		cuad.call([en.call(ta, ri, ya0), en.call(tb, ri, yb0), en.call(tb, ri, yb1), en.call(ta, ri, ya1)],
			[Vector2(ua, 1), Vector2(ub, 1), Vector2(ub, 0), Vector2(ua, 0)], -sale)
		cuad.call([en.call(ta, ri, ya1), en.call(tb, ri, yb1), en.call(tb, ro, yb1), en.call(ta, ro, ya1)],
			[Vector2(ua, 0), Vector2(ub, 0), Vector2(ub, 0.03), Vector2(ua, 0.03)], Vector3.UP)
		cuad.call([en.call(ta, ri, ya0), en.call(tb, ri, yb0), en.call(tb, ro, yb0), en.call(ta, ro, ya0)],
			[Vector2(ua, 1), Vector2(ub, 1), Vector2(ub, 0.97), Vector2(ua, 0.97)], Vector3.DOWN)
	if absf(t1 - t0) < TAU - 0.001:
		for punta: Array in [[t0, -1.0], [t1, 1.0]]:
			var t: float = punta[0]
			var y0: float = abajo.call(t)
			var y1: float = arriba.call(t)
			var tangente := Vector3(-sin(t) * FAJA_A, 0.0, cos(t) * FAJA_B).normalized() * float(punta[1])
			cuad.call([en.call(t, ri, y0), en.call(t, ro, y0), en.call(t, ro, y1), en.call(t, ri, y1)],
				[Vector2(0, 1), Vector2(0.03, 1), Vector2(0.03, 0), Vector2(0, 0)], tangente)
	st.generate_normals()
	return st.commit()


# Nylon negro: tejido fino, el ribete gris oscuro en las dos orillas con su costura, y las
# costuras acolchadas a lo largo (u a lo largo de la vuelta, v de abajo a arriba)
func _nylon_faja() -> Texture2D:
	const W := 256
	const H := 24
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 401
	for y in H:
		for x in W:
			var c := Color(0.075, 0.075, 0.08).lightened(rnd.randf_range(0.0, 0.035))
			if (x + y) % 2 == 0:
				c = c.lightened(0.02)
			# Ribete: dos renglones en cada orilla, un poco mas claro
			if y < 2 or y > H - 3:
				c = Color(0.16, 0.16, 0.17).lightened(rnd.randf_range(0.0, 0.03))
			# Costuras: puntadas grises junto al ribete y una en medio
			elif (y == 3 or y == H - 4) and x % 2 == 0:
				c = Color(0.2, 0.2, 0.21)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Velcro: gris muy oscuro con el pelito (puntos claros y oscuros) y las orillas cosidas
func _velcro() -> Texture2D:
	const W := 64
	const H := 12
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 411
	for y in H:
		for x in W:
			var c := Color(0.11, 0.11, 0.12).lightened(rnd.randf_range(-0.03, 0.08))
			if rnd.randf() > 0.8:
				c = c.darkened(0.4)
			if (y == 1 or y == H - 2) and x % 3 != 0:
				c = Color(0.28, 0.28, 0.3)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Etiqueta: gris oscuro con orilla y "CARGA" en letras claras de pixel (3x5)
func _etiqueta_faja() -> Texture2D:
	const W := 28
	const H := 12
	const LETRAS := {
		"C": ["111", "100", "100", "100", "111"],
		"A": ["010", "101", "111", "101", "101"],
		"R": ["110", "101", "110", "101", "101"],
		"G": ["111", "100", "101", "101", "111"],
	}
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(Color(0.2, 0.2, 0.21))
	for x in W:
		img.set_pixel(x, 0, Color(0.1, 0.1, 0.1))
		img.set_pixel(x, H - 1, Color(0.1, 0.1, 0.1))
	for y in H:
		img.set_pixel(0, y, Color(0.1, 0.1, 0.1))
		img.set_pixel(W - 1, y, Color(0.1, 0.1, 0.1))
	var x0 := 3
	for letra in "CARGA":
		var filas: Array = LETRAS[letra]
		for fy in 5:
			for fx in 3:
				if (filas[fy] as String)[fx] == "1":
					img.set_pixel(x0 + fx, 3 + fy, Color(0.88, 0.88, 0.86))
		x0 += 5
	return ImageTexture.create_from_image(img)


# --- Chaleco de llanta (armadura III: tela + hule): chaleco de lona verde olivo con placas
# cortadas de llanta remachadas encima, encimadas como escamas (la de arriba tapa la orilla
# de la de abajo), tirantes en los hombros, sisas para los brazos y el cuello en V abierto
# adelante. Usa la elipse de la cintura de la faja (_banda), mas ancha ---

const CHALECO_BAJO := -0.17
const CHALECO_ALTO := 0.13


func _chaleco_llanta() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Chaleco"
	# La orilla de arriba: alta adelante y atras, baja en los costados (las sisas) y en V al frente
	var arriba := func(t: float) -> float:
		var y := lerpf(-0.02, CHALECO_ALTO, pow(absf(sin(t)), 0.7))
		var al_frente := absf(wrapf(t + PI * 0.5, -PI, PI))
		if al_frente < 0.55:
			y = lerpf(0.0, y, al_frente / 0.55)
		return y
	var lona := _lona()
	# Da la vuelta menos la abertura del frente
	var cuerpo := _malla(_banda(-PI * 0.5 + 0.1, PI * 1.5 - 0.1, 48, 0.03,
		func(_t: float) -> float: return CHALECO_BAJO, arriba, 0.006), lona)
	cuerpo.name = "Lona"
	raiz.add_child(cuerpo)
	# Tirantes: de la orilla de adelante, por encima del hombro, a la de atras
	for x: float in [-0.085, 0.085]:
		var z := (FAJA_B + 0.03) * sqrt(1.0 - pow(x / (FAJA_A + 0.03), 2.0))
		# Cada punta sale de donde esta la orilla de la lona en ese lado
		var y_frente: float = arriba.call(atan2(-z / (FAJA_B + 0.03), x / (FAJA_A + 0.03))) - 0.012
		var y_atras: float = arriba.call(atan2(z / (FAJA_B + 0.03), x / (FAJA_A + 0.03))) - 0.012
		var camino: Array[Vector3] = [Vector3(x, y_frente, -z - 0.004), Vector3(x, 0.17, -z * 0.7),
			Vector3(x, 0.2, -z * 0.25), Vector3(x, 0.2, z * 0.25), Vector3(x, 0.17, z * 0.7), Vector3(x, y_atras, z + 0.004)]
		var tirante := _malla(_tubo(camino, 0.007, 4), lona)
		tirante.name = "Tirante"
		tirante.scale.x = 2.6
		tirante.position.x = x * (1.0 - 2.6)   # que el escalado no lo saque de su lugar
		raiz.add_child(tirante)
	# Placas de llanta: filas de abajo hacia arriba, cada una un poco mas afuera que la de abajo
	var hule := _dibujo_llanta()
	var remache := _liso(Color(0.6, 0.6, 0.62), 421)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 431
	var fila := 0
	for y: float in [-0.135, -0.08, -0.025, 0.03, 0.085]:
		# Cada fila corrida media placa (tresbolillo)
		var t := -PI * 0.5 + 0.3 + (0.2 if fila % 2 == 1 else 0.0)
		while t < PI * 1.5 - 0.25:
			var tope: float = arriba.call(t)
			var lado := absf(cos(t)) > 0.8
			if y + 0.03 < tope and not (lado and y > -0.03):
				var fuera := 0.036 + fila * 0.004
				var punto := Vector3(cos(t) * (FAJA_A + fuera), y, sin(t) * (FAJA_B + fuera))
				var normal := Vector3(cos(t) / FAJA_A, 0.0, sin(t) / FAJA_B).normalized()
				var eje_x := Vector3.UP.cross(normal).normalized()
				var placa := _malla(_caja(Vector3(0.068, 0.06, 0.009)), hule)
				placa.name = "Placa"
				# La orilla de abajo un poco hacia afuera, como escama
				placa.basis = Basis(eje_x, Vector3.UP, normal).rotated(eje_x, -0.12)
				placa.position = punto + Vector3.UP * rnd.randf_range(-0.004, 0.004)
				raiz.add_child(placa)
				for lado_r: float in [-1.0, 1.0]:
					var r := CylinderMesh.new()
					r.top_radius = 0.0035
					r.bottom_radius = 0.0035
					r.height = 0.004
					r.radial_segments = 6
					var rm := _malla(r, remache)
					rm.name = "Remache"
					rm.basis = Basis(Quaternion(Vector3.UP, normal))
					rm.position = punto + eje_x * 0.024 * lado_r + Vector3.UP * 0.02 + normal * 0.006
					raiz.add_child(rm)
			t += 0.4
		fila += 1
	# Que la captura lo vea de frente
	raiz.rotation.y = PI
	return raiz


# Lona verde olivo: tejido grueso, deslavada y con costuras (u a lo largo, v de abajo a arriba)
func _lona() -> Texture2D:
	const W := 128
	const H := 32
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 441
	var mugre := FastNoiseLite.new()
	mugre.seed = 442
	mugre.frequency = 0.07
	for y in H:
		for x in W:
			var c := Color(0.33, 0.35, 0.22)
			if (x % 2 == 0) != (y % 2 == 0):
				c = c.darkened(0.1)
			c = c.lightened(mugre.get_noise_2d(x, y) * 0.15 + rnd.randf_range(-0.03, 0.03))
			if (y == 2 or y == H - 3) and x % 3 != 0:
				c = Color(0.22, 0.22, 0.14)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Chamarra del Machetes (armadura IV: metal + Tapa del tinaco): la chamarra de piel cafe del
# protagonista, con hombreras de lamina remachada que tapan los hombros, aros de lamina en los
# antebrazos, el cierre al frente y la Tapa del tinaco (el trofeo, con su Virgen) atornillada en
# la espalda. Misma elipse que la faja y el chaleco ---

const CHAMARRA_BAJO := -0.18
const CHAMARRA_HOMBRO := 0.12


func _chamarra_machetes() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Chamarra"
	var piel := _piel_chamarra()
	var lamina := _lamina()
	const FUERA := 0.03
	var cuerpo := _malla(_banda(-PI * 0.5 + 0.05, PI * 1.5 - 0.05, 48, FUERA,
		func(_t: float) -> float: return CHAMARRA_BAJO, func(_t: float) -> float: return CHAMARRA_HOMBRO, 0.007), piel)
	cuerpo.name = "Piel"
	raiz.add_child(cuerpo)
	# El resorte de abajo, un poco mas grueso
	var resorte := _malla(_banda(-PI * 0.5 + 0.05, PI * 1.5 - 0.05, 48, FUERA + 0.002,
		func(_t: float) -> float: return CHAMARRA_BAJO - 0.002, func(_t: float) -> float: return CHAMARRA_BAJO + 0.022, 0.008),
		_liso(Color(0.24, 0.15, 0.09), 451))
	resorte.name = "Resorte"
	raiz.add_child(resorte)
	# El cierre: dos tiras de dientes de metal en la abertura del frente
	for lado: float in [-1.0, 1.0]:
		var t := -PI * 0.5 + 0.05 * lado
		var cierre := _malla(_caja(Vector3(0.006, CHAMARRA_HOMBRO - CHAMARRA_BAJO, 0.004)), _liso(Color(0.62, 0.6, 0.55), 452))
		cierre.name = "Cierre"
		cierre.position = Vector3(cos(t) * (FAJA_A + FUERA + 0.004), (CHAMARRA_HOMBRO + CHAMARRA_BAJO) * 0.5, sin(t) * (FAJA_B + FUERA + 0.004))
		raiz.add_child(cierre)
	# El cuello: un aro de piel alrededor del pescuezo
	var cuello := _malla(_tubo([Vector3(0.0, CHAMARRA_HOMBRO - 0.005, 0.0), Vector3(0.0, CHAMARRA_HOMBRO + 0.035, 0.0)] as Array[Vector3],
		0.075, 12, [0.08, 0.07]), piel)
	cuello.name = "Cuello"
	cuello.scale.z = 0.85
	raiz.add_child(cuello)
	var cuello_dentro := _malla(_tubo([Vector3(0.0, CHAMARRA_HOMBRO - 0.005, 0.0), Vector3(0.0, CHAMARRA_HOMBRO + 0.035, 0.0)] as Array[Vector3],
		0.075, 12, [0.077, 0.067], true), _liso(Color(0.15, 0.09, 0.05), 453))
	cuello_dentro.scale.z = 0.85
	raiz.add_child(cuello_dentro)
	# Mangas: del hombro hacia afuera y abajo (en A), con lo de adentro oscuro y dos aros de lamina
	for lado: float in [-1.0, 1.0]:
		var hombro := Vector3(lado * (FAJA_A + FUERA - 0.01), CHAMARRA_HOMBRO - 0.035, 0.0)
		var puno := Vector3(lado * 0.4, -0.2, 0.0)
		var manga: Array[Vector3] = []
		var radios: Array = []
		for k in 7:
			manga.append(hombro.lerp(puno, k / 6.0))
			radios.append(lerpf(0.05, 0.038, k / 6.0))
		var m := _malla(_tubo(manga, 0.045, 10, radios), piel)
		m.name = "Manga"
		raiz.add_child(m)
		var dentro := _malla(_tubo(manga, 0.045, 10, radios.map(func(r: float) -> float: return r - 0.003), true), _liso(Color(0.15, 0.09, 0.05), 454))
		dentro.name = "MangaDentro"
		raiz.add_child(dentro)
		for k: float in [0.68, 0.84]:
			var centro := hombro.lerp(puno, k)
			var aro := _malla(_tubo([centro - (puno - hombro).normalized() * 0.018, centro + (puno - hombro).normalized() * 0.018] as Array[Vector3],
				lerpf(0.05, 0.038, k) + 0.006, 10), lamina)
			aro.name = "Brazal"
			(aro.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.5)
			raiz.add_child(aro)
		# Hombrera: tres laminas encimadas que bajan del hombro hacia la manga, con remaches
		for k in 3:
			var placa := _malla(_caja(Vector3(0.075, 0.008, 0.2 - k * 0.03)), lamina)
			placa.name = "Hombrera"
			(placa.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.5)
			placa.position = Vector3(lado * (0.1 + k * 0.045), CHAMARRA_HOMBRO + 0.012 - k * 0.028, 0.0)
			placa.rotation.z = -lado * (0.35 + k * 0.12)
			raiz.add_child(placa)
			for z: float in [-0.06, 0.06]:
				var r := CylinderMesh.new()
				r.top_radius = 0.004
				r.bottom_radius = 0.004
				r.height = 0.011
				r.radial_segments = 6
				var rm := _malla(r, _liso(Color(0.45, 0.42, 0.38), 455))
				rm.name = "Remache"
				rm.position = placa.position + Vector3(0.0, 0.0, z * (1.0 - k * 0.15))
				rm.rotation.z = placa.rotation.z
				raiz.add_child(rm)
	# La Tapa del tinaco en la espalda, parada, con la Virgen hacia afuera y cuatro pijas
	var tapa := _tapa_tinaco()
	tapa.name = "TapaTinaco"
	tapa.rotation.x = PI / 2.0
	tapa.position = Vector3(0.0, -0.02, FAJA_B + FUERA + 0.007 + TAPA_ALTO * 0.5)
	raiz.add_child(tapa)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		var pija := CylinderMesh.new()
		pija.top_radius = 0.005
		pija.bottom_radius = 0.005
		pija.height = 0.004
		pija.radial_segments = 6
		var pm := _malla(pija, _liso(Color(0.55, 0.55, 0.57), 456))
		pm.name = "Pija"
		pm.rotation.x = PI / 2.0
		pm.position = Vector3(cos(a) * TAPA_RADIO * 0.85, -0.02 + sin(a) * TAPA_RADIO * 0.85, FAJA_B + FUERA + 0.008 + TAPA_ALTO)
		raiz.add_child(pm)
	# Que la captura lo vea por la espalda, con la tapa
	return raiz


# Piel cafe de chamarra: gastada, con arrugas mas oscuras, raspones claros y costuras
func _piel_chamarra() -> Texture2D:
	const W := 128
	const H := 32
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 461
	var arruga := FastNoiseLite.new()
	arruga.seed = 462
	arruga.frequency = 0.12
	for y in H:
		for x in W:
			var c := Color(0.36, 0.22, 0.12).lightened(rnd.randf_range(-0.03, 0.03))
			var n := arruga.get_noise_2d(x * 0.7, y * 1.4)
			c = c.darkened(clampf(n * 0.5, 0.0, 0.3)).lightened(clampf(-n * 0.25, 0.0, 0.12))
			if rnd.randf() > 0.97:
				c = Color(0.52, 0.38, 0.25)
			if (x % 32 == 0 or y == 3) and (x + y) % 3 != 0:
				c = Color(0.2, 0.12, 0.07)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Lamina: gris galvanizado opaco, con manchas de oxido y rayones
func _lamina() -> Texture2D:
	const T := 32
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 471
	var oxido := FastNoiseLite.new()
	oxido.seed = 472
	oxido.frequency = 0.1
	for y in T:
		for x in T:
			var c := Color(0.5, 0.51, 0.52).lightened(rnd.randf_range(-0.05, 0.05))
			if oxido.get_noise_2d(x, y) > 0.3:
				c = Color(0.48, 0.26, 0.1).lerp(Color(0.6, 0.34, 0.14), rnd.randf())
			if (x - y) % 11 == 0 and rnd.randf() > 0.4:
				c = c.lightened(0.2)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Botas del 84 (botas IV: metal + Ojo de turba): las de casquillo (models/taller/
# botas_casquillo, de Sketchfab) con la piel ennegrecida y venas de cobalto 60 que brillan, el
# casquillo de la punta azul, y la luz chica del Cobalto 84 ---

const BOTAS_BASE := "res://models/taller/botas_casquillo/botas_casquillo.scn"


func _botas_84() -> Node3D:
	var modelo := (load(BOTAS_BASE) as PackedScene).instantiate() as Node3D
	modelo.scene_file_path = ""
	for malla: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		for k in malla.mesh.get_surface_count():
			var mat := malla.get_active_material(k)
			if not mat is ShaderMaterial:
				continue
			var original := (mat as ShaderMaterial).get_shader_parameter("albedo_texture") as Texture2D
			var nuevo := (mat as ShaderMaterial).duplicate() as ShaderMaterial
			if original:
				nuevo.set_shader_parameter("albedo_texture", _cobaltear(original))
			nuevo.set_shader_parameter("brillo", 0.35)
			malla.set_surface_override_material(k, nuevo)
	var luz := OmniLight3D.new()
	luz.name = "LuzPiso"   # quitarla en el inventario y en el pie, como la del Cobalto 84
	luz.light_color = Color(0.3, 0.6, 1.0)
	luz.light_energy = 1.0
	luz.omni_range = 1.2
	luz.shadow_enabled = false
	modelo.add_child(luz)
	return modelo


# La piel pasa a casi negro (guarda la luz de la textura, no el color), la suela queda negra, y
# encima se pintan venas de cobalto: caminos que serpentean, claros al centro y azul oscuro a los
# lados, mas puntos que brillan
func _cobaltear(textura: Texture2D) -> Texture2D:
	var img := textura.get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGB8)
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var luz := c.get_luminance()
			img.set_pixel(x, y, Color(0.08, 0.09, 0.12).lerp(Color(0.25, 0.27, 0.33), clampf(luz * 1.6, 0.0, 1.0)))
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 1984
	for k in 40:
		var p := Vector2(rnd.randf() * w, rnd.randf() * h)
		var rumbo := rnd.randf() * TAU
		for paso in rnd.randi_range(20, 60):
			var q := Vector2i(posmod(int(p.x), w), posmod(int(p.y), h))
			img.set_pixel(q.x, q.y, Color(0.5, 0.9, 1.0))
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var o := q + d
				img.set_pixel(posmod(o.x, w), posmod(o.y, h), Color(0.12, 0.35, 0.85))
			rumbo += rnd.randf_range(-0.5, 0.5)
			p += Vector2(cos(rumbo), sin(rumbo))
	for k in 120:
		img.set_pixel(rnd.randi_range(0, w - 1), rnd.randi_range(0, h - 1), Color(0.55, 0.92, 1.0))
	return ImageTexture.create_from_image(img)


# --- Escapulario (amuleto I: frijol rojo + tela): dos cuadritos de fieltro cafe con la orilla
# cosida en amarillo, unidos por dos cordones; uno con la estampita de la Virgen del Tinaco (la de
# la Tapa del tinaco) y el otro con un frijol rojo cosido. Acostado, como en el inventario ---

const ESCAPULARIO_ANCHO := 0.034
const ESCAPULARIO_ALTO := 0.044


func _escapulario() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Escapulario"
	for lado in 2:
		var cuadro := _malla(_caja(Vector3(ESCAPULARIO_ANCHO, ESCAPULARIO_ALTO, 0.004)), _fieltro(lado == 0))
		cuadro.name = "Virgen" if lado == 0 else "Frijol"
		cuadro.rotation.x = -PI / 2.0   # la cara con la textura (+z) hacia arriba
		cuadro.position = Vector3(-0.05 if lado == 0 else 0.05, 0.0, 0.0)
		cuadro.rotation.y = 0.12 if lado == 0 else -0.1
		raiz.add_child(cuadro)
	# El frijol cosido al centro del segundo cuadro, con dos puntadas que lo cruzan
	var frijol := SphereMesh.new()
	frijol.radius = 0.008
	frijol.height = 0.01
	frijol.radial_segments = 8
	frijol.rings = 5
	var f := _malla(frijol, _frijol_piel())
	f.name = "FrijolRojo"
	f.scale = Vector3(1.0, 0.7, 1.45)
	f.position = Vector3(0.05, 0.004, 0.0)
	(f.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.5)
	raiz.add_child(f)
	for z: float in [-0.004, 0.004]:
		var puntada := _malla(_caja(Vector3(0.019, 0.0012, 0.0012)), _liso(Color(0.92, 0.78, 0.25), 481))
		puntada.name = "Puntada"
		puntada.position = Vector3(0.05, 0.0085, z)
		raiz.add_child(puntada)
	# Cordones: de las esquinas de arriba de un cuadro a las del otro, en arco (acostados en xz)
	var cordon := _liso(Color(0.35, 0.22, 0.12), 482)
	for par: Array in [[Vector2(-0.065, -0.021), Vector2(0.065, -0.021), -0.16], [Vector2(-0.035, -0.021), Vector2(0.035, -0.021), -0.12]]:
		var a: Vector2 = par[0]
		var b: Vector2 = par[1]
		var control := Vector2(0.0, float(par[2]))
		var puntos: Array[Vector3] = []
		for k in 13:
			var t := k / 12.0
			var p := a.lerp(control, t).lerp(control.lerp(b, t), t)
			puntos.append(Vector3(p.x, 0.0, p.y))
		var c := _malla(_tubo(puntos, 0.0013, 4), cordon)
		c.name = "Cordon"
		raiz.add_child(c)
	return raiz


# Fieltro cafe con la orilla cosida en amarillo; con `virgen`, la estampita al centro
func _fieltro(virgen: bool) -> Texture2D:
	const W := 24
	const H := 32
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 491 if virgen else 492
	for y in H:
		for x in W:
			var c := Color(0.36, 0.22, 0.13).lightened(rnd.randf_range(-0.05, 0.05))
			# La costura a 2 px de la orilla: los cantos de la caja toman la esquina (0, H-1), que queda cafe
			var orilla := x == 2 or y == 2 or x == W - 3 or y == H - 3
			if orilla and (x + y) % 2 == 0:
				c = Color(0.92, 0.78, 0.25)
			img.set_pixel(x, y, c)
	if virgen:
		for y in range(5, H - 5):
			for x in range(4, W - 4):
				var cx := (W - 1) * 0.5
				var cy := (H - 1) * 0.5
				var e := Vector2((x - cx) / 7.5, (y - cy) / 10.5).length()
				if e >= 1.0:
					continue
				var c := Color(0.15, 0.3, 0.65)
				var manto := Vector2((x - cx) / (1.5 + (y - cy + 4.0) * 0.18), (y - cy - 3.0) / 6.5).length() < 1.0 and y > cy - 4.0
				var cara := Vector2(x - cx, y - (cy - 6.0)).length() < 1.6
				var rayo := e > 0.6 and int(rad_to_deg(Vector2(x - cx, y - cy).angle()) + 360.0) % 30 < 8
				if rayo:
					c = Color(0.95, 0.8, 0.3)
				if manto or cara:
					c = Color(0.92, 0.88, 0.72)
				if e > 0.88:
					c = Color(0.85, 0.7, 0.25)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Ojo de venado (amuleto I: frijol rojo + tela): la semilla cafe brillosa con su franja negra
# alrededor, colgada de un hilo rojo con su nudo y una borla de estambre rojo abajo. Parado,
# viendo de frente ---

const OJO_RADIO := 0.017


func _ojo_venado() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "OjoVenado"
	var semilla := SphereMesh.new()
	semilla.radius = OJO_RADIO
	semilla.height = OJO_RADIO * 2.0
	semilla.radial_segments = 12
	semilla.rings = 6
	var s := _malla(semilla, _semilla_venado())
	s.name = "Semilla"
	s.scale = Vector3(1.0, 0.92, 0.55)   # aplanada
	(s.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.7)
	raiz.add_child(s)
	# La franja negra (el hilio) que le da la vuelta por la orilla
	var franja := TorusMesh.new()
	franja.inner_radius = OJO_RADIO * 0.86
	franja.outer_radius = OJO_RADIO * 1.1
	franja.rings = 16
	franja.ring_segments = 5
	var f := _malla(franja, _liso(Color(0.05, 0.04, 0.04), 501))
	f.name = "Franja"
	f.rotation.x = PI / 2.0
	f.scale = Vector3(1.0, 0.75, 0.92)
	(f.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.6)
	raiz.add_child(f)
	var rojo := _estambre()
	# Hilo: amarrado arriba de la semilla, sube y hace una vuelta para colgarlo (la vuelta se arma
	# acostada en xz y se para con el nodo: _tubo tuerce los anillos en tramos verticales)
	var vuelta: Array[Vector3] = []
	for k in 17:
		var t := TAU * k / 16.0
		vuelta.append(Vector3(sin(t) * 0.014, 0.0, -(1.0 - cos(t)) * 0.024))
	var hilo := _malla(_tubo(vuelta, 0.0014, 4), rojo)
	hilo.name = "Hilo"
	hilo.rotation.x = PI / 2.0   # la z negativa de la vuelta queda hacia arriba
	hilo.position.y = OJO_RADIO * 0.92
	raiz.add_child(hilo)
	# Nudos arriba y abajo, y la borla: hebras que cuelgan del nudo de abajo, abiertas en abanico
	for y: float in [OJO_RADIO * 0.95, -OJO_RADIO * 1.0]:
		var nudo := SphereMesh.new()
		nudo.radius = 0.0035
		nudo.height = 0.007
		nudo.radial_segments = 6
		nudo.rings = 4
		var n := _malla(nudo, rojo)
		n.name = "Nudo"
		n.position.y = y
		raiz.add_child(n)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 502
	var arriba := Vector3(0.0, -OJO_RADIO - 0.006, 0.0)
	var amarre := Vector3(0.0, -OJO_RADIO - 0.012, 0.0)
	var hebras: Array[Vector3] = [arriba, amarre]
	var cuello := _malla(_tubo(hebras, 0.004, 6), rojo)
	cuello.name = "Amarre"
	raiz.add_child(cuello)
	for k in 14:
		var ang := TAU * k / 14.0
		var abre := rnd.randf_range(0.002, 0.006)
		var largo := rnd.randf_range(0.03, 0.038)
		var puntos: Array[Vector3] = [amarre + Vector3(cos(ang), 0.0, sin(ang)) * 0.0025,
			amarre + Vector3(cos(ang) * abre, -largo, sin(ang) * abre)]
		var h := _malla(_tubo(puntos, 0.0011, 3), rojo)
		h.name = "Hebra"
		raiz.add_child(h)
	return raiz


# Semilla de ojo de venado: cafe rojizo brilloso con vetitas mas oscuras y un brillo claro
func _semilla_venado() -> Texture2D:
	const T := 32
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 511
	var vetas := FastNoiseLite.new()
	vetas.seed = 512
	vetas.frequency = 0.15
	for y in T:
		for x in T:
			var c := Color(0.42, 0.22, 0.12).lightened(vetas.get_noise_2d(x, y * 2.0) * 0.12 + rnd.randf_range(-0.03, 0.03))
			if rnd.randf() > 0.94:
				c = c.darkened(0.3)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Estambre rojo: hebras torcidas (rayas diagonales)
func _estambre() -> Texture2D:
	const T := 8
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	for y in T:
		for x in T:
			var c := Color(0.78, 0.08, 0.08)
			if (x + y) % 4 < 2:
				c = c.darkened(0.25)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Collar de obsidiana (amuleto II: obsidiana + tela): cordon de algodon trenzado con cuentas
# de obsidiana talladas (las piedras de facetas del tilich) y de dije una punta de flecha de
# obsidiana amarrada con hilo. Acostado, como en el inventario ---

const COLLAR_A := 0.075
const COLLAR_B := 0.095


func _collar_obsidiana() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Collar"
	var vidrio := _vidrio_negro()
	# El cordon: una gota (elipse que se cierra en punta abajo, donde cuelga el dije), acostada en xz
	var cordon: Array[Vector3] = []
	for k in 41:
		var t := TAU * k / 40.0
		var z := cos(t) * COLLAR_B
		var x := sin(t) * COLLAR_A * (0.55 + 0.45 * (1.0 - cos(t)) * 0.5)
		cordon.append(Vector3(x, 0.0, -z))
	var c := _malla(_tubo(cordon, 0.0018, 4), _cordon_trenzado())
	c.name = "Cordon"
	raiz.add_child(c)
	# Cuentas de obsidiana en la mitad de abajo del collar, de mas chicas a mas grandes hacia el dije
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 521
	for k in range(-6, 7):
		if k == 0:
			continue
		var t := PI + k * 0.2   # t = PI es la punta de abajo
		var z := cos(t) * COLLAR_B
		var x := sin(t) * COLLAR_A * (0.55 + 0.45 * (1.0 - cos(t)) * 0.5)
		var radio := 0.0075 - absi(k) * 0.0006
		var cuenta := _malla(_piedra(radio, Vector3.ONE, 530 + k), vidrio)
		cuenta.name = "Cuenta"
		(cuenta.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.85)
		cuenta.position = Vector3(x, 0.0, -z)
		cuenta.rotation = Vector3(rnd.randf() * TAU, rnd.randf() * TAU, 0.0)
		raiz.add_child(cuenta)
	# El dije: punta de flecha, una placa con su contorno (filo con muescas, aletas y espiga)
	var punta := PackedVector2Array([
		Vector2(0.0, -0.045), Vector2(0.008, -0.03), Vector2(0.011, -0.022), Vector2(0.014, -0.01),
		Vector2(0.016, 0.004), Vector2(0.018, 0.012), Vector2(0.01, 0.009), Vector2(0.006, 0.012),
		Vector2(0.006, 0.02), Vector2(-0.006, 0.02), Vector2(-0.006, 0.012), Vector2(-0.01, 0.009),
		Vector2(-0.018, 0.012), Vector2(-0.016, 0.004), Vector2(-0.014, -0.01), Vector2(-0.011, -0.022),
		Vector2(-0.008, -0.03)])
	punta.reverse()   # _extruir quiere el contorno antihorario
	var dije := _malla(_extruir(punta, 0.005, Rect2(-0.02, -0.045, 0.04, 0.065)), vidrio)
	dije.name = "PuntaFlecha"
	(dije.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.9)
	dije.rotation.x = -PI / 2.0   # acostada; la punta hacia afuera del collar
	dije.position = Vector3(0.0, 0.0, COLLAR_B + 0.022)
	raiz.add_child(dije)
	# El amarre de la espiga al cordon: vueltas de hilo
	for k in 3:
		var aro := TorusMesh.new()
		aro.inner_radius = 0.0045
		aro.outer_radius = 0.0062
		aro.rings = 8
		aro.ring_segments = 4
		var a := _malla(aro, _cordon_trenzado())
		a.name = "Amarre"
		a.rotation.x = PI / 2.0
		a.position = Vector3(0.0, 0.0, COLLAR_B + 0.003 + k * 0.004)
		raiz.add_child(a)
	return raiz


# Cordon de algodon trenzado: cafe oscuro con la trenza en diagonal
func _cordon_trenzado() -> Texture2D:
	const T := 8
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	for y in T:
		for x in T:
			var c := Color(0.3, 0.2, 0.12)
			if (x + y) % 4 < 2:
				c = c.lightened(0.15)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Medalla de la Virgen (amuleto II: obsidiana + metal): medalla ovalada plateada con la Virgen
# del Tinaco en relieve claro y la orilla levantada, una cuenta de obsidiana engarzada arriba en
# el arillo, y cadena de bolitas. Acostada, como en el inventario ---

const MEDALLA_A := 0.016
const MEDALLA_B := 0.022


func _medalla_virgen() -> Node3D:
	var cuenta := _malla(_piedra(0.0045, Vector3.ONE, 551), _vidrio_negro())
	cuenta.name = "Obsidiana"
	return _medalla(_cara_medalla(), Color(0.72, 0.73, 0.76), cuenta, _bolitas(), 0.0026)


# Medalla acostada: la placa ovalada con `cara`, la orilla y el engarce de `metal`, la `piedra`
# engarzada arriba (z negativa) y la cadena con su textura y grueso
func _medalla(cara: Texture2D, metal: Color, piedra: Node3D, textura_cadena: Texture2D, grueso_cadena: float) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Medalla"
	var ovalo := PackedVector2Array()
	for k in 24:
		var t := TAU * k / 24.0
		ovalo.append(Vector2(cos(t) * MEDALLA_A, sin(t) * MEDALLA_B))
	var placa := _malla(_extruir(ovalo, 0.003, Rect2(-MEDALLA_A, -MEDALLA_B, MEDALLA_A * 2.0, MEDALLA_B * 2.0)), cara)
	placa.name = "Placa"
	(placa.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.75)
	placa.rotation.x = -PI / 2.0
	raiz.add_child(placa)
	# La orilla levantada
	var orilla := TorusMesh.new()
	orilla.inner_radius = MEDALLA_A - 0.0015
	orilla.outer_radius = MEDALLA_A + 0.0008
	orilla.rings = 24
	orilla.ring_segments = 4
	var plata := _liso(metal, 541)
	var o := _malla(orilla, plata)
	o.name = "Orilla"
	o.scale = Vector3(1.0, 1.4, MEDALLA_B / MEDALLA_A)
	(o.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.8)
	raiz.add_child(o)
	# Arriba (z negativa): el arillo con la cuenta de obsidiana engarzada
	var cuenta := piedra
	for nodo: Node in [cuenta] + cuenta.find_children("*", "MeshInstance3D", true, false):
		if nodo is MeshInstance3D and (nodo as MeshInstance3D).get_surface_override_material(0):
			((nodo as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.9)
	cuenta.position = Vector3(0.0, 0.0, -MEDALLA_B - 0.004)
	raiz.add_child(cuenta)
	var engarce := TorusMesh.new()
	engarce.inner_radius = 0.004
	engarce.outer_radius = 0.0052
	engarce.rings = 10
	engarce.ring_segments = 4
	var e := _malla(engarce, plata)
	e.name = "Engarce"
	e.position = cuenta.position
	raiz.add_child(e)
	var arillo := TorusMesh.new()
	arillo.inner_radius = 0.003
	arillo.outer_radius = 0.0045
	arillo.rings = 8
	arillo.ring_segments = 4
	var ar := _malla(arillo, plata)
	ar.name = "Arillo"
	ar.rotation.z = PI / 2.0
	ar.position = Vector3(0.0, 0.0, -MEDALLA_B - 0.011)
	raiz.add_child(ar)
	# Cadena de bolitas: un tubo delgado con la textura de bolitas, en gota hasta el arillo
	var cadena: Array[Vector3] = []
	for k in 41:
		var t := TAU * k / 40.0
		var z := -MEDALLA_B - 0.013 - (1.0 - cos(t)) * 0.08
		var x := sin(t) * 0.06 * (0.4 + 0.6 * (1.0 - cos(t)) * 0.5)
		cadena.append(Vector3(x, 0.0, z))
	var c := _malla(_tubo(cadena, grueso_cadena, 6), textura_cadena)
	c.name = "Cadena"
	(c.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.7)
	raiz.add_child(c)
	return raiz


# La cara de la medalla: plata con la Virgen del Tinaco en relieve claro (la figura y los rayos) y
# lo hundido mas oscuro
func _cara_medalla() -> Texture2D:
	const W := 24
	const H := 32
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 561
	var cx := (W - 1) * 0.5
	var cy := (H - 1) * 0.5
	for y in H:
		for x in W:
			var c := Color(0.5, 0.51, 0.54).lightened(rnd.randf_range(-0.03, 0.03))
			var e := Vector2((x - cx) / 10.0, (y - cy) / 14.0).length()
			var manto := Vector2((x - cx) / (2.0 + (y - cy + 5.0) * 0.22), (y - cy - 3.0) / 8.0).length() < 1.0 and y > cy - 5.0
			var cara := Vector2(x - cx, y - (cy - 8.0)).length() < 2.0
			var rayo := e > 0.62 and e < 0.85 and int(rad_to_deg(Vector2(x - cx, y - cy).angle()) + 360.0) % 30 < 8
			if manto or cara or rayo:
				c = Color(0.82, 0.83, 0.86).lightened(rnd.randf_range(-0.03, 0.03))
			# Sombra del relieve: un pixel oscuro abajo a la derecha de lo levantado
			elif _alto_medalla(x - 1, y - 1, cx, cy):
				c = c.darkened(0.25)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _alto_medalla(x: int, y: int, cx: float, cy: float) -> bool:
	var e := Vector2((x - cx) / 10.0, (y - cy) / 14.0).length()
	var manto := Vector2((x - cx) / (2.0 + (y - cy + 5.0) * 0.22), (y - cy - 3.0) / 8.0).length() < 1.0 and y > cy - 5.0
	var cara := Vector2(x - cx, y - (cy - 8.0)).length() < 2.0
	var rayo := e > 0.62 and e < 0.85 and int(rad_to_deg(Vector2(x - cx, y - cy).angle()) + 360.0) % 30 < 8
	return manto or cara or rayo


# Cadena de bolitas: a lo largo (v) bolita clara, junta oscura
func _bolitas() -> Texture2D:
	const H := 96
	var img := Image.create(4, H, false, Image.FORMAT_RGB8)
	for y in H:
		for x in 4:
			img.set_pixel(x, y, Color(0.75, 0.76, 0.78) if y % 2 == 0 else Color(0.3, 0.3, 0.32))
	return ImageTexture.create_from_image(img)


# --- Medalla de San Judas (amuleto III: cuarzo + metal): la misma medalla en dorado con San Judas
# Tadeo en esmalte (tunica verde sobre blanca, su medallon dorado en el pecho, la flamita sobre la
# cabeza y el baston), un cristal de cuarzo engarzado arriba y cadena gruesa dorada ---

func _medalla_san_judas() -> Node3D:
	var cuarzo := _malla(_prisma(0.004, 0.012), _cristal())
	cuarzo.name = "Cuarzo"
	cuarzo.rotation.x = -PI / 2.0   # el cristal acostado, con la punta hacia afuera de la medalla
	var engarzado := Node3D.new()
	engarzado.name = "Piedra"
	engarzado.add_child(cuarzo)
	cuarzo.position.z = 0.005
	return _medalla(_cara_san_judas(), Color(0.9, 0.72, 0.28), engarzado, _eslabones(), 0.003)


func _cara_san_judas() -> Texture2D:
	const W := 24
	const H := 32
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 571
	var cx := (W - 1) * 0.5
	var cy := (H - 1) * 0.5
	for y in H:
		for x in W:
			# Fondo dorado con un poco de grano
			var c := Color(0.85, 0.66, 0.25).lightened(rnd.randf_range(-0.05, 0.04))
			var e := Vector2((x - cx) / 10.5, (y - cy) / 14.5).length()
			if e > 0.86:
				c = Color(0.7, 0.52, 0.18)
			# Tunica blanca (abajo) y manto verde encima, mas angosto arriba
			var cuerpo := Vector2((x - cx) / (2.2 + (y - cy + 4.0) * 0.2), (y - cy - 3.5) / 8.5).length() < 1.0 and y > cy - 4.0
			var manto := cuerpo and absf(x - cx) > 1.5 + (y - cy) * 0.05
			if cuerpo:
				c = Color(0.92, 0.9, 0.85)
			if manto:
				c = Color(0.1, 0.5, 0.22).lightened(rnd.randf_range(-0.04, 0.04))
			# El medallon dorado en el pecho
			if Vector2(x - cx, y - (cy - 1.0)).length() < 1.6:
				c = Color(1.0, 0.82, 0.3)
			# Cara y la flamita encima
			if Vector2(x - cx, y - (cy - 7.0)).length() < 1.8:
				c = Color(0.82, 0.62, 0.45)
			if (y == int(cy - 10.0) or y == int(cy - 11.0)) and absf(x - cx) < 1.0:
				c = Color(1.0, 0.55, 0.1)
			# El baston, del lado derecho
			if x == int(cx + 5.0) and y > cy - 6.0 and y < cy + 10.0:
				c = Color(0.45, 0.28, 0.12)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Cadena dorada de eslabones: a lo largo, eslabon claro con su hueco oscuro
func _eslabones() -> Texture2D:
	const H := 96
	var img := Image.create(4, H, false, Image.FORMAT_RGB8)
	for y in H:
		for x in 4:
			var c := Color(0.95, 0.78, 0.32)
			if y % 3 == 2:
				c = Color(0.45, 0.32, 0.1)
			elif (x + y) % 2 == 0:
				c = c.darkened(0.12)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Pulsera de San Benito (amuleto III: cuarzo + tela): hilo rojo trenzado con nudos, cuentas de
# cuarzo entre ellos y la medallita redonda de San Benito (dorada, con la cruz negra y las letras
# en puntitos alrededor). Acostada ---

const PULSERA_RADIO := 0.034


func _pulsera_san_benito() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Pulsera"
	var hilo: Array[Vector3] = []
	for k in 33:
		var t := TAU * k / 32.0
		hilo.append(Vector3(cos(t), 0.0, sin(t)) * PULSERA_RADIO)
	var h := _malla(_tubo(hilo, 0.0022, 5), _estambre())
	h.name = "Hilo"
	raiz.add_child(h)
	var cristal := _cristal()
	var rojo := _estambre()
	# Del lado de enfrente (z negativa) la medalla; alrededor, cuarzo y nudo alternados
	for k in 12:
		var t := -PI * 0.5 + TAU * (k + 1) / 13.0
		var donde := Vector3(cos(t), 0.0, sin(t)) * PULSERA_RADIO
		if k % 2 == 0:
			var cuenta := _malla(_piedra(0.0042, Vector3.ONE, 580 + k), cristal)
			cuenta.name = "Cuarzo"
			(cuenta.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.9)
			cuenta.position = donde
			raiz.add_child(cuenta)
		else:
			var nudo := SphereMesh.new()
			nudo.radius = 0.0034
			nudo.height = 0.0068
			nudo.radial_segments = 6
			nudo.rings = 4
			var n := _malla(nudo, rojo)
			n.name = "Nudo"
			n.position = donde
			raiz.add_child(n)
	# La medallita: colgada del hilo por un arillo, acostada afuera de la pulsera
	var circulo := PackedVector2Array()
	for k in 16:
		var t := TAU * k / 16.0
		circulo.append(Vector2(cos(t), sin(t)) * 0.0085)
	var medalla := _malla(_extruir(circulo, 0.0018, Rect2(-0.0085, -0.0085, 0.017, 0.017)), _cara_san_benito())
	medalla.name = "Medalla"
	(medalla.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.8)
	medalla.rotation.x = -PI / 2.0
	medalla.position = Vector3(0.0, 0.0, -PULSERA_RADIO - 0.013)
	raiz.add_child(medalla)
	var arillo := TorusMesh.new()
	arillo.inner_radius = 0.0018
	arillo.outer_radius = 0.0027
	arillo.rings = 8
	arillo.ring_segments = 4
	var a := _malla(arillo, _liso(Color(0.9, 0.72, 0.28), 591))
	a.name = "Arillo"
	a.rotation.z = PI / 2.0
	a.position = Vector3(0.0, 0.0, -PULSERA_RADIO - 0.003)
	raiz.add_child(a)
	return raiz


# Medalla de San Benito: dorada con orilla, la cruz negra al centro y las letras de alrededor en
# puntitos oscuros
func _cara_san_benito() -> Texture2D:
	const T := 20
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 601
	var c0 := (T - 1) * 0.5
	for y in T:
		for x in T:
			var r := Vector2(x - c0, y - c0).length()
			var c := Color(0.88, 0.7, 0.28).lightened(rnd.randf_range(-0.04, 0.04))
			if r > 8.6:
				c = Color(0.72, 0.54, 0.18)
			elif r > 6.0 and r < 7.6 and (x + y) % 2 == 0:
				c = Color(0.3, 0.22, 0.1)   # las letras de alrededor
			if (absf(x - c0) < 1.0 and absf(y - c0) < 5.0) or (absf(y - c0) < 1.0 and absf(x - c0) < 5.0):
				c = Color(0.08, 0.07, 0.06)   # la cruz
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Liston de la Virgen (amuleto IV: cuarzo + tela + Marca de cazador): liston de satin azul con
# orilla dorada y la Virgen del Tinaco estampada a lo largo, amarrado en moño (dos gazas y dos
# colas); de una cola cuelga la Marca de cazador (el trofeo) y de la otra un cristal de cuarzo.
# Acostado ---

const LISTON_ANCHO := 0.022


func _liston_virgen() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Liston"
	var tela := _satin_virgen()
	# Gazas del moño: vueltas que salen del nudo y regresan
	for lado: float in [-1.0, 1.0]:
		var gaza: Array[Vector2] = []
		for k in 13:
			var t := PI * k / 12.0
			gaza.append(Vector2(lado * (0.006 + sin(t) * 0.045), -cos(t) * 0.016 - 0.002))
		var g := _malla(_tira(gaza, LISTON_ANCHO * 0.9, 0.0), tela)
		g.name = "Gaza"
		raiz.add_child(g)
	# Colas: bajan ondulando, una mas larga que la otra
	var finales: Array[Vector2] = []
	for datos: Array in [[-1.0, 0.13], [1.0, 0.11]]:
		var lado: float = datos[0]
		var largo: float = datos[1]
		var cola: Array[Vector2] = []
		for k in 13:
			var t := k / 12.0
			cola.append(Vector2(lado * (0.006 + t * 0.035 + sin(t * 5.0) * 0.008), 0.004 + t * largo))
		var c := _malla(_tira(cola, LISTON_ANCHO, 0.0006), tela)
		c.name = "Cola"
		raiz.add_child(c)
		finales.append(cola[-1])
	# El nudo
	var nudo := _malla(_caja(Vector3(0.016, 0.006, 0.02)), _liso(Color(0.15, 0.3, 0.68), 611))   # azul: la caja tomaba la orilla dorada
	nudo.name = "Nudo"
	nudo.position.y = 0.002
	raiz.add_child(nudo)
	# La Marca de cazador en la punta de la cola larga (acostada, el cordon hacia la cola)
	var marca := _marca_cazador()
	marca.scale = Vector3.ONE * 0.55
	marca.rotation.x = -PI / 2.0
	marca.position = Vector3(finales[0].x, 0.002, finales[0].y + 0.026)
	raiz.add_child(marca)
	# El cuarzo en la punta de la otra, acostado con la punta hacia afuera
	var cuarzo := _malla(_prisma(0.006, 0.026), _cristal())
	cuarzo.name = "Cuarzo"
	(cuarzo.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.9)
	cuarzo.rotation.x = PI / 2.0
	cuarzo.position = Vector3(finales[1].x, 0.004, finales[1].y)
	raiz.add_child(cuarzo)
	return raiz


# Tira plana acostada en xz que sigue `puntos` (x, z), con su ancho: cara de arriba y de abajo
# (las dos se ven), u a lo ancho y v a lo largo. `alto` sube la tira un poco (que no se pele con
# lo que tiene abajo)
func _tira(puntos: Array[Vector2], ancho: float, alto: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bordes: Array = []
	for i in puntos.size():
		var adelante := (puntos[mini(i + 1, puntos.size() - 1)] - puntos[maxi(i - 1, 0)]).normalized()
		var lado := Vector2(-adelante.y, adelante.x) * ancho * 0.5
		bordes.append([Vector3(puntos[i].x - lado.x, alto, puntos[i].y - lado.y), Vector3(puntos[i].x + lado.x, alto, puntos[i].y + lado.y)])
	for i in puntos.size() - 1:
		var a: Vector3 = bordes[i][0]
		var b: Vector3 = bordes[i][1]
		var c: Vector3 = bordes[i + 1][1]
		var d: Vector3 = bordes[i + 1][0]
		var v0 := float(i) / (puntos.size() - 1)
		var v1 := float(i + 1) / (puntos.size() - 1)
		var uv := [Vector2(0, v0), Vector2(1, v0), Vector2(1, v1), Vector2(0, v1)]
		for normal: Vector3 in [Vector3.UP, Vector3.DOWN]:
			var orden := [0, 1, 2, 0, 2, 3]
			if (b - a).cross(c - a).dot(normal) > 0.0:
				orden = [0, 2, 1, 0, 3, 2]
			var q := [a, b, c, d]
			var desfase := normal * 0.0002   # la de abajo un pelito abajo
			for k in orden:
				st.set_uv(uv[k])
				st.add_vertex(q[k] + (desfase if normal == Vector3.DOWN else Vector3.ZERO) * -1.0)
	st.generate_normals()
	return st.commit()


# Satin azul con orilla dorada y la Virgen del Tinaco estampada cada tanto, con su brillo claro
# a lo largo (u a lo ancho, v a lo largo)
func _satin_virgen() -> Texture2D:
	const W := 12
	const H := 64
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	for y in H:
		for x in W:
			var c := Color(0.16, 0.32, 0.72)
			if x == 4 or x == 5:
				c = c.lightened(0.18)   # el brillo del satin
			if x == 0 or x == W - 1:
				c = Color(0.92, 0.76, 0.28)
			# Una Virgen cada 16 renglones: manto claro en campana y la cabeza, con rayitos dorados
			var yy := y % 16
			var cx := (W - 1) * 0.5
			var manto := yy > 5 and yy < 13 and absf(x - cx) < 0.6 + (yy - 5) * 0.35
			var cabeza := yy >= 3 and yy <= 4 and absf(x - cx) < 1.0
			if manto or cabeza:
				c = Color(0.92, 0.88, 0.75)
			elif (yy == 2 or yy == 14) and x % 2 == 1 and x > 1 and x < W - 2:
				c = Color(0.95, 0.8, 0.3)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Collar de la Santa Muerte (amuleto IV: metal + Casco de GelA; referencia de JJ): dije de
# plata de la Santa Muerte, flaca, con el manto cuajado de piedritas negras, la calavera plateada
# descubierta (cuencas con ojos rojos, nariz, dientes), mangas, la mano de hueso agarrando la
# guadaña, la aureola de rueda de rayos atras y un tecolotito a los pies; asa de triangulo con
# piedras y la cadena completa, gruesa. Sin balanza, casco ni capucha (JJ). Parada, de frente ---

const MUERTE_CARA := Vector3(0.0, 0.0545, 0.0)


func _collar_santa_muerte() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "SantaMuerte"
	var plata := _liso(Color(0.66, 0.67, 0.7), 621)
	var piedras := _piedritas_negras()
	var negro := _liso(Color(0.04, 0.04, 0.05), 624)
	var brilla := func(m: MeshInstance3D, b: float) -> void:
		(m.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", b)
	# El manto: hombros anchos, se cierra poco en la cintura y abre en campana abajo; termina en
	# el cuello (la capucha va aparte)
	var perfil: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.0108, 0.0), Vector2(0.011, 0.005),
		Vector2(0.0094, 0.018), Vector2(0.0084, 0.03), Vector2(0.0092, 0.04), Vector2(0.0088, 0.045),
		Vector2(0.0066, 0.0485), Vector2(0.0, 0.05)]   # flaca (JJ): es la muerte
	var manto := _malla(_torno(perfil, 18), piedras)
	manto.name = "Manto"
	manto.scale = Vector3(1.0, 1.0, 0.72)
	brilla.call(manto, 0.8)
	raiz.add_child(manto)
	# Las mangas: bultos a los lados, de los hombros a la cadera
	for lado: float in [-1.0, 1.0]:
		var manga := SphereMesh.new()
		manga.radius = 0.0031
		manga.height = 0.0062
		manga.radial_segments = 10
		manga.rings = 6
		var m := _malla(manga, piedras)
		m.name = "Manga"
		m.scale = Vector3(1.0, 2.7, 0.9)
		m.rotation.z = lado * 0.12
		m.position = Vector3(lado * 0.0084, 0.033, 0.0006)
		brilla.call(m, 0.8)
		raiz.add_child(m)
	# La calavera: craneo, quijada con dientes, cuencas negras con el ojo rojo, nariz
	var craneo := SphereMesh.new()
	craneo.radius = 0.0042
	craneo.height = 0.0084
	craneo.radial_segments = 10
	craneo.rings = 6
	var cr := _malla(craneo, plata)
	cr.name = "Craneo"
	cr.scale = Vector3(0.95, 1.0, 0.9)
	cr.position = MUERTE_CARA + Vector3(0.0, 0.0008, 0.0018)
	brilla.call(cr, 0.85)
	raiz.add_child(cr)
	# El cuello: vertebras de la calavera al manto (si no, la cabeza flotaba)
	var cuello := CylinderMesh.new()
	cuello.top_radius = 0.0017
	cuello.bottom_radius = 0.0022
	cuello.height = 0.0065
	cuello.radial_segments = 6
	var cu_ := _malla(cuello, plata)
	cu_.name = "Cuello"
	cu_.position = MUERTE_CARA + Vector3(0.0, -0.0048, 0.0008)
	raiz.add_child(cu_)
	var quijada := _malla(_caja(Vector3(0.0052, 0.0032, 0.004)), _dientes())
	quijada.name = "Quijada"
	quijada.position = MUERTE_CARA + Vector3(0.0, -0.0032, 0.0033)
	brilla.call(quijada, 0.8)
	raiz.add_child(quijada)
	var rojo := _liso(Color(1.0, 0.06, 0.06), 622)
	for lado: float in [-1.0, 1.0]:
		var cuenca := SphereMesh.new()
		cuenca.radius = 0.0014
		cuenca.height = 0.0028
		cuenca.radial_segments = 8
		cuenca.rings = 4
		var cu := _malla(cuenca, negro)
		cu.name = "Cuenca"
		cu.scale = Vector3(1.0, 0.9, 0.5)
		cu.position = MUERTE_CARA + Vector3(lado * 0.0017, 0.0008, 0.0055)
		raiz.add_child(cu)
		var ojo := SphereMesh.new()
		ojo.radius = 0.0008
		ojo.height = 0.0016
		ojo.radial_segments = 6
		ojo.rings = 3
		var o := _malla(ojo, rojo)
		o.name = "Ojo"
		brilla.call(o, 1.0)
		o.position = MUERTE_CARA + Vector3(lado * 0.0017, 0.0008, 0.006)
		raiz.add_child(o)
	var nariz := PackedVector2Array([Vector2(0.0, -0.0008), Vector2(0.0007, 0.0006), Vector2(-0.0007, 0.0006)])
	nariz.reverse()
	var na := _malla(_extruir(nariz, 0.0006, Rect2(-0.0007, -0.0008, 0.0014, 0.0014)), negro)
	na.name = "Nariz"
	na.position = MUERTE_CARA + Vector3(0.0, -0.0011, 0.0058)
	raiz.add_child(na)
	# La aureola: una rueda de rayos atras de la capucha
	# Pegada a la nuca y a los hombros (JJ: flotaba): el aro entra al manto abajo y los rayos van
	# de la calavera al aro
	var centro_aureola := MUERTE_CARA + Vector3(0.0, 0.0015, -0.0032)
	var aro := TorusMesh.new()
	aro.inner_radius = 0.0118
	aro.outer_radius = 0.0138
	aro.rings = 24
	aro.ring_segments = 4
	var a := _malla(aro, plata)
	a.name = "Aureola"
	a.rotation.x = PI / 2.0
	a.position = centro_aureola
	brilla.call(a, 0.85)
	raiz.add_child(a)
	for k in 18:
		var ang := TAU * k / 18.0
		var rayo := _malla(_caja(Vector3(0.001, 0.0092, 0.0009)), plata)
		rayo.name = "Rayo"
		rayo.rotation.z = ang - PI / 2.0
		rayo.position = centro_aureola + Vector3(cos(ang), sin(ang), 0.0) * 0.0084
		raiz.add_child(rayo)
	# La guadaña: baston del piso hasta arriba de la cabeza, a un lado, y la hoja curva hacia afuera
	var frente := 0.0062   # pegada al manto
	var baston: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -0.067)]
	var b := _malla(_tubo(baston, 0.0009, 5), plata)
	b.name = "Baston"
	b.rotation.x = PI / 2.0   # armado en z negativa: se para hacia arriba
	b.position = Vector3(0.0046, 0.001, frente)
	raiz.add_child(b)
	var hoja: Array[Vector3] = []
	var grueso: Array = []
	for k in 11:
		var t := k / 10.0
		hoja.append(Vector3(0.0046 + sin(t * PI * 0.6) * 0.022, 0.0, -(0.066 - (1.0 - cos(t * PI * 0.6)) * 0.024)))
		grueso.append(0.0022 * (1.0 - t * 0.85))
	var h := _malla(_tubo(hoja, 1.0, 5, grueso), plata)
	h.name = "Hoja"
	h.rotation.x = PI / 2.0
	h.position = Vector3(0.0, 0.001, frente)
	h.scale = Vector3(1.0, 0.4, 1.0)   # plana: el y local queda a lo hondo
	brilla.call(h, 0.9)
	raiz.add_child(h)
	# La mano de hueso agarrando el baston: nudillos y dedos que le dan la vuelta
	var mano := _malla(_caja(Vector3(0.0034, 0.0026, 0.0016)), plata)
	mano.name = "Mano"
	mano.position = Vector3(0.0034, 0.037, frente + 0.0006)
	raiz.add_child(mano)
	for k in 4:
		var dedo := _malla(_caja(Vector3(0.0011, 0.0006, 0.0028)), plata)
		dedo.name = "Dedo"
		dedo.position = Vector3(0.005, 0.0358 + k * 0.0008, frente + 0.0003)
		raiz.add_child(dedo)
	# El tecolotito a los pies, de frente
	var tecolote := SphereMesh.new()
	tecolote.radius = 0.0024
	tecolote.height = 0.0048
	tecolote.radial_segments = 8
	tecolote.rings = 5
	var te := _malla(tecolote, plata)
	te.name = "Tecolote"
	te.scale = Vector3(1.0, 1.25, 0.6)
	te.position = Vector3(-0.0015, 0.0042, 0.0081)
	brilla.call(te, 0.85)
	raiz.add_child(te)
	for lado: float in [-1.0, 1.0]:
		var ojito := SphereMesh.new()
		ojito.radius = 0.0007
		ojito.height = 0.0014
		ojito.radial_segments = 6
		ojito.rings = 3
		var oj := _malla(ojito, negro)
		oj.name = "OjoTecolote"
		oj.position = te.position + Vector3(lado * 0.0009, 0.0012, 0.0013)
		raiz.add_child(oj)
		var oreja := _malla(_caja(Vector3(0.0008, 0.0014, 0.0008)), plata)
		oreja.name = "Oreja"
		oreja.rotation.z = -lado * 0.4
		oreja.position = te.position + Vector3(lado * 0.0015, 0.0031, 0.0)
		raiz.add_child(oreja)
	# El asa: aro chico y el triangulo con piedras
	var argolla := TorusMesh.new()
	argolla.inner_radius = 0.0016
	argolla.outer_radius = 0.0024
	argolla.rings = 8
	argolla.ring_segments = 4
	var ar := _malla(argolla, plata)
	ar.name = "Argolla"
	ar.rotation.z = PI / 2.0
	ar.position = Vector3(0.0, 0.0705, -0.0032)   # colgada de lo alto de la aureola
	raiz.add_child(ar)
	var triangulo := PackedVector2Array([Vector2(0.0016, -0.0035), Vector2(0.0048, 0.009), Vector2(-0.0048, 0.009), Vector2(-0.0016, -0.0035)])
	var asa := _malla(_extruir(triangulo, 0.0035, Rect2(-0.0048, -0.0035, 0.0096, 0.0125)), piedras)
	asa.name = "Asa"
	brilla.call(asa, 0.8)
	asa.position = Vector3(0.0, 0.0765, -0.0032)
	raiz.add_child(asa)
	# La cadena completa: gruesa y ostentosa (JJ), eslabones alternados (uno de canto, uno de
	# frente) en una gota cerrada que sale del asa, sube y da la vuelta atras
	var camino: Array[Vector3] = []
	for k in 121:
		var t := TAU * k / 120.0
		camino.append(Vector3(sin(t) * 0.042 * (0.35 + 0.65 * sin(t * 0.5)), 0.0825 + (1.0 - cos(t)) * 0.06, -0.0032 - (1.0 - cos(t)) * 0.006))
	var largos: Array[float] = [0.0]
	for k in range(1, camino.size()):
		largos.append(largos[-1] + camino[k].distance_to(camino[k - 1]))
	const PASO := 0.0062
	var cuantos := int(largos[-1] / PASO)
	var tramo := 1
	for k in cuantos:
		var donde := largos[-1] * k / cuantos
		while tramo < camino.size() - 1 and largos[tramo] < donde:
			tramo += 1
		var f := (donde - largos[tramo - 1]) / maxf(largos[tramo] - largos[tramo - 1], 0.000001)
		var p := camino[tramo - 1].lerp(camino[tramo], f)
		var d := (camino[tramo] - camino[tramo - 1]).normalized()
		var eslabon := TorusMesh.new()
		eslabon.inner_radius = 0.0026
		eslabon.outer_radius = 0.0047
		eslabon.rings = 10
		eslabon.ring_segments = 6
		var e := _malla(eslabon, plata)
		e.name = "Eslabon"
		brilla.call(e, 0.95)
		var n := Vector3.BACK if k % 2 == 0 else d.cross(Vector3.BACK).normalized()
		n = (n - d * n.dot(d)).normalized()
		e.basis = Basis(d, n, d.cross(n)).scaled_local(Vector3(1.4, 1.0, 1.0))
		e.position = p
		raiz.add_child(e)
	return raiz


# Dientes de la calavera (la cara de enfrente de la quijada): plata con la raya de la mordida y
# las rayitas entre diente y diente
func _dientes() -> Texture2D:
	const W := 12
	const H := 8
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	for y in H:
		for x in W:
			var c := Color(0.75, 0.76, 0.8)
			if y == 3 or y == 4:
				c = Color(0.08, 0.08, 0.1)   # la mordida
			elif y > 1 and y < 7 and x % 2 == 0 and x > 0 and x < W - 1:
				c = Color(0.3, 0.3, 0.33)   # entre dientes
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Torneado: gira el `perfil` (x = radio, y = alto, de abajo hacia arriba) alrededor del eje y, de
# `desde` a `hasta` (0 es de frente, +z; menos de una vuelta deja abierto el frente). u da la
# vuelta, v sube
func _torno(perfil: Array[Vector2], lados: int, desde := 0.0, hasta := TAU) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var largo: Array[float] = [0.0]   # v por largo del perfil, que las piedritas no se estiren
	for i in perfil.size() - 1:
		largo.append(largo[-1] + perfil[i].distance_to(perfil[i + 1]))
	for i in perfil.size() - 1:
		for k in lados:
			var t0 := desde + (hasta - desde) * k / lados
			var t1 := desde + (hasta - desde) * (k + 1) / lados
			var p0 := perfil[i]
			var p1 := perfil[i + 1]
			var a := Vector3(sin(t0) * p0.x, p0.y, cos(t0) * p0.x)
			var b := Vector3(sin(t1) * p0.x, p0.y, cos(t1) * p0.x)
			var c := Vector3(sin(t1) * p1.x, p1.y, cos(t1) * p1.x)
			var d := Vector3(sin(t0) * p1.x, p1.y, cos(t0) * p1.x)
			var v0 := 1.0 - largo[i] / largo[-1]
			var v1 := 1.0 - largo[i + 1] / largo[-1]
			var uv := [Vector2(float(k) / lados, v0), Vector2(float(k + 1) / lados, v0), Vector2(float(k + 1) / lados, v1), Vector2(float(k) / lados, v1)]
			var q := [a, b, c, d]
			var afuera := Vector3(sin((t0 + t1) * 0.5), 0.0, cos((t0 + t1) * 0.5))
			var orden := [0, 1, 2, 0, 2, 3]
			var cruz := (b - a).cross(c - a) if (b - a).length() > 0.000001 else (c - a).cross(d - a)
			if cruz.dot(afuera + Vector3.UP * 0.01) > 0.0:
				orden = [0, 2, 1, 0, 3, 2]
			for j in orden:
				st.set_uv(uv[j])
				st.add_vertex(q[j])
	st.generate_normals()
	return st.commit()


# Plata cuajada de piedritas negras con su brillito, y la orilla del manto abierta de frente en
# plata lisa (u = 0 es el frente)
func _piedritas_negras() -> Texture2D:
	const C := 8     # una piedrita redonda por celda de 8 px, en panal (en 6 px salian cuadradas)
	const W := 256
	const H := 224
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 631
	for y in H:
		for x in W:
			var c := Color(0.62, 0.63, 0.67).lightened(rnd.randf_range(-0.06, 0.04))
			var renglon := y / C
			var fx := float((x + (C / 2 if renglon % 2 == 1 else 0)) % C) - 3.5
			var fy := float(y % C) - 3.5
			var r := Vector2(fx, fy).length()
			if r < 3.4:
				c = Color(0.05, 0.05, 0.06)
				if fx < 0.0 and fy < 0.0 and r < 2.2 and r > 0.8:
					c = Color(0.32, 0.32, 0.38)   # el brillo de la piedra, arriba a la izquierda
			if x <= 3 or x >= W - 4:
				c = Color(0.78, 0.79, 0.83)   # la orilla del manto, abierto de frente
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

# --- Marro (linea pesada II, despues del tubo: JJ): marro de albañil de 4 libras. Cabeza de acero forjado ochavada
# (cuadrada con las esquinas biseladas) con las caras de golpe aplastadas y claras, mango de
# madera con la cola pintada de rojo (para que no se lo lleven de la obra), el agarre sudado y
# salpicaduras de mezcla. El mango va en x negativa y la cabeza en el origen, a lo largo de y ---

const MARRO_CABEZA := 0.13      # m de cara a cara
const MARRO_LADO := 0.048       # m de lado de la cabeza
const MARRO_BISEL := 0.011      # m que se come cada esquina
const MARRO_MANGO := 0.36       # m de la cola a la cabeza
const MARRO_RADIO := 0.0135


func _marro() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Marro"
	var cabeza := _malla(_cabeza_marro(false), _acero_marro())
	cabeza.name = "Cabeza"
	(cabeza.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.25)
	raiz.add_child(cabeza)
	var caras := _malla(_cabeza_marro(true), _cara_marro())
	caras.name = "Caras"
	(caras.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("brillo", 0.7)
	raiz.add_child(caras)
	# Mango: puntos parejos (la v de _tubo va por punto), mas grueso en la cola, adelgaza en el
	# cuello y engorda otra vez donde entra a la cabeza
	var puntos: Array[Vector3] = []
	var radios: Array = []
	const PASOS := 16
	for i in PASOS + 1:
		var t := float(i) / PASOS
		puntos.append(Vector3(-MARRO_MANGO + t * (MARRO_MANGO + MARRO_LADO * 0.5), 0.0, 0.0))
		var r := MARRO_RADIO
		if t < 0.06:
			r *= 1.25 - t * 2.0
		elif t > 0.7 and t < 0.9:
			r *= 0.88
		radios.append(r)
	var mango := _malla(_tubo(puntos, MARRO_RADIO, 8, radios), _mango_marro())
	mango.name = "Mango"
	raiz.add_child(mango)
	# La cola del mango, tapada (el tubo sale abierto), roja como la pintura
	var cola := CylinderMesh.new()
	cola.top_radius = MARRO_RADIO * 1.2
	cola.bottom_radius = MARRO_RADIO * 1.2
	cola.height = 0.004
	cola.radial_segments = 8
	var c := _malla(cola, _liso(Color(0.62, 0.12, 0.08), 201))
	c.name = "Cola"
	c.rotation.z = PI / 2.0
	c.position.x = -MARRO_MANGO
	raiz.add_child(c)
	# Arriba de la cabeza asoma la punta del mango con su cuña de fierro atravesada
	var ojo := _malla(_caja(Vector3(0.002, MARRO_RADIO * 1.5, MARRO_RADIO * 2.0)), _liso(Color(0.55, 0.4, 0.24), 202))
	ojo.name = "PuntaMango"
	ojo.position.x = MARRO_LADO * 0.5 + 0.0005
	raiz.add_child(ojo)
	var cuna := _malla(_caja(Vector3(0.0026, 0.003, MARRO_RADIO * 1.9)), _liso(Color(0.22, 0.22, 0.23), 203))
	cuna.name = "Cuna"
	cuna.position.x = MARRO_LADO * 0.5 + 0.0008
	raiz.add_child(cuna)
	return raiz


# Ochavo a lo largo de y: costados y biseles (caras = false) o solo las dos caras de golpe
func _cabeza_marro(caras: bool) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var h := MARRO_LADO * 0.5
	var b := MARRO_BISEL
	var perfil: Array[Vector2] = [Vector2(h, h - b), Vector2(h - b, h), Vector2(-h + b, h), Vector2(-h, h - b),
		Vector2(-h, -h + b), Vector2(-h + b, -h), Vector2(h - b, -h), Vector2(h, -h + b)]
	var y := MARRO_CABEZA * 0.5
	# [altura, escala del ochavo]: la orilla de cada cara va biselada (las caras se aplastan con el uso)
	var anillos := [[-y, 0.8], [-y + 0.007, 1.0], [y - 0.007, 1.0], [y, 0.8]]
	var tri := func(a: Vector3, bb: Vector3, cc: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
		# Frente horario visto desde afuera (Godot): si la normal sale, se voltea
		if (bb - a).cross(cc - a).dot((a + bb + cc) / 3.0) > 0.0:
			var t := bb; bb = cc; cc = t
			var tu := ub; ub = uc; uc = tu
		for par in [[a, ua], [bb, ub], [cc, uc]]:
			st.set_uv(par[1])
			st.add_vertex(par[0])
	var punto := func(i: int, k: int) -> Vector3:
		var p: Vector2 = perfil[k % 8] * float(anillos[i][1])
		return Vector3(p.x, float(anillos[i][0]), p.y)
	if caras:
		for lado in [0, 3]:
			var centro := Vector3(0.0, float(anillos[lado][0]), 0.0)
			for k in 8:
				var p0: Vector3 = punto.call(lado, k)
				var p1: Vector3 = punto.call(lado, k + 1)
				tri.call(centro, p0, p1, Vector2(0.5, 0.5), Vector2(0.5 + p0.x / MARRO_LADO, 0.5 + p0.z / MARRO_LADO),
					Vector2(0.5 + p1.x / MARRO_LADO, 0.5 + p1.z / MARRO_LADO))
	else:
		for i in 3:
			for k in 8:
				var u0 := k / 8.0
				var u1 := (k + 1) / 8.0
				var v0 := (float(anillos[i][0]) + y) / MARRO_CABEZA
				var v1 := (float(anillos[i + 1][0]) + y) / MARRO_CABEZA
				var a: Vector3 = punto.call(i, k)
				var bb: Vector3 = punto.call(i, k + 1)
				var cc: Vector3 = punto.call(i + 1, k + 1)
				var d: Vector3 = punto.call(i + 1, k)
				tri.call(a, bb, cc, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1))
				tri.call(a, cc, d, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1))
	st.generate_normals()
	return st.commit()


# Acero forjado: gris casi negro con la cascarilla, oxido en manchas y en las orillas, rayones
# claros y salpicaduras de mezcla gris
func _acero_marro() -> Texture2D:
	const T := 32
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 211
	var ruido := FastNoiseLite.new()
	ruido.seed = 211
	ruido.frequency = 0.12
	var mezcla := FastNoiseLite.new()
	mezcla.seed = 212
	mezcla.frequency = 0.2
	for y in T:
		for x in T:
			var c := Color(0.2, 0.2, 0.21).lightened(rnd.randf_range(-0.04, 0.06))
			var n := (ruido.get_noise_2d(x, y) + 1.0) * 0.5
			var orilla := y < 2 or y > T - 3
			if n < 0.3 or (orilla and rnd.randf() < 0.6):
				c = Color(0.38, 0.2, 0.09).lerp(Color(0.55, 0.3, 0.12), rnd.randf())
			if rnd.randf() > 0.96:
				c = Color(0.5, 0.5, 0.52)
			if mezcla.get_noise_2d(x, y) > 0.45:
				c = Color(0.66, 0.64, 0.6).darkened(rnd.randf_range(0.0, 0.12))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Cara de golpe: acero claro de tanto pegar, con abolladuras y la orilla mas oscura
func _cara_marro() -> Texture2D:
	const T := 16
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 221
	for y in T:
		for x in T:
			var d := Vector2(x - T * 0.5 + 0.5, y - T * 0.5 + 0.5).length() / (T * 0.5)
			var c := Color(0.62, 0.62, 0.64).lerp(Color(0.32, 0.31, 0.3), clampf((d - 0.55) * 2.0, 0.0, 1.0))
			c = c.lightened(rnd.randf_range(-0.06, 0.06))
			if rnd.randf() > 0.9:
				c = c.darkened(0.25)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Madera del mango: u alrededor, v de la cola (0) a la cabeza (1). Vetas a lo largo, la cola
# pintada de rojo, el agarre oscuro de sudor y mugre, y mezcla salpicada cerca de la cabeza
func _mango_marro() -> Texture2D:
	const W := 16
	const H := 48
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 231
	var vetas: Array[float] = []
	for x in W:
		vetas.append(rnd.randf_range(-0.07, 0.07))
	for y in H:
		var v := float(y) / (H - 1)
		for x in W:
			var c := Color(0.6, 0.43, 0.25).lightened(vetas[(x + int(y / 9.0)) % W] + rnd.randf_range(-0.03, 0.03))
			if (x * 5 + y / 6) % 7 == 0:
				c = c.darkened(0.18)
			if v < 0.07:
				c = Color(0.62, 0.12, 0.08).lightened(rnd.randf_range(-0.05, 0.08))
				if rnd.randf() > 0.85:
					c = Color(0.6, 0.43, 0.25)   # la pintura descarapelada
			elif v < 0.42:
				c = c.darkened(0.3 + rnd.randf_range(0.0, 0.08))
			if v > 0.72 and rnd.randf() > 0.88:
				c = Color(0.66, 0.64, 0.6)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Placa plana: el contorno arriba y abajo (en +-Z) con sus lados; la uv sale de `marco`
func _extruir(contorno: PackedVector2Array, grueso: float, marco: Rect2) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var tris := Geometry2D.triangulate_polygon(contorno)
	var uv := func(p: Vector2) -> Vector2: return Vector2((p.x - marco.position.x) / marco.size.x, 1.0 - (p.y - marco.position.y) / marco.size.y)
	for lado in [1.0, -1.0]:
		for t in range(0, tris.size(), 3):
			var orden := [tris[t], tris[t + 2], tris[t + 1]] if lado > 0.0 else [tris[t], tris[t + 1], tris[t + 2]]
			for k: int in orden:
				st.set_uv(uv.call(contorno[k]))
				st.add_vertex(Vector3(contorno[k].x, contorno[k].y, lado * grueso * 0.5))
	for i in contorno.size():
		var a := contorno[i]
		var b := contorno[(i + 1) % contorno.size()]
		var q := [Vector3(a.x, a.y, grueso * 0.5), Vector3(a.x, a.y, -grueso * 0.5), Vector3(b.x, b.y, -grueso * 0.5), Vector3(b.x, b.y, grueso * 0.5)]
		_cara(st, q, [uv.call(a), uv.call(a), uv.call(b), uv.call(b)])
	st.generate_normals()
	return st.commit()


# Hoja: acero gris con rayas de afilado a lo largo, el filo claro abajo y oxido segun el tier
func _hoja_machete(estilo: Dictionary) -> Texture2D:
	const W := 96
	const H := 24
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = estilo["semilla"]
	var ruido := FastNoiseLite.new()
	ruido.seed = estilo["semilla"]
	ruido.frequency = 0.12
	var oxido: float = estilo.get("oxido", 0.0)
	var vetas := FastNoiseLite.new()
	vetas.seed = estilo["semilla"]
	vetas.frequency = 0.05
	var filas := []
	for y in H:
		filas.append(rnd.randf_range(-0.04, 0.04))
	for y in H:
		for x in W:
			var c: Color = (estilo.get("acero", Color(0.42, 0.44, 0.47)) as Color).lightened(filas[y] + rnd.randf_range(-0.02, 0.02))
			if y >= H - 4 and not estilo.has("forma"):
				c = Color(0.75, 0.77, 0.8)   # el filo
			if estilo.get("forma", "") == "sierra" and y >= H - 8:
				c = Color(0.7, 0.72, 0.75).lightened(rnd.randf_range(-0.03, 0.03))   # el filo amolado
			if estilo.get("cobalto", false):
				# Vetas de cobalto que corren a lo largo y se ramifican; el filo y los dientes azul claro
				if y >= H - 8 or y <= 1:
					c = Color(0.45, 0.8, 1.0).lightened(rnd.randf_range(-0.05, 0.1))
				else:
					# Grietas: donde el ruido (suave y estirado a lo largo) cruza el cero
					var v := vetas.get_noise_2d(x * 0.5, y * 1.6)
					if absf(v) < 0.045:
						c = Color(0.3, 0.7, 1.0)
					elif absf(v) < 0.09:
						c = c.lerp(Color(0.1, 0.3, 0.6), 0.6)
			var n := (ruido.get_noise_2d(x, y) + 1.0) * 0.5
			if n < oxido and y < H - 2:
				var o := Color(0.45, 0.22, 0.09).lerp(Color(0.62, 0.33, 0.12), rnd.randf())
				c = o.darkened(rnd.randf_range(0.0, 0.25)) if n < oxido * 0.8 else c.lerp(o, 0.5)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Tapa del mango: naranja, o el color de `tapa` con el trebol de radiacion negro en el del 84
func _tapa_mango(estilo: Dictionary) -> Texture2D:
	const T := 16
	var color: Color = estilo.get("tapa", Color(0.95, 0.45, 0.08))
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	for y in T:
		for x in T:
			var c := color
			if estilo.get("cobalto", false):
				var p := Vector2(x - 7.5, y - 7.5)
				var ang := fposmod(rad_to_deg(p.angle()) + 90.0, 120.0)
				if p.length() < 1.6 or (p.length() > 2.6 and p.length() < 6.5 and ang < 60.0):
					c = Color(0.05, 0.05, 0.05)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Mango de hule: negro con el grabado antiderrapante en rombitos
func _hule_mango() -> Texture2D:
	const W := 32
	const H := 16
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	for y in H:
		for x in W:
			var c := Color(0.1, 0.1, 0.11)
			if (x + y) % 4 == 0 or (x - y + 64) % 4 == 0:
				c = Color(0.05, 0.05, 0.055)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Cinta de aislar: negra con un brillo de plastico a lo largo y la orilla mas clara
func _cinta_aislar() -> Texture2D:
	const T := 16
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 183
	for y in T:
		for x in T:
			var c := Color(0.06, 0.06, 0.07).lightened(rnd.randf_range(0.0, 0.03))
			# La orilla de cada vuelta brilla y la de abajo queda en sombra: se ve encimada
			if x <= 1:
				c = Color(0.24, 0.24, 0.27)
			elif x >= T - 2:
				c = Color(0.02, 0.02, 0.02)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Soldadura: fierro oscuro con el cordon en escamitas mas claras y quemado azul
func _soldadura() -> Texture2D:
	const T := 16
	var img := Image.create(T, T, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 182
	for y in T:
		for x in T:
			var c := Color(0.3, 0.3, 0.32).lightened(rnd.randf_range(-0.04, 0.04))
			if x % 4 == 0:
				c = Color(0.5, 0.48, 0.45)
			elif rnd.randf() > 0.85:
				c = Color(0.25, 0.3, 0.45)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Mango: madera cafe con vetas a lo largo, mas gastada en el oxidado
func _madera_mango(estilo: Dictionary) -> Texture2D:
	const W := 32
	const H := 16
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = int(estilo["semilla"]) + 1
	var base: Color = estilo.get("madera", Color(0.4, 0.24, 0.12))
	for y in H:
		var veta := rnd.randf_range(-0.06, 0.06)
		for x in W:
			var c := base.lightened(veta + rnd.randf_range(-0.03, 0.03))
			if (x + y * 3) % 11 == 0:
				c = c.darkened(0.25)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Oxida lo que es metal (los pixeles grises, sin color) de una textura: manchas cafe naranja
# que cubren `cuanto` del metal; la madera solo se oscurece tantito
func _oxidar(ruta: String, cuanto: float, semilla: int) -> Texture2D:
	var img := (load(ruta) as Texture2D).get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGB8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = semilla
	var ruido := FastNoiseLite.new()
	ruido.seed = semilla
	ruido.frequency = 0.08
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.s < 0.18:
				var n := (ruido.get_noise_2d(x, y) + 1.0) * 0.5
				if n < cuanto:
					var oxido := Color(0.45, 0.22, 0.09).lerp(Color(0.62, 0.33, 0.12), rnd.randf())
					c = oxido.darkened(rnd.randf_range(0.0, 0.25)) if n < cuanto * 0.8 else c.lerp(oxido, 0.5)
				else:
					c = c.darkened(0.05)
			else:
				c = c.darkened(0.15)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Comun ---

func _malla(malla: Mesh, textura: Texture2D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = "Malla"
	m.mesh = malla
	m.set_surface_override_material(0, _material(textura))
	return m


func _material(textura: Texture2D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("albedo_texture", textura)
	material.set_shader_parameter("base_color", Color.WHITE)
	material.set_shader_parameter("affine_enabled", false)
	# El wobble pega los vertices a una rejilla de 1/40 m en la vista: mas grande que una varilla de 1 cm
	material.set_shader_parameter("wobble_enabled", false)
	return material


func _guardar(nodo: Node3D, id: String, grupo := "tiliches") -> void:
	var ruta := SALIDA % [grupo, id, id]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ruta.get_base_dir()))
	var raiz := Node3D.new()
	raiz.name = id.capitalize().replace(" ", "")
	raiz.add_child(nodo)
	nodo.owner = raiz
	for hijo in nodo.find_children("*", "", true, false):
		hijo.owner = raiz
	var escena := PackedScene.new()
	escena.pack(raiz)
	ResourceSaver.save(escena, ruta, ResourceSaver.FLAG_COMPRESS)
	raiz.free()
