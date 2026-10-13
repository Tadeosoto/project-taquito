extends CharacterBody3D

var camera_sensitivity = 2.5
var camera_pitch = -15.0

var rotation_speed = 5

var speed = 5.0
var gravity = 20.0
var acceleration = 15.0
var jump_velocity: float = 13.0

func _physics_process(delta):
		var input_direction = Input.get_vector(
			"move_left",
			"move_right",
			"move_forward",
			"move_backward"
		)
		
		
		var forward = -$CameraPivot.global_transform.basis.z
		var right = $CameraPivot.global_transform.basis.x
		
		forward.y = 0
		right.y = 0
		
		forward = forward.normalized()
		right = right.normalized()
		
		print(Input.get_connected_joypads())
		print(input_direction)

		var direction = (
			right * input_direction.x
			+ forward * - input_direction.y
		)

		if direction.length_squared() > 0.01:
			
			var look_target = $Frijol.global_position + direction
		
			var target_transform = $Frijol.global_transform.looking_at(look_target, Vector3.UP)
		
			$Frijol.global_transform = $Frijol.global_transform.interpolate_with(
				target_transform, 
				rotation_speed * delta
		)

		velocity.x = move_toward(
			velocity.x,
			direction.x * speed,
			acceleration * delta
		)
		velocity.z = move_toward(
			velocity.z,
			direction.z * speed,
			acceleration * delta
		)
		
		if not is_on_floor():
			velocity.y -= gravity * delta
			
		var camera_input = Input.get_vector(
			"camera_left",
			"camera_right",
			"camera_up",
			"camera_down",
			0.2
		)
		
		if camera_input.length() > 0.2:
		
			$CameraPivot.rotation.y -= camera_input.x * camera_sensitivity * delta
		
			camera_pitch -= camera_input.y * camera_sensitivity * 50.0 * delta
		
		camera_pitch = clamp(camera_pitch, -60.0, 30.0)
		
		$CameraPivot/SpringArm3D.rotation_degrees.x = camera_pitch
		
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0.0

		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity
		
		move_and_slide()

		var ninja := $Frijol/Ninja
		if ninja.has_method("update_animation"):
			ninja.update_animation(direction.length_squared() > 0.01, not is_on_floor())
