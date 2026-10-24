extends Node3D

# Jalar InventoryItemData
@export var item_data: InventoryItemData

# Sonidito cuando agarras algo
@export var pickup_sound: AudioStream

func interact() -> void:
	# Safety check
	if item_data == null:
		push_warning("Este WorldItem no tiene ni madres asignado!")
		return

	# Agregar item a inventario
	Inventory.add_item(item_data)

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
