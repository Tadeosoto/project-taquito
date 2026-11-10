# La plaza del desfile (stage 6): el escenario de La Mojiganga para scenes/catrina.tscn. Portales
# coloniales de cantera alrededor (arcos abajo, balcones arriba, cornisa), un kiosco al fondo
# donde estaba el templete, cuatro carros alegoricos (calaverota, arco de cempasuchil, alebrije,
# ataud con musicos) y seis ofrendas escalonadas, con la misma disposicion que PruebaCatrina.gd.
# Texturas CC0 de Poly Haven (cache/, ver CREDITS.md) puestas directo en el color, que el glTF las
# lleva; coordenadas de textura por caras, en metros.
# Las colisiones son cajas con "-colonly" en el nombre: Godot las vuelve StaticBody3D al importar.
# Cada carro y cada ofrenda es su propio objeto (Carro_0..3, Ofrenda_0..5) con su version
# reventada al lado (Carro_0_Roto...): la Catrina los revienta al pasar (scripts/catrina/Rompible.gd
# esconde el entero, prende el roto y apaga su caja de choque).
# El papel picado viene aqui (objeto "PapelPicado": PruebaCatrina ya no pone el suyo); las luces
# y las velas las sigue poniendo el codigo.
#
# Coordenadas: Blender (x, y, z) = Godot (x, -z, y). Se corre en Blender; arma la escena "Plaza" y
# exporta models/escenarios/plaza_catrina/plaza_catrina.glb y su fuente.

import bpy
import bmesh
import math
import os
import random
from mathutils import Vector, Matrix

RAIZ = r"C:\Users\Big Boss\Documents\GitHub\project-taquito"
CACHE = RAIZ + r"\tools\blender\cache"
SALIDA = RAIZ + r"\models\escenarios\plaza_catrina"
_a = {"SOLO_FUNCIONES": True, "__name__": "catrina_alta"}
exec(open(RAIZ + r"\tools\blender\catrina_alta.py", encoding="utf-8").read(), _a)

MEDIO = 22.0
ALTO = 10.0
PORTAL = 6.2          # alto de los arcos
FONDO_PORTAL = 3.0
CARROS = [(-9.0, -3.0), (9.0, -3.0), (-9.0, 7.0), (9.0, 7.0)]                 # Godot (x, z)
OFRENDAS = [(-19.0, -8.0), (19.0, -8.0), (-19.0, 6.0), (19.0, 6.0), (-6.0, -19.0), (6.0, -19.0)]
KIOSCO = (0.0, -17.5)
# Braseros de hierro junto a las columnas (fuego de pixelfx encima, en Godot)
BRASEROS = [(-20.4, -14.0), (20.4, -14.0), (-20.4, 14.0), (20.4, 14.0), (-12.0, 20.4), (12.0, 20.4)]

# material -> foto (o None) y color
MATERIALES = {
    "Piso": ("cobblestone_floor_01", (1, 1, 1)),
    "Aplanado": ("red_plaster_weathered", (1, 1, 1)),
    "Cantera": ("old_sandstone_02", (1, 1, 1)),
    "Tablas": ("blue_painted_planks", (1, 1, 1)),
    "Lamina": ("green_metal_rust", (1, 1, 1)),
    "Teja": ("clay_roof_tiles", (1, 1, 1)),
    "Oscuro": (None, (0.03, 0.025, 0.03)),
    "Hierro": (None, (0.08, 0.09, 0.08)),
    "Hueso": (None, (0.78, 0.72, 0.6)),
    "Naranja": (None, (0.8, 0.38, 0.06)),
    "Magenta": (None, (0.65, 0.12, 0.38)),
    "Morado": (None, (0.32, 0.12, 0.45)),
    "Verde": (None, (0.18, 0.45, 0.25)),
    "Amarillo": (None, (0.8, 0.65, 0.15)),
    "Turquesa": (None, (0.1, 0.55, 0.55)),
    "Vela": (None, (0.85, 0.8, 0.62)),
    "Negro": (None, (0.05, 0.04, 0.05)),
    "Colision": (None, (1, 0, 1)),
}
NOMBRES = list(MATERIALES)


