class_name CampoDistancia
extends RefCounted
# Campo de distancia con signo, horneado al empezar: una rejilla 3D donde cada celda sabe que
# tan cerca esta la superficie mas cercana (negativo = adentro de algo). Las lombrices leen un
# numero y, si es negativo o casi, salen por el gradiente (SolverLombrices).
#
# Hornear: primero que celdas estan ocupadas, con intersect_shape de una caja del tamano de la
# celda (capa 1, sin el jugador), probando antes bloques de BLOQUE³ celdas para saltarse el aire;
# luego la distancia a la celda ocupada mas cercana se reparte por vecinas (cada celda hereda la
# semilla de quien la llego) hasta LIMITE celdas, y lo mismo hacia adentro. Las superficies que
# caen justo en el borde de una celda (el piso, si el origen esta alineado) salen exactas; las
# demas, con hasta media celda de error.
# Se hace por pedazos con un presupuesto de microsegundos por cuadro (hornear_paso).

const BLOQUE := 4
const LIMITE := 6        # celdas: mas lejos que esto da lo mismo
const LEJOS := 10.0      # m que devuelve fuera de la caja
const ENCOGE := 0.96     # la caja de prueba, un poco menor que la celda: tocar no es ocupar

var origen := Vector3.ZERO
var celda := 0.25
var nx := 0
var ny := 0
var nz := 0
var datos := PackedFloat32Array()
var listo := false
var g := Vector3.ZERO    # gradiente de la ultima muestra (sin normalizar)

var _solido := PackedByteArray()
var _semilla := PackedInt32Array()
var _d2 := PackedInt32Array()
var _cola := PackedInt32Array()
var _cabeza_cola := 0
var _fase := 0
var _cursor := 0
var _hacia := 0          # 0: llenando el aire, 1: llenando lo solido
var _excluir: Array[RID] = []
var _prueba := PhysicsShapeQueryParameters3D.new()
var _caja := BoxShape3D.new()


func preparar(desde: Vector3, tam: Vector3, tam_celda: float, excluir: Array[RID]) -> void:
	origen = desde
	celda = tam_celda
	nx = maxi(ceili(tam.x / celda), 2)
	ny = maxi(ceili(tam.y / celda), 2)
	nz = maxi(ceili(tam.z / celda), 2)
	var total := nx * ny * nz
	datos.resize(total)
	_solido.resize(total)
	_solido.fill(0)
	_semilla.resize(total)
	_d2.resize(total)
	_excluir = excluir
	_prueba.shape = _caja
	_prueba.collision_mask = 1
	_prueba.exclude = excluir
	_fase = 0
	_cursor = 0
	listo = false


func tamano() -> Vector3:
	return Vector3(nx, ny, nz) * celda


# Sigue horneando hasta gastar `presupuesto_usec`; true cuando termino
func hornear_paso(espacio: PhysicsDirectSpaceState3D, presupuesto_usec: int) -> bool:
	var hasta := Time.get_ticks_usec() + presupuesto_usec
	while not listo and Time.get_ticks_usec() < hasta:
		match _fase:
			0:
				_ocupar(espacio, hasta)
			1, 3:
				_sembrar(hasta)
			2, 4:
				_repartir(hasta)
			5:
				_terminar(hasta)
	return listo


func _ocupar(espacio: PhysicsDirectSpaceState3D, hasta: int) -> void:
	var bx := ceili(float(nx) / BLOQUE)
	var by := ceili(float(ny) / BLOQUE)
	var bz := ceili(float(nz) / BLOQUE)
	while _cursor < bx * by * bz:
		if Time.get_ticks_usec() >= hasta:
			return
		var b := _cursor
		_cursor += 1
		var x0 := (b % bx) * BLOQUE
		var y0 := (b / bx % by) * BLOQUE
		var z0 := (b / (bx * by)) * BLOQUE
		var x1 := mini(x0 + BLOQUE, nx)
		var y1 := mini(y0 + BLOQUE, ny)
		var z1 := mini(z0 + BLOQUE, nz)
		var medida := Vector3(x1 - x0, y1 - y0, z1 - z0) * celda
		if not _hay_algo(espacio, origen + Vector3(x0, y0, z0) * celda + medida / 2.0, medida * ENCOGE):
			continue
		for z in range(z0, z1):
			for y in range(y0, y1):
				for x in range(x0, x1):
					if _hay_algo(espacio, origen + (Vector3(x, y, z) + Vector3.ONE * 0.5) * celda, Vector3.ONE * celda * ENCOGE):
						_solido[x + nx * (y + ny * z)] = 1
	_fase = 1
	_cursor = 0
	_hacia = 0


