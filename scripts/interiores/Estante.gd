@tool
class_name Estante
extends Mostrador

# Muebles de pared de los interiores, armados de cajas como el Mostrador (de el saca
# las piezas, los empaques en MultiMesh y los letreros; su `estilo` no se usa aqui).
# Copian las fotos de referencia del usuario:
#   repisas   anaquel con niveles llenos de mercancia, marco de `color` y filo de
#             `color_filo`; con `texto`, cabecera de letrero (farmacia: azul con filo
#             amarillo y "NUEVOS PRODUCTOS")
#   ganchos   panel ranurado de `color` de ferreteria con herramientas y blisters colgados
#             (con `colgar`, piezas de modelo: herramientas, machetes, bates, cintas)
#   colgados  tiras de bolsas de papitas colgando (abarrotes)
#   rejilla   exhibidor de papitas de alambre de `color` (el rojo de las tiendas):
#             canastillas inclinadas al frente con filo de `color_filo` y carita,
#             bolsas paradas recargadas atras y letrero arriba; la primera linea de
#             `texto` va en la franja roja, las demas en la parte de `color_letrero`
# La mercancia lleva etiquetas de textures/interiores/empaques.png (la fila de su
# `mercancia`), las herramientas sueltas solo su color; con `con_modelos` las repisas
# llevan piezas del paquete de comida (Mostrador.PIEZAS_DE). Las papitas de la rejilla
# y las colgadas son siempre las bolsas de ese paquete (si esta).
# El origen es el centro de su base y el frente ve a +Z.

# Mangos de las herramientas colgadas (sin etiqueta)
const HERRAMIENTAS := [Color(0.95, 0.8, 0.1), Color(0.2, 0.45, 0.85), Color(0.85, 0.2, 0.15),
	Color(0.2, 0.6, 0.3), Color(0.95, 0.55, 0.1), Color(0.12, 0.12, 0.12)]

@export_enum("repisas", "ganchos", "colgados", "rejilla") var tipo := 0:
	set(valor):
		tipo = valor
		_reconstruir()
@export var color_filo := Color(0.95, 0.95, 0.92):
	set(valor):
		color_filo = valor
		_reconstruir()
@export_enum("botanas", "abarrotes", "medicinas", "herramientas") var mercancia := 0:
	set(valor):
		mercancia = valor
		_reconstruir()
@export var niveles := 6:
	set(valor):
		niveles = valor
		_reconstruir()
@export var color_letrero := Color(0.95, 0.8, 0.1):
	set(valor):
		color_letrero = valor
		_reconstruir()
# Ganchos: categorias de piezas (Mostrador.piezas: herramienta, machete, bate,
# cinta...) que cuelgan de los ganchos en vez de blisters y herramientas de cajitas
@export var colgar := PackedStringArray():
	set(valor):
		colgar = valor
		_reconstruir()
# Fraccion de mercancia que queda (rejilla): 1 lleno, 0 vacio
@export_range(0.0, 1.0) var surtido := 1.0:
	set(valor):
		surtido = valor
		_reconstruir()


func _armar() -> void:
	match tipo:
		0: _repisas()
		1: _ganchos()
		2: _colgados()
		3: _rejilla()


func _repisas() -> void:
	var z := fondo / 2
	var marco := _ps1(color)
	var filo := _ps1(color_filo)
	var cabecera := 0.35 if texto != "" else 0.0
	var hueco := alto - cabecera
	_caja(Vector3(ancho, hueco, 0.03), Vector3(0, hueco / 2, -z + 0.015), _ps1(color.lightened(0.15)))
	for signo in [-1.0, 1.0]:
		_caja(Vector3(0.05, alto, fondo), Vector3(signo * (ancho / 2 - 0.025), alto / 2, 0), marco)
	_caja(Vector3(ancho, 0.12, fondo), Vector3(0, 0.06, 0), marco)
	var paso := (hueco - 0.14) / niveles
	for i in niveles:
		var y := 0.12 + paso * i
		_caja(Vector3(ancho - 0.1, 0.02, fondo - 0.03), Vector3(0, y, 0), marco)
		_caja(Vector3(ancho - 0.1, 0.05, 0.012), Vector3(0, y + 0.01, z - 0.005), filo)
		if con_modelos and (not categorias.is_empty() or PIEZAS_DE.has(mercancia)):
			var cosas: Array = Array(categorias) if not categorias.is_empty() else PIEZAS_DE[mercancia]
			_fila_modelos(y + 0.01, ancho - 0.16, Vector2(-z + 0.1, z - 0.1), paso * 0.85, cosas)
		else:
			_fila(y + 0.01, ancho - 0.16, Vector2(-z + 0.08, z - 0.08), Vector2(paso * 0.45, paso * 0.8), 0.11, mercancia)
	_caja(Vector3(ancho, 0.03, fondo), Vector3(0, hueco, 0), marco)
	if cabecera > 0.0:
		var centro := Vector3(0, hueco + cabecera / 2, z - 0.02)
		_caja(Vector3(ancho, cabecera, 0.04), centro, _plano(color_letrero))
		_caja(Vector3(ancho + 0.01, 0.04, 0.05), centro + Vector3(0, cabecera / 2 - 0.02, 0), marco)
		_letrero(texto, centro + Vector3(0, 0, 0.025), ancho * 0.85, color.darkened(0.4))


