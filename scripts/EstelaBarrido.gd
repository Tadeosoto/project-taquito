extends MeshInstance3D

# La estela del barrido: una cinta en el mundo entre la mano y la punta del arma, que Barrido.gd
# va dejando mientras el brazo pasa. Asi siempre sigue al brazo y a donde mira el personaje, desde
# cualquier angulo (un dibujo plano de cara a la camara se veia siempre de lado). Corre con el
# tiempo del juego: se queda en la congelada del golpe como todo lo demas.
# Cada tantos pedazos suelta una nube de polvo cerca de la punta, como las de la hoja 2D.

const VIDA := 0.18             # s que dura cada pedazo
const DESDE := 0.45            # la orilla de adentro, en fraccion del largo desde la mano
# m que baja la orilla de adentro: acostada (el brazo va casi parejo) desde atras se veia de canto
const ADENTRO_BAJA := 0.3
# Una media luna solida como la hoja de la barrida (golpe_barrida en tools/pixelfx/efectos.json):
# franjas de su paleta, de la orilla clara de la punta hacia adentro mas oscuro, sin mezclar. UV.x va
# de adentro (0) a la punta (1) y UV.y es la edad: lo viejo se adelgaza hasta quedar en la orilla
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

const vec3 PALETA[6] = vec3[](
	vec3(0.110, 0.133, 0.188), vec3(0.180, 0.212, 0.282), vec3(0.290, 0.329, 0.408),
	vec3(0.431, 0.478, 0.565), vec3(0.604, 0.651, 0.729), vec3(0.816, 0.847, 0.902));

void fragment() {
	float borde = UV.y * 0.9;
	if (UV.x < borde) {
		discard;
	}
	float k = (UV.x - borde) / (1.0 - borde);
	int paso = clamp(int(k * 6.0), 0, 5);
	ALBEDO = pow(PALETA[paso], vec3(2.2));
}
"""

# La estela de todos los golpes (JJ): 0 la de siempre, 1 la de agua, 2 la de la mariposa monarca
# (que ademas suelta monarcas chiquitas, Player._estela_golpe). La pone el protagonista
# (Personaje.estela: Genaro fuego, Homero monarca, Ramon agua, Emiliano rayos haki, Felipe rayos con los colores de su ropa) y la tecla 8 del safehouse la cambia.
# La de agua es azul con blanco, al estilo de la respiracion del agua de Tanjiro: mas ancha y dura
# mas, con franjas que ondulan a lo largo de la estela, crestas blancas que corren y la orilla de
# adentro rota en gotas. UV2.x cuenta los pedazos, para saber donde va cada uno a lo largo
# La de fuego (JJ: con los colores de la danza del dios del fuego de Tanjiro) es la de agua tal
# cual, con la paleta del rojo oscuro al amarillo casi blanco y chispas en vez de espuma
# La de rayos (JJ, la de Emiliano: como el haki del rey de One Piece): ancha como la de agua, negra
# por fuera, cafe en medio como su saco y roja del haki por dentro, con grietas en zigzag que
# brincan de lugar, y en vez de nubes suelta rayos con las mismas capas que salen un poco de la
# punta (RAYO_AFUERA) y parpadean
# La de Felipe es fuego negro: flamas como las de fuego con los colores de su chamarra (JJ): gris carbon de los
# cuadros por fuera, grises cada vez mas claros hasta el blanco adentro, sin amarillo ni naranja
enum Estilo { NORMAL, AGUA, MONARCA, FUEGO, RAYOS, FLAMAS_FELIPE }
const NOMBRES := ["la de siempre", "agua", "mariposa monarca", "fuego", "rayos haki", "fuego negro de Felipe"]
const SHADER_RAYOS := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

// Emiliano (JJ): negro por fuera, cafe en medio y rojo del haki del rey por dentro; NUCLEO es el
// centro encendido de grietas y rayos
const vec3 NEGRO = vec3(0.060, 0.020, 0.080);
const vec3 CAFE = vec3(0.450, 0.280, 0.150);
const vec3 DENTRO = vec3(0.880, 0.080, 0.180);
const vec3 NUCLEO = vec3(1.000, 0.380, 0.450);

float azar(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

// Una linea quebrada: para cada u, a que altura (0..1) de la estela pasa
float quebrada(float u, float s) {
	float i = floor(u);
	return mix(azar(i + s), azar(i + 1.0 + s), fract(u));
}

void fragment() {
	float edad = UV.y;
	float u = UV2.x * 0.35;
	float borde = edad * 0.85;
	float ruido = fract(sin(floor(UV2.x) * 12.9898 + floor(UV.x * 10.0) * 78.233) * 43758.5453);
	if (UV.x < borde + ruido * 0.12 * edad) {
		discard;
	}
	float k = (UV.x - borde) / (1.0 - borde);
	// Cuerpo en tres franjas: adentro al centro, cafe en medio y negro en las dos orillas (JJ)
	float orilla = abs(k - 0.5) * 2.0;
	// El de adentro delgado y el cafe ancho (JJ: que se vea mas el cafe)
	vec3 c = orilla < 0.18 ? DENTRO : (orilla < 0.70 ? CAFE : NEGRO);
	// Dos grietas que brincan de lugar 14 veces por segundo: nucleo encendido, cafe y contorno negro
	float cuadro = floor(TIME * 14.0);
	float d = 1.0;
	for (int j = 0; j < 2; j++) {
		float fj = float(j);
		float p = 0.12 + 0.76 * quebrada(u * 2.5 + fj * 7.3, cuadro * 3.1 + fj * 11.0);
		d = min(d, abs(k - p));
	}
	float grueso = 0.035 * (1.0 - edad * 0.6);
	if (d < grueso) {
		c = NUCLEO;
	} else if (d < grueso + 0.025) {
		c = CAFE;
	} else if (d < grueso + 0.055) {
		c = NEGRO;
	}
	ALBEDO = pow(c, vec3(2.2));
}
"""
# Los rayos que salen: el mismo cuadro de cara a la camara que las nubes, con un rayo quebrado
# de orilla a orilla en un angulo al azar y una rama
const RAYO_TAMANO := Vector2(1.0, 1.35)   # m, al salir y al final
const RAYO_AFUERA := 0.06    # m mas alla de la punta del arma: que sobresalgan de la estela (JJ)
const RAYO_CADA := 4         # pedazos entre rayo y rayo (las nubes van cada NUBE_CADA)
const SHADER_RAYO := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

