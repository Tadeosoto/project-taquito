class_name CallesRuta
extends RefCounted

# Rutas de vehiculos por las calles del mapa. Lo usan la camioneta que se va de la defensa del
# tinaco (DecoracionDefensa) y, despues, las misiones de reparto y escolta de camioneta
# (docs/plan-noche.md S11, M2). Las calles se leen del minimapa (make_minimapa.py las pinta a 1 m
# por pixel con los colores de CALLE_COLORES), asi que sirve en cualquier colonia que tenga uno.
#
#   CallesRuta.entre(a, b)            ruta por las calles de a a b (A* sobre una rejilla), ya enderezada
#   CallesRuta.seguir(desde, rumbo, m) ruta por la calle que ya lleva `desde`, `m` metros hacia `rumbo`
#   CallesRuta.suavizar(ruta)         tramos rectos y esquinas redondeadas, como maneja un carro
#   CallesRuta.es_calle(punto)        si en ese punto del mundo hay calle
#
# Las rutas son PackedVector3Array en coordenadas globales (la altura no se toca: ponla con un
# rayo al piso). ConductorCarro las recorre.

const MINIMAPA := "res://textures/map/minimapa.png"
const MINIMAPA_DATOS := "res://resources/map/minimapa.json"
const CALLE_COLORES := [Color8(150, 148, 140), Color8(196, 192, 180), Color8(226, 222, 206), Color8(240, 214, 140)]
const COLOR_TOLERANCIA := 0.03

# seguir(): una calle que ya se lleva
const PASO := 2.0                      # m entre puntos
const GIROS := [0.0, 8.0, -8.0, 16.0, -16.0, 25.0, -25.0, 35.0, -35.0, 45.0, -45.0]   # grados que prueba en cada paso
const ANCHO_MAX := 16.0                # m que mide a los lados para centrarse

# entre(): A* sobre una rejilla de CELDA m
const CELDA := 2.0
const MAX_NODOS := 12000               # lo mas que expande antes de rendirse
const BUSCA_CALLE := 30.0              # m a la redonda para encontrar la calle mas cercana a un punto
const ORILLA := 3.0                    # m: una celda con menos calle que esto a algun lado cuesta mas (anda por en medio)
const ORILLA_COSTO := 1.5

# suavizar(): tramos rectos y esquinas redondeadas
const TOLERANCIA := 2.5                # m que puede apartarse de los puntos de la calle al enderezar
const CURVA_RADIO := 7.0               # m de las esquinas
const CURVA_PUNTOS := 10               # puntos por esquina
const TRAMO_MIN := 8.0                 # m: entre esquinas hay al menos esto, para que quepa la curva
const MIN_GIRO := 4.0                  # grados: menos que eso no es esquina

static var _calles: Image
static var _origen := Vector2.ZERO
static var _m_por_pixel := 1.0
static var _celdas := {}               # celda -> 0 sin calle, 1 calle, 2 calle pegada a la orilla (A* mira cada una varias veces)


static func es_calle(punto: Vector3) -> bool:
	if _calles == null and not _cargar():
		return false
	var px := int((punto.x - _origen.x) / _m_por_pixel)
	var pz := int((punto.z - _origen.y) / _m_por_pixel)
	if px < 0 or pz < 0 or px >= _calles.get_width() or pz >= _calles.get_height():
		return false
	var color := _calles.get_pixel(px, pz)
	for calle: Color in CALLE_COLORES:
		if absf(color.r - calle.r) + absf(color.g - calle.g) + absf(color.b - calle.b) < COLOR_TOLERANCIA * 3.0:
			return true
	return false


static func _cargar() -> bool:
	var datos = JSON.parse_string(FileAccess.get_file_as_string(MINIMAPA_DATOS))
	if not datos is Dictionary:
		return false
	_calles = (load(MINIMAPA) as Texture2D).get_image()
	if _calles.is_compressed():
		_calles.decompress()
	_origen = Vector2(datos["x0"], datos["z0"])
	_m_por_pixel = float(datos["metros_por_pixel"])
	return true


# El largo de una ruta (m)
static func largo(ruta: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, ruta.size()):
		total += ruta[i].distance_to(ruta[i - 1])
	return total


# `punto` corrido a la mitad de la calle, midiendo a los lados de `rumbo`
static func al_centro(punto: Vector3, rumbo: Vector3) -> Vector3:
	var lado := Vector3(-rumbo.z, 0.0, rumbo.x)
	var a := 0.0
	while a < ANCHO_MAX / 2.0 and es_calle(punto + lado * (a + 0.5)):
		a += 0.5
	var b := 0.0
	while b < ANCHO_MAX / 2.0 and es_calle(punto - lado * (b + 0.5)):
		b += 0.5
	return punto + lado * (a - b) / 2.0


