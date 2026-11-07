class_name RestosZombi
extends Node3D

# Lo que queda de un zombi que revento (Zombie._reventar, docs/especificaciones.md 4.2), en pixel
# art (AG). Cada muerte sale distinta:
# - un cono de embarrado hacia donde iba el golpe (CONO_*: abertura, alcance y desvio al azar),
#   con 1-2 embarrados largos en el piso que salen del cuerpo por el eje del cono;
# - PEDAZOS cuadros planos de 16x16 (DIBUJOS) escogidos de bolsas por familia (tripas, carne,
#   huesos, pedacitos): los pesados caen cerca, los ligeros lejos, unos pocos se salen del cono;
#   cada uno con giro, espejo, tamano y tinte al azar;
# - 2-3 piezas solidas en 3D (craneo, fémur, media caja de costillas, un bofe), mallas de
#   SurfaceTool con el shader PS1, que vuelan dando vueltas, rebotan una vez y se quedan
#   acostadas;
# - una rafaga de pedacitos (GPUParticles3D, billboards sin luz, filter_nearest).
# A los SE_VA s los cuadros se desvanecen con tramado y los solidos se hunden; a los VIDA s se
# borra. Es aparte del Zombie porque ese vuelve a la reserva a los 5 s. El atlas, las mallas,
# los materiales y el proceso de las particulas los comparten todos (crear materiales por
# instancia trababa, CLAUDE.md). Reloj real, como los demas efectos de los golpes. Los pone y
# los limita Zombis.gd (dejar_restos, MAX_RESTOS).

const PEDAZOS := 20           # cuadros que vuelan (sin el charco ni los embarrados)
const PIXEL := 0.025          # m por pixel de los dibujos (16 px = 0.4 m)
const CHARCO_GRANDE := 2.2    # el charco, mas grande que los pedazos
const SALE_ALTO := 1.0        # m sobre el piso de donde salen (el pecho; por el tamano del zombi)
const VUELO := 0.55           # s que tardan en crecer el charco y los embarrados
const VUELA := Vector2(0.35, 0.65) # s que vuela cada pedazo, al azar
const GRAVEDAD := 14.0
const SE_VA := 50.0           # s en que empiezan a desvanecerse
const VIDA := 60.0
const SE_HUNDE := 2.0         # s del final en que los solidos se hunden en el piso
const CAPAS := 0.002          # m entre cuadro y cuadro, para que no parpadeen encimados
# El cono: hacia donde iba el golpe (sin golpe, para un lado al azar)
const CONO_ABRE := Vector2(20.0, 45.0)   # grados a cada lado
const CONO_ALCANCE := Vector2(1.5, 3.5)  # m (por tamano)
const CONO_DESVIO := 8.0                 # grados que se tuerce el eje
const SUELTOS := 0.1          # de los pedazos que se salen del cono
const SUELTOS_ABRE := 30.0    # grados de mas
const EMBARRADO_LARGO := Vector2(1.2, 2.5) # m
const EMBARRADO_ANCHO := 0.8   # m (el dibujo ocupa la mitad de alto)
const TAMANO := Vector2(0.7, 1.4)
# La rafaga: pedacitos que vuelan y se pierden antes de tocar el piso
const RAFAGA := 32
const RAFAGA_DURA := 0.7      # s
const RAFAGA_TAMANO := 0.12   # m