# Panel ranurado de `color` (ranuras mas oscuras cada 10 cm) con hileras de ganchos; de cada gancho
# cuelga un blister de carton de color o una herramienta (mango de color y fierro)
func _ganchos() -> void:
	_caja(Vector3(ancho, alto, 0.04), Vector3(0, alto / 2, 0), _ps1(color))
	var ranura := _ps1(color.darkened(0.35))
	var y := 0.1
	while y < alto - 0.05:
		_caja(Vector3(ancho, 0.012, 0.01), Vector3(0, y, 0.021), ranura)
		y += 0.1
	var colgables := []
	for categoria in colgar:
		colgables.append_array(Mostrador.piezas(categoria))
	if not colgables.is_empty():
		_colgar_modelos(colgables)
		return
	var fierro := Color(0.55, 0.56, 0.58)
	var colores := HERRAMIENTAS
	var fila_y := alto - 0.2
	while fila_y > 0.5:
		var x := -ancho / 2 + 0.1
		var tinte: Color = colores[_rng.randi() % colores.size()]
		var etiqueta := 0
		var bloque := 0
		while x < ancho / 2 - 0.1:
			if bloque == 0:
				bloque = _rng.randi_range(2, 5)
				tinte = colores[_rng.randi() % colores.size()]
				etiqueta = _etiqueta(FERRETERIA)
			bloque -= 1
			# Gancho
			_empaques.append([Vector3(x, fila_y, 0.1), Vector3(0.008, 0.008, 0.16), fierro])
			if _rng.randf() < 0.12:
				x += 0.1
				continue
			if _rng.randf() < 0.55:
				# Blister: carton con su etiqueta (la pieza viene dibujada en su burbuja)
				_empaques.append([Vector3(x, fila_y - 0.1, 0.06), Vector3(0.09, 0.13, 0.015), Color.WHITE, etiqueta])
				x += 0.11
			else:
				# Herramienta: mango arriba, fierro abajo
				var largo := _rng.randf_range(0.14, 0.24)
				_empaques.append([Vector3(x, fila_y - 0.05, 0.06), Vector3(0.03, 0.09, 0.03), tinte])
				_empaques.append([Vector3(x, fila_y - 0.09 - largo / 2, 0.06), Vector3(0.015, largo, 0.012), fierro])
				x += 0.07
		fila_y -= 0.32


# Hileras de ganchos con piezas de modelo colgadas por arriba, varias iguales seguidas;
# las hileras se separan lo que mide la pieza mas larga (machetes y bates: dos)
func _colgar_modelos(colgables: Array) -> void:
	var fierro := Color(0.55, 0.56, 0.58)
	var largo_max := 0.0
	for malla in colgables:
		largo_max = maxf(largo_max, malla.get_aabb().size.y)
	var fila_y := alto - 0.12
	while fila_y - largo_max > 0.3:
		var x := -ancho / 2 + 0.08
		var bloque := 0
		var malla: Mesh
		while true:
			if bloque == 0:
				bloque = _rng.randi_range(2, 4)
				malla = colgables[_rng.randi() % colgables.size()]
			var caja := malla.get_aabb()
			var paso := caja.size.x + 0.05
			if x + paso > ancho / 2 - 0.05:
				break
			bloque -= 1
			var centro := x + paso / 2
			_empaques.append([Vector3(centro, fila_y, 0.1), Vector3(0.008, 0.008, 0.16), fierro])
			# Algun gancho vacio, ya se vendio
			if _rng.randf() >= 0.1:
				var giro := Basis(Vector3.FORWARD, _rng.randf_range(-0.05, 0.05))
				_modelo(malla, Transform3D(giro, Vector3(centro, fila_y - 0.015 - caja.size.y, 0.03 + caja.size.z / 2)))
			x += paso
		fila_y -= largo_max + 0.12


