@tool
class_name Yonke
extends Interior

# El Yonke de Don Chava, que ahora atiende su nieta, La Chava (docs/personajes.md): el taller
# donde se hacen cosas con los materiales del Morral (Taller.gd, Recetas.gd), como la sintesis
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
}

var _taller: TallerUI
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