instance uniform float edad = 0.0;
instance uniform float semilla = 0.0;

// Emiliano (JJ): negro por fuera, cafe en medio y rojo del haki del rey por dentro; NUCLEO es el
// centro encendido de grietas y rayos
const vec3 NEGRO = vec3(0.060, 0.020, 0.080);
const vec3 CAFE = vec3(0.450, 0.280, 0.150);
const vec3 DENTRO = vec3(0.880, 0.080, 0.180);
const vec3 NUCLEO = vec3(1.000, 0.380, 0.450);

float azar(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

float quebrada(float u, float s) {
	float i = floor(u);
	return mix(azar(i + s), azar(i + 1.0 + s), fract(u)) - 0.5;
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

// Distancia a un rayo que sale del centro en el angulo a, de largo l
float rayo(vec2 p, float a, float l, float s) {
	vec2 eje = vec2(cos(a), sin(a));
	float largo = dot(p, eje);
	float lado = dot(p, vec2(-eje.y, eje.x));
	if (largo < 0.0 || largo > l) {
		return 1.0;
	}
	// Mas quebrado lejos del centro
	float desvio = quebrada(largo * 9.0, s) * 0.16 * (0.3 + largo * 1.6);
	return abs(lado - desvio);
}

void fragment() {
	// 24 x 24 pixeles por rayo, como pixel art
	vec2 p = (floor(UV * 24.0) + 0.5) / 24.0 - 0.5;
	float cuadro = floor(TIME * 18.0);
	// Parpadea: algunos cuadros no se ve, mas conforme se acaba
	if (azar(cuadro + semilla * 91.0) < 0.15 + edad * 0.5) {
		discard;
	}
	float a = semilla * 6.2832;
	float l = 0.52 * (1.0 - edad * 0.45);
	float d = rayo(p, a, l, cuadro + semilla * 37.0);
	d = min(d, rayo(p, a + 0.8 * sign(semilla - 0.5), l * 0.6, cuadro * 1.7 + semilla * 53.0) + 0.01);
	d = min(d, rayo(p, a + 3.1416, l * 0.4, cuadro * 2.3 + semilla * 17.0) + 0.01);
	// Por capas como la estela: nucleo encendido mientras es nuevo, adentro, cafe y contorno negro
	float grueso = 0.025 * (1.0 - edad * 0.5);
	vec3 c;
	if (d < grueso * 0.5 && edad < 0.5) {
		c = NUCLEO;
	} else if (d < grueso) {
		c = DENTRO;
	} else if (d < grueso + 0.015) {
		c = CAFE;
	} else if (d < grueso + 0.035) {
		c = NEGRO;
	} else {
		discard;
	}
	ALBEDO = pow(c, vec3(2.2));
}
"""
static var estilo := Estilo.NORMAL
const AGUA_VIDA := 0.32
const AGUA_DESDE := 0.15
const AGUA_BAJA := 0.15
const SHADER_AGUA := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

const vec3 AGUA[6] = vec3[](
	vec3(0.035, 0.090, 0.280), vec3(0.055, 0.200, 0.520), vec3(0.110, 0.380, 0.780),
	vec3(0.330, 0.620, 0.940), vec3(0.680, 0.860, 1.000), vec3(0.970, 0.990, 1.000));

void fragment() {
	float edad = UV.y;
	float u = UV2.x * 0.18;
	float borde = edad * 0.85;
	// La orilla de adentro se rompe en gotas conforme envejece
	float ruido = fract(sin(floor(UV2.x) * 12.9898 + floor(UV.x * 10.0) * 78.233) * 43758.5453);
	if (UV.x < borde + ruido * 0.12 * edad) {
		discard;
	}
	float k = (UV.x - borde) / (1.0 - borde);
	// Las franjas ondulan como agua que corre
	float onda = sin(u * 6.2832 - TIME * 10.0) * 0.08 + sin(u * 13.0 + TIME * 6.0) * 0.04;
	float kk = clamp(k + onda, 0.0, 0.999);
	int paso = int(kk * 6.0);
	vec3 c = AGUA[paso];
	// Rayitas blancas entre franja y franja, como el agua dibujada
	if (paso >= 2 && fract(kk * 6.0) < 0.12) {
		c = AGUA[5];
	}
	// Crestas que se enroscan hacia la punta y corren por la estela
	float s = fract(u - TIME * 1.5);
	float cresta = 0.8 - 0.25 * s * s;
	if (k > cresta && k < cresta + 0.07) {
		c = AGUA[5];
	}
	ALBEDO = pow(c, vec3(2.2));
}
"""

# La monarca (JJ): franjas naranjas que se oscurecen hacia adentro, cortadas por venas negras a lo
# largo y de traves, y la orilla de la punta negra con puntitos blancos, como el ala. Ancha como la
# de agua
const SHADER_MONARCA := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

const vec3 NEGRO = vec3(0.05, 0.035, 0.03);
const vec3 BLANCO = vec3(0.98, 0.96, 0.9);
const vec3 NARANJA[4] = vec3[](
	vec3(0.55, 0.20, 0.03), vec3(0.80, 0.33, 0.04), vec3(0.95, 0.47, 0.07), vec3(1.00, 0.62, 0.16));

void fragment() {
	float edad = UV.y;
	float u = UV2.x * 0.18;
	float borde = edad * 0.85;
	if (UV.x < borde) {
		discard;
	}
	float k = (UV.x - borde) / (1.0 - borde);
	vec3 c;
	if (k > 0.8) {
		// La orilla negra del ala con dos hileras de puntitos blancos
		c = NEGRO;
		float hilera = k > 0.9 ? 0.5 : 0.0;
		if (abs(k - 0.85 - hilera * 0.1) < 0.035 && fract(u * 1.6 + hilera) < 0.28) {
			c = BLANCO;
		}
	} else {
		c = NARANJA[clamp(int(k / 0.8 * 4.0), 0, 3)];
		// Venas: a lo largo (entre celda y celda) y de traves, inclinadas hacia la punta
		float vena_larga = fract(k / 0.8 * 3.0);
		float vena_cruz = fract(u * 0.9 + k * 0.6);
		if (vena_larga < 0.09 || vena_cruz < 0.07) {
			c = NEGRO;
		}
	}
	ALBEDO = pow(c, vec3(2.2));
}
"""

# Nubes de polvo: una bola pixeleada de cara a la camara, blanca (JJ no la quiso cafe como la de
# la hoja), mas clara arriba a la izquierda, que crece, sube y se deshace.
# `edad` va de 0 a 1 y `semilla` cambia la forma de cada una
const NUBES := 20              # en la reserva; se reusa la mas vieja (el estallido del puno saca 7)
const NUBE_CADA := 5           # pedazos de estela entre nube y nube
const NUBE_VIDA := 0.45
const NUBE_TAMANO := Vector2(0.2, 0.5)  # m, al salir y al final
const NUBE_SUBE := 0.35        # m/s
const NUBE_ABAJO := 0.12       # m por debajo de la punta
const SHADER_NUBE := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

instance uniform float edad = 0.0;
instance uniform float semilla = 0.0;

const vec3 POLVO[4] = vec3[](
	vec3(0.961, 0.957, 0.937), vec3(0.851, 0.847, 0.827), vec3(0.698, 0.698, 0.686),
	vec3(0.549, 0.553, 0.549));

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	// 12 x 12 pixeles por nube, como pixel art
	vec2 p = (floor(UV * 12.0) + 0.5) / 12.0 - 0.5;
	float angulo = atan(p.y, p.x);
	float d = length(p) + 0.06 * sin(angulo * 3.0 + semilla * 6.283) + 0.04 * sin(angulo * 5.0 - semilla * 3.1);
	// Se deshace al final: se encoge y se le hacen hoyos
	float radio = 0.42 * (1.0 - edad * edad * 0.6);
	float hoyo = fract(sin(dot(floor(UV * 12.0), vec2(12.9898, 78.233)) + semilla) * 43758.5453);
	if (d > radio || hoyo < (edad - 0.5) * 1.6) {
		discard;
	}
	float luz = clamp(0.55 - (p.x - p.y) * 1.1 - d * 0.6 - edad * 0.5, 0.0, 0.999);
	ALBEDO = pow(POLVO[3 - int(luz * 4.0)], vec3(2.2));
}
"""

static var _material: ShaderMaterial
static var _material_nube: ShaderMaterial
static var _quad: QuadMesh
static var _material_agua: ShaderMaterial
static var _material_espuma: ShaderMaterial
static var _material_monarca: ShaderMaterial
static var _material_polen: ShaderMaterial
static var _material_fuego: ShaderMaterial
static var _material_chispas: ShaderMaterial
static var _material_rayos: ShaderMaterial
static var _material_rayo: ShaderMaterial
static var _material_flamas: ShaderMaterial
static var _material_chispas_felipe: ShaderMaterial
const PALETA_AGUA := """vec3(0.035, 0.090, 0.280), vec3(0.055, 0.200, 0.520), vec3(0.110, 0.380, 0.780),
	vec3(0.330, 0.620, 0.940), vec3(0.680, 0.860, 1.000), vec3(0.970, 0.990, 1.000)"""
const PALETA_FUEGO := """vec3(0.300, 0.030, 0.020), vec3(0.620, 0.070, 0.030), vec3(0.900, 0.230, 0.040),
	vec3(1.000, 0.480, 0.080), vec3(1.000, 0.760, 0.250), vec3(1.000, 0.960, 0.780)"""
# Felipe: de afuera (0) hacia adentro, del carbon de los cuadros al blanco, sin amarillo ni naranja (JJ)
const PALETA_FELIPE := """vec3(0.100, 0.110, 0.140), vec3(0.250, 0.260, 0.290), vec3(0.420, 0.430, 0.460),
	vec3(0.620, 0.630, 0.650), vec3(0.820, 0.830, 0.840), vec3(0.970, 0.970, 0.970)"""
const POLVO_GRIS := """vec3(0.961, 0.957, 0.937), vec3(0.851, 0.847, 0.827), vec3(0.698, 0.698, 0.686),
	vec3(0.549, 0.553, 0.549)"""

var _pedazos: Array = []       # [mano, punta, edad]
var _malla := ImmediateMesh.new()
var _nubes: Array[MeshInstance3D] = []
var _nube_edad: Array[float] = []
var _nube_vel: Array[Vector3] = []     # las del estallido salen disparadas; las demas, quietas
var _nube_escala: Array[float] = []
var _siguiente := 0
var _cuenta := 0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _malla
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
	material_override = _material
	if _material_nube == null:
		var shader := Shader.new()
		shader.code = SHADER_NUBE
		_material_nube = ShaderMaterial.new()
		_material_nube.shader = shader
		_quad = QuadMesh.new()
		# El shader voltea el cuadro hacia la camara: sin esto se recortaba al verlo de lado
		_quad.custom_aabb = AABB(Vector3.ONE * -0.5, Vector3.ONE)
	for i in NUBES:
		var nube := MeshInstance3D.new()
		nube.mesh = _quad
		nube.material_override = _material_nube
		nube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nube.top_level = true
		nube.visible = false
		add_child(nube)
		_nubes.append(nube)
		_nube_edad.append(-1.0)
		_nube_vel.append(Vector3.ZERO)
		_nube_escala.append(1.0)
	if _material_agua == null:
		var shader := Shader.new()
		shader.code = SHADER_AGUA
		_material_agua = ShaderMaterial.new()
		_material_agua.shader = shader
		# La espuma: las mismas nubes en azul clarito y blanco
		var espuma := Shader.new()
		espuma.code = SHADER_NUBE.replace("""vec3(0.961, 0.957, 0.937), vec3(0.851, 0.847, 0.827), vec3(0.698, 0.698, 0.686),
	vec3(0.549, 0.553, 0.549)""", """vec3(0.970, 0.990, 1.000), vec3(0.760, 0.900, 1.000), vec3(0.450, 0.720, 0.980),
	vec3(0.200, 0.470, 0.850)""")
		_material_espuma = ShaderMaterial.new()
		_material_espuma.shader = espuma
	if _material_monarca == null:
		var shader := Shader.new()
		shader.code = SHADER_MONARCA
		_material_monarca = ShaderMaterial.new()
		_material_monarca.shader = shader
		# Las nubes de la monarca: blanco y naranja claro, como sus puntitos
		var polen := Shader.new()
		polen.code = SHADER_NUBE.replace("""vec3(0.961, 0.957, 0.937), vec3(0.851, 0.847, 0.827), vec3(0.698, 0.698, 0.686),
	vec3(0.549, 0.553, 0.549)""", """vec3(0.980, 0.960, 0.900), vec3(1.000, 0.820, 0.560), vec3(0.980, 0.600, 0.200),
	vec3(0.800, 0.380, 0.080)""")
		_material_polen = ShaderMaterial.new()
		_material_polen.shader = polen
	if _material_fuego == null:
		var shader := Shader.new()
		# Al reves que el agua: lo rojo afuera (la punta) y lo amarillo adentro (JJ); las rayitas y
		# crestas siguen siendo del color mas claro
		shader.code = SHADER_AGUA.replace(PALETA_AGUA, PALETA_FUEGO) \
				.replace("vec3 c = AGUA[paso];", "vec3 c = AGUA[5 - paso];")
		_material_fuego = ShaderMaterial.new()
		_material_fuego.shader = shader
		# Chispas: amarillo claro a rojo
		var chispas := Shader.new()
		chispas.code = SHADER_NUBE.replace(POLVO_GRIS, """vec3(1.000, 0.950, 0.700), vec3(1.000, 0.700, 0.200),
	vec3(0.950, 0.380, 0.060), vec3(0.650, 0.110, 0.030)""")
		_material_chispas = ShaderMaterial.new()
		_material_chispas.shader = chispas
	if _material_rayos == null:
		var shader := Shader.new()
		shader.code = SHADER_RAYOS
		_material_rayos = ShaderMaterial.new()
		_material_rayos.shader = shader
		var rayo := Shader.new()
		rayo.code = SHADER_RAYO
		_material_rayo = ShaderMaterial.new()
		_material_rayo.shader = rayo
	if _material_flamas == null:
		var flamas := Shader.new()
		flamas.code = SHADER_AGUA.replace(PALETA_AGUA, PALETA_FELIPE) \
				.replace("vec3 c = AGUA[paso];", "vec3 c = AGUA[5 - paso];")
		_material_flamas = ShaderMaterial.new()
		_material_flamas.shader = flamas
		# Las llamas que suelta: negras (JJ), del carbon al negro
		var chispas := Shader.new()
		chispas.code = SHADER_NUBE.replace(POLVO_GRIS, """vec3(0.180, 0.180, 0.200), vec3(0.110, 0.110, 0.130),
	vec3(0.060, 0.060, 0.070), vec3(0.020, 0.020, 0.025)""")
		_material_chispas_felipe = ShaderMaterial.new()
		_material_chispas_felipe.shader = chispas
	set_process(false)


func _de_rayos() -> bool:
	return _modo() == Estilo.RAYOS


func _tamano_nube() -> Vector2:
	return RAYO_TAMANO if _de_rayos() else NUBE_TAMANO


func _modo() -> int:
	return estilo


func _de_agua() -> bool:
	return _modo() != 0   # las demas tienen la forma ancha de la de agua


# a_puno: la estela de un puno (Player.ESTELA_PUNOS) va pareja de la muneca a los nudillos, sin
# empezar a medio camino ni bajar la orilla de adentro como la del machete
func agregar(mano: Vector3, punta: Vector3, a_puno := false) -> void:
	var de_agua := _de_agua()
	if _pedazos.is_empty():
		material_override = [_material, _material_agua, _material_monarca, _material_fuego, _material_rayos, _material_flamas][_modo()]
	var desde := AGUA_DESDE if de_agua else DESDE
	var baja := AGUA_BAJA if de_agua else ADENTRO_BAJA
	if a_puno:
		desde = 0.0
		baja = 0.0
	_pedazos.append([mano.lerp(punta, desde) + Vector3.DOWN * baja, punta, 0.0, float(_cuenta)])
	_cuenta += 1
	if _de_rayos():
		if _cuenta % RAYO_CADA == 0:
			_soltar_nube(punta + (punta - mano).normalized() * RAYO_AFUERA)
	elif _cuenta % NUBE_CADA == 0:
		_soltar_nube(punta.lerp(mano, 0.15) + Vector3.DOWN * NUBE_ABAJO)
	set_process(true)


# Varias de golpe en un punto (el punetazo a punos al pegar, Player.PUNO_ESTALLIDO): salen
# disparadas hacia `hacia` (abiertas ESTALLIDO_ABRE), se frenan (ESTALLIDO_FRENA) y luego suben;
# `escala` las agranda. Sin `hacia`, se quedan donde salen
const ESTALLIDO_VEL := Vector2(2.0, 4.5)   # m/s
const ESTALLIDO_ABRE := 0.8
const ESTALLIDO_FRENA := 6.0
func estallar(donde: Vector3, cuantas: int, hacia := Vector3.ZERO, escala := 1.0) -> void:
	for i in cuantas:
		var j := _soltar_nube(donde + Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), randf_range(-0.1, 0.1)))
		_nube_escala[j] = escala
		if hacia != Vector3.ZERO:
			var abre := Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)) * ESTALLIDO_ABRE
			_nube_vel[j] = (hacia.normalized() + abre).normalized() * randf_range(ESTALLIDO_VEL.x, ESTALLIDO_VEL.y)
	set_process(true)


