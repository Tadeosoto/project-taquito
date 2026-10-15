extends CanvasLayer

@onready var item_name_label: Label = $MainPanel/ItemName
@onready var item_description_label: RichTextLabel = ($MainPanel/ItemDescription)
@onready var item_pivot: Node3D = (
	$MainPanel/PreviewContainer/PreviewViewport/PreviewWorld/ItemPivot
)

@export var test_item : InventoryItemData

func _ready() -> void:
	
	if test_item == null:
		print("ERROR: No test item assigned to InventoryUI.")
			
	item_name_label.text  = test_item.item_name
			
	item_description_label.text = test_item.description

	if test_item == null:
		return
	
	item_name_label.text = test_item.item_name
	
	item_description_label.text = test_item.description
	
	display_item(test_item)
	
var current_model: Node3D

func display_item(item: InventoryItemData) -> void:
	
		if current_model:
				current_model.queue_free()
		
		if item.inspection_model == null:
				return
				
		current_model = item.inspection_model.instantiate()
		
		item_pivot.add_child(current_model)
