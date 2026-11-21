shader_type spatial;
// El agua del canal de las cañerías del arroyo (TunelesNivel, y su boca en map_test): drenaje cafe
// revuelto con Serenol. Manchas cafes oscuras y claras, y manchas de Serenol azul brillante (emisivas:
// el tunel esta casi a oscuras) que corren a lo largo del canal hacia -Z local, hacia el carcamo.
// Todo en coordenadas locales de la malla, asi la boca de afuera, que esta girada, corre igual.
// Texel fino (`pixel`, JJ: los de 6 cm se veian muy grandes) y colores en degradado (`suave`: 0 = cortes
// duros de paleta, 1 = mezcla suave). Opaco: el drenaje no deja ver el fondo, y sin transparencia no se
// ordena con nada.
render_mode cull_disabled;

uniform vec3 cafe_oscuro : source_color = vec3(0.10, 0.065, 0.03);
uniform vec3 cafe_claro : source_color = vec3(0.30, 0.20, 0.09);
uniform vec3 serenol : source_color = vec3(0.15, 0.55, 1.0);
uniform float velocidad = 0.6;        // m/s que corre el agua
uniform float pixel = 0.015;          // tamaño del texel en m (0 = sin pixelar)
uniform float cuadros = 30.0;         // cuadros por segundo de la animacion
uniform float suave = 1.0;            // ancho del degradado entre colores
uniform float cambia = 1.0;           // cuanto crecen y se encogen las manchas (0 = fijas)
uniform float ritmo = 0.35;           // que tan rapido cambian de tamaño
uniform float cuanto_serenol = 0.4;   // 0 = nada de Serenol, 1 = casi todo
uniform float brillo_serenol = 2.2;
uniform float brillo_cafe = 0.25;     // un poco de luz propia: las luces del canal estan bajo el agua

varying vec3 local;

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(azar(i), azar(i + vec2(1.0, 0.0)), f.x),
		mix(azar(i + vec2(0.0, 1.0)), azar(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return ruido(p) * 0.6 + ruido(p * 2.1 + 7.3) * 0.3 + ruido(p * 4.3 + 1.7) * 0.1;
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	float t = floor(TIME * cuadros) / cuadros;
	vec2 p = pixel > 0.0 ? floor(local.xz / pixel) * pixel : local.xz;
	// Corre hacia -Z: se muestrea mas atras conforme pasa el tiempo. Un poco de remolino de lado a lado
	vec2 cafe_p = vec2(p.x * 1.6, p.y + t * velocidad);
	cafe_p.x += (ruido(cafe_p * 0.7 + 3.1) - 0.5) * 0.8;
	// Las manchas cambian de forma: se mezclan dos ruidos que van y vienen con el tiempo
	float vaiven = 0.5 + 0.5 * sin(t * ritmo * 2.3);
	float c = mix(fbm(cafe_p * 1.3), fbm(cafe_p * 1.3 + vec2(17.0, 3.0)), vaiven * 0.5 * cambia);
	// El Serenol va un poco mas rapido que el drenaje, en manchas algo estiradas a lo largo
	vec2 ser_p = vec2(p.x * 1.5, (p.y + t * velocidad * 1.35) * 0.75);
	ser_p.x += (ruido(ser_p * 1.1 + 11.0) - 0.5) * 1.2;
	float s = fbm(ser_p * 1.2 + 5.0);
	// Degradados: de cafe oscuro a claro, a espuma sucia, y el Serenol con un borde verdoso donde se revuelve
	float a = 0.08 * suave + 0.001;
	vec3 espuma = mix(cafe_claro, vec3(0.42, 0.33, 0.18), 0.5);
	vec3 color = mix(cafe_oscuro, cafe_claro, smoothstep(0.55 - a * 2.0, 0.55 + a * 2.0, c));
	color = mix(color, espuma, smoothstep(0.72 - a, 0.72 + a, c));
	// Y crecen y se encogen: el umbral sube y baja por zonas, cada una a su tiempo
	float zona = ruido(p * vec2(1.0, 0.35) + vec2(0.0, t * velocidad * 0.3));
	float late = sin(t * ritmo * 6.2832 + zona * 6.2832);
	float umbral = 1.0 - cuanto_serenol + late * 0.09 * cambia;
	c += late * 0.05 * cambia;
	float azul = smoothstep(umbral - a * 0.5, umbral + a, s);
	float orilla = smoothstep(umbral - 0.06 - a, umbral - 0.03, s) * (1.0 - azul);
	color = mix(color, mix(cafe_claro, serenol, 0.45), orilla);
	color = mix(color, serenol, azul);
	ALBEDO = color;
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
	EMISSION = color * (brillo_cafe + azul * brillo_serenol + orilla * 0.5);
}
