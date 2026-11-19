shader_type canvas_item;

// Modo alta (scripts/ModoAlta.gd): la ventana va a 1080p pero el 3D se renderiza chico
// (Viewport.scaling_3d_scale) y Godot lo agranda suavizado. Esto lo vuelve a juntar en cuadros
// duros: cada pixel de pantalla toma el color del centro de su cuadro de la rejilla del 3D, asi
// se ve como antes (640 x 480 agrandado con nearest), pero la UI encima va nitida.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 rejilla = vec2(853.0, 480.0);

void fragment() {
	vec2 uv = (floor(SCREEN_UV * rejilla) + 0.5) / rejilla;
	COLOR = vec4(textureLod(screen_texture, uv, 0.0).rgb, 1.0);
}
