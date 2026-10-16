extends CanvasLayer

enum InventoryState {
	NAVIGATING,
	INSPECTING
}

@onready var item_name_label: Label = $MainPanel/ItemName
@onready var item_description_label: RichTextLabel = ($MainPanel/ItemDescription)
@onready var item_pivot: Node3D = ($MainPanel/PreviewContainer/PreviewViewport/PreviewWorld/ItemPivot)
@onready var inspect_hint_label: Label = $MainPanel/InspecHint
@onready var item_count_label: Label = $MainPanel/ItemCount
@onready var inspect_button: Button = $MainPanel/InspectButton
@onready var inspect_viewer: Node3D = ($MainPanel/PreviewContainer/PreviewViewport/PreviewWorld)

@export var inventory_items: Array[InventoryItemData] = []

var current_state: InventoryState = InventoryState.NAVIGATING
var current_item_index: int = 0

var current_model : Node3D

func _ready() -> void:
	
	inspect_button.pressed.connect(_on_inspect_button_pressed)
	
	inspect_button.focus_mode = Control.FOCUS_NONE
	
	for index in range(inventory_items.size() -1, -1, -1):
		if inventory_items[index] == null:
				inventory_items.remove_at(index)
	
	set_inspection_mode(false)
	
	display_current_item()
	
func _on_inspect_button_pressed() -> void:
	if current_state == InventoryState.INSPECTING:
		set_inspection_mode(false)
	elif is_instance_valid(current_model):
		set_inspection_mode(true)
	
func _unhandled_input(event: InputEvent) -> void:
	
	if current_state == InventoryState.INSPECTING:
		if event.is_action_pressed("inventory_back"):
				set_inspection_mode(false)
				get_viewport().set_input_as_handled()
		return
	
	if inventory_items.is_empty():
		return
		
	if event.is_action_pressed("inventory_next"):
			current_item_index = (
				(current_item_index + 1) % inventory_items.size()
			)
			
			display_current_item()
			get_viewport().set_input_as_handled()
			
	elif event.is_action_pressed("inventory_previous"):
			current_item_index = (
				(current_item_index - 1 + inventory_items.size())
				% inventory_items.size()
			)
			
			display_current_item()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory_confirm"):
		if is_instance_valid(current_model):
				set_inspection_mode(true)
		
		get_viewport().set_input_as_handled()
	
func set_inspection_mode(active: bool) -> void:
	if active:
			current_state = InventoryState.INSPECTING
	else:
			current_state = InventoryState.NAVIGATING
	inspect_viewer.set_inspection_active(active)
	update_hint()

func display_current_item() -> void:
		clear_current_model()
	
		if inventory_items.is_empty():
			item_name_label.text = "No Items"
			item_description_label.text = "There is nothing in the inventory."
			update_hint()
			return
			
		var selected_item := inventory_items[current_item_index]
		
		if selected_item == null:
			push_warning("Assign an item resoruce to this inventory slot.")
			return
			
		item_name_label.text = selected_item.item_name
		item_description_label.text = selected_item.description
		
		display_item_model(selected_item)
		
		update_hint()
		
func display_item_model(item: InventoryItemData) -> void:
		if item.inspection_model == null:
				return
		var instance: Node = item.inspection_model.instantiate()
		
		if not instance is Node3D:
				instance.queue_free()
				
				push_warning("The inspection model needs a Node3D root.")
				
				return
				
		current_model= instance as Node3D
		
		item_pivot.rotation_degrees = Vector3.ZERO
		
		item_pivot.add_child(current_model)
		
func clear_current_model() -> void:
		if is_instance_valid(current_model):
			item_pivot.remove_child(current_model)
			
			current_model.queue_free()
			
		current_model = null
		
func update_hint() -> void:
		if inventory_items.is_empty():
			inspect_hint_label.text = ""
			item_count_label.text = "Objecto 0 de 0"
			
			inspect_button.text = "Examinar [Enter]"
			inspect_button.disabled = true
			
			return
		
		item_count_label.text = "Objeto %d de %d" % [
				current_item_index + 1,
				inventory_items.size()
		]
		
		if current_state == InventoryState.INSPECTING:
			inspect_hint_label.text = "Flechas: Rotar"
			
			inspect_button.text = "Regresar: [Esc]"
			inspect_button.disabled = false
			
		else:
			
			inspect_hint_label.text= "Q: Anterior                                                         E: Siguiente"
			
			inspect_button.text = "Examinar [Enter]"
			
			inspect_button.disabled = not is_instance_valid(current_model)
			
		
		
