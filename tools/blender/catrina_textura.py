# La Mojiganga, paso 1c-B: la textura. Pinta la version alta (Catrina_Alta) con fotos CC0 de Poly
# Haven (bajadas a tools/blender/cache/, sin versionar) mas capas hechas aqui (pintura de calavera
# deslavada, lagrimas de agua sucia, manchas de agua del ruedo para arriba, mugre en lo hondo) y la
# hornea en la malla del juego (catrina_baja.py): models/personajes/catrina/catrina.png (2048,
# color con la mugre ya puesta) y catrina_emision.png (el brillo del Serenol y las flamas).
#
# Paleta deslavada y siniestra (AG): el morado y las flores siguen, pero apagados y manchados; lo
# mas brillante es el turquesa.
#
# Se corre por pasos (cada uno tarda): uv(), pintar(), material_juego(), hornear("Vestido")... o
# todo() de jalon. Las fotos: velour_velvet, rough_linen (Rico Cilliers / colormass),
# decrepit_wallpaper (Rob Tuytel), clay_plaster (Amal Kumar), bamboo_veneer (Jenelle van Heerden),
# hessian_230 (Rico Cilliers / colormass); creditos en CREDITS.md.

import bpy
import math
import os

RAIZ = r"C:\Users\Big Boss\Documents\GitHub\project-taquito"
CACHE = RAIZ + r"\tools\blender\cache"
SALIDA = RAIZ + r"\models\personajes\catrina"
_a = {"SOLO_FUNCIONES": True, "__name__": "catrina_alta"}
exec(open(RAIZ + r"\tools\blender\catrina_alta.py", encoding="utf-8").read(), _a)
_m = _a["_m"]
CABEZA = _a["CABEZA"]
matriz_cabeza = _a["matriz_cabeza"]

BAJAS = ["Vestido", "Vestido_Roto", "Cuerpo", "Craneo", "Carrizo", "Nudo"]
FUENTES = {
    "Vestido": ["Vestido_Alta", "Rebozo_Alta", "Cola_Alta"],
    "Vestido_Roto": ["Vestido_Roto_Alta", "Rebozo_Roto_Alta", "Cola_Roto_Alta"],
    "Cuerpo": ["Cuerpo_Alta"],
    "Craneo": ["Craneo_Alta", "Peinado_Alta", "Flores_Alta", "Resplandor_Alta"],
    "Carrizo": ["Carrizo_Alta"],
    "Nudo": ["Nudo_Alta"],
}
ALBEDO = 2048
EMISION = 1024