def g(x, z, y=0.0):
    """Un punto de Godot (x, y, z) en Blender."""
    return Vector((x, -z, y))


def _mats():
    mats = []
    for nombre, (foto, color) in MATERIALES.items():
        m = bpy.data.materials.get("plaza_" + nombre) or bpy.data.materials.new("plaza_" + nombre)
        m.use_nodes = True
        m.use_backface_culling = False
        arbol = m.node_tree
        arbol.nodes.clear()
        salida = arbol.nodes.new("ShaderNodeOutputMaterial")
        bsdf = arbol.nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.inputs["Roughness"].default_value = 1.0
        bsdf.inputs["Base Color"].default_value = (*color, 1)
        arbol.links.new(bsdf.outputs[0], salida.inputs[0])
        if foto:
            img = bpy.data.images.get(foto) or bpy.data.images.load(os.path.join(CACHE, foto + "_diff_1k.jpg"))
            img.name = foto
            tex = arbol.nodes.new("ShaderNodeTexImage")
            tex.image = img
            arbol.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
        mats.append(m)
    return mats


def pintar(caras, nombre):
    i = NOMBRES.index(nombre)
    for f in caras:
        f.material_index = i


def caras_de(verts):
    return {f for v in verts for f in v.link_faces}


def caja(bm, centro, tam, nombre, giro=None):
    r = bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix.Translation(Vector(centro)) @ (giro or Matrix.Identity(4)) @ Matrix.Diagonal((*tam, 1.0))
    bmesh.ops.transform(bm, matrix=m, verts=r["verts"])
    pintar(caras_de(r["verts"]), nombre)
    return r["verts"]


def cilindro(bm, a, b, r1, r2, nombre, lados=8, tapas=True):
    vs = _a["tubo"](bm, [Vector(a), Vector(b)], [r1, r2], "Hueso", lados=lados, tapas=tapas)
    pintar(caras_de(vs), nombre)
    return vs


def esfera(bm, centro, radios, nombre, seg=10, anillos=6):
    r = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=anillos, radius=1.0)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(centro)) @ Matrix.Diagonal((*radios, 1.0)), verts=r["verts"])
    pintar(caras_de(r["verts"]), nombre)
    return r["verts"]


def poligono(bm, puntos, nombre):
    vs = [bm.verts.new(p) for p in puntos]
    f = bm.faces.new(vs)
    f.material_index = NOMBRES.index(nombre)
    return f


def uv_mundial(bm, escala=0.5):
    """Coordenadas de textura por la cara mas parecida a cada eje, en metros."""
    capa = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        eje = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            p = l.vert.co
            u, v = ((p.y, p.z), (p.x, p.z), (p.x, p.y))[eje]
            l[capa].uv = (u * escala, v * escala)


# --- Portales ---