func _hay_algo(espacio: PhysicsDirectSpaceState3D, centro: Vector3, medida: Vector3) -> bool:
	_caja.size = medida
	_prueba.transform = Transform3D(Basis.IDENTITY, centro)
	return not espacio.intersect_shape(_prueba, 1).is_empty()


# Semillas: las celdas del otro lado que tocan el lado que se va a llenar
func _sembrar(hasta: int) -> void:
	var total := nx * ny * nz
	if _cursor == 0:
		_d2.fill(0x7fffffff)
		_semilla.fill(-1)
		_cola.clear()
		_cabeza_cola = 0
	var otro := 1 - _hacia
	while _cursor < total:
		if (_cursor & 1023) == 0 and Time.get_ticks_usec() >= hasta:
			return
		var c := _cursor
		_cursor += 1
		if _solido[c] != otro:
			continue
		var x := c % nx
		var y := c / nx % ny
		var z := c / (nx * ny)
		if (x > 0 and _solido[c - 1] == _hacia) or (x < nx - 1 and _solido[c + 1] == _hacia) \
				or (y > 0 and _solido[c - nx] == _hacia) or (y < ny - 1 and _solido[c + nx] == _hacia) \
				or (z > 0 and _solido[c - nx * ny] == _hacia) or (z < nz - 1 and _solido[c + nx * ny] == _hacia):
			_semilla[c] = c
			_d2[c] = 0
			_cola.append(c)
	_fase += 1


func _repartir(hasta: int) -> void:
	var limite2 := LIMITE * LIMITE
	var capa := nx * ny
	while _cabeza_cola < _cola.size():
		if (_cabeza_cola & 255) == 0 and Time.get_ticks_usec() >= hasta:
			return
		var c := _cola[_cabeza_cola]
		_cabeza_cola += 1
		var s := _semilla[c]
		var sx := s % nx
		var sy := s / nx % ny
		var sz := s / capa
		var x := c % nx
		var y := c / nx % ny
		var z := c / capa
		if x > 0:
			_llegar(c - 1, x - 1 - sx, y - sy, z - sz, s, limite2)
		if x < nx - 1:
			_llegar(c + 1, x + 1 - sx, y - sy, z - sz, s, limite2)
		if y > 0:
			_llegar(c - nx, x - sx, y - 1 - sy, z - sz, s, limite2)
		if y < ny - 1:
			_llegar(c + nx, x - sx, y + 1 - sy, z - sz, s, limite2)
		if z > 0:
			_llegar(c - capa, x - sx, y - sy, z - 1 - sz, s, limite2)
		if z < nz - 1:
			_llegar(c + capa, x - sx, y - sy, z + 1 - sz, s, limite2)
	# Guarda la distancia de este lado en datos y prepara el otro
	for c in nx * ny * nz:
		if _solido[c] == _hacia:
			if _d2[c] <= limite2 and _semilla[c] != -1:
				var d := sqrt(float(_d2[c])) * celda - celda * 0.5
				datos[c] = d if _hacia == 0 else -d
			else:
				datos[c] = LIMITE * celda * (1.0 if _hacia == 0 else -1.0)
	_fase += 1
	_cursor = 0
	_hacia = 1


func _llegar(n: int, dx: int, dy: int, dz: int, s: int, limite2: int) -> void:
	if _solido[n] != _hacia:
		return
	var d2 := dx * dx + dy * dy + dz * dz
	if d2 < _d2[n] and d2 <= limite2:
		_d2[n] = d2
		_semilla[n] = s
		_cola.append(n)


