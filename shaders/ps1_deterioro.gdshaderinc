// Deterioro post-apocaliptico del mapa: pintura deslavada, escurrimientos,
// hollin, aplanado caido, grietas, baches y vidrios rotos. Cuanto, lo dice un
// ruido grande en el mundo (cuadras casi intactas y otras destruidas) por el
// maximo global `deterioro`. Los globales estan en project.godot [shader_globals].
// Lo incluyen ps1_facade, ps1_suelo, ps1_casa y ps1_combined.

#ifndef PS1_DETERIORO
#define PS1_DETERIORO

// 0 = todo nuevo, 1 = lo mas destruido
global uniform float deterioro;
// Tamano (m) de las zonas de deterioro
global uniform float deterioro_escala;
// textures/map/grietas.png (make_textures.py): grietas oscuras sobre blanco
global uniform sampler2D deterioro_grietas;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float ruido2(vec2 p) {
	return ruido(p) * 0.65 + ruido(p * 2.03 + 17.0) * 0.35;
}

// Hash con enteros: da lo mismo en la GPU y en GDScript (scripts/map/Deterioro.gd),
// el de sin() no (float de 32 contra 64 bits)
float hash_entero(ivec2 p) {
	uint h = uint(p.x) * 374761393u + uint(p.y) * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h & 16777215u) / 16777215.0;
}

float ruido_entero(vec2 p) {
	ivec2 i = ivec2(floor(p));
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_entero(i), hash_entero(i + ivec2(1, 0)), f.x),
		mix(hash_entero(i + ivec2(0, 1)), hash_entero(i + ivec2(1, 1)), f.x), f.y);
}

// Cuanto deterioro hay en (x, z): nunca menos de un cuarto del maximo. La misma
// formula esta en scripts/map/Deterioro.gd (bodegas, y despues spawn de zombies):
// si cambia aqui, cambiarla alla.
float zona_deterioro(vec2 xz) {
	vec2 p = xz / max(deterioro_escala, 1.0);
	float n = ruido_entero(p) * 0.65 + ruido_entero(p * 2.03 + 17.0) * 0.35;
	return deterioro * mix(0.25, 1.0, smoothstep(0.3, 0.7, n));
}

float grieta(vec2 uv) {
	return 1.0 - texture(deterioro_grietas, uv).r;
}

// Muro: `p` en el mundo, y = 0 en la calle. Cuadritos de 1/16 m para que se vea PS1.
vec3 muro_sucio(vec3 c, vec3 p, float zona) {
	p = floor(p * 16.0) / 16.0;
	// Coordenada a lo largo de la pared, sirve para paredes en x y en z
	float h = p.x + p.z;
	// Pintura deslavada por el sol
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * 0.95 + 0.04, zona * 0.5);
	// Escurrimientos: franjas que bajan desde arriba de cada piso
	float franja = ruido(vec2(h * 1.7, 0.0));
	float largo = ruido(vec2(h * 0.6, 3.0));
	float y_piso = fract(p.y / 2.5);
	float escurre = smoothstep(0.55, 0.8, franja) * smoothstep(1.0 - largo, 1.0, y_piso);
	c *= 1.0 - escurre * 0.45 * zona;
	// Mugre y salpicaduras a ras de piso
	float suelo = 1.0 - smoothstep(0.0, 0.9, p.y);
	c *= 1.0 - suelo * (0.2 + 0.2 * ruido(vec2(h * 3.0, p.y * 6.0))) * (0.4 + zona);
	// Hollin de incendios, solo en lo mas destruido
	float hollin = smoothstep(0.7, 0.85, ruido(vec2(h, p.y * 1.3) / 3.0 + 31.0)) * smoothstep(0.5, 0.8, zona);
	c = mix(c, vec3(0.08, 0.07, 0.06), hollin * 0.85);
	// Aplanado caido: se ve el block gris o el tabique
	float caido = ruido(vec2(h, p.y) * 1.1 + 53.0) * 0.75 + hash(floor(vec2(h, p.y) * 6.0)) * 0.25;
	if (caido > 1.0 - zona * 0.3) {
		vec3 block = mix(vec3(0.5, 0.49, 0.46), vec3(0.58, 0.32, 0.24), step(0.5, ruido(vec2(h, p.y) * 0.3 + 7.0)));
		vec2 b = vec2(h / 0.4 + step(1.0, mod(floor(p.y / 0.2), 2.0)) * 0.5, p.y / 0.2);
		float junta = max(step(0.85, fract(b.x)), step(0.75, fract(b.y)));
		c = block * (1.0 - junta * 0.35);
	}
	return c;
}