# Del atlas: . nada, k contorno, g/G pellejo, r/R carne, b/B hueso, c/C trapo, w/W agua sucia,
# i/I tripa, y grasa
const COLORES := {
	"k": Color(0.08, 0.06, 0.04), "g": Color(0.3, 0.33, 0.2), "G": Color(0.42, 0.46, 0.28),
	"r": Color(0.35, 0.08, 0.07), "R": Color(0.55, 0.15, 0.12), "b": Color(0.72, 0.68, 0.52),
	"B": Color(0.88, 0.85, 0.7), "c": Color(0.25, 0.22, 0.3), "C": Color(0.38, 0.35, 0.42),
	"w": Color(0.2, 0.25, 0.1), "W": Color(0.3, 0.36, 0.16),
	"i": Color(0.55, 0.35, 0.32), "I": Color(0.7, 0.5, 0.45), "y": Color(0.7, 0.62, 0.3),
}
# Los dos ultimos son especiales: el charco (abajo de todo, en el cuerpo) y el embarrado (se
# estira por el eje del cono). La rafaga usa todos menos esos dos
const CHARCO := 14
const EMBARRADO := 15
# Familias: [dibujos, peso en la bolsa, que tan lejos caen (del alcance)]
const FAMILIAS := [
	[[7, 8, 12, 1], 0.3, 0.75],   # tripas
	[[0, 1, 3, 5], 0.25, 0.8],    # carne y pellejo
	[[2, 4, 9, 10, 11], 0.25, 0.55], # huesos (pesados)
	[[6, 13], 0.2, 1.0],          # pedacitos (ligeros)
]
const DIBUJOS := [
	[   # 0 pellejo
		"................", "................", ".....kkkkk......", "....kgggGGk.....",
		"...kggGGGggk....", "..kgggGggggkk...", "..kggggggRRgk...", ".kgggggRRrRgk...",
		".kggGggRrrRggk..", ".kgggggRRRgggk..", "..kgggggggggk...", "..kkggggGggk....",
		"....kkgggkk.....", "......kkk.......", "................", "................",
	],
	[   # 1 carne
		"................", "................", "......kkk.......", "....kkRRRkk.....",
		"...kRRRrRRRk....", "..kRRrrrRRBRk...", "..kRrrrRRRRRk...", ".kRRrrRRRrrRRk..",
		".kRRRRRrrrrRRk..", ".kRBRRRRrrRRk...", "..kRRRrRRRRRk...", "...kkRRRRRkk....",
		".....kkkkk......", "................", "................", "................",
	],
	[   # 2 hueso
		"................", "..kk............", ".kBBk...........", ".kBBbk..........",
		"..kbBbk.........", "...kbBbk........", "....kbBbk.......", ".....kbBbk......",
		"......kbBbk.....", ".......kbBbk....", "........kbBbk...", ".........kbBBk..",
		"..........kbBBk.", "...........kBBk.", "............kk..", "................",
	],
	[   # 3 trapo
		"................", "................", "...kkkk.........", "..kcccckkk......",
		"..kccCcccck.....", "...kccccCcck....", "...kcCcccccck...", "..kcccccCccck...",
		"..kccRcccccck...", "...kcccccCck....", "....kcccccck....", "....kcckkcck....",
		".....kk..kk.....", "................", "................", "................",
	],
	[   # 4 costillas
		"................", "................", "....kkkkkkk.....", "...kbBBBBBbk....",
		"...kbkkbkkbk....", "..kbk.kbk.kbk...", "..kBk.kBk.kBk...", "..kbk.kbk.kbk...",
		"..kBk.kBk.kBk...", "...kk.kbk.kk....", "......kBk.......", "......kbk.......",
		"......kkk.......", "................", "................", "................",
	],
	[   # 5 ojo
		"................", "................", "................", ".....kkkk.......",
		"....kBBBBk......", "...kBBkkBBk.....", "...kBkrrkBk.....", "...kBkrrkBk.....",
		"...kBBkkBBkk....", "....kBBBBkRRk...", ".....kkkkkRrRk..", "..........kRRk..",
		"...........kk...", "................", "................", "................",
	],
	[   # 6 pedacitos
		"................", "..kk.......kk...", ".kRRk.....kGgk..", "..kk.......kk...",
		"................", "......kkk.......", ".....kbBbk......", "......kkk...kk..",
		"...........kRrk.", "..kk........kk..", ".kgGk...........", "..kk.....kk.....",
		".........kRk....", "..........k.....", "................", "................",
	],
	[   # 7 tripa enrollada
		"................", "....kkkkkkk.....", "...kIIiiiIIk....", "..kIikkkkkiIk...",
		".kIik.....kiIk..", ".kIk..kkk..kIk..", ".kik.kIIIk.kik..", ".kik.kIkIk.kik..",
		".kik.kiikk.kik..", ".kIk..kk..kIk...", ".kIik....kiIk...", "..kIikkkkiIk....",
		"...kIIiiIIk.....", "....kkkkkk......", "................", "................",
	],
	[   # 8 tripa larga
		"................", "..kkk...........", ".kIIik..........", ".kikIik.........",
		"..kkkIik........", "....kIik........", "....kiIk...kkk..", "....kIik..kIIik.",
		".....kIikkIikik.", "......kIiIik.kk.", ".......kkkk.....", "................",
		"................", "................", "................", "................",
	],
	[   # 9 espinazo
		"................", "................", "................", "................",
		"..k...k...k...k.", ".kbk.kbk.kbk.kbk", "kbBBkbBBkbBBkbBk", "kBBbkBBbkBBbkBbk",
		".kbk.kbk.kbk.kbk", "..k...k...k...k.", "................", "................",
		"................", "................", "................", "................",
	],
	[   # 10 quijada
		"................", "................", "................", "..kk........kk..",
		".kbBk......kBbk.", ".kbBk.BkBkBkBbk.", ".kbBkkkkkkkkBbk.", "..kbBBBBBBBBbk..",
		"...kbbbbbbbbk...", "....kkkkkkkk....", "................", "................",
		"................", "................", "................", "................",
	],
	[   # 11 mano
		"................", "....k.k.k.......", "...kgkgkgk......", "...kgkgkgk.k....",
		"...kgkgkgkkgk...", "...kgggggkgk....", "..kkgggGgggk....", ".kgkgGGggggk....",
		".kggkggggggk....", "..kkgggggRk.....", "....kggRRRk.....", ".....kRrRk......",
		"......kkk.......", "................", "................", "................",
	],
	[   # 12 bofe
		"................", "................", "....kk...kk.....", "...kRRk.kRRk....",
		"..kRRRRkRrRRk...", "..kRRyRRRRrRk...", "..kRRRRRRrrRk...", "...kRRRRRrRk....",
		"....kRRRrRk.....", ".....kRRRk......", "......kRk.......", ".......k........",
		"................", "................", "................", "................",
	],
	[   # 13 astillas
		"................", ".kk.........k...", ".kBk.......kBk..", "..k...kk....k...",
		"......kbk.......", "..k....k....kk..", ".kbk.......kBBk.", "..k..kk.....kk..",
		".....kBk........", "......k...k.....", "..kk.....kbk....", ".kBbk.....k.....",
		"..kk............", "................", "................", "................",
	],
	[   # 14 charco
		"................", "......ww........", "...w.wwww..w....", "....wwwwwww.....",
		"..wwwwWwwwwww...", ".wwwwWWwwwwwww..", "..wwwwwwwrrwww..", "w.wwwwwwrrrwww.w",
		"..wwwwwwwrwwwww.", ".wwwwwwwwwwwww..", "..wwwWwwwwwww...", "...wwwwwwwww.w..",
		"..w..wwwwww.....", "......ww...w....", "................", "................",
	],
	[   # 15 embarrado (a lo largo de X)
		"................", "................", "................", "................",
		"...ww.w...w.....", ".wwwwwwwwwwww.w.", "wwWWwwwwwrwwwwww", "wwwwwWWwwwwwrwww",
		"wwrwwwwwwWWwwwww", ".wwwwwwwwwwwwww.", "...w..ww.w..w...", "................",
		"................", "................", "................", "................",
	],
]
const SHADER := preload("res://shaders/restos_pixel.gdshader")
const SHADER_SOLIDO := preload("res://shaders/ps1_combined.gdshader")
const COLOR_HUESO := Color(0.78, 0.74, 0.58)
const COLOR_OSCURO := Color(0.05, 0.04, 0.03)
const COLOR_BOFE := Color(0.5, 0.16, 0.13)
# Solidos: [nombre, que tan lejos caen (del alcance), alto acostado (m)]
const SOLIDOS := [["craneo", 0.45, 0.09], ["femur", 0.5, 0.04], ["costillas", 0.55, 0.16], ["bofe", 0.65, 0.06]]

