shader_type canvas_item;

uniform sampler2D screen_texture :
	hint_screen_texture,
	repeat_disable,
	filter_nearest;
	
uniform float color_levels : hint_range(8.0, 64.0, 1.0) = 32.0;
uniform float dither_strenght : hint_range(0.0, 2.0, 0.05) = 0.35;

// Correccion de color antes del dither (post-apocaliptico en map_test). Los valores
// por defecto no cambian nada.
uniform float desaturacion : hint_range(0.0, 1.0, 0.05) = 0.0;
uniform vec3 tinte : source_color = vec3(1.0);
uniform float contraste : hint_range(0.5, 2.0, 0.05) = 1.0;
// Oscurece las orillas de la pantalla
uniform float vineta : hint_range(0.0, 1.0, 0.05) = 0.0;

const mat4 bayer = mat4(
	vec4(0.0, 8.0, 2.0, 10.0),
	vec4(12.0, 4.0, 14.0, 6.0),
	vec4(3.0, 11.0, 1.0, 9.0),
	vec4(15.0, 7.0, 13.0, 5.0)
);

void fragment() {
	vec3 color = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(luma), desaturacion) * tinte;
	color = clamp((color - 0.5) * contraste + 0.5, 0.0, 1.0);
	vec2 centro = SCREEN_UV - 0.5;
	color *= 1.0 - vineta * smoothstep(0.25, 0.75, length(centro * vec2(1.2, 1.0)));
	
	vec2 pixel = vec2(FRAGCOORD.xy);
	int x = int(mod(pixel.x, 4.0));
	int y = int(mod(pixel.y, 4.0));
	
	float treshold = bayer[x][y] / 16.0 - 0.5;
	
	color += treshold * dither_strenght / color_levels;
	color = floor(color * color_levels +0.5) / color_levels;
	
	COLOR = vec4(color, 1.0);
	
}