def portal(bm, lado):
    """Un lado de la plaza. lado: 0 norte (al fondo, Godot -z), 1 sur, 2 oeste, 3 este."""
    giro = Matrix.Rotation((0, math.pi, -math.pi / 2, math.pi / 2)[lado], 4, "Z")
    antes = set(bm.verts)
    columnas = 11
    paso = (2 * MEDIO) / (columnas - 1)
    for k in range(columnas):
        x = -MEDIO + paso * k
        caja(bm, (x, MEDIO + 0.3, 2.1), (0.7, 0.7, 4.2), "Cantera")
        caja(bm, (x, MEDIO + 0.3, 0.15), (0.95, 0.95, 0.3), "Cantera")
        caja(bm, (x, MEDIO + 0.3, 4.15), (0.9, 0.9, 0.2), "Cantera")
    # Arcos: cada tramo un panel de cantera con el hueco del arco
    for k in range(columnas - 1):
        x0 = -MEDIO + paso * k + 0.35
        x1 = x0 + paso - 0.7
        r = (x1 - x0) / 2
        cx = (x0 + x1) / 2
        arco = [Vector((cx + math.cos(t) * r, MEDIO, 4.25 + math.sin(t) * r * 0.9)) for t in (math.pi * i / 10 for i in range(11))]
        arriba_i = Vector((x1, MEDIO, PORTAL))
        arriba_d = Vector((x0, MEDIO, PORTAL))
        for i in range(10):
            esquina = arriba_i if i < 5 else arriba_d
            poligono(bm, [arco[i], arco[i + 1], esquina], "Cantera")
        poligono(bm, [arco[5], arriba_d, arriba_i], "Cantera")
        poligono(bm, [Vector((x1, MEDIO, 4.25)), arco[0], arriba_i], "Cantera")
        poligono(bm, [arco[10], Vector((x0, MEDIO, 4.25)), arriba_d], "Cantera")
        # Puertas oscuras al fondo del portal
        caja(bm, (cx, MEDIO + FONDO_PORTAL - 0.05, 1.5), (1.6, 0.1, 3.0), "Oscuro")
    # Fondo, techo del portal, piso alto con ventanas y balcones, cornisa y teja
    caja(bm, (0, MEDIO + FONDO_PORTAL + 0.2, PORTAL / 2), (2 * MEDIO + 2, 0.4, PORTAL), "Aplanado")
    caja(bm, (0, MEDIO + FONDO_PORTAL / 2, PORTAL + 0.1), (2 * MEDIO + 2, FONDO_PORTAL + 0.6, 0.2), "Cantera")
    caja(bm, (0, MEDIO + 0.3, (PORTAL + ALTO) / 2), (2 * MEDIO + 2, 0.6, ALTO - PORTAL), "Aplanado")
    for k in range(columnas - 1):
        cx = -MEDIO + paso * (k + 0.5)
        caja(bm, (cx, MEDIO - 0.02, 8.0), (1.3, 0.1, 2.0), "Oscuro")
        caja(bm, (cx, MEDIO - 0.05, 9.1), (1.7, 0.2, 0.2), "Cantera")
        caja(bm, (cx - 0.75, MEDIO - 0.05, 8.0), (0.2, 0.2, 2.2), "Cantera")
        caja(bm, (cx + 0.75, MEDIO - 0.05, 8.0), (0.2, 0.2, 2.2), "Cantera")
        if k % 2 == 0:
            caja(bm, (cx, MEDIO - 0.45, 6.95), (2.0, 0.9, 0.12), "Cantera")
            caja(bm, (cx, MEDIO - 0.88, 7.4), (2.0, 0.05, 0.05), "Hierro")
            for b in range(9):
                caja(bm, (cx - 0.95 + b * 0.24, MEDIO - 0.88, 7.2), (0.04, 0.04, 0.5), "Hierro")
    caja(bm, (0, MEDIO + 0.1, ALTO + 0.2), (2 * MEDIO + 2.4, 1.0, 0.4), "Cantera")
    caja(bm, (0, MEDIO + 0.6, ALTO + 0.7), (2 * MEDIO + 2.4, 1.6, 0.6), "Teja")
    bmesh.ops.transform(bm, matrix=giro, verts=[v for v in bm.verts if v not in antes])


# --- Kiosco ---

