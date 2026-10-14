shader_type spatial;

uniform float snap_resolution = 40.0;

void vertex() {
	// Called for every vertex the material is visible on.
	vec4 view_pos = MODELVIEW_MATRIX * vec4 (VERTEX, 1.0);
	
	view_pos.xyz =
		floor(view_pos.xyz * snap_resolution)
		/ snap_resolution;
	VERTEX = 
		(inverse(MODELVIEW_MATRIX) * view_pos).xyz;
}
