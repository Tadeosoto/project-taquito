class_name SolverLombrices
extends RefCounted
# Toda la fisica de las lombrices (EnjambreLombrices.gd, MadreCarcamo.gd), sin nodos: el truco de
# los cuerpos de Hitman (Jakobsen). Cada lombriz son puntos sueltos unidos por hilos: Verlet mueve
# cada punto con lo que traia, y luego ITERACIONES vueltas los acomodan: los hilos a su largo (y
# las `uniones` de las lombrices fundidas en latigo), los puntos que se enciman se separan
# (rejilla con hash de enteros) y los que quedan dentro de una pared salen por el gradiente del
# campo de distancia (CampoDistancia.gd).
#
# Lo que piensa cada lombriz lo decide el enjambre en el hilo principal y llega aqui por punto:
# `modo` (bits, abajo) y `meta` (a donde va ese punto). Todo vive en arreglos planos, para poder
# cambiar esta clase por una de C++ (GDExtension) con el mismo `step` sin tocar nada mas.

# Bits de `modo`
const CABEZA := 1        # jala mas que el cuerpo
const BAJO_TIERRA := 2   # no ve el campo ni pesa: va derecho a su meta por debajo del piso
const ANCLA := 4         # se queda clavada en su meta (pegada al jugador o a un zombi)
const LIBRE := 8         # no se guia: va volando (salto, caida de la torre)
const AIRE := 16         # se guia aunque no toque nada y casi no pesa (erguida, torre)
const RAPIDO := 32       # RAPIDO_X mas rapido (arranques de las crias, latigo, la Madre al morder)
const RAPIDO_X := 1.75
const LEJOS := 64        # lejos del jugador: se mueve un paso de cada LEJOS_CADA, con ese dt
const DORMIDA := 128     # lejos y no le toca este paso: no se mueve
const LEJOS_CADA := 3

const ITERACIONES := 3
const LARGO := 0.14            # m entre dos puntos unidos (las chicas)
const RADIO := 0.09            # m de grueso de cada punto (las chicas)
const GRAVEDAD := 14.0         # m/s2: un poco mas que la real, que se vean pesadas
const AMORTIGUA := 0.985       # lo que se queda de la velocidad cada paso
const VELOCIDAD := 4.0         # m/s a la que se arrastran (los zombis, 3-5; tu trotas a 5)
const TOPE_PASO := 0.3         # m que puede avanzar un punto en un paso (que no atraviese nada)
const VELOCIDAD_CUERPO := 0.9  # x la velocidad para el cuerpo: la cabeza jala un poco mas
const GUIA_CABEZA := 0.25      # que tanto corrige su velocidad cada paso la cabeza (0-1)
const GUIA_CUERPO := 0.12
const GUIA_AIRE := 0.15
const AIRE_PESA := 0.15        # de la gravedad, en modo AIRE
const VEL_TIERRA := 1.6        # x la velocidad, enterradas
const PEGA := 0.04             # m de holgura para contar que toca una superficie
const AGARRE := 0.92           # en una pared se le quita esto de la gravedad: se pega y trepa
const TREPA := 1.4             # cuanto pesa "hacia arriba" al trepar
const ADHIERE := 6.0           # m/s2 hacia la superficie que toca
const ONDA := 0.35             # vaiven de lado a lado, como culebra (0.7 las tiraba de la pasarela)
const ONDA_VEL := 9.0          # rad/s
const ONDA_PASO := 0.8         # rad de desfase entre un punto y el siguiente
const VOLANDO := 2.5           # x la velocidad de arrastre: mas rapido que esto va volando
const VOLANDO_GUIA := 0.2      # y se guia solo esto, para que el balazo las avente de veras
const MARGEN := 0.06           # m de mas al juntar parejas
const TABLA := 16384           # casillas del hash (potencia de 2)
const CERCA := 0.35            # m: de mas lejos del campo no se revisa en las vueltas

