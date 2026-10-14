extends Node3D

const _IDLE := "Idle"
const _WALK := "Walk"
const _SPRINT_PLAYBACK := 1.9
const _SPRINT_LEAN := 0.1
const _BOB_HEIGHT := 0.035
const _BOB_STEPS_PER_SECOND := 5.5

var _animation_player: AnimationPlayer
var _armature: Node3D
var _armature_rest := Vector3.ZERO
var _body_rest_rotation := Vector3.ZERO
var _is_sprinting := false
var _bob_time := 0.0


func _ready() -> void:
	_body_rest_rotation = rotation
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


func _process(delta: float) -> void:
	if _armature != null:
		_armature.position = _armature_rest
	rotation = _body_rest_rotation
	if not _is_sprinting:
		_bob_time = 0.0
		return
	_bob_time += delta
	rotation.x = _body_rest_rotation.x + _SPRINT_LEAN
	if _armature != null:
		var bounce := absf(sin(_bob_time * TAU * _BOB_STEPS_PER_SECOND))
		_armature.position.y = _armature_rest.y + bounce * _BOB_HEIGHT


func update_animation(is_moving: bool, is_airborne: bool, is_sprinting: bool = false) -> void:
	if _animation_player == null:
		return
	_is_sprinting = is_sprinting and is_moving and not is_airborne
	if is_airborne or not is_moving:
		_animation_player.speed_scale = 1.0
		_play(_IDLE)
	else:
		_animation_player.speed_scale = _SPRINT_PLAYBACK if _is_sprinting else 1.0
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
