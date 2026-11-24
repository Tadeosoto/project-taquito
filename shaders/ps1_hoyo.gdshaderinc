// Un hueco en el suelo del mapa: ps1_suelo y ps1_pasto no se dibujan dentro de un rectangulo (la escalera
// de las cañerías del arroyo, MuroColonia._boca). `hoyo_eje` = (centro x, centro z, adentro x, adentro z):
// el +Z local del rectangulo es `adentro` y su X es (adentro.z, -adentro.x), como el nodo Boca.
// `hoyo_medida` = (x min, x max, z min, z max) en ese marco; todo en cero = sin hueco (cualquier otra escena).
// Dos huecos: `hoyo_*` (la entrada) y `hoyo2_*` (la salida del carcamo, la escalera de la punta norte).
global uniform vec4 hoyo_eje;
global uniform vec4 hoyo_medida;
global uniform vec4 hoyo2_eje;
global uniform vec4 hoyo2_medida;

bool en_un_hoyo(vec3 mundo, vec4 eje, vec4 medida) {
	if (medida.y <= medida.x) {
		return false;
	}
	vec2 d = mundo.xz - eje.xy;
	float x = dot(d, vec2(eje.w, -eje.z));
	float z = dot(d, eje.zw);
	return x > medida.x && x < medida.y && z > medida.z && z < medida.w;
}

bool en_hoyo(vec3 mundo) {
	if (mundo.y < -1.0 || mundo.y > 1.0) {
		return false;
	}
	return en_un_hoyo(mundo, hoyo_eje, hoyo_medida) || en_un_hoyo(mundo, hoyo2_eje, hoyo2_medida);
}
