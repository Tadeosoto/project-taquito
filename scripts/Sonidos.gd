class_name Sonidos
extends RefCounted

# Casi no hay archivos de audio en el juego: los sonidos cortos se arman en codigo y se
# guardan la primera vez que se piden (salvo ARCHIVOS).

const MUESTRAS := 22050

static var _sonidos := {}
# Si no esta vacio, solo suenan estos: los demas regresan null y su reproductor no toca
# nada. La defensa del tinaco deja solo los machetazos y los balazos, con su musica
static var solo: Array[String] = []

# Los unicos que vienen de archivo: el rugido de los zombis (JJ), la subida y la bajada sin lo de en medio para cuando te
# detectan, y para el aviso de que van a pegar el pico ya bajando. Ya vienen mas bajos
# (de "rugido zombie.mpeg" con ffmpeg).
const ARCHIVOS := {
	"rugido": "res://audio/zombis/rugido.ogg",
	"rugido_corto": "res://audio/zombis/rugido_corto.ogg",
	"disparo_pistola": "res://audio/weapons/pistol_shot.wav",   # grabado (CC0); Pistola.gd
	# La recarga de la pistola (Pistola._seguir_recarga), grabados (CC0)
	"recarga_suelta": "res://audio/weapons/pistol_mag_drop.wav",  # sale con el cargador (Cargador.gd)
	"recarga_mete": "res://audio/weapons/pistol_clip_insert.wav",
	"recarga_cierra": "res://audio/weapons/pistol_cock.wav",
}

# Cupo de rugidos: con una horda de 15 todos querian rugir a la vez y tapaban todo.
# Nunca suenan mas de RUGIDOS_MAX juntos, y entre uno y otro pasan RUGIDO_SEPARA s.
# Los cortos (aviso de ataque) tienen su propio cupo, mas suelto, porque te dicen algo.
const RUGIDOS_MAX := 2
const RUGIDO_SEPARA := 2.5
const CORTOS_MAX := 3
const CORTO_SEPARA := 0.35
static var _sonando := {"rugido": [], "rugido_corto": []}   # cuando acaba cada uno (ms)
static var _ultimo := {"rugido": -100000, "rugido_corto": -100000}


# true si `nombre` ("rugido" o "rugido_corto") puede sonar ahora, y lo aparta
static func turno(nombre: String, tono := 1.0) -> bool:
	if not _sonando.has(nombre):
		return true
	var stream := sonido(nombre)
	if stream == null:
		return false
	var ahora := Time.get_ticks_msec()
	var corto := nombre == "rugido_corto"
	var lista: Array = _sonando[nombre]
	lista = lista.filter(func(fin: int) -> bool: return fin > ahora)
	_sonando[nombre] = lista
	if lista.size() >= (CORTOS_MAX if corto else RUGIDOS_MAX):
		return false
	if ahora - int(_ultimo[nombre]) < int((CORTO_SEPARA if corto else RUGIDO_SEPARA) * 1000.0):
		return false
	_ultimo[nombre] = ahora
	lista.append(ahora + int(stream.get_length() / maxf(tono, 0.1) * 1000.0))
	return true


