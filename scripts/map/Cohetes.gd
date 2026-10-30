class_name Cohetes
extends Node3D

# Cohetes de la maquinita cuando alguien gana dinero: suben dejando estela y truenan en
# el cielo. Van en la raiz de la escena y no en la maquina: esta se libera al alejarse
# (MapPuntos) y en coop cada jugador los lanza desde la posicion que le manden.

const COLORES := [Color(1.0, 0.25, 0.2), Color(1.0, 0.85, 0.1), Color(0.3, 1.0, 0.45),
		Color(0.35, 0.6, 1.0), Color(1.0, 0.4, 0.9), Color(1.0, 0.6, 0.15)]
const ALTURA := Vector2(25.0, 40.0)
const SUBIDA := 1.1        # s que tarda en subir
const ENTRE_COHETES := 0.3 # s
const TAMANO := 0.9        # m de cada chispa
const CHISPAS := 70
const VIDA_CHISPA := 1.6

static var _material: StandardMaterial3D
static var _cuadro: QuadMesh


# `cantidad` cohetes desde `posicion`, de uno en uno, repartidos para que no truenen juntos
static func lanzar(quien: Node, posicion: Vector3, cantidad: int) -> void:
	var cohetes := Cohetes.new()
	quien.get_tree().current_scene.add_child(cohetes)
	cohetes.global_position = posicion
	cohetes._disparar(cantidad)


func _disparar(cantidad: int) -> void:
	for i in cantidad:
		_cohete(Vector3(randf_range(-4.0, 4.0), randf_range(ALTURA.x, ALTURA.y), randf_range(-1.0, 3.0)))
		await get_tree().create_timer(ENTRE_COHETES).timeout
	await get_tree().create_timer(SUBIDA + VIDA_CHISPA + 1.0).timeout
	queue_free()


func _cohete(destino: Vector3) -> void:
	var cohete := Node3D.new()
	add_child(cohete)
	var estela := chispas(24, 0.5, Color(1.0, 0.85, 0.5), 0.35)
	estela.one_shot = false
	estela.explosiveness = 0.0
	estela.initial_velocity_max = 0.5
	cohete.add_child(estela)
	_voz(cohete, "silbido", 60.0)
	var tween := cohete.create_tween()
	tween.tween_property(cohete, "position", destino, SUBIDA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	estela.emitting = false
	var color: Color = COLORES.pick_random()
	var trueno := chispas(CHISPAS, VIDA_CHISPA, color, TAMANO)
	trueno.initial_velocity_min = 8.0
	trueno.initial_velocity_max = 13.0
	cohete.add_child(trueno)
	# Una luz breve, para que de noche alumbre algo
	var luz := OmniLight3D.new()
	luz.light_color = color
	luz.light_energy = 6.0
	luz.omni_range = 45.0
	cohete.add_child(luz)
	cohete.create_tween().tween_property(luz, "light_energy", 0.0, 0.5)
	_voz(cohete, "trueno", 250.0)


# Las chispas de un trueno o una estela: cuadros de frente a la camara, sin niebla (la
# del mapa los borraba a esa distancia) y sumando luz
static func chispas(cantidad: int, vida: float, color: Color, tamano: float) -> CPUParticles3D:
	if _material == null:
		var mancha := GradientTexture2D.new()
		mancha.width = 8
		mancha.height = 8
		mancha.fill = GradientTexture2D.FILL_RADIAL
		mancha.fill_from = Vector2(0.5, 0.5)
		mancha.fill_to = Vector2(0.5, 0.0)
		var borde := Gradient.new()
		borde.set_color(0, Color(1, 1, 1, 1))
		borde.set_color(1, Color(1, 1, 1, 0))
		mancha.gradient = borde
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_material.vertex_color_use_as_albedo = true
		_material.disable_fog = true
		_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_material.albedo_texture = mancha
		_cuadro = QuadMesh.new()
		_cuadro.size = Vector2.ONE
	var particulas := CPUParticles3D.new()
	particulas.mesh = _cuadro
	particulas.material_override = _material
	particulas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particulas.amount = cantidad
	particulas.lifetime = vida
	particulas.one_shot = true
	particulas.explosiveness = 1.0
	particulas.local_coords = false
	particulas.direction = Vector3.UP
	particulas.spread = 180.0
	particulas.gravity = Vector3(0.0, -5.0, 0.0)
	particulas.damping_min = 3.0
	particulas.damping_max = 5.0
	particulas.scale_amount_min = tamano * 0.7
	particulas.scale_amount_max = tamano
	var tono := Gradient.new()
	tono.set_color(0, Color(1, 1, 1, 1))
	tono.set_color(1, Color(color.r, color.g, color.b, 0))
	tono.add_point(0.15, color)
	particulas.color_ramp = tono
	# Mas grande el cielo que la vista: que no se apague por su AABB al subir
	particulas.visibility_aabb = AABB(Vector3.ONE * -60.0, Vector3.ONE * 120.0)
	return particulas


func _voz(padre: Node3D, nombre: String, alcance: float) -> void:
	var voz := AudioStreamPlayer3D.new()
	voz.stream = Maquinita.sonido(nombre)
	voz.unit_size = alcance * 0.25
	voz.max_distance = alcance
	padre.add_child(voz)
	voz.play()