static var _atlas: ImageTexture
static var _malla: PlaneMesh
static var _material: ShaderMaterial
static var _rafaga_proceso: ParticleProcessMaterial
static var _rafaga_malla: QuadMesh
static var _solidos := {}     # nombre -> ArrayMesh

var _inicio := 0
var _escala := 1.0
var _hacia := Vector3.ZERO
var _multi: MultiMesh
var _rafaga: GPUParticles3D
var _cuantos := 0             # instancias del MultiMesh
var _desde: Array[Vector3] = []
var _vel: Array[Vector3] = []
var _giro: Array[float] = []
var _cual: Array[int] = []
var _cae: Array[float] = []   # s en que cada uno toca el piso
var _medida: Array[Vector3] = [] # escala del cuadro (x negativa = espejo)
var _tinte: Array[float] = []
var _eje := Vector3.FORWARD   # del cono, horizontal
var _cayeron := false
var _alfa := 1.0
# Solidos: cada uno [MeshInstance3D, desde, vel, cae, alto, eje1, eje2, giro de descanso]
var _piezas: Array = []
var _asentados := false


static func _preparar() -> void:
	if _atlas:
		return
	var imagen := Image.create_empty(16 * DIBUJOS.size(), 16, false, Image.FORMAT_RGBA8)
	for d in DIBUJOS.size():
		var filas: Array = DIBUJOS[d]
		if filas.size() != 16:
			push_error("RestosZombi: el dibujo %d no tiene 16 filas" % d)
		for y in mini(filas.size(), 16):
			var fila: String = filas[y]
			if fila.length() != 16:
				push_error("RestosZombi: la fila %d del dibujo %d no mide 16" % [y, d])
			for x in mini(fila.length(), 16):
				if COLORES.has(fila[x]):
					imagen.set_pixel(d * 16 + x, y, COLORES[fila[x]])
	_atlas = ImageTexture.create_from_image(imagen)
	_malla = PlaneMesh.new()
	_malla.size = Vector2.ONE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("atlas", _atlas)
	_material.set_shader_parameter("dibujos", DIBUJOS.size())
	# La rafaga: billboards con un dibujo al azar (sin charco ni embarrado), sin luz y pixeles duros
	var dibujo := StandardMaterial3D.new()
	dibujo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dibujo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	dibujo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	dibujo.alpha_scissor_threshold = 0.5
	dibujo.albedo_texture = _atlas
	dibujo.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dibujo.particles_anim_h_frames = DIBUJOS.size()
	dibujo.particles_anim_v_frames = 1
	dibujo.particles_anim_loop = false
	_rafaga_malla = QuadMesh.new()
	_rafaga_malla.size = Vector2.ONE * RAFAGA_TAMANO
	_rafaga_malla.material = dibujo
	_rafaga_proceso = ParticleProcessMaterial.new()
	_rafaga_proceso.direction = Vector3.UP
	_rafaga_proceso.spread = 50.0
	_rafaga_proceso.initial_velocity_min = 2.5
	_rafaga_proceso.initial_velocity_max = 5.5
	_rafaga_proceso.gravity = Vector3.DOWN * GRAVEDAD
	_rafaga_proceso.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_rafaga_proceso.emission_sphere_radius = 0.2
	_rafaga_proceso.scale_min = 0.6
	_rafaga_proceso.scale_max = 1.4
	_rafaga_proceso.anim_speed_min = 0.0
	_rafaga_proceso.anim_speed_max = 0.0
	_rafaga_proceso.anim_offset_min = 0.0
	_rafaga_proceso.anim_offset_max = float(CHARCO) / DIBUJOS.size() - 0.001
	_armar_solidos()