static func sonido(nombre: String) -> AudioStream:
	if not solo.is_empty() and not solo.has(nombre):
		return null
	if not _sonidos.has(nombre):
		if ARCHIVOS.has(nombre):
			_sonidos[nombre] = load(ARCHIVOS[nombre])
			return _sonidos[nombre]
		match nombre:
			"paso":
				_sonidos[nombre] = _tono(880.0, 0.035, 0.0, 0.5)
			"boton":
				_sonidos[nombre] = _tono(220.0, 0.05, -60.0, 0.6)
			"moneda":
				_sonidos[nombre] = _tono(1500.0, 0.06, 900.0, 0.5)
			"perder":
				_sonidos[nombre] = _tono(300.0, 0.45, -180.0, 0.5)
			"silbido":
				_sonidos[nombre] = _tono(500.0, 0.9, 1400.0, 0.2)
			"trueno":
				_sonidos[nombre] = _ruido(0.8, 0.35, 3.0)
			"machetazo":
				_sonidos[nombre] = _ruido(0.14, 0.8, 1.5)
			"golpe":
				_sonidos[nombre] = _ruido(0.18, 0.2, 2.0)
			"ladrido":
				_sonidos[nombre] = _tono(420.0, 0.11, -200.0, 0.7)
			"whack":
				_sonidos[nombre] = _whack()
			"bloqueo":
				_sonidos[nombre] = _bloqueo()
			"casquillo":
				_sonidos[nombre] = _casquillo()
			"reventar":
				_sonidos[nombre] = _reventar()
			# La Madre del Carcamo y sus crias (scripts/lombrices/)
			"squelch":
				_sonidos[nombre] = _squelch()
			"fizz":
				_sonidos[nombre] = _ruido(0.6, 0.92, 1.4)
			"chillido":
				_sonidos[nombre] = _chillido()
			"chapoteo":
				_sonidos[nombre] = _chapoteo()
			# La libreta del Nocturno: un lapiz que raya papel
			"lapiz":
				_sonidos[nombre] = _lapiz()
			"dolor":
				_sonidos[nombre] = _tono(190.0, 0.22, -70.0, 0.6)
			"gemido":
				_sonidos[nombre] = _gemido()
			"morir_zombi":
				_sonidos[nombre] = _tono(120.0, 0.6, -80.0, 0.6)
			"campana":
				_sonidos[nombre] = _tono(620.0, 1.6, -8.0, 0.4)
			# Menus e inventario: survival horror de los 90 (clics secos, campanitas
			# metalicas con eco, estatica que crece). Hechos aqui, no sacados de ningun juego.
			"ui_mover":
				_sonidos[nombre] = _ui_mover()
			"ui_aceptar":
				_sonidos[nombre] = _ui_aceptar()
			"ui_cancelar":
				_sonidos[nombre] = _ui_cancelar()
			"ui_error":
				_sonidos[nombre] = _ui_error()
			"inv_abrir":
				_sonidos[nombre] = _inv_abrir()
			"inv_cerrar":
				_sonidos[nombre] = _inv_cerrar()
			"inv_girar":
				_sonidos[nombre] = _inv_girar()
			"inv_examinar":
				_sonidos[nombre] = _inv_examinar()
			"inv_usar":
				_sonidos[nombre] = _inv_usar()
			"inv_combinar":
				_sonidos[nombre] = _inv_combinar()
			"mapa_abrir":
				_sonidos[nombre] = _papel(0.38, 41)
			"mapa_cerrar":
				_sonidos[nombre] = _papel(0.24, 43)
			"ui_jugar":
				_sonidos[nombre] = _ui_jugar()
			"ui_azar":
				_sonidos[nombre] = _ui_azar()
			"inicio_partida":
				_sonidos[nombre] = _inicio_partida()
			"menu_aparece":
				_sonidos[nombre] = _menu_aparece()
			"ambiente_menu":
				_sonidos[nombre] = _ambiente_menu()
			# Abrir una bolsa especial de Takis (TazoRevelacion.gd)
			"bolsa_abrir":
				_sonidos[nombre] = _papel(0.32, 91)
			"tazo_tiembla":
				_sonidos[nombre] = _tazo_tiembla()
			"destello":
				_sonidos[nombre] = _destello()
			"brillo":
				_sonidos[nombre] = _brillo()
			"retumbo":
				_sonidos[nombre] = _retumbo()
			"zumbido":
				_sonidos[nombre] = _zumbido()
			"boom":
				_sonidos[nombre] = _boom()
			# Recoger una cajita de botin o una moneda (CajaBotin.gd)
			"botin":
				_sonidos[nombre] = _botin()
			"disparo", "disparo_1":
				_sonidos[nombre] = _disparo(0)
			"disparo_2":
				_sonidos[nombre] = _disparo(1)
			"disparo_3":
				_sonidos[nombre] = _disparo(2)
			"disparo_4":
				_sonidos[nombre] = _disparo(3)
			"recarga":
				_sonidos[nombre] = _recarga()
			"cortina":
				_sonidos[nombre] = _cortina()
			"cortina_tope":
				_sonidos[nombre] = _cortina_tope()
	return _sonidos[nombre]


# Campanita de arcade: dos notas cuadradas que suben, la segunda con mas cola
static func _botin() -> AudioStreamWAV:
	var notas := [[1318.5, 0.0, 0.05], [1975.5, 0.045, 0.16]]   # Mi6 y Si6: hz, desde s, dura s
	var salida := PackedFloat32Array()
	salida.resize(int(0.22 * MUESTRAS))
	for nota: Array in notas:
		var inicio := int(nota[1] * MUESTRAS)
		var cuantas := int(nota[2] * MUESTRAS)
		var fase := 0.0
		for i in cuantas:
			if inicio + i >= salida.size():
				break
			var t := float(i) / cuantas
			fase += nota[0] / MUESTRAS
			salida[inicio + i] += (1.0 if fmod(fase, 1.0) < 0.5 else -1.0) * 0.28 * pow(1.0 - t, 1.5)
	return _a_wav(salida)


# Toca `nombre` una vez colgado de `donde` y se borra al terminar. Suena aunque el
# juego este en pausa (el inventario pausa el arbol).
static func tocar(donde: Node, nombre: String, volumen_db := 0.0, tono := 1.0) -> void:
	if donde == null or not donde.is_inside_tree():
		return
	var voz := AudioStreamPlayer.new()
	voz.stream = sonido(nombre)
	voz.volume_db = volumen_db
	voz.pitch_scale = tono
	voz.process_mode = Node.PROCESS_MODE_ALWAYS
	voz.finished.connect(voz.queue_free)
	donde.add_child(voz)
	voz.play()


# --- Menus e inventario ------------------------------------------------------

# Cursor: un tic corto y brillante con un clic encima
static func _ui_mover() -> AudioStreamWAV:
	var b := _vacio(0.06)
	var azar := RandomNumberGenerator.new()
	azar.seed = 47
	var fase := 0.0
	for i in b.size():
		var t := float(i) / MUESTRAS
		fase += 1750.0 / MUESTRAS
		var clic := (azar.randf_range(-1.0, 1.0) if t < 0.003 else 0.0) * 0.4
		b[i] = sin(fase * TAU) * exp(-t * 90.0) * 0.45 + clic
	return _a_wav(_eco(b, [19, 29], 0.25, 0.08, 0.3))


