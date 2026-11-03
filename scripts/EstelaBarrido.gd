extends MeshInstance3D

# La estela del barrido: una cinta en el mundo entre la mano y la punta del arma, que Barrido.gd
# va dejando mientras el brazo pasa. Asi siempre sigue al brazo y a donde mira el personaje, desde
# cualquier angulo (un dibujo plano de cara a la camara se veia siempre de lado). Corre con el
# tiempo del juego: se queda en la congelada del golpe como todo lo demas.

const VIDA := 0.18             # s que dura cada pedazo
const DESDE := 0.45            # la orilla de adentro, en fraccion del largo desde la mano
# Una media luna solida como la hoja de la barrida (golpe_barrida en tools/pixelfx/efectos.json):
# franjas de su paleta, de la orilla clara de la punta hacia adentro mas oscuro, sin mezclar. UV.x va
# de adentro (0) a la punta (1) y UV.y es la edad: lo viejo se adelgaza hasta quedar en la orilla
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

const vec3 PALETA[6] = vec3[](
	vec3(0.110, 0.133, 0.188), vec3(0.180, 0.212, 0.282), vec3(0.290, 0.329, 0.408),
	vec3(0.431, 0.478, 0.565), vec3(0.604, 0.651, 0.729), vec3(0.816, 0.847, 0.902));

void fragment() {
	float borde = UV.y * 0.9;
	if (UV.x < borde) {
		discard;
	}
	float k = (UV.x - borde) / (1.0 - borde);
	int paso = clamp(int(k * 6.0), 0, 5);
	ALBEDO = pow(PALETA[paso], vec3(2.2));
}
"""

static var _material: ShaderMaterial

var _pedazos: Array = []       # [mano, punta, edad]
var _malla := ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _malla
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
	material_override = _material
	set_process(false)


func agregar(mano: Vector3, punta: Vector3) -> void:
	_pedazos.append([mano.lerp(punta, DESDE), punta, 0.0])
	set_process(true)


func _process(delta: float) -> void:
	for pedazo: Array in _pedazos:
		pedazo[2] += delta
	while not _pedazos.is_empty() and _pedazos[0][2] >= VIDA:
		_pedazos.pop_front()
	_malla.clear_surfaces()
	if _pedazos.size() < 2:
		if _pedazos.is_empty():
			set_process(false)
		return
	_malla.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for pedazo: Array in _pedazos:
		var edad: float = pedazo[2] / VIDA
		_malla.surface_set_uv(Vector2(0.0, edad))
		_malla.surface_add_vertex(pedazo[0])
		_malla.surface_set_uv(Vector2(1.0, edad))
		_malla.surface_add_vertex(pedazo[1])
	_malla.surface_end()