# Por instancia: la Madre usa el mismo solver con otro tamano
var radio := RADIO
var largo := LARGO
var velocidad := VELOCIDAD
var gravedad := GRAVEDAD
var separar := true            # repulsion entre puntos (la Madre sola no la necesita)
var puntos_por_lombriz := 12
# El jugador como capsula: los puntos no se le meten, se le amontonan encima
var obstaculo := Vector3.ZERO
var obstaculo_radio := 0.45
var obstaculo_medio_alto := 0.55
var obstaculo_activo := false

var _t := 0.0
# Microsegundos de cada parte del ultimo paso (integrar, parejas, hilos, separar, campo, limites)
var perfil := PackedInt64Array([0, 0, 0, 0, 0, 0])
var _celda := 0.0
# Hash: cabeza de lista por casilla y el siguiente de cada punto (sin diccionarios)
var _cabeza := PackedInt32Array()
var _siguiente := PackedInt32Array()
var _bases := PackedInt32Array()
var _vecinas := PackedInt32Array()   # las 13 casillas "de adelante" mas la propia
var _parejas := PackedInt32Array()
# Lo que vio cada punto del campo al leerlo, para los pasos y vueltas en que no lo lee
var _d := PackedFloat32Array()
var _n := PackedVector3Array()
var _p0 := PackedVector3Array()


func _init() -> void:
	_cabeza.resize(TABLA)
	# Clave lineal: x + y*73 + z*5867. Las vecinas son sumas fijas y el & las envuelve; dos
	# celdas lejanas que caen en la misma casilla solo cuestan una distancia de mas
	for dz in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				# Solo la mitad: cada pareja de celdas se ve una vez
				if dz > 0 or (dz == 0 and dy > 0) or (dz == 0 and dy == 0 and dx >= 0):
					_vecinas.append(dx + dy * 73 + dz * 5867)


# Enjambre nuevo: olvida lo que vio cada punto
func reiniciar() -> void:
	_d.resize(0)
	_n.resize(0)
	_p0.resize(0)


func step(pos: PackedVector3Array, old_pos: PackedVector3Array, links: PackedByteArray,
		vivos: PackedByteArray, modo: PackedByteArray, meta: PackedVector3Array,
		uniones: PackedInt32Array, dt: float, campo: CampoDistancia) -> void:
	var n := pos.size()
	if _d.size() != n:
		_d.resize(n)
		_n.resize(n)
		_p0.resize(n)
		_siguiente.resize(n)
		_bases.resize(n)
	_celda = 2.0 * radio + MARGEN
	_t += dt
	var t0 := Time.get_ticks_usec()
	_integrar(pos, old_pos, vivos, modo, meta, dt, campo)
	var t1 := Time.get_ticks_usec()
	if separar:
		_juntar_parejas(pos, vivos)
	var t2 := Time.get_ticks_usec()
	var th := 0
	var ts := 0
	var tc := 0
	for vuelta in ITERACIONES:
		var a := Time.get_ticks_usec()
		_hilos(pos, links, vivos, uniones, modo)
		var b := Time.get_ticks_usec()
		# Separarlas una vez por paso basta: las otras vueltas solo arreglan hilos y paredes
		if separar and vuelta == 0:
			_separar(pos, vivos)
		var c := Time.get_ticks_usec()
		_campo_aprox(pos, vivos, modo)
		th += b - a
		ts += c - b
		tc += Time.get_ticks_usec() - c
	var t3 := Time.get_ticks_usec()
	_limites(pos, old_pos, vivos, modo, meta, campo)
	perfil[0] = t1 - t0
	perfil[1] = t2 - t1
	perfil[2] = th
	perfil[3] = ts
	perfil[4] = tc
	perfil[5] = Time.get_ticks_usec() - t3