# No se puede: dos zumbidos graves desafinados
static func _ui_error() -> AudioStreamWAV:
	var b := _vacio(0.24)
	var f1 := 0.0
	var f2 := 0.0
	for i in b.size():
		var t := float(i) / MUESTRAS
		f1 += 110.0 / MUESTRAS
		f2 += 117.0 / MUESTRAS
		var golpe := 1.0 if t < 0.09 or (t > 0.13 and t < 0.22) else 0.0
		var cuadrada := (1.0 if fmod(f1, 1.0) < 0.5 else -1.0) + (1.0 if fmod(f2, 1.0) < 0.5 else -1.0)
		b[i] = cuadrada * 0.24 * golpe
	return _a_wav(_eco(b, [31], 0.2, 0.06, 0.2))


# Abrir: un pestillo de dos tiempos (clic-clac), el primero agudo y el segundo firme
static func _inv_abrir() -> AudioStreamWAV:
	var b := _vacio(0.16)
	b = _mezclar(b, _clic(2600.0, 140.0, 0.35, 61), 0.0)
	b = _mezclar(b, _clic(1250.0, 90.0, 0.6, 62), 0.07)
	return _a_wav(_eco(b, [23, 37], 0.3, 0.12, 0.25))


# Cerrar: un solo clic grave y sordo con un poco de cuerpo abajo
static func _inv_cerrar() -> AudioStreamWAV:
	var b := _vacio(0.14)
	b = _mezclar(b, _clic(320.0, 70.0, 0.6, 63), 0.0)
	var fase := 0.0
	for i in b.size():
		var t := float(i) / MUESTRAS
		fase += 70.0 / MUESTRAS
		b[i] += sin(fase * TAU) * exp(-t * 35.0) * 0.35
	return _a_wav(_eco(b, [29, 43], 0.3, 0.12, 0.2))


# Cambiar de objeto: el tic mas ligero de todos
static func _inv_girar() -> AudioStreamWAV:
	return _a_wav(_eco(_clic(2200.0, 180.0, 0.4, 64), [17], 0.2, 0.05, 0.15))


# Un clic limpio: un chasquido de 2.5 ms (ruido filtrado) y un cuerpo seno que se
# apaga rapido segun `caida`. Sin cola de ruido, para que no suene a barrido.
static func _clic(frecuencia: float, caida: float, volumen: float, semilla: int) -> PackedFloat32Array:
	var b := _vacio(minf(6.0 / caida + 0.01, 0.12))
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	var ruido := 0.0
	for i in b.size():
		var t := float(i) / MUESTRAS
		ruido = lerpf(ruido, azar.randf_range(-1.0, 1.0), 0.7)
		var chasquido := ruido * (1.0 - minf(t / 0.0025, 1.0)) * 0.6
		b[i] = (sin(TAU * frecuencia * t) * exp(-t * caida) + chasquido) * volumen
	return b


# Suma `fuente` a una copia de `destino` desde `desde` segundos (los Packed se pasan por valor)
static func _mezclar(destino: PackedFloat32Array, fuente: PackedFloat32Array, desde: float) -> PackedFloat32Array:
	var inicio := int(desde * MUESTRAS)
	for i in fuente.size():
		if inicio + i >= destino.size():
			break
		destino[inicio + i] += fuente[i]
	return destino


# Ambiente del menu: zumbido grave y viento lejano que se repiten sin costura.
# Las frecuencias son multiplos de 1/LARGO Hz para que cada una cierre ciclos
# completos en el bucle; el viento se funde de su final a su principio.
static func _ambiente_menu() -> AudioStreamWAV:
	const LARGO := 8.0
	const FUNDIDO := 0.5
	var cuantas := int(LARGO * MUESTRAS)
	var b := _vacio(LARGO)
	var tonos: Array[float] = [55.0, 82.5, 110.125]
	var pesos: Array[float] = [0.5, 0.22, 0.12]
	var azar := RandomNumberGenerator.new()
	azar.seed = 81
	var extra := int(FUNDIDO * MUESTRAS)
	var viento := PackedFloat32Array()
	viento.resize(cuantas + extra)
	var bajo := 0.0
	var mas_bajo := 0.0
	for i in viento.size():
		bajo = lerpf(bajo, azar.randf_range(-1.0, 1.0), 0.04)
		mas_bajo = lerpf(mas_bajo, bajo, 0.08)
		viento[i] = mas_bajo
	# El pedazo de mas al final se funde sobre el principio: el ruido cierra el bucle
	for i in extra:
		var f := float(i) / extra
		viento[i] = lerpf(viento[cuantas + i], viento[i], f)
	for i in cuantas:
		var t := float(i) / MUESTRAS
		var lfo := 0.75 + 0.25 * sin(TAU * t / LARGO)
		var dron := 0.0
		for k in tonos.size():
			dron += sin(TAU * tonos[k] * t) * pesos[k]
		var rafaga := 0.55 + 0.45 * sin(TAU * t * 2.0 / LARGO + 1.3)
		b[i] = dron * lfo * 0.5 + viento[i] * rafaga * 2.2
	var wav := _a_wav(b)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = cuantas
	return wav


# Examinar: un zumbido grave que se abre, como acercarse a algo
static func _inv_examinar() -> AudioStreamWAV:
	var b := _vacio(0.45)
	var fase := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		fase += lerpf(98.0, 110.0, t) / MUESTRAS
		var onda := sin(fase * TAU) + sin(fase * 2.0 * TAU) * 0.5 + sin(fase * 3.01 * TAU) * 0.25
		b[i] = onda * sin(PI * t) * 0.3
	return _a_wav(_eco(b, [61, 83, 101], 0.55, 0.5, 0.4))


