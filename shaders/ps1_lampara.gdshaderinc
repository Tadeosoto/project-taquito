// Brillo de una lampara (0..1) con su INSTANCE_CUSTOM (prendida, parpadea, semilla,
// umbral): se prende cuando `noche` pasa su umbral y parpadea igual que
// Alumbrado.parpadeo() en scripts/map/Alumbrado.gd. Necesita hash_entero de
// ps1_deterioro.gdshaderinc (incluirlo antes).

global uniform float noche;
global uniform float alumbrado_tiempo;

float lampara_parpadeo(int semilla, float t) {
	if (hash_entero(ivec2(semilla + 101, int(floor(t / 1.5)))) < 0.4) {
		return 1.0;
	}
	float h = hash_entero(ivec2(semilla + 202, int(floor(t * 14.0))));
	return h < 0.45 ? 0.0 : (h < 0.6 ? 0.35 : 1.0);
}

float lampara_brillo(vec4 custom) {
	float b = custom.x * smoothstep(custom.w, custom.w + 0.05, noche);
	if (custom.y > 0.5) {
		b *= lampara_parpadeo(int(custom.z + 0.5), alumbrado_tiempo);
	}
	return b;
}
