class_name FortalezasMapa
extends Node3D
## Las otras dos fortalezas y las cinco defensas del tinaco en el mapa completo (docs/mapa/zona-enfoque.md).
## Santa Mugre tiene su propio muro (MuroColonia); aqui van:
## - Los Reservorios (GelA): barda alrededor del ITESO de OSM, recortado en la orilla norte del mapa,
##   con una caseta y su pluma (cerrada) en la avenida de arriba.
## - La Gotera: en Haciendas de San Jodido (docs/mapa/colonias/la_gotera.md), por las calles para no partir
##   casas: la barda va por la banqueta poniente de la Av. del Cedro (la avenida queda adentro), la del norte
##   por la banqueta sur de Primavera, la del sur por la banqueta norte de Nogal y la del oriente por la orilla
##   del mapa. Una reja cerrada donde la avenida sale por el norte y por el sur. Todavia no se entra: por dentro
##   siguen las casas de map_test hasta que se haga la colonia en Blender.
## - Los cinco tinacos de la defensa (SitiosTinaco: solo el tinaco, sin barricada; Chava los ofrece de dia y
##   la defensa es la escena defensa_tinaco).
## Todo choca en la capa 1, como las casas y el muro de Santa Mugre.

const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")
const MODELO_TINACO := preload("res://models/props/tinaco/tinaco.scn")

## Vertices (x, z) de la barda de GelA: el poligono "ITESO" de OSM; el ultimo tramo corre por la orilla norte
const GELA := [
	Vector2(279.0, -897.5), Vector2(278.4, -651.4), Vector2(-75.1, -749.9), Vector2(-103.8, -760.3),
	Vector2(-166.9, -777.5), Vector2(-318.3, -828.1), Vector2(-432.8, -787.1), Vector2(-459.9, -846.9),
	Vector2(-473.7, -897.5),
]
const GELA_ALTO := 3.6
const GELA_COLOR := Color(0.86, 0.87, 0.88)
## La caseta, sobre el tramo de la avenida (GELA[1] a GELA[2]): centro del hueco y su ancho
const CASETA := Vector2(-50.0, -742.9)
const CASETA_HUECO := 7.0

## Vertices (x, z) de la barda de La Gotera: las calles de OSM corridas BANQUETA m hacia afuera de su eje.
## De la esquina noroeste baja por la Av. del Cedro, sigue al oriente por Nogal, sube por la orilla del mapa
## y regresa por Primavera
const GOTERA := [
	Vector2(722.9, -341.5), Vector2(720.4, -309.9), Vector2(717.4, -273.0), Vector2(714.3, -235.2),
	Vector2(713.4, -224.0), Vector2(710.0, -182.8), Vector2(707.1, -146.9), Vector2(704.4, -113.9),
	Vector2(709.9, -113.4), Vector2(790.8, -106.4), Vector2(914.0, -95.7), Vector2(914.0, -324.1),
	Vector2(811.5, -333.4), Vector2(728.4, -341.0),
]
const BANQUETA := 5.5        # m del eje de la calle a la barda: media calle de 7 m y la banqueta
const GOTERA_ALTO := 3.2
const GOTERA_COLOR := Color(0.5, 0.5, 0.47)
## Donde sale la Av. del Cedro: centro (x, z) de cada reja (el eje de la avenida), su rumbo y su largo
const GOTERA_REJAS := [
	[Vector2(728.4, -341.0), Vector2(0.9959, 0.0909), 2.0 * BANQUETA],
	[Vector2(709.9, -113.5), Vector2(0.996, 0.0895), 2.0 * BANQUETA],
]
## Lo que se cierra a los carros (CallesRuta solo cierra rectangulos): de la avenida a la orilla, entre
## Primavera y Nogal
const GOTERA_CALLES := Rect2(704.0, -324.0, 210.0, 210.0)

const TINACO_ALTO := 2.8                # Barricada.TINACO_ALTO
const TINACO_PIEZAS := ["Tinaco_3er_capa", "Bomba_1", "Tapa"]   # Barricada.TINACO_PIEZAS

const GRUESO := 0.3
const COLOR_FIERRO := Color(0.12, 0.12, 0.13)

var _fierro: ShaderMaterial


func _enter_tree() -> void:
	# Los carros (CallesRuta) no cruzan La Gotera: sus rejas estan cerradas
	CallesRuta.cerrar(GOTERA_CALLES)


func _exit_tree() -> void:
	CallesRuta.abrir(GOTERA_CALLES)


func _ready() -> void:
	_fierro = _material(COLOR_FIERRO)
	_gela()
	_gotera()
	add_to_group("fortalezas")
	for sitio: Dictionary in SitiosTinaco.SITIOS:
		_tinaco(sitio["pos"])


# --- Los Reservorios ---