# Papel que se desdobla: rafagas de ruido de fuerza al azar
static func _papel(duracion: float, semilla: int) -> AudioStreamWAV:
	var b := _vacio(duracion)
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	var ruido := 0.0
	var anterior := 0.0
	var fuerza := 0.0
	for i in b.size():
		if i % 300 == 0:
			fuerza = azar.randf_range(0.0, 1.0) * azar.randf_range(0.0, 1.0)
		ruido = lerpf(ruido, azar.randf_range(-1.0, 1.0), 0.6)
		var crujido := ruido - anterior
		anterior = ruido
		var t := float(i) / b.size()
		b[i] = crujido * fuerza * minf(t * 20.0, 1.0) * (1.0 - t) * 0.9
	return _a_wav(_eco(b, [17, 29], 0.2, 0.05, 0.5))


# --- Tazos (TazoRevelacion.gd) -------------------------------------------------

# El tazo temblando adentro de la bolsa: golpecitos de carton duro, cada vez mas seguidos
static func _tazo_tiembla() -> AudioStreamWAV:
	var b := _vacio(0.9)
	var t := 0.0
	var paso := 0.11
	var i := 0
	while t < 0.8:
		b = _mezclar(b, _clic(900.0 + 260.0 * (i % 3), 160.0, 0.35, 100 + i), t)
		t += paso
		paso = maxf(paso * 0.86, 0.035)
		i += 1
	return _a_wav(_eco(b, [13, 21], 0.2, 0.05, 0.25))


# Destello al voltearlo: un acorde brillante de tres campanitas con eco largo
static func _destello() -> AudioStreamWAV:
	var b := _vacio(0.7)
	var tonos: Array[float] = [1320.0, 1661.0, 1976.0]
	for i in b.size():
		var t := float(i) / MUESTRAS
		var suma := 0.0
		for k in tonos.size():
			var arranca := k * 0.035
			if t >= arranca:
				suma += sin(TAU * tonos[k] * (t - arranca)) * exp(-(t - arranca) * 6.0)
		b[i] = suma * 0.22
	return _a_wav(_eco(b, [53, 89, 131], 0.45, 0.6, 0.45))


# El brillo del holografico: un barrido agudo que sube y tiembla, como celofan
static func _brillo() -> AudioStreamWAV:
	var b := _vacio(1.4)
	var fase := 0.0
	var azar := RandomNumberGenerator.new()
	azar.seed = 93
	for i in b.size():
		var t := float(i) / b.size()
		fase += lerpf(1800.0, 4200.0, t) * (1.0 + 0.03 * sin(t * 90.0)) / MUESTRAS
		var chispa := azar.randf_range(-1.0, 1.0) * 0.15 if azar.randf() < 0.02 else 0.0
		b[i] = (sin(fase * TAU) * 0.12 + chispa) * sin(PI * t)
	return _a_wav(_eco(b, [41, 67], 0.4, 0.4, 0.4))


# Retumbo: un grave que crece y tiembla antes del golpe
static func _retumbo() -> AudioStreamWAV:
	var b := _vacio(0.9)
	var azar := RandomNumberGenerator.new()
	azar.seed = 95
	var ruido := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		var s := float(i) / MUESTRAS
		ruido = lerpf(ruido, azar.randf_range(-1.0, 1.0), 0.03)
		var grave := sin(TAU * (42.0 + 8.0 * sin(s * 30.0)) * s)
		b[i] = (grave * 0.55 + ruido * 2.5) * t * t
	return _a_wav(b)


# Zumbido: aire que pasa rapido, ruido que se abre y se cierra
static func _zumbido() -> AudioStreamWAV:
	var b := _vacio(0.45)
	var azar := RandomNumberGenerator.new()
	azar.seed = 97
	var ruido := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		ruido = lerpf(ruido, azar.randf_range(-1.0, 1.0), lerpf(0.05, 0.6, t))
		b[i] = ruido * sin(PI * t) * 0.8
	return _a_wav(b)


# Boom: un golpe grave que cae con estallido de ruido y cola larga
static func _boom() -> AudioStreamWAV:
	var b := _vacio(1.1)
	var azar := RandomNumberGenerator.new()
	azar.seed = 99
	var fase := 0.0
	var ruido := 0.0
	for i in b.size():
		var t := float(i) / MUESTRAS
		fase += lerpf(90.0, 32.0, minf(t / 0.5, 1.0)) / MUESTRAS
		ruido = lerpf(ruido, azar.randf_range(-1.0, 1.0), 0.25)
		var golpe := sin(fase * TAU) * exp(-t * 4.0)
		var estallido := ruido * exp(-t * 14.0) * 1.4
		b[i] = clampf(golpe * 0.85 + estallido, -1.0, 1.0)
	return _a_wav(_eco(b, [71, 113], 0.35, 0.5, 0.3))


# Pistola (Pistola.gd): un estallido seco de ruido con un golpe grave abajo y un poco de
# eco de calle, mas corto que el cohete
# Las variantes del balazo (Pistola elige una al azar): semilla, tono del cuerpo (de, a),
# cuanto dura el cuerpo, cuanto el estallido, que tan aspero es el ruido y la cola del eco
const DISPAROS := [
	{"semilla": 61, "tono": Vector2(160.0, 55.0), "cuerpo": 22.0, "estallido": 38.0, "aspero": 0.6, "eco": 0.3},
	{"semilla": 73, "tono": Vector2(185.0, 62.0), "cuerpo": 26.0, "estallido": 46.0, "aspero": 0.75, "eco": 0.25},
	{"semilla": 89, "tono": Vector2(140.0, 48.0), "cuerpo": 18.0, "estallido": 32.0, "aspero": 0.5, "eco": 0.38},
	{"semilla": 97, "tono": Vector2(170.0, 58.0), "cuerpo": 24.0, "estallido": 52.0, "aspero": 0.85, "eco": 0.3},
]