func _terminar(_hasta: int) -> void:
	_solido = PackedByteArray()
	_semilla = PackedInt32Array()
	_d2 = PackedInt32Array()
	_cola = PackedInt32Array()
	listo = true


# --- Guardar y cargar (EnjambreLombrices.guardar_campo) ---

const VERSION_ARCHIVO := 1

# Un numero que cambia si cambia cualquier colision de la capa 1 que toque la caja: su forma, su
# medida y donde esta. Asi un campo guardado solo se usa si el lugar es el mismo
static func firma(arbol: SceneTree, desde: Vector3, tam: Vector3) -> int:
	var caja := AABB(desde, tam)
	var partes := PackedStringArray()
	for forma: CollisionShape3D in arbol.root.find_children("*", "CollisionShape3D", true, false):
		var cuerpo := forma.get_parent() as CollisionObject3D
		if cuerpo == null or cuerpo is CharacterBody3D or cuerpo is Area3D or cuerpo.collision_layer & 1 == 0 or forma.disabled or forma.shape == null:
			continue
		var t := forma.global_transform
		if not caja.grow(1.0).has_point(t.origin) and not forma.shape is WorldBoundaryShape3D:
			continue
		var medida := ""
		if forma.shape is BoxShape3D:
			medida = str((forma.shape as BoxShape3D).size)
		elif forma.shape is CylinderShape3D:
			medida = "%s,%s" % [(forma.shape as CylinderShape3D).radius, (forma.shape as CylinderShape3D).height]
		elif forma.shape is CapsuleShape3D:
			medida = "%s,%s" % [(forma.shape as CapsuleShape3D).radius, (forma.shape as CapsuleShape3D).height]
		elif forma.shape is SphereShape3D:
			medida = str((forma.shape as SphereShape3D).radius)
		partes.append("%s|%s|%s" % [forma.shape.get_class(), medida, str(t).sha1_text().left(12)])
	partes.sort()
	return ("%s|%s|%d|" % [desde, tam, VERSION_ARCHIVO] + "/".join(partes)).hash()