func _gela() -> void:
	var muro := _material(GELA_COLOR)
	var puntos: Array[Vector2] = []
	puntos.assign(GELA)
	_barda(puntos, true, [[CASETA, CASETA_HUECO]], GELA_ALTO, muro)
	_caseta(muro)


# La caseta de vigilancia a un lado del hueco, por fuera, y la pluma cerrada atravesada
func _caseta(muro: Material) -> void:
	var a: Vector2 = GELA[1]
	var b: Vector2 = GELA[2]
	var largo := (b - a).normalized()
	var afuera := Vector2(-largo.y, largo.x)
	if afuera.dot(_centro(GELA) - CASETA) > 0.0:
		afuera = -afuera
	var nodo := Node3D.new()
	nodo.name = "Caseta"
	nodo.position = Vector3(CASETA.x, 0.0, CASETA.y)
	nodo.rotation.y = atan2(largo.x, largo.y)
	add_child(nodo)
	# En local, +Z corre a lo largo de la barda y +X hacia afuera (o al reves: se voltea con `lado`)
	var lado := signf(Vector2(largo.y, -largo.x).dot(afuera))
	var cuarto := Vector3(lado * 2.2, 0.0, CASETA_HUECO / 2.0 + 1.6)
	_cuerpo(nodo, cuarto + Vector3(0.0, 1.3, 0.0), Vector3(2.6, 2.6, 2.4), muro)
	_cuerpo(nodo, cuarto + Vector3(0.0, 2.75, 0.0), Vector3(3.2, 0.2, 3.0), _material(Color(0.2, 0.35, 0.65)))
	# La pluma: brazo a rayas rojas y blancas a 1 m, de poste a poste; el choque cierra todo el hueco
	_caja(nodo, Vector3(0.3, 1.2, 0.3), Vector3(0.0, 0.6, CASETA_HUECO / 2.0 - 0.2), _fierro)
	var tramos := 7
	for i in tramos:
		var z := CASETA_HUECO / 2.0 - 0.4 - (CASETA_HUECO - 0.6) * (i + 0.5) / tramos
		var color := Color(0.8, 0.12, 0.1) if i % 2 == 0 else Color(0.92, 0.92, 0.9)
		_caja(nodo, Vector3(0.1, 0.1, (CASETA_HUECO - 0.6) / tramos), Vector3(0.0, 1.0, z), _material(color))
	_choque(nodo, Vector3(0.0, 1.0, 0.0), Vector3(GRUESO, 3.0, CASETA_HUECO))


# --- La Gotera ---

func _gotera() -> void:
	var puntos: Array[Vector2] = []
	puntos.assign(GOTERA)
	var huecos: Array = []
	for reja: Array in GOTERA_REJAS:
		huecos.append([reja[0], reja[2]])
	_barda(puntos, true, huecos, GOTERA_ALTO, _material(GOTERA_COLOR))
	for reja: Array in GOTERA_REJAS:
		_reja(reja[0], reja[1], reja[2], GOTERA_ALTO)


# --- Bardas ---

# Una barda por los `puntos`, con huecos ([centro, ancho]) donde caen sobre la linea de un tramo. Un hueco
# puede caer en una esquina y abarcar dos tramos: a cada uno le quita su parte
func _barda(puntos: Array[Vector2], cerrada: bool, huecos: Array, alto: float, material: Material) -> void:
	var n := puntos.size() if cerrada else puntos.size() - 1
	for i in n:
		var a := puntos[i]
		var b := puntos[(i + 1) % puntos.size()]
		var cortes: Array[Vector2] = []   # (desde, hasta) en metros sobre el tramo
		var largo := a.distance_to(b)
		var dir := (b - a) / largo
		for hueco: Array in huecos:
			var c: Vector2 = hueco[0]
			var t := (c - a).dot(dir)
			var desde_hueco := maxf(t - hueco[1] / 2.0, 0.0)
			var hasta_hueco := minf(t + hueco[1] / 2.0, largo)
			if absf((c - a).cross(dir)) < 1.0 and desde_hueco < hasta_hueco:
				cortes.append(Vector2(desde_hueco, hasta_hueco))
		cortes.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
		var desde := -GRUESO / 2.0   # cada tramo se pasa medio grueso para cerrar las esquinas
		for corte in cortes:
			if corte.x > desde:
				_pared(a + dir * desde, a + dir * corte.x, alto, material)
			desde = corte.y
		_pared(a + dir * desde, a + dir * (largo + GRUESO / 2.0), alto, material)