static func _disparo(variante: int) -> AudioStreamWAV:
	var v: Dictionary = DISPAROS[variante]
	var tono: Vector2 = v["tono"]
	var b := _vacio(0.35)
	var azar := RandomNumberGenerator.new()
	azar.seed = v["semilla"]
	var fase := 0.0
	var ruido := 0.0
	for i in b.size():
		var t := float(i) / MUESTRAS
		fase += lerpf(tono.x, tono.y, minf(t / 0.12, 1.0)) / MUESTRAS
		ruido = lerpf(ruido, azar.randf_range(-1.0, 1.0), v["aspero"])
		var golpe := sin(fase * TAU) * exp(-t * v["cuerpo"])
		var estallido := ruido * exp(-t * v["estallido"]) * 1.6
		b[i] = clampf(golpe * 0.8 + estallido, -1.0, 1.0)
	return _a_wav(_eco(b, [47, 89], v["eco"], 0.25, 0.35))


# Dos clics metalicos: sale el cargador y entra el otro
static func _recarga() -> AudioStreamWAV:
	var b := _vacio(0.5)
	var azar := RandomNumberGenerator.new()
	azar.seed = 67
	for desde: float in [0.0, 0.32]:
		var fase := 0.0
		for i in int(0.06 * MUESTRAS):
			var t := float(i) / MUESTRAS
			fase += 2400.0 / MUESTRAS
			var j := int(desde * MUESTRAS) + i
			b[j] += (sin(fase * TAU) * 0.5 + azar.randf_range(-1.0, 1.0) * 0.5) * exp(-t * 90.0) * 0.8
	return _a_wav(b)


# La cortina de lamina enrollandose o bajando: el traqueteo de las tablillas, en bucle (MapPuntos
# lo toca mientras se mueve). 20 tablillas por segundo, asi el segundo cierra sin costura.
static func _cortina() -> AudioStreamWAV:
	var b := _vacio(1.0)
	var azar := RandomNumberGenerator.new()
	azar.seed = 83
	for k in 20:
		var clic := _clic(azar.randf_range(900.0, 1500.0), azar.randf_range(140.0, 220.0), azar.randf_range(0.18, 0.3), 200 + k)
		b = _mezclar(b, clic, k * 0.05 + azar.randf_range(0.0, 0.012))
	# Un rumor grave de lamina debajo
	var ruido := 0.0
	for i in b.size():
		ruido = lerpf(ruido, azar.randf_range(-1.0, 1.0), 0.04)
		b[i] += ruido * 0.25
	var wav := _a_wav(b)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = b.size()
	return wav


# El golpe de la cortina al llegar al piso (o al rollo de arriba)
static func _cortina_tope() -> AudioStreamWAV:
	var b := _golpe_grave(85.0, 14.0, 0.7, 0.45)
	b = _mezclar(b, _clic(620.0, 40.0, 0.35, 91), 0.0)
	b = _mezclar(b, _clic(1100.0, 60.0, 0.2, 92), 0.07)
	return _a_wav(_eco(b, [23, 37], 0.3, 0.15, 0.3))


static func _vacio(duracion: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(duracion * MUESTRAS))
	return b


# Eco de cuarto: varios retardos (ms) que se realimentan y se oscurecen, sumados al
# sonido seco. `cola` alarga el sonido en segundos para que el eco se apague solo.
static func _eco(seco: PackedFloat32Array, retardos: Array[int], realimentacion: float, cola: float, mezcla: float) -> PackedFloat32Array:
	var total := seco.size() + int(cola * MUESTRAS)
	var salida := PackedFloat32Array()
	salida.resize(total)
	for i in seco.size():
		salida[i] = seco[i]
	for ms: int in retardos:
		var d := int(ms * MUESTRAS / 1000.0)
		var linea := PackedFloat32Array()
		linea.resize(total)
		var oscuro := 0.0
		for i in total:
			var entrada := seco[i] if i < seco.size() else 0.0
			var atras := linea[i - d] if i >= d else 0.0
			oscuro = lerpf(oscuro, atras, 0.45)
			linea[i] = entrada + oscuro * realimentacion
		for i in total:
			salida[i] += (linea[i] - (seco[i] if i < seco.size() else 0.0)) * mezcla / retardos.size()
	# Que la cola no corte de golpe
	var fundido := mini(int(0.03 * MUESTRAS), total)
	for i in fundido:
		salida[total - 1 - i] *= float(i) / fundido
	return salida


static func _a_wav(b: PackedFloat32Array) -> AudioStreamWAV:
	var datos := PackedByteArray()
	datos.resize(b.size() * 2)
	for i in b.size():
		datos.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32000.0))
	return _wav(datos)


# Onda cuadrada de `frecuencia` Hz que sube o baja `barrido` Hz en `duracion` s
static func _tono(frecuencia: float, duracion: float, barrido: float, volumen: float) -> AudioStreamWAV:
	var datos := PackedByteArray()
	var cuantas := int(duracion * MUESTRAS)
	datos.resize(cuantas * 2)
	var fase := 0.0
	for i in cuantas:
		var t := float(i) / cuantas
		fase += (frecuencia + barrido * t) / MUESTRAS
		var valor := (1.0 if fmod(fase, 1.0) < 0.5 else -1.0) * volumen * (1.0 - t)
		datos.encode_s16(i * 2, int(valor * 32000.0))
	return _wav(datos)