# Verlet: lo que traia, mas gravedad, mas las ganas de llegar a su meta. Lo que es "por paso"
# (amortiguar, guiarse) se ajusta al dt, para que a 30 o a 60 pasos por segundo se vea igual.
# El campo se lee aqui mismo, sin llamar a CampoDistancia.muestra (en GDScript la llamada y los
# miembros por punto costaban mas que la cuenta)
func _integrar(pos: PackedVector3Array, old_pos: PackedVector3Array, vivos: PackedByteArray,
		modo: PackedByteArray, meta: PackedVector3Array, dt_paso: float, campo: CampoDistancia) -> void:
	var dd := _d
	var nn := _n
	var pp := _p0
	var datos := campo.datos
	var celda := campo.celda
	var inv := 1.0 / celda
	var ox := campo.origen.x
	var oy := campo.origen.y
	var oz := campo.origen.z
	var cnx := campo.nx
	var cny := campo.ny
	var cnz := campo.nz
	var capa := cnx * cny
	var lejos_campo := 3.0 * celda
	var r := radio
	var ppl := puntos_por_lombriz
	# Dos juegos de numeros: el paso normal y el de las lejanas (LEJOS_CADA veces mas largo)
	var juegos := []
	for k in 2:
		var dt := dt_paso * (1.0 if k == 0 else float(LEJOS_CADA))
		var pasos := dt * 60.0
		juegos.append([dt * dt, velocidad * dt, pow(AMORTIGUA, pasos),
			1.0 - pow(1.0 - GUIA_CABEZA, pasos), 1.0 - pow(1.0 - GUIA_CUERPO, pasos),
			1.0 - pow(1.0 - GUIA_AIRE, pasos), 1.0 - pow(1.0 - 0.3, pasos)])
	for i in pos.size():
		if vivos[i] == 0:
			continue
		var m := modo[i]
		if m & DORMIDA:
			continue
		var j: Array = juegos[1 if m & LEJOS else 0]
		var dt2: float = j[0]
		var paso: float = j[1]
		var p := pos[i]
		var v := (p - old_pos[i]) * float(j[2])
		var objetivo := meta[i]
		if m & ANCLA:
			old_pos[i] = objetivo
			pos[i] = objetivo
			continue
		if m & BAJO_TIERRA:
			# Derecho a su meta, sin campo ni gravedad
			var hacia := objetivo - p
			var dist := hacia.length()
			var deseo := hacia / dist * minf(paso * VEL_TIERRA * (RAPIDO_X if m & RAPIDO else 1.0), dist) if dist > 0.001 else Vector3.ZERO
			v = v.lerp(deseo, float(j[6]))
			old_pos[i] = p
			pos[i] = p + v
			nn[i] = Vector3.ZERO
			dd[i] = 1.0
			continue
		# El campo en p: trilineal entre centros de celda, con su gradiente
		var d := 10.0
		var normal := Vector3.ZERO
		var fx := (p.x - ox) * inv - 0.5
		var fy := (p.y - oy) * inv - 0.5
		var fz := (p.z - oz) * inv - 0.5
		if fx >= 0.0 and fy >= 0.0 and fz >= 0.0 and fx <= cnx - 1 and fy <= cny - 1 and fz <= cnz - 1:
			var x0 := mini(int(fx), cnx - 2)
			var y0 := mini(int(fy), cny - 2)
			var z0 := mini(int(fz), cnz - 2)
			var c := x0 + cnx * (y0 + cny * z0)
			var c000 := datos[c]
			if c000 > lejos_campo:
				d = c000 - celda * 1.75
			else:
				var tx := fx - x0
				var ty := fy - y0
				var tz := fz - z0
				var c100 := datos[c + 1]
				var c010 := datos[c + cnx]
				var c110 := datos[c + cnx + 1]
				var c001 := datos[c + capa]
				var c101 := datos[c + capa + 1]
				var c011 := datos[c + capa + cnx]
				var c111 := datos[c + capa + cnx + 1]
				var c00 := c000 + (c100 - c000) * tx
				var c10 := c010 + (c110 - c010) * tx
				var c01 := c001 + (c101 - c001) * tx
				var c11 := c011 + (c111 - c011) * tx
				var c0 := c00 + (c10 - c00) * ty
				var c1 := c01 + (c11 - c01) * ty
				d = c0 + (c1 - c0) * tz
				var g := Vector3(
					((c100 - c000) * (1.0 - ty) + (c110 - c010) * ty) * (1.0 - tz) + ((c101 - c001) * (1.0 - ty) + (c111 - c011) * ty) * tz,
					(c10 - c00) * (1.0 - tz) + (c11 - c01) * tz,
					c1 - c0)
				if g.length_squared() > 0.000001:
					normal = g.normalized()
		dd[i] = d
		nn[i] = normal
		pp[i] = p
		# Lo que quedo adentro sale aqui, antes de moverse
		if d < r and normal != Vector3.ZERO:
			p += normal * (r - d)
			d = r
		var peso := gravedad
		var rapido := RAPIDO_X if m & RAPIDO else 1.0
		if m & AIRE:
			var hacia := objetivo - p
			var deseo := hacia.normalized() * minf(paso * rapido, hacia.length()) if hacia.length_squared() > 0.0001 else Vector3.ZERO
			v = v.lerp(deseo, float(j[5]))
			peso *= AIRE_PESA
		elif not (m & LIBRE) and d < r + PEGA and normal != Vector3.ZERO:
			var k := i % ppl
			var hacia := objetivo - p
			var plano := hacia - normal * hacia.dot(normal)
			var dir := plano.normalized() if plano.length_squared() > 0.0025 else Vector3.ZERO
			if normal.y < 0.6:
				# Pared o techo: se agarra, y trepa si su meta esta del otro lado o arriba
				peso *= 1.0 - AGARRE
				var arriba := Vector3.UP - normal * normal.y
				if hacia.normalized().dot(normal) < -0.3 or hacia.y > 0.5:
					dir = (dir + arriba * TREPA).normalized()
			var lado := normal.cross(dir)
			if lado.length_squared() > 0.0001:
				dir += lado.normalized() * sin(_t * ONDA_VEL * rapido - k * ONDA_PASO + (i / ppl) * 2.3) * ONDA
			var cabeza := (m & CABEZA) != 0
			var deseo := dir * paso * rapido * (1.0 if cabeza else VELOCIDAD_CUERPO)
			var vn := normal * v.dot(normal)
			var vt := v - vn
			var guia: float = j[3] if cabeza else j[4]
			if vt.length_squared() > paso * paso * rapido * rapido * VOLANDO * VOLANDO:
				guia *= VOLANDO_GUIA
			v = vt.lerp(deseo, guia) + vn - normal * ADHIERE * dt2
		v.y -= peso * dt2
		if v.length_squared() > TOPE_PASO * TOPE_PASO:
			v = v.normalized() * TOPE_PASO
		old_pos[i] = p
		pos[i] = p + v


