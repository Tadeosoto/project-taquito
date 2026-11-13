# El kit del mapa: texturas, materiales y piezas parametricas que usa colonia.py.
#
# Materiales: el nombre es lo que Godot reconoce (scripts/mapa/MapaPostImport.gd los cambia por
# los shaders PS1 del juego), y en Blender llevan una vista previa parecida:
#   fachada_kit   paredes: el atlas textures/mapa/fachadas_kit.png con las UV puestas aqui y
#                 el color de la casa como color de vertice (se pinta solo donde la mascara es
#                 blanca). En Godot: shaders/ps1_fachada_kit.gdshader, con mugre segun la zona.
#   azotea        techos: textures/map/azoteas.png en coordenadas de mundo (ps1_facade, azotea)
#   asfalto, banqueta, empedrado, pasto_seco, tierra
#                 pisos con textura de textures/map/ repetida en coordenadas de mundo
#                 (ps1_suelo, como el Suelo de map_test)
#   cualquier otro  ps1_combined con su color (y su textura, si tiene), sin temblor PS1
#
# El atlas (atlas()): 4 columnas x 5 filas de 64 px; cada mosaico es un tramo de PISO x PISO m.
#   filas 0-3: textures/map/fachadas.png tal cual (0 = piso de arriba, 1 = planta baja,
#              2-3 = lo mismo deteriorado; tools/map_import/make_textures.py)
#   fila 4:    paredes sin ventana: aplanado liso, aplanado caido con el ladrillo, ladrillo,
#              block gris de obra negra
# Se rehace con: SOLO_FUNCIONES = True; exec(kit.py); atlas()

import bpy
import math
import os

