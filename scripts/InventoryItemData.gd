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

# Lo que te queda en la mano al usarlo (Inventory.usar_curacion): el refresco y la caguama dejan la
# botella vacia, que con gasolina y un trapo es molotov. Con esto se puede utilizar aunque no cure
@export var deja : InventoryItemData

# Para comprarlo hace falta traer esto, y se gasta: la gasolinera te llena una botella vacia, no te
# vende la gasolina suelta (Interior._comprar)
@export var requiere : InventoryItemData

# Si es arma: lo que le quita a un zombi de un golpe (Player._golpear). 0 = no es arma
@export var dano : int = 0

# Si es arma de fuego: su llave en Pistola.ARMAS ("escopeta", "ametralladora", "subfusil"). Traerla
# en el inventario la suma a las que cambia la tecla 2 (Pistola.siguiente). "" = no lo es
@export var arma_fuego : String = ""

# Si es mochila: cuantos objetos caben con ella (Inventory.equipar_mochila). 0 = no es mochila
@export var capacidad : int = 0

# Pinta todo el modelo de este color, sin textura; con alfa 0 se queda como viene
@export var tinte : Color = Color(1, 1, 1, 0)

# Bolsa especial de Takis: "Abrir" en el inventario saca un tazo (Tazos.gd, TazoRevelacion.gd)
@export var bolsa_tazo : bool = false

# --- Lo del taller (El Yonke de La Chava, Recetas.gd) ---

# Si es arma, como pega ademas del dano: factores sobre el alcance, el empujon al zombi y la
# rapidez del golpe (1 = como el machete), y si lo prende (Zombie.quemar)
@export var alcance : float = 1.0
@export var empujon : float = 1.0
@export var velocidad : float = 1.0
@export var quema : bool = false

# Si es amuleto: lo que da mientras lo traes puesto en uno de los dos lugares (Bonos.gd).
# Llaves: vida (+vida maxima), fuerza, defensa (fracciones, 0.1 = 10 %), noche (menos dano de
# noche), turba (menos dano de las turbas), fuertes (menos dano de cazadores y jefe), pesos
# (mas pesos por zombi), suerte (mejores tazos), arrojable, alcance (fracciones) y luz (true)
@export var amuleto : Dictionary = {}

# Estampita: se usa una vez y dura toda la partida (Bonos.gd). "punto" = +1 punto de
# habilidad, "defensa" = -5 % de dano, "fuerza" = +5 % de fuerza
@export var estampita : String = ""

# Ademas de curar, vuelve a dejar usar Segundo aire esta noche (Tazos.gd)
@export var recarga_segundo_aire : bool = false

# La cangurera (Inventory.cangurera): se pone sola, no ocupa lugar y es donde van los tiliches
@export var cangurera : bool = false

# Si se vende como material del taller (la plata del punto): al comprarlo va a los Tiliches con
# este id (Materiales.gd) y no al inventario
@export var material : String = ""


func es_amuleto() -> bool:
	return not amuleto.is_empty()


# Lo que se gasta se apila en un solo lugar del inventario (Inventory.MAX_PILA)
func apilable() -> bool:
	return curacion > 0 or bolsa_tazo or estampita != ""


# Se avienta con el Lanzador (tecla 3): sal o molotov (de limon o de cereza, que quema 1.5 veces mas lejos) contra las lombrices (ZonaLombrices), la
# palomita que aturde a los zombis (Arrojadizo.PALOMITA) o la bocina que los jala (Senuelo)
@export_enum("No", "Sal", "Molotov", "Palomita", "Bocina", "Bocina encintada", "Molotov de cereza") var arrojar : int = 0
# Cuantos lanzamientos da una pieza (la bolsa de sal: 10; JJ, 2026-11-10)
@export var usos : int = 1


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