# Hash de la rejilla y las parejas de puntos que pueden tocarse, una vez por paso.
# (Los arreglos en variables locales: leerlos asi es bastante mas rapido que como miembros)
func _juntar_parejas(pos: PackedVector3Array, vivos: PackedByteArray) -> void:
	var cabeza := _cabeza
	var siguiente := _siguiente
	var bases := _bases
	var vecinas := _vecinas
	var parejas := _parejas
	cabeza.fill(-1)
	parejas.clear()
	var mascara := TABLA - 1
	var inv := 1.0 / _celda
	var n := pos.size()
	for i in n:
		if vivos[i] == 0:
			continue
		var p := pos[i]
		var base := floori(p.x * inv) + floori(p.y * inv) * 73 + floori(p.z * inv) * 5867
		bases[i] = base
		var h := base & mascara
		siguiente[i] = cabeza[h]
		cabeza[h] = i
	var lejos := (2.0 * radio + MARGEN) * (2.0 * radio + MARGEN)
	var ppl := puntos_por_lombriz
	for i in n:
		if vivos[i] == 0:
			continue
		var p := pos[i]
		var base := bases[i]
		for off in vecinas:
			# En su propia casilla solo los que siguen en la lista: cada pareja una vez
			var j := siguiente[i] if off == 0 else cabeza[(base + off) & mascara]
			while j != -1:
				if j != i and p.distance_squared_to(pos[j]) < lejos \
						and not (absi(j - i) == 1 and i / ppl == j / ppl):
					parejas.append(i)
					parejas.append(j)
				j = siguiente[j]