# --- Solidos: mallas bajas hechas en codigo, una por tipo, compartidas ---

static func _material_solido(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER_SOLIDO
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("affine_enabled", false)
	return material


static func _armar_solidos() -> void:
	var hueso := _material_solido(COLOR_HUESO)
	var oscuro := _material_solido(COLOR_OSCURO)
	# Craneo: cara hacia +Z, apoyado en y 0 cuando esta derecho
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bola := SphereMesh.new()
	bola.radius = 0.1
	bola.height = 0.18
	bola.radial_segments = 7
	bola.rings = 4
	st.append_from(bola, 0, Transform3D(Basis(), Vector3(0, 0.0, 0)))
	_caja(st, Vector3(0.12, 0.05, 0.07), Vector3(0, -0.075, 0.05))
	var huecos := SurfaceTool.new()
	huecos.begin(Mesh.PRIMITIVE_TRIANGLES)
	_caja(huecos, Vector3(0.04, 0.035, 0.03), Vector3(-0.04, 0.01, 0.088))
	_caja(huecos, Vector3(0.04, 0.035, 0.03), Vector3(0.04, 0.01, 0.088))
	_caja(huecos, Vector3(0.02, 0.03, 0.02), Vector3(0, -0.03, 0.095))
	var craneo := ArrayMesh.new()
	st.commit(craneo)
	craneo.surface_set_material(0, hueso)
	huecos.commit(craneo)
	craneo.surface_set_material(1, oscuro)
	_solidos["craneo"] = craneo
	# Femur: a lo largo de X, con sus bolas en las puntas
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cana := CylinderMesh.new()
	cana.top_radius = 0.022
	cana.bottom_radius = 0.022
	cana.height = 0.34
	cana.radial_segments = 6
	cana.rings = 1
	st.append_from(cana, 0, Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3.ZERO))
	for lado: float in [-1.0, 1.0]:
		var nudo := SphereMesh.new()
		nudo.radius = 0.04
		nudo.height = 0.07
		nudo.radial_segments = 6
		nudo.rings = 3
		st.append_from(nudo, 0, Transform3D(Basis(), Vector3(lado * 0.17, 0, 0)))
		st.append_from(nudo, 0, Transform3D(Basis().scaled(Vector3.ONE * 0.8), Vector3(lado * 0.17, 0, lado * 0.035)))
	var femur := ArrayMesh.new()
	st.commit(femur)
	femur.surface_set_material(0, hueso)
	_solidos["femur"] = femur
	# Media caja de costillas: el espinazo arriba (a lo largo de Z) y cuatro costillas que bajan
	# en arco hacia +X, asi queda con lo curvo para arriba
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_caja(st, Vector3(0.045, 0.045, 0.32), Vector3(0, 0.0, 0))
	for c in 4:
		var z := -0.11 + c * 0.075
		var radio := 0.13 - c * 0.008
		var antes := Vector3(0, 0, z)
		for paso in range(1, 6):
			var a := paso / 5.0 * PI * 0.75
			var punto := Vector3(sin(a) * radio, (cos(a) - 1.0) * radio * 0.75, z)
			_barra(st, antes, punto, 0.022)
			antes = punto
	var costillas := ArrayMesh.new()
	st.commit(costillas)
	costillas.surface_set_material(0, hueso)
	_solidos["costillas"] = costillas
	# Bofe: una bola chueca. El ruido sale de la posicion para que las costuras no se abran
	var bofe_base := SphereMesh.new()
	bofe_base.radius = 0.08
	bofe_base.height = 0.13
	bofe_base.radial_segments = 7
	bofe_base.rings = 4
	var arreglos := bofe_base.get_mesh_arrays()
	var puntos: PackedVector3Array = arreglos[Mesh.ARRAY_VERTEX]
	for i in puntos.size():
		var p := puntos[i]
		var semilla := int(round(p.x * 1000.0)) * 73856093 ^ int(round(p.y * 1000.0)) * 19349663 ^ int(round(p.z * 1000.0)) * 83492791
		var azar := RandomNumberGenerator.new()
		azar.seed = semilla
		puntos[i] = p * azar.randf_range(0.7, 1.25)
	arreglos[Mesh.ARRAY_VERTEX] = puntos
	arreglos[Mesh.ARRAY_NORMAL] = null
	arreglos[Mesh.ARRAY_TANGENT] = null
	var crudo := ArrayMesh.new()
	crudo.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arreglos)
	st = SurfaceTool.new()
	st.create_from(crudo, 0)
	st.generate_normals()
	var bofe := st.commit()
	bofe.surface_set_material(0, _material_solido(COLOR_BOFE))
	_solidos["bofe"] = bofe