# Ruido que se apaga: con `filtro` bajo suena a golpe, alto a siseo
static func _ruido(duracion: float, filtro: float, caida: float) -> AudioStreamWAV:
	var datos := PackedByteArray()
	var cuantas := int(duracion * MUESTRAS)
	datos.resize(cuantas * 2)
	var azar := RandomNumberGenerator.new()
	azar.seed = 11
	var valor := 0.0
	for i in cuantas:
		var t := float(i) / cuantas
		valor = lerpf(valor, azar.randf_range(-1.0, 1.0), filtro)
		datos.encode_s16(i * 2, int(valor * 32000.0 * pow(1.0 - t, caida)))
	return _wav(datos)


# El golpe que pega: un chasquido seco de ruido encima de un retumbo grave
static func _whack() -> AudioStreamWAV:
	var datos := PackedByteArray()
	var cuantas := int(0.13 * MUESTRAS)
	datos.resize(cuantas * 2)
	var azar := RandomNumberGenerator.new()
	azar.seed = 23
	var fase := 0.0
	for i in cuantas:
		var t := float(i) / cuantas
		fase += lerpf(150.0, 50.0, t) / MUESTRAS
		var chasquido := azar.randf_range(-1.0, 1.0) * pow(1.0 - minf(t * 4.0, 1.0), 2.0)
		var retumbo := sin(fase * TAU) * pow(1.0 - t, 2.0)
		datos.encode_s16(i * 2, int(clampf(chasquido * 0.9 + retumbo * 0.75, -1.0, 1.0) * 32000.0))
	return _wav(datos)


# Golpe parado con el machete: un golpe sordo en el cuerpo, el chasquido del choque y la hoja que
# vibra (parciales que no son armonicos, como una lamina), con un poco de eco
# El casquillo de laton que cae al piso: un "tin" agudo, tres parciales inarmonicos que se
# apagan en ~80 ms y un chasquido al principio (Casquillo.gd le sube el tono al azar)
static func _casquillo() -> AudioStreamWAV:
	const DURA := 0.18
	var b := PackedFloat32Array()
	b.resize(int(DURA * MUESTRAS))
	var azar := RandomNumberGenerator.new()
	azar.seed = 17
	var parciales := [[3200.0, 38.0, 0.35], [4700.0, 55.0, 0.25], [6100.0, 70.0, 0.15]]
	for i in b.size():
		var t := float(i) / MUESTRAS
		var tin := azar.randf_range(-1.0, 1.0) * exp(-t * 400.0) * 0.3
		for p: Array in parciales:
			tin += sin(TAU * p[0] * t) * exp(-t * p[1]) * p[2]
		b[i] = tin
	return _a_wav(b)


static func _bloqueo() -> AudioStreamWAV:
	var b := _golpe_grave(85.0, 18.0, 0.7, 0.45)
	var azar := RandomNumberGenerator.new()
	azar.seed = 91
	var parciales := [[1180.0, 9.0, 0.32], [1910.0, 12.0, 0.24], [2970.0, 16.0, 0.16], [4230.0, 22.0, 0.1]]
	for i in b.size():
		var t := float(i) / MUESTRAS
		var choque := azar.randf_range(-1.0, 1.0) * exp(-t * 120.0) * 0.8
		var lamina := 0.0
		for p: Array in parciales:
			lamina += sin(TAU * p[0] * t) * exp(-t * p[1]) * p[2]
		b[i] += choque + lamina
	return _a_wav(_eco(b, [23, 37], 0.3, 0.15, 0.25))


# Un zombi que gime: una garganta (diente de sierra apagado) que sube y luego se cae,
# "uuurgh", con dos resonancias de boca entre "o" y "u", carraspeo irregular, aire y un poco
# de eco. Antes era un tono cuadrado que bajaba y sonaba a globo desinflandose.
static func _gemido() -> AudioStreamWAV:
	const DURA := 1.4
	var cuantas := int(DURA * MUESTRAS)
	var seco := PackedFloat32Array()
	seco.resize(cuantas)
	var azar := RandomNumberGenerator.new()
	azar.seed = 41
	var fase := 0.0
	var garganta := 0.0
	var carraspeo := 0.0
	var aire := 0.0
	# Dos resonadores de dos polos: [y1, y2] de cada uno
	var r1 := [0.0, 0.0]
	var r2 := [0.0, 0.0]
	var pico := 0.0
	for i in cuantas:
		var t := float(i) / cuantas
		# Tono: 72 Hz, sube a 92 al primer tercio y se cae a 58, con temblor
		var tono := lerpf(72.0, 92.0, smoothstep(0.0, 0.3, t)) - 34.0 * smoothstep(0.35, 1.0, t)
		tono *= 1.0 + 0.035 * sin(t * DURA * TAU * 5.5) + 0.02 * azar.randf_range(-1.0, 1.0)
		fase += tono / MUESTRAS
		var sierra := fmod(fase, 1.0) * 2.0 - 1.0
		garganta = lerpf(garganta, sierra, 0.35)
		# Carraspeo: ruido lento que abre y cierra la garganta, mas al final
		carraspeo = lerpf(carraspeo, azar.randf_range(0.0, 1.0), 0.004)
		var voz := garganta * (0.55 + 0.9 * carraspeo * (0.5 + t))
		aire = lerpf(aire, azar.randf_range(-1.0, 1.0), 0.12)
		var fuente := voz + aire * 0.25
		# Boca: de "o" (520 / 880 Hz) a "u" (380 / 700 Hz)
		var f1 := _resonar(fuente, lerpf(520.0, 380.0, t), 0.985, r1)
		var f2 := _resonar(fuente, lerpf(880.0, 700.0, t), 0.98, r2)
		var envolvente := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.65, 1.0, t))
		# Lo que mas se oye es la boca; la garganta sola da el cuerpo grave
		var valor := (garganta * 0.15 + f1 * 0.35 + f2 * 0.2) * envolvente
		seco[i] = valor
		pico = maxf(pico, absf(valor))
	# Que no truene fuerte: mas quedito que el tono de antes
	var escala := 0.5 / maxf(pico, 0.001)
	for i in cuantas:
		seco[i] *= escala
	return _a_wav(_eco(seco, [83, 131] as Array[int], 0.3, 0.45, 0.35))