# Zona -> (foto o None, tinte, escala de la foto, saturacion, cuanta mugre)
# Paleta de "funeral podrido" (AG, 2026-11-10: "el vestido tiene colores alegres"): morado casi
# negro de moreton, sangre seca, hueso amarillento, flores marchitas, moho y agua de Serenol
PINTURA = {
    "Tela": ("velour_velvet", (0.075, 0.03, 0.085), 1.6, 0.5, 1.2),
    "Blanco": ("rough_linen", (0.4, 0.36, 0.26), 2.0, 0.35, 1.2),
    "Faja": ("rough_linen", (0.36, 0.31, 0.23), 2.0, 0.35, 1.2),
    "Hueso": ("clay_plaster", (0.55, 0.47, 0.33), 1.2, 0.45, 1.2),
    "Cabello": ("hessian_230", (0.06, 0.045, 0.035), 3.0, 0.5, 0.8),
    "Carrizo": ("bamboo_veneer", (0.4, 0.33, 0.22), 1.0, 0.5, 1.0),
    "Nudo": ("clay_plaster", (0.22, 0.26, 0.18), 2.0, 0.6, 1.0),
    "Flor_Magenta": ("decrepit_wallpaper", (0.36, 0.09, 0.18), 2.5, 0.5, 0.9),
    "Flor_Naranja": ("decrepit_wallpaper", (0.4, 0.19, 0.06), 2.5, 0.5, 0.9),
    "Flor_Morada": ("decrepit_wallpaper", (0.19, 0.08, 0.24), 2.5, 0.5, 0.9),
    "Flor_Rosa": ("decrepit_wallpaper", (0.38, 0.2, 0.2), 2.5, 0.45, 0.9),
    "Flor_Centro": ("hessian_230", (0.26, 0.19, 0.07), 4.0, 0.5, 0.9),
    "Verde": ("decrepit_wallpaper", (0.12, 0.18, 0.09), 2.5, 0.5, 0.9),
    "Rebozo": ("rough_linen", (0.15, 0.025, 0.03), 2.0, 0.65, 1.0),
    "Papel": ("decrepit_wallpaper", (0.24, 0.23, 0.21), 1.6, 0.3, 1.2),
    "Cuerda": ("hessian_230", (0.28, 0.22, 0.14), 4.0, 0.5, 0.9),
    "Alambre": (None, (0.16, 0.14, 0.14), 1.0, 0.5, 0.5),
    "Vela": (None, (0.6, 0.55, 0.42), 1.0, 0.6, 0.6),
    "Flama": (None, (1.0, 0.6, 0.15), 1.0, 1.0, 0.0),
    "Brillo": (None, (0.2, 1.0, 0.85), 1.0, 1.0, 0.0),
}
# Las flores marchitas siguen siendo el blanco de la pistola: un brillo enfermo de Serenol
BRILLAN = {"Flama": (1.0, 0.55, 0.12), "Brillo": (0.15, 1.0, 0.8),
           "Flor_Magenta": (0.015, 0.09, 0.07), "Flor_Naranja": (0.015, 0.09, 0.07),
           "Flor_Morada": (0.015, 0.09, 0.07), "Flor_Rosa": (0.015, 0.09, 0.07), "Flor_Centro": (0.03, 0.14, 0.11)}
# Zonas que llevan las manchas de sangre seca, moho y escurrimientos de Serenol
MANCHADAS = {"Tela", "Blanco", "Faja", "Rebozo", "Papel", "Hueso", "Cuerda", "Verde", "Carrizo", "Nudo"}


def _escena():
    sc = bpy.data.scenes["Catrina"]
    for ventana in bpy.context.window_manager.windows:
        ventana.scene = sc
    return sc


def _contexto_3d():
    for ventana in bpy.context.window_manager.windows:
        for area in ventana.screen.areas:
            if area.type == "VIEW_3D":
                region = next(r for r in area.regions if r.type == "WINDOW")
                return dict(window=ventana, area=area, region=region, screen=ventana.screen)
    return {}


# --- 1. UV: un solo atlas para las seis mallas ---

def uv():
    sc = _escena()
    obs = [bpy.data.objects[n] for n in BAJAS]
    for ob in sc.objects:
        ob.select_set(False)
    for ob in obs:
        ob.hide_set(False)
        ob.select_set(True)
        if not ob.data.uv_layers:
            ob.data.uv_layers.new(name="UVMap")
    sc.view_layers[0].objects.active = obs[0]
    with bpy.context.temp_override(**_contexto_3d()):
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004, scale_to_bounds=False)
        bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
        bpy.ops.object.mode_set(mode="OBJECT")
    for n in ("Vestido_Roto", "Carrizo", "Nudo"):
        bpy.data.objects[n].hide_set(True)
    print("uv listo")


# --- 2. La pintura de la alta ---

def _foto(nombre):
    ruta = os.path.join(CACHE, nombre + "_diff_1k.jpg")
    img = bpy.data.images.get(nombre) or bpy.data.images.load(ruta)
    img.name = nombre
    return img


def _nodo(arbol, tipo, x, y, **props):
    n = arbol.nodes.new(tipo)
    n.location = (x, y)
    for k, v in props.items():
        setattr(n, k, v)
    return n


