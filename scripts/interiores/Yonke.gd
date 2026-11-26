@tool
class_name Yonke
extends Interior

# El Yonke de Don Chava, que ahora atiende su nieta, La Chava (docs/personajes.md): el taller
# donde se hacen cosas con los materiales de los Tiliches (Taller.gd, Recetas.gd), como la sintesis
# de Kingdom Hearts. Es un interior como las tiendas (se entra por la flecha amarilla, de noche
# esta cerrado), pero en vez del carrusel de productos abre la pantalla del taller (TallerUI) y
# lo que elijes flota en el banco, frente a la camara. Propuesta de AG.

const CHAVA := preload("res://models/personajes/chava_psx/chava_psx.scn")
const CHAVA_ALTO := 1.62
const GIRO := 50.0            # grados por segundo de lo que esta en el banco
const OBJETO_TAMANO := 0.32
const SALUDO := "¿Qué te armo? Trae material y te hago lo que quieras. Bueno, lo que sepa."

# Lo que dice La Chava (al azar)
const LINEAS_HECHO := ["Ahí está. Quedó chido.", "Listo. No me lo vayas a devolver.", "Salió a la primera.",
	"Soldado y probado. Bueno, soldado.", "Eso. Mi abuelo no lo hubiera hecho mejor."]
const LINEA_JUEGO := "Ya le estás agarrando la onda. Te voy a enseñar más cosas."
const LINEAS_NO := {
	"cerrado": "Eso todavía no te lo hago. Tráeme más trabajo primero.",
	"plano": "Sin el plano ni le muevo. Búscalo.",
	"materiales": "No te alcanza el material. Ve a juntar.",
	"pesos": "Mi trabajo cuesta, eh. No te alcanza.",
	"lleno": "Ya no te cabe nada. Haz lugar.",
	"cangurera": "¿Y dónde lo vas a cargar? Consíguete una cangurera.",
}

# Mientras atiende, La Chava suelda el machete que trae en la prensa (yonke.py la_chava_cosas):
# chispazos cada tanto en la prensa del mostrador
const PRENSA_CHISPAS := Vector3(0.34, 1.12, -0.15)
const SOLDA_CADA := Vector2(2.5, 6.0)

var _taller: TallerUI
var _solda: GPUParticles3D
var _solda_espera := 3.0
var _banco: Node3D
var _objeto: Node3D


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	# La Chava (Gente.poner_modelo la escala por sus huesos). El Vendedor es un Node3D solo:
	# con el npc.tscn y su ninja quitado salian errores de material nulo
	var vendedor := get_node_or_null("Vendedor") as Node3D
	if vendedor:
		Gente.poner_modelo(vendedor, CHAVA, CHAVA_ALTO)
	_banco = get_node_or_null("Banco") as Node3D
	_solda = _chispazo()
	_solda.position = PRENSA_CHISPAS
	add_child(_solda)


# Lo que dice al llegar (el npc de las tiendas lo trae en `dialogue`; aqui no hay npc)
func dialogo() -> String:
	return SALUDO


func activar() -> void:
	activo = true
	_taller = TallerUI.new()
	_taller.yonke = self
	add_child(_taller)
	_taller.decir(_saludo())


func _process(delta: float) -> void:
	super._process(delta)
	if _objeto:
		_objeto.rotation_degrees.y += GIRO * delta
	if _solda:
		_solda_espera -= delta
		if _solda_espera <= 0.0:
			_solda_espera = randf_range(SOLDA_CADA.x, SOLDA_CADA.y)
			_solda.restart()


# Lo elegido en la pantalla del taller, flotando en el banco
func mostrar(receta: String) -> void:
	if _objeto:
		_objeto.queue_free()
		_objeto = null
	if _banco == null or receta == "":
		return
	var item := Recetas.objeto(receta)
	if item:
		_objeto = item.crear_modelo(OBJETO_TAMANO)
	else:
		# Un material (varilla armada, del 84): su icono en un cuadrito
		var icono := Materiales.icono(Recetas.material_resultado(receta))
		if icono:
			var sprite := Sprite3D.new()
			sprite.texture = icono
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			sprite.pixel_size = 0.02
			_objeto = Node3D.new()
			_objeto.add_child(sprite)
	if _objeto:
		_banco.add_child(_objeto)


# Chispas de soldadura en el banco (EfectosPixel, si hay) al hacer algo
func chispas() -> void:
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos and _banco:
		efectos.lanzar("impacto", _banco.global_position, Vector3.FORWARD, 0.6, "mata")


static func linea_hecho() -> String:
	return LINEAS_HECHO.pick_random()


# Un chispazo de soldadura: chispas amarillas que saltan y caen
func _chispazo() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 20
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.85
	p.emitting = false
	var proceso := ParticleProcessMaterial.new()
	proceso.direction = Vector3(0, 1, 0)
	proceso.spread = 75.0
	proceso.initial_velocity_min = 0.8
	proceso.initial_velocity_max = 1.8
	proceso.gravity = Vector3(0, -9.8, 0)
	proceso.color = Color(1.0, 0.85, 0.35)
	p.process_material = proceso
	var quad := QuadMesh.new()
	quad.size = Vector2(0.012, 0.012)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	p.draw_pass_1 = quad
	return p
