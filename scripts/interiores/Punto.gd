@tool
class_name Punto
extends Interior

# El Punto: la oficina de atras de la Cantina El Olvido (models/negocios/punto/punto_dentro.glb, de
# tools/blender/negocios/punto.py), donde Don Lalo Santacruz vende fierros (las armas de fuego)
# sentado en su silla de piel: madera oscura, la pared de cuernos, cajas de balas, el tapete de
# tigre, la pecera, el telefono de oro, la caja fuerte abierta y el altar de la Virgen del Tinaco.
# Se llega por la puerta de atras de la cantina (scripts/punto/Cantina.gd); es un interior como las
# tiendas: lo que vende flota en la Vitrina y se compra con saltar. No cierra de noche
# (Interiores.ABIERTOS_NOCHE).
#
# Don Lalo es hombre_04 del pack PSX (el cuerpo de El Compa) con su textura (tools/personajes/
# el_compa.gd -- --patron: seda negra barroca, cadena, rapado, candado, cicatriz y diente de oro),
# sentado, y cambia de gesto solo (Sitting_Idle/Talking/Nodding/Idle02/03): platica cuando compras
# y asiente, despacio, cuando no te alcanza. Trae su puro (con humo), los lentes en la cabeza, sus
# anillos y su reloj de oro, pegados a los huesos. Viejo, rezandero y de usted (docs/personajes.md).

const MODELO := "hombre_04"
const TEXTURA := preload("res://models/personajes/patron/Character_04.png")
const NOMBRE := "Don Lalo Santacruz"
# Sitting_Idle deja la cadera CADERA m detras de los pies (Sotano.CADERA): el Vendedor marca el
# centro del asiento y el modelo se adelanta eso
const CADERA := 0.38
# La lampara de banquero del escritorio (punto.py: O_lampara_*) alumbra de verdad
const LAMPARA := Vector3(-0.75, 1.05, -0.78)
const LAMPARA_COLOR := Color(1.0, 0.8, 0.5)
const LAMPARA_ENERGIA := 2.2
const GESTOS := ["h/Sitting_Idle", "h/Sitting_Idle02", "h/Sitting_Idle03", "h/Sitting_Nodding"]
const GESTO_CADA := Vector2(5.0, 9.0)     # s entre un gesto y otro
const ESCALA := 0.39                       # Civiles.ESCALA: los huesos estan en medidas del modelo
const SALUDOS := [
	"Pase usted. Aquí se atiende con respeto, y se paga igual.",
	"Buenas, joven. La Virgen me lo trajo, ¿qué se le ofrece?",
	"Siéntese... no, mejor no se siente. Escoja.",
	"Los zombis no respetan a nadie. Esto sí lo respetan.",
]
const SALUDOS_NOCHE := [
	"A esta hora sólo vienen los que de veras lo necesitan. Usted dirá.",
	"De noche los precios son los mismos. La prisa no.",
]
const COMPRA := ["Buena elección. Que Dios se la bendiga.", "Cuídela, que ésa no se presta.", "Trátela como a una madre.",
	"Con eso ya puede dormir tranquilo. Más o menos."]
const NO_ALCANZA := ["Aquí no se fía, joven. Ni a los santos.", "Junte, y regresa. Aquí lo espero.",
	"Con eso no le alcanza ni para el estuche."]

var _animacion: AnimationPlayer
var _gesto := 0.0


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	var lampara := OmniLight3D.new()
	lampara.name = "Lampara"
	lampara.position = LAMPARA
	lampara.light_color = LAMPARA_COLOR
	lampara.light_energy = LAMPARA_ENERGIA
	lampara.omni_range = 3.0
	add_child(lampara)
	var vendedor := get_node_or_null("Vendedor") as Node3D
	if vendedor == null:
		return
	var asiento := Node3D.new()
	asiento.name = "Patron"
	asiento.position = Vector3(0.0, 0.0, CADERA)
	# hombre_04 queda de espaldas con Civiles.poner (los civiles de la calle no tienen frente fijo):
	# media vuelta para que vea a la camara
	asiento.rotation.y = PI
	vendedor.add_child(asiento)
	_animacion = Civiles.poner(asiento, MODELO, "Sitting_Idle")
	# Su textura en vez de la del pack: un material por malla, hecho una vez al entrar
	var material := StandardMaterial3D.new()
	material.albedo_texture = TEXTURA
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.9
	for malla: MeshInstance3D in asiento.find_children("*", "MeshInstance3D", true, false):
		for i in malla.mesh.get_surface_count():
			malla.set_surface_override_material(i, material)
	var esqueletos := asiento.find_children("*", "Skeleton3D", true, false)
	if not esqueletos.is_empty():
		_props(esqueletos[0] as Skeleton3D)
	_gesto = randf_range(GESTO_CADA.x, GESTO_CADA.y)


func dialogo() -> String:
	var ciclo := get_tree().get_first_node_in_group("ciclo") if is_inside_tree() else null
	var lista: Array = SALUDOS_NOCHE if ciclo and ciclo.es_noche() and randf() < 0.6 else SALUDOS
	return lista[randi() % lista.size()]


func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint() or _animacion == null:
		return
	_gesto -= delta
	if _gesto <= 0.0:
		_gesto = randf_range(GESTO_CADA.x, GESTO_CADA.y)
		_hacer(GESTOS[randi() % GESTOS.size()])


