extends Node3D

# Objeto tirado en el mundo: se ve girando y con el boton de saltar se recoge
# (Player._nearby_interactable).

const TAMANO := 0.5
const RADIO := 1.5
const GIRO := 60.0 # grados por segundo
const IMAN_CADA := 0.2 # s entre revisar si el jugador con Iman esta cerca

# Jalar InventoryItemData
@export var item_data: InventoryItemData

# Sonidito cuando agarras algo
@export var pickup_sound: AudioStream

var _player_inside := false
var _recogido := false
var _modelo: Node3D
var _aviso: Label3D
var _iman_espera := 0.0


func _ready() -> void:
	add_to_group("interactuable")
	if item_data:
		_modelo = item_data.crear_modelo(TAMANO)
		if _modelo:
			add_child(_modelo)
		# Una bolsa especial de Takis brilla para que se encuentre de noche (EfectosPixel)
		if item_data.bolsa_tazo:
			var haz := EfectosPixel.cuadro_bucle("haz", PiezaMapa.HAZ_ESCALA, PiezaMapa.HAZ_ALFA)
			if haz:
				haz.position.y = -position.y
				add_child(haz)
	_aviso = Label3D.new()
	_aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_aviso.no_depth_test = true
	_aviso.position = Vector3.UP * 0.7
	_aviso.pixel_size = 0.008
	_aviso.visible = false
	add_child(_aviso)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = RADIO
	forma.shape = esfera
	area.add_child(forma)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	# Si usas algo o cambias de mochila junto al objeto, ya te puede caber
	Inventory.inventory_changed.connect(_actualizar_aviso)


func _process(delta: float) -> void:
	if _modelo:
		_modelo.rotation_degrees.y += GIRO * delta
	_revisar_iman(delta)


# Iman (Tazos.gd): cerca del jugador se recoge solo, si cabe. Se revisa cada IMAN_CADA s
func _revisar_iman(delta: float) -> void:
	_iman_espera -= delta
	if _iman_espera > 0.0 or _recogido or not Tazos.tiene("iman"):
		return
	_iman_espera = IMAN_CADA
	var jugador := get_tree().get_first_node_in_group("jugador") as Node3D
	if jugador and jugador.global_position.distance_to(global_position) <= Habilidades.IMAN_RADIO:
		interact()


func is_player_inside() -> bool:
	return _player_inside and not _recogido


func interact() -> void:
	# Safety check
	if item_data == null:
		push_warning("Este WorldItem no tiene ni madres asignado!")
		return
	if _recogido:
		return

	# Agregar item a inventario; si no cabe se queda tirado
	var agarrado := false
	if item_data.material != "":
		# Un material del taller (Morral.gd): no ocupa lugar
		get_node("/root/Morral").dar(item_data.material)
		agarrado = true
	else:
		agarrado = Inventory.equipar_mochila(item_data) if item_data.capacidad > 0 else Inventory.add_item(item_data)
	if not agarrado:
		return
	_recogido = true
	visible = false
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos:
		efectos.lanzar("recoger", global_position)

	# Sonidito
	if pickup_sound:
		# Hacer chingon luego
		var audio = AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = pickup_sound
		audio.play()
		# liberar item despues de un rato pa q se acabe el sonidito
		await get_tree().create_timer(0.1).timeout

	# Remover item de la escena
	queue_free()


func _on_body_entered(body: Node3D) -> void:
	if not body is Player:
		return
	_player_inside = true
	_actualizar_aviso()
	_aviso.visible = true


func _actualizar_aviso() -> void:
	if item_data == null:
		_aviso.text = ""
	elif item_data.capacidad > 0 and item_data.capacidad <= Inventory.capacidad_mochila():
		_aviso.text = "Ya traes una mochila mejor"
	elif item_data.capacidad == 0 and item_data.material == "" and Inventory.esta_lleno():
		_aviso.text = "No te cabe: %s" % item_data.item_name
	else:
		var tecla := "Espacio" if Input.get_connected_joypads().is_empty() else "X"
		_aviso.text = "%s: recoger %s" % [tecla, item_data.item_name]


func _on_body_exited(body: Node3D) -> void:
	if not body is Player:
		return
	_player_inside = false
	_aviso.visible = false