func _pared(a: Vector2, b: Vector2, alto: float, material: Material) -> void:
	var largo := a.distance_to(b)
	if largo < 0.05:
		return
	var dir := (b - a) / largo
	var centro := (a + b) / 2.0
	var nodo := Node3D.new()
	nodo.position = Vector3(centro.x, 0.0, centro.y)
	nodo.rotation.y = atan2(dir.x, dir.y)
	add_child(nodo)
	# Baja 1 m bajo el piso por si el terreno sube, como MuroColonia
	_cuerpo(nodo, Vector3(0.0, alto / 2.0 - 0.5, 0.0), Vector3(GRUESO, alto + 1.0, largo), material)


# Reja de fierro cerrada a lo largo de `dir`, como las de MuroColonia: postes, travesanos y barrotes
func _reja(centro: Vector2, dir: Vector2, largo: float, alto: float) -> void:
	var nodo := Node3D.new()
	nodo.name = "Reja"
	nodo.position = Vector3(centro.x, 0.0, centro.y)
	nodo.rotation.y = atan2(dir.x, dir.y)
	add_child(nodo)
	var concreto := _material(GOTERA_COLOR)
	for z in [-largo / 2.0 + 0.3, 0.0, largo / 2.0 - 0.3]:
		_caja(nodo, Vector3(GRUESO + 0.1, alto + 0.3, 0.6), Vector3(0.0, (alto + 0.3) / 2.0, z), concreto)
	var zs: Array[float] = []
	for hoja in [-1.0, 1.0]:
		var z0: float = -largo / 2.0 + 0.6 if hoja < 0.0 else 0.3
		var z1: float = -0.3 if hoja < 0.0 else largo / 2.0 - 0.6
		for y in [0.25, alto - 0.35, alto * 0.5]:
			_caja(nodo, Vector3(0.07, 0.07, z1 - z0), Vector3(0.0, y, (z0 + z1) / 2.0), _fierro)
		var cuantos := maxi(2, int((z1 - z0) / 0.2))
		for i in cuantos + 1:
			zs.append(z0 + (z1 - z0) * i / cuantos)
	var barrote := BoxMesh.new()
	barrote.size = Vector3(0.035, alto - 0.1, 0.035)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = barrote
	multi.instance_count = zs.size()
	for i in zs.size():
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0.0, alto / 2.0 - 0.05, zs[i])))
	var barrotes := MultiMeshInstance3D.new()
	barrotes.multimesh = multi
	barrotes.material_override = _fierro
	nodo.add_child(barrotes)
	_choque(nodo, Vector3(0.0, alto / 2.0 - 0.5, 0.0), Vector3(GRUESO + 0.1, alto + 1.0, largo))


# --- Tinacos ---

func _tinaco(donde: Vector2) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "TinacoDefensa"
	cuerpo.position = Vector3(donde.x, 0.0, donde.y)
	add_child(cuerpo)
	var modelo := MODELO_TINACO.instantiate() as Node3D
	# El modelo trae tres tinacos: se deja uno completo (como Barricada._tinaco)
	for pieza in modelo.find_children("*", "Node3D"):
		if pieza.name.begins_with("Tinaco_") and pieza.get_parent().name == "Tinaco" and not pieza.name in TINACO_PIEZAS:
			pieza.get_parent().remove_child(pieza)
			pieza.queue_free()
	var caja := Barricada._caja_de(modelo)
	var escala := TINACO_ALTO / caja.size.y
	var sosten := Node3D.new()
	sosten.scale = Vector3.ONE * escala
	sosten.position = Vector3(-caja.get_center().x * escala, -caja.position.y * escala, -caja.get_center().z * escala)
	sosten.add_child(modelo)
	cuerpo.add_child(sosten)
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = maxf(caja.size.x, caja.size.z) * escala / 2.0
	cilindro.height = TINACO_ALTO
	forma.shape = cilindro
	forma.position.y = TINACO_ALTO / 2.0
	cuerpo.add_child(forma)


# --- Piezas ---

func _material(base: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PS1_SHADER
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("deterioro_modo", 2)
	material.set_shader_parameter("affine_enabled", false)
	material.set_shader_parameter("jitter_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	return material


func _caja(padre: Node3D, tam: Vector3, donde: Vector3, material: Material) -> void:
	var malla := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = tam
	malla.mesh = box
	malla.position = donde
	malla.material_override = material
	padre.add_child(malla)


func _choque(padre: Node3D, donde: Vector3, tam: Vector3) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.position = donde
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tam
	forma.shape = caja
	cuerpo.add_child(forma)
	padre.add_child(cuerpo)


# Caja con malla y choque
func _cuerpo(padre: Node3D, donde: Vector3, tam: Vector3, material: Material) -> void:
	_choque(padre, donde, tam)
	_caja(padre, tam, donde, material)


static func _centro(puntos: Array) -> Vector2:
	var suma := Vector2.ZERO
	for p: Vector2 in puntos:
		suma += p
	return suma / puntos.size()
