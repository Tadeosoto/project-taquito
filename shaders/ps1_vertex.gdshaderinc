// Shared PS1 vertex stage: view-space vertex wobble, affine (non-perspective-
// correct) UVs and screen-space vertex jitter. Included by ps1_combined and
// ps1_facade. Varyings can't be written from a function, so callers copy the
// out parameters into VERTEX / POSITION / their own varyings.

// --- Screen-space vertex jitter (from jittershader) ---
uniform bool jitter_enabled = true;
uniform float snap_resolution : hint_range(20, 320, 1.0) = 160.0;

// --- View-space vertex wobble (from vertex_wobble) ---
uniform bool wobble_enabled = true;
uniform float wobble_resolution = 40.0;

// --- Affine texture warp (from affine_warp) ---
uniform bool affine_enabled = true;
uniform float warp_strength = 80.0;

// Applies wobble to `vertex`, writes the affine UV and returns the clip
// position (snapped when jitter_enabled). Callers must always write it to
// POSITION: a shader that writes POSITION only sometimes leaves the vertex
// at the origin otherwise and the mesh disappears.
vec4 ps1_vertex(inout vec3 vertex, vec2 uv, mat4 modelview, mat4 projection, out vec2 affine_uv_out) {
	// Depth (view-space z) is sampled before anything else so the affine UV
	// and the jitter both use the original geometry position.
	float view_z = (modelview * vec4(vertex, 1.0)).z;

	// 1. View-space vertex wobble.
	if (wobble_enabled) {
		vec4 view_pos = modelview * vec4(vertex, 1.0);
		view_pos.xyz =
			floor(view_pos.xyz * wobble_resolution)
			/ wobble_resolution;
		vertex = (inverse(modelview) * view_pos).xyz;
	}

	// 2. Affine texture warp. The UV is interpolated linearly across the
	// triangle, so perspective correction is lost on the sampled texture.
	affine_uv_out = uv;
	if (affine_enabled) {
		affine_uv_out *= abs(view_z) / warp_strength;
	}

	// 3. Screen-space vertex jitter (PS1 vertex snapping).
	vec4 clip_position = projection * modelview * vec4(vertex, 1.0);
	if (!jitter_enabled) {
		return clip_position;
	}
	vec2 screen_position = clip_position.xy / clip_position.w;
	screen_position =
		round(screen_position * snap_resolution)
		/ snap_resolution;
	clip_position.xy = screen_position * clip_position.w;
	return clip_position;
}