# Tiras de bolsas de papitas, de un mismo producto cada tira, colgadas de un tubo
func _colgados() -> void:
	_caja(Vector3(ancho, 0.025, 0.025), Vector3(0, alto, 0), _ps1(Color(0.5, 0.5, 0.52)))
	var tiras := maxi(1, int(ancho / 0.2))
	var cordon := Color(0.85, 0.85, 0.85)
	# Las bolsas del paquete de comida; sin el, cajas con etiqueta
	var papas := Mostrador.piezas("papas")
	for t in tiras:
		var x := -ancho / 2 + ancho * (t + 0.5) / tiras
		var etiqueta := _etiqueta(BOTANAS)
		var bolsa: Mesh = papas[_rng.randi() % papas.size()] if not papas.is_empty() else null
		_empaques.append([Vector3(x, alto / 2, 0), Vector3(0.01, alto, 0.01), cordon])
		var y := alto - 0.15
		while y > 0.15:
			# Bolsas un poco chuecas y de lado a lado
			var pos := Vector3(x + _rng.randf_range(-0.02, 0.02), y, _rng.randf_range(0.0, 0.03))
			if bolsa:
				var escala := 0.18 / bolsa.get_aabb().size.y
				var giro := Basis(Vector3.FORWARD, _rng.randf_range(-0.1, 0.1)).scaled(Vector3.ONE * escala)
				_modelo(bolsa, Transform3D(giro, pos - Vector3(0, 0.09, 0)))
			else:
				_empaques.append([pos, Vector3(0.13, 0.18, 0.04), Color.WHITE, etiqueta])
			y -= _rng.randf_range(0.15, 0.19)


# Exhibidor de papitas: postes atras, `niveles` canastillas de alambre inclinadas al
# frente (la de abajo casi en el piso) y letrero arriba. Alambres y bolsas van como
# empaques con giro (un solo MultiMesh)
func _rejilla() -> void:
	var alambre := color
	var grueso := 0.008
	var cabecera := 0.38
	var postes := alto - cabecera
	var atras := -fondo / 2 - 0.02
	# Postes, patas y travesanos del piso
	for signo in [-1.0, 1.0]:
		var x: float = signo * (ancho / 2 - 0.04)
		_empaques.append([Vector3(x, postes / 2, atras), Vector3(0.022, postes, 0.022), alambre])
		_empaques.append([Vector3(x, 0.01, 0.0), Vector3(0.025, 0.02, fondo + 0.1), alambre])
	for z in [atras, fondo / 2]:
		_empaques.append([Vector3(0, 0.012, z), Vector3(ancho, 0.015, 0.015), alambre])
	# Canastillas
	var inclinacion := deg_to_rad(14.0)
	var abajo := 0.1
	var arriba := postes - 0.28
	var paso := (arriba - abajo) / maxi(niveles - 1, 1)
	for i in niveles:
		var y := abajo + paso * i + sin(inclinacion) * fondo / 2
		_canastilla(Transform3D(Basis(Vector3.RIGHT, inclinacion), Vector3(0, y, 0)), alambre, grueso, paso)
	# Letrero: franja de `color` arriba con la marca y abajo `color_letrero` con el lema
	# y la carita
	var renglones := texto.split("\n")
	var base := Vector3(0, postes + cabecera / 2, atras)
	var franja := cabecera * 0.38
	_caja(Vector3(ancho + 0.06, cabecera, 0.02), base, _plano(color_letrero))
	_caja(Vector3(ancho + 0.07, franja, 0.025), base + Vector3(0, (cabecera - franja) / 2, 0), _plano(color.darkened(0.05)))
	if renglones[0] != "":
		_letrero(renglones[0], base + Vector3(ancho * 0.12, (cabecera - franja) / 2, 0.02), ancho * 0.6, Color(1, 0.95, 0.85))
	if renglones.size() > 1:
		var lema := "\n".join(renglones.slice(1))
		_letrero(lema, base + Vector3(ancho * 0.14, -franja / 2, 0.02), ancho * 0.6, color.darkened(0.25))
	_carita(base + Vector3(-ancho * 0.3, -0.02, 0.016), cabecera * 0.36)