def _mezcla(arbol, x, y, modo, a, b, fac):
    """Mix de color (ShaderNodeMix en modo RGBA): a, b y fac pueden ser sockets o valores."""
    n = _nodo(arbol, "ShaderNodeMix", x, y, data_type="RGBA", blend_type=modo)
    l = arbol.links
    for entrada, valor in ((n.inputs[0], fac), (n.inputs[6], a), (n.inputs[7], b)):
        if isinstance(valor, bpy.types.NodeSocket):
            l.new(valor, entrada)
        else:
            entrada.default_value = valor
    return n.outputs[2]


def _valor(arbol, x, y, op, a, b=None, c=None):
    n = _nodo(arbol, "ShaderNodeMath", x, y, operation=op)
    for i, v in enumerate((a, b, c)):
        if v is None:
            continue
        if isinstance(v, bpy.types.NodeSocket):
            arbol.links.new(v, n.inputs[i])
        else:
            n.inputs[i].default_value = v
    return n.outputs[0]


def _cara(arbol, pos_cabeza, x, y, color):
    """La pintura de calavera de azucar, deslavada: petalos alrededor de las cuencas, flor en la
    frente, puntos en los pomulos y lagrimas de agua sucia que bajan de las cuencas. pos_cabeza es
    la posicion en el espacio de la cabeza (sin joroba)."""
    l = arbol.links
    sep = _nodo(arbol, "ShaderNodeSeparateXYZ", x, y)
    l.new(pos_cabeza, sep.inputs[0])
    px, py, pz = sep.outputs[0], sep.outputs[1], sep.outputs[2]
    frente = _valor(arbol, x + 150, y - 300, "LESS_THAN", py, -0.15)
    ruido = _nodo(arbol, "ShaderNodeTexNoise", x, y - 450, noise_dimensions="3D")
    ruido.inputs["Scale"].default_value = 14.0
    l.new(pos_cabeza, ruido.inputs["Vector"])
    deslave = _valor(arbol, x + 150, y - 450, "GREATER_THAN", ruido.outputs[0], 0.32)
    salida = color
    dx = 250
    for i, (cx, tinte) in enumerate(((-0.24, (0.34, 0.06, 0.15, 1)), (0.24, (0.38, 0.15, 0.04, 1)))):
        # anillo alrededor de la cuenca, ondulado como petalos
        ddx = _valor(arbol, x + 300, y - 100 * i, "SUBTRACT", px, cx)
        ddz = _valor(arbol, x + 300, y - 100 * i - 50, "SUBTRACT", pz, 0.04)
        d = _valor(arbol, x + 450, y - 100 * i, "SQRT", _valor(arbol, x + 450, y - 100 * i - 40, "ADD",
                   _valor(arbol, x + 400, y - 100 * i, "MULTIPLY", ddx, ddx), _valor(arbol, x + 400, y - 100 * i - 60, "MULTIPLY", ddz, ddz)))
        ang = _valor(arbol, x + 450, y - 100 * i - 80, "ARCTAN2", ddz, ddx)
        petalo = _valor(arbol, x + 600, y - 100 * i - 80, "MULTIPLY", _valor(arbol, x + 550, y - 100 * i - 80, "SINE",
                        _valor(arbol, x + 500, y - 100 * i - 80, "MULTIPLY", ang, 8.0)), 0.025)
        dd = _valor(arbol, x + 650, y - 100 * i, "ADD", d, petalo)
        anillo = _valor(arbol, x + 800, y - 100 * i, "MULTIPLY", _valor(arbol, x + 700, y - 100 * i, "GREATER_THAN", dd, 0.22),
                        _valor(arbol, x + 700, y - 100 * i - 40, "LESS_THAN", dd, 0.27))
        mascara = _valor(arbol, x + 900, y - 100 * i, "MULTIPLY", _valor(arbol, x + 850, y - 100 * i, "MULTIPLY", anillo, frente), deslave)
        salida = _mezcla(arbol, x + 1000 + dx * i, y - 100 * i, "MIX", salida, tinte, _valor(arbol, x + 950, y - 100 * i, "MULTIPLY", mascara, 0.75))
        # Lagrima: una franja angosta que baja de la cuenca, oscura con turquesa arriba
        cerca = _valor(arbol, x + 700, y - 100 * i - 300, "LESS_THAN", _valor(arbol, x + 650, y - 100 * i - 300, "ABSOLUTE",
                       _valor(arbol, x + 600, y - 100 * i - 300, "ADD", ddx, _valor(arbol, x + 550, y - 100 * i - 340, "MULTIPLY",
                                                                                   _valor(arbol, x + 500, y - 100 * i - 340, "SUBTRACT", ruido.outputs[0], 0.5), 0.08))), 0.045)
        abajo = _valor(arbol, x + 700, y - 100 * i - 360, "MULTIPLY", _valor(arbol, x + 650, y - 100 * i - 360, "LESS_THAN", pz, -0.1),
                       _valor(arbol, x + 650, y - 100 * i - 400, "GREATER_THAN", pz, -0.62))
        lagrima = _valor(arbol, x + 850, y - 100 * i - 330, "MULTIPLY", _valor(arbol, x + 800, y - 100 * i - 330, "MULTIPLY", cerca, abajo), frente)
        salida = _mezcla(arbol, x + 1100 + dx * i, y - 100 * i - 300, "MULTIPLY", salida, (0.35, 0.42, 0.38, 1), _valor(arbol, x + 950, y - 100 * i - 330, "MULTIPLY", lagrima, 0.9))
    # Flor en la frente y puntos en los pomulos
    for j, (cx, cz, r, tinte) in enumerate(((0.0, 0.33, 0.08, (0.2, 0.08, 0.26, 1)), (-0.38, -0.2, 0.05, (0.34, 0.07, 0.15, 1)), (0.38, -0.2, 0.05, (0.34, 0.07, 0.15, 1)))):
        ddx = _valor(arbol, x + 300, y - 700 - 80 * j, "SUBTRACT", px, cx)
        ddz = _valor(arbol, x + 300, y - 740 - 80 * j, "SUBTRACT", pz, cz)
        d = _valor(arbol, x + 450, y - 700 - 80 * j, "SQRT", _valor(arbol, x + 400, y - 700 - 80 * j, "ADD",
                   _valor(arbol, x + 350, y - 700 - 80 * j, "MULTIPLY", ddx, ddx), _valor(arbol, x + 350, y - 740 - 80 * j, "MULTIPLY", ddz, ddz)))
        punto = _valor(arbol, x + 600, y - 700 - 80 * j, "MULTIPLY", _valor(arbol, x + 550, y - 700 - 80 * j, "LESS_THAN", d, r),
                       _valor(arbol, x + 550, y - 740 - 80 * j, "MULTIPLY", frente, deslave))
        salida = _mezcla(arbol, x + 1600, y - 700 - 80 * j, "MIX", salida, tinte, _valor(arbol, x + 700, y - 700 - 80 * j, "MULTIPLY", punto, 0.8))
    return salida