def kiosco(bm):
    c = g(*KIOSCO)
    lados = 8
    r = 4.5
    alto = 1.2
    anillo_abajo = [c + Vector((math.cos(math.tau * i / lados) * r, math.sin(math.tau * i / lados) * r, 0)) for i in range(lados)]
    anillo_arriba = [p + Vector((0, 0, alto)) for p in anillo_abajo]
    for i in range(lados):
        j = (i + 1) % lados
        poligono(bm, [anillo_abajo[i], anillo_abajo[j], anillo_arriba[j], anillo_arriba[i]], "Cantera")
    poligono(bm, anillo_arriba, "Cantera")
    # Escalones hacia la plaza (Blender -y)
    for k in range(3):
        caja(bm, c + Vector((0, -r - 0.4 - 0.4 * (2 - k), 0.2 + 0.4 * k)) - Vector((0, 0, 0.0)), (2.6, 0.45 * (k + 1) + 0.4, 0.4), "Cantera")
    techo = c + Vector((0, 0, alto + 3.6))
    for i in range(lados):
        a = math.tau * (i + 0.5) / lados
        p = c + Vector((math.cos(a) * (r - 0.4), math.sin(a) * (r - 0.4), alto))
        cilindro(bm, p, p + Vector((0, 0, 3.6)), 0.13, 0.11, "Lamina", lados=8)
        q = c + Vector((math.cos(math.tau * (i + 1.5) / lados) * (r - 0.4), math.sin(math.tau * (i + 1.5) / lados) * (r - 0.4), alto))
        if i != 6:   # deja el frente abierto
            cilindro(bm, p + Vector((0, 0, 0.9)), q + Vector((0, 0, 0.9)), 0.04, 0.04, "Hierro", lados=4)
    # Cupula de lamina con su remate
    perfil = [(r + 0.4, 0.0), (r, 0.4), (3.6, 1.2), (2.4, 1.9), (1.0, 2.4), (0.2, 2.6)]
    anillos = []
    for rr, zz in perfil:
        anillos.append([bm.verts.new(techo + Vector((math.cos(math.tau * i / 16) * rr, math.sin(math.tau * i / 16) * rr, zz))) for i in range(16)])
    for k in range(len(anillos) - 1):
        for i in range(16):
            j = (i + 1) % 16
            f = bm.faces.new((anillos[k][i], anillos[k][j], anillos[k + 1][j], anillos[k + 1][i]))
            f.material_index = NOMBRES.index("Lamina")
    esfera(bm, techo + Vector((0, 0, 2.9)), (0.35,) * 3, "Amarillo", seg=8, anillos=5)
    cilindro(bm, techo + Vector((0, 0, 2.6)), techo + Vector((0, 0, 3.6)), 0.05, 0.02, "Hierro", lados=4)


# --- Carros alegoricos ---

def base_carro(bm, c, color):
    caja(bm, c + Vector((0, 0, 0.9)), (3.2, 5.5, 1.0), "Tablas")
    caja(bm, c + Vector((0, 0, 0.42)), (3.3, 5.6, 0.12), color)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p = c + Vector((sx * 1.55, sy * 1.9, 0.38))
            cilindro(bm, p - Vector((0.12 * sx, 0, 0)), p + Vector((0.12 * sx, 0, 0)), 0.38, 0.38, "Negro", lados=10)
    # Fleco de papel en la orilla
    for k in range(22):
        t = k / 21
        for sx in (-1, 1):
            p = c + Vector((sx * 1.62, -2.7 + 5.4 * t, 0.62))
            caja(bm, p, (0.02, 0.22, 0.3), ("Magenta", "Naranja", "Morado", "Verde")[k % 4])


def carro_calavera(bm, c):
    base_carro(bm, c, "Morado")
    centro = c + Vector((0, 0.4, 2.6))
    vs = esfera(bm, centro, (0.6, 0.62, 0.62), "Hueso", seg=16, anillos=11)
    escala = 1.6
    for v in vs:
        _a["_forma_craneo"](v, v.co - centro)
    # _forma_craneo deja los vertices alrededor de CABEZA: los regreso al carro y los agrando
    cab = _a["CABEZA"]
    for v in vs:
        v.co = centro + (v.co - cab) * escala
    for x in (-0.38, 0.38):
        esfera(bm, centro + Vector((x, -0.75, 0.1)), (0.17, 0.1, 0.15), "Turquesa", seg=6, anillos=4)
    for k in range(9):
        a = math.pi * (0.1 + 0.8 * k / 8)
        p = centro + Vector((math.cos(a) * 1.1, -0.2, 0.75 + math.sin(a) * 0.35))
        esfera(bm, p, (0.2,) * 3, ("Magenta", "Naranja", "Morado")[k % 3], seg=8, anillos=5)