func _hilos(pos: PackedVector3Array, links: PackedByteArray, vivos: PackedByteArray, uniones: PackedInt32Array, modo: PackedByteArray) -> void:
	for i in pos.size() - 1:
		if links[i] == 0 or vivos[i] == 0 or vivos[i + 1] == 0 or modo[i] & DORMIDA:
			continue
		_jalar(pos, i, i + 1)
	var k := 0
	while k + 1 < uniones.size():
		var a := uniones[k]
		var b := uniones[k + 1]
		k += 2
		if vivos[a] == 1 and vivos[b] == 1:
			_jalar(pos, a, b)


func _jalar(pos: PackedVector3Array, i: int, j: int) -> void:
	var a := pos[i]
	var b := pos[j]
	var delta := b - a
	var l := delta.length()
	if l < 0.0001:
		return
	var corrige := delta * ((l - largo) / l * 0.5)
	pos[i] = a + corrige
	pos[j] = b - corrige


func _separar(pos: PackedVector3Array, vivos: PackedByteArray) -> void:
	var minimo := 2.0 * radio
	var minimo2 := minimo * minimo
	var parejas := _parejas
	var k := 0
	while k < parejas.size():
		var i := parejas[k]
		var j := parejas[k + 1]
		k += 2
		if vivos[i] == 0 or vivos[j] == 0:
			continue
		var delta := pos[j] - pos[i]
		var d2 := delta.length_squared()
		if d2 >= minimo2 or d2 < 0.000001:
			continue
		var d := sqrt(d2)
		var corrige := delta * ((minimo - d) / d * 0.5)
		pos[i] -= corrige
		pos[j] += corrige


# En las vueltas el campo se aproxima por el plano que se vio (barato)
func _campo_aprox(pos: PackedVector3Array, vivos: PackedByteArray, modo: PackedByteArray) -> void:
	var dd := _d
	var nn := _n
	var pp := _p0
	for i in pos.size():
		if vivos[i] == 0 or dd[i] > CERCA or modo[i] & (BAJO_TIERRA | ANCLA | DORMIDA):
			continue
		var normal := nn[i]
		if normal == Vector3.ZERO:
			continue
		var p := pos[i]
		var d := dd[i] + normal.dot(p - pp[i])
		if d < radio:
			pos[i] = p + normal * (radio - d)


# Al final: el jugador, la caja del campo y lo anclado (el campo de veras se lee al empezar)
func _limites(pos: PackedVector3Array, old_pos: PackedVector3Array, vivos: PackedByteArray,
		modo: PackedByteArray, meta: PackedVector3Array, campo: CampoDistancia) -> void:
	var minimo := campo.origen + Vector3.ONE * radio
	var maximo := campo.origen + campo.tamano() - Vector3.ONE * radio
	var radio_jugador := obstaculo_radio + radio
	for i in pos.size():
		if vivos[i] == 0:
			continue
		var m := modo[i]
		if m & DORMIDA:
			continue
		if m & ANCLA:
			pos[i] = meta[i]
			old_pos[i] = meta[i]
			continue
		var p := pos[i]
		if obstaculo_activo and not (m & BAJO_TIERRA):
			var y := clampf(p.y, obstaculo.y - obstaculo_medio_alto, obstaculo.y + obstaculo_medio_alto)
			var delta := p - Vector3(obstaculo.x, y, obstaculo.z)
			var d2 := delta.length_squared()
			if d2 < radio_jugador * radio_jugador and d2 > 0.000001:
				p += delta * ((radio_jugador - sqrt(d2)) / sqrt(d2))
		# La caja del campo es el mundo: afuera no hay nada que la detenga
		var dentro := p.clamp(minimo, maximo)
		if dentro != p:
			old_pos[i] = old_pos[i] + (dentro - p)
			p = dentro
		pos[i] = p