static func _caja(st: SurfaceTool, medida: Vector3, donde: Vector3) -> void:
	var caja := BoxMesh.new()
	caja.size = medida
	st.append_from(caja, 0, Transform3D(Basis(), donde))


# Una barra cuadrada de `a` a `b`
static func _barra(st: SurfaceTool, a: Vector3, b: Vector3, grueso: float) -> void:
	var largo := a.distance_to(b)
	if largo < 0.0001:
		return
	var y := (b - a) / largo
	var x := y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var caja := BoxMesh.new()
	caja.size = Vector3(grueso, largo + grueso * 0.5, grueso)
	st.append_from(caja, 0, Transform3D(Basis(x, y, x.cross(y)), (a + b) / 2.0))


func tamano(cuanto: float) -> void:
	_escala = cuanto


# A donde iba el golpe que lo mato (horizontal): el cono de embarrado va para alla
func direccion(hacia: Vector3) -> void:
	_hacia = Vector3(hacia.x, 0.0, hacia.z).normalized() if hacia != Vector3.ZERO else Vector3.ZERO


func _ready() -> void:
	_preparar()
	_inicio = Time.get_ticks_msec()
	# El cono de esta muerte
	var eje := _hacia if _hacia != Vector3.ZERO else Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	_eje = eje.rotated(Vector3.UP, deg_to_rad(randf_range(-CONO_DESVIO, CONO_DESVIO)))
	var abre := deg_to_rad(randf_range(CONO_ABRE.x, CONO_ABRE.y))
	var alcance := randf_range(CONO_ALCANCE.x, CONO_ALCANCE.y) * _escala
	var alto := SALE_ALTO * _escala
	var base := PIXEL * 16.0 * _escala
	# 0: el charco; 1-2: embarrados; luego los pedazos (asi los de abajo se dibujan abajo)
	_agregar(CHARCO, Vector3.ZERO, Vector3.ZERO, 0.0, Vector3(base * CHARCO_GRANDE, 1.0, base * CHARCO_GRANDE), 0.0, randf() * TAU)
	for e in randi_range(1, 2):
		var largo := randf_range(EMBARRADO_LARGO.x, EMBARRADO_LARGO.y) * _escala
		var lado := _eje.rotated(Vector3.UP, randf_range(-abre, abre) * 0.4)
		_agregar(EMBARRADO, lado, Vector3.ZERO, 0.0, Vector3(largo, 1.0, EMBARRADO_ANCHO * _escala), randf() * 0.5, atan2(-lado.z, lado.x))
	var bolsa := _bolsa()
	for i in PEDAZOS:
		var familia: Array = FAMILIAS[bolsa[i]]
		var dibujos: Array = familia[0]
		var cual: int = dibujos[randi() % dibujos.size()]
		var desde := Vector3(randf_range(-0.15, 0.15), alto, randf_range(-0.15, 0.15))
		var cae := randf_range(VUELA.x, VUELA.y)
		var meta := _en_cono(abre, alcance * float(familia[2]))
		var vel := _lanzar(desde, meta, cae)
		var tam := base * randf_range(TAMANO.x, TAMANO.y)
		var espejo := -1.0 if randf() < 0.5 else 1.0
		_desde.append(desde)
		_vel.append(vel)
		_cae.append(cae)
		_cual.append(cual)
		_giro.append(randf() * TAU)
		_medida.append(Vector3(tam * espejo, 1.0, tam))
		_tinte.append(randf() * 0.6)
	_cuantos = _cual.size()
	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_custom_data = true
	_multi.mesh = _malla
	_multi.instance_count = _cuantos
	var pedazos := MultiMeshInstance3D.new()
	pedazos.multimesh = _multi
	pedazos.material_override = _material
	pedazos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# La caja no cambia con lo que vuelan: que no los recorte la camara
	pedazos.custom_aabb = AABB(Vector3(-5, -0.5, -5) * _escala, Vector3(10, 4, 10) * _escala)
	add_child(pedazos)
	_armar_piezas(abre, alcance, alto)
	_armar_rafaga(alto)
	_colocar(0.0)


