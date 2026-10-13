shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform float snap_resolution : hint_range(20, 320, 1.0) = 160;
uniform vec4 base_color : source_color = vec4(0.55, 0.55, 0.55, 1.0);
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);


void vertex() {
	// Called for every vertex the material is visible on.
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

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	// Called for every pixel the material is visible on.
	ALBEDO = tex_color.rgb * tint.rgb;
	ROUGHNESS = 1.0;
	
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
