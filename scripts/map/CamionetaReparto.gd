class_name CamionetaReparto
extends Acompanante

# La camioneta del gremio en una ruta de entregas de noche (PasoMision.Tipo.CAMIONETA,
# docs/plan-noche.md S11). Es un Acompanante: tiene vida, los zombis la atacan (lleva agua: los
# atrae desde lejos, mas parada) y si cae avisa con `cayo`. No te espera ni te sigue: va por las
# calles (CallesRuta) a tu trote (5 m/s: si te quedas atras la alcanzas corriendo con shift) y en
# cada casa se para DESCARGA_S segundos, el tinaco movil, mientras llegan las turbas
# (MisionesMundo las lanza). Al terminar la descarga emite `entrega(numero)` y sigue; en la ultima
# emite `termino`. La ruta se arma al crearla con el tiempo que queda de noche: se escogen las casas
# que quepan, para que acabe antes del amanecer.

signal entrega(numero: int)
signal termino

enum Estado { ANDA, DESCARGA, TERMINO }

const VELOCIDAD_RUTA := 5.0        # m/s: el trote del jugador (Player.speed)
const DESCARGA_S := 20.0
const ATRAE_ANDANDO := 16.0        # m desde los que los zombis la prefieren a ti
const ATRAE_PARADA := 30.0
const AMANECER_MARGEN := 0.85      # de lo que queda de noche se usa a lo mucho esto (el resto es holgura)
const RUTA_MIN := 20.0             # m: una casa mas cerca que esto de la anterior no cuenta como otra parada
const DIRECTA_SALTO := 40.0        # m de la parada de relleno si no hay calles (la safehouse no tiene)
const BARRA_ANCHO := 40            # pixeles de la barra de vida sobre la camioneta
const BARRA_ALTO := 6
const BARRA_PIXEL := 0.06          # m por pixel (la barra mide 2.4 m)
const BARRA_Y := 3.6
const BARRA_FONDO := Color(0.08, 0.02, 0.02)
const BARRA_BUENA := Color(0.35, 0.8, 0.3)
const BARRA_MALA := Color(0.9, 0.2, 0.15)

var estado := Estado.ANDA
var paradas: Array[Vector3] = []
var tramos: Array[PackedVector3Array] = []
var hechas := 0
var descarga_s := DESCARGA_S
var directa := false               # algun tramo no tuvo calle y va en linea recta

var _tramo := 0
var _conductor: ConductorCarro
var _queda := 0.0
var _barra: Sprite3D
var _imagen: Image


# Crea la camioneta en `desde` y le arma la ruta por `candidatas` (casas, en el orden en que se
# prueban): hasta `cuantas` paradas, las que quepan en `segundos_noche` (andar a VELOCIDAD_RUTA y
# descargar cada una). `rumbo_inicial`: hacia donde mira al salir (no arranca para atras). Si
# ninguna tiene calle, la ruta es en linea recta.
static func crear_reparto(padre: Node, desde: Vector3, candidatas: Array[Vector3], cuantas: int, con_vida: int, vida_total: int, segundos_noche: float, segundos_descarga := DESCARGA_S, rumbo_inicial := Vector3.ZERO) -> CamionetaReparto:
	var c := CamionetaReparto.new()
	c.vida = con_vida
	c.vida_max = vida_total
	c.descarga_s = segundos_descarga
	padre.add_child(c)
	var presupuesto := segundos_noche * AMANECER_MARGEN
	var actual := CallesRuta.calle_cercana(desde)
	if actual == Vector3.INF:
		actual = desde
	var gastado := 0.0
	var rumbo := rumbo_inicial   # hacia donde mira al llegar a cada parada: el siguiente tramo sale hacia adelante
	var restantes := candidatas.duplicate()
	while c.paradas.size() < cuantas and not restantes.is_empty():
		# Una busqueda de la parada actual a todas las casas que quedan; se toma la primera que quepa
		# en su parte de la noche (lo que queda entre las paradas que faltan: una lejana no se come
		# la noche entera) o, si ninguna, la mas cercana que quepa en lo que queda
		var parte := (presupuesto - gastado) / (cuantas - c.paradas.size())
		var alcance := (presupuesto - gastado - segundos_descarga) * VELOCIDAD_RUTA
		if alcance < RUTA_MIN:
			break
		var rutas := CallesRuta.entre_varias(actual, restantes, rumbo, alcance)
		if rumbo != Vector3.ZERO and rutas.all(func(r: PackedVector3Array) -> bool: return r.size() < 2):
			# Sin salida hacia adelante (una cerrada): da la vuelta en U ahi mismo
			rutas = CallesRuta.entre_varias(actual, restantes, Vector3.ZERO, alcance)
		var elegida := -1
		var cercana := -1
		for i in restantes.size():
			var largo := CallesRuta.largo(rutas[i]) if rutas[i].size() > 1 else 0.0
			if largo < RUTA_MIN or gastado + largo / VELOCIDAD_RUTA + segundos_descarga > presupuesto:
				continue
			if largo / VELOCIDAD_RUTA + segundos_descarga <= parte:
				elegida = i
				break
			if cercana < 0 or largo < CallesRuta.largo(rutas[cercana]):
				cercana = i
		if elegida < 0:
			elegida = cercana
		if elegida < 0:
			break
		gastado += CallesRuta.largo(rutas[elegida]) / VELOCIDAD_RUTA + segundos_descarga
		c._agregar(rutas[elegida])
		actual = rutas[elegida][rutas[elegida].size() - 1]
		rumbo = CallesRuta.rumbo_final(rutas[elegida])
		restantes.remove_at(elegida)
	if c.paradas.is_empty():
		# Sin calles que lleven a una casa: en linea recta, para que se pruebe donde no hay mapa
		c.directa = true
		var desde_ahora := desde
		for casa in candidatas:
			if c.paradas.size() >= cuantas:
				break
			var largo := desde_ahora.distance_to(casa)
			var t := largo / VELOCIDAD_RUTA + segundos_descarga
			if largo < RUTA_MIN or gastado + t > presupuesto:
				continue
			gastado += t
			c._agregar(PackedVector3Array([desde_ahora, casa]))
			desde_ahora = casa
		if c.paradas.is_empty():
			c._agregar(PackedVector3Array([desde, desde + Vector3(DIRECTA_SALTO, 0.0, 0.0)]))
	c.global_position = c.tramos[0][0]
	c._al_piso()
	c._arrancar()
	return c