def carro_arco(bm, c):
    base_carro(bm, c, "Naranja")
    for k in range(25):
        t = math.pi * k / 24
        p = c + Vector((math.cos(t) * 1.4, 0, 1.4 + math.sin(t) * 2.4))
        esfera(bm, p, (0.24,) * 3, "Naranja", seg=8, anillos=5)
    for k in range(6):
        p = c + Vector(((k - 2.5) * 0.45, -1.8, 1.4))
        cilindro(bm, p, p + Vector((0, 0, 0.35 + 0.1 * (k % 2))), 0.07, 0.07, "Vela", lados=6)
    caja(bm, c + Vector((0, 1.2, 1.9)), (1.6, 1.0, 1.0), "Morado")


def carro_alebrije(bm, c):
    base_carro(bm, c, "Verde")
    cuerpo = c + Vector((0, 0.3, 2.4))
    esfera(bm, cuerpo, (0.9, 1.6, 0.8), "Magenta", seg=12, anillos=8)
    cabeza = cuerpo + Vector((0, -1.8, 0.7))
    esfera(bm, cabeza, (0.55, 0.65, 0.5), "Turquesa", seg=10, anillos=6)
    for sx in (-1, 1):
        cilindro(bm, cabeza + Vector((0.3 * sx, 0, 0.3)), cabeza + Vector((0.6 * sx, 0.2, 1.1)), 0.1, 0.01, "Amarillo", lados=5)
        ala = [cuerpo + Vector((0.6 * sx, -0.5, 0.4)), cuerpo + Vector((2.4 * sx, -0.2, 1.6)), cuerpo + Vector((2.2 * sx, 0.9, 0.9)), cuerpo + Vector((0.6 * sx, 0.6, 0.4))]
        poligono(bm, ala, "Naranja")
        for k in range(2):
            pie = cuerpo + Vector((0.6 * sx, -0.7 + 1.4 * k, -0.6))
            cilindro(bm, pie, pie - Vector((0, 0, 0.6)), 0.14, 0.1, "Morado", lados=6)
    cola = [cuerpo + Vector((0, 1.5, 0)), cuerpo + Vector((0, 2.2, 0.6)), cuerpo + Vector((0, 2.4, 1.4)), cuerpo + Vector((0, 2.0, 1.9))]
    _a["tubo"](bm, cola, [0.25, 0.18, 0.12, 0.03], "Hueso", lados=6)
    pintar(caras_de([v for v in bm.verts if (v.co - cola[2]).length < 1.2 and v.co.z > cuerpo.z]), "Amarillo")


def carro_ataud(bm, c):
    base_carro(bm, c, "Magenta")
    # Ataud de seis lados, tapa a un lado
    puntos = [(-0.5, -1.3), (0.5, -1.3), (0.7, -0.6), (0.4, 1.3), (-0.4, 1.3), (-0.7, -0.6)]
    abajo = [c + Vector((x, y, 1.4)) for x, y in puntos]
    arriba = [p + Vector((0, 0, 0.6)) for p in abajo]
    for i in range(6):
        j = (i + 1) % 6
        poligono(bm, [abajo[i], abajo[j], arriba[j], arriba[i]], "Negro")
    poligono(bm, arriba, "Oscuro")
    # Tres musicos de huesos: calavera, cuerpo, instrumento
    for k, (x, y) in enumerate(((-1.0, 1.6), (1.0, 1.6), (0.0, 2.2))):
        p = c + Vector((x, y, 1.4))
        cilindro(bm, p, p + Vector((0, 0, 0.9)), 0.12, 0.1, "Hueso", lados=6)
        esfera(bm, p + Vector((0, 0, 1.15)), (0.22, 0.24, 0.24), "Hueso", seg=8, anillos=6)
        caja(bm, p + Vector((0, 0, 1.38)), (0.5, 0.5, 0.05), "Negro")
        caja(bm, p + Vector((0, 0, 1.47)), (0.25, 0.25, 0.18), "Negro")
        if k == 2:
            cilindro(bm, p + Vector((0.2, -0.2, 0.7)), p + Vector((0.4, -0.5, 1.2)), 0.05, 0.25, "Amarillo", lados=8)
        else:
            cilindro(bm, p + Vector((-0.2, -0.2, 0.6)), p + Vector((0.3, -0.3, 0.8)), 0.06, 0.06, "Amarillo", lados=6)