# Puntos por el centro de la calle desde `desde` hacia `rumbo`, hasta `metros` o hasta que se
# acaba la calle; en los cruces sigue lo mas derecho que pueda. Sin suavizar.
static func seguir(desde: Vector3, rumbo: Vector3, metros: float) -> PackedVector3Array:
	var puntos := PackedVector3Array([desde])
	var aqui := desde
	var recorrido := 0.0
	while recorrido < metros:
		var siguiente := Vector3.INF
		for grados: float in GIROS:
			var prueba := aqui + rumbo.rotated(Vector3.UP, deg_to_rad(grados)) * PASO
			if es_calle(prueba):
				siguiente = al_centro(prueba, rumbo)
				break
		if siguiente == Vector3.INF:
			break
		rumbo = (siguiente - aqui).normalized()
		recorrido += aqui.distance_to(siguiente)
		aqui = siguiente
		puntos.append(aqui)
	return puntos


# La celda de calle mas cercana a `punto` (en el mundo), o Vector3.INF si no hay a BUSCA_CALLE m
static func calle_cercana(punto: Vector3) -> Vector3:
	var mejor := Vector3.INF
	var mejor_d := INF
	var radio := int(BUSCA_CALLE / CELDA)
	var centro := _celda(punto)
	for dx in range(-radio, radio + 1):
		for dz in range(-radio, radio + 1):
			var celda := centro + Vector2i(dx, dz)
			var donde := _punto(celda, punto.y)
			var d := donde.distance_to(punto)
			if d < mejor_d and d <= BUSCA_CALLE and es_calle(donde):
				mejor_d = d
				mejor = donde
	return mejor


# Ruta por las calles de `a` a `b` (las dos se llevan a la calle mas cercana), ya enderezada.
# Vacia si alguna no tiene calle cerca o no hay camino. A* sobre una rejilla de CELDA m: de 8 lados,
# sin cortar esquinas, y las celdas pegadas a la orilla de la calle cuestan un poco mas.
static func entre(a: Vector3, b: Vector3) -> PackedVector3Array:
	var inicio := calle_cercana(a)
	var final := calle_cercana(b)
	if inicio == Vector3.INF or final == Vector3.INF:
		return PackedVector3Array()
	var de := _celda(inicio)
	var a_ := _celda(final)
	var vino := {de: de}
	var costo := {de: 0.0}
	var monton: Array = [[_h(de, a_), de]]   # montículo binario de [f, celda]
	var nodos := 0
	var llego := false
	while not monton.is_empty() and nodos < MAX_NODOS:
		var actual: Vector2i = _sacar(monton)[1]
		if actual == a_:
			llego = true
			break
		nodos += 1
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var sig := actual + Vector2i(dx, dz)
				var tipo := _tipo(sig)
				if tipo == 0:
					continue
				# Sin cortar esquinas
				if dx != 0 and dz != 0 and (_tipo(actual + Vector2i(dx, 0)) == 0 or _tipo(actual + Vector2i(0, dz)) == 0):
					continue
				var paso := (1.4142 if dx != 0 and dz != 0 else 1.0) + (ORILLA_COSTO if tipo == 2 else 0.0)
				var nuevo: float = costo[actual] + paso
				if not costo.has(sig) or nuevo < costo[sig]:
					costo[sig] = nuevo
					vino[sig] = actual
					_meter(monton, [nuevo + _h(sig, a_), sig])
	if not llego:
		return PackedVector3Array()
	var celdas: Array[Vector2i] = [a_]
	while celdas[celdas.size() - 1] != de:
		celdas.append(vino[celdas[celdas.size() - 1]])
	celdas.reverse()
	var ruta := PackedVector3Array()
	for celda in celdas:
		ruta.append(_punto(celda, inicio.y))
	ruta[0] = inicio
	ruta[ruta.size() - 1] = final
	return suavizar(ruta)


static func _celda(punto: Vector3) -> Vector2i:
	return Vector2i(floori(punto.x / CELDA), floori(punto.z / CELDA))


static func _punto(celda: Vector2i, altura: float) -> Vector3:
	return Vector3((celda.x + 0.5) * CELDA, altura, (celda.y + 0.5) * CELDA)


static func _h(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a).distance_to(Vector2(b))


