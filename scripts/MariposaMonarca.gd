class_name MariposaMonarca
extends MeshInstance3D

# Una mariposa monarca chiquita en pixel art que sale volando de la punta del arma con la
# estocada cuando la estela es la monarca (EstelaBarrido.estilo, JJ). Un cuadro de cara a la camara con el dibujo de abajo;
# aletea encogiendo las alas a lo ancho, sube revoloteando y se deshace en pixeles al final.
# Corre con el tiempo del juego, asi se queda en la congelada del golpe.

const TAMANO := 0.16          # m de ancho con las alas abiertas (JJ: 0.32 se veia grande)
const VIDA := 2.2             # s
const DESHACE := 0.6          # s finales en que se deshace
const SALE := 1.4             # m/s hacia donde fue la estocada
const SUBE := 0.9             # m/s
const ALETEO := 22.0          # rad/s
# Media mariposa: la izquierda, de la punta del ala (columna 0) al cuerpo (7); la derecha es el
# espejo. K negro, O naranja, D naranja oscuro, W blanco
const DIBUJO := [
	"......K.",
	".KKK...K",
	"KOOKKK.K",
	"KWOOOKKK",
	"KKOKODKK",
	"WKOOKODK",
	"KWKOOKDK",
	".KKKKKKK",
	"..KOKODK",
	".KOOKODK",
	".WKOOKKK",
	"..WKKK..",
]
const COLORES := {"K": Color(0.05, 0.035, 0.03), "O": Color(0.96, 0.5, 0.08),
	"D": Color(0.72, 0.28, 0.04), "W": Color(0.98, 0.96, 0.9)}
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D dibujo : filter_nearest;
instance uniform float edad = 0.0;
instance uniform float fase = 0.0;
uniform float aleteo = 22.0;

void vertex() {
	// De cara a la camara; las alas se cierran a lo ancho al aletear
	float abre = 0.25 + 0.75 * abs(cos(TIME * aleteo + fase));
	VERTEX.x *= abre;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 c = texture(dibujo, UV);
	vec2 celda = floor(UV * vec2(16.0, 12.0));
	float hoyo = fract(sin(dot(celda, vec2(12.9898, 78.233)) + fase) * 43758.5453);
	if (c.a < 0.5 || hoyo < edad) {
		discard;
	}
	ALBEDO = pow(c.rgb, vec3(2.2));
}
"""

static var _material: ShaderMaterial
static var _quad: QuadMesh

var _t := 0.0
var _vel := Vector3.ZERO
var _giro := 0.0       # hacia donde va virando, para que no vuele derecho


# Suelta una en `donde`, saliendo hacia `hacia` (horizontal)
static func soltar(padre: Node, donde: Vector3, hacia: Vector3) -> MariposaMonarca:
	if padre == null:
		return null
	var m := MariposaMonarca.new()
	padre.add_child(m)
	m.global_position = donde
	var plano := Vector3(hacia.x, 0.0, hacia.z)
	m._vel = (plano.normalized() if plano.length_squared() > 0.001 else Vector3.FORWARD) * SALE + Vector3.UP * SUBE
	return m


func _ready() -> void:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = Shader.new()
		_material.shader.code = SHADER
		_material.set_shader_parameter("dibujo", _dibujo())
		_material.set_shader_parameter("aleteo", ALETEO)
		_quad = QuadMesh.new()
		_quad.size = Vector2(TAMANO, TAMANO * 12.0 / 16.0)
		# El shader voltea el cuadro hacia la camara: sin esto se recortaba al verlo de lado
		_quad.custom_aabb = AABB(Vector3.ONE * -0.5, Vector3.ONE)
	mesh = _quad
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	_giro = randf_range(-1.0, 1.0)
	set_instance_shader_parameter("fase", randf() * TAU)
	set_instance_shader_parameter("edad", 0.0)


func _process(delta: float) -> void:
	_t += delta
	if _t >= VIDA:
		queue_free()
		return
	# Frena lo que traia de la estocada, sigue subiendo poco a poco y vira de un lado a otro
	var plano := Vector3(_vel.x, 0.0, _vel.z)
	plano = plano.rotated(Vector3.UP, sin(_t * 2.3 + _giro * 3.0) * 2.5 * delta)
	plano = plano.move_toward(plano.normalized() * 0.5, 1.5 * delta)
	_vel = Vector3(plano.x, move_toward(_vel.y, 0.45, 1.0 * delta), plano.z)
	# Cada aleteo la sube un poquito: revolotea en vez de flotar parejo
	var brinco := sin(_t * ALETEO * 0.5) * 0.35
	global_position += (_vel + Vector3.UP * brinco) * delta
	set_instance_shader_parameter("edad", clampf((_t - (VIDA - DESHACE)) / DESHACE, 0.0, 1.0))


# 16 x 12 pixeles: la mitad de DIBUJO y su espejo
static func _dibujo() -> ImageTexture:
	var img := Image.create(16, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in DIBUJO.size():
		var fila: String = DIBUJO[y]
		for x in 8:
			var letra := fila[x]
			if COLORES.has(letra):
				img.set_pixel(x, y, COLORES[letra])
				img.set_pixel(15 - x, y, COLORES[letra])
	return ImageTexture.create_from_image(img)
