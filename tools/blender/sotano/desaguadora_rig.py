# LA DESAGUADORA con rig (AG 2026-11-19: "se ve muy basica"): un esqueleto con columna, cuello,
# cabeza, quijada, brazos y manos, ocho cadenas de pelo y ocho de falda (las mece en Godot un
# SpringBoneSimulator3D, Desaguadora.gd), una sola malla pesada por cercania a los huesos, el cuerpo
# esculpido (panza colgada, espinazo, omoplatos, clavículas, venas en la textura), una boca vertical
# que se abre con la quijada debajo del pelo, el pelo en tarjetas con alfa y la basura que se fue
# tragando el desague (una coladera en la espalda, un tubo atravesado en el hombro, cadenas con
# gancho, un pedazo de cortina de bano, fichas, anillos y cartas enredadas en el pelo).
# Animaciones (acciones del esqueleto, salen en el glb): idle, emerge, hundir, zarpazo_d, zarpazo_i,
# grito, charcos, latigo, atras, expuesta, golpeada, muerte.
# Texturas pintadas aqui con numpy: textures/sotano/piel_desaguadora.png y pelo_desaguadora.png.
# Exporta models/sotano/desaguadora.glb (reemplaza al de desague.py). Corre en un archivo vacio:
#   R = r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender\sotano"
#   exec(open(R + r"\desaguadora_rig.py", encoding="utf-8").read(), {"__name__": "desaguadora_rig"})
# Coordenadas: las de Godot de la escena del Sotano (x, y arriba, z; su frente es -Z), con _b().

import bpy
import math
import os
import random
from mathutils import Matrix, Vector, noise

_R = os.path.join(os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito"), "tools", "blender", "sotano")
_g = globals()
_nombre = _g.get("__name__")
_g["__name__"] = "sotano_funciones"
exec(open(os.path.join(_R, "sotano.py"), encoding="utf-8").read(), _g)
_g["__name__"] = _nombre
_RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(_R)))
TEXTURAS = os.path.join(_RAIZ, "textures", "sotano")

FPS = 24
CINTURA = 1.15
INCLINA = math.radians(-16)
ANCHO = 1.15
HONDO = 0.9
PERFIL = suavizar([(0, 1.15), (0.42, 1.15), (0.66, 1.42), (0.62, 1.72), (0.5, 2.0), (0.46, 2.18), (0.2, 2.4), (0.13, 2.5), (0, 2.55)], 3)
PELO_CADENAS = 8
FALDA_CADENAS = 8
rnd = random.Random(7)


def cuerpo(x, y, z):
    """Un punto del cuerpo derecho llevado a donde queda con el torso ensanchado e inclinado."""
    dx, dy, dz = x * ANCHO, y - CINTURA, z * HONDO
    return Vector((dx, CINTURA + dy * math.cos(INCLINA) - dz * math.sin(INCLINA), dy * math.sin(INCLINA) + dz * math.cos(INCLINA)))


def radio(y):
    for (r0, y0), (r1, y1) in zip(PERFIL, PERFIL[1:]):
        if y0 <= y <= y1 and y1 > y0:
            return r0 + (r1 - r0) * (y - y0) / (y1 - y0)
    return 0.0


def curva(pts, pasos=4):
    if len(pts) < 3:
        return pts
    salida = []
    ext = [pts[0]] + list(pts) + [pts[-1]]
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for k in range(pasos):
            t = k / pasos
            t2, t3 = t * t, t * t * t
            salida.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    salida.append(pts[-1])
    return salida


# --- Texturas (numpy) ---

def _guardar(nombre, arr):
    import numpy as np
    alto, ancho = arr.shape[0], arr.shape[1]
    img = bpy.data.images.get(nombre) or bpy.data.images.new(nombre, ancho, alto, alpha=True)
    img.scale(ancho, alto)
    img.pixels.foreach_set(np.flipud(arr).astype(np.float32).ravel())
    ruta = os.path.join(TEXTURAS, nombre + ".png")
    img.filepath_raw = ruta
    img.file_format = "PNG"
    img.save()
    return img


