extends SceneTree

# Dibuja el atlas de la maquinita de frutas (scripts/map/Maquinita.gd), sin fotos.
#   godot --path . --headless -s tools/map_import/make_maquinita.gd
# Despues: godot --path . --headless --import
# Los numeros de los contadores los dibuja ps1_maquinita.gdshader; aqui solo sus ventanas.

const SALIDA := "res://textures/map/maquinita.png"
# Alfa menor a 0.75 = es foquito (LED): ps1_maquinita lo prende solo
const LED := 0.5
const ROJO_LED := Color(1.0, 0.1, 0.05, LED)

const LETRAS := {
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
	"C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
	"I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
	"N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
	"0": ["01110", "10011", "10101", "10101", "10101", "11001", "01110"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
	"3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	"5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
	"7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
}

var img: Image


func _initialize() -> void:
	# Las frutas primero: el tablero y los botones las copian
	img = Image.create_empty(256, 32, false, Image.FORMAT_RGBA8)
	for i in Tragamonedas.FRUTAS.size():
		_fruta(Tragamonedas.FRUTAS[i], i * 32 + 16, 16)
	var frutas := img
	var frutas_grandes: Image = frutas.duplicate()
	frutas_grandes.resize(320, 40, Image.INTERPOLATE_NEAREST)

	img = Image.create_empty(int(Maquinita.ATLAS), int(Maquinita.ATLAS), false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	_panel(frutas, frutas_grandes)
	_botones(frutas)
	_abajo(frutas)
	_charola()
	_cuerpo()
	_muestras()
	img.save_png(SALIDA)
	print("escrito: ", SALIDA)
	quit()


# --- El panel de arriba, de arriba a abajo como la foto: nombre, contadores, tablero y
# la hilera de apuestas, todo con su orilla de LEDs rojos
func _panel(frutas: Image, frutas_grandes: Image) -> void:
	var r: Rect2i = Maquinita.PANEL
	_degradado(r, Color(0.1, 0.38, 0.85), Color(0.75, 0.9, 1.0))
	for nube in [[42, 300, 22], [20, 340, 30], [440, 330, 24], [462, 290, 18], [34, 420, 18], [448, 440, 20]]:
		_circulo(nube[0], nube[1], nube[2], Color(1, 1, 1))
	_texto("COCTEL DE FRUTAS", 96, 52, 3, Color(1.0, 0.88, 0.1))
	_texto("PREMIOS", 100, 96, 2, Color.WHITE)
	_texto("CREDITOS", 292, 96, 2, Color.WHITE)
	for ventana: Rect2i in [Maquinita.CONTADOR_PREMIOS, Maquinita.CONTADOR_CREDITOS]:
		_rect(ventana.grow(3), Color(0.35, 0.3, 0.1))
		_rect(ventana, Color(0.07, 0.0, 0.0))
	# Tablero: 7 x 7 casillas, la orilla son los 24 focos
	var x0: int = Maquinita.TABLERO_ORIGEN.x
	var y0: int = Maquinita.TABLERO_ORIGEN.y
	var c: int = Maquinita.TABLERO_CASILLA
	_rect(Rect2i(x0 - 3, y0 - 3, c * 7 + 6, c * 7 + 6), Color(0.05, 0.05, 0.08))
	_rect(Rect2i(x0 + c, y0 + c, c * 5, c * 5), Color(0.1, 0.1, 0.32))
	for i in Tragamonedas.TABLERO.size():
		var celda := Maquinita.celda_foco(i)
		var caja := Rect2i(x0 + celda.x * c + 1, y0 + celda.y * c + 1, c - 2, c - 2)
		_rect(caja, Color(0.96, 0.92, 0.72))
		var indice := Tragamonedas.FRUTAS.find(Tragamonedas.TABLERO[i])
		img.blend_rect(frutas_grandes, Rect2i(indice * 40, 0, 40, 40), caja.position + Vector2i(1, 1))
	_fresa(x0 + c * 3 + c / 2, y0 + c * 3 + 6, 58)
	# Hilera de apuestas: contador, fruta y cuanto paga
	_rect(Rect2i(30, 484, 420, 112), Color(0.08, 0.1, 0.3))
	for i in Tragamonedas.FRUTAS.size():
		var x := Maquinita.APUESTA_X + i * Maquinita.APUESTA_COLUMNA
		_rect(Rect2i(x + 7, Maquinita.APUESTA_Y - 2, 36, Maquinita.APUESTA_LADO + 4), Color(0.07, 0.0, 0.0))
		img.blend_rect(frutas, Rect2i(i * 32, 0, 32, 32), Vector2i(x + 9, Maquinita.APUESTA_Y + 36))
		var paga := "X%d" % Tragamonedas.MULTIPLICADORES[Tragamonedas.FRUTAS[i]]
		_texto(paga, x + 25 - paga.length() * 6, Maquinita.APUESTA_Y + 70, 2, Color(1.0, 0.88, 0.1))
	# LEDs por la orilla, siguiendo la curva de arriba
	for x in range(14, 468, 15):
		var u := (x - 240.0) / 240.0
		_rect(Rect2i(x, int(Maquinita.CURVA_PANEL_PX * u * u) + 12, 7, 7), ROJO_LED)
		_rect(Rect2i(x, 624, 7, 7), ROJO_LED)
	for y in range(int(Maquinita.CURVA_PANEL_PX) + 14, 626, 15):
		_rect(Rect2i(12, y, 7, 7), ROJO_LED)
		_rect(Rect2i(461, y, 7, 7), ROJO_LED)


# --- Tablero inclinado: la fruta abajo de su boton, y lo que hacen los de arriba
func _botones(frutas: Image) -> void:
	var r: Rect2i = Maquinita.BOTONES
	_degradado(r, Color(0.16, 0.42, 0.85), Color(0.08, 0.22, 0.6))
	for i in 8:
		var centro := _px_boton(r, Maquinita.boton_centro(i))
		img.blend_rect(frutas, Rect2i(i * 32, 0, 32, 32), Vector2i(centro.x - 16, r.end.y - 36))
	for par in [[Maquinita.BOTON_TIRAR, "TIRAR"], [Maquinita.BOTON_QUITAR, "QUITAR"], [Maquinita.BOTON_SALIR, "SALIR"]]:
		var centro := _px_boton(r, Maquinita.boton_centro(par[0]))
		var texto: String = par[1]
		_texto(texto, centro.x - texto.length() * 6, r.position.y + 6, 2, Color.WHITE)


# Del centro de un boton en el tablero (m a lo ancho, m hacia arriba de la rampa) a px
func _px_boton(r: Rect2i, centro: Vector2) -> Vector2i:
	return Vector2i(r.position.x + int((centro.x / Maquinita.ANCHO + 0.5) * r.size.x), r.end.y - int(centro.y / Maquinita.RAMPA * r.size.y))


# --- Panel de abajo: la fresa grande, frutas y el monedero
func _abajo(frutas: Image) -> void:
	var r: Rect2i = Maquinita.ABAJO
	_degradado(r, Color(0.98, 0.75, 0.15), Color(0.85, 0.15, 0.2))
	_fresa(r.position.x + 170, r.position.y + 110, 74)
	for i in 8:
		img.blend_rect(frutas, Rect2i(i * 32, 0, 32, 32), Vector2i(r.position.x + 10 + i * 40, r.end.y - 44))
	_texto("COCTEL", r.position.x + 40, r.position.y + 220, 5, Color.WHITE)
	# El monedero
	var mx := r.position.x + 350
	var my := r.position.y + 50
	_rect(Rect2i(mx, my, 110, 150), Color(0.45, 0.46, 0.48))
	_rect(Rect2i(mx + 6, my + 6, 98, 138), Color(0.68, 0.69, 0.7))
	_rect(Rect2i(mx + 50, my + 18, 6, 40), Color(0.05, 0.05, 0.05))
	_circulo(mx + 54, my + 100, 22, Color(0.25, 0.25, 0.27))
	_circulo(mx + 54, my + 100, 15, Color(0.82, 0.82, 0.84))


func _charola() -> void:
	var r: Rect2i = Maquinita.CHAROLA
	_degradado(r, Color(0.2, 0.5, 0.9), Color(0.1, 0.25, 0.65))
	_texto("COCTEL DE FRUTAS", r.position.x + 32, r.position.y + 22, 2, Color(1.0, 0.88, 0.1))


# El color del gabinete se pone al dibujar (instancia); aqui solo el desgaste
func _cuerpo() -> void:
	var r: Rect2i = Maquinita.CUERPO
	var azar := RandomNumberGenerator.new()
	azar.seed = 7
	for y in r.size.y:
		for x in r.size.x:
			var v := 0.92 + azar.randf() * 0.08
			img.set_pixel(r.position.x + x, r.position.y + y, Color(v, v, v))


# --- Colores de los botones, el dorado, las monedas y lo de la veladora
func _muestras() -> void:
	for par in [[Maquinita.COLOR_VERDE, Color(0.1, 0.85, 0.2)], [Maquinita.COLOR_NARANJA, Color(1.0, 0.5, 0.05)],
			[Maquinita.COLOR_AZUL, Color(0.1, 0.35, 1.0)], [Maquinita.COLOR_ROJO, Color(1.0, 0.08, 0.05)]]:
		var r: Rect2i = par[0]
		_rect(r, (par[1] as Color).darkened(0.25))
		_rect(r.grow(-8), par[1])
		_rect(r.grow(-20), (par[1] as Color).lightened(0.4))
	_degradado(Maquinita.COLOR_DORADO, Color(0.95, 0.8, 0.35), Color(0.6, 0.42, 0.1))
	_rect(Maquinita.COLOR_MONEDA, Color(0.8, 0.75, 0.55))
	_rect(Maquinita.COLOR_MONEDA.grow(-10), Color(0.92, 0.86, 0.62))
	_rect(Maquinita.COLOR_METAL, Color(0.55, 0.56, 0.58))
	# El vaso de la veladora: rojo con franja blanca
	var v: Rect2i = Maquinita.COLOR_VELA
	_degradado(v, Color(0.95, 0.15, 0.1), Color(0.6, 0.05, 0.05))
	_rect(Rect2i(v.position.x, v.position.y + 22, v.size.x, 20), Color(0.95, 0.92, 0.8))
	# La estampita: una figura con manto y aureola, sin ser ningun santo en particular
	var e: Rect2i = Maquinita.ESTAMPA
	_rect(e, Color(0.9, 0.85, 0.65))
	_rect(e.grow(-4), Color(0.25, 0.4, 0.75))
	var cx := e.position.x + e.size.x / 2
	_circulo(cx, e.position.y + 28, 16, Color(1.0, 0.85, 0.2))
	_circulo(cx, e.position.y + 28, 9, Color(0.9, 0.72, 0.58))
	_elipse(cx, e.position.y + 66, 18, 26, Color(0.8, 0.2, 0.25))


# --- La fresa de la maquinita: cara de monito
func _fresa(cx: int, cy: int, radio: int) -> void:
	_elipse(cx, cy, radio, int(radio * 1.15), Color(0.5, 0.03, 0.05))
	_elipse(cx, cy, radio - maxi(radio / 12, 1), int(radio * 1.15) - maxi(radio / 12, 1), Color(0.88, 0.1, 0.12))
	var hojas := Color(0.15, 0.6, 0.15)
	for i in 5:
		var x := cx + (i - 2) * radio / 3
		_elipse(x, cy - radio + radio / 16, radio / 4, radio / 3, hojas)
	# Semillas
	for s in [[-0.6, 0.35], [0.6, 0.35], [-0.3, 0.75], [0.3, 0.75], [0.0, 0.95], [-0.75, -0.2], [0.75, -0.2]]:
		_circulo(cx + int(s[0] * radio), cy + int(s[1] * radio), maxi(radio / 18, 1), Color(1.0, 0.9, 0.45))
	# Ojos y sonrisa
	var ojo := maxi(radio / 4, 2)
	for lado in [-1, 1]:
		_circulo(cx + lado * radio / 3, cy - radio / 5, ojo, Color.WHITE)
		_circulo(cx + lado * radio / 3, cy - radio / 6, maxi(ojo / 2, 1), Color.BLACK)
	for i in range(-radio / 3, radio / 3 + 1):
		var t := float(i) / maxf(radio / 3.0, 1.0)
		var y := cy + radio / 4 + int((1.0 - t * t) * radio / 4.0)
		_rect(Rect2i(cx + i, y, maxi(radio / 18, 1), maxi(radio / 18, 1)), Color(0.15, 0, 0))


# --- Los 8 iconos, de 32 px
func _fruta(fruta: String, x: int, y: int) -> void:
	match fruta:
		"MANZANA":
			_circulo(x, y + 2, 11, Color(0.45, 0.02, 0.03))
			_circulo(x, y + 2, 10, Color(0.88, 0.1, 0.1))
			_circulo(x - 4, y - 2, 3, Color(1.0, 0.6, 0.55))
			_rect(Rect2i(x - 1, y - 13, 2, 6), Color(0.35, 0.2, 0.08))
			_elipse(x + 5, y - 10, 5, 2, Color(0.2, 0.65, 0.15))
		"NARANJA":
			_circulo(x, y + 1, 12, Color(0.6, 0.28, 0.0))
			_circulo(x, y + 1, 11, Color(1.0, 0.55, 0.05))
			_circulo(x - 4, y - 3, 3, Color(1.0, 0.82, 0.45))
			_elipse(x + 3, y - 11, 4, 2, Color(0.2, 0.6, 0.15))
		"CEREZA":
			_linea(Vector2(x - 6, y + 2), Vector2(x + 3, y - 12), Color(0.2, 0.5, 0.1))
			_linea(Vector2(x + 7, y + 3), Vector2(x + 3, y - 12), Color(0.2, 0.5, 0.1))
			for lado in [-6, 7]:
				_circulo(x + lado, y + 6, 7, Color(0.4, 0.0, 0.08))
				_circulo(x + lado, y + 6, 6, Color(0.82, 0.05, 0.15))
				_circulo(x + lado - 2, y + 4, 2, Color(1.0, 0.55, 0.6))
		"CAMPANA":
			_circulo(x, y - 4, 8, Color(0.98, 0.78, 0.1))
			_rect(Rect2i(x - 8, y - 4, 16, 9), Color(0.98, 0.78, 0.1))
			_rect(Rect2i(x - 12, y + 5, 24, 4), Color(0.85, 0.55, 0.05))
			_circulo(x, y + 11, 3, Color(0.6, 0.35, 0.02))
			_circulo(x - 3, y - 6, 2, Color(1.0, 0.97, 0.7))
		"MELON":
			_elipse(x, y, 13, 10, Color(0.65, 0.65, 0.15))
			_elipse(x, y, 12, 9, Color(0.82, 0.86, 0.4))
			for i in [-7, -2, 3, 8]:
				_rect(Rect2i(x + i, y - 8, 1, 16), Color(0.4, 0.55, 0.12))
		"SANDIA":
			for i in range(-13, 14):
				var alto := int(sqrt(169.0 - i * i))
				_rect(Rect2i(x + i, y - 4, 1, alto + 2), Color(0.1, 0.5, 0.15))
				if absi(i) <= 11:
					_rect(Rect2i(x + i, y - 4, 1, maxi(alto - 2, 0)), Color(0.92, 0.15, 0.2))
			for s in [[-6, 0], [0, 2], [6, 0], [-3, -2], [3, -2]]:
				_rect(Rect2i(x + s[0], y + s[1], 2, 2), Color.BLACK)
		"SIETE":
			_rect(Rect2i(x - 10, y - 12, 20, 6), Color(0.85, 0.05, 0.05))
			for i in 18:
				_rect(Rect2i(x + 6 - int(i * 0.75), y - 6 + i, 6, 2), Color(0.85, 0.05, 0.05))
		"BAR":
			_rect(Rect2i(x - 14, y - 8, 28, 16), Color.BLACK)
			_rect(Rect2i(x - 13, y - 7, 26, 14), Color(0.12, 0.12, 0.12))
			_texto("BAR", x - 10, y - 4, 1, Color(1.0, 0.85, 0.1))


# --- Herramientas de dibujo
func _rect(r: Rect2i, c: Color) -> void:
	var dentro := r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if dentro.has_area():
		img.fill_rect(dentro, c)


func _circulo(cx: int, cy: int, radio: int, c: Color) -> void:
	_elipse(cx, cy, radio, radio, c)


func _elipse(cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for y in range(-ry, ry + 1):
		var ancho := int(rx * sqrt(maxf(1.0 - float(y * y) / float(maxi(ry * ry, 1)), 0.0)))
		_rect(Rect2i(cx - ancho, cy + y, ancho * 2 + 1, 1), c)


func _linea(a: Vector2, b: Vector2, c: Color) -> void:
	var pasos := int(a.distance_to(b)) + 1
	for i in pasos + 1:
		var p := a.lerp(b, float(i) / pasos)
		_rect(Rect2i(int(p.x), int(p.y), 2, 2), c)


func _degradado(r: Rect2i, arriba: Color, abajo: Color) -> void:
	for y in r.size.y:
		_rect(Rect2i(r.position.x, r.position.y + y, r.size.x, 1), arriba.lerp(abajo, float(y) / r.size.y))


func _texto(texto: String, x: int, y: int, escala: int, c: Color) -> void:
	for letra in texto:
		var filas: Array = LETRAS.get(letra, [])
		for fy in filas.size():
			for fx in 5:
				if filas[fy][fx] == "1":
					_rect(Rect2i(x + fx * escala, y + fy * escala, escala, escala), c)
		x += 6 * escala
