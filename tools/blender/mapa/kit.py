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
         "cantera_piso": ("../mapa/cantera_rosa.png", 1.5), "pasto": ("pasto.png", 2.5)}

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
    for carpeta, tipo in (("grafitis", "grafiti"), ("propaganda", "propaganda")):
        ruta = os.path.join(TEXTURAS_MAPA, carpeta)
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
               tinaco=True, varillas=None):
    """La casa como una malla: paredes en tramos del atlas, pretil, azotea, tinaco y varillas.
    `puntos` es la huella ([x, z] relativos al origen de la pieza) y `frente` el indice del lado
    que da a la calle (el lado i va del punto i al i+1, en el orden del .json)."""
    import bmesh
    azar = _Azar(_semilla(nombre))
    mats = materiales()
    bm = bmesh.new()
    capa_uv = bm.loops.layers.uv.new("UVMap")
    capa_color = bm.loops.layers.float_color.new("Color")
    indice = {"fachada_kit": 0, "azotea": 1, "tinaco": 2, "varilla": 3, "mural": 4}
    alto = pisos * PISO
    lisos = []      # tramos lisos de la planta baja del frente: ahi va el mural, si toca
    # Los colores de la paleta estan en sRGB; el color de vertice va lineal
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
        puerta_en = tramos // 2 if en_frente else -1
        for piso in range(pisos):
            for t in range(tramos):
                u0, u1 = t / tramos, (t + 1) / tramos
                p0 = (a[0] + (b[0] - a[0]) * u0, a[1] + (b[1] - a[1]) * u0)
                p1 = (a[0] + (b[0] - a[0]) * u1, a[1] + (b[1] - a[1]) * u1)
                z0, z1 = piso * PISO, (piso + 1) * PISO
                celda = _celda_fachada(azar, piso, en_frente, t, puerta_en, desgaste, tienda)
                if en_frente and piso == 0 and celda in (LISO, CAIDO):
                    lisos.append((p0, p1))
                cara([(p0[0], p0[1], z0), (p1[0], p1[1], z0), (p1[0], p1[1], z1), (p0[0], p0[1], z1)],
                     [uv_mosaico(celda, 0, 0), uv_mosaico(celda, 1, 0), uv_mosaico(celda, 1, 1), uv_mosaico(celda, 0, 1)], "fachada_kit")
        # Pretil: lo de abajo del aplanado liso
        v = PRETIL / PISO
        cara([(a[0], a[1], alto), (b[0], b[1], alto), (b[0], b[1], alto + PRETIL), (a[0], a[1], alto + PRETIL)],
             [uv_mosaico(LISO, 0, 0), uv_mosaico(LISO, largo / PISO % 1 or 1, 0), uv_mosaico(LISO, largo / PISO % 1 or 1, v), uv_mosaico(LISO, 0, v)], "fachada_kit")

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
    # Varillas de obra negra: el segundo piso que nunca se construyo
    if varillas if varillas is not None else azar() < desgaste * 0.35:
        for k in range(4):
            esquina = ccw[k % len(ccw)]
            _caja_bm(cara, (esquina[0] * 0.9, esquina[1] * 0.9, alto), 0.05, 1.2, "varilla")

    malla = bpy.data.meshes.new(nombre)
    bm.to_mesh(malla)
    bm.free()
    for m in ("fachada_kit", "azotea"):
        malla.materials.append(mats[m])
    malla.materials.append(material("tinaco", COLOR_TINACO))
    malla.materials.append(material("varilla", COLOR_VARILLA))
    malla.materials.append(mat_mural())
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
                 "varilla": COLOR_VARILLA}


if not globals().get("SOLO_FUNCIONES"):
    atlas()
    materiales(rehacer=True)
    for nombre in FOTOS:
        foto(nombre, rehacer=True)