# --- Ofrendas ---

def ofrenda(bm, c, semilla):
    rnd = random.Random(semilla)
    for k in range(3):
        caja(bm, c + Vector((0, 0.15 * k, 0.25 + 0.5 * k)), (1.8 - 0.4 * k, 1.0 - 0.25 * k, 0.5), ("Morado", "Magenta", "Naranja")[k])
    for k in range(9):
        esfera(bm, c + Vector((-0.8 + 0.2 * k, -0.45, 0.55)), (0.09,) * 3, "Naranja", seg=6, anillos=4)
    puntas = []
    for k in range(5):
        p = c + Vector((-0.6 + 0.3 * k, -0.15, 1.0))
        alto = 0.2 + 0.15 * rnd.random()
        cilindro(bm, p, p + Vector((0, 0, alto)), 0.05, 0.05, "Vela", lados=6)
        puntas.append(p + Vector((0, 0, alto + 0.02)))
    for k in range(2):
        caja(bm, c + Vector((-0.3 + 0.6 * k, 0.2, 1.75)), (0.3, 0.04, 0.4), "Oscuro")
    for k in range(3):
        esfera(bm, c + Vector((-0.4 + 0.4 * k, -0.25, 1.55)), (0.09, 0.1, 0.1), "Hueso", seg=6, anillos=4)
    return puntas


def brasero(bm, c):
    """Un brasero de hierro en tripie (~100 triangulos): el cazo, el aro y tres patas. Devuelve la
    boca, donde va el fuego."""
    boca = c + Vector((0, 0, 1.15))
    cilindro(bm, c + Vector((0, 0, 0.85)), boca, 0.18, 0.42, "Hierro", lados=8)
    cilindro(bm, boca - Vector((0, 0, 0.04)), boca + Vector((0, 0, 0.02)), 0.45, 0.45, "Negro", lados=8, tapas=False)
    for k in range(3):
        a = math.tau * k / 3
        pie = c + Vector((math.cos(a) * 0.45, math.sin(a) * 0.45, 0))
        cilindro(bm, pie, c + Vector((math.cos(a) * 0.15, math.sin(a) * 0.15, 0.95)), 0.035, 0.035, "Hierro", lados=4, tapas=False)
    return boca


# --- Papel picado ---

def papel_picado(bm):
    """Las mismas tiras que ponia PruebaCatrina._papel_picado: de lado a lado, colgando, cada
    banderita un pentagono con la orilla de abajo en pico (papel cortado), sin transparencia."""
    colores = ["Magenta", "Naranja", "Morado", "Verde", "Amarillo", "Turquesa"]
    rnd = random.Random(12)
    alto = ALTO - 0.5
    for z in range(-16, 17, 4):
        a = g(-MEDIO, z, alto)
        b = g(MEDIO, z + 1.0, alto)
        cuantos = 80
        cuerda = []
        for k in range(cuantos + 1):
            t = k / cuantos
            cuerda.append(a.lerp(b, t) + Vector((0, 0, -(math.sin(t * math.pi) * 1.0 + 0.4))))
        pintar(caras_de(_a["tubo"](bm, cuerda[::4], 0.012, "Hueso", lados=3, tapas=False)), "Negro")
        for k in range(cuantos):
            c = (cuerda[k] + cuerda[k + 1]) / 2
            lado = (cuerda[k + 1] - cuerda[k]).normalized()
            w, h = 0.21, 0.6
            giro = rnd.uniform(-0.2, 0.2)
            abajo = Vector((0, 0, -1)) * h
            pts = [c - lado * w, c + lado * w, c + lado * w + abajo * 0.8, c + abajo, c - lado * w + abajo * 0.8]
            # Se mece tantito con el aire: inclinada sobre la cuerda
            eje = lado
            m = Matrix.Translation(c) @ Matrix.Rotation(giro, 4, eje) @ Matrix.Translation(-c)
            poligono(bm, [m @ p for p in pts], colores[rnd.randrange(len(colores))])


