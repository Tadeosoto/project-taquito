extends MeshInstance3D

# La estela del barrido: una cinta en el mundo entre la mano y la punta del arma, que Barrido.gd
# va dejando mientras el brazo pasa. Asi siempre sigue al brazo y a donde mira el personaje, desde
# cualquier angulo (un dibujo plano de cara a la camara se veia siempre de lado). Corre con el
# tiempo del juego: se queda en la congelada del golpe como todo lo demas.

const VIDA := 0.16             # s que dura cada pedazo
const DESDE := 0.35            # la orilla de adentro, en fraccion del largo desde la mano
const COLOR_PUNTA := Color(0.96, 0.93, 0.84, 1.0)
const COLOR_ADENTRO := Color(0.55, 0.45, 0.32, 0.15)
# Transparencia en cuadritos de 2 x 2 pixeles, sin mezclar: como el difuminado del resto del juego
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

void fragment() {
	ivec2 p = ivec2(FRAGCOORD.xy * 0.5) % 2;
	float umbral = (float((p.x * 2 + p.y * 3) % 4) + 0.5) / 4.0;
	if (COLOR.a < umbral) {
		discard;
	}
	ALBEDO = COLOR.rgb;
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
		var queda: float = 1.0 - pedazo[2] / VIDA
		var punta := COLOR_PUNTA
		punta.a *= queda
		_malla.surface_set_color(COLOR_ADENTRO)
		_malla.surface_add_vertex(pedazo[0])
		_malla.surface_set_color(punta)
		_malla.surface_add_vertex(pedazo[1])
	_malla.surface_end()
