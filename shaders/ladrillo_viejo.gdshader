shader_type spatial;
// El ladrillo viejo de las cañerías del arroyo (TunelesNivel) y de su boca en map_test (MuroColonia._boca):
// ladrillos que faltan, mugre, moho que sube del piso y baja de la clave, escurridos y salitre. Todo en
// coordenadas del tunel (`al_tunel`: la inversa de su transform), asi la boca de afuera y el tunel de
// adentro se ven igual. Los muros planos se proyectan por su normal; la boveda usa sus UV (`usar_uv`).
render_mode cull_disabled;

uniform sampler2D ladrillo : source_color, filter_nearest, repeat_enable;
uniform sampler2D ruido : filter_nearest, repeat_enable;      // manchas grandes
uniform sampler2D detalle : filter_nearest, repeat_enable;    // borde del moho, escurridos, salitre
uniform mat4 al_tunel = mat4(1.0);
uniform bool usar_uv = false;
uniform vec2 tam = vec2(1.6, 0.8);       // m que mide la textura (4 ladrillos por 8 hiladas)
uniform vec3 color_moho : source_color = vec3(0.07, 0.09, 0.05);
uniform vec3 color_salitre : source_color = vec3(0.72, 0.71, 0.64);
uniform float piso = 0.0;                // altura del pasillo (el moho sube de ahi)
uniform float clave = 4.0;               // altura de la clave (de ahi escurre)
uniform float deterioro = 1.0;

varying vec3 tunel;
varying vec3 normal_tunel;

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	tunel = (al_tunel * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_tunel = abs((al_tunel * MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p;
	if (usar_uv) {
		p = UV * tam;
	} else if (normal_tunel.x > normal_tunel.z && normal_tunel.x > normal_tunel.y) {
		p = vec2(tunel.z, tunel.y);
	} else if (normal_tunel.z >= normal_tunel.y) {
		p = vec2(tunel.x, tunel.y);
	} else {
		p = tunel.xz;
	}
	vec2 t = p / tam;
	vec3 c = texture(ladrillo, t).rgb;
	float g = texture(ruido, p * 0.05).r;
	float f = texture(detalle, p * 0.2).r;
	// Cada ladrillo (8 hiladas y 4 ladrillos por textura, las impares corridas medio): unos faltan
	// (queda el hueco negro), mas donde el muro esta mas comido, y otros estan manchados
	float fila = floor(t.y * 8.0);
	float col = floor(t.x * 4.0 - (mod(fila, 2.0) > 0.5 ? 0.5 : 0.0));
	float h = azar(vec2(col, fila));
	if (h < 0.09 * deterioro * (0.4 + g)) {
		c = vec3(0.04, 0.035, 0.03);
	} else if (h > 0.9) {
		c *= 0.55;
	}
	// Mugre pareja por manchas grandes
	c *= mix(0.45, 1.0, smoothstep(0.2, 0.8, g));
	// Moho: sube del piso y baja de la clave
	float y = tunel.y;
	float abajo = 1.0 - smoothstep(piso, piso + 1.5, y);
	float arriba = smoothstep(clave - 1.6, clave, y);
	float m = g * 0.8 + f * 0.3 + abajo * 0.55 + arriba * 0.4 - 0.78;
	c = mix(c, color_moho, smoothstep(0.0, 0.14, m) * 0.85 * deterioro);
	// Escurridos: ruido estirado a lo alto
	float escurre = texture(detalle, vec2(p.x * 0.8, y * 0.05)).r;
	c *= 1.0 - smoothstep(0.68, 0.8, escurre) * 0.5 * deterioro;
	// Salitre blanco en las juntas de arriba
	float s = texture(detalle, p * 0.35 + vec2(0.37)).r;
	c = mix(c, color_salitre, smoothstep(0.8, 0.88, s) * 0.45 * deterioro * (1.0 - abajo));
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