# --- Reventados ---

def aplastar(bm, c, semilla, alto=0.24):
    """La version reventada de un carro u ofrenda: la misma malla aplastada contra el piso, abierta
    hacia los lados y chueca (carton y tablas hechos pedazos)."""
    rnd = random.Random(semilla)
    giro = Matrix.Rotation(rnd.uniform(-0.35, 0.35), 4, "Z")
    ladeo = Vector((rnd.uniform(-0.12, 0.12), rnd.uniform(-0.12, 0.12)))
    for v in bm.verts:
        d = v.co - c
        h = max(d.z, 0.0)
        abre = 1.0 + 0.25 * min(h / 2.5, 1.0)
        nuevo = Vector((d.x * abre, d.y * abre, h * alto))
        nuevo.x += rnd.uniform(-0.12, 0.12) + ladeo.x * h
        nuevo.y += rnd.uniform(-0.12, 0.12) + ladeo.y * h
        nuevo.z += rnd.uniform(0.0, 0.08)
        v.co = c + giro @ nuevo


# --- Colisiones ---

def colision(sc, col, nombre, centro, tam):
    bm = bmesh.new()
    caja(bm, centro, tam, "Colision")
    malla = bpy.data.meshes.new(nombre)
    bm.to_mesh(malla)
    bm.free()
    ob = bpy.data.objects.new(nombre + "-colonly", malla)
    col.objects.link(ob)
    ob.display_type = "WIRE"


def marca(sc, nombre, donde):
    """Un vacio (se exporta como nodo) donde Godot cuelga un efecto."""
    ob = bpy.data.objects.new(nombre, None)
    ob.empty_display_size = 0.15
    ob.location = donde
    sc.collection.objects.link(ob)
    return ob


