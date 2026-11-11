# La casa base de Parques de Santa Maria (la de Santa Mugre): 5 m de frente, adosada a las vecinas,
# con la cochera de 5 m al frente (cabe el coche) y luego la banqueta. La gente la ha ampliado
# a dos pisos: casa_psm(pisos=1) y casa_psm(pisos=2).
#
# Pocos triangulos (unos 150 por casa) y el detalle en texturas de librerias (Poly Haven, CC0;
# texturas_casa.py las baja y las deja en textures/mapa/):
#   muro      cemento enjarrado (white_stucco_02, tambien en los arcos): se repite cada 2.5 m y lo pinta el color de
#             vertice (la textura va en gris)
#   azotea    losa de concreto (concrete_wall_008), cada 2 m
#   concreto  el piso de la cochera: la misma de las banquetas de map_test (textures/map/banqueta.png,
#             dirty_concrete), cada 3 m como ellas
#   pasto     pasto de verdad (leafy_grass, a color), cada 2 m
#   detalle   un atlas (no se repite) con las ventanas (vidrio, cortina de lino, marco y herreria
#             blanca ornamental con sombra), las puertas lisas (blanca, negra y cafe), el arco pintado,
#             el medidor, la lampara y las tres rejas (cada una en sus colores: blanco, negro, gris y
#             cafe) con alfa. Las formas se dibujan aqui con bordes suavizados; las superficies
#             (la cortina, el metal pintado de la herreria, las rejas y las puertas, el arco) salen
#             de las texturas de librerias
# La luz va horneada en el color de vertice (arriba claro, lados oscuros, mas oscuro hacia el piso).
#
# Se corre dentro de Blender (con --background o desde el editor); usa bpy, bmesh y numpy:
#   exec(open(".../casa_psm.py", encoding="utf-8").read(), G)
#   G["guardar_atlas"]("textures/mapa/casa_psm.png")    # el atlas de detalle, para Godot
#   ob = G["casa_psm"]("Casa_psm_1p", pisos=1)
#
# Medidas de una foto de la casa real (la puerta de 0.9 m de referencia). Metros, piso en z = 0,
# origen en el centro de la fachada, la fachada ve a -Y (como las piezas de kit.py) y la casa
# crece hacia +Y. De izquierda a derecha de la fachada: ventana chica, cuerpo alto (el
# "torreon"), puerta lisa con marquesina y ventana grande; arcos pintados sobre las ventanas,
# medidor de luz, lampara junto a la puerta, azotea con pretil.

import os
import bpy
import bmesh
import math
import numpy as np
from mathutils import Vector

ANCHO = 5.0
FONDO = 7.0              # de la fachada al fondo de la casa
COCHERA = 5.0            # de la banqueta a la fachada
PISO1 = 2.8              # losa de la planta baja
PISO2 = 2.7              # un piso nuevo
PRETIL = 0.15
MEDIO = ANCHO / 2

# Vanos de la planta baja: (x0, x1, z0, z1)
V_CHICA = (-1.90, -0.66, 1.10, 1.95)
V_PUERTA = (-0.25, 0.65, 0.0, 2.0)
V_GRANDE = (0.85, 2.20, 0.45, 2.05)
V_2P_A = (-1.95, -0.75, 3.95, 4.95)       # segundo piso
V_2P_B = (0.35, 1.95, 3.90, 5.00)
TORREON_X = (-MEDIO, -0.25)               # el cuerpo alto de la izquierda
TORREON_TOPE = 3.5
RESALTE = 0.012                            # lo que las calcomanias (ventanas, puerta) salen de la pared

COLORES_PUERTA = {"blanca": (0.92, 0.91, 0.87), "negra": (0.07, 0.07, 0.08), "cafe": (0.33, 0.2, 0.12)}
COLORES_REJA = {"blanco": (0.92, 0.91, 0.87), "negro": (0.07, 0.07, 0.08), "gris": (0.45, 0.46, 0.48), "cafe": (0.27, 0.16, 0.1)}
REJAS = ("tablones", "barrotes", "persiana")
ALTOS_REJA = {"tablones": 1.5, "barrotes": 2.1, "persiana": 2.1}     # tambien la altura de las bardas de los lados; barrotes y persiana miden lo mismo
COLOR_AZOTEA = (0.78, 0.76, 0.74)
COLOR_TINACO = (0.07, 0.07, 0.08)

RAIZ = os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito")
PX_VENTANA = 128          # pixeles por metro de las ventanas y puertas
PX_REJA = 80              # y de las rejas
PX_VIDRIO = 256           # las ventanas van al doble: la herreria es delgada y se pixeleaba
COLORES_HERRERIA = {"blanca": (0.95, 0.95, 0.93), "negra": (0.07, 0.07, 0.08)}
# Metros que cubre una repeticion de cada textura, y de donde sale la imagen
REPETICION = {"muro": 2.5, "azotea": 2.0, "concreto": 3.0, "pasto": 2.0, "tinaco": 1.0}
IMAGEN_REPO = {"concreto": "textures/map/banqueta.png", "pasto": "textures/mapa/casa_psm_pasto.png",
               "muro": "textures/mapa/casa_psm_muro.png", "azotea": "textures/mapa/casa_psm_azotea.png"}