# Un cuadro que no vuela (charco o embarrado): queda en el piso desde el principio. Para el
# embarrado `desde` es la direccion en que se estira
func _agregar(cual: int, desde: Vector3, vel: Vector3, cae: float, medida: Vector3, tinte: float, giro: float) -> void:
	_cual.append(cual)
	_desde.append(desde)
	_vel.append(vel)
	_cae.append(cae)
	_medida.append(medida)
	_tinte.append(tinte)
	_giro.append(giro)


# Que familia toca a cada pedazo: por peso, barajado
func _bolsa() -> Array:
	var bolsa := []
	for f in FAMILIAS.size():
		for n in roundi(PEDAZOS * float(FAMILIAS[f][1])):
			bolsa.append(f)
	while bolsa.size() < PEDAZOS:
		bolsa.append(randi() % FAMILIAS.size())
	bolsa.shuffle()
	return bolsa


# Un punto del piso dentro del cono (unos pocos se salen)
func _en_cono(abre: float, lejos: float) -> Vector3:
	var angulo := randf_range(-abre, abre)
	if randf() < SUELTOS:
		angulo += signf(angulo) * deg_to_rad(randf_range(0.0, SUELTOS_ABRE))
	var hacia := _eje.rotated(Vector3.UP, angulo)
	return hacia * maxf(0.3 * _escala, lejos * randf_range(0.35, 1.1))


