// Un hueco en el suelo del mapa: ps1_suelo y ps1_pasto no se dibujan dentro de un rectangulo (la escalera
// de las cañerías del arroyo, MuroColonia._boca). `hoyo_eje` = (centro x, centro z, adentro x, adentro z):
// el +Z local del rectangulo es `adentro` y su X es (adentro.z, -adentro.x), como el nodo Boca.
// `hoyo_medida` = (x min, x max, z min, z max) en ese marco; todo en cero = sin hueco (cualquier otra escena).
global uniform vec4 hoyo_eje;
global uniform vec4 hoyo_medida;

bool en_hoyo(vec3 mundo) {
	if (hoyo_medida.y <= hoyo_medida.x || mundo.y < -1.0 || mundo.y > 1.0) {
		return false;
	}
	vec2 d = mundo.xz - hoyo_eje.xy;
	float x = dot(d, vec2(hoyo_eje.w, -hoyo_eje.z));
	float z = dot(d, hoyo_eje.zw);
	return x > hoyo_medida.x && x < hoyo_medida.y && z > hoyo_medida.z && z < hoyo_medida.w;
}