# Un resonador de dos polos en `frecuencia` Hz; `radio` cerca de 1 = mas angosto
static func _resonar(entrada: float, frecuencia: float, radio: float, estado: Array) -> float:
	var y: float = (1.0 - radio) * entrada + 2.0 * radio * cos(TAU * frecuencia / MUESTRAS) * estado[0] - radio * radio * estado[1]
	estado[1] = estado[0]
	estado[0] = y
	return y


# Un globo de agua que truena: un pop agudo que cae y luego el agua que se riega
static func _reventar() -> AudioStreamWAV:
	var datos := PackedByteArray()
	var cuantas := int(0.42 * MUESTRAS)
	datos.resize(cuantas * 2)
	var azar := RandomNumberGenerator.new()
	azar.seed = 37
	var fase := 0.0
	var agua := 0.0
	for i in cuantas:
		var t := float(i) / cuantas
		fase += lerpf(1100.0, 160.0, minf(t * 7.0, 1.0)) / MUESTRAS
		var pop := sin(fase * TAU) * pow(1.0 - minf(t * 6.0, 1.0), 2.0)
		agua = lerpf(agua, azar.randf_range(-1.0, 1.0), 0.28)
		var riego := agua * 1.8 * minf(t * 12.0, 1.0) * pow(1.0 - t, 2.5)
		datos.encode_s16(i * 2, int(clampf(pop * 0.8 + riego, -1.0, 1.0) * 32000.0))
	return _wav(datos)


# Algo blando que se aplasta: un golpe grave corto y ruido mojado que se apaga rapido
static func _squelch() -> AudioStreamWAV:
	var b := _vacio(0.22)
	var azar := RandomNumberGenerator.new()
	azar.seed = 61
	var agua := 0.0
	var fase := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		fase += lerpf(180.0, 70.0, t) / MUESTRAS
		agua = lerpf(agua, azar.randf_range(-1.0, 1.0), 0.35 + 0.4 * sin(t * 40.0) * sin(t * 40.0))
		b[i] = sin(fase * TAU) * pow(1.0 - t, 3.0) * 0.7 + agua * 1.6 * pow(1.0 - t, 2.0)
	return _a_wav(b)


# El chillido de la Madre: un barrido agudo que se quiebra, con un temblor
static func _chillido() -> AudioStreamWAV:
	var b := _vacio(0.9)
	var fase := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		var s := float(i) / MUESTRAS
		fase += (lerpf(1300.0, 380.0, t) + sin(s * 55.0) * 60.0) / MUESTRAS
		var onda := sin(fase * TAU) + 0.4 * sin(fase * TAU * 2.01)
		b[i] = onda * 0.35 * minf(t * 10.0, 1.0) * pow(1.0 - t, 1.5)
	return _a_wav(b)


# Un lapiz rayando: tres trazos cortos de ruido agudo que suben y bajan
static func _lapiz() -> AudioStreamWAV:
	var b := _vacio(0.45)
	var azar := RandomNumberGenerator.new()
	azar.seed = 71
	var ruido := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		ruido = lerpf(ruido, azar.randf_range(-1.0, 1.0), 0.75)
		var trazo := maxf(sin(t * PI * 6.0), 0.0)
		b[i] = ruido * 0.35 * trazo * (1.0 - t * 0.5)
	return _a_wav(b)


# Algo grande que sale del lodo: un golpe sordo y agua que cae
static func _chapoteo() -> AudioStreamWAV:
	var b := _vacio(0.8)
	var azar := RandomNumberGenerator.new()
	azar.seed = 23
	var agua := 0.0
	var fase := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		fase += lerpf(90.0, 40.0, t) / MUESTRAS
		agua = lerpf(agua, azar.randf_range(-1.0, 1.0), 0.18)
		b[i] = sin(fase * TAU) * pow(1.0 - minf(t * 3.0, 1.0), 2.0) * 0.8 + agua * 2.2 * minf(t * 8.0, 1.0) * pow(1.0 - t, 1.8)
	return _a_wav(b)