# La velocidad para ir de `desde` a `meta` (en el piso) en `t` segundos
func _lanzar(desde: Vector3, meta: Vector3, t: float) -> Vector3:
	var plano := Vector3(meta.x - desde.x, 0.0, meta.z - desde.z) / t
	return plano + Vector3.UP * ((meta.y - desde.y) / t + 0.5 * GRAVEDAD * t)


func _armar_piezas(abre: float, alcance: float, alto: float) -> void:
	var tipos := range(SOLIDOS.size())
	tipos.shuffle()
	for n in randi_range(2, 3):
		var s: Array = SOLIDOS[tipos[n]]
		var malla := MeshInstance3D.new()
		malla.mesh = _solidos[s[0]]
		malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		malla.scale = Vector3.ONE * _escala
		add_child(malla)
		var desde := Vector3(randf_range(-0.1, 0.1), alto, randf_range(-0.1, 0.1))
		var cae := randf_range(VUELA.x, VUELA.y)
		var meta := _en_cono(abre, alcance * float(s[1]))
		meta.y = float(s[2]) * _escala
		var descanso := Basis(Vector3.UP, randf() * TAU) * _acostado(s[0])
		_piezas.append([malla, desde, _lanzar(desde, meta, cae), cae, float(s[2]) * _escala,
			Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized(), randf_range(8.0, 16.0), descanso])


# Como queda en el piso cada solido (antes del giro al azar alrededor de Y)
func _acostado(nombre: String) -> Basis:
	match nombre:
		"craneo":
			# De lado o boca abajo
			return Basis(Vector3.BACK, PI / 2.0 * (1.0 if randf() < 0.5 else -1.0)) if randf() < 0.6 else Basis(Vector3.RIGHT, PI / 2.0)
		"bofe":
			return Basis(Vector3(randf(), randf(), randf()).normalized(), randf() * TAU)
	return Basis()


func _armar_rafaga(alto: float) -> void:
	_rafaga = GPUParticles3D.new()
	_rafaga.process_material = _rafaga_proceso
	_rafaga.draw_pass_1 = _rafaga_malla
	_rafaga.amount = RAFAGA
	_rafaga.lifetime = RAFAGA_DURA
	_rafaga.one_shot = true
	_rafaga.explosiveness = 1.0
	_rafaga.local_coords = false
	_rafaga.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rafaga.position = Vector3.UP * alto
	# Inclinada por el eje del cono: la direccion del proceso es la Y de la rafaga
	var arriba := (Vector3.UP + _eje * 1.0).normalized()
	var eje := Vector3.UP.cross(arriba).normalized()
	_rafaga.basis = Basis(eje, Vector3.UP.angle_to(arriba))
	_rafaga.scale = Vector3.ONE * _escala
	add_child(_rafaga)
	_rafaga.emitting = true