// Obra negra (la casa del punto): todo el muro en block gris sin aplanar, con sus
// juntas de mortero y algun block mas claro u oscuro. `p` en el mundo.
vec3 obra_negra(vec3 p) {
	p = floor(p * 16.0) / 16.0;
	float h = p.x + p.z;
	vec2 b = vec2(h / 0.4 + step(1.0, mod(floor(p.y / 0.2), 2.0)) * 0.5, p.y / 0.2);
	float junta = max(step(0.88, fract(b.x)), step(0.8, fract(b.y)));
	vec3 block = vec3(0.52, 0.51, 0.48) * (0.85 + 0.25 * hash(floor(b)));
	return mix(block, vec3(0.62, 0.6, 0.55), junta);
}

// Obra negra abandonada: manchas grandes de hollin (fogatas, incendios) que suben
// en lenguas, escurrimientos negros desde arriba, salitre claro y lodo abajo. Aunque
// la zona este sana se ensucia bastante, para que no parezca solo una casa gris.
vec3 obra_negra_sucia(vec3 c, vec3 p, float zona) {
	p = floor(p * 16.0) / 16.0;
	float h = p.x + p.z;
	float z = max(zona, 0.6);
	// Hollin: manchas que se adelgazan hacia arriba, como lenguas de humo
	float base = ruido(vec2(h * 0.45, 0.0) + 17.0);
	float alto = 1.2 + 2.2 * ruido(vec2(h * 0.3, 5.0));
	float lengua = smoothstep(0.32, 0.55, base + ruido(vec2(h * 1.3, p.y * 0.8) + 3.0) * 0.35)
		* (1.0 - smoothstep(alto * 0.4, alto, p.y));
	float mancha = smoothstep(0.5, 0.68, ruido(vec2(h, p.y * 1.2) / 2.2 + 41.0));
	float hollin = max(lengua, mancha) * (0.55 + 0.45 * z);
	c = mix(c, vec3(0.06, 0.055, 0.05), hollin * 0.9);
	// Escurrimientos oscuros desde la losa
	float franja = smoothstep(0.6, 0.8, ruido(vec2(h * 2.3, 9.0)));
	float largo = ruido(vec2(h * 0.7, 11.0));
	c *= 1.0 - franja * smoothstep(1.0 - largo, 1.0, fract(p.y / 2.5)) * 0.55;
	// Salitre blanquizco en manchones
	float salitre = smoothstep(0.78, 0.9, ruido(vec2(h * 0.8, p.y * 0.9) + 77.0)) * (1.0 - hollin);
	c = mix(c, vec3(0.7, 0.68, 0.62), salitre * 0.3);
	// Lodo y humedad a ras de piso
	float suelo = 1.0 - smoothstep(0.2, 0.9 + 0.7 * ruido(vec2(h * 1.5, 2.0)), p.y);
	c = mix(c, vec3(0.16, 0.13, 0.1), suelo * 0.85);
	return c;
}