TEXTURA_METAL = "textures/mapa/casa_psm_metal.png"
TEXTURA_TELA = "textures/mapa/casa_psm_tela.png"
TEXTURA_MADERA = "textures/mapa/casa_psm_madera.png"   # 512 px = 1 m de veta
TEXTURA_MURO = IMAGEN_REPO["muro"]
IMAGEN_REPO["tinaco"] = "models/props/tinaco/textures/Tinaco_baseColor.png"
# El tinaco de la azotea es el negro de Sketchfab que ya usa la defensa (models/props/tinaco/, CC BY
# dmlmx). Ese modelo solo esta como .scn de Godot: exportar_tinaco.gd lo pasa a este .glb.
TINACO_GLB = "tools/blender/cache/tinaco.glb"
TINACO_PIEZAS = ("Tinaco_3er_capa", "Tapa")      # el .glb trae tres tinacos y una bomba; uno completo
TINACO_ALTO = 1.15                              # metros (uno de 1100 litros)
# Su textura es beige (Rotoplas); se oscurece con el color de vertice para que quede negro
COLOR_TINACO_TEXTURA = (0.2, 0.2, 0.21)

_atlas = None
_tinaco = None
# Los materiales que leen del atlas. Los arcos van aparte de "detalle" aunque usen el mismo atlas:
# en Godot (MapCasas) se pintan del color de cada casa como el muro, y lo demas del atlas no
DEL_ATLAS = ("detalle", "arco")


# --- Dibujo con numpy -------------------------------------------------------------------------
def _cob(coord, a, b):
    """Cuanto de cada pixel (de 1 de ancho, centrado en `coord`) cae dentro de [a, b]."""
    return np.clip(np.minimum(coord + 0.5, b) - np.maximum(coord - 0.5, a), 0.0, 1.0)


def _malla(w, h):
    y, x = np.mgrid[0:h, 0:w]
    return x.astype(np.float32), y.astype(np.float32)


def _mezclar(t, cob, color):
    """Pinta `color` sobre la imagen t con la cobertura `cob` (alto x ancho, 0 a 1)."""
    cob = cob[..., None]
    t[..., :3] = t[..., :3] * (1 - cob) + np.array(color, np.float32) * cob


def _d_segmento(X, Y, x0, y0, x1, y1):
    dx, dy = x1 - x0, y1 - y0
    l2 = dx * dx + dy * dy or 1.0
    t = np.clip(((X - x0) * dx + (Y - y0) * dy) / l2, 0, 1)
    return np.hypot(X - (x0 + t * dx), Y - (y0 + t * dy))


def _d_anillo(X, Y, cx, cy, r):
    return np.abs(np.hypot(X - cx, Y - cy) - r)


def _distancia(formas, X, Y, margen=None):
    """La distancia de cada pixel a la figura mas cercana de `formas`: ("seg", x0, y0, x1, y1) o ("anillo", cx, cy, r).
    Con `margen` solo se mide en la caja de cada figura mas ese margen (lejos queda en 1e9)."""
    d = np.full(X.shape, 1e9, np.float32)
    h, w = X.shape
    ox, oy = float(X[0, 0]), float(Y[0, 0])
    for f in formas:
        if margen is None:
            sl = (slice(None), slice(None))
        else:
            if f[0] == "seg":
                xa, xb, ya, yb = min(f[1], f[3]), max(f[1], f[3]), min(f[2], f[4]), max(f[2], f[4])
            else:
                xa, xb, ya, yb = f[1] - f[3], f[1] + f[3], f[2] - f[3], f[2] + f[3]
            i0, i1 = max(0, int(ya - oy - margen)), min(h, int(yb - oy + margen) + 2)
            j0, j1 = max(0, int(xa - ox - margen)), min(w, int(xb - ox + margen) + 2)
            if i0 >= i1 or j0 >= j1:
                continue
            sl = (slice(i0, i1), slice(j0, j1))
        xs, ys = X[sl], Y[sl]
        d[sl] = np.minimum(d[sl], _d_segmento(xs, ys, *f[1:]) if f[0] == "seg" else _d_anillo(xs, ys, *f[1:]))
    return d


def _espiral(cx, cy, r0, r1, a0, vueltas, sentido=1, pasos=28):
    """Una voluta de herreria: espiral de radio r0 a r1 que arranca en el angulo a0, como segmentos."""
    pts = []
    for k in range(pasos + 1):
        f = k / pasos
        a = a0 + sentido * f * vueltas * math.tau
        r = r0 + (r1 - r0) * f
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return [("seg", *pts[k], *pts[k + 1]) for k in range(pasos)]


def _trazo(d, ancho):
    return np.clip(ancho / 2 + 0.5 - d, 0.0, 1.0)


# --- El brillo de las texturas de librerias ----------------------------------------------------
_brillos = {}


def _gris(rel):
    """El brillo de una textura del repo, normalizado a media 1 (alto x ancho)."""
    if rel not in _brillos:
        img = bpy.data.images.load(os.path.join(RAIZ, rel), check_existing=True)
        w, h = img.size
        px = np.empty(w * h * 4, np.float32)
        img.pixels.foreach_get(px)
        g = px.reshape(h, w, 4)[::-1, :, :3].mean(axis=2)
        _brillos[rel] = g / g.mean()
    return _brillos[rel]