func _soltar_nube(donde: Vector3) -> int:
	var i := _siguiente
	_siguiente = (_siguiente + 1) % NUBES
	var nube := _nubes[i]
	nube.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * _tamano_nube().x), donde)
	nube.material_override = [_material_nube, _material_espuma, _material_polen, _material_chispas, _material_rayo, _material_chispas_felipe][_modo()]
	nube.set_instance_shader_parameter("semilla", randf())
	nube.set_instance_shader_parameter("edad", 0.0)
	nube.visible = true
	_nube_edad[i] = 0.0
	_nube_vel[i] = Vector3.ZERO
	_nube_escala[i] = 1.0
	return i


func _process(delta: float) -> void:
	for pedazo: Array in _pedazos:
		pedazo[2] += delta
	var vida := AGUA_VIDA if _de_agua() else VIDA
	while not _pedazos.is_empty() and _pedazos[0][2] >= vida:
		_pedazos.pop_front()
	var hay_nubes := _mover_nubes(delta)
	_malla.clear_surfaces()
	if _pedazos.size() < 2:
		if _pedazos.is_empty() and not hay_nubes:
			set_process(false)
		return
	_malla.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for pedazo: Array in _pedazos:
		var edad: float = pedazo[2] / vida
		_malla.surface_set_uv(Vector2(0.0, edad))
		_malla.surface_set_uv2(Vector2(pedazo[3], 0.0))
		_malla.surface_add_vertex(pedazo[0])
		_malla.surface_set_uv(Vector2(1.0, edad))
		_malla.surface_set_uv2(Vector2(pedazo[3], 0.0))
		_malla.surface_add_vertex(pedazo[1])
	_malla.surface_end()


func _mover_nubes(delta: float) -> bool:
	var hay := false
	for i in NUBES:
		if _nube_edad[i] < 0.0:
			continue
		_nube_edad[i] += delta
		var nube := _nubes[i]
		var edad := _nube_edad[i] / NUBE_VIDA
		if edad >= 1.0:
			_nube_edad[i] = -1.0
			nube.visible = false
			continue
		hay = true
		var tam := _tamano_nube()
		var tamano := lerpf(tam.x, tam.y, ease(edad, 0.4)) * _nube_escala[i]
		# Los rayos no suben como el humo
		var sube := 0.0 if _de_rayos() else NUBE_SUBE
		_nube_vel[i] = _nube_vel[i].move_toward(Vector3.ZERO, ESTALLIDO_FRENA * delta)
		nube.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * tamano),
			nube.global_position + (Vector3.UP * sube + _nube_vel[i]) * delta)
		nube.set_instance_shader_parameter("edad", edad)
	return hay