def texturas():
    import numpy as np
    r = np.random.default_rng(3)
    # La piel: gris azulado con manchas, moretones morados y venas oscuras ramificadas
    n = 256
    yy, xx = np.mgrid[0:n, 0:n] / n
    base = np.zeros((n, n, 4))
    mancha = np.zeros((n, n))
    for f, a in ((4, 0.5), (9, 0.3), (23, 0.2)):
        fase = r.random(4) * 6.28
        mancha += a * (np.sin(xx * 6.28 * f + fase[0]) * np.sin(yy * 6.28 * f + fase[1]) + np.sin((xx + yy) * 6.28 * f * 0.7 + fase[2])) * 0.5
    mancha = (mancha - mancha.min()) / (mancha.max() - mancha.min())
    color = np.array([0.42, 0.5, 0.55]) * (0.75 + 0.35 * mancha[..., None])
    for _ in range(9):
        cx, cy, rr = r.random(), r.random(), 0.04 + r.random() * 0.08
        d = np.sqrt(np.minimum(abs(xx - cx), 1 - abs(xx - cx)) ** 2 + (yy - cy) ** 2)
        k = np.clip(1 - d / rr, 0, 1) ** 1.5
        color = color * (1 - k[..., None] * 0.6) + np.array([0.35, 0.2, 0.38]) * k[..., None] * 0.6
    venas = np.zeros((n, n))
    for _ in range(26):
        x, y = r.random() * n, r.random() * n
        ang = r.random() * 6.28
        for paso in range(90):
            ang += r.normal(0, 0.35)
            x = (x + math.cos(ang) * 1.6) % n
            y = min(max(y + math.sin(ang) * 1.6, 0), n - 1)
            venas[int(y), int(x)] = max(venas[int(y), int(x)], 1.0 - paso / 110.0)
    venas = np.maximum(venas, np.roll(venas, 1, 0) * 0.6)
    color = color * (1 - venas[..., None] * 0.55) + np.array([0.12, 0.18, 0.3]) * venas[..., None] * 0.55
    base[..., :3] = np.clip(color, 0, 1)
    base[..., 3] = 1.0
    _guardar("piel_desaguadora", base)
    # El pelo: tarjeta de mechones mojados (alfa), puntas deshilachadas
    w, h = 64, 256
    yy, xx = np.mgrid[0:h, 0:w]
    pelo = np.zeros((h, w, 4))
    a = np.zeros((h, w))
    for _ in range(28):
        cx = r.random() * w
        grueso = 0.8 + r.random() * 1.6
        largo = h * (0.65 + r.random() * 0.35)
        onda = r.random() * 6.28
        x = cx + np.sin(yy / h * 6.28 * 0.7 + onda) * 3.0
        k = np.clip(1 - abs(xx - x) / grueso, 0, 1) * (yy < largo)
        a = np.maximum(a, k)
    pelo[..., 0] = 0.03 + 0.05 * a
    pelo[..., 1] = 0.035 + 0.05 * a
    pelo[..., 2] = 0.04 + 0.06 * a
    pelo[..., 3] = np.clip(a * 1.4, 0, 1)
    _guardar("pelo_desaguadora", pelo)


# --- El esqueleto ---