func guardar(ruta: String, firma_: int) -> void:
	var archivo := FileAccess.open_compressed(ruta, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if archivo == null:
		return
	archivo.store_32(VERSION_ARCHIVO)
	archivo.store_64(firma_)
	archivo.store_var([origen, celda, nx, ny, nz])
	archivo.store_buffer(datos.to_byte_array())


# true si habia un campo guardado de este mismo lugar y ya quedo listo
func cargar(ruta: String, firma_: int) -> bool:
	if not FileAccess.file_exists(ruta):
		return false
	var archivo := FileAccess.open_compressed(ruta, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if archivo == null or archivo.get_32() != VERSION_ARCHIVO or archivo.get_64() != firma_:
		return false
	var cabeza: Array = archivo.get_var()
	if cabeza.size() != 5 or not (cabeza[0] as Vector3).is_equal_approx(origen) or not is_equal_approx(cabeza[1], celda) \
			or cabeza[2] != nx or cabeza[3] != ny or cabeza[4] != nz:
		return false
	var bytes := archivo.get_buffer(nx * ny * nz * 4)
	if bytes.size() != nx * ny * nz * 4:
		return false
	datos = bytes.to_float32_array()
	_terminar(0)
	return true


# Puntos del piso (a la altura `piso`) junto a una columna solida que sube de piso + `desde` a
# piso + `hasta` sin huecos: el pie de un muro o de un pilar, por donde se puede trepar. Uno de
# cada `cada` celdas. Regresa [puntos, hacia la pared]
func trepaderos(piso: float, desde := 0.5, hasta := 2.5, cada := 4) -> Array:
	var puntos := PackedVector3Array()
	var hacia := PackedVector3Array()
	if not listo:
		return [puntos, hacia]
	var y0 := int((piso + celda * 0.5 - origen.y) / celda)
	var ya := int((piso + desde - origen.y) / celda)
	var yb := mini(int((piso + hasta - origen.y) / celda), ny - 1)
	if y0 < 0 or y0 >= ny or ya > yb:
		return [puntos, hacia]
	var vecinos := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for z in range(1, nz - 1):
		for x in range(1, nx - 1):
			if (x + z) % cada != 0:
				continue
			if datos[x + nx * (y0 + ny * z)] <= 0.0:
				continue
			for v: Vector2i in vecinos:
				var solido := true
				for y in range(ya, yb + 1):
					if datos[(x + v.x) + nx * (y + ny * (z + v.y))] > 0.0:
						solido = false
						break
				if solido:
					puntos.append(origen + Vector3((x + 0.5) * celda, piso - origen.y, (z + 0.5) * celda))
					hacia.append(Vector3(v.x, 0.0, v.y))
					break
	return [puntos, hacia]


# Lo solido conectado a lo que pisas, en la capa justo debajo de `pies`: la pasarela entera con
# los pilares que la atraviesan. Regresa las celdas (x + nx * z) como llaves de un diccionario
func plataforma(pies: Vector3, maximo := 6000) -> Dictionary:
	var region := {}
	if not listo:
		return region
	var y := int((pies.y - celda * 0.5 - origen.y) / celda)
	var x0 := int((pies.x - origen.x) / celda)
	var z0 := int((pies.z - origen.z) / celda)
	if y < 0 or y >= ny or x0 < 0 or x0 >= nx or z0 < 0 or z0 >= nz:
		return region
	var capa := nx * ny
	if datos[x0 + nx * y + capa * z0] > 0.0:
		return region
	var cola: Array[Vector2i] = [Vector2i(x0, z0)]
	region[x0 + nx * z0] = true
	while not cola.is_empty() and region.size() < maximo:
		var c: Vector2i = cola.pop_back()
		for v: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var x := c.x + v.x
			var z := c.y + v.y
			if x < 0 or x >= nx or z < 0 or z >= nz or region.has(x + nx * z):
				continue
			if datos[x + nx * y + capa * z] <= 0.0:
				region[x + nx * z] = true
				cola.append(Vector2i(x, z))
	return region


func celda_xz(p: Vector3) -> int:
	return int((p.x - origen.x) / celda) + nx * int((p.z - origen.z) / celda)


# Distancia en `p` (trilineal entre centros de celda) y su gradiente en `g`.
# Lejos de todo regresa la de la celda mas cercana, sin gradiente: no hace falta mas.
func muestra(p: Vector3) -> float:
	g = Vector3.ZERO
	var fx := (p.x - origen.x) / celda - 0.5
	var fy := (p.y - origen.y) / celda - 0.5
	var fz := (p.z - origen.z) / celda - 0.5
	if fx < 0.0 or fy < 0.0 or fz < 0.0 or fx > nx - 1 or fy > ny - 1 or fz > nz - 1:
		return LEJOS
	var x0 := mini(int(fx), nx - 2)
	var y0 := mini(int(fy), ny - 2)
	var z0 := mini(int(fz), nz - 2)
	var c := x0 + nx * (y0 + ny * z0)
	var c000 := datos[c]
	# La esquina esta a menos de 0.87 celdas de p: lo de veras es al menos esto, y basta
	if c000 > 3.0 * celda:
		return c000 - celda * 1.75
	var tx := fx - x0
	var ty := fy - y0
	var tz := fz - z0
	var capa := nx * ny
	var c100 := datos[c + 1]
	var c010 := datos[c + nx]
	var c110 := datos[c + nx + 1]
	var c001 := datos[c + capa]
	var c101 := datos[c + capa + 1]
	var c011 := datos[c + capa + nx]
	var c111 := datos[c + capa + nx + 1]
	var c00 := c000 + (c100 - c000) * tx
	var c10 := c010 + (c110 - c010) * tx
	var c01 := c001 + (c101 - c001) * tx
	var c11 := c011 + (c111 - c011) * tx
	var c0 := c00 + (c10 - c00) * ty
	var c1 := c01 + (c11 - c01) * ty
	var gx := ((c100 - c000) * (1.0 - ty) + (c110 - c010) * ty) * (1.0 - tz) 		+ ((c101 - c001) * (1.0 - ty) + (c111 - c011) * ty) * tz
	var gy := (c10 - c00) * (1.0 - tz) + (c11 - c01) * tz
	g = Vector3(gx, gy, c1 - c0)
	return c0 + (c1 - c0) * tz
