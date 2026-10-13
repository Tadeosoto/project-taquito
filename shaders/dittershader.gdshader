shader_type canvas_item;

uniform sampler2D screen_texture :
	hint_screen_texture,
	repeat_disable,
	filter_nearest;
	
uniform float color_levels : hint_range(8.0, 64.0, 1.0) = 32.0;
uniform float dither_strenght : hint_range(0.0, 2.0, 0.05) = 0.35;

const mat4 bayer = mat4(
	vec4(0.0, 8.0, 2.0, 10.0),
	vec4(12.0, 4.0, 14.0, 6.0),
	vec4(3.0, 11.0, 1.0, 9.0),
	vec4(15.0, 7.0, 13.0, 5.0)
);

void fragment() {
	vec3 color = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	
	vec2 pixel = vec2(FRAGCOORD.xy);
	int x = int(mod(pixel.x, 4.0));
	int y = int(mod(pixel.y, 4.0));
	
	float treshold = bayer[x][y] / 16.0 - 0.5;
	
	color += treshold * dither_strenght / color_levels;
	color = floor(color * color_levels +0.5) / color_levels;
	
	COLOR = vec4(color, 1.0);
	
}
