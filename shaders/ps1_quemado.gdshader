shader_type spatial;
// Carro quemado (CarrosColonia.gd): la textura del modelo oscurecida, manchas negras de hollin (ruido
// por cuadritos del modelo, mas abajo del techo menos) y sin vidrios: lo que en la textura es casi
// negro (las ventanas) sale negro del todo, como un hueco. Misma etapa de vertices que ps1_combined.

#include "res://shaders/ps1_vertex.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_nearest;
// Cuanto se oscurece la pintura que sobrevive
uniform float oscuro : hint_range(0.0, 1.0) = 0.65;
// Lo que cubre el hollin (0 nada, 1 todo) y el tamano de las manchas (cuadros por metro)
uniform float hollin : hint_range(0.0, 1.0) = 0.45;
uniform float cuadros = 7.0;
// Luminosidad bajo la que un texel es vidrio
uniform float vidrio_umbral = 0.13;

varying vec2 affine_uv;
varying vec3 local_pos;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float ruido(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	local_pos = VERTEX;
	vec3 vertex = VERTEX;
	vec2 uv_out;
	vec4 clip_position = ps1_vertex(vertex, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, uv_out);
	VERTEX = vertex;
	affine_uv = uv_out;
	POSITION = clip_position;
}

void fragment() {
	vec3 tex = texture(albedo_texture, affine_uv).rgb;
	float luz = dot(tex, vec3(0.299, 0.587, 0.114));
	// La pintura que sobrevive, medio ceniza y oxido: asi el hollin se lee aunque el carro fuera oscuro
	vec3 c = mix(tex * oscuro, vec3(0.34, 0.27, 0.22), 0.45);
	// Hollin en cuadritos: dos escalas de ruido; arriba (techo, cofre) se acumula mas
	vec3 q = floor(local_pos * cuadros) / cuadros;
	float n = ruido(q * 1.8) * 0.65 + ruido(q * 4.3 + 7.0) * 0.35;
	n += (local_pos.y - 0.7) * 0.18;
	float mancha = smoothstep(1.0 - hollin - 0.06, 1.0 - hollin + 0.06, n);
	c = mix(c, vec3(0.01), mancha);
	if (luz < vidrio_umbral) {
		c = vec3(0.0);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
