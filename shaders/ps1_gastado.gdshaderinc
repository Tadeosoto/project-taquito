// Uso y abandono de los muebles de los interiores (Mostrador, Estante, Refrigerador y
// la mercancia): que nada sea de un solo color parejo ni de caricatura. Va despues de
// ps1_deterioro.gdshaderinc (usa hash, ruido y grieta).

// Altura sobre el piso: los interiores se ponen Interiores.ALTURA (500 m) arriba del
// negocio y afuera el mapa nunca llega a 500 m, asi que sirve igual en la calle
float altura_local(float y) {
	return mod(y, 500.0);
}

// `c` color, `p` posicion en el mundo, `n` normal en el mundo, `desgaste` 0-1. Con
// `metal` la pintura se despostilla y deja ver el fierro con oxido.
vec3 gastado(vec3 c, vec3 p, vec3 n, float desgaste, bool metal) {
	float h = altura_local(p.y);
	// Cuadritos de 1/32 m para que se vea PS1; dos coordenadas de pared (sirven para
	// caras en x y en z) y una de piso
	vec3 q = floor(p * 32.0) / 32.0;
	vec2 pared = vec2(q.x + q.z, q.y);
	// Manchas grandes y granito: la pintura nunca es pareja
	float mancha = ruido(pared * 2.3 + q.xz * 1.1) * 0.6 + ruido(pared * 7.0 + 13.0) * 0.4;
	c *= 0.78 + 0.34 * mancha;
	c *= 0.92 + 0.16 * hash(floor(vec2(p.x + p.z, p.y) * 32.0) + floor(p.xz * 32.0) * 1.7);
	// Desteñido: menos saturado y hacia un gris amarillento de tienda vieja
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * vec3(1.03, 0.98, 0.88), 0.3 + 0.35 * desgaste);
	// Mugre que sube del piso, dispareja
	float suelo = 1.0 - smoothstep(0.0, 0.45 + 0.4 * ruido(pared * 3.0 + 5.0), h);
	c *= 1.0 - suelo * (0.25 + 0.3 * desgaste);
	// Escurrimientos y manos sucias a media altura
	float escurre = smoothstep(0.6, 0.85, ruido(vec2(pared.x * 9.0, 0.0))) * smoothstep(0.3, 1.0, ruido(pared * vec2(9.0, 1.5) + 3.0));
	c *= 1.0 - escurre * 0.3 * desgaste;
	// Polvo en lo que ve hacia arriba
	c = mix(c, vec3(0.52, 0.49, 0.43), smoothstep(0.6, 0.95, n.y) * 0.4 * desgaste);
	// Rayones y grietas
	float raya = grieta(pared * 0.7 + q.xz * 0.5);
	c *= 1.0 - raya * 0.4 * desgaste;
	if (metal) {
		// Despostillado: se ve el fierro gris y el oxido
		float chip = ruido(pared * 10.0 + q.xz * 6.0 + 41.0) * 0.7 + hash(floor(pared * 40.0)) * 0.3;
		if (chip > 1.0 - desgaste * 0.18) {
			float oxido = ruido(pared * 4.0 + 7.0);
			c = mix(vec3(0.3, 0.29, 0.28), vec3(0.4, 0.19, 0.08), oxido) * (0.8 + 0.3 * hash(floor(pared * 64.0)));
		}
	}
	return c;
}