def _teselar(rel, w, h, contraste=1.0, desde=(0, 0)):
    """Un pedazo de w x h pixeles del brillo de la textura `rel` (se repite si no alcanza), con el
    contraste ajustado alrededor de 1: es lo que se multiplica por un color."""
    g = _gris(rel)
    g = np.tile(g, (h // g.shape[0] + 2, w // g.shape[1] + 2))[desde[1]:desde[1] + h, desde[0]:desde[0] + w]
    return (1.0 + contraste * (g - 1.0)).astype(np.float32)


# --- El atlas de detalle ----------------------------------------------------------------------
def _herreria_panel(x0, y0, x1, y1):
    """Las figuras de la herreria de un panel, como en las casas de la colonia: marco, barrote al
    centro, un rombo alargado y volutas (rizos en espiral) pareadas."""
    W, H = x1 - x0, y1 - y0
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    f = [("seg", x0, y0, x1, y0), ("seg", x0, y1, x1, y1), ("seg", x0, y0, x0, y1), ("seg", x1, y0, x1, y1),
         ("seg", cx, y0, cx, y1)]
    r = min(W * 0.17, H * 0.09)
    a = W * 0.32
    p = [(cx, y0), (cx + a, cy), (cx, y1), (cx - a, cy)]
    f += [("seg", *p[j], *p[(j + 1) % 4]) for j in range(4)]
    for yy in (y0 + H * 0.27, y0 + H * 0.73):                # rizos en C, espalda con espalda
        for s_ in (1, -1):
            f += _espiral(cx + s_ * r, yy, r, r * 0.3, math.pi if s_ > 0 else 0.0, 1.15, sentido=s_)
    for s_ in (1, -1):                                       # rizo chico arriba y abajo del centro
        f += _espiral(cx + s_ * r * 0.7, cy - r * 0.9, r * 0.7, r * 0.2, math.pi if s_ > 0 else 0.0, 0.9, -s_)
        f += _espiral(cx + s_ * r * 0.7, cy + r * 0.9, r * 0.7, r * 0.2, math.pi if s_ > 0 else 0.0, 0.9, s_)
    return f


def _t_ventana(w, h, paneles, herreria):
    """Una ventana vista de frente, como las de las fotos: vidrio gris (se ve la cortina delgada
    detras, con pliegues), marco y correderas de aluminio blanco, travesano de arriba con vidrio mas
    oscuro y herreria de volutas por fuera (blanca o negra, COLORES_HERRERIA) con su sombra."""
    m_ = lambda metros: metros * PX_VIDRIO
    X, Y = _malla(w, h)
    t = np.ones((h, w, 4), np.float32)
    m = m_(0.035)                                            # marco de afuera
    ytrans = int(h * 0.13)
    # vidrio: gris claro con la cortina detras (pliegues verticales suaves y el tejido del lino)
    pliegue = 0.5 + 0.5 * np.sin(X / m_(0.07) * math.tau + 1.7 * np.sin(X / m_(0.23)))
    gris = 0.58 + 0.07 * pliegue - 0.06 * (Y / h)
    gris = gris * _teselar(TEXTURA_TELA, w, h, 0.25)
    t[..., :3] = gris[..., None] * np.array((0.97, 1.0, 1.0), np.float32)
    reflejo = np.exp(-(((X + 0.8 * Y) - w * 0.7) / (w * 0.12)) ** 2) * 0.08
    t[..., :3] += reflejo[..., None]
    # travesano de arriba: vidrio sin cortina, mas oscuro
    arriba = Y < ytrans
    t[arriba, :3] = np.array((0.2, 0.25, 0.27), np.float32) + reflejo[arriba][:, None] * 2
    # aluminio blanco: marco, travesano, divisiones y el marco de cada corredera
    blanco = (0.93, 0.93, 0.91)
    barras = [(0, w, 0, m), (0, w, h - m, h), (0, m, 0, h), (w - m, w, 0, h), (0, w, ytrans - m / 2, ytrans + m / 2)]
    c = m_(0.022)
    for k in range(paneles):
        a, b = w * k / paneles, w * (k + 1) / paneles
        barras += [(a, a + c + m / 2, ytrans, h), (b - c - m / 2, b, ytrans, h)]
    sombra = np.zeros((h, w), np.float32)
    for x0, x1, y0, y1 in barras:
        cob = _cob(X, x0, x1) * _cob(Y, y0, y1)
        sombra = np.maximum(sombra, _cob(X, x0, x1 + 3) * _cob(Y, y0, y1 + 3))
        _mezclar(t, cob, blanco)
    t[..., :3] *= (1 - 0.18 * np.clip(sombra - np.max([_cob(X, x0, x1) * _cob(Y, y0, y1) for x0, x1, y0, y1 in barras], axis=0), 0, 1))[..., None]
    # herreria (por fuera, cubre todo el vano)
    formas = []
    hx0, hy0, hx1, hy1 = m_(0.03), m_(0.03), w - m_(0.03), h - m_(0.03)
    for i in range(paneles):
        a, b = hx0 + (hx1 - hx0) * i / paneles, hx0 + (hx1 - hx0) * (i + 1) / paneles
        formas += _herreria_panel(a, hy0, b, hy1)
    g = m_(0.017)                                            # grueso de la solera
    color = np.array(COLORES_HERRERIA[herreria], np.float32)
    ds = _distancia(formas, X - m_(0.012), Y - m_(0.02), margen=g * 3)
    _mezclar(t, np.clip((g * 1.2 - ds) / (g * 1.0), 0, 1) * 0.35, (0.05, 0.05, 0.05))   # sombra suave en el vidrio
    d = _distancia(formas, X, Y, margen=g * 2)
    cob = _trazo(d, g)
    perfil = np.clip(1 - (d / (g / 2)) ** 2, 0, 1)            # tubo: claro al centro, oscuro en la orilla
    tono = color * (0.62 + 0.38 * perfil)[..., None] + (0.06 + 0.22 * (1 - color.mean())) * perfil[..., None] ** 4
    tono *= _teselar(TEXTURA_METAL, w, h, 0.15)[..., None]
    cob3 = cob[..., None]
    t[..., :3] = t[..., :3] * (1 - cob3) + tono * cob3
    return np.clip(t, 0, 1)


def _t_puerta(w, h, color):
    """Una puerta de madera pintada: la hoja con dos tableros hundidos (con bisel), el marco y la
    manija. Lleva su color (blanca, negra o cafe) sobre la veta de la madera (vertical), que se
    nota mas en la cafe."""
    X, Y = _malla(w, h)
    c = np.array(color, np.float32)
    t = np.ones((h, w, 4), np.float32)
    k = 2                                                    # pixeles de la textura por pixel de la puerta
    veta = _teselar(TEXTURA_MADERA, w * k, h * k, 0.7 + 0.5 * (1 - c.mean())).reshape(h, k, w, k).mean(axis=(1, 3))
    # (la veta multiplica el color, y en las oscuras ademas aclara un poco, o en la negra no se veria)
    t[..., :3] = c * (1.05 - 0.12 * (Y / h))[..., None] * veta[..., None] + ((veta - 1) * 0.06 * (1 - c.mean()))[..., None]
    luz = np.zeros((h, w), np.float32)
    e = PX_VIDRIO / 128                                      # (las medidas en pixeles eran a 128 px/m)
    m = 4 * e
    for x0, x1, y0, y1 in ((m + 5 * e, w - m - 5 * e, 12 * e, h / 2 - 8 * e), (m + 5 * e, w - m - 5 * e, h / 2 + 6 * e, h - 14 * e)):
        dentro = _cob(X, x0, x1) * _cob(Y, y0, y1)
        borde = np.minimum(np.minimum(X - x0, x1 - X), np.minimum(Y - y0, y1 - Y))
        bisel = np.clip(1 - borde / (3.0 * e), 0, 1) * dentro
        arriba_izq = ((X - x0) < (x1 - X)) & ((Y - y0) < (y1 - Y))
        luz += np.where(arriba_izq, 0.18, -0.22) * bisel
        t[..., :3] *= (1 - 0.06 * dentro)[..., None]
    t[..., :3] = np.clip(t[..., :3] + luz[..., None] * np.maximum(c, 0.25)[None, None, :], 0, 1)
    _mezclar(t, np.clip(_cob(X, 0, m) + _cob(X, w - m, w) + _cob(Y, 0, m), 0, 1), tuple(np.clip(c * 0.78, 0, 1)))
    manija = _cob(X, w - 20 * e, w - 13 * e) * _cob(Y, h * 0.5 - 4 * e, h * 0.5 + 20 * e)
    _mezclar(t, manija, (0.62, 0.62, 0.6))
    _mezclar(t, manija * _cob(X, w - 20 * e, w - 18 * e), (0.9, 0.9, 0.88))
    return np.clip(t, 0, 1)


def _t_arco(w, h):
    """El arco pintado sobre una ventana: medio circulo con el enjarre de librerias, mas oscuro que el
    muro (0.75 contra 0.88): en Godot MapCasas lo pinta del color de la casa y asi sale un tono abajo;
    en Blender lo pinta el color de vertice."""
    X, Y = _malla(w, h)
    r = np.hypot((X - w / 2) / (w / 2), (Y - h) / h)
    t = np.ones((h, w, 4), np.float32)
    t[..., :3] = (0.75 * _teselar(TEXTURA_MURO, w, h, 0.8))[..., None]
    t[..., 3] = np.clip((1.0 - r) * (w / 2) + 0.5, 0, 1)
    return np.clip(t, 0, 1)


def _t_medidor(w, h):
    X, Y = _malla(w, h)
    cx, cy, R = w / 2 - 0.5, h / 2 - 0.5, w / 2 - 1
    r = np.hypot(X - cx, Y - cy)
    t = np.ones((h, w, 4), np.float32)
    t[..., :3] = (0.78 - 0.18 * (r / R))[..., None]
    t[..., :3] += (np.exp(-(((X - cx * 0.7) ** 2 + (Y - cy * 0.7) ** 2) / (R * 0.5) ** 2)) * 0.25)[..., None]
    _mezclar(t, _trazo(np.abs(r - R * 0.55), 1.4) * 0.8, (0.25, 0.25, 0.25))
    _mezclar(t, np.clip(R * 0.2 - r + 0.5, 0, 1), (0.15, 0.15, 0.15))
    t[..., 3] = np.clip(R - r + 0.5, 0, 1)
    return np.clip(t, 0, 1)


def _t_lampara(w, h):
    """Un farol colonial chico: tapa y base negras y el vidrio ambar."""
    X, Y = _malla(w, h)
    t = np.zeros((h, w, 4), np.float32)
    cuerpo = _cob(X, w * 0.2, w * 0.8) * _cob(Y, h * 0.2, h * 0.85)
    t[..., :3] = (0.14, 0.13, 0.12)
    ambar = _cob(X, w * 0.3, w * 0.7) * _cob(Y, h * 0.3, h * 0.78)
    _mezclar(t, ambar, (0.85, 0.62, 0.25))
    _mezclar(t, ambar * np.clip(1 - np.abs(X - w * 0.45) / (w * 0.15), 0, 1) * 0.5, (1.0, 0.9, 0.6))
    t[..., 3] = np.maximum(cuerpo, _cob(X, w * 0.1, w * 0.9) * _cob(Y, h * 0.1, h * 0.22))
    return t


def _mapas_reja(tipo):
    """La forma de una reja: (alfa, sombra, brillo) de alto x ancho; el color se pone aparte. Cada barra
    lleva un perfil de tubo (mas oscura en las orillas, con un brillo a un lado)."""
    w, h = round((ANCHO - 0.3) * PX_REJA), round(ALTOS_REJA[tipo] * PX_REJA)
    X, Y = _malla(w, h)
    forma = {"alfa": np.zeros((h, w), np.float32), "sombra": np.ones((h, w), np.float32), "brillo": np.zeros((h, w), np.float32)}

    def barra(x0, x1, y0, y1, vertical, fondo=False):
        c = _cob(X, x0, x1) * _cob(Y, y0, y1)
        tt = np.clip(((X - x0) / max(x1 - x0, 1e-3)) if vertical else ((Y - y0) / max(y1 - y0, 1e-3)), 0, 1)
        nuevo = c > forma["alfa"] * 0.5 + 0.001
        forma["sombra"] = np.where(nuevo, (0.7 + 0.3 * np.sin(np.pi * tt) ** 0.7) * (0.8 if fondo else 1.0), forma["sombra"])
        forma["brillo"] = np.where(nuevo, 0.55 * np.exp(-((tt - 0.3) / 0.14) ** 2) * (0.5 if fondo else 1.0), forma["brillo"])
        forma["alfa"] = np.maximum(forma["alfa"], c)

    px = lambda m: m * PX_REJA
    if tipo == "tablones":
        paso, ancho = px(0.105), px(0.06)
        for fila in (h - px(0.3), px(0.25)):
            barra(0, w, fila - px(0.025), fila + px(0.025), False, fondo=True)
        for k in range(int((w - 1) / paso)):
            x = paso * (k + 0.5)
            barra(x - ancho / 2, x + ancho / 2, 0, h, True)
        postes, ancho_p = (px(0.04), w * 0.45, w - px(0.04)), px(0.08)
    elif tipo == "barrotes":
        n = int(round((w - 1) / px(0.14)))
        for k in range(n + 1):
            x = (w - 1) * k / n
            barra(x - px(0.0125), x + px(0.0125), 0, h, True)
        for k in range(1, 6):                                      # la cuadricula de abajo
            barra(0, w, h - px(0.1) * k - px(0.01), h - px(0.1) * k + px(0.01), False)
        barra(0, w, h - px(0.6) - px(0.02), h - px(0.6) + px(0.02), False)
        barra(0, w, 0, px(0.05), False)
        postes, ancho_p = tuple((w - 1) * f for f in (0.0, 1 / 3, 2 / 3, 1.0)), px(0.06)
    else:
        paso, lama = px(0.115), px(0.08)
        k = 0
        while h - px(0.1) - k * paso - lama > px(0.1):
            y1 = h - px(0.1) - k * paso
            barra(0, w, y1 - lama, y1, False)
            k += 1
        barra(0, w, 0, px(0.1), False)
        postes, ancho_p = tuple((w - 1) * f for f in (0.0, 0.25, 0.5, 0.75, 1.0)), px(0.07)
    for x in postes:
        barra(x - ancho_p / 2, x + ancho_p / 2, 0, h, True)
    return forma["alfa"], forma["sombra"], forma["brillo"]


def _t_reja(tipo, color):
    alfa, sombra, brillo = _mapas_reja(tipo)
    t = np.ones(alfa.shape + (4,), np.float32)
    c = np.array(color, np.float32)
    detalle = _teselar(TEXTURA_METAL, alfa.shape[1], alfa.shape[0], 0.2)       # la pintura y los rayones del metal
    t[..., :3] = np.clip(c * (sombra * detalle)[..., None] + brillo[..., None] * (0.12 + 0.5 * c)[None, None, :], 0, 1)
    t[..., 3] = alfa
    return t


def _tiles():
    ven = lambda v, p, c: (round((v[1] - v[0]) * PX_VIDRIO), round((v[3] - v[2]) * PX_VIDRIO), lambda w, h: _t_ventana(w, h, p, c))
    tiles = {"arco": (256, 128, _t_arco), "medidor": (40, 40, _t_medidor), "lampara": (36, 54, _t_lampara)}
    for c in COLORES_HERRERIA:
        tiles.update({"ventana_chica_" + c: ven(V_CHICA, 2, c), "ventana_grande_" + c: ven(V_GRANDE, 2, c),
                      "ventana_2p_a_" + c: ven(V_2P_A, 2, c), "ventana_2p_b_" + c: ven(V_2P_B, 2, c)})
    pw, ph = round((V_PUERTA[1] - V_PUERTA[0]) * PX_VIDRIO), round((V_PUERTA[3] - V_PUERTA[2]) * PX_VIDRIO)
    for nombre, color in COLORES_PUERTA.items():
        tiles["puerta_" + nombre] = (pw, ph, lambda w, h, c=color: _t_puerta(w, h, c))
    for tipo in REJAS:
        w, h = round((ANCHO - 0.3) * PX_REJA), round(ALTOS_REJA[tipo] * PX_REJA)
        for nombre, color in COLORES_REJA.items():
            tiles["reja_%s_%s" % (tipo, nombre)] = (w, h, lambda w, h, t=tipo, c=color: _t_reja(t, c))
    return tiles


def _armar_atlas(ancho=2048, alto=2048, pad=2):
    """Pinta cada mosaico y los acomoda en filas, con `pad` pixeles repetidos alrededor para que el
    filtro suave no mezcle un mosaico con el de al lado."""
    pixeles = np.zeros((alto, ancho, 4), np.float32)
    pos = {}
    x = y = fila = 0
    for nombre, (w, h, pintar) in sorted(_tiles().items(), key=lambda kv: -kv[1][1]):
        if x + w + 2 * pad > ancho:
            x, y, fila = 0, y + fila, 0
        assert y + h + 2 * pad <= alto, "el atlas no alcanza"
        t = pintar(w, h)
        pixeles[y:y + h + 2 * pad, x:x + w + 2 * pad] = np.pad(t, ((pad, pad), (pad, pad), (0, 0)), mode="edge")
        pos[nombre] = (x + pad, y + pad, w, h)
        x, fila = x + w + 2 * pad, max(fila, h + 2 * pad)
    return {"imagen": _imagen("casa_psm_atlas", pixeles), "pos": pos, "W": ancho, "H": alto}


def _imagen(nombre, pixeles):
    """Una imagen de Blender con estos pixeles (alto x ancho x 4, origen arriba a la izquierda)."""
    if nombre in bpy.data.images:
        bpy.data.images.remove(bpy.data.images[nombre])
    h, w = pixeles.shape[:2]
    img = bpy.data.images.new(nombre, w, h, alpha=True)
    img.pixels.foreach_set(np.ascontiguousarray(pixeles[::-1], dtype=np.float32).ravel())
    img.update()            # (sin tocar colorspace_settings: en una imagen generada borra los pixeles; ya es sRGB)
    return img


def atlas():
    global _atlas
    if _atlas is None or _atlas["imagen"].name not in bpy.data.images:
        _atlas = _armar_atlas()
    return _atlas


def _textura(nombre):
    """La imagen que se repite de un material (de textures/), o None si no lleva (el tinaco)."""
    if nombre not in IMAGEN_REPO:
        return None
    return bpy.data.images.load(os.path.join(RAIZ, IMAGEN_REPO[nombre]), check_existing=True)


def guardar_atlas(ruta):
    """Guarda el atlas de detalle como PNG (para Godot: textures/mapa/casa_psm.png)."""
    img = atlas()["imagen"]
    img.filepath_raw = ruta
    img.file_format = "PNG"
    img.save()


def material(nombre):
    """El material de una clase de superficie ("detalle", "muro", "azotea", "concreto", "pasto" o
    "tinaco"): su imagen por el color de vertice (la luz horneada y el color de la casa)."""
    m = bpy.data.materials.get("casa_psm_" + nombre)
    if m is not None:
        return m
    m = bpy.data.materials.new("casa_psm_" + nombre)
    m.use_nodes = True
    a = m.node_tree
    bsdf = a.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 1.0
    attr = a.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Color"
    imagen = atlas()["imagen"] if nombre in DEL_ATLAS else _textura(nombre)
    if imagen is None:
        a.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
        return m
    tex = a.nodes.new("ShaderNodeTexImage")
    tex.image = imagen
    tex.interpolation = "Linear"
    tex.extension = "EXTEND" if nombre in DEL_ATLAS else "REPEAT"
    mezcla = a.nodes.new("ShaderNodeMix")
    mezcla.data_type = "RGBA"
    mezcla.blend_type = "MULTIPLY"
    mezcla.inputs["Factor"].default_value = 1.0
    a.links.new(tex.outputs["Color"], mezcla.inputs["A"])
    a.links.new(attr.outputs["Color"], mezcla.inputs["B"])
    a.links.new(mezcla.outputs["Result"], bsdf.inputs["Base Color"])
    if nombre in DEL_ATLAS:
        a.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        try:
            m.surface_render_method = "DITHERED"
        except (AttributeError, TypeError):
            pass
    return m


def _tinaco_sketchfab():
    """Los triangulos del tinaco de Sketchfab, [(puntos, uvs, normal)], con la base en el origen y
    TINACO_ALTO de alto (completo: reducirlo lo deformaba); o None si no esta el .glb (sale el prisma)."""
    global _tinaco
    if _tinaco is not None:
        return _tinaco or None
    ruta = os.path.join(RAIZ, TINACO_GLB)
    if not os.path.exists(ruta):
        print("casa_psm: falta %s (godot --path . --headless -s tools/blender/mapa/exportar_tinaco.gd); va el prisma" % TINACO_GLB)
        _tinaco = []
        return None
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=ruta)
    nuevos = [o for o in bpy.data.objects if o not in antes]
    bm = bmesh.new()
    for o in nuevos:
        if o.type == "MESH" and o.name.startswith(TINACO_PIEZAS):
            m = o.data.copy()
            m.transform(o.matrix_world)
            bm.from_mesh(m)
            bpy.data.meshes.remove(m)
    for o in nuevos:
        bpy.data.objects.remove(o, do_unlink=True)
    malla = bpy.data.meshes.new("_tinaco_tmp")
    bm.to_mesh(malla)
    bm.free()
    vs = [v.co for v in malla.vertices]
    x0, x1 = min(v.x for v in vs), max(v.x for v in vs)
    y0, y1 = min(v.y for v in vs), max(v.y for v in vs)
    z0, z1 = min(v.z for v in vs), max(v.z for v in vs)
    k = TINACO_ALTO / (z1 - z0)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    uv = malla.uv_layers.active.data
    _tinaco = []
    for pol in malla.polygons:
        pts = [((vs[i].x - cx) * k, (vs[i].y - cy) * k, (vs[i].z - z0) * k) for i in pol.vertices]
        _tinaco.append((pts, [tuple(uv[l].uv) for l in pol.loop_indices], tuple(pol.normal)))
    bpy.data.meshes.remove(malla)
    return _tinaco


# --- La malla ---------------------------------------------------------------------------------
# Luz horneada por la direccion de la cara; ademas, las paredes se oscurecen hacia el piso
LUZ = {"arriba": 1.0, "frente": 0.96, "lado": 0.86, "fondo": 0.8, "abajo": 0.55}


def _luz(normal, z):
    if abs(normal[2]) > 0.5:
        return LUZ["arriba"] if normal[2] > 0 else LUZ["abajo"]
    f = LUZ["lado"] if abs(normal[0]) > 0.5 else (LUZ["frente"] if normal[1] < 0 else LUZ["fondo"])
    return f * (0.8 + 0.2 * min(max(z / 2.5, 0.0), 1.0))


class _Constructor:
    def __init__(self):
        self.a = atlas()
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.color = self.bm.loops.layers.float_color.new("Color")
        self.mats = []

    def _uv_detalle(self, tile, u, v):
        x, y, w, h = self.a["pos"][tile]
        return ((x + w * u) / self.a["W"], 1.0 - (y + h * (1.0 - v)) / self.a["H"])

    def cara(self, pts, mat, color, normal, tile=None, uvs=None, hornear=True):
        """Una cara (cuadrilatero o poligono) que mira hacia `normal`. Con `mat` "detalle" lleva el
        mosaico `tile` del atlas (uvs: sus esquinas, de 0 a 1); con los demas, la textura se repite
        en metros del mundo (REPETICION)."""
        pts = [tuple(p) for p in pts]
        uvs = list(uvs or ((0, 0), (1, 0), (1, 1), (0, 1)))
        p0, p1, p2 = (Vector(p) for p in pts[:3])
        if (p1 - p0).cross(p2 - p0).dot(Vector(normal)) < 0:
            pts.reverse()
            uvs.reverse()
        if mat not in self.mats:
            self.mats.append(mat)
        cara = self.bm.faces.new([self.bm.verts.new(p) for p in pts])
        cara.material_index = self.mats.index(mat)
        escala = REPETICION.get(mat, 1.0)
        for lazo, (u, v), p in zip(cara.loops, uvs, pts):
            if mat in DEL_ATLAS:
                lazo[self.uv].uv = self._uv_detalle(tile, u, v)
            elif abs(normal[2]) > 0.5:
                lazo[self.uv].uv = (p[0] / escala, p[1] / escala)
            elif abs(normal[0]) > 0.5:
                lazo[self.uv].uv = (p[1] / escala, p[2] / escala)
            else:
                lazo[self.uv].uv = (p[0] / escala, p[2] / escala)
            f = _luz(normal, p[2]) if hornear else 1.0
            lazo[self.color] = tuple(min(c * f, 1.0) ** 2.2 for c in color[:3]) + (1.0,)

    def caja(self, x0, x1, y0, y1, z0, z1, mat, color, sin=()):
        lados = {
            "frente": ((x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1), (0, -1, 0)),
            "fondo": ((x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1), (0, 1, 0)),
            "izq": ((x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (-1, 0, 0)),
            "der": ((x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1), (1, 0, 0)),
            "abajo": ((x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (x1, y0, z0), (0, 0, -1)),
            "arriba": ((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1), (0, 0, 1)),
        }
        for nombre, (a, b, c, d, n) in lados.items():
            if nombre not in sin:
                self.cara((a, b, c, d), mat, color, n)

    def calcomania(self, v, tile, color=(1.0, 1.0, 1.0), y=-RESALTE, mat="detalle"):
        """Un plano pegado a la fachada (ventana, puerta, arco...) con el mosaico `tile` del atlas."""
        x0, x1, z0, z1 = v
        self.cara(((x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)), mat, color, (0, -1, 0), tile=tile)

    def pegar(self, caras, x, y, z, mat, color=(1.0, 1.0, 1.0)):
        """Caras de un modelo con sus propias UV ([(puntos, uvs, normal)]), movidas a (x, y, z), con
        la luz horneada por su normal."""
        if mat not in self.mats:
            self.mats.append(mat)
        for pts, uvs, n in caras:
            pts = [(px + x, py + y, pz + z) for px, py, pz in pts]
            cara = self.bm.faces.new([self.bm.verts.new(p) for p in pts])
            cara.material_index = self.mats.index(mat)
            for lazo, uv, p in zip(cara.loops, uvs, pts):
                lazo[self.uv].uv = uv
                f = _luz(n, p[2] - z + 1.5)
                lazo[self.color] = tuple(min(c * f, 1.0) ** 2.2 for c in color[:3]) + (1.0,)

    def prisma(self, x, y, z, radio, alto, mat, color, lados=8):
        anillo = [(x + math.cos(k * math.tau / lados) * radio, y + math.sin(k * math.tau / lados) * radio) for k in range(lados)]
        for k in range(lados):
            a, b = anillo[k], anillo[(k + 1) % lados]
            m = ((a[0] + b[0]) / 2 - x, (a[1] + b[1]) / 2 - y, 0)
            self.cara(((a[0], a[1], z), (b[0], b[1], z), (b[0], b[1], z + alto), (a[0], a[1], z + alto)), mat, color, m)
        self.cara([(px, py, z + alto) for px, py in anillo], mat, color, (0, 0, 1))

    def terminar(self, nombre, espejo=False):
        bm = self.bm
        if espejo:
            for v in bm.verts:
                v.co.x = -v.co.x
            bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
        malla = bpy.data.meshes.new(nombre)
        bm.to_mesh(malla)
        bm.free()
        for m in self.mats:
            malla.materials.append(material(m))
        malla.color_attributes.active_color = malla.color_attributes["Color"]
        # El exportador de glTF lee el de render (con -1 sale todo blanco)
        malla.color_attributes.render_color_index = malla.color_attributes.active_color_index
        ob = bpy.data.objects.new(nombre, malla)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def _arco_sobre(b, v, color):
    """El arco pintado sobre una ventana, un tono mas oscuro y rojizo que la pared."""
    pintado = (color[0] * 1.16, color[1] * 0.99, color[2] * 0.99)      # (sobre el 0.75 del mosaico)
    cx, radio = (v[0] + v[1]) / 2, (v[1] - v[0]) / 2 + 0.05
    b.calcomania((cx - radio, cx + radio, v[3] + 0.03, v[3] + 0.03 + radio), "arco", pintado, y=-RESALTE * 2, mat="arco")


def _reja_cochera(b, tipo, color_reja, color_muro, medio=MEDIO, cochera=COCHERA):
    """La reja que cierra el frente de la cochera y el jardin, en la linea de la banqueta, entre dos
    bardas de los lados de su misma altura (ALTOS_REJA): `tablones` (tablones verticales anchos, la
    mas baja), `barrotes` (barrotes delgados, con la cuadricula abajo, en hojas con postes) o
    `persiana` (lamas horizontales, de la altura de los barrotes). Es un plano con la textura de
    metal recortada por alfa (en su color), visto de los dos lados."""
    alto = ALTOS_REJA[tipo]
    for x0, x1 in ((-medio, -medio + 0.15), (medio - 0.15, medio)):
        b.caja(x0, x1, -cochera, 0.0, 0.0, alto, "muro", color_muro, sin=("abajo",))
    y = -cochera + 0.05
    x0, x1 = -medio + 0.15, medio - 0.15
    puntos = ((x0, y, 0.0), (x1, y, 0.0), (x1, y, alto), (x0, y, alto))
    for normal in ((0, -1, 0), (0, 1, 0)):
        b.cara(puntos, "detalle", (1.0, 1.0, 1.0), normal, tile="reja_%s_%s" % (tipo, color_reja), hornear=False)


def casa_psm(nombre, pisos=1, color=(0.93, 0.76, 0.7), puerta="blanca", lote=True, tinaco=True, espejo=False,
             reja=None, reja_color="negro", herreria="blanca", fondo=FONDO, ancho=ANCHO, cochera=COCHERA):
    """La casa. `puerta`: "blanca", "negra" o "cafe" (COLORES_PUERTA); `lote`: cochera de concreto,
    jardin y la barda baja de un lado de la cochera; `espejo`: invertida de izquierda a derecha
    (las casas del arreglo se alternan); `reja`: None (cochera abierta, con la barda baja de un lado)
    o uno de REJAS (cierra el frente, con bardas a los dos lados a su altura), del color
    `reja_color` ("blanco", "negro", "gris" o "cafe", COLORES_REJA); `herreria`: el color de la herreria
    de las ventanas, "blanca" o "negra" (COLORES_HERRERIA); `fondo`: de la fachada al fondo de la casa (los
    lotes de la colonia no son todos iguales); `ancho`: el frente (de 4.5 m para arriba; puerta, ventanas y
    marquesina se quedan del mismo tamano y en medio, lo que crece es el muro de los lados y el torreon);
    `cochera`: de la banqueta a la fachada (con `lote`)."""
    b = _Constructor()
    medio = ancho / 2
    tope = PISO1 + (PISO2 if pisos == 2 else 0.0)
    # El cuerpo de la casa (las paredes son planas: ventanas y puerta van de textura)
    b.caja(-medio, medio, 0.0, fondo, 0.0, tope, "muro", color, sin=("abajo", "arriba"))
    if pisos == 1:
        b.caja(-medio, TORREON_X[1], 0.0, 0.2, PISO1, TORREON_TOPE, "muro", color)         # el torreon
        b.caja(TORREON_X[1], medio, 0.0, 0.12, PISO1, PISO1 + PRETIL, "muro", color)
    else:
        b.caja(-medio, medio, 0.0, 0.12, tope, tope + PRETIL, "muro", color)
        b.caja(-medio, medio, -0.05, 0.0, PISO1 - 0.1, PISO1 + 0.05, "muro", color)       # cornisa de la losa
    # Planta baja: marquesina sobre la puerta (con dos pisos, debajo de la cornisa), vanos y arcos pintados
    b.caja(-0.45, 0.85, -0.45, 0.0, *((2.4, 3.1) if pisos == 1 else (2.1, 2.7)), "muro", color)
    b.calcomania(V_CHICA, "ventana_chica_" + herreria)
    b.calcomania(V_GRANDE, "ventana_grande_" + herreria)
    b.calcomania(V_PUERTA, "puerta_" + puerta)
    _arco_sobre(b, V_CHICA, color)
    _arco_sobre(b, V_GRANDE, color)
    b.calcomania((-medio + 0.27, -medio + 0.43, 1.52, 1.68), "medidor")
    b.calcomania((0.74, 0.88, 1.78, 1.98), "lampara")
    if pisos == 2:
        b.calcomania(V_2P_A, "ventana_2p_a_" + herreria)
        b.calcomania(V_2P_B, "ventana_2p_b_" + herreria)
    # Azotea con pretil
    b.cara(((-medio + 0.1, 0.12, tope), (medio - 0.1, 0.12, tope), (medio - 0.1, fondo - 0.1, tope), (-medio + 0.1, fondo - 0.1, tope)),
           "azotea", COLOR_AZOTEA, (0, 0, 1))
    b.caja(-medio, -medio + 0.1, 0.12, fondo, tope, tope + PRETIL, "muro", color)
    b.caja(medio - 0.1, medio, 0.12, fondo, tope, tope + PRETIL, "muro", color)
    b.caja(-medio, medio, fondo - 0.1, fondo, tope, tope + PRETIL, "muro", color)
    if tinaco:
        caras = _tinaco_sketchfab()
        if caras:
            b.pegar(caras, 1.4, fondo - 1.7, tope, "tinaco", COLOR_TINACO_TEXTURA)
        else:
            b.prisma(1.4, fondo - 1.7, tope, 0.55, 1.1, "tinaco_liso", COLOR_TINACO)
    if lote:
        for x0, x1, mat in ((-medio, 0.8, "concreto"), (0.8, medio, "pasto")):
            b.cara(((x0, -cochera, 0.02), (x1, -cochera, 0.02), (x1, 0.0, 0.02), (x0, 0.0, 0.02)), mat, (1.0, 1.0, 1.0), (0, 0, 1))
        if not reja:       # con reja las bardas de los dos lados las pone _reja_cochera
            b.caja(-medio, -medio + 0.15, -cochera, 0.0, 0.0, 1.2, "muro", color, sin=("abajo",))
    if reja:
        _reja_cochera(b, reja, reja_color, color, medio, cochera)
    return b.terminar(nombre, espejo)
