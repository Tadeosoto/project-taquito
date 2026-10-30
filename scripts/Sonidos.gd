class_name Sonidos
extends RefCounted

# No hay archivos de audio en el juego: los sonidos cortos se arman en codigo y se
# guardan la primera vez que se piden.

const MUESTRAS := 22050

static var _sonidos := {}


static func sonido(nombre: String) -> AudioStreamWAV:
	if not _sonidos.has(nombre):
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
			"dolor":
				_sonidos[nombre] = _tono(190.0, 0.22, -70.0, 0.6)
			"gemido":
				_sonidos[nombre] = _tono(95.0, 0.7, -25.0, 0.45)
			"morir_zombi":
				_sonidos[nombre] = _tono(120.0, 0.6, -80.0, 0.6)
			"campana":
				_sonidos[nombre] = _tono(620.0, 1.6, -8.0, 0.4)
	return _sonidos[nombre]


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


static func _wav(datos: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MUESTRAS
	wav.data = datos
	return wav
