extends Node3D

const _IDLE := "Idle"
const _WALK := "Walk"

var _animation_player: AnimationPlayer
var _armature: Node3D
var _armature_rest := Vector3.ZERO


func _ready() -> void:
	_animation_player = _find_animation_player()
	var armature := find_child("CharacterArmature", true, false)
	if armature is Node3D and armature != self:
		_armature = armature
		_armature_rest = _armature.position
	if _animation_player == null:
		return
	_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	_force_loop(_IDLE)
	_force_loop(_WALK)
	_play(_IDLE)
	process_priority = 100


func _process(_delta: float) -> void:
	if _armature != null:
		_armature.position = _armature_rest


func update_animation(is_moving: bool, is_airborne: bool) -> void:
	if _animation_player == null:
		return
	if is_airborne or not is_moving:
		_play(_IDLE)
	else:
		_play(_WALK)


func _play(hint: String) -> void:
	var clip := _resolve_clip(hint)
	if clip == "":
		return
	if _animation_player.current_animation == clip and _animation_player.is_playing():
		return
	_animation_player.play(clip)


func _resolve_clip(hint: String) -> String:
	if _animation_player == null:
		return ""
	for animation_name in _animation_player.get_animation_list():
		var clip_name := String(animation_name)
		if clip_name == hint or clip_name.ends_with("|" + hint):
			return clip_name
	return ""


func _force_loop(hint: String) -> void:
	var clip := _resolve_clip(hint)
	if clip == "":
		return
	var animation := _animation_player.get_animation(clip)
	animation.loop_mode = Animation.LOOP_LINEAR


func _find_animation_player() -> AnimationPlayer:
	var player := find_child("AnimationPlayer", true, false)
	if player is AnimationPlayer:
		return player
	return null
