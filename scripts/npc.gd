extends Node3D

@export var tint: Color = Color.WHITE
@export var dialogue: String = ""

var _player_inside: bool = false
var _talking: bool = false
var _using_keyboard: bool = true

@onready var _prompt: Sprite3D = $Prompt
@onready var _bubble: Sprite3D = $Bubble
@onready var _key_panel: PanelContainer = $PromptViewport/Center/Bar/Row/Key
@onready var _key_label: Label = $PromptViewport/Center/Bar/Row/Key/KeyLabel
@onready var _dialogue_label: Label = $BubbleViewport/BubbleRoot/Dialogue


func _ready() -> void:
	add_to_group("npc")
	_apply_tint(tint)
	_dialogue_label.text = dialogue
	_prompt.texture = $PromptViewport.get_texture()
	_bubble.texture = $BubbleViewport.get_texture()
	_using_keyboard = Input.get_connected_joypads().is_empty()
	_apply_prompt_key()
	_prompt.visible = false
	_bubble.visible = false
	_play_idle()
	var area := $TalkArea as Area3D
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_set_prompt_device(true)
	elif event is InputEventJoypadButton and event.pressed:
		_set_prompt_device(false)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.35:
		_set_prompt_device(false)


func is_player_inside() -> bool:
	return _player_inside


func interact() -> void:
	if not _player_inside:
		return
	_talking = true
	_prompt.visible = false
	_bubble.visible = true


func _on_body_entered(body: Node3D) -> void:
	if not body is Player:
		return
	_player_inside = true
	_talking = false
	_bubble.visible = false
	_prompt.visible = true


func _on_body_exited(body: Node3D) -> void:
	if not body is Player:
		return
	_player_inside = false
	_talking = false
	_prompt.visible = false
	_bubble.visible = false


func _set_prompt_device(keyboard: bool) -> void:
	if keyboard == _using_keyboard:
		return
	_using_keyboard = keyboard
	_apply_prompt_key()


func _apply_prompt_key() -> void:
	if _using_keyboard:
		_key_label.text = "Space"
		_key_panel.custom_minimum_size = Vector2(0, 48)
	else:
		_key_label.text = "X"
		_key_panel.custom_minimum_size = Vector2(52, 48)


func _apply_tint(color: Color) -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_idx in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface_idx)
			if source == null:
				continue
			var tinted := source.duplicate()
			if tinted is BaseMaterial3D:
				(tinted as BaseMaterial3D).albedo_color = color
			mesh_instance.set_surface_override_material(surface_idx, tinted)


func _play_idle() -> void:
	var animation_player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		return
	for animation_name in animation_player.get_animation_list():
		var clip_name := String(animation_name)
		if clip_name != "Idle" and not clip_name.ends_with("|Idle"):
			continue
		var animation := animation_player.get_animation(clip_name)
		animation.loop_mode = Animation.LOOP_LINEAR
		animation_player.play(clip_name)
		return