def esqueleto(col):
    arm = bpy.data.armatures.new("Desaguadora_huesos")
    ob = bpy.data.objects.new("Desaguadora", arm)
    col.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    huesos = {}

    def hueso(nombre, cabeza, cola, padre=None, conectado=False):
        b = arm.edit_bones.new(nombre)
        b.head = _b(*cabeza)
        b.tail = _b(*cola)
        if padre:
            b.parent = huesos[padre]
            b.use_connect = conectado
        huesos[nombre] = b
        return b

    columna = [cuerpo(0, y, 0) for y in (CINTURA, 1.45, 1.75, 2.05, 2.38)]
    hueso("Hips", Vector((0, 0.0, 0)), columna[0])
    hueso("Spine1", columna[0], columna[1], "Hips")
    hueso("Spine2", columna[1], columna[2], "Spine1", True)
    hueso("Spine3", columna[2], columna[3], "Spine2", True)
    hueso("Neck", columna[3], columna[4], "Spine3", True)
    cabeza = cuerpo(0.0, 2.5, -0.1) + Vector((0, 0.05, -0.12))
    hueso("Head", columna[4], cabeza + Vector((0, 0.25, -0.05)), "Neck", True)
    hueso("Jaw", cabeza + Vector((0, -0.02, -0.08)), cabeza + Vector((0, -0.22, -0.28)), "Head")
    for lado, s in (("L", -1), ("R", 1)):
        hombro = cuerpo(s * radio(2.12) * 0.92, 2.12, 0.0)
        codo = hombro + Vector((s * 0.12, -0.78, -0.07))
        muneca = hombro + Vector((s * 0.08, -1.62, -0.17))
        punta = hombro + Vector((s * 0.1, -2.04, -0.22))
        hueso("Clavicle_" + lado, cuerpo(s * 0.12, 2.18, -0.05), hombro, "Spine3")
        hueso("UpperArm_" + lado, hombro, codo, "Clavicle_" + lado, True)
        hueso("Forearm_" + lado, codo, muneca, "UpperArm_" + lado, True)
        hueso("Hand_" + lado, muneca, punta, "Forearm_" + lado, True)
    # Las cadenas de pelo: del craneo hacia afuera y abajo; las de enfrente, largas, sobre la cara
    pelo = []
    for k in range(PELO_CADENAS):
        a = k * math.tau / PELO_CADENAS + math.tau / 16
        frente = max(-math.sin(a), 0.0)
        largo = 1.2 + 0.7 * frente
        pts = [cabeza + Vector((math.cos(a) * 0.26, 0.22, math.sin(a) * 0.26))]
        for j in range(1, 5):
            t = j / 4.0
            pts.append(cabeza + Vector((math.cos(a) * (0.3 + t * 0.12), 0.22 - largo * t, math.sin(a) * (0.3 + t * 0.12) - math.sin(t * math.pi * 0.8) * 0.55 * frente)))
        nombres = []
        for j in range(4):
            nombre = "Pelo_%d_%d" % (k, j)
            hueso(nombre, pts[j], pts[j + 1], "Head" if j == 0 else "Pelo_%d_%d" % (k, j - 1), j > 0)
            nombres.append(nombre)
        pelo.append((a, nombres))
    # La falda: de la orilla de la cintura al agua
    falda = []
    for k in range(FALDA_CADENAS):
        a = k * math.tau / FALDA_CADENAS
        arriba = cuerpo(math.cos(a) * radio(1.32) * 0.96, 1.32, math.sin(a) * radio(1.32) * 0.96)
        abajo = Vector((math.cos(a) * 0.8, 0.02, math.sin(a) * 0.8))
        pts = [arriba.lerp(abajo, t / 3.0) + Vector((math.cos(a), 0, math.sin(a))) * math.sin(t / 3.0 * math.pi) * 0.06 for t in range(4)]
        nombres = []
        for j in range(3):
            nombre = "Falda_%d_%d" % (k, j)
            hueso(nombre, pts[j], pts[j + 1], "Hips" if j == 0 else "Falda_%d_%d" % (k, j - 1), j > 0)
            nombres.append(nombre)
        falda.append((a, nombres))
    # Todos con el mismo giro: asi los pose de las animaciones son predecibles
    for b in arm.edit_bones:
        b.roll = 0.0
    seg = {b.name: (b.head.copy(), b.tail.copy()) for b in arm.edit_bones}
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob, seg, pelo, falda, cabeza


# --- Pesos: cada vertice a los dos huesos mas cercanos de su lista ---

def _dist_segmento(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length


def pesar(ob, huesos, seg, uno=False):
    me = ob.data
    # (matrix_basis: matrix_world no se actualiza hasta refrescar la escena y todo quedaba en el origen)
    me.transform(ob.matrix_basis.copy())
    ob.matrix_basis = Matrix()
    grupos = {h: ob.vertex_groups.new(name=h) for h in huesos}
    for v in me.vertices:
        ds = sorted(((_dist_segmento(v.co, *seg[h]), h) for h in huesos))
        if uno or len(ds) == 1:
            grupos[ds[0][1]].add([v.index], 1.0, "REPLACE")
            continue
        (d0, h0), (d1, h1) = ds[0], ds[1]
        w0, w1 = 1.0 / max(d0, 0.01) ** 2, 1.0 / max(d1, 0.01) ** 2
        grupos[h0].add([v.index], w0 / (w0 + w1), "REPLACE")
        grupos[h1].add([v.index], w1 / (w0 + w1), "REPLACE")


def uv_cilindro(ob, centro_y=1.6, escala_v=0.6):
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers[0].data
    for poly in me.polygons:
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uv[li].uv = ((math.atan2(co.y, co.x) / math.tau) % 1.0 * 2.0, co.z * escala_v)


def tarjeta(nombre, puntos, ancho, mat, col, normal_de=None):
    """Una tira plana (tarjeta de pelo) a lo largo de `puntos` (Godot), de frente al afuera."""
    import bmesh
    me = bpy.data.meshes.new(nombre)
    bm = bmesh.new()
    pts = [_b(*p) for p in puntos]
    uvl = bm.loops.layers.uv.new("UVMap")
    filas = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        afuera = (p - normal_de) if normal_de is not None else Vector((1, 0, 0))
        afuera.z = 0.0
        lado = d.cross(afuera.normalized() if afuera.length > 1e-4 else Vector((1, 0, 0))).normalized()
        w = ancho * (1.0 - 0.5 * i / max(len(pts) - 1, 1))
        filas.append((bm.verts.new(p - lado * w * 0.5), bm.verts.new(p + lado * w * 0.5)))
    for i in range(len(filas) - 1):
        f = bm.faces.new((filas[i][0], filas[i][1], filas[i + 1][1], filas[i + 1][0]))
        v0, v1 = i / (len(filas) - 1), (i + 1) / (len(filas) - 1)
        for loop, uv in zip(f.loops, ((0, 1 - v0), (1, 1 - v0), (1, 1 - v1), (0, 1 - v1))):
            loop[uvl].uv = uv
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nombre, me)
    ob.data.materials.append(mat)
    col.objects.link(ob)
    return ob