# Se dibuja una vez todo junto para que el primero no trabe (Zombie.calentar)
func calentar() -> void:
	set_process(false)


func _colocar(t: float) -> void:
	var crece := clampf(t / VUELO, 0.0, 1.0)
	for i in _cuantos:
		var cual := _cual[i]
		var medida := _medida[i]
		var donde: Vector3
		var base := Basis(Vector3.UP, _giro[i])
		if cual == CHARCO:
			medida = Vector3(medida.x * lerpf(0.3, 1.0, crece), 1.0, medida.z * lerpf(0.3, 1.0, crece))
			donde = Vector3.ZERO
		elif cual == EMBARRADO:
			# Sale del cuerpo y se va alargando por el eje
			var largo := medida.x * lerpf(0.2, 1.0, crece)
			medida = Vector3(largo, 1.0, medida.z)
			donde = _desde[i] * (largo * 0.5)
		else:
			var vuela := minf(t, _cae[i])
			donde = _desde[i] + _vel[i] * vuela + Vector3.DOWN * 0.5 * GRAVEDAD * vuela * vuela
			if t < _cae[i]:
				# En el aire va dando vueltas
				base = base * Basis(Vector3.RIGHT, t * 12.0 + _giro[i])
			else:
				donde.y = 0.0
		donde.y += CAPAS * i
		_multi.set_instance_transform(i, Transform3D(base * Basis.from_scale(medida), donde))
		_multi.set_instance_custom_data(i, Color(cual, _tinte[i], 0.0, _alfa))


# Vuela dando vueltas, rebota una vez y se acomoda acostado
func _mover_piezas(t: float) -> bool:
	var quietas := true
	for p: Array in _piezas:
		var malla: MeshInstance3D = p[0]
		var desde: Vector3 = p[1]
		var vel: Vector3 = p[2]
		var cae: float = p[3]
		var alto: float = p[4]
		var descanso: Basis = p[7]
		var girando := Basis(p[5], t * float(p[6]))
		if t < cae:
			quietas = false
			malla.position = desde + vel * t + Vector3.DOWN * 0.5 * GRAVEDAD * t * t
			malla.basis = girando.scaled(Vector3.ONE * _escala)
			continue
		# El rebote: un tercio de la velocidad con que pego, y despacio hacia adelante
		var llega := desde + vel * cae + Vector3.DOWN * 0.5 * GRAVEDAD * cae * cae
		var sube := (GRAVEDAD * cae - vel.y) * 0.3
		var dura := 2.0 * sube / GRAVEDAD
		var r := minf(t - cae, dura)
		var plano := Vector3(vel.x, 0.0, vel.z) * 0.3
		malla.position = Vector3(llega.x, alto, llega.z) + plano * r + Vector3.UP * (sube * r - 0.5 * GRAVEDAD * r * r)
		var avance := clampf(r / maxf(dura, 0.001), 0.0, 1.0)
		var giro := Basis(Basis(p[5], cae * float(p[6])).get_rotation_quaternion().slerp(descanso.get_rotation_quaternion(), avance))
		malla.basis = giro.scaled(Vector3.ONE * _escala)
		if t - cae < dura:
			quietas = false
	return quietas


func _process(_delta: float) -> void:
	var t := (Time.get_ticks_msec() - _inicio) / 1000.0
	if t >= VIDA:
		queue_free()
		return
	if not _cayeron or not _asentados:
		if not _cayeron:
			_colocar(t)
			_cayeron = t >= maxf(VUELO, _cae.max())
		if not _asentados:
			_asentados = _mover_piezas(t)
		return
	if t >= SE_VA:
		_alfa = 1.0 - (t - SE_VA) / (VIDA - SE_VA)
		_colocar(t)
	if t >= VIDA - SE_HUNDE:
		# Los solidos se hunden en el piso
		var hunde := (t - (VIDA - SE_HUNDE)) / SE_HUNDE
		for p: Array in _piezas:
			var malla: MeshInstance3D = p[0]
			malla.position.y = float(p[4]) * (1.0 - 2.5 * hunde)