// Lamina (bodegas): oxido que escurre de arriba y de los traslapes, manchas de
// oxido abajo y la pintura deslavada. `p` en el mundo, y = 0 en la calle.
vec3 lamina_oxidada(vec3 c, vec3 p, float zona) {
	p = floor(p * 16.0) / 16.0;
	float h = p.x + p.z;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * 0.95 + 0.04, zona * 0.4);
	vec3 oxido = vec3(0.42, 0.22, 0.1) * (0.7 + 0.5 * ruido(vec2(h * 4.0, p.y * 2.0)));
	// Escurrimientos: franjas angostas que bajan desde arriba
	float franja = smoothstep(0.6, 0.75, ruido(vec2(h * 2.3, 5.0)));
	float largo = ruido(vec2(h * 0.7, 9.0)) * 6.0;
	float escurre = franja * step(mod(-p.y, 8.0), largo + zona * 3.0);
	// Manchas grandes, mas abajo
	float mancha = smoothstep(0.62, 0.75, ruido2(vec2(h, p.y * 1.5) / 2.5 + 41.0)) * (1.2 - smoothstep(0.0, 4.0, p.y));
	c = mix(c, oxido, clamp(max(escurre * 0.7, mancha) * (0.3 + zona), 0.0, 1.0));
	return c * (1.0 - (1.0 - smoothstep(0.0, 0.8, p.y)) * 0.25);
}

// Mugre ligera para lo que no es muro (puertas, herreria, anuncios)
vec3 mugre(vec3 c, vec3 p, float zona) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), zona * 0.35);
	float suelo = 1.0 - smoothstep(0.0, 0.9, p.y);
	return c * (1.0 - zona * (0.12 + 0.15 * ruido(floor(p.xz * 8.0 + p.y * 8.0) / 4.0)) - suelo * 0.2);
}

// Vidrio roto: mas negro (hueco) y con grietas segun la zona; `semilla` cambia por casa
vec3 vidrio_roto(vec3 c, vec3 p, float zona, float semilla) {
	float h = p.x + p.z;
	if (hash(vec2(semilla, floor(h / 1.5) + floor(p.y / 2.5) * 7.0)) < zona * 0.8) {
		float g = grieta(vec2(h, p.y) / 1.5 + semilla);
		return mix(vec3(0.03), c * 1.3, step(0.5, g) * 0.8);
	}
	return c * (1.0 - grieta(vec2(h, p.y) / 2.0) * zona);
}

// Pisos: tipo 1 asfalto, 2 banqueta, 3 empedrado (0 = nada)
vec3 piso_roto(vec3 c, vec2 xz, float zona, int tipo) {
	if (tipo == 0) {
		return c;
	}
	xz = floor(xz * 16.0) / 16.0;
	// Tierra que el viento junta
	float polvo = smoothstep(0.55, 0.8, ruido2(xz / 6.0 + 11.0));
	c = mix(c, vec3(0.42, 0.38, 0.3), polvo * zona * 0.7);
	// Grietas: unas grandes donde el ruido dice, mas finas entre mas deterioro
	float g = grieta(xz / 5.0) * step(0.75 - zona * 0.5, ruido(xz / 7.0 + 3.0));
	g = max(g, grieta(xz / 2.3 + 0.37) * step(0.5, zona) * zona);
	c *= 1.0 - g * 0.65;
	if (tipo == 1) {
		// Baches: uno por celda de 3 m en algunas celdas; hoyo oscuro con orilla de grava
		vec2 celda = floor(xz / 3.0);
		if (hash(celda + 5.0) < zona * 0.3) {
			vec2 centro = (celda + 0.3 + 0.4 * vec2(hash(celda + 1.3), hash(celda + 7.1))) * 3.0;
			float r = 0.35 + 0.6 * hash(celda + 2.7);
			float d = length(xz - centro) / r + (ruido(xz * 3.0) - 0.5) * 0.5;
			c = mix(c, vec3(0.36, 0.33, 0.29), step(d, 1.15));
			c = mix(c, vec3(0.09, 0.08, 0.07), step(d, 0.85));
		}
	} else if (tipo == 2) {
		// Losas de banqueta manchadas o levantadas (cada 1 m)
		c *= 1.0 - step(1.0 - zona * 0.4, hash(floor(xz) + 9.0)) * 0.3;
	}
	return c;
}

#endif