def armar_plaza():
    sc = bpy.data.scenes.get("Plaza") or bpy.data.scenes.new("Plaza")
    for ob in list(sc.collection.all_objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for ventana in bpy.context.window_manager.windows:
        ventana.scene = sc
    mats = _mats()
    piezas = []

    def objeto(nombre, bm, escala_uv=0.5):
        uv_mundial(bm, escala_uv)
        malla = bpy.data.meshes.new(nombre)
        bm.to_mesh(malla)
        bm.free()
        for m in mats:
            malla.materials.append(m)
        ob = bpy.data.objects.new(nombre, malla)
        sc.collection.objects.link(ob)
        piezas.append(ob)
        return ob

    bm = bmesh.new()
    caja(bm, (0, 0, -0.5), (2 * MEDIO + 8, 2 * MEDIO + 8, 1.0), "Piso")
    objeto("Piso", bm, 0.4)
    bm = bmesh.new()
    for lado in range(4):
        portal(bm, lado)
    objeto("Portales", bm, 0.35)
    bm = bmesh.new()
    kiosco(bm)
    objeto("Kiosco", bm, 0.5)
    for i, ((x, z), hacer) in enumerate(zip(CARROS, (carro_calavera, carro_arco, carro_alebrije, carro_ataud))):
        for roto in (False, True):
            bm = bmesh.new()
            hacer(bm, g(x, z))
            if roto:
                aplastar(bm, g(x, z), 30 + i)
            objeto("Carro_%d%s" % (i, "_Roto" if roto else ""), bm, 0.6)
    for i, (x, z) in enumerate(OFRENDAS):
        for roto in (False, True):
            bm = bmesh.new()
            puntas = ofrenda(bm, g(x, z), i)
            if roto:
                aplastar(bm, g(x, z), 50 + i, 0.3)
            objeto("Ofrenda_%d%s" % (i, "_Roto" if roto else ""), bm, 0.8)
        # Las puntas de las velas: PruebaCatrina les pone flamas de pixelfx
        for k, punta in enumerate(puntas):
            marca(sc, "Ofrenda_%d_Vela_%d" % (i, k), punta)
    for i, (x, z) in enumerate(BRASEROS):
        for roto in (False, True):
            bm = bmesh.new()
            boca = brasero(bm, g(x, z))
            if roto:
                aplastar(bm, g(x, z), 70 + i, 0.25)
            objeto("Brasero_%d%s" % (i, "_Roto" if roto else ""), bm, 0.8)
        marca(sc, "Brasero_%d_Fuego" % i, boca)
    bm = bmesh.new()
    papel_picado(bm)
    objeto("PapelPicado", bm, 1.0)
    # Colisiones (capa 1 en Godot): piso, muros en la linea de las columnas, kiosco, carros, ofrendas
    colision(sc, sc.collection, "Col_Piso", (0, 0, -0.5), (2 * MEDIO + 8, 2 * MEDIO + 8, 1.0))
    for lado in range(4):
        giro = Matrix.Rotation((0, math.pi, -math.pi / 2, math.pi / 2)[lado], 4, "Z")
        centro = giro @ Vector((0, MEDIO + 0.5, ALTO / 2))
        tam = (2 * MEDIO + 2, 1.0, ALTO) if lado < 2 else (1.0, 2 * MEDIO + 2, ALTO)
        colision(sc, sc.collection, "Col_Muro_%d" % lado, centro, tam)
    colision(sc, sc.collection, "Col_Kiosco", g(*KIOSCO) + Vector((0, 0, 0.6)), (8.6, 8.6, 1.2))
    for i, (x, z) in enumerate(CARROS):
        colision(sc, sc.collection, "Col_Carro_%d" % i, g(x, z) + Vector((0, 0, 1.4)), (3.3, 5.6, 2.8))
    for i, (x, z) in enumerate(BRASEROS):
        colision(sc, sc.collection, "Col_Brasero_%d" % i, g(x, z) + Vector((0, 0, 0.6)), (0.9, 0.9, 1.2))
    for i, (x, z) in enumerate(OFRENDAS):
        colision(sc, sc.collection, "Col_Ofrenda_%d" % i, g(x, z) + Vector((0, 0, 0.75)), (1.8, 1.0, 1.5))
    for ob in piezas:
        usados = sorted({p.material_index for p in ob.data.polygons})
        for i in reversed(range(len(ob.data.materials))):
            if i not in usados:
                ob.data.materials.pop(index=i)
    total = sum(sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in piezas)
    print("plaza:", total, "tris en", len(piezas), "piezas")
    return sc


def exportar_plaza():
    sc = bpy.data.scenes["Plaza"]
    os.makedirs(SALIDA, exist_ok=True)
    for ob in sc.objects:
        ob.hide_set(False)
        ob.select_set(True)
    with bpy.context.temp_override(scene=sc, view_layer=sc.view_layers[0]):
        bpy.ops.export_scene.gltf(filepath=os.path.join(SALIDA, "plaza_catrina.glb"), export_format="GLB", use_selection=True,
                                  use_active_scene=True, export_animations=False, export_yup=True, export_materials="EXPORT")
    carpeta = os.path.join(SALIDA, "fuente")
    os.makedirs(carpeta, exist_ok=True)
    open(os.path.join(carpeta, ".gdignore"), "w").close()
    bpy.data.libraries.write(os.path.join(carpeta, "plaza.blend"), {sc}, fake_user=True, compress=True)
    print("plaza exportada")


if not globals().get("SOLO_FUNCIONES"):
    armar_plaza()
    exportar_plaza()
