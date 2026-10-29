@tool
class_name Colchon
extends Node3D

# Colchon tirado en el piso (el cuarto del punto), con manchas y, si `con_alguien`,
# alguien acostado boca arriba: por ahora el ninja de los NPC, con su animacion de
# espera muy lenta para que parezca que respira. El origen es el centro de su base.

const PERSONA := preload("res://models/ninja_male.fbx")
const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")

@export var tamano := Vector3(1.35, 0.18, 1.9):
	set(valor):
		tamano = valor
		_reconstruir()
@export var color := Color(0.86, 0.8, 0.62):
	set(valor):
		color = valor
		_reconstruir()
@export var con_alguien := true:
	set(valor):
		con_alguien = valor
		_reconstruir()
# Hacia donde queda la cabeza, en grados sobre el colchon (0 = hacia -Z)
@export var giro_persona := 15.0:
	set(valor):
		giro_persona = valor
		_reconstruir()
@export var semilla := 0:
	set(valor):
		semilla = valor
		_reconstruir()

var _partes: Node3D


func _ready() -> void:
	_reconstruir()


func _reconstruir() -> void:
	if not is_inside_tree():
		return
	if _partes:
		_partes.queue_free()
	_partes = Node3D.new()
	add_child(_partes, false, Node.INTERNAL_MODE_FRONT)
	var malla := BoxMesh.new()
	malla.size = tamano
	var material := StandardMaterial3D.new()
	material.albedo_texture = _tela()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 1.6
	malla.material = material
	var colchon := MeshInstance3D.new()
	colchon.mesh = malla
	colchon.position.y = tamano.y / 2
	_partes.add_child(colchon)
	# Ribete de la orilla
	var ribete := BoxMesh.new()
	ribete.size = Vector3(tamano.x + 0.01, 0.025, tamano.z + 0.01)
	var gris := ShaderMaterial.new()
	gris.shader = PS1_SHADER
	gris.set_shader_parameter("tint", color.darkened(0.35))
	gris.set_shader_parameter("affine_enabled", false)
	gris.set_shader_parameter("wobble_enabled", false)
	ribete.material = gris
	for y in [0.02, tamano.y - 0.02]:
		var borde := MeshInstance3D.new()
		borde.mesh = ribete
		borde.position.y = y
		_partes.add_child(borde)
	if con_alguien:
		_persona()


# Boca arriba (el modelo ve a +Z: girado -90 en X queda viendo al techo, con la cabeza
# hacia -Z) sobre el colchon
func _persona() -> void:
	var giro := Node3D.new()
	giro.rotation_degrees.y = giro_persona
	giro.position = Vector3(0, tamano.y + 0.08, 0.35)
	_partes.add_child(giro)
	var persona := PERSONA.instantiate() as Node3D
	persona.scale = Vector3.ONE * 0.6
	persona.rotation_degrees = Vector3(-90, 0, 0)
	giro.add_child(persona)
	var animaciones := persona.find_children("*", "AnimationPlayer", true, false)
	if animaciones.is_empty():
		return
	var animacion := animaciones[0] as AnimationPlayer
	for nombre in animacion.get_animation_list():
		if nombre.ends_with("Idle"):
			animacion.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR
			animacion.speed_scale = 0.25
			animacion.play(nombre)


# Tela acolchada con rombos y manchas amarillentas
func _tela() -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var ruido := FastNoiseLite.new()
	ruido.seed = semilla
	ruido.frequency = 0.04
	var lado := 64
	var imagen := Image.create(lado, lado, false, Image.FORMAT_RGB8)
	for y in lado:
		for x in lado:
			var c := color
			# Costuras en rombo cada 16 px
			if (x + y) % 16 == 0 or (x - y + lado) % 16 == 0:
				c = c.darkened(0.18)
			var mancha := ruido.get_noise_2d(x, y)
			if mancha > 0.25:
				c = c.lerp(Color(0.6, 0.48, 0.25), clampf((mancha - 0.25) * 2.5, 0.0, 0.7))
			c = c.darkened(rng.randf() * 0.06)
			imagen.set_pixel(x, y, c)
	imagen.generate_mipmaps()
	return ImageTexture.create_from_image(imagen)