func _hacer(clip: String) -> void:
	if _animacion and _animacion.has_animation(clip):
		_animacion.play(clip, 0.4)


# Platica cuando le compras, asiente despacio cuando no te alcanza
func _comprar() -> void:
	var cartera := get_node_or_null("/root/Cartera")
	var antes: int = cartera.pesos if cartera else 0
	super._comprar()
	if cartera == null or _ui == null:
		return
	if cartera.pesos < antes:
		_hacer("h/Sitting_Talking")
		_ui.decir(COMPRA[randi() % COMPRA.size()], 2.5)
	else:
		_hacer("h/Sitting_Nodding")
		_ui.decir(NO_ALCANZA[randi() % NO_ALCANZA.size()], 2.5)
	_gesto = GESTO_CADA.y


# --- Lo que trae encima, pegado a los huesos (en medidas del esqueleto: metros / ESCALA)

func _props(esqueleto: Skeleton3D) -> void:
	var oro := StandardMaterial3D.new()
	oro.albedo_color = Color(0.95, 0.72, 0.2)
	oro.metallic = 0.85
	oro.roughness = 0.3
	var negro := StandardMaterial3D.new()
	negro.albedo_color = Color(0.04, 0.04, 0.05)
	negro.roughness = 0.2
	negro.metallic_specular = 0.9
	# Los lentes oscuros subidos en la cabeza
	var cabeza := _pegar(esqueleto, "Head")
	if cabeza:
		cabeza.name = "Lentes"
		for s in [-1.0, 1.0]:
			cabeza.add_child(_caja(Vector3(0.11, 0.06, 0.02) / ESCALA, Vector3(s * 0.045, 0.16, 0.07) / ESCALA, negro))
		cabeza.add_child(_caja(Vector3(0.2, 0.012, 0.012) / ESCALA, Vector3(0.0, 0.177, 0.07) / ESCALA, oro))
	# El puro en la mano derecha, con su brasa y su humo
	var derecha := _pegar(esqueleto, "RightHand")
	if derecha:
		derecha.name = "Puro"
		var puro := MeshInstance3D.new()
		var cilindro := CylinderMesh.new()
		cilindro.top_radius = 0.009 / ESCALA
		cilindro.bottom_radius = 0.011 / ESCALA
		cilindro.height = 0.14 / ESCALA
		cilindro.radial_segments = 6
		puro.mesh = cilindro
		var cafe := StandardMaterial3D.new()
		cafe.albedo_color = Color(0.35, 0.2, 0.1)
		puro.material_override = cafe
		puro.position = Vector3(0.0, 0.09, 0.04) / ESCALA
		puro.rotation_degrees = Vector3(0, 0, 90)
		derecha.add_child(puro)
		var brasa := MeshInstance3D.new()
		var bola := SphereMesh.new()
		bola.radius = 0.012 / ESCALA
		bola.height = 0.024 / ESCALA
		brasa.mesh = bola
		var rojo := StandardMaterial3D.new()
		rojo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rojo.albedo_color = Color(1.0, 0.45, 0.1)
		brasa.material_override = rojo
		brasa.position = Vector3(0.0, cilindro.height / 2.0, 0.0)
		puro.add_child(brasa)
		brasa.add_child(_humo())
		derecha.add_child(_anillo(Vector3(-0.01, 0.06, 0.0) / ESCALA, oro))
	var izquierda := _pegar(esqueleto, "LeftHand")
	if izquierda:
		izquierda.add_child(_anillo(Vector3(0.01, 0.06, 0.0) / ESCALA, oro))
	var antebrazo := _pegar(esqueleto, "LeftLowerArm")
	if antebrazo:
		antebrazo.add_child(_caja(Vector3(0.055, 0.03, 0.055) / ESCALA, Vector3(0.0, 0.2, 0.0) / ESCALA, oro))


func _pegar(esqueleto: Skeleton3D, hueso: String) -> BoneAttachment3D:
	if esqueleto.find_bone(hueso) < 0:
		return null
	var pegado := BoneAttachment3D.new()
	pegado.bone_name = hueso
	esqueleto.add_child(pegado)
	return pegado


func _caja(tamano: Vector3, en: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var malla := BoxMesh.new()
	malla.size = tamano
	mi.mesh = malla
	mi.material_override = material
	mi.position = en
	return mi


func _anillo(en: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var dona := TorusMesh.new()
	dona.inner_radius = 0.009 / ESCALA
	dona.outer_radius = 0.014 / ESCALA
	dona.rings = 8
	dona.ring_segments = 4
	mi.mesh = dona
	mi.material_override = material
	mi.position = en
	return mi


# Humito del puro: particulas grises que suben y se abren
func _humo() -> GPUParticles3D:
	var humo := GPUParticles3D.new()
	humo.amount = 10
	humo.lifetime = 2.2
	var proceso := ParticleProcessMaterial.new()
	proceso.direction = Vector3(0, 1, 0)
	proceso.spread = 12.0
	proceso.initial_velocity_min = 0.05
	proceso.initial_velocity_max = 0.12
	proceso.gravity = Vector3(0, 0.05, 0)
	proceso.scale_min = 0.6
	proceso.scale_max = 1.4
	var curva := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 1.0))
	curva.curve = c
	proceso.scale_curve = curva
	proceso.color = Color(0.75, 0.75, 0.75, 0.35)
	humo.process_material = proceso
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	humo.draw_pass_1 = quad
	humo.local_coords = false
	return humo