func _ready() -> void:
	super()
	add_child(CamionetaModelo.crear(int(global_position.x) + int(global_position.z)))
	# La capsula del acompanante es de persona: la camioneta ocupa mas
	_conductor = ConductorCarro.new()
	_conductor.vel_max = VELOCIDAD_RUTA
	_conductor.parar_al_final = true
	_conductor.llego.connect(_llego)
	add_child(_conductor)
	_armar_barra()


func _agregar(ruta: PackedVector3Array) -> void:
	tramos.append(ruta)
	paradas.append(ruta[ruta.size() - 1])


# Cada punto de la ruta a la altura del piso que tiene abajo (las calles no son planas)
func _al_piso() -> void:
	var espacio := get_world_3d().direct_space_state
	for t in tramos.size():
		var ruta := tramos[t]
		for i in ruta.size():
			var punto := ruta[i]
			var rayo := PhysicsRayQueryParameters3D.create(punto + Vector3.UP * 6.0, punto + Vector3.DOWN * 8.0, 1)
			var pego := espacio.intersect_ray(rayo)
			if not pego.is_empty() and absf(pego.position.y - punto.y) < 4.0:
				punto.y = pego.position.y
			ruta[i] = punto
		tramos[t] = ruta
		paradas[t] = ruta[ruta.size() - 1]


func _arrancar() -> void:
	estado = Estado.ANDA
	quieto = false
	atrae = ATRAE_ANDANDO
	# El primer tramo se pone de frente de golpe; los demas siguen el rumbo con el que llego
	_conductor.iniciar(self, tramos[_tramo], true, _tramo == 0)


func _llego() -> void:
	if _cayo:
		return
	estado = Estado.DESCARGA
	quieto = true
	atrae = ATRAE_PARADA
	_queda = descarga_s


func _physics_process(delta: float) -> void:
	# No sigue al jugador (Acompanante): la conduce el ConductorCarro
	if _cayo or estado != Estado.DESCARGA:
		return
	_queda -= delta
	if _queda > 0.0:
		return
	hechas += 1
	entrega.emit(hechas)
	_tramo += 1
	if _tramo >= tramos.size():
		estado = Estado.TERMINO
		quieto = false
		atrae = 0.0
		termino.emit()
	else:
		_arrancar()


# A donde va ahora (la parada que sigue); en la ultima descarga, donde esta
func destino() -> Vector3:
	return paradas[mini(_tramo, paradas.size() - 1)]


# Cuanto falta de la descarga en curso (s), 0 si no esta descargando
func descargando_queda() -> float:
	return maxf(_queda, 0.0) if estado == Estado.DESCARGA else 0.0


# Lo llaman los zombis al pegarle (el mismo nombre que el tinaco y la bocina)
func recibir_golpe(dano: int) -> void:
	super(dano)
	_dibujar_barra()
	if _cayo:
		_conductor.pausa = true
		# Se queda parada y se ladea: no cae de espaldas como una persona
		rotation.x = 0.0
		rotation.z = deg_to_rad(9.0)


# La barra de vida sobre la camioneta: una imagen chica, de frente a la camara, que se redibuja al
# recibir un golpe
func _armar_barra() -> void:
	_imagen = Image.create(BARRA_ANCHO, BARRA_ALTO, false, Image.FORMAT_RGBA8)
	_barra = Sprite3D.new()
	_barra.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_barra.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_barra.pixel_size = BARRA_PIXEL
	_barra.shaded = false
	_barra.no_depth_test = true
	_barra.render_priority = 5
	_barra.position.y = BARRA_Y
	add_child(_barra)
	_dibujar_barra()


func _dibujar_barra() -> void:
	if _imagen == null:
		return
	var fraccion := clampf(float(vida) / maxf(vida_max, 1), 0.0, 1.0)
	var lleno := roundi(fraccion * (BARRA_ANCHO - 2))
	var color := BARRA_MALA.lerp(BARRA_BUENA, fraccion)
	_imagen.fill(BARRA_FONDO)
	for x in lleno:
		for y in range(1, BARRA_ALTO - 1):
			_imagen.set_pixel(x + 1, y, color)
	_barra.texture = ImageTexture.create_from_image(_imagen)
