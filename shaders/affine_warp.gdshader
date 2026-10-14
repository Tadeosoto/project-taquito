shader_type spatial;

uniform sampler2D albedo_texture : source_color;

uniform float warp_strength = 80.0;

varying vec2 affine_uv;

void vertex() {
	affine_uv = UV;
	
	float w = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	affine_uv *= abs(w) / warp_strength;
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec2 uv = affine_uv;
	
	ALBEDO = texture(albedo_texture, uv).rgb;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
