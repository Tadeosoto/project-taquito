class_name CamionetaModelo
extends RefCounted

# La pickup del gremio con sus tambos azules en la caja (y, si se pide, un rollo de manguera
# parado en el techo), como la ven la defensa del tinaco (DecoracionDefensa) y el reparto
# (CamionetaReparto). El origen es el suelo bajo el centro de la camioneta y su frente esta en +Z.
# El rollo queda como hijo "Rollo" para que quien lo pida lo haga girar.

const PICKUP := preload("res://models/vehiculos/pickup/pickup.scn")   # PS1 Ford F150: frente en +Z
const ESCALA := 1.1                          # el modelo mide 4.66 de largo: unos 5.1 m
const PISO := 0.84                           # lo que el modelo baja de su origen (las llantas)
const TECHO := 0.89                          # altura del techo de la cabina (en el modelo)
const CAJA_PISO := -0.12                     # el piso de la caja (en el modelo)
const CAJA_Z := -1.33                        # centro de los tambos (en el modelo): pegados a la cabina, los de atras quedan dentro de la compuerta
const TINTE := Color(0.85, 0.82, 0.74)       # pintura deslavada
const DESGASTE := 0.8                        # ps1_gastado: fierro pintado, percudido
const TAMBOS_FILAS := 2                      # en la caja: 2 hileras de 3 a lo largo
const TAMBOS_POR_FILA := 3
const ROLLO := preload("res://models/props/rollo_manguera/rollo_manguera.scn")   # Garden Hose Reel: eje en Z, 1 m de diametro
const ROLLO_ESCALA := 0.8
const ROLLO_RADIO := 0.5                     # del modelo, con el centro en su origen
const LARGO := 5.1                           # m, para ocupar lugar en la calle

static var _pintura := {}                    # material del modelo -> su copia percudida


static func crear(semilla := 0, con_rollo := false) -> Node3D:
	var raiz := Node3D.new()
	var pickup: Node3D = PICKUP.instantiate()
	pickup.scale = Vector3.ONE * ESCALA
	pickup.position.y = PISO * ESCALA
	raiz.add_child(pickup)
	_percudir(pickup)
	for fila in TAMBOS_FILAS:
		var tambos := Tambos.new()
		tambos.columnas = TAMBOS_POR_FILA
		tambos.niveles = 1
		tambos.semilla = fila + semilla
		tambos.rotation.y = PI / 2.0   # la hilera (su X) a lo largo de la caja
		var lado := (fila - (TAMBOS_FILAS - 1) / 2.0) * (Tambos.RADIO * 2.0 + 0.04)
		tambos.position = Vector3(lado, (PISO + CAJA_PISO) * ESCALA, CAJA_Z * ESCALA)
		raiz.add_child(tambos)
	if con_rollo:
		# Parado, con el eje de lado a lado para que gire y la manguera salga hacia atras
		var rollo: Node3D = ROLLO.instantiate()
		rollo.name = "Rollo"
		rollo.scale = Vector3.ONE * ROLLO_ESCALA
		rollo.rotation.y = PI / 2.0
		rollo.position = Vector3(0.0, (PISO + TECHO) * ESCALA + ROLLO_RADIO * ROLLO_ESCALA, 0.0)
		raiz.add_child(rollo)
		# La punta de manguera que trae el modelo la pone la animacion
		var cola := rollo.find_child("Object_5", true, false) as Node3D
		if cola != null:
			cola.visible = false
	return raiz


# Cambia la pintura del modelo por la misma con el desgaste de fierro de ps1_gastado
static func _percudir(modelo: Node) -> void:
	for malla: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		for i in malla.mesh.get_surface_count():
			var original := malla.mesh.surface_get_material(i) as ShaderMaterial
			if original == null:
				continue
			if not _pintura.has(original):
				var sucio := original.duplicate() as ShaderMaterial
				sucio.set_shader_parameter("deterioro_modo", 4)
				sucio.set_shader_parameter("desgaste", DESGASTE)
				sucio.set_shader_parameter("metal", true)
				sucio.set_shader_parameter("tint", TINTE)
				_pintura[original] = sucio
			malla.set_surface_override_material(i, _pintura[original])