def _material_pintado(mat, zona):
    foto, tinte, escala, sat, mugre = PINTURA[zona]
    mat.use_nodes = True
    arbol = mat.node_tree
    arbol.nodes.clear()
    l = arbol.links
    salida = _nodo(arbol, "ShaderNodeOutputMaterial", 1900, 0)
    bsdf = _nodo(arbol, "ShaderNodeBsdfPrincipled", 1600, 0)
    l.new(bsdf.outputs[0], salida.inputs[0])
    bsdf.inputs["Roughness"].default_value = 1.0
    coords = _nodo(arbol, "ShaderNodeTexCoord", -900, 0)
    color = (*tinte, 1.0)
    if foto:
        mapa = _nodo(arbol, "ShaderNodeMapping", -700, 0)
        mapa.inputs["Scale"].default_value = (escala,) * 3
        l.new(coords.outputs["Object"], mapa.inputs["Vector"])
        img = _nodo(arbol, "ShaderNodeTexImage", -500, 0, image=_foto(foto), projection="BOX", projection_blend=0.3)
        l.new(mapa.outputs[0], img.inputs[0])
        hsv = _nodo(arbol, "ShaderNodeHueSaturation", -250, 0)
        hsv.inputs["Saturation"].default_value = 0.0
        l.new(img.outputs[0], hsv.inputs["Color"])
        # La foto da la textura (luz y sombra del tejido); el tinte da el color
        # Overlay: el gris medio de la foto deja el tinte tal cual; lo claro y lo oscuro del tejido
        # lo aclaran y lo oscurecen
        color = _mezcla(arbol, 0, 0, "OVERLAY", color, hsv.outputs[0], 0.75)
    if zona == "Hueso":
        mc = matriz_cabeza()
        centro = mc @ CABEZA
        sub = _nodo(arbol, "ShaderNodeVectorMath", -700, -400, operation="SUBTRACT")
        sub.inputs[1].default_value = centro
        l.new(coords.outputs["Object"], sub.inputs[0])
        rot = _nodo(arbol, "ShaderNodeVectorRotate", -500, -400, rotation_type="X_AXIS", invert=True)
        rot.inputs["Angle"].default_value = _m["INCLINA"] + _m["CABECEA"]
        l.new(sub.outputs[0], rot.inputs["Vector"])
        color = _cara(arbol, rot.outputs[0], -300, -400, color)
    # Agua sucia: manchas que suben del piso (mas abajo, mas mojado y verdoso)
    sep = _nodo(arbol, "ShaderNodeSeparateXYZ", 300, -300)
    l.new(coords.outputs["Object"], sep.inputs[0])
    ruido = _nodo(arbol, "ShaderNodeTexNoise", 300, -500)
    ruido.inputs["Scale"].default_value = 2.5
    ruido.inputs["Detail"].default_value = 6.0
    l.new(coords.outputs["Object"], ruido.inputs["Vector"])
    alto = _valor(arbol, 500, -300, "SUBTRACT", 1.0, _valor(arbol, 450, -300, "DIVIDE", sep.outputs[2], 2.6))
    mojado = _valor(arbol, 650, -300, "MULTIPLY", _valor(arbol, 600, -300, "GREATER_THAN", _valor(arbol, 550, -350, "ADD", alto, _valor(arbol, 500, -450, "MULTIPLY", ruido.outputs[0], 0.6)), 0.85), 0.7)
    color = _mezcla(arbol, 800, -100, "MULTIPLY", color, (0.55, 0.55, 0.42, 1), mojado)
    if zona in MANCHADAS:
        color = _manchas(arbol, coords.outputs["Object"], color, zona)
    # Lo apagado: menos saturacion y valor
    hsv2 = _nodo(arbol, "ShaderNodeHueSaturation", 1000, 0)
    hsv2.inputs["Saturation"].default_value = sat
    hsv2.inputs["Value"].default_value = 0.8
    l.new(color, hsv2.inputs["Color"])
    color = hsv2.outputs[0]
    # Mugre en lo hondo (oclusion de la propia pieza)
    if mugre > 0.0:
        ao = _nodo(arbol, "ShaderNodeAmbientOcclusion", 1000, -300, only_local=True, samples=16)
        ao.inputs["Distance"].default_value = 0.25
        hondo = _valor(arbol, 1200, -300, "MULTIPLY", _valor(arbol, 1150, -300, "SUBTRACT", 1.0, ao.outputs["AO"]), mugre)
        color = _mezcla(arbol, 1350, -100, "MIX", color, (0.07, 0.05, 0.04, 1), hondo)
    l.new(color, bsdf.inputs["Base Color"])
    if zona in BRILLAN:
        bsdf.inputs["Emission Color"].default_value = (*BRILLAN[zona], 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.0


def _ruido(arbol, vector, x, y, escala, detalle=4.0, estira=None):
    l = arbol.links
    if estira:
        mapa = _nodo(arbol, "ShaderNodeMapping", x - 200, y)
        mapa.inputs["Scale"].default_value = estira
        l.new(vector, mapa.inputs["Vector"])
        vector = mapa.outputs[0]
    n = _nodo(arbol, "ShaderNodeTexNoise", x, y)
    n.inputs["Scale"].default_value = escala
    n.inputs["Detail"].default_value = detalle
    l.new(vector, n.inputs["Vector"])
    return n.outputs[0]


def _manchas(arbol, pos, color, zona):
    """Sangre seca que sube del ruedo, moho negro a manchones, escurrimientos de agua de Serenol
    y, en el hueso, cuarteaduras."""
    l = arbol.links
    sep = _nodo(arbol, "ShaderNodeSeparateXYZ", 300, -800)
    l.new(pos, sep.inputs[0])
    # Sangre: abajo de ~1.6 m con orilla irregular
    orilla = _valor(arbol, 500, -800, "ADD", 1.4, _valor(arbol, 450, -850, "MULTIPLY", _ruido(arbol, pos, 300, -900, 1.8, 6.0), 1.6))
    sangre = _valor(arbol, 650, -800, "LESS_THAN", sep.outputs[2], orilla)
    if zona not in ("Hueso", "Carrizo", "Nudo"):
        color = _mezcla(arbol, 800, -800, "MIX", color, (0.09, 0.012, 0.012, 1), _valor(arbol, 700, -850, "MULTIPLY", sangre, 0.7))
    # Moho a manchones
    moho = _valor(arbol, 650, -1000, "GREATER_THAN", _ruido(arbol, pos, 450, -1000, 4.0, 8.0), 0.6)
    color = _mezcla(arbol, 850, -1000, "MIX", color, (0.025, 0.035, 0.018, 1), _valor(arbol, 750, -1050, "MULTIPLY", moho, 0.75))
    # Escurrimientos: ruido estirado en vertical (rayas que bajan)
    rayas = _valor(arbol, 650, -1200, "GREATER_THAN", _ruido(arbol, pos, 450, -1200, 3.0, 3.0, (9.0, 9.0, 0.7)), 0.66)
    color = _mezcla(arbol, 900, -1200, "MIX", color, (0.04, 0.26, 0.22, 1), _valor(arbol, 750, -1250, "MULTIPLY", rayas, 0.55))
    if zona == "Hueso":
        vor = _nodo(arbol, "ShaderNodeTexVoronoi", 450, -1400, feature="DISTANCE_TO_EDGE")
        vor.inputs["Scale"].default_value = 6.0
        l.new(pos, vor.inputs["Vector"])
        grieta = _valor(arbol, 650, -1400, "LESS_THAN", vor.outputs["Distance"], 0.025)
        color = _mezcla(arbol, 950, -1400, "MIX", color, (0.05, 0.035, 0.025, 1), _valor(arbol, 750, -1450, "MULTIPLY", grieta, 0.85))
    if zona == "Carrizo":
        hollin = _valor(arbol, 650, -1500, "GREATER_THAN", _ruido(arbol, pos, 450, -1500, 2.0, 4.0), 0.5)
        color = _mezcla(arbol, 950, -1500, "MIX", color, (0.02, 0.018, 0.016, 1), _valor(arbol, 750, -1550, "MULTIPLY", hollin, 0.7))
    return color


def solo_pintura():
    """Repinta y rehornea sin volver a desenvolver (el rig y los clips no cambian)."""
    pintar()
    material_juego()
    for i, n in enumerate(BAJAS):
        hornear(n, primero=(i == 0), jaula=0.25 if n == "Craneo" else 0.12, rayo=0.8 if n == "Craneo" else 0.4)
    guardar()


def pintar():
    _escena()
    for zona in PINTURA:
        mat = bpy.data.materials.get("cat_" + zona)
        if mat:
            _material_pintado(mat, zona)
    print("pintura lista")


# --- 3. El material del juego: el atlas horneado ---

def _imagen(nombre, lado):
    img = bpy.data.images.get(nombre)
    if img is None or img.size[0] != lado:
        if img:
            bpy.data.images.remove(img)
        img = bpy.data.images.new(nombre, lado, lado, alpha=False)
    return img


def material_juego():
    _escena()
    mat = bpy.data.materials.get("cat_juego") or bpy.data.materials.new("cat_juego")
    mat.use_nodes = True
    mat.use_backface_culling = False
    arbol = mat.node_tree
    arbol.nodes.clear()
    l = arbol.links
    salida = _nodo(arbol, "ShaderNodeOutputMaterial", 600, 0)
    bsdf = _nodo(arbol, "ShaderNodeBsdfPrincipled", 300, 0)
    bsdf.inputs["Roughness"].default_value = 1.0
    l.new(bsdf.outputs[0], salida.inputs[0])
    color = _nodo(arbol, "ShaderNodeTexImage", 0, 100, image=_imagen("catrina", ALBEDO), interpolation="Closest", name="albedo")
    brillo = _nodo(arbol, "ShaderNodeTexImage", 0, -200, image=_imagen("catrina_emision", EMISION), interpolation="Closest", name="emision")
    l.new(color.outputs[0], bsdf.inputs["Base Color"])
    l.new(brillo.outputs[0], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.0
    for n in BAJAS:
        ob = bpy.data.objects[n]
        ob.data.materials.clear()
        ob.data.materials.append(mat)
    print("material del juego listo")
    return mat


# --- 4. Hornear (un objeto por llamada: tarda) ---

def hornear(baja, primero=False, jaula=0.12, rayo=0.4):
    sc = _escena()
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 16
    sc.render.bake.use_selected_to_active = True
    sc.render.bake.cage_extrusion = 0.12
    sc.render.bake.max_ray_distance = 0.4
    sc.render.bake.margin = 6
    col = bpy.data.collections["Catrina_Alta"]
    col.hide_viewport = False
    vl = sc.view_layers[0]
    for ob in sc.objects:
        ob.select_set(False)
    destino = bpy.data.objects[baja]
    destino.hide_set(False)
    fuentes = [bpy.data.objects[n] for n in FUENTES[baja] if bpy.data.objects.get(n)]
    for ob in fuentes:
        ob.hide_set(False)
        ob.hide_render = False
        ob.select_set(True)
    destino.select_set(True)
    vl.objects.active = destino
    mat = destino.data.materials[0]
    for nombre, tipo, filtro in (("albedo", "DIFFUSE", {"COLOR"}), ("emision", "EMIT", set())):
        mat.node_tree.nodes.active = mat.node_tree.nodes[nombre]
        with bpy.context.temp_override(**_contexto_3d()):
            bpy.ops.object.bake(type=tipo, pass_filter=filtro, use_selected_to_active=True, cage_extrusion=jaula,
                                max_ray_distance=rayo, margin=6, use_clear=primero, target="IMAGE_TEXTURES")
    for ob in fuentes:
        ob.hide_set(True)
        ob.select_set(False)
    if baja in ("Vestido_Roto", "Carrizo", "Nudo"):
        destino.hide_set(True)
    col.hide_viewport = True
    print("horneado", baja)


def guardar():
    os.makedirs(SALIDA, exist_ok=True)
    for nombre, archivo in (("catrina", "catrina.png"), ("catrina_emision", "catrina_emision.png")):
        img = bpy.data.images[nombre]
        img.filepath_raw = os.path.join(SALIDA, archivo)
        img.file_format = "PNG"
        img.save()
    print("guardadas en", SALIDA)


def todo():
    uv()
    pintar()
    material_juego()
    for i, n in enumerate(BAJAS):
        # El resplandor de la baja (prismas) queda mas lejos de la alta (canas con nudos): rayo largo
        hornear(n, primero=(i == 0), jaula=0.25 if n == "Craneo" else 0.12, rayo=0.8 if n == "Craneo" else 0.4)
    guardar()


if not globals().get("SOLO_FUNCIONES"):
    todo()