# 0 si la celda no es calle, 1 si lo es, 2 si lo es pero esta pegada a la orilla (cuesta mas: asi
# la ruta anda por en medio)
static func _tipo(celda: Vector2i) -> int:
	if _celdas.has(celda):
		return _celdas[celda]
	var centro := _punto(celda, 0.0)
	var tipo := 0
	if es_calle(centro):
		tipo = 1
		for lado in [Vector3(ORILLA, 0, 0), Vector3(-ORILLA, 0, 0), Vector3(0, 0, ORILLA), Vector3(0, 0, -ORILLA)]:
			if not es_calle(centro + lado):
				tipo = 2
				break
	_celdas[celda] = tipo
	return tipo


# Monticulo binario (el menor f arriba) de [f, celda]
static func _meter(monton: Array, item: Array) -> void:
	monton.append(item)
	var i := monton.size() - 1
	while i > 0:
		var padre := (i - 1) / 2
		if monton[padre][0] <= monton[i][0]:
			break
		var t = monton[padre]
		monton[padre] = monton[i]
		monton[i] = t
		i = padre


static func _sacar(monton: Array) -> Array:
	var primero: Array = monton[0]
	var ultimo: Array = monton.pop_back()
	if not monton.is_empty():
		monton[0] = ultimo
		var i := 0
		while true:
			var h1 := 2 * i + 1
			var h2 := h1 + 1
			var menor := i
			if h1 < monton.size() and monton[h1][0] < monton[menor][0]:
				menor = h1
			if h2 < monton.size() and monton[h2][0] < monton[menor][0]:
				menor = h2
			if menor == i:
				break
			var t = monton[menor]
			monton[menor] = monton[i]
			monton[i] = t
			i = menor
	return primero


# La ruta como la manejaria una persona: se quitan los puntos que solo siguen los pequenos
# zigzags del centro de la calle (Douglas-Peucker), las esquinas muy juntas se vuelven una y las
# que quedan se redondean.
static func suavizar(ruta: PackedVector3Array) -> PackedVector3Array:
	if ruta.size() < 3:
		return ruta
	var simple := PackedVector3Array([ruta[0]])
	simple.append_array(_simplificar(ruta, 0, ruta.size() - 1))
	var recta := PackedVector3Array([simple[0]])
	for i in range(1, simple.size() - 1):
		if simple[i].distance_to(recta[recta.size() - 1]) >= TRAMO_MIN and simple[i].distance_to(simple[simple.size() - 1]) >= TRAMO_MIN:
			recta.append(simple[i])
	recta.append(simple[simple.size() - 1])
	if recta.size() < 3:
		return recta
	var suave := PackedVector3Array([recta[0]])
	for i in range(1, recta.size() - 1):
		var antes := recta[i] - recta[i - 1]
		var despues := recta[i + 1] - recta[i]
		antes.y = 0.0
		despues.y = 0.0
		var d1 := antes.normalized()
		var d2 := despues.normalized()
		var giro := acos(clampf(d1.dot(d2), -1.0, 1.0))
		if rad_to_deg(giro) < MIN_GIRO:
			suave.append(recta[i])
			continue
		# Tangentes de la curva: lo que pide el radio, sin pasar de la mitad de cada tramo
		var tangente := minf(CURVA_RADIO * tan(giro / 2.0), minf(antes.length(), despues.length()) / 2.0)
		var entra := recta[i] - d1 * tangente
		var sale := recta[i] + d2 * tangente
		for k in range(CURVA_PUNTOS + 1):
			var t := float(k) / CURVA_PUNTOS
			suave.append(entra.lerp(recta[i], t).lerp(recta[i].lerp(sale, t), t))
	suave.append(recta[recta.size() - 1])
	return suave


# Douglas-Peucker: los puntos de ruta[desde+1 .. hasta] que hay que conservar
static func _simplificar(ruta: PackedVector3Array, desde: int, hasta: int) -> PackedVector3Array:
	var mas_lejos := 0.0
	var donde := -1
	var a := Vector2(ruta[desde].x, ruta[desde].z)
	var b := Vector2(ruta[hasta].x, ruta[hasta].z)
	for i in range(desde + 1, hasta):
		var p := Vector2(ruta[i].x, ruta[i].z)
		var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
		if d > mas_lejos:
			mas_lejos = d
			donde = i
	var conservados := PackedVector3Array()
	if donde >= 0 and mas_lejos > TOLERANCIA:
		conservados.append_array(_simplificar(ruta, desde, donde))
		conservados.append_array(_simplificar(ruta, donde, hasta))
	else:
		conservados.append(ruta[hasta])
	return conservados