def esculpir(ob, panza=0.12, grumos=0.025):
    """La panza colgada hacia el frente y abajo, y grumos de ahogada (ruido sobre la normal)."""
    me = ob.data
    me.calc_normals_split() if hasattr(me, "calc_normals_split") else None
    for v in me.vertices:
        p = v.co
        # Blender: frente es +y (Godot -z), alto es z
        alto = p.z
        frente = max(p.y, 0.0)
        caida = math.exp(-((alto - 1.45) / 0.25) ** 2)
        p.y += frente * panza * caida * 1.4
        p.z -= frente * panza * caida * 0.5
        n = v.normal
        p += n * noise.noise(p * 4.0) * grumos


# --- La jefa ---

def desaguadora():
    col = coleccion("Desaguadora")
    texturas()
    piel = material("piel_ahogada", (0.5, 0.56, 0.6))
    piel_osc = material("piel_ahogada_sombra", (0.36, 0.42, 0.47))
    pelo = material("pelo_mojado", (0.03, 0.03, 0.035))
    agua = material("agua_negra", (0.02, 0.025, 0.03))
    boca = material("boca_desaguadora", (0.12, 0.02, 0.03))
    diente = material("diente_amarillo", (0.75, 0.68, 0.45))
    oxido = material("oxido", (0.32, 0.16, 0.08))
    cadena = material("cadena", (0.35, 0.33, 0.3))
    cortina = material("cortina_bano", (0.55, 0.62, 0.45))
    ficha_mat = material("ficha_roja", (0.7, 0.1, 0.1))
    anillo_mat = material("anillo_oro", (0.85, 0.65, 0.2))
    carta_mat = material("carta_vieja", (0.85, 0.82, 0.7))
    luz = material("corazon_luz", (0.3, 1.0, 0.85), emision=3.0)
    arm, seg, cadenas_pelo, cadenas_falda, cabeza = esqueleto(col)
    piezas = []

    def pieza(ob, huesos, uno=False):
        pesar(ob, huesos, seg, uno)
        piezas.append(ob)
        return ob

    columna = ["Hips", "Spine1", "Spine2", "Spine3", "Neck"]
    # Torso esculpido
    torso = girar("Des_torso", [(r, y - CINTURA) for r, y in PERFIL], piel, col, lados=40)
    torso.location = _b(0.0, CINTURA, 0.0)
    torso.rotation_euler = (INCLINA, 0, 0)
    torso.scale = (ANCHO, HONDO, 1.0)
    bpy.context.view_layer.update()
    torso.data.transform(torso.matrix_world)
    torso.matrix_world = Matrix()
    sub = torso.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    bpy.context.view_layer.objects.active = torso
    bpy.ops.object.select_all(action="DESELECT")
    torso.select_set(True)
    bpy.ops.object.modifier_apply(modifier="sub")
    esculpir(torso)
    uv_cilindro(torso)
    pieza(torso, columna + ["Clavicle_L", "Clavicle_R"])
    # Omoplatos, clavículas, espinazo y costillas
    for s in (-1, 1):
        omo = esfera("Des_omoplato_%d" % (s > 0), 0.16, piel, col, lados=16, anillos=10)
        omo.location = _b(*cuerpo(s * 0.26, 1.98, radio(1.98) * 0.86))
        omo.scale = (1.0, 0.35, 1.3)
        pieza(omo, ["Spine3"], True)
        clav = tubo_curva("Des_clavicula_%d" % (s > 0), curva([cuerpo(s * 0.06, 2.2, -radio(2.2) * 0.85), cuerpo(s * 0.22, 2.21, -radio(2.21) * 0.9),
                                                                 cuerpo(s * 0.4, 2.16, -radio(2.16) * 0.5)], 4), 0.03, piel_osc, col, lados=8)
        pieza(clav, ["Spine3", "Clavicle_" + ("R" if s > 0 else "L")])
        for k in range(5):
            yk = 1.66 + k * 0.1
            r = radio(yk) * 1.02
            pts = [cuerpo(s * r * math.cos(math.radians(a)), yk, -r * math.sin(math.radians(a))) for a in (60, 30, 0, -30)]
            pieza(tubo_curva("Des_costilla_%d_%d" % (s > 0, k), curva(pts, 4), 0.02, piel_osc, col, lados=6), ["Spine2", "Spine3"])
    for k in range(10):
        yk = 1.35 + k * 0.11
        nudo = esfera("Des_espinazo_%d" % k, 0.05 - k * 0.002, piel_osc, col, lados=12, anillos=8)
        nudo.location = _b(*cuerpo(0.0, yk, radio(yk)))
        pieza(nudo, columna, True)
    # La cabeza: craneo y la boca vertical (arriba a Head, abajo a Jaw) con dientes
    craneo = esfera("Des_craneo", 0.3, piel, col, lados=24, anillos=16)
    craneo.location = _b(*(cabeza + Vector((0, -0.05, 0.0))))
    pieza(craneo, ["Head"], True)
    for mitad, hueso in ((1, "Head"), (-1, "Jaw")):
        labio = esfera("Des_boca_%s" % hueso, 0.1, boca, col, lados=12, anillos=8)
        labio.location = _b(*(cabeza + Vector((0, -0.06 + mitad * 0.06, -0.27))))
        labio.scale = (0.45, 0.2, 0.9)
        pieza(labio, [hueso], True)
        for d in range(5):
            dt = esfera("Des_diente_%s_%d" % (hueso, d), 0.018, diente, col, lados=6, anillos=4)
            dt.location = _b(*(cabeza + Vector(((d - 2) * 0.022, -0.06 + mitad * 0.02, -0.3))))
            dt.scale = (0.6, 1.0, 1.8)
            pieza(dt, [hueso], True)
    # Los brazos: largos y huesudos, con codo, muneca, nudillos y seis dedos
    for lado, s in (("L", -1), ("R", 1)):
        h0, h1 = seg["UpperArm_" + lado]
        f0, f1 = seg["Forearm_" + lado]
        m0, m1 = seg["Hand_" + lado]
        g = lambda v: Vector((v.x, v.z, -v.y))   # Blender a Godot
        brazo = [g(h0), g(h0.lerp(h1, 0.5)) + Vector((0, 0, -0.02)), g(h1), g(f0.lerp(f1, 0.5)), g(f1)]
        pieza(tubo_curva("Des_brazo_" + lado, curva(brazo, 5), 0.065, piel, col, lados=12), ["Clavicle_" + lado, "UpperArm_" + lado, "Forearm_" + lado])
        for nombre, centro, rr in (("hombro", g(h0), 0.11), ("codo", g(h1), 0.08), ("muneca", g(f1), 0.06)):
            e = esfera("Des_%s_%s" % (nombre, lado), rr, piel_osc if nombre == "codo" else piel, col, lados=14, anillos=10)
            e.location = _b(*centro)
            pieza(e, ["UpperArm_" + lado] if nombre == "hombro" else (["Forearm_" + lado] if nombre == "codo" else ["Hand_" + lado]), True)
        mano = g(m0)
        for d in range(6):
            dd = (d - 2.5) * 0.04
            dedo = [mano + Vector((dd, -0.02, 0)), mano + Vector((dd * 1.6, -0.18, -0.06)), mano + Vector((dd * 2.0, -0.34, -0.08)), mano + Vector((dd * 2.2, -0.46, -0.03))]
            pieza(tubo_curva("Des_dedo_%s_%d" % (lado, d), curva(dedo, 4), 0.016, piel, col, lados=6), ["Hand_" + lado], True)
            nud = esfera("Des_nudillo_%s_%d" % (lado, d), 0.02, piel_osc, col, lados=8, anillos=6)
            nud.location = _b(*dedo[1])
            pieza(nud, ["Hand_" + lado], True)
    # La falda: tarjetas de pelo de la cintura al agua, pesadas a su cadena
    for k in range(64):
        a = k * math.tau / 64 + rnd.uniform(-0.03, 0.03)
        cad = min(cadenas_falda, key=lambda c: abs(math.atan2(math.sin(c[0] - a), math.cos(c[0] - a))))
        arriba = cuerpo(math.cos(a) * radio(1.32) * 0.96, 1.32, math.sin(a) * radio(1.32) * 0.96)
        abajo = Vector((math.cos(a) * (0.7 + rnd.uniform(0.0, 0.2)), 0.0, math.sin(a) * (0.7 + rnd.uniform(0.0, 0.2))))
        pts = [arriba.lerp(abajo, t / 7.0) + Vector((math.cos(a), 0, math.sin(a))) * math.sin(t / 7.0 * math.pi) * 0.06 for t in range(8)]
        pieza(tarjeta("Des_falda_%d" % k, pts, 0.14, pelo, col, normal_de=Vector((0, 0, 0))), ["Hips"] + cad[1])
    # El pelo: tarjetas de la cabeza hacia afuera; las de enfrente, largas, tapan la cara y el pecho
    centro_b = _b(*cabeza)
    for k in range(140):
        a = k * math.tau / 140 + rnd.uniform(-0.02, 0.02)
        frente = max(-math.sin(a), 0.0)
        largo = rnd.uniform(1.3, 2.1) if frente > 0.2 else rnd.uniform(0.8, 1.2)
        pts = [cabeza + Vector((math.cos(a) * 0.26, 0.22, math.sin(a) * 0.26))]
        for j in range(1, 9):
            t = j / 8.0
            pts.append(cabeza + Vector((math.cos(a) * (0.3 + t * 0.12) + rnd.uniform(-0.015, 0.015), 0.22 - largo * t,
                                        math.sin(a) * (0.3 + t * 0.12) - math.sin(t * math.pi * 0.8) * 0.55 * frente)))
        cad = min(cadenas_pelo, key=lambda c: abs(math.atan2(math.sin(c[0] - a), math.cos(c[0] - a))))
        pieza(tarjeta("Des_pelo_%d" % k, pts, rnd.uniform(0.08, 0.13), pelo, col, normal_de=centro_b), ["Head"] + cad[1])
        # Lo que se enredo en el pelo: fichas, anillos y cartas (pocas)
        if k % 11 == 3:
            j = rnd.randint(3, 7)
            cosa = rnd.choice(("ficha", "anillo", "carta"))
            if cosa == "carta":
                c = caja("Des_carta_%d" % k, -0.04, 0.04, -0.06, 0.06, -0.003, 0.003, carta_mat, col, choca=False)
            elif cosa == "ficha":
                c = cilindro("Des_ficha_%d" % k, 0.0, -0.006, 0.006, 0.0, 0.03, ficha_mat, col, lados=12)
            else:
                c = girar("Des_anillo_%d" % k, [(0.018, -0.004), (0.024, -0.004), (0.024, 0.004), (0.018, 0.004), (0.018, -0.004)], anillo_mat, col, lados=12)
            c.location = _b(*pts[j])
            c.rotation_euler = (rnd.uniform(0, 3), rnd.uniform(0, 3), rnd.uniform(0, 3))
            pieza(c, [cad[1][min(j // 2, 3)]], True)
    # La basura del desague: coladera en la espalda, tubo en el hombro, cadenas, cortina
    espalda = cuerpo(0.05, 1.8, radio(1.8) * 0.98)
    rejilla = caja("Des_coladera_marco", -0.2, 0.2, -0.2, 0.2, -0.015, 0.015, oxido, col, choca=False)
    rejilla.location = _b(*espalda)
    rejilla.rotation_euler = (math.radians(90 - 16), 0, math.radians(8))
    pieza(rejilla, ["Spine2"], True)
    for k in range(5):
        barra = caja("Des_coladera_barra_%d" % k, -0.015, 0.015, -0.19, 0.19, -0.025, 0.025, oxido, col, choca=False)
        barra.location = _b(*(espalda + Vector(((k - 2) * 0.075, 0, 0.02))))
        barra.rotation_euler = (math.radians(90 - 16), 0, math.radians(8))
        pieza(barra, ["Spine2"], True)
    hombro_r = seg["UpperArm_R"][0]
    tubo = cilindro("Des_tubo", 0.0, -0.45, 0.45, 0.0, 0.045, oxido, col, lados=10)
    tubo.location = hombro_r + Vector((-0.08, 0.0, 0.05))
    tubo.rotation_euler = (math.radians(70), math.radians(20), 0)
    pieza(tubo, ["Clavicle_R"], True)
    for s in (-1, 1):
        base = cuerpo(s * 0.35, 1.3, radio(1.3) * 0.7)
        eslabones = []
        for k in range(9):
            p = base + Vector((s * 0.02 * k, -0.09 * k, 0.03 * k))
            e = girar("Des_eslabon_%d_%d" % (s > 0, k), [(0.022, -0.006), (0.03, -0.006), (0.03, 0.006), (0.022, 0.006), (0.022, -0.006)], cadena, col, lados=8)
            e.location = _b(*p)
            e.rotation_euler = (0, math.radians(90 if k % 2 else 0), 0)
            e.scale = (1.0, 1.6, 1.0)
            pieza(e, ["Hips"], True)
            eslabones.append(p)
        gancho = tubo_curva("Des_gancho_%d" % (s > 0), [eslabones[-1], eslabones[-1] + Vector((0, -0.12, 0)), eslabones[-1] + Vector((s * 0.06, -0.18, 0)),
                                                         eslabones[-1] + Vector((s * 0.08, -0.12, 0))], 0.012, cadena, col, lados=6)
        pieza(gancho, ["Hips"], True)
    trapo = tarjeta("Des_cortina", [cuerpo(-0.3, 2.05, -radio(2.05) * 0.95), cuerpo(-0.33, 1.85, -radio(1.85) * 1.05),
                                    cuerpo(-0.3, 1.6, -radio(1.6) * 1.1), cuerpo(-0.36, 1.4, -radio(1.4) * 1.05)], 0.32, cortina, col)
    pieza(trapo, ["Spine2", "Spine3"])
    # El charco a sus pies (a Hips) y el corazon (a Spine3; Corazon_luz lo prende el codigo)
    pieza(girar("Des_charco", [(0, 0.0), (1.1, 0.0), (1.15, 0.02), (0, 0.03)], agua, col, lados=48), ["Hips"], True)
    corazon = esfera("Corazon_luz", 0.13, luz, col, lados=16, anillos=12)
    centro_cor = cuerpo(0.0, 1.88, -radio(1.88))
    corazon.location = _b(*centro_cor)
    # Todo junto en una malla, con el modificador del esqueleto
    bpy.ops.object.select_all(action="DESELECT")
    for p in piezas:
        p.select_set(True)
    bpy.context.view_layer.objects.active = piezas[0]
    bpy.ops.object.join()
    malla = bpy.context.view_layer.objects.active
    malla.name = "Desaguadora_malla"
    malla.parent = arm
    mod = malla.modifiers.new("Esqueleto", "ARMATURE")
    mod.object = arm
    # El corazon: hijo del hueso Spine3 (en Godot sale en un BoneAttachment3D) y un vacio Corazon
    vacio = bpy.data.objects.new("Corazon", None)
    col.objects.link(vacio)
    vacio.parent = arm
    vacio.parent_type = "BONE"
    vacio.parent_bone = "Spine3"
    vacio.matrix_world = Matrix.Translation(_b(*centro_cor))
    corazon.parent = vacio
    corazon.matrix_world = Matrix.Translation(_b(*centro_cor))
    return arm


# --- Animaciones ---

POSES = {}


def _pose(arm, t, giros, lugar=None):
    """Pone los giros (grados, en los ejes del hueso) en el cuadro t (s) y les pone llave."""
    cuadro = int(round(t * FPS))
    for nombre, (rx, ry, rz) in giros.items():
        pb = arm.pose.bones[nombre]
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
        pb.keyframe_insert("rotation_euler", frame=cuadro)
    if lugar is not None:
        pb = arm.pose.bones["Hips"]
        pb.location = lugar
        pb.keyframe_insert("location", frame=cuadro)


def _accion(arm, nombre, llaves, ciclo=False):
    """llaves: [(t, {hueso: (rx, ry, rz)}, lugar_hips o None)]. Los huesos que no salen van en cero."""
    accion = bpy.data.actions.new(nombre)
    accion.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = accion
    usados = set()
    for _, g, _l in llaves:
        usados |= set(g)
    base = ["Hips", "Spine1", "Spine2", "Spine3", "Neck", "Head", "Jaw", "Clavicle_L", "Clavicle_R", "UpperArm_L", "UpperArm_R", "Forearm_L", "Forearm_R", "Hand_L", "Hand_R"]
    for t, g, lugar in llaves:
        todo = {b: (0, 0, 0) for b in base}
        todo.update(g)
        _pose(arm, t, todo, lugar if lugar is not None else (Vector((0, 0, 0)) if any(l is not None for _, _, l in llaves) else None))
    # (el bucle de "idle" lo pone Desaguadora.gd: en Blender 5 las acciones van por capas)
    # Para el glb: cada accion en su pista NLA (export_animation_mode ACTIONS las toma todas)
    pista = arm.animation_data.nla_tracks.new()
    pista.name = nombre
    pista.strips.new(nombre, 0, accion)
    arm.animation_data.action = None
    return accion


def animaciones(arm):
    # Ejes de los huesos (roll 0): los brazos cuelgan; giro en X lleva el brazo al frente (positivo)
    # o atras; en Z lo abre al lado. La columna: X positivo la dobla al frente.
    respira = lambda f: {"Spine2": (2 + f * 2, 0, 0), "Spine3": (f * 3, 0, 0), "Head": (8 + f * 4, f * 5, 0), "UpperArm_L": (f * 4, 0, 3), "UpperArm_R": (-f * 4, 0, -3)}
    _accion(arm, "idle", [(0.0, respira(0), None), (1.2, respira(1), None), (2.4, respira(0), None)], True)
    agacha = {"Spine1": (40, 0, 0), "Spine2": (25, 0, 0), "Head": (30, 0, 0), "UpperArm_L": (60, 0, 20), "UpperArm_R": (60, 0, -20)}
    _accion(arm, "emerge", [(0.0, agacha, Vector((0, 0, -2.2))), (1.0, {"Spine1": (10, 0, 0), "UpperArm_L": (30, 0, 10), "UpperArm_R": (30, 0, -10)}, Vector((0, 0, -0.3))),
                            (1.6, respira(0), Vector((0, 0, 0)))])
    _accion(arm, "hundir", [(0.0, respira(0), Vector((0, 0, 0))), (1.1, agacha, Vector((0, 0, -2.6)))])
    for lado, s in (("d", "R"), ("i", "L")):
        otro = "L" if s == "R" else "R"
        arriba = {"UpperArm_" + s: (-150, 0, 25 if s == "L" else -25), "Forearm_" + s: (-30, 0, 0), "Spine2": (-8, 0, 12 if s == "R" else -12), "Head": (0, 15 if s == "R" else -15, 0)}
        abajo = {"UpperArm_" + s: (40, 0, 0), "Forearm_" + s: (-10, 0, 0), "Spine2": (18, 0, -14 if s == "R" else 14), "Spine1": (10, 0, 0), "UpperArm_" + otro: (10, 0, 0)}
        _accion(arm, "zarpazo_" + lado, [(0.0, respira(0), None), (0.5, arriba, None), (0.62, abajo, None), (0.9, respira(0), None)])
    abre = {"UpperArm_L": (-20, 0, 80), "UpperArm_R": (-20, 0, -80), "Forearm_L": (0, 0, 20), "Forearm_R": (0, 0, -20), "Spine2": (-15, 0, 0), "Spine3": (-12, 0, 0),
            "Head": (-40, 0, 0), "Jaw": (55, 0, 0)}
    _accion(arm, "grito", [(0.0, respira(0), None), (0.9, abre, None), (1.0, dict(abre, Jaw=(65, 0, 0)), None), (1.4, respira(0), None)])
    sube = {"UpperArm_L": (-160, 0, 10), "UpperArm_R": (-160, 0, -10), "Spine2": (-10, 0, 0), "Head": (-15, 0, 0)}
    golpe = {"UpperArm_L": (50, 0, 10), "UpperArm_R": (50, 0, -10), "Spine1": (25, 0, 0), "Spine2": (15, 0, 0), "Head": (20, 0, 0)}
    _accion(arm, "charcos", [(0.0, respira(0), None), (0.6, sube, None), (0.75, golpe, None), (1.4, respira(0), None)])
    _accion(arm, "latigo", [(0.0, respira(0), None), (0.5, {"Head": (-35, 0, 0), "Neck": (-15, 0, 0), "Spine3": (-10, 0, 0)}, None),
                            (0.62, {"Head": (45, 0, 0), "Neck": (20, 0, 0), "Spine3": (15, 0, 0)}, None), (1.2, respira(0), None)])
    _accion(arm, "atras", [(0.0, respira(0), None), (0.3, {"Head": (30, 0, 0), "Spine3": (8, 0, 0)}, None),
                           (0.42, {"Head": (-55, 0, 0), "Neck": (-20, 0, 0), "Spine3": (-15, 0, 0)}, None), (0.8, respira(0), None)])
    _accion(arm, "expuesta", [(0.0, respira(0), None), (0.2, {"Spine2": (-25, 0, 0), "Spine3": (-20, 0, 0), "Head": (-30, 0, 0), "UpperArm_L": (0, 0, 55), "UpperArm_R": (0, 0, -55)}, None),
                              (0.9, {"Spine2": (-20, 0, 0), "Spine3": (-15, 0, 0), "Head": (-20, 0, 0), "UpperArm_L": (0, 0, 45), "UpperArm_R": (0, 0, -45)}, None),
                              (1.1, respira(0), None)])
    _accion(arm, "golpeada", [(0.0, respira(0), None), (0.08, {"Spine2": (-12, 0, 6), "Head": (-20, 8, 0)}, None), (0.3, respira(0), None)])
    _accion(arm, "muerte", [(0.0, respira(0), Vector((0, 0, 0))), (0.5, abre, Vector((0, 0, 0))), (1.4, dict(agacha, Jaw=(40, 0, 0)), Vector((0, 0, -0.8))),
                            (3.0, dict(agacha, Jaw=(40, 0, 0)), Vector((0, 0, -3.0)))])


def exportar():
    salida = os.path.join(_RAIZ, "models", "sotano", "desaguadora.glb")
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.data.collections["Desaguadora"].all_objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=salida, export_format="GLB", use_selection=True, export_yup=True, export_materials="EXPORT",
                              export_animations=True, export_animation_mode="NLA_TRACKS", export_skins=True, export_apply=False)


if __name__ == "desaguadora_rig":
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    a = desaguadora()
    animaciones(a)
    exportar()
    print("desaguadora_rig: %d huesos, %d triangulos" % (len(a.data.bones), sum(len(p.vertices) - 2 for o in bpy.data.objects if o.type == "MESH" for p in o.data.polygons)))