# Una canastilla en `xform` (centro del piso, frente +Z ya inclinado hacia abajo):
# varillas del piso, barandal a los lados y atras, filo de color con carita y las
# bolsas paradas en tres filas, en bloques del mismo producto
func _canastilla(xform: Transform3D, alambre: Color, grueso: float, paso: float) -> void:
	var giro := xform.basis
	var f := fondo / 2
	var a := ancho / 2 - 0.02
	var pieza := func(centro: Vector3, tam: Vector3, tinte: Color, etiqueta := -1, local := Basis()) -> void:
		_empaques.append([xform * centro, tam, tinte, etiqueta, giro * local])
	var x := -a
	while x <= a + 0.001:
		pieza.call(Vector3(x, 0, 0), Vector3(grueso, grueso, fondo), alambre)
		x += 0.07
	for z in [-f, 0.0, f]:
		pieza.call(Vector3(0, 0, z), Vector3(ancho - 0.04, grueso, grueso), alambre)
	var barandal := minf(0.14, paso * 0.5)
	for signo in [-1.0, 1.0]:
		for h in [barandal * 0.5, barandal]:
			pieza.call(Vector3(signo * a, h, 0), Vector3(grueso, grueso, fondo), alambre)
		for z in [-f, f]:
			pieza.call(Vector3(signo * a, barandal / 2, z), Vector3(grueso, barandal, grueso), alambre)
	for h in [barandal * 0.6, barandal * 1.3]:
		pieza.call(Vector3(0, h, -f), Vector3(ancho - 0.04, grueso, grueso), alambre)
	pieza.call(Vector3(0, 0.025, f + 0.008), Vector3(ancho - 0.02, 0.045, 0.01), color_filo)
	_carita(xform * Vector3(0, 0.025, f + 0.016), 0.018)
	# Bolsas: chuecas y recargadas atras; enfrente se acaban primero
	var bolsa := Vector3(0.135, minf(0.25, paso * 1.05), 0.045)
	var papas := Mostrador.piezas("papas")
	var ancho_bolsa := 0.145
	if not papas.is_empty():
		var caja: AABB = papas[0].get_aabb()
		ancho_bolsa = caja.size.x * bolsa.y / caja.size.y + 0.008
	var columnas := maxi(1, int((ancho - 0.06) / ancho_bolsa))
	var bloque := 0
	var etiqueta := 0
	var modelo: Mesh
	for c in columnas:
		if bloque == 0:
			bloque = _rng.randi_range(1, 3)
			etiqueta = _etiqueta(BOTANAS)
			if not papas.is_empty():
				modelo = papas[_rng.randi() % papas.size()]
		bloque -= 1
		var bx := -(columnas - 1) * ancho_bolsa / 2 + c * ancho_bolsa
		for fila in 3:
			var queda := surtido * (0.85 if fila == 2 else 1.0)
			if _rng.randf() > queda:
				continue
			var z := -f + 0.06 + fila * (fondo - 0.12) / 2
			var recargada := Basis(Vector3.RIGHT, -0.35 + _rng.randf_range(-0.08, 0.08)) \
				* Basis(Vector3.FORWARD, _rng.randf_range(-0.08, 0.08))
			var centro := Vector3(bx + _rng.randf_range(-0.01, 0.01), bolsa.y * 0.45, z)
			if modelo:
				# La pieza tiene el origen en su base
				var escala := bolsa.y / modelo.get_aabb().size.y
				var base := centro - recargada * Vector3(0, bolsa.y / 2, 0)
				_modelo(modelo, Transform3D(giro * recargada.scaled(Vector3.ONE * escala), xform * base))
			else:
				pieza.call(centro, bolsa, Color.WHITE.darkened(0.15 * (2 - fila) / 2.0), etiqueta, recargada)


# Carita de la marca (inventada): circulo blanco con orilla oscura, cachetes rojos y
# sonrisa
func _carita(pos: Vector3, radio: float) -> void:
	_disco(radio * 1.15, pos, Color(0.25, 0.12, 0.08))
	_disco(radio, pos + Vector3(0, 0, 0.002), Color(1, 1, 0.97))
	for signo in [-1.0, 1.0]:
		_disco(radio * 0.22, pos + Vector3(signo * radio * 0.5, -radio * 0.1, 0.004), Color(0.9, 0.2, 0.15))
		_disco(radio * 0.1, pos + Vector3(signo * radio * 0.3, radio * 0.3, 0.004), Color(0.15, 0.08, 0.05))
	var boca := _plano(Color(0.15, 0.08, 0.05))
	for i in 7:
		var angulo := lerpf(-1.0, 1.0, i / 6.0)
		_caja(Vector3(radio * 0.16, radio * 0.12, 0.002), pos + Vector3(sin(angulo) * radio * 0.5, -cos(angulo) * radio * 0.5, 0.004), boca)