static func _wav(datos: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MUESTRAS
	wav.data = datos
	return wav


# Aceptar: un clic firme con un golpecito grave abajo, sin campana
static func _ui_aceptar() -> AudioStreamWAV:
	var b := _vacio(0.12)
	b = _mezclar(b, _clic(1400.0, 100.0, 0.55, 91), 0.0)
	b = _mezclar(b, _golpe_grave(110.0, 40.0, 0.35, 0.1), 0.0)
	return _a_wav(_eco(b, [29, 41], 0.3, 0.12, 0.22))


# Cancelar: un clic suave y grave, de la familia de cerrar pero un poco mas agudo
static func _ui_cancelar() -> AudioStreamWAV:
	var b := _clic(450.0, 75.0, 0.55, 92)
	return _a_wav(_eco(b, [27, 39], 0.3, 0.1, 0.2))


# Jugar: un doble clic pesado con un golpe grave
static func _ui_jugar() -> AudioStreamWAV:
	var b := _vacio(0.3)
	b = _mezclar(b, _clic(900.0, 80.0, 0.5, 93), 0.0)
	b = _mezclar(b, _clic(600.0, 60.0, 0.6, 94), 0.06)
	b = _mezclar(b, _golpe_grave(75.0, 14.0, 0.4, 0.25), 0.06)
	return _a_wav(_eco(b, [41, 59, 73], 0.4, 0.3, 0.28))


# Al azar: cuatro clics que suben rapido y un clic firme mas grave al final
static func _ui_azar() -> AudioStreamWAV:
	var b := _vacio(0.32)
	var tonos: Array[float] = [900.0, 1200.0, 1600.0, 2100.0]
	for k in tonos.size():
		b = _mezclar(b, _clic(tonos[k], 150.0, 0.4, 70 + k), k * 0.045)
	b = _mezclar(b, _clic(700.0, 70.0, 0.6, 75), 0.2)
	b = _mezclar(b, _golpe_grave(100.0, 30.0, 0.25, 0.1), 0.2)
	return _a_wav(_eco(b, [31, 47], 0.35, 0.15, 0.25))


# Empezar la partida: un golpe grave que retumba y un segundo mas quedito, con un eco
# largo y oscuro, como cruzar una puerta que no debias. Sin metal.
static func _inicio_partida() -> AudioStreamWAV:
	var b := _vacio(1.6)
	var fase := 0.0
	for i in b.size():
		var t := float(i) / MUESTRAS
		fase += lerpf(62.0, 41.0, minf(t * 2.0, 1.0)) / MUESTRAS
		b[i] = sin(fase * TAU) * minf(t * 300.0, 1.0) * exp(-t * 2.2) * 0.68
	b = _mezclar(b, _clic(240.0, 45.0, 0.35, 95), 0.0)
	b = _mezclar(b, _golpe_grave(48.0, 5.0, 0.35, 0.9), 0.4)
	return _a_wav(_eco(b, [79, 113, 149, 197], 0.72, 2.5, 0.45))


# El menu aparece: un zumbido grave que crece y se apaga en un golpe sordo
static func _menu_aparece() -> AudioStreamWAV:
	var b := _vacio(1.1)
	var fase := 0.0
	var crecer := 0.7
	for i in b.size():
		var t := float(i) / MUESTRAS
		fase += 73.42 / MUESTRAS
		var sobre := smoothstep(0.0, crecer, t) * (exp(-(t - crecer) * 6.0) if t > crecer else 1.0)
		b[i] = (sin(fase * TAU) + sin(fase * 1.5 * TAU) * 0.3) * sobre * 0.35
	b = _mezclar(b, _golpe_grave(60.0, 9.0, 0.55, 0.4), crecer)
	b = _mezclar(b, _clic(300.0, 60.0, 0.3, 96), crecer)
	return _a_wav(_eco(b, [67, 97, 131], 0.55, 1.0, 0.35))


# Utilizar (curarse): un pop suave, un seno que cae rapido con un soplo
static func _inv_usar() -> AudioStreamWAV:
	var b := _vacio(0.12)
	var azar := RandomNumberGenerator.new()
	azar.seed = 97
	var fase := 0.0
	var ruido := 0.0
	for i in b.size():
		var t := float(i) / MUESTRAS
		fase += lerpf(600.0, 250.0, minf(t / 0.06, 1.0)) / MUESTRAS
		ruido = lerpf(ruido, azar.randf_range(-1.0, 1.0), 0.3)
		b[i] = (sin(fase * TAU) * 0.6 + ruido * 0.15) * minf(t * 600.0, 1.0) * exp(-t * 35.0)
	return _a_wav(_eco(b, [31, 43], 0.3, 0.1, 0.2))


# Combinar: dos clacs, uno agudo y uno mas grave, como piezas que embonan
static func _inv_combinar() -> AudioStreamWAV:
	var b := _vacio(0.2)
	b = _mezclar(b, _clic(1100.0, 110.0, 0.55, 98), 0.0)
	b = _mezclar(b, _clic(700.0, 80.0, 0.65, 99), 0.08)
	b = _mezclar(b, _golpe_grave(90.0, 30.0, 0.25, 0.1), 0.08)
	return _a_wav(_eco(b, [29, 43], 0.35, 0.12, 0.22))


# Golpe grave: un seno de `frecuencia` Hz que se apaga segun `caida`, sin ataque duro
static func _golpe_grave(frecuencia: float, caida: float, volumen: float, duracion: float) -> PackedFloat32Array:
	var b := _vacio(duracion)
	for i in b.size():
		var t := float(i) / MUESTRAS
		b[i] = sin(TAU * frecuencia * t) * minf(t * 500.0, 1.0) * exp(-t * caida) * volumen
	return b
