class_name InventoryItemData

extends Resource

@export var item_name : String

@export_multiline var description : String

@export var icon : Texture2D

@export var inspection_model : PackedScene

# Lo que hace al usarlo (se ve en la tienda, debajo del nombre)
@export_multiline var efecto : String

# Precio en las tiendas (docs/especificaciones.md 4.5): en pesos o en agua limpia
@export var precio : int = 0

@export_enum("Pesos", "Agua") var moneda : int = 0

# Vida que recupera con "Utilizar" en el inventario; 0 = no se puede utilizar
@export var curacion : int = 0

# Si es arma: lo que le quita a un zombi de un golpe (Player._golpear). 0 = no es arma
@export var dano : int = 0

# Si es mochila: cuantos objetos caben con ella (Inventory.equipar_mochila). 0 = no es mochila
@export var capacidad : int = 0

# Pinta todo el modelo de este color, sin textura; con alfa 0 se queda como viene
@export var tinte : Color = Color(1, 1, 1, 0)


# El modelo centrado y escalado a una caja de `tamano` m (los de Sketchfab vienen en
# cualquier unidad), dentro de un nodo que se puede mover, girar y escalar libremente.
func crear_modelo(tamano: float) -> Node3D:
	if inspection_model == null:
		return null
	var instancia := inspection_model.instantiate()
	if not instancia is Node3D:
		instancia.queue_free()
		return null
	var modelo := instancia as Node3D
	var caja := Mueble.medir(modelo)
	var mayor := maxf(caja.size.x, maxf(caja.size.y, caja.size.z))
	if mayor > 0.0:
		var escala := tamano / mayor
		# Lo largo hacia los lados: un machete de frente a la camara se veia como una raya.
		# Solo si es claramente largo; a lo casi redondo (la caguama) se le veria el costado
		var giro := Basis(Vector3.UP, PI / 2.0) if caja.size.z > caja.size.x * 1.5 else Basis.IDENTITY
		modelo.transform = Transform3D(giro.scaled(Vector3.ONE * escala), giro * (-caja.get_center() * escala))
	if tinte.a > 0.0:
		_pintar(modelo)
	var soporte := Node3D.new()
	soporte.add_child(modelo)
	return soporte


func _pintar(nodo: Node) -> void:
	if nodo is MeshInstance3D and (nodo as MeshInstance3D).mesh:
		var malla := nodo as MeshInstance3D
		for i in malla.mesh.get_surface_count():
			var material := malla.get_active_material(i) as ShaderMaterial
			if material:
				var copia := material.duplicate() as ShaderMaterial
				copia.set_shader_parameter("tint", tinte)
				copia.set_shader_parameter("albedo_texture", null)
				malla.set_surface_override_material(i, copia)
	for hijo in nodo.get_children():
		_pintar(hijo)