_c = {"__name__": "comun"}
exec(open(os.path.join(os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito"), "tools", "blender", "mapa", "comun.py"), encoding="utf-8").read(), _c)
globals().update({k: v for k, v in _c.items() if not k.startswith("__")})

import numpy as np

PISO = 2.75                     # m por piso y por tramo de fachada
MOSAICO = 64                    # px
COLUMNAS, FILAS = 4, 5
TEXTURAS_MAPA = os.path.join(RAIZ, "textures", "map")
TEXTURAS_KIT = os.path.join(RAIZ, "textures", "mapa")
ATLAS = os.path.join(TEXTURAS_KIT, "fachadas_kit.png")
ATLAS_MASCARA = os.path.join(TEXTURAS_KIT, "fachadas_kit_mascara.png")
CACHE = os.path.join(RAIZ, "tools", "blender", "cache")

# Mosaicos del atlas (columna, fila)
VENTANA_ARRIBA = [(0, 0), (1, 0), (2, 0), (3, 0)]
PUERTA, CORTINA, VENTANA_ABAJO, ZAGUAN = (0, 1), (1, 1), (2, 1), (3, 1)
LISO, CAIDO, LADRILLO, BLOCK = (0, 4), (1, 4), (2, 4), (3, 4)

# Pisos: textura de textures/map/ y metros por repeticion (los mismos que MapPostImport)
PISOS = {"asfalto": ("asfalto.png", 4.0), "banqueta": ("banqueta.png", 3.0), "empedrado": ("empedrado.png", 2.5),
         "pasto_seco": ("pasto_seco.png", 2.5), "tierra": ("../mapa/tierra.png", 2.0), "azotea": ("azoteas.png", PISO),
         # El piso de la plaza: la foto del kit (textures/mapa/, foto("piedra_plaza"))
         "adoquin": ("../mapa/piedra_plaza.png", 2.0),
         # Andadores de la plaza (cantera rosa) y sus jardines
         "cantera_piso": ("../mapa/cantera_rosa.png", 1.5), "pasto": ("pasto.png", 2.5),
         # La glorieta del tinaco comunitario: la piedra de la plaza pintada del rosa de los andadores
         # (tools/map_import/make_piedra_plaza_rosa.py)
         "adoquin_rosa": ("../mapa/piedra_plaza_rosa.png", 2.0),
         # La cenefa entre lo rosa y lo gris (tools/map_import/make_cantera_orilla.py)
         "cantera_orilla": ("../mapa/cantera_orilla.png", 1.5)}

# Colores de Guadalajara (desteñidos: el shader del juego les pone la mugre)
PALETA = {"terracota": (0.72, 0.36, 0.24), "mostaza": (0.82, 0.62, 0.22), "turquesa": (0.25, 0.6, 0.6),
          "rosa": (0.85, 0.5, 0.58), "lima": (0.6, 0.72, 0.3), "azul": (0.35, 0.48, 0.72),
          "crema": (0.88, 0.82, 0.68), "blanco": (0.9, 0.9, 0.86), "naranja": (0.88, 0.5, 0.22),
          "morado": (0.55, 0.38, 0.6), "verde": (0.3, 0.55, 0.4), "gris": (0.62, 0.62, 0.6)}


# --- Atlas ---

def _leer_png(ruta):
    img = bpy.data.images.load(ruta, check_existing=False)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]   # fila 0 arriba
    bpy.data.images.remove(img)
    return px


def _escribir_png(ruta, px):
    h, w = px.shape[:2]
    img = bpy.data.images.new(os.path.basename(ruta), w, h, alpha=True)
    img.pixels[:] = px[::-1].reshape(-1)
    img.filepath_raw = ruta
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def _foto_mosaico(nombre, tam=MOSAICO):
    """Un pedazo de la foto de Poly Haven del cache, reducido a tam x tam (vecino mas cercano)."""
    px = _leer_png(os.path.join(CACHE, nombre + "_diff_1k.jpg"))
    h, w = px.shape[:2]
    ys = (np.arange(tam) * (h / 2 / tam)).astype(int)
    xs = (np.arange(tam) * (w / 2 / tam)).astype(int)
    return px[ys][:, xs]


def _ladrillo(tam=MOSAICO):
    rng = np.random.default_rng(7)
    px = np.zeros((tam, tam, 4), np.float32)
    px[..., 3] = 1.0
    junta = np.array([0.62, 0.58, 0.52])
    px[..., :3] = junta
    alto, largo = 5, 13               # px: ladrillo de 7 x 21 cm con su junta
    for fila in range(tam // alto + 1):
        desfase = (largo // 2) * (fila % 2)
        for col in range(-1, tam // largo + 2):
            x0, y0 = col * largo + desfase, fila * alto
            tono = np.array([0.58, 0.3, 0.2]) * rng.uniform(0.8, 1.15)
            px[max(y0, 0):min(y0 + alto - 1, tam), max(x0, 0):min(x0 + largo - 1, tam), :3] = tono
    return px


def _block(tam=MOSAICO):
    rng = np.random.default_rng(11)
    px = np.ones((tam, tam, 4), np.float32)
    px[..., :3] = 0.42
    alto, largo = 8, 16               # block de 20 x 40 cm
    for fila in range(tam // alto + 1):
        desfase = (largo // 2) * (fila % 2)
        for col in range(-1, tam // largo + 2):
            x0, y0 = col * largo + desfase, fila * alto
            tono = rng.uniform(0.55, 0.66)
            px[max(y0, 0):min(y0 + alto - 1, tam), max(x0, 0):min(x0 + largo - 1, tam), :3] = tono
    px[..., :3] *= rng.uniform(0.93, 1.05, (tam, tam, 1))
    return px


def atlas():
    """Arma textures/mapa/fachadas_kit.png y su mascara."""
    base = _leer_png(os.path.join(TEXTURAS_MAPA, "fachadas.png"))
    base_m = _leer_png(os.path.join(TEXTURAS_MAPA, "fachadas_mascara.png"))
    T = MOSAICO
    px = np.ones((T * FILAS, T * COLUMNAS, 4), np.float32)
    m = np.ones_like(px)
    px[:T * 4], m[:T * 4] = base, base_m
    # Liso: el aplanado gris de la foto, casi blanco, para que lo pinte el color de la casa
    yeso = _foto_mosaico("clay_plaster")
    gris = yeso[..., :3].mean(axis=2, keepdims=True)
    liso = np.concatenate([np.clip(0.86 + (gris - gris.mean()) * 0.6, 0, 1).repeat(3, 2), np.ones((T, T, 1))], 2)
    lad = _ladrillo()
    # Caido: liso con manchones de ladrillo (ruido de bloques)
    rng = np.random.default_rng(3)
    ruido = rng.random((T // 8, T // 8)).repeat(8, 0).repeat(8, 1)
    caido_m = (ruido > 0.35).astype(np.float32)
    caido = np.where(caido_m[..., None] > 0.5, liso, lad)
    fila = T * 4
    for col, (color, mascara) in enumerate([(liso, 1.0), (caido, caido_m[..., None]), (lad, 0.0), (_block(), 0.0)]):
        px[fila:fila + T, col * T:(col + 1) * T] = color
        m[fila:fila + T, col * T:(col + 1) * T, :3] = mascara
    os.makedirs(TEXTURAS_KIT, exist_ok=True)
    _escribir_png(ATLAS, px)
    _escribir_png(ATLAS_MASCARA, m)
    print("atlas:", ATLAS)


def uv_mosaico(celda, u, v):
    """(u, v) de 0 a 1 dentro de un mosaico -> UV del atlas (V de Blender va hacia arriba)."""
    col, fila = celda
    return ((col + u) / COLUMNAS, 1.0 - (fila + 1.0 - v) / FILAS)


# --- Materiales ---

def _arbol(mat):
    mat.use_nodes = True
    arbol = mat.node_tree
    for n in list(arbol.nodes):
        if n.type != "OUTPUT_MATERIAL":
            arbol.nodes.remove(n)
    salida = next(n for n in arbol.nodes if n.type == "OUTPUT_MATERIAL")
    bsdf = arbol.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 1.0
    arbol.links.new(bsdf.outputs[0], salida.inputs[0])
    return arbol, bsdf


def _imagen(ruta):
    nombre = os.path.basename(ruta)
    img = bpy.data.images.get(nombre)
    if img is None:
        img = bpy.data.images.load(ruta)
    img.reload()
    return img


def mat_fachada(rehacer=False):
    """Atlas con color de vertice donde la mascara es blanca."""
    mat = bpy.data.materials.get("fachada_kit")
    if mat and not rehacer:
        return mat
    mat = mat or bpy.data.materials.new("fachada_kit")
    arbol, bsdf = _arbol(mat)
    tex = arbol.nodes.new("ShaderNodeTexImage")
    tex.image = _imagen(ATLAS)
    tex.interpolation = "Closest"
    msk = arbol.nodes.new("ShaderNodeTexImage")
    msk.image = _imagen(ATLAS_MASCARA)
    msk.image.colorspace_settings.name = "Non-Color"
    msk.interpolation = "Closest"
    color = arbol.nodes.new("ShaderNodeVertexColor")
    color.layer_name = "Color"
    por = arbol.nodes.new("ShaderNodeMix")
    por.data_type, por.blend_type = "RGBA", "MULTIPLY"
    por.inputs[0].default_value = 1.0
    arbol.links.new(tex.outputs[0], por.inputs[6])
    arbol.links.new(color.outputs[0], por.inputs[7])
    mezcla = arbol.nodes.new("ShaderNodeMix")
    mezcla.data_type = "RGBA"
    arbol.links.new(msk.outputs[0], mezcla.inputs[0])
    arbol.links.new(tex.outputs[0], mezcla.inputs[6])
    arbol.links.new(por.outputs[2], mezcla.inputs[7])
    arbol.links.new(mezcla.outputs[2], bsdf.inputs["Base Color"])
    return mat


def mat_detalle():
    """El atlas de fachadas con otro nombre, para los detalles de las casas (climas, rejas,
    antenas, ropa): en Godot MapaPostImport los pone en cuadros que no se dibujan de lejos."""
    mat = bpy.data.materials.get("detalle_kit")
    if mat is None:
        mat = mat_fachada().copy()
        mat.name = "detalle_kit"
    return mat


def mat_piso(nombre, rehacer=False):
    """Textura de textures/map/ repetida en metros de mundo (como ps1_suelo en Godot)."""
    archivo, metros = PISOS[nombre]
    mat = bpy.data.materials.get(nombre)
    if mat and not rehacer:
        return mat
    mat = mat or bpy.data.materials.new(nombre)
    arbol, bsdf = _arbol(mat)
    coords = arbol.nodes.new("ShaderNodeNewGeometry")
    escala = arbol.nodes.new("ShaderNodeVectorMath")
    escala.operation = "SCALE"
    escala.inputs["Scale"].default_value = 1.0 / metros
    arbol.links.new(coords.outputs["Position"], escala.inputs[0])
    tex = arbol.nodes.new("ShaderNodeTexImage")
    tex.image = _imagen(os.path.join(TEXTURAS_MAPA, archivo))
    tex.interpolation = "Closest"
    arbol.links.new(escala.outputs[0], tex.inputs[0])
    if nombre == "azotea":
        # El atlas de azoteas trae dos mosaicos: en Blender se ve el primero
        mitad = arbol.nodes.new("ShaderNodeMapping")
        mitad.inputs["Scale"].default_value = (0.5, 1.0, 1.0)
        arbol.links.new(escala.outputs[0], mitad.inputs[0])
        arbol.links.new(mitad.outputs[0], tex.inputs[0])
    arbol.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    return mat


def materiales(rehacer=False):
    """Todos los del kit (los de color liso los hace comun.material). Ya hechos se reusan."""
    mats = {"fachada_kit": mat_fachada(rehacer)}
    for nombre in PISOS:
        mats[nombre] = mat_piso(nombre, rehacer)
    return mats


# --- Murales: grafitis y propaganda pintada ---
# Los mismos catalogos que el mapa de OSM (textures/map/grafitis/ y textures/map/propaganda/, ver sus
# LEEME.md: se agregan diseños poniendo imagenes ahi), juntos en textures/mapa/murales.png con su
# indice en murales.json. Material "mural": en Godot, ps1_casa (descarta lo transparente).
MURAL_PX = 128
MURAL_COLUMNAS = 8
MURALES_PNG = os.path.join(TEXTURAS_KIT, "murales.png")
MURALES_JSON = os.path.join(TEXTURAS_KIT, "murales.json")
_MURALES = []


def murales():
    """Arma el atlas de murales (cada diseño reducido sin suavizar a MURAL_PX de lado)."""
    disenos = []
    # "virgen": lo que pintan los fieles de Santa Mugre (tools/map_import/make_murales_virgen.py);
    # va aparte de propaganda/ para que las bardas de map_test no cambien de diseño
    for carpeta, tipo in (("grafitis", "grafiti"), ("propaganda", "propaganda"), ("virgen", "virgen")):
        ruta = os.path.join(TEXTURAS_MAPA, carpeta)
        if not os.path.isdir(ruta):
            continue
        for archivo in sorted(os.listdir(ruta)):
            if archivo.lower().endswith((".png", ".webp", ".jpg")):
                disenos.append((os.path.join(ruta, archivo), tipo))
    filas = (len(disenos) + MURAL_COLUMNAS - 1) // MURAL_COLUMNAS
    atlas = np.zeros((filas * MURAL_PX, MURAL_COLUMNAS * MURAL_PX, 4), np.float32)
    indice = []
    for i, (ruta, tipo) in enumerate(disenos):
        px = _leer_png(ruta)
        h, w = px.shape[:2]
        escala = min(MURAL_PX / w, MURAL_PX / h, 1.0)
        nw, nh = max(1, int(w * escala)), max(1, int(h * escala))
        ys = (np.arange(nh) / escala).astype(int).clip(0, h - 1)
        xs = (np.arange(nw) / escala).astype(int).clip(0, w - 1)
        col, fila = i % MURAL_COLUMNAS, i // MURAL_COLUMNAS
        atlas[fila * MURAL_PX:fila * MURAL_PX + nh, col * MURAL_PX:col * MURAL_PX + nw] = px[ys][:, xs]
        W, H = MURAL_COLUMNAS * MURAL_PX, filas * MURAL_PX
        # UV de Blender (v hacia arriba): de abajo-izq a arriba-der
        indice.append({"archivo": os.path.basename(ruta), "tipo": tipo, "proporcion": nh / nw,
                       "uv": [col * MURAL_PX / W, 1 - (fila * MURAL_PX + nh) / H, (col * MURAL_PX + nw) / W, 1 - fila * MURAL_PX / H]})
    os.makedirs(TEXTURAS_KIT, exist_ok=True)
    _escribir_png(MURALES_PNG, atlas)
    guardar_json(MURALES_JSON, {"disenos": indice})
    _MURALES[:] = indice
    print("murales: %d diseños" % len(indice))


def lista_murales():
    if not _MURALES:
        if not os.path.exists(MURALES_JSON):
            murales()
        else:
            _MURALES[:] = json.load(open(MURALES_JSON, encoding="utf-8"))["disenos"]
    return _MURALES


def mat_arbol(nombre):
    """arbol_<x>_corteza y arbol_<x>_hojas (y los del arbolito de Tacos_ Props, arbol_corteza y arbol_hojas):
    textures/mapa/<nombre>.png (extraer_arbol_tacos.gd, extraer_arboles.gd). Las hojas llevan alfa recortado."""
    mat = bpy.data.materials.get(nombre)
    if mat:
        return mat
    mat = bpy.data.materials.new(nombre)
    arbol, bsdf = _arbol(mat)
    tex = arbol.nodes.new("ShaderNodeTexImage")
    tex.image = _imagen(os.path.join(TEXTURAS_KIT, nombre + ".png"))
    tex.interpolation = "Closest"
    arbol.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    if nombre.endswith("hojas"):
        arbol.links.new(tex.outputs[1], bsdf.inputs["Alpha"])
        try:
            mat.blend_method = "CLIP"
        except (AttributeError, TypeError):
            pass
    return mat


def _arbol_modelo():
    """Los arboles de modelos/arbol_tacos.json (leidos una vez): variantes con altura, ancho y las
    mallas "corteza" y "hojas" (v, uv, i), en metros, base en (0, 0, 0), Y arriba."""
    if "datos" not in _ARBOL_MODELO:
        import json
        with open(os.path.join(RAIZ, "tools", "blender", "mapa", "modelos", "arbol_tacos.json"), encoding="utf-8") as f:
            _ARBOL_MODELO["datos"] = json.load(f)["variantes"]
    return _ARBOL_MODELO["datos"]


_ARBOL_MODELO = {}


def mat_mural(rehacer=False):
    mat = bpy.data.materials.get("mural")
    if mat and not rehacer:
        return mat
    mat = mat or bpy.data.materials.new("mural")
    arbol, bsdf = _arbol(mat)
    tex = arbol.nodes.new("ShaderNodeTexImage")
    tex.image = _imagen(MURALES_PNG)
    tex.interpolation = "Closest"
    arbol.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    arbol.links.new(tex.outputs[1], bsdf.inputs["Alpha"])
    try:
        mat.blend_method = "CLIP"
    except (AttributeError, TypeError):
        pass
    return mat


def elegir_mural(semilla, tipo=None):
    """Un diseño fijo por semilla; tipo "grafiti" o "propaganda" (None: cualquiera)."""
    lista = [d for d in lista_murales() if tipo is None or d["tipo"] == tipo]
    return lista[semilla % len(lista)]


def esquinas_mural(a, b, base, normal, diseno, ancho_max, alto_max, salir=0.03):
    """Rectangulo del diseño en un muro (en el plano que va de a a b, con su normal hacia afuera),
    centrado en el tramo, sin estirar: devuelve 4 puntos (abajo-izq, abajo-der, arriba-der,
    arriba-izq) en las mismas coordenadas que a y b (x, y horizontales; z arriba) y sus UV."""
    ax, ay = a
    bx, by = b
    largo = math.hypot(bx - ax, by - ay)
    ancho = min(ancho_max, largo * 0.9)
    alto = ancho * diseno["proporcion"]
    if alto > alto_max:
        alto = alto_max
        ancho = alto / diseno["proporcion"]
    ux, uy = (bx - ax) / largo, (by - ay) / largo
    cx, cy = (ax + bx) / 2 + normal[0] * salir, (ay + by) / 2 + normal[1] * salir
    p0 = (cx - ux * ancho / 2, cy - uy * ancho / 2)
    p1 = (cx + ux * ancho / 2, cy + uy * ancho / 2)
    u0, v0, u1, v1 = diseno["uv"]
    return ([(p0[0], p0[1], base), (p1[0], p1[1], base), (p1[0], p1[1], base + alto), (p0[0], p0[1], base + alto)],
            [(u0, v0), (u1, v0), (u1, v1), (u0, v1)])


# --- Casa ---

PRETIL = 0.45               # m del borde de la azotea
TINACO_RADIO, TINACO_ALTO = 0.55, 1.1
COLOR_TINACO = (0.07, 0.07, 0.08)
COLOR_VARILLA = (0.36, 0.2, 0.12)


class _Azar:
    """Numeros fijos por casa (misma casa, misma fachada en cada armada)."""
    def __init__(self, semilla):
        self.r = np.random.default_rng(abs(hash(semilla)) % (2 ** 32) if isinstance(semilla, str) else semilla)

    def __call__(self, a=0.0, b=1.0):
        return float(self.r.uniform(a, b))

    def elegir(self, lista):
        return lista[int(self.r.integers(len(lista)))]


def _semilla(texto):
    return sum((i + 1) * ord(c) for i, c in enumerate(texto))


def _ccw(puntos):
    """[x, z] de Godot -> (x, y) de Blender en sentido antihorario visto desde arriba."""
    pts = [(px, -pz) for px, pz in puntos]
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))
    return pts if area > 0 else pts[::-1]


def _celda_fachada(azar, piso, en_frente, tramo, puerta_en, desgaste, tienda):
    roto = azar() < desgaste * 0.7
    if not en_frente:
        return CAIDO if azar() < desgaste * 0.5 else LISO
    if piso == 0:
        if tramo == puerta_en:
            celda = CORTINA if tienda else azar.elegir([PUERTA, PUERTA, ZAGUAN])
        else:
            celda = CORTINA if tienda and azar() < 0.5 else azar.elegir([VENTANA_ABAJO, VENTANA_ABAJO, LISO, CAIDO if desgaste > 0.5 else LISO])
    else:
        celda = azar.elegir(VENTANA_ARRIBA + [LISO])
    if roto and celda not in (LISO, CAIDO):
        return (celda[0], celda[1] + 2)
    return celda


def casa_malla(nombre, puntos, pisos=1, color=(0.8, 0.8, 0.8), frente=0, desgaste=0.5, tienda=False,
               tinaco=True, varillas=None, detalles=True, acabado=None, obra=None, ventanal=False, tapado=0.0):
    """La casa como una malla: paredes en tramos del atlas, pretil, azotea, tinaco y varillas.
    `puntos` es la huella ([x, z] relativos al origen de la pieza) y `frente` el indice del lado
    que da a la calle (el lado i va del punto i al i+1, en el orden del .json).
    Obra negra (La Gotera, docs/mapa/colonias/la_gotera.md): `acabado` "ladrillo" (rojo) o "block"
    (tabique gris), los dos sin enjarre y con dalas y castillos de concreto; `obra` "castillos" (el
    piso que nunca se construyo: castillos con la varilla de fuera encima de la azotea) o "losa"
    (ademas media losa colada sobre ellos); `ventanal` (un ventanal de herreria en la planta baja
    del frente) y `tapado` (que parte de las ventanas de arriba estan tapadas con lona o tabla)."""
    import bmesh
    azar = _Azar(_semilla(nombre))
    mats = materiales()
    bm = bmesh.new()
    capa_uv = bm.loops.layers.uv.new("UVMap")
    capa_color = bm.loops.layers.float_color.new("Color")
    indice = {"fachada_kit": 0, "azotea": 1, "tinaco": 2, "varilla": 3, "mural": 4, "detalle": 5}
    alto = pisos * PISO
    lisos = []      # tramos lisos de la planta baja del frente: ahi va el mural, si toca
    crudo = {"ladrillo": LADRILLO, "block": BLOCK}.get(acabado)
    pretil = crudo if crudo else LISO
    muros = []      # (a, b, tramos) de cada lado, para los detalles de las fachadas
    ocupado = []    # (x, y, radio) de lo que ya hay en la azotea
    ventanas = []   # (p0, p1) de los tramos con ventana en la planta baja: llevan reja
    ventanales = [] # (p0, p1) del tramo del ventanal de herreria (obra negra)
    tapadas = []    # (p0, p1, z0, lona) ventanas de arriba tapadas con lona o con tabla
    # Los colores de la paleta estan en sRGB; el color de vertice va lineal
    ladrillo = crudo is not None
    if acabado == "ladrillo":
        # Obra negra de ladrillo (la foto de la cancha de AG): los muros lisos son el mosaico de
        # ladrillo y lo que rodea las ventanas va del color del ladrillo
        color = COLOR_LADRILLO
    elif acabado == "block":
        color = COLOR_BLOCK
    rgba = tuple(c ** 2.2 for c in color[:3]) + (1.0,)

    # El orden del .json decide cual es el frente; para las caras hace falta el sentido
    pts_json = [(px, -pz) for px, pz in puntos]
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts_json, pts_json[1:] + pts_json[:1]))
    invertido = area < 0
    n = len(pts_json)

    def cara(esquinas, uvs, mat, colores=None):
        f = bm.faces.new([bm.verts.new(c) for c in esquinas])
        f.material_index = indice[mat]
        for loop, uv in zip(f.loops, uvs):
            loop[capa_uv].uv = uv
            loop[capa_color] = colores or rgba
        return f

    for i in range(n):
        a, b = pts_json[i], pts_json[(i + 1) % n]
        if invertido:
            a, b = b, a
        largo = math.hypot(b[0] - a[0], b[1] - a[1])
        if largo < 0.05:
            continue
        en_frente = i == frente
        tramos = max(1, round(largo / PISO))
        muros.append((a, b, tramos))
        puerta_en = tramos // 2 if en_frente else -1
        for piso in range(pisos):
            for t in range(tramos):
                u0, u1 = t / tramos, (t + 1) / tramos
                p0 = (a[0] + (b[0] - a[0]) * u0, a[1] + (b[1] - a[1]) * u0)
                p1 = (a[0] + (b[0] - a[0]) * u1, a[1] + (b[1] - a[1]) * u1)
                z0, z1 = piso * PISO, (piso + 1) * PISO
                celda = _celda_fachada(azar, piso, en_frente, t, puerta_en, desgaste, tienda)
                if ladrillo and celda in (LISO, CAIDO):
                    celda = crudo
                # El ventanal de herreria: el tramo junto a la puerta, en la planta baja del frente
                if ventanal and en_frente and piso == 0 and tramos >= 2 and t == (puerta_en + 1 if puerta_en + 1 < tramos else puerta_en - 1):
                    celda = crudo or LISO
                    ventanales.append((p0, p1))
                if en_frente and piso == 0 and celda in (LISO, CAIDO):
                    lisos.append((p0, p1))
                if piso == 0 and celda == VENTANA_ABAJO:
                    ventanas.append((p0, p1))
                if piso > 0 and celda in VENTANA_ARRIBA and azar() < tapado:
                    tapadas.append((p0, p1, z0, azar() < 0.6))
                cara([(p0[0], p0[1], z0), (p1[0], p1[1], z0), (p1[0], p1[1], z1), (p0[0], p0[1], z1)],
                     [uv_mosaico(celda, 0, 0), uv_mosaico(celda, 1, 0), uv_mosaico(celda, 1, 1), uv_mosaico(celda, 0, 1)], "fachada_kit")
        # Pretil: lo de abajo del aplanado liso
        v = PRETIL / PISO
        cara([(a[0], a[1], alto), (b[0], b[1], alto), (b[0], b[1], alto + PRETIL), (a[0], a[1], alto + PRETIL)],
             [uv_mosaico(pretil, 0, 0), uv_mosaico(pretil, largo / PISO % 1 or 1, 0), uv_mosaico(pretil, largo / PISO % 1 or 1, v), uv_mosaico(pretil, 0, v)], "fachada_kit")

    # Un mural (grafiti o propaganda) en un tramo liso del frente; mas con mas desgaste
    if lisos and azar() < 0.3 + desgaste * 0.5:
        p0, p1 = lisos[int(azar(0, len(lisos)))]
        normal = ((p1[1] - p0[1]), -(p1[0] - p0[0]))
        ln = math.hypot(*normal) or 1.0
        diseno = elegir_mural(_semilla(nombre) * 7, "propaganda" if azar() < 0.45 else "grafiti")
        base = 1.0 if diseno["tipo"] == "propaganda" else 0.3
        esquinas, uvs = esquinas_mural(p0, p1, base, (normal[0] / ln, normal[1] / ln), diseno, PISO * 0.95, PISO - base - 0.1)
        cara(esquinas, uvs, "mural", (1.0, 1.0, 1.0, 1.0))

    # Azotea (un poco abajo del pretil) y la cara de adentro del pretil no hace falta: no se ve
    ccw = _ccw(puntos)
    cara([(x, y, alto + 0.05) for x, y in ccw], [(0, 0)] * len(ccw), "azotea")

    # Tinaco negro en una esquina de la azotea, lejos del frente
    if tinaco:
        cx = sum(p[0] for p in ccw) / len(ccw)
        cy = sum(p[1] for p in ccw) / len(ccw)
        esquina = ccw[int(azar(0, len(ccw)))]
        tx, ty = cx + (esquina[0] - cx) * 0.55, cy + (esquina[1] - cy) * 0.55
        _cilindro(bm, cara, (tx, ty, alto + 0.05), TINACO_RADIO, TINACO_ALTO, "tinaco")
        ocupado.append((tx, ty, TINACO_RADIO + 0.3))
    # Varillas de obra negra: el segundo piso que nunca se construyo
    if varillas if varillas is not None else azar() < desgaste * 0.35:
        for k in range(4):
            esquina = ccw[k % len(ccw)]
            _caja_bm(cara, (esquina[0] * 0.9, esquina[1] * 0.9, alto), 0.05, 1.2, "varilla")
            ocupado.append((esquina[0] * 0.9, esquina[1] * 0.9, 0.3))
    if detalles:
        _detalles_casa(cara, nombre, muros, ccw, alto, pisos, desgaste, ocupado, ventanas)
    if ladrillo:
        _estructura(cara, muros, ccw, pisos)
    if obra in ("castillos", "losa"):
        _obra_arriba(cara, nombre, muros, ccw, alto, obra, crudo or BLOCK)
    if ventanales or tapadas:
        _huecos_obra(cara, nombre, ccw, ventanales, tapadas)

    malla = bpy.data.meshes.new(nombre)
    bm.to_mesh(malla)
    bm.free()
    for m in ("fachada_kit", "azotea"):
        malla.materials.append(mats[m])
    malla.materials.append(material("tinaco", COLOR_TINACO))
    malla.materials.append(material("varilla", COLOR_VARILLA))
    malla.materials.append(mat_mural())
    malla.materials.append(mat_detalle())
    malla.color_attributes.active_color = malla.color_attributes["Color"]
    # El exportador de glTF lee el de render (con -1 sale todo blanco)
    malla.color_attributes.render_color_index = malla.color_attributes.active_color_index
    return malla


def _cilindro(bm, cara, base, radio, alto, mat, lados=10):
    x, y, z = base
    anillo = [(x + math.cos(k * math.tau / lados) * radio, y + math.sin(k * math.tau / lados) * radio) for k in range(lados)]
    negro = (1.0, 1.0, 1.0, 1.0)
    for k in range(lados):
        a, b = anillo[k], anillo[(k + 1) % lados]
        cara([(a[0], a[1], z), (b[0], b[1], z), (b[0], b[1], z + alto), (a[0], a[1], z + alto)], [(0, 0)] * 4, mat, negro)
    cara([(px, py, z + alto) for px, py in anillo], [(0, 0)] * lados, mat, negro)


def _caja_bm(cara, base, ancho, alto, mat):
    x, y, z = base
    h = ancho / 2
    blanco = (1.0, 1.0, 1.0, 1.0)
    esquinas = [(x - h, y - h), (x + h, y - h), (x + h, y + h), (x - h, y + h)]
    for k in range(4):
        a, b = esquinas[k], esquinas[(k + 1) % 4]
        cara([(a[0], a[1], z), (b[0], b[1], z), (b[0], b[1], z + alto), (a[0], a[1], z + alto)], [(0, 0)] * 4, mat, blanco)


# --- Detalles de casa: lo que cuelga de las fachadas y lo que hay en las azoteas ---
# Todo con el atlas de la fachada (como "detalle_kit", mat_detalle) y la UV fija en el centro del
# mosaico liso, asi que el color de vertice los pinta.
COLOR_CLIMA = (0.82, 0.82, 0.78)
COLOR_NEGRO = (0.09, 0.09, 0.1)
COLOR_PANEL = (0.12, 0.17, 0.3)
COLOR_GAS = (0.86, 0.86, 0.84)
HERRERIA = [(0.08, 0.08, 0.09), (0.08, 0.08, 0.09), (0.85, 0.85, 0.82), (0.15, 0.35, 0.25), (0.45, 0.12, 0.1)]
ROPA = [(0.8, 0.18, 0.2), (0.15, 0.4, 0.78), (0.92, 0.75, 0.15), (0.9, 0.9, 0.88), (0.9, 0.42, 0.62), (0.2, 0.62, 0.32)]


def _cara_hacia(cara, puntos, normal, color, mat="detalle"):
    """Una cara de color liso con su frente hacia `normal` (voltea los puntos si hace falta)."""
    import mathutils
    a, b, c = (mathutils.Vector(p) for p in puntos[:3])
    if (b - a).cross(c - a).dot(mathutils.Vector(normal)) < 0:
        puntos = puntos[::-1]
    uv = uv_mosaico(LISO, 0.5, 0.5)
    cara(puntos, [uv] * len(puntos), mat, tuple(k ** 2.2 for k in color) + (1.0,))


def _caja_detalle(cara, centro, u, ancho, fondo, alto, color, abajo=False, mat="detalle"):
    """Caja parada en `centro` (x, y, z de la base) con su ancho a lo largo de `u` (x, y)."""
    x, y, z = centro
    ux, uy = u
    nx, ny = -uy, ux
    ha, hf = ancho / 2, fondo / 2
    def p(sa, sf, zz):
        return (x + ux * sa * ha + nx * sf * hf, y + uy * sa * ha + ny * sf * hf, zz)
    z1 = z + alto
    _cara_hacia(cara, [p(-1, -1, z1), p(1, -1, z1), p(1, 1, z1), p(-1, 1, z1)], (0, 0, 1), color, mat)
    for (sa0, sf0), (sa1, sf1), n in (((-1, -1), (1, -1), (-nx, -ny, 0)), ((1, -1), (1, 1), (ux, uy, 0)),
                                      ((1, 1), (-1, 1), (nx, ny, 0)), ((-1, 1), (-1, -1), (-ux, -uy, 0))):
        _cara_hacia(cara, [p(sa0, sf0, z), p(sa1, sf1, z), p(sa1, sf1, z1), p(sa0, sf0, z1)], n, color, mat)
    if abajo:
        _cara_hacia(cara, [p(-1, -1, z), p(1, -1, z), p(1, 1, z), p(-1, 1, z)], (0, 0, -1), color, mat)


COLOR_LADRILLO = (0.66, 0.34, 0.22)
COLOR_BLOCK = (0.6, 0.6, 0.58)
COLOR_CONCRETO = (0.62, 0.61, 0.58)
COLOR_OXIDO = (0.42, 0.22, 0.12)
COLOR_TABLA = (0.5, 0.36, 0.22)
LONAS_TAPADO = [(0.15, 0.4, 0.78), (0.2, 0.62, 0.32), (0.85, 0.15, 0.15), (0.92, 0.75, 0.15), (0.1, 0.1, 0.12)]


def _estructura(cara, muros, ccw, pisos):
    """Dalas de concreto gris en cada losa y castillos en las esquinas, saliendo un poco del muro:
    lo que se le ve a una casa de ladrillo sin aplanar. Con la fachada (no se esconde de lejos)."""
    cx = sum(p[0] for p in ccw) / len(ccw)
    cy = sum(p[1] for p in ccw) / len(ccw)
    for a, b, _t in muros:
        largo = math.hypot(b[0] - a[0], b[1] - a[1])
        u = ((b[0] - a[0]) / largo, (b[1] - a[1]) / largo)
        n = (-u[1], u[0])
        m = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        if n[0] * (m[0] - cx) + n[1] * (m[1] - cy) < 0:
            n = (-n[0], -n[1])
        # Una banda plana apenas saliente por piso (era una caja: seis caras por muro y piso)
        for piso in range(1, pisos + 1):
            z0, z1 = piso * PISO - 0.22, piso * PISO + 0.02
            p0 = (a[0] + n[0] * 0.05 - u[0] * 0.06, a[1] + n[1] * 0.05 - u[1] * 0.06)
            p1 = (b[0] + n[0] * 0.05 + u[0] * 0.06, b[1] + n[1] * 0.05 + u[1] * 0.06)
            _cara_hacia(cara, [(p0[0], p0[1], z0), (p1[0], p1[1], z0), (p1[0], p1[1], z1), (p0[0], p0[1], z1)], (n[0], n[1], 0), COLOR_CONCRETO, mat="fachada_kit")
    for x, y in ccw:
        _caja_detalle(cara, (x, y, 0.0), (1.0, 0.0), 0.3, 0.3, pisos * PISO, COLOR_CONCRETO, mat="fachada_kit")


def _obra_arriba(cara, nombre, muros, ccw, alto, obra, celda):
    """El piso que nunca se construyo (obra negra de La Gotera): castillos de concreto en las
    esquinas y a media pared subiendo un piso mas desde la azotea, con las varillas oxidadas de
    fuera; con `obra` "losa", ademas media losa colada encima (la mitad de atras de la casa) y un
    pedazo de muro de block de un metro bajo ella."""
    azar = _Azar(_semilla(nombre) * 5 + 2)
    cx = sum(p[0] for p in ccw) / len(ccw)
    cy = sum(p[1] for p in ccw) / len(ccw)
    castillos = list(ccw)
    for a, b, _t in muros:
        largo = math.hypot(b[0] - a[0], b[1] - a[1])
        n = int(largo / 6.5)
        for i in range(1, n + 1):
            f = i / (n + 1)
            castillos.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f))
    for n_c, (x, y) in enumerate(castillos):
        # Un poco hacia adentro, para no colgar del pretil
        px, py = x + (cx - x) * 0.04, y + (cy - y) * 0.04
        h = PISO * azar(0.75, 1.0) if obra == "castillos" else PISO
        _caja_detalle(cara, (px, py, alto), (1.0, 0.0), 0.3, 0.3, h, COLOR_CONCRETO, mat="fachada_kit")
        # Dos varillas en los de esquina, una en los de en medio (eran cuatro: pesaban)
        for dx, dy in ((0.04, 0.04),):
            _caja_detalle(cara, (px + dx, py + dy, alto + h), (1.0, 0.0), 0.04, 0.04, azar(0.5, 1.1), COLOR_OXIDO)
    if obra == "losa":
        # La losa sobre la mitad de atras (la mas lejos del frente, que es el primer muro)
        a, b, _t = muros[0]
        fx, fy = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        nx, ny = cx - fx, cy - fy
        ln = math.hypot(nx, ny) or 1.0
        nx, ny = nx / ln, ny / ln
        ux, uy = -ny, nx
        anchos = [abs((p[0] - cx) * ux + (p[1] - cy) * uy) for p in ccw]
        fondos = [(p[0] - cx) * nx + (p[1] - cy) * ny for p in ccw]
        ancho = 2 * max(anchos) - 0.3
        fondo = max(fondos) * 1.05
        mx, my = cx + nx * fondo / 2, cy + ny * fondo / 2
        _caja_detalle(cara, (mx, my, alto + PISO), (ux, uy), ancho, fondo, 0.14, COLOR_CONCRETO, abajo=True, mat="fachada_kit")
        for i in range(3):
            _caja_detalle(cara, (mx + ux * (i - 1) * ancho * 0.3, my + uy * (i - 1) * ancho * 0.3, alto + PISO + 0.14), (1.0, 0.0), 0.035, 0.035, azar(0.4, 0.9), COLOR_OXIDO)
        # Un metro de block sobre el muro de atras, abajo de la losa
        tras = max(muros[1:], key=lambda m: (m[0][0] + m[1][0]) / 2 * nx + (m[0][1] + m[1][1]) / 2 * ny) if len(muros) > 1 else None
        if tras:
            p0, p1 = tras[0], tras[1]
            lx = math.hypot(p1[0] - p0[0], p1[1] - p0[1]) / PISO
            cara([(p0[0], p0[1], alto + 0.05), (p1[0], p1[1], alto + 0.05), (p1[0], p1[1], alto + 1.0), (p0[0], p0[1], alto + 1.0)],
                 [uv_mosaico(celda, 0, 0), uv_mosaico(celda, lx % 1 or 1, 0), uv_mosaico(celda, lx % 1 or 1, 0.35), uv_mosaico(celda, 0, 0.35)], "fachada_kit")
            cara([(p1[0], p1[1], alto + 0.05), (p0[0], p0[1], alto + 0.05), (p0[0], p0[1], alto + 1.0), (p1[0], p1[1], alto + 1.0)],
                 [uv_mosaico(celda, 0, 0), uv_mosaico(celda, lx % 1 or 1, 0), uv_mosaico(celda, lx % 1 or 1, 0.35), uv_mosaico(celda, 0, 0.35)], "fachada_kit")


def _huecos_obra(cara, nombre, ccw, ventanales, tapadas):
    """Lo que tapa los huecos de una obra negra: el ventanal de herreria de la planta baja (hueco
    oscuro con su cuadricula de fierro) y las ventanas de arriba tapadas con una lona de color o
    con tablas, porque todavia no hay vidrio."""
    azar = _Azar(_semilla(nombre) * 11 + 7)
    cx = sum(p[0] for p in ccw) / len(ccw)
    cy = sum(p[1] for p in ccw) / len(ccw)

    def marco(p0, p1):
        largo = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        ux, uy = (p1[0] - p0[0]) / largo, (p1[1] - p0[1]) / largo
        nx, ny = -uy, ux
        mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        if nx * (mx - cx) + ny * (my - cy) < 0:
            nx, ny = -nx, -ny
        return largo, (ux, uy), (nx, ny)

    color_reja = azar.elegir(HERRERIA)
    for p0, p1 in ventanales:
        largo, (ux, uy), (nx, ny) = marco(p0, p1)
        s0, s1 = 0.1 * largo, 0.9 * largo
        z0, z1 = 0.35, PISO - 0.45
        def en(s, salir=0.03):
            return (p0[0] + ux * s + nx * salir, p0[1] + uy * s + ny * salir)
        # El hueco oscuro, apenas afuera del muro
        a, b = en(s0, 0.02), en(s1, 0.02)
        _cara_hacia(cara, [(a[0], a[1], z0), (b[0], b[1], z0), (b[0], b[1], z1), (a[0], a[1], z1)], (nx, ny, 0), (0.05, 0.05, 0.06))
        # La cuadricula: barrotes a cada 0.3 m y tres travesanos, saliendo 7 cm
        for z in (z0, z1 - 0.04):
            x, y = en((s0 + s1) / 2, 0.07)
            _caja_detalle(cara, (x, y, z), (ux, uy), s1 - s0, 0.04, 0.04, color_reja)
        barrotes = max(3, round((s1 - s0) / 0.6))
        for i in range(barrotes + 1):
            x, y = en(s0 + (s1 - s0) * i / barrotes, 0.07)
            _caja_detalle(cara, (x, y, z0), (ux, uy), 0.035, 0.035, z1 - z0, color_reja)
    for p0, p1, zb, lona in tapadas:
        largo, (ux, uy), (nx, ny) = marco(p0, p1)
        # La ventana del mosaico va mas o menos de 0.22 a 0.8 del ancho y de 0.25 a 0.8 del alto
        s0, s1 = 0.2 * largo, 0.82 * largo
        z0, z1 = zb + 0.22 * PISO, zb + 0.82 * PISO
        if lona or True:
            c = azar.elegir(LONAS_TAPADO) if lona else COLOR_TABLA
            a = (p0[0] + ux * s0 + nx * 0.025, p0[1] + uy * s0 + ny * 0.025)
            b = (p0[0] + ux * s1 + nx * 0.025, p0[1] + uy * s1 + ny * 0.025)
            _cara_hacia(cara, [(a[0], a[1], z0), (b[0], b[1], z0), (b[0], b[1], z1 + 0.05), (a[0], a[1], z1 + 0.05)], (nx, ny, 0), c)
        else:
            # Dos tablas anchas (eran cuatro: pesaban), con un hueco oscuro entre ellas
            tablas = 2
            a = (p0[0] + ux * s0 + nx * 0.02, p0[1] + uy * s0 + ny * 0.02)
            b = (p0[0] + ux * s1 + nx * 0.02, p0[1] + uy * s1 + ny * 0.02)
            _cara_hacia(cara, [(a[0], a[1], z0), (b[0], b[1], z0), (b[0], b[1], z1), (a[0], a[1], z1)], (nx, ny, 0), (0.05, 0.05, 0.06))
            for i in range(tablas):
                z = z0 + (z1 - z0) * (i + 0.5) / tablas
                x, y = p0[0] + ux * (s0 + s1) / 2 + nx * 0.04, p0[1] + uy * (s0 + s1) / 2 + ny * 0.04
                _caja_detalle(cara, (x, y, z - 0.17), (ux, uy), (s1 - s0) * azar(0.9, 1.1), 0.04, 0.34, COLOR_TABLA)


def _detalles_casa(cara, nombre, muros, ccw, alto, pisos, desgaste, ocupado, ventanas=()):
    """Climas de ventana en las fachadas y, en la azotea, antena, calentador solar, tanque de
    gas y tendedero con ropa. Con su propio azar, para no cambiar las fachadas ya armadas."""
    azar = _Azar(_semilla(nombre) * 3 + 1)
    cx = sum(p[0] for p in ccw) / len(ccw)
    cy = sum(p[1] for p in ccw) / len(ccw)
    # Climas: en los tramos de los pisos de arriba (en la planta baja se los roban)
    for a, b, tramos in muros:
        largo = math.hypot(b[0] - a[0], b[1] - a[1])
        ux, uy = (b[0] - a[0]) / largo, (b[1] - a[1]) / largo
        nx, ny = -uy, ux
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        if nx * (mx - cx) + ny * (my - cy) < 0:
            nx, ny = -nx, -ny
        for piso in range(1, pisos):
            for t in range(tramos):
                if azar() > 0.12:
                    continue
                s = (t + 0.5) / tramos * largo + azar(-0.5, 0.5)
                px, py = a[0] + ux * s + nx * 0.24, a[1] + uy * s + ny * 0.24
                _caja_detalle(cara, (px, py, piso * PISO + azar(0.5, 0.9)), (ux, uy), 0.66, 0.46, 0.42, COLOR_CLIMA, abajo=True)

    # Rejas de herreria en las ventanas de la planta baja (el mosaico VENTANA_ABAJO tiene la
    # ventana de 0.25 a 0.78 del ancho y de 0.28 a 0.75 del alto): marco, barrotes y travesanos
    color_reja = azar.elegir(HERRERIA)
    for p0, p1 in ventanas:
        largo = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        ux, uy = (p1[0] - p0[0]) / largo, (p1[1] - p0[1]) / largo
        nx, ny = -uy, ux
        mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        if nx * (mx - cx) + ny * (my - cy) < 0:
            nx, ny = -nx, -ny
        s0, s1 = 0.22 * largo, 0.81 * largo
        z0, z1 = 0.26 * PISO, 0.77 * PISO
        sale = 0.07
        def en(s, salir=sale):
            return (p0[0] + ux * s + nx * salir, p0[1] + uy * s + ny * salir)
        for s in (s0, s1):
            x, y = en(s)
            _caja_detalle(cara, (x, y, z0), (ux, uy), 0.04, 0.04, z1 - z0, color_reja)
        for z in (z0, (z0 + z1) / 2, z1 - 0.04):
            x, y = en((s0 + s1) / 2)
            _caja_detalle(cara, (x, y, z), (ux, uy), s1 - s0, 0.04, 0.04, color_reja, abajo=True)
        barrotes = max(3, round((s1 - s0) / 0.13))
        for i in range(1, barrotes):
            x, y = en(s0 + (s1 - s0) * i / barrotes)
            _caja_detalle(cara, (x, y, z0), (ux, uy), 0.025, 0.025, z1 - z0, color_reja)

    def lugar(radio):
        """Un punto de la azotea lejos de lo que ya hay (tinaco, varillas) o None."""
        for _ in range(6):
            v = ccw[int(azar(0, len(ccw)))]
            f = azar(0.15, 0.6)
            x, y = cx + (v[0] - cx) * f, cy + (v[1] - cy) * f
            if all(math.hypot(x - ox, y - oy) > radio + orad for ox, oy, orad in ocupado):
                ocupado.append((x, y, radio))
                return x, y
        return None
    z = alto + 0.05
    giro = azar(0, math.tau)
    u = (math.cos(giro), math.sin(giro))
    if azar() < 0.4:
        sitio = lugar(0.6)
        if sitio:
            x, y = sitio
            _caja_detalle(cara, (x, y, z), u, 0.05, 0.05, 2.6, COLOR_NEGRO)
            for i, (h, l) in enumerate(((1.8, 1.0), (2.15, 0.75), (2.5, 0.5))):
                _caja_detalle(cara, (x, y, z + h), u, l, 0.03, 0.03, COLOR_NEGRO)
    if azar() < 0.22:
        sitio = lugar(1.0)
        if sitio:
            x, y = sitio
            nx, ny = -u[1], u[0]
            # Panel inclinado 35 grados que sube hacia n, con su termotanque blanco arriba
            sube, largo = math.radians(35), 1.5
            h0, h1 = z + 0.3, z + 0.3 + math.sin(sube) * largo
            d = math.cos(sube) * largo / 2
            esq = [(x - u[0] * 0.5 - nx * d, y - u[1] * 0.5 - ny * d, h0), (x + u[0] * 0.5 - nx * d, y + u[1] * 0.5 - ny * d, h0),
                   (x + u[0] * 0.5 + nx * d, y + u[1] * 0.5 + ny * d, h1), (x - u[0] * 0.5 + nx * d, y - u[1] * 0.5 + ny * d, h1)]
            _cara_hacia(cara, esq, (-nx * math.sin(sube), -ny * math.sin(sube), math.cos(sube)), COLOR_PANEL)
            _cara_hacia(cara, esq, (nx * math.sin(sube), ny * math.sin(sube), -math.cos(sube)), COLOR_GAS)
            _caja_detalle(cara, (x + nx * (d + 0.2), y + ny * (d + 0.2), h1 - 0.1), u, 1.2, 0.42, 0.42, COLOR_GAS, abajo=True)
            _caja_detalle(cara, (x + nx * (d + 0.2), y + ny * (d + 0.2), z), u, 1.0, 0.06, h1 - 0.1 - z, COLOR_NEGRO)
    if azar() < 0.3:
        sitio = lugar(0.4)
        if sitio:
            x, y = sitio
            lados = 8
            anillo = [(x + math.cos(k * math.tau / lados) * 0.3, y + math.sin(k * math.tau / lados) * 0.3) for k in range(lados)]
            for k in range(lados):
                p0, p1 = anillo[k], anillo[(k + 1) % lados]
                _cara_hacia(cara, [(p0[0], p0[1], z), (p1[0], p1[1], z), (p1[0], p1[1], z + 1.1), (p0[0], p0[1], z + 1.1)],
                            ((p0[0] + p1[0]) / 2 - x, (p0[1] + p1[1]) / 2 - y, 0), COLOR_GAS)
            _cara_hacia(cara, [(px, py, z + 1.1) for px, py in anillo], (0, 0, 1), COLOR_GAS)
    if azar() < 0.3 + desgaste * 0.2:
        sitio = lugar(1.4)
        if sitio:
            x, y = sitio
            l = 2.6
            for s in (-1, 1):
                _caja_detalle(cara, (x + u[0] * s * l / 2, y + u[1] * s * l / 2, z), u, 0.05, 0.05, 1.7, COLOR_NEGRO)
            _caja_detalle(cara, (x, y, z + 1.65), u, l, 0.02, 0.02, COLOR_NEGRO)
            prendas = int(azar(2, 6))
            for i in range(prendas):
                s = -l / 2 + 0.35 + (l - 0.7) * (i + azar(0.1, 0.9)) / prendas
                ancho, colgado = azar(0.35, 0.6), azar(0.4, 0.75)
                _caja_detalle(cara, (x + u[0] * s, y + u[1] * s, z + 1.65 - colgado), u, ancho, 0.02, colgado,
                              ROPA[int(azar(0, len(ROPA)))])


# --- Fotos: materiales con textura (cantera, empedrado, lamina...) ---
# Material "foto_<nombre>": textures/mapa/<nombre>.png, un pedazo de la foto de Poly Haven del
# cache reducido a FOTO_PX y teñido; en Godot MapaPostImport lo carga por el nombre. Las UV las
# pone el Constructor en metros (FOTO_METROS por repeticion).
FOTO_PX = 128
# nombre -> (foto, color o None, metros por repeticion). Con color se usa solo el detalle de la
# foto (su brillo alrededor del promedio) sobre ese color; sin color, la foto tal cual
FOTOS = {"cantera": ("old_sandstone_02", (0.84, 0.74, 0.64), 2.0),
         "cantera_oscura": ("old_sandstone_02", (0.6, 0.52, 0.46), 2.0),
         "aplanado_palacio": ("clay_plaster", (0.93, 0.84, 0.6), 2.5),
         "teja": ("clay_roof_tiles", None, 2.0),
         "lamina_verde": ("green_metal_rust", None, 1.5),
         "madera": ("blue_painted_planks", (0.45, 0.32, 0.22), 1.5),
         "piedra_plaza": ("cobblestone_floor_01", None, 2.0),
         "aplanado_rojo": ("red_plaster_weathered", None, 2.5),
         "aplanado_blanco": ("clay_plaster", (0.9, 0.88, 0.82), 2.5),
         "cantera_rosa": ("old_sandstone_02", (0.86, 0.66, 0.58), 1.5),
         # Dibujadas aqui (_mamposteria, _azulejo), no fotos
         "mamposteria": ("_mamposteria", None, 1.5),
         "azulejo_amarillo": ("_azulejo", None, 1.0),
         "block": ("_block", None, 1.0),
         "ladrillo_rojo": ("_ladrillo_foto", None, 1.0),
         "tierra": ("_tierra", None, 2.0)}


def _mamposteria(tam=FOTO_PX):
    """Muro de piedra de mamposteria (la parroquia de Arandas): piedras rosas, beige y grises
    de formas irregulares en mezcla clara. Celdas de Voronoi que se repiten sin costura."""
    rng = np.random.default_rng(5)
    n = 70
    puntos = rng.random((n, 2)) * tam
    tonos = np.array([(0.72, 0.52, 0.46), (0.78, 0.66, 0.55), (0.6, 0.5, 0.46), (0.82, 0.72, 0.62),
                      (0.55, 0.42, 0.38), (0.7, 0.6, 0.52)])
    colores = tonos[rng.integers(len(tonos), size=n)] * rng.uniform(0.85, 1.1, (n, 1))
    yy, xx = np.mgrid[0:tam, 0:tam]
    d1 = np.full((tam, tam), 1e9)
    d2 = np.full((tam, tam), 1e9)
    cual = np.zeros((tam, tam), int)
    for i, (px, py) in enumerate(puntos):
        dx = np.abs(xx - px)
        dy = np.abs(yy - py)
        dx = np.minimum(dx, tam - dx)
        dy = np.minimum(dy, tam - dy)
        d = np.sqrt(dx * dx + dy * dy)
        cerca = d < d1
        d2 = np.where(cerca, d1, np.minimum(d2, d))
        cual = np.where(cerca, i, cual)
        d1 = np.where(cerca, d, d1)
    px = np.ones((tam, tam, 4), np.float32)
    px[..., :3] = colores[cual] * (1.0 - np.clip(d1 / 30.0, 0, 0.25))[..., None]
    junta = (d2 - d1) < 1.6
    px[junta, :3] = (0.8, 0.77, 0.7)
    return px


def _ladrillo_foto(tam=FOTO_PX):
    """Ladrillo rojo de los tuneles de La Gotera, a 1 m por repeticion (ladrillo de 7 x 21 cm con
    su junta), oscurecido por la humedad en manchas."""
    rng = np.random.default_rng(13)
    px = np.ones((tam, tam, 4), np.float32)
    px[..., :3] = (0.52, 0.48, 0.42)
    alto, largo = 9, 27
    for fila in range(tam // alto + 1):
        desfase = (largo // 2) * (fila % 2)
        for col in range(-1, tam // largo + 2):
            x0, y0 = col * largo + desfase, fila * alto
            tono = np.array([0.55, 0.27, 0.18]) * rng.uniform(0.75, 1.15)
            px[max(y0, 0):min(y0 + alto - 1, tam), max(x0, 0):min(x0 + largo - 1, tam), :3] = tono
    mancha = rng.random((tam // 16, tam // 16))
    mancha = np.kron(mancha, np.ones((16, 16)))
    px[..., :3] *= (0.8 + 0.25 * mancha)[..., None]
    return np.clip(px, 0, 1)


def _tierra(tam=FOTO_PX):
    """Tierra seca de baldio: cafe con manchas, piedritas y terrones (se repite sin costura)."""
    rng = np.random.default_rng(9)
    gruesa = rng.random((tam // 16, tam // 16))
    gruesa = np.kron(gruesa, np.ones((16, 16)))
    gruesa = (gruesa + np.roll(gruesa, 8, 0) + np.roll(gruesa, 8, 1) + np.roll(np.roll(gruesa, 8, 0), 8, 1)) / 4
    fina = rng.random((tam, tam))
    brillo = 0.75 + gruesa * 0.25 + (fina - 0.5) * 0.15
    px = np.ones((tam, tam, 4), np.float32)
    px[..., :3] = np.array((0.5, 0.38, 0.26)) * brillo[..., None]
    piedras = rng.random((tam, tam)) > 0.985
    px[piedras, :3] = (0.62, 0.58, 0.52)
    return np.clip(px, 0, 1)


def _azulejo(tam=FOTO_PX):
    """Azulejo amarillo y blanco de las cupulas, en cuadros de 16 px con junta oscura."""
    px = np.ones((tam, tam, 4), np.float32)
    c = 16
    yy, xx = np.mgrid[0:tam, 0:tam]
    amarillo = ((xx // c + yy // c) % 2) == 0
    px[..., :3] = np.where(amarillo[..., None], (0.93, 0.72, 0.16), (0.92, 0.9, 0.84))
    # Rombo blanco al centro de cada amarillo (el dibujo de talavera)
    cx, cy = xx % c - c / 2 + 0.5, yy % c - c / 2 + 0.5
    rombo = amarillo & (np.abs(cx) + np.abs(cy) < 4)
    px[rombo, :3] = (0.92, 0.9, 0.84)
    px[(xx % c == 0) | (yy % c == 0), :3] = (0.35, 0.3, 0.22)
    return px


def foto(nombre, rehacer=False):
    """El material foto_<nombre> (y su png, si falta)."""
    origen, tinte, _metros = FOTOS[nombre]
    ruta = os.path.join(TEXTURAS_KIT, nombre + ".png")
    if rehacer or not os.path.exists(ruta):
        px = globals()[origen]() if origen.startswith("_") else _foto_mosaico(origen, FOTO_PX)
        if tinte is not None:
            brillo = px[..., :3].mean(axis=2, keepdims=True)
            px[..., :3] = np.array(tinte, np.float32) * (1.0 + (brillo - brillo.mean()) * 1.2)
        os.makedirs(TEXTURAS_KIT, exist_ok=True)
        _escribir_png(ruta, np.clip(px, 0, 1))
    mat = bpy.data.materials.get("foto_" + nombre)
    if mat and not rehacer:
        return mat
    mat = mat or bpy.data.materials.new("foto_" + nombre)
    arbol, bsdf = _arbol(mat)
    tex = arbol.nodes.new("ShaderNodeTexImage")
    tex.image = _imagen(ruta)
    tex.interpolation = "Closest"
    arbol.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    return mat


def metros_foto(mat_nombre):
    if mat_nombre.startswith("foto_"):
        return FOTOS[mat_nombre[5:]][2]
    return 1.0


# --- Constructor: mallas de piezas en coordenadas de Godot ---
# x a la derecha, y arriba, z hacia el frente (la calle). Por dentro pasa a Blender (x, -z, y).

def g(x, y, z):
    return (x, -z, y)


# Tipos de arbol de la pieza `ficus` (piezas.py), al azar pero fijos por nombre: 0 el arbolito de
# Tacos_ Props (Constructor.arbol_modelo, va en el .glb) y 1, 2 y 3 los de Sketchfab ARBOLES_EXTRA
# (ArbolesModelo.gd, desde resources/mapa/<colonia>/arboles_modelo.json: un MultiMesh por arbol, no van
# en el .glb)
ARBOL_PESOS = (0.25, 0.25, 0.25, 0.25)
ARBOLES_EXTRA = ("arce", "realista", "roble")


def arbol_tipo(nombre):
    import random
    r = random.Random("arbol:" + nombre).random()
    for tipo, peso in enumerate(ARBOL_PESOS):
        r -= peso
        if r < 0:
            return tipo
    return len(ARBOL_PESOS) - 1


class Constructor:
    def __init__(self, nombre):
        import bmesh
        self.nombre = nombre
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.color = self.bm.loops.layers.float_color.new("Color")
        self.mats = []
        self.choques = []          # cajas (centro, tam, giro_y) en coordenadas de Godot
        self.fijas = []            # (cara, uvs): UV puestas a mano (atlas), terminar() no las toca
        self.rampas = []           # puntos (Godot) de cajas de choque inclinadas: colonia.py hace su casco convexo

    def _mat(self, nombre):
        if nombre not in self.mats:
            self.mats.append(nombre)
        return self.mats.index(nombre)

    def cara(self, puntos, mat, color=(1.0, 1.0, 1.0), uvs=None):
        """puntos en Godot, en sentido antihorario visto desde afuera. `uvs`: las UV de cada
        punto (para el atlas de fachadas); sin ellas, terminar() las pone en metros."""
        try:
            f = self.bm.faces.new([self.bm.verts.new(g(*p)) for p in puntos])
        except ValueError:
            return None
        f.material_index = self._mat(mat)
        rgba = tuple(c ** 2.2 for c in color) + (1.0,)
        for loop in f.loops:
            loop[self.color] = rgba
        if uvs:
            self.fijas.append((f, uvs))
        return f

    def mosaico(self, esquinas, celda, color=(1.0, 1.0, 1.0)):
        """Un mosaico del atlas de fachadas en un cuadro (abajo-izq, abajo-der, arriba-der,
        arriba-izq), pintado de `color` donde la mascara es pared."""
        return self.cara(esquinas, "fachada_kit", color,
                         [uv_mosaico(celda, 0, 0), uv_mosaico(celda, 1, 0), uv_mosaico(celda, 1, 1), uv_mosaico(celda, 0, 1)])

    def esfera(self, centro, radio, mat, seg=8, anillos=5, color=(1.0, 1.0, 1.0), aplastar=1.0):
        cx, cy, cz = centro
        def p(i, j):
            a = math.pi * j / anillos - math.pi / 2
            b = math.tau * i / seg
            return (cx + math.cos(a) * math.cos(b) * radio, cy + math.sin(a) * radio * aplastar, cz + math.cos(a) * math.sin(b) * radio)
        for j in range(anillos):
            for i in range(seg):
                q = [p(i, j), p(i + 1, j), p(i + 1, j + 1), p(i, j + 1)]
                if j == 0:
                    q = [q[0], q[2], q[3]]
                elif j == anillos - 1:
                    q = [q[0], q[1], q[2]]
                self.cara(q[::-1], mat, color)

    def caja(self, centro, tam, mat, giro=0.0, color=(1.0, 1.0, 1.0), choca=False, sin_abajo=True):
        cx, cy, cz = centro
        sx, sy, sz = tam[0] / 2, tam[1] / 2, tam[2] / 2
        c, s = math.cos(giro), math.sin(giro)
        def p(x, y, z):
            return (cx + x * c + z * s, cy + y, cz - x * s + z * c)
        v = [p(-sx, -sy, -sz), p(sx, -sy, -sz), p(sx, -sy, sz), p(-sx, -sy, sz),
             p(-sx, sy, -sz), p(sx, sy, -sz), p(sx, sy, sz), p(-sx, sy, sz)]
        caras = [(3, 2, 6, 7), (1, 0, 4, 5), (2, 1, 5, 6), (0, 3, 7, 4), (4, 7, 6, 5)]
        if not sin_abajo:
            caras.append((0, 1, 2, 3))
        for f in caras:
            self.cara([v[i] for i in f], mat, color)
        if choca:
            self.choques.append((centro, tam, giro))

    def cilindro(self, base, radio, alto, mat, lados=8, color=(1.0, 1.0, 1.0), radio_arriba=None, tapa=True, choca=False):
        x, y, z = base
        r2 = radio if radio_arriba is None else radio_arriba
        ab = [(x + math.cos(k * math.tau / lados) * radio, y, z + math.sin(k * math.tau / lados) * radio) for k in range(lados)]
        ar = [(x + math.cos(k * math.tau / lados) * r2, y + alto, z + math.sin(k * math.tau / lados) * r2) for k in range(lados)]
        for k in range(lados):
            j = (k + 1) % lados
            self.cara([ab[j], ab[k], ar[k], ar[j]], mat, color)
        if tapa and r2 > 0.001:
            self.cara(ar[::-1], mat, color)
        if choca:
            self.choques.append(((x, y + alto / 2, z), (radio * 1.6, alto, radio * 1.6), 0.0))

    def arbol_modelo(self, base, ancho, variante=0, giro=0.0, alto_max=None):
        """El arbolito de Tacos_ Props (tools/blender/mapa/extraer_arbol_tacos.gd) con su base en `base`
        (Godot), de `ancho` m de copa (sin pasar de `alto_max` de altura), girado `giro` rad en Y."""
        v = _arbol_modelo()[variante % len(_arbol_modelo())]
        s = ancho / v["ancho"]
        if alto_max:
            s = min(s, alto_max / v["altura"])
        c, sn = math.cos(giro), math.sin(giro)
        bx, by, bz = base
        for parte, mat in (("corteza", "arbol_corteza"), ("hojas", "arbol_hojas")):
            malla = v[parte]
            pts = [(bx + (x * c + z * sn) * s, by + y * s, bz + (-x * sn + z * c) * s) for x, y, z in malla["v"]]
            uvs = [(u, 1.0 - w) for u, w in malla["uv"]]
            idx = malla["i"]
            for t in range(0, len(idx), 3):
                a, b, d = idx[t], idx[t + 1], idx[t + 2]
                # Godot da la cara por el sentido de las agujas del reloj; el Constructor, al reves
                self.cara([pts[a], pts[d], pts[b]], mat, uvs=[uvs[a], uvs[d], uvs[b]])

    def cono(self, base, radio, alto, mat, lados=8, color=(1.0, 1.0, 1.0)):
        x, y, z = base
        ab = [(x + math.cos(k * math.tau / lados) * radio, y, z + math.sin(k * math.tau / lados) * radio) for k in range(lados)]
        punta = (x, y + alto, z)
        for k in range(lados):
            self.cara([ab[(k + 1) % lados], ab[k], punta], mat, color)

    def arco(self, centro, ancho, alto, grueso, mat, giro=0.0, lados=6, color=(1.0, 1.0, 1.0)):
        """Un vano de arco de medio punto en un muro: el marco (pilares y dovelas), sin muro."""
        cx, cy, cz = centro
        r = ancho / 2
        pilar = 0.4
        c, s = math.cos(giro), math.sin(giro)
        def p(x, y, z):
            return (cx + x * c + z * s, cy + y, cz - x * s + z * c)
        for lado in (-1, 1):
            xx = lado * (r + pilar / 2)
            self.caja(p(xx, (alto - r) / 2, 0), (pilar, alto - r, grueso), mat, giro, color)
        for k in range(lados):
            a0, a1 = math.pi * k / lados, math.pi * (k + 1) / lados
            q =[(math.cos(a0) * r, alto - r + math.sin(a0) * r), (math.cos(a1) * r, alto - r + math.sin(a1) * r),
                 (math.cos(a1) * (r + pilar), alto - r + math.sin(a1) * (r + pilar)), (math.cos(a0) * (r + pilar), alto - r + math.sin(a0) * (r + pilar))]
            h = grueso / 2
            frente = [p(q[i][0], q[i][1], h) for i in (1, 0, 3, 2)]
            atras = [p(q[i][0], q[i][1], -h) for i in (0, 1, 2, 3)]
            self.cara(frente, mat, color)
            self.cara(atras, mat, color)
            self.cara([p(q[0][0], q[0][1], h), p(q[1][0], q[1][1], h), p(q[1][0], q[1][1], -h), p(q[0][0], q[0][1], -h)], mat, color)

    def terminar(self):
        """La malla, con UV en metros por caja segun la normal de cada cara."""
        bm = self.bm
        fijas = {f: uvs for f, uvs in self.fijas}
        for f, uvs in fijas.items():
            for loop, uv in zip(f.loops, uvs):
                loop[self.uv].uv = uv
        for f in bm.faces:
            if f in fijas:
                continue
            f.normal_update()
            n = f.normal
            eje = max(range(3), key=lambda i: abs(n[i]))
            escala = 1.0 / metros_foto(self.mats[f.material_index])
            for loop in f.loops:
                co = loop.vert.co
                if eje == 2:
                    uv = (co.x, co.y)
                elif eje == 0:
                    uv = (co.y, co.z)
                else:
                    uv = (co.x, co.z)
                loop[self.uv].uv = (uv[0] * escala, uv[1] * escala)
        malla = bpy.data.meshes.new(self.nombre)
        bm.to_mesh(malla)
        bm.free()
        for nombre in self.mats:
            if nombre == "fachada_kit":
                malla.materials.append(mat_fachada())
            elif nombre == "mural":
                malla.materials.append(mat_mural())
            elif nombre.startswith("arbol_"):
                malla.materials.append(mat_arbol(nombre))
            elif nombre.startswith("foto_"):
                malla.materials.append(foto(nombre[5:]))
            elif nombre in PISOS:
                malla.materials.append(mat_piso(nombre))
            elif nombre in COLORES_PIEZA:
                malla.materials.append(material(nombre, COLORES_PIEZA[nombre]))
            else:
                malla.materials.append(material(nombre, (0.8, 0.8, 0.8)))
        if malla.color_attributes:
            malla.color_attributes.active_color = malla.color_attributes["Color"]
            malla.color_attributes.render_color_index = malla.color_attributes.active_color_index
        return malla


# Materiales de color liso de las piezas (en Godot: ps1_combined con ese color)
COLORES_PIEZA = {"fierro": (0.12, 0.12, 0.13), "fierro_verde": (0.18, 0.3, 0.22), "blanco_cal": (0.88, 0.86, 0.8),
                 "tinaco": COLOR_TINACO, "concreto": (0.58, 0.57, 0.55), "manguera": (0.15, 0.4, 0.2),
                 "llave": (0.7, 0.6, 0.3), "lona": (1.0, 1.0, 1.0), "manta_gela": (0.92, 0.92, 0.95),
                 "azul_gela": (0.1, 0.35, 0.75), "pasto_muerto": (0.42, 0.4, 0.25), "veladora": (0.95, 0.85, 0.4),
                 "rojo": (0.7, 0.12, 0.1), "oro": (0.8, 0.65, 0.25), "vidrio": (0.15, 0.2, 0.25),
                 "naranja_gela": (0.92, 0.45, 0.08), "cable": (0.05, 0.05, 0.05),
                 "hojas": (0.11, 0.27, 0.09), "hojas_claras": (0.2, 0.4, 0.14), "farol": (0.98, 0.86, 0.5),
                 "blanco_reloj": (0.95, 0.94, 0.9), "bronce": (0.45, 0.32, 0.18),
                 "hueco": (0.06, 0.05, 0.05), "malla": (0.2, 0.22, 0.2),
                 "flor_naranja": (0.95, 0.5, 0.08), "flor_amarilla": (0.96, 0.8, 0.14), "flor_blanca": (0.92, 0.92, 0.86),
                 "flor_rosa": (0.85, 0.34, 0.5), "flor_roja": (0.75, 0.1, 0.12), "vela_roja": (0.7, 0.1, 0.1),
                 "vela_azul": (0.2, 0.35, 0.7), "vela_verde": (0.2, 0.5, 0.3), "vela_blanca": (0.9, 0.88, 0.8),
                 "varilla": COLOR_VARILLA}


if not globals().get("SOLO_FUNCIONES"):
    atlas()
    materiales(rehacer=True)
    for nombre in FOTOS:
        foto(nombre, rehacer=True)
