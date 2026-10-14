shader_type spatial;
// Combined PS1 look: screen-space vertex jitter + view-space vertex wobble
// + affine (non-perspective-correct) texture warping.
// Merges jittershader.gdshader, vertex_wobble.gdshader and affine_warp.gdshader.

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 base_color : source_color = vec4(0.55, 0.55, 0.55, 1.0);
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// --- Screen-space vertex jitter (from jittershader) ---
uniform bool jitter_enabled = true;
uniform float snap_resolution : hint_range(20, 320, 1.0) = 160.0;

// --- View-space vertex wobble (from vertex_wobble) ---
uniform bool wobble_enabled = true;
uniform float wobble_resolution = 40.0;

// --- Affine texture warp (from affine_warp) ---
uniform bool affine_enabled = true;
uniform float warp_strength = 80.0;

varying vec2 affine_uv;

void vertex() {
	// Depth (view-space z) is sampled before anything else so the affine UV
	// and the jitter both use the original geometry position.
	float view_z = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;

	// 1. View-space vertex wobble.
	if (wobble_enabled) {
		vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		view_pos.xyz =
			floor(view_pos.xyz * wobble_resolution)
			/ wobble_resolution;
		VERTEX = (inverse(MODELVIEW_MATRIX) * view_pos).xyz;
	}

	// 2. Affine texture warp. affine_uv is interpolated linearly across the
	// triangle, so perspective correction is lost on the sampled texture.
	affine_uv = UV;
	if (affine_enabled) {
		affine_uv *= abs(view_z) / warp_strength;
	}

	// 3. Screen-space vertex jitter (PS1 vertex snapping).
	if (jitter_enabled) {
		vec4 clip_position =
			PROJECTION_MATRIX *
			MODELVIEW_MATRIX *
			vec4(VERTEX, 1.0);

		vec2 screen_position = clip_position.xy / clip_position.w;

		screen_position =
			round(screen_position * snap_resolution)
			/ snap_resolution;

		clip_position.xy = screen_position * clip_position.w;

		POSITION = clip_position;
	}
}

void fragment() {
	vec4 tex_color = texture(albedo_texture, affine_uv);
	ALBEDO = tex_color.rgb * tint.rgb;
	ROUGHNESS = 1.0;
}