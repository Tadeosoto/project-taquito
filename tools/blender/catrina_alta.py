# La Mojiganga, paso 1c: la version de alta resolucion (para hornear), v3 "Dark Souls" (AG,
# 2026-11-09). Nunca va al juego: su detalle se hornea en la textura de la malla del juego
# (catrina_baja.py, catrina_textura.py). Usa la misma disposicion y las funciones de
# catrina_malla.py (doblar, radio_vestido, las zonas...), asi los marcadores del juego no se mueven.
#
# Se corre en Blender igual que catrina_malla.py. Arma la coleccion "Catrina_Alta" en la escena
# "Catrina" (la crea si no esta). PARTES elige que partes rehacer (todas por omision).
#
# Que trae (lo que AG escogio):
#   - Cara de horror: craneo agrietado (grietas por booleana, con carrizo adentro), cuencas que
#     lloran, dientes disparejos y rotos, quijada zafada de lado.
#   - El resplandor: ~4 m de varas de carrizo rotas detras de la cabeza, cempasuchiles, velas.
#   - Tela de verdad: la falda colgada del armazon (se cuelga entre vara y vara), olanes caidos y
#     mojados, bordado en relieve, ruedo deshilachado; rebozo y cola con simulacion de tela.
#   - Estructura arruinada: carrizo con nudos, cuerda torcida, alambre, clavos, parches cosidos.

import bpy
import bmesh
import math
import random
from mathutils import Vector, Matrix, noise

RUTA = r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender"
_m = {"SOLO_FUNCIONES": True, "__name__": "catrina_malla"}
exec(open(RUTA + r"\catrina_malla.py", encoding="utf-8").read(), _m)
ZONAS = _m["ZONAS"]
NOMBRES_ZONAS = _m["NOMBRES_ZONAS"]
SUAVES = _m["SUAVES"]
doblar = _m["doblar"]
radio_vestido = _m["radio_vestido"]
CABEZA = _m["CABEZA"]
FLORES = _m["FLORES"]
CEMPASUCHIL = _m["CEMPASUCHIL"]
HOMBRO = _m["HOMBRO"]
HOMBRO_Z = _m["HOMBRO_Z"]
NUDO = _m["NUDO"]

COLECCION = "Catrina_Alta"
PARTES = None   # p. ej. ["craneo"] para rehacer solo esa


def zona(nombre):
    return NOMBRES_ZONAS.index(nombre)


def matriz_cabeza():
    """La joroba completa (cintura + cuello) como una matriz rigida: la cabeza y el resplandor
    no se deben deformar como lo de en medio."""
    pc = Vector((0, 0, _m["CINTURA_Z"]))
    r1 = Matrix.Translation(pc) @ Matrix.Rotation(_m["INCLINA"], 4, "X") @ Matrix.Translation(-pc)
    cuello = r1 @ Vector((0, 0, _m["CUELLO_Z"]))
    r2 = Matrix.Translation(cuello) @ Matrix.Rotation(_m["CABECEA"], 4, "X") @ Matrix.Translation(-cuello)
    return r2 @ r1


# --- Utilidades de malla ---

def caras_de(verts):
    return {f for v in verts for f in v.link_faces}


def pintar(caras, nombre):
    i = zona(nombre)
    for f in caras:
        f.material_index = i


def esfera(bm, centro, radios, nombre, seg=24, anillos=14):
    r = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=anillos, radius=1.0)
    m = Matrix.Translation(Vector(centro)) @ Matrix.Diagonal((*radios, 1.0))
    bmesh.ops.transform(bm, matrix=m, verts=r["verts"])
    pintar(caras_de(r["verts"]), nombre)
    return r["verts"]


def caja_redonda(bm, centro, tam, nombre, giro=None, bisel=0.2):
    r = bmesh.ops.create_cube(bm, size=1.0)
    verts = r["verts"]
    aristas = list({e for v in verts for e in v.link_edges})
    hecho = bmesh.ops.bevel(bm, geom=verts + aristas, offset=bisel, segments=2, affect="EDGES", profile=0.5)
    verts = list({v for v in verts} | set(hecho.get("verts", [])))
    verts = [v for v in bm.verts if v.is_valid and v in set(verts)] or verts
    todos = list(caras_de([v for v in verts if v.is_valid]))
    vs = list({v for f in todos for v in f.verts})
    m = Matrix.Translation(Vector(centro)) @ (giro or Matrix.Identity(4)) @ Matrix.Diagonal((*tam, 1.0))
    bmesh.ops.transform(bm, matrix=m, verts=vs)
    pintar(todos, nombre)
    return vs


def tubo(bm, puntos, radio, nombre, lados=8, tapas=True, estrias=None, torcer=0.0):
    """Un tubo a lo largo de una linea con marcos que no se tuercen solos. `radio` puede ser un
    numero, una lista (uno por punto) o una funcion de t (0-1). `estrias` = (cuantas, cuanto):
    cuerda torcida (con `torcer` vueltas por metro)."""
    pts = [Vector(p) for p in puntos]
    n = len(pts)
    if n < 2:
        return []
    tans = []
    for i in range(n):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, n - 1)]
        tans.append((b - a).normalized())
    normal = tans[0].orthogonal().normalized()
    largo = 0.0
    anillos = []
    for i in range(n):
        if i > 0:
            largo += (pts[i] - pts[i - 1]).length
            normal = (normal - tans[i] * normal.dot(tans[i])).normalized()
        bin_ = tans[i].cross(normal)
        t = i / (n - 1)
        r = radio(t) if callable(radio) else (radio[i] if isinstance(radio, (list, tuple)) else radio)
        anillo = []
        for k in range(lados):
            a = math.tau * k / lados
            rr = r
            if estrias:
                rr *= 1.0 + estrias[1] * math.cos(estrias[0] * a + torcer * largo * math.tau)
            anillo.append(bm.verts.new(pts[i] + (normal * math.cos(a) + bin_ * math.sin(a)) * rr))
        anillos.append(anillo)
    caras = []
    for i in range(n - 1):
        for k in range(lados):
            j = (k + 1) % lados
            caras.append(bm.faces.new((anillos[i][k], anillos[i][j], anillos[i + 1][j], anillos[i + 1][k])))
    if tapas:
        caras.append(bm.faces.new(list(reversed(anillos[0]))))
        caras.append(bm.faces.new(anillos[-1]))
    pintar(caras, nombre)
    return [v for a in anillos for v in a]


def cana(bm, a, b, radio, nombre="Carrizo", nudo_cada=0.32, lados=7, punta_rota=False):
    """Una vara de carrizo con sus nudos (anillos mas gruesos). Rota: termina en astillas."""
    a, b = Vector(a), Vector(b)
    largo = (b - a).length
    pasos = max(int(largo / 0.06), 2)
    pts = [a.lerp(b, i / pasos) for i in range(pasos + 1)]
    radios = []
    for i in range(pasos + 1):
        d = (largo * i / pasos) % nudo_cada
        bulto = math.exp(-((min(d, nudo_cada - d)) / 0.02) ** 2)
        radios.append(radio * (1.0 + 0.25 * bulto))
    verts = tubo(bm, pts, radios, nombre, lados=lados)
    if punta_rota:
        d = (b - a).normalized()
        u = d.orthogonal().normalized()
        for k in range(4):
            giro = Matrix.Rotation(math.tau * k / 4 + 0.3, 4, d)
            lado = (giro @ u.to_4d()).to_3d() if False else (Matrix.Rotation(math.tau * k / 4, 3, d) @ u)
            p0 = b + lado * radio * 0.6
            verts += tubo(bm, [p0, p0 + d * (0.08 + 0.05 * k) + lado * 0.03], [radio * 0.35, 0.002], nombre, lados=3)
    return verts


def cuerda(bm, puntos, radio=0.03, nombre="Cuerda"):
    return tubo(bm, puntos, radio, nombre, lados=9, estrias=(3, 0.22), torcer=6.0)


def suavizar_linea(puntos, pasos=4):
    """Catmull-Rom: mas puntos entre los dados (para cuerdas y trenzas redondas)."""
    p = [Vector(x) for x in puntos]
    salida = []
    for i in range(len(p) - 1):
        p0 = p[max(i - 1, 0)]
        p1, p2 = p[i], p[i + 1]
        p3 = p[min(i + 2, len(p) - 1)]
        for k in range(pasos):
            t = k / pasos
            t2, t3 = t * t, t * t * t
            salida.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    salida.append(p[-1])
    return salida


def materiales():
    return _m["materiales"]()


def coleccion():
    sc = bpy.data.scenes.get("Catrina") or bpy.data.scenes.new("Catrina")
    col = bpy.data.collections.get(COLECCION)
    if col is None:
        col = bpy.data.collections.new(COLECCION)
        sc.collection.children.link(col)
    cortes = bpy.data.collections.get("Catrina_Cortes")
    if cortes is None:
        cortes = bpy.data.collections.new("Catrina_Cortes")
        sc.collection.children.link(cortes)
    cortes.hide_viewport = True
    cortes.hide_render = True
    for ventana in bpy.context.window_manager.windows:
        ventana.scene = sc
    return sc, col, cortes


def quitar(nombre):
    ob = bpy.data.objects.get(nombre)
    if ob:
        bpy.data.objects.remove(ob, do_unlink=True)


def objeto(col, nombre, bm, mats, suave_todo=False):
    quitar(nombre)
    for f in bm.faces:
        f.smooth = suave_todo or NOMBRES_ZONAS[f.material_index] in SUAVES
    malla = bpy.data.meshes.new(nombre)
    bm.to_mesh(malla)
    bm.free()
    for m in mats:
        malla.materials.append(m)
    ob = bpy.data.objects.new(nombre, malla)
    col.objects.link(ob)
    return ob


def textura(nombre, tipo, escala, **extra):
    t = bpy.data.textures.get(nombre) or bpy.data.textures.new(nombre, tipo)
    if t.type != tipo:
        t.type = tipo
    t = bpy.data.textures[nombre]
    if hasattr(t, "noise_scale"):
        t.noise_scale = escala
    for k, v in extra.items():
        setattr(t, k, v)
    return t


def desplazar(ob, tex, fuerza, grupo="", medio=0.5):
    m = ob.modifiers.new("Desplazar_" + tex.name, "DISPLACE")
    m.texture = tex
    m.strength = fuerza
    m.mid_level = medio
    m.texture_coords = "GLOBAL"
    if grupo:
        m.vertex_group = grupo
    return m


def subdividir(ob, niveles):
    m = ob.modifiers.new("Subdividir", "SUBSURF")
    m.levels = niveles
    m.render_levels = niveles
    return m


# --- La cabeza: craneo agrietado, quijada zafada, dientes, peinado, flores, aretes, resplandor ---

def _caida(d, radio):
    """1 en el centro, 0 en el radio, suave."""
    if d >= radio:
        return 0.0
    t = 1.0 - d / radio
    return t * t * (3 - 2 * t)


def _forma_craneo(v, rel):
    """Del globo al craneo: frente plana, cuencas hondas con borde, hueco de la nariz en forma de
    corazon al reves, maxilar que baja hasta los dientes, pomulos, sienes hundidas, ceja de hueso."""
    p = Vector(rel)
    # Frente aplanada (un craneo no es esfera)
    if p.y < -0.42:
        p.y = -0.42 + (p.y + 0.42) * 0.55
    # El maxilar baja y se adelanta hacia la fila de dientes de arriba
    if p.z < 0.0 and p.y < 0.05:
        w = _caida(abs(p.x), 0.5) * min(-p.z / 0.3, 1.0)
        p.z -= 0.2 * w
        p.y -= 0.04 * w
    # La nuca y la quijada de abajo se encogen (el craneo se ve mas angosto abajo)
    if p.z < -0.15:
        p.x *= 1.0 - 0.25 * min((-0.15 - p.z) / 0.35, 1.0)
    # Cuencas: elipses hondas con el borde levantado
    for cx in (-0.24, 0.24):
        dx = (p.x - cx) / 0.2
        dz = (p.z - 0.04) / 0.17
        d = math.sqrt(dx * dx + dz * dz)
        if p.y < -0.2:
            if d < 1.0:
                p.y += 0.3 * (1.0 - d * d) ** 0.7
            elif d < 1.3:
                p.y -= 0.025 * _caida(abs(d - 1.12), 0.18)
    # Nariz: corazon al reves, hondo
    dx = p.x / (0.085 + 0.04 * max(0.0, -(p.z + 0.13) / 0.12))
    dz = (p.z + 0.17) / 0.12
    d = math.sqrt(dx * dx + dz * dz)
    if d < 1.0 and p.y < -0.2:
        p.y += 0.2 * (1.0 - d * d) ** 0.6
    # Pomulos y arco cigomatico
    for cx in (-0.43, 0.43):
        w = _caida((p - Vector((cx, -0.32, -0.13))).length, 0.2)
        p += Vector((math.copysign(1, cx) * 0.05, -0.04, 0)) * w
    # Sienes hundidas
    for cx in (-0.58, 0.58):
        w = _caida((p - Vector((cx, -0.1, 0.02))).length, 0.24)
        p.x -= math.copysign(1, cx) * 0.07 * w
    # Ceja de hueso sobre las cuencas
    if p.y < -0.3 and 0.17 < p.z < 0.3 and abs(p.x) < 0.48:
        p.y -= 0.035 * _caida(abs(p.z - 0.23), 0.07)
    v.co = CABEZA + p


def _grieta(cortes, nombre, puntos_sup, ancho, hondo, semilla):
    """Un cortador: una tira dentada que sigue la superficie del craneo y la atraviesa."""
    quitar(nombre)
    rnd = random.Random(semilla)
    bm = bmesh.new()
    pts = suavizar_linea(puntos_sup, 3)
    arriba, abajo = [], []
    for i, p in enumerate(pts):
        rel = p - CABEZA
        n = rel.normalized()
        t = i / (len(pts) - 1)
        w = ancho * math.sin(math.pi * t) ** 0.6 * (0.6 + 0.8 * rnd.random())
        tan = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        lado = tan.cross(n).normalized()
        jit = lado * rnd.uniform(-0.02, 0.02)
        for capa, d in ((arriba, 0.08), (abajo, -hondo)):
            capa.append((bm.verts.new(p + jit + n * d - lado * w), bm.verts.new(p + jit + n * d + lado * w)))
    for i in range(len(pts) - 1):
        a0, a1 = arriba[i]
        b0, b1 = arriba[i + 1]
        c0, c1 = abajo[i]
        d0, d1 = abajo[i + 1]
        bm.faces.new((a0, b0, b1, a1))
        bm.faces.new((c1, d1, d0, c0))
        bm.faces.new((a0, c0, d0, b0))
        bm.faces.new((a1, b1, d1, c1))
    bm.faces.new((arriba[0][0], arriba[0][1], abajo[0][1], abajo[0][0]))
    bm.faces.new((arriba[-1][1], arriba[-1][0], abajo[-1][0], abajo[-1][1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    malla = bpy.data.meshes.new(nombre)
    bm.to_mesh(malla)
    bm.free()
    # Las paredes de la grieta: capas de papel (la booleana les pasa este material)
    malla.materials.append(bpy.data.materials["cat_Papel"])
    ob = bpy.data.objects.new(nombre, malla)
    cortes.objects.link(ob)
    ob.display_type = "WIRE"
    return ob


def _en_craneo(x, y, z, salir=0.0):
    """Un punto sobre la superficie del craneo en la direccion (x, y, z) desde el centro."""
    d = Vector((x, y, z)).normalized()
    return CABEZA + Vector((d.x * 0.6, d.y * 0.62, d.z * 0.62)) * (1.0 + salir)


def diente(bm, centro, ancho, alto, abajo=False, giro=0.0, roto=False):
    g = Matrix.Rotation(giro, 4, "Y")
    alto_real = alto * (0.55 if roto else 1.0)
    c = Vector(centro) + Vector((0, 0, (alto - alto_real) * (0.5 if abajo else -0.5)))
    vs = caja_redonda(bm, c, (ancho, ancho * 0.8, alto_real), "Hueso", g, bisel=0.3)
    if roto:
        # La orilla rota: un pico chueco
        borde = max(vs, key=lambda v: v.co.z) if abajo else min(vs, key=lambda v: v.co.z)
        borde.co.z += (0.03 if abajo else -0.03)
    return vs


def cabeza(col, cortes, mats):
    """Craneo_Alta (craneo con grietas, quijada, dientes), Peinado_Alta (cabello, chongo,
    trenza), Flores_Alta (flores, cempasuchiles, sartas, aretes) y Resplandor_Alta."""
    mc = matriz_cabeza()
    rnd = random.Random(7)
    obs = []

    # Craneo
    bm = bmesh.new()
    vs = esfera(bm, CABEZA, (0.6, 0.62, 0.62), "Hueso", seg=112, anillos=64)
    for v in vs:
        _forma_craneo(v, v.co - CABEZA)
    # Quijada en U, zafada: mas abierta, ladeada y corrida a un lado
    quijada = []
    pts = []
    for i in range(11):
        x = -0.4 + 0.8 * i / 10
        pts.append(CABEZA + Vector((x, -0.2 - 0.36 * (1 - (x / 0.4) ** 2), -0.64 + 0.06 * (x / 0.4) ** 2)))
    pts = [CABEZA + Vector((-0.42, -0.05, -0.28))] + pts + [CABEZA + Vector((0.42, -0.05, -0.28))]
    quijada += tubo(bm, suavizar_linea(pts, 3), lambda t: 0.075 + 0.025 * math.sin(math.pi * t), "Hueso", lados=10)
    # Dientes de arriba: disparejos, faltan dos, dos colmillos largos, dos rotos
    for k in range(10):
        if k in (2, 7):
            continue
        x = (k - 4.5) * 0.07
        y = -0.57 + 0.5 * x * x
        largo = 0.13 + rnd.uniform(-0.03, 0.04) + (0.08 if k in (3, 6) else 0.0)
        diente(bm, CABEZA + Vector((x, y, -0.3 - largo / 2 + 0.06)), 0.058 + rnd.uniform(-0.01, 0.01), largo,
               giro=rnd.uniform(-0.15, 0.15), roto=k in (1, 8))
    abajo_d = []
    for k in range(10):
        if k == 5:
            continue
        x = (k - 4.5) * 0.068
        y = -0.53 + 0.5 * x * x
        largo = 0.11 + rnd.uniform(-0.03, 0.03)
        abajo_d += diente(bm, CABEZA + Vector((x, y, -0.6 + largo / 2)), 0.054 + rnd.uniform(-0.01, 0.01), largo,
                          abajo=True, giro=rnd.uniform(-0.2, 0.2), roto=k in (0, 6))
    bisagra = CABEZA + Vector((0.42, -0.05, -0.28))
    zafar = Matrix.Translation(bisagra) @ Matrix.Rotation(math.radians(-9), 4, "X") @ \
        Matrix.Rotation(math.radians(7), 4, "Y") @ Matrix.Translation(-bisagra) @ Matrix.Translation((-0.04, 0, -0.03))
    bmesh.ops.transform(bm, matrix=zafar, verts=list(set(quijada + abajo_d)))
    # El brillo de Serenol al fondo de las cuencas
    for x in (-0.24, 0.24):
        esfera(bm, CABEZA + Vector((x, -0.18, 0.04)), (0.09, 0.05, 0.08), "Brillo", seg=12, anillos=8)
    # Carrizo por dentro: se ve por las grietas
    for a, b in (((-0.55, 0.1, 0.25), (0.55, -0.2, 0.3)), ((-0.3, -0.4, 0.5), (0.35, 0.3, 0.45)), ((0.1, -0.5, 0.05), (0.2, 0.5, 0.55))):
        cana(bm, CABEZA + Vector(a) * 0.9, CABEZA + Vector(b) * 0.9, 0.035, nudo_cada=0.2, lados=6)
    bmesh.ops.transform(bm, matrix=mc, verts=bm.verts)
    craneo = objeto(col, "Craneo_Alta", bm, mats)
    obs.append(craneo)
    # Grietas: booleana con cortadores dentados, luego la porosidad
    grietas = [
        [_en_craneo(0.05, -0.2, 1.0), _en_craneo(-0.02, -0.75, 0.62), _en_craneo(-0.12, -0.9, 0.35), _en_craneo(-0.2, -1, 0.2)],
        [_en_craneo(0.55, -0.45, 0.62), _en_craneo(0.8, -0.35, 0.25), _en_craneo(0.9, -0.2, -0.15)],
        [_en_craneo(0.32, -0.95, -0.1), _en_craneo(0.48, -0.85, -0.3), _en_craneo(0.62, -0.7, -0.4)],
        [_en_craneo(-0.8, -0.3, 0.4), _en_craneo(-0.95, 0.05, 0.05), _en_craneo(-0.85, 0.3, -0.3)],
        [_en_craneo(-0.45, -0.7, 0.5), _en_craneo(-0.62, -0.6, 0.3)],
    ]
    for i, g in enumerate(grietas):
        corte = _grieta(cortes, "Grieta_%d" % i, g, 0.05, 0.22, 11 + i)
        corte.matrix_world = mc
        mod = craneo.modifiers.new("Grieta_%d" % i, "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.object = corte
        mod.solver = "EXACT"
        mod.material_mode = "TRANSFER"
    desplazar(craneo, textura("cat_poros", "CLOUDS", 0.05, noise_depth=3), 0.012)
    desplazar(craneo, textura("cat_bultos", "CLOUDS", 0.35), 0.03)

    # Peinado: casquete con mechones, chongo de trenza enroscada y una trenza de tres hebras
    bm = bmesh.new()
    vs = esfera(bm, CABEZA + Vector((0, 0.16, 0.16)), (0.66, 0.6, 0.6), "Cabello", seg=48, anillos=28)
    for v in vs:
        rel = v.co - CABEZA
        if rel.y < -0.38 and rel.z < 0.45:
            v.co.y += 0.12    # que no tape la cara
    chongo = CABEZA + Vector((0, 0.66, 0.08))
    esfera(bm, chongo, (0.36, 0.32, 0.34), "Cabello", seg=24, anillos=14)
    espiral = []
    for i in range(90):
        t = i / 89
        a = t * math.tau * 3.2
        r = 0.12 + 0.3 * t
        espiral.append(chongo + Vector((math.cos(a) * r, 0.1 + 0.18 * (1 - t), math.sin(a) * r)))
    for h in range(3):
        fase = math.tau * h / 3
        hebra = [p + Vector((0, 0.03 * math.sin(i * 0.9 + fase), 0.03 * math.cos(i * 0.9 + fase))) for i, p in enumerate(espiral)]
        tubo(bm, hebra, 0.065, "Cabello", lados=8)
    arriba = CABEZA + Vector((0, 0.92, -0.1))
    abajo = Vector((0, 1.15, 2.85))
    for h in range(3):
        fase = math.tau * h / 3
        hebra = []
        for i in range(80):
            t = i / 79
            eje = arriba.lerp(abajo, t)
            hebra.append(eje + Vector((0.07 * math.sin(t * 34 + fase), 0.04 * math.cos(t * 34 + fase), 0)))
        tubo(bm, hebra, lambda t: 0.075 - 0.025 * t, "Cabello", lados=8)
    bmesh.ops.transform(bm, matrix=mc, verts=[v for v in bm.verts if (v.co - CABEZA).length < 1.6])
    # La trenza cuelga del cuello para abajo: solo la parte de arriba sigue a la cabeza
    for v in bm.verts:
        if (v.co - CABEZA).length >= 1.6:
            v.co = doblar(v.co)
    peinado = objeto(col, "Peinado_Alta", bm, mats)
    desplazar(peinado, textura("cat_mechones", "WOOD", 0.04, wood_type="BANDNOISE", turbulence=8.0), 0.015)
    obs.append(peinado)

    # Flores: las cuatro grandes (puntos debiles), cempasuchiles, sartas y aretes de pompones
    bm = bmesh.new()
    for (ofs, nombre) in FLORES:
        flor_papel(bm, CABEZA + Vector(ofs), Vector(ofs) + Vector((0, -0.5, 0)), 0.3, nombre, capas=3, petalos=10)
    for ofs in CEMPASUCHIL:
        cempasuchil(bm, CABEZA + Vector(ofs), 0.13)
    for lado in (-1, 1):
        for k in range(7):
            cempasuchil(bm, CABEZA + Vector((0.7 * lado, -0.12, 0.12 - 0.17 * k)), 0.075)
        base = CABEZA + Vector((0.6 * lado, -0.02, -0.32))
        tubo(bm, [base + Vector((0, 0, 0.1)), base + Vector((0, 0, -0.4))], 0.008, "Alambre", lados=4)
        for k, nombre in enumerate(["Verde", "Flor_Naranja", "Flor_Rosa"]):
            esfera(bm, base + Vector((0, 0, -0.19 * k)), (0.1,) * 3, nombre, seg=16, anillos=10)
    bmesh.ops.transform(bm, matrix=mc, verts=bm.verts)
    flores = objeto(col, "Flores_Alta", bm, mats)
    desplazar(flores, textura("cat_pelusa", "CLOUDS", 0.012), 0.01)
    obs.append(flores)

    obs.append(resplandor(col, mats, mc))
    return obs


def flor_papel(bm, centro, normal, radio, nombre, capas=3, petalos=10):
    """Flor de papel crepe: capas de petalos curvos y arrugados alrededor de un centro."""
    centro = Vector(centro)
    giro = Vector((0, 0, 1)).rotation_difference(Vector(normal).normalized()).to_matrix().to_4x4()
    todas = []
    rnd = random.Random(int(radio * 1000) + capas)
    for capa in range(capas):
        rr = radio * (1.0, 0.74, 0.5)[capa]
        for p in range(petalos):
            a0 = math.tau * (p + 0.5 * capa) / petalos
            filas = []
            for i in range(5):            # del centro a la punta
                t = i / 4
                ancho = math.sin(math.pi * (0.15 + 0.7 * t)) * rr * 0.36
                fila = []
                for j in range(4):        # de lado a lado
                    s = j / 3 - 0.5
                    ang = a0 + s * ancho / max(rr * t, 0.02) * 0.9
                    r = rr * t
                    alza = 0.06 * capa + 0.1 * rr * t * t + 0.025 * math.sin(s * 9 + t * 7 + p)   # arrugado
                    fila.append(bm.verts.new((math.cos(ang) * r, math.sin(ang) * r, alza)))
                filas.append(fila)
            caras = []
            for i in range(4):
                for j in range(3):
                    caras.append(bm.faces.new((filas[i][j], filas[i][j + 1], filas[i + 1][j + 1], filas[i + 1][j])))
            pintar(caras, nombre)
            todas += [v for f in filas for v in f]
    todas += esfera(bm, (0, 0, 0.06 * capas), (radio * 0.18,) * 3, "Flor_Centro", seg=10, anillos=6)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(centro) @ giro, verts=todas)


def cempasuchil(bm, centro, radio, normal=None):
    """Cempasuchil: un domo de anillos de petalitos encrespados."""
    centro = Vector(centro)
    n = Vector(normal).normalized() if normal else (centro - CABEZA).normalized()
    giro = Vector((0, 0, 1)).rotation_difference(n).to_matrix().to_4x4()
    todas = []
    for anillo in range(5):
        t = anillo / 4
        r = radio * (1.0 - 0.75 * t)
        alto = radio * 0.75 * math.sin(t * math.pi / 2)
        cuantos = int(16 - 8 * t)
        for k in range(cuantos):
            a = math.tau * (k + 0.5 * anillo) / cuantos
            punta = Vector((math.cos(a) * r * 1.15, math.sin(a) * r * 1.15, alto - 0.2 * radio * (1 - t)))
            base = Vector((math.cos(a) * r * 0.45, math.sin(a) * r * 0.45, alto + 0.15 * radio))
            lado = Vector((-math.sin(a), math.cos(a), 0)) * r * 0.22
            vs = [bm.verts.new(base - lado), bm.verts.new(base + lado), bm.verts.new(punta + lado * 0.6 + Vector((0, 0, 0.03 * radio))),
                  bm.verts.new(punta - lado * 0.6)]
            pintar([bm.faces.new(vs)], "Flor_Naranja")
            todas += vs
    bmesh.ops.transform(bm, matrix=Matrix.Translation(centro) @ giro, verts=todas)


def resplandor(col, mats, mc):
    """El resplandor: varas de carrizo (unas rotas) en abanico detras de la cabeza, amarradas en
    el centro con cuerda, con cempasuchiles y velas en las puntas largas."""
    rnd = random.Random(3)
    bm = bmesh.new()
    centro = CABEZA + Vector((0, 0.55, 0.05))
    varas = 32
    for i in range(varas):
        a = math.tau * i / varas
        largo = (2.0 if i % 2 == 0 else 1.25) * rnd.uniform(0.9, 1.08)
        rota = rnd.random() < 0.28
        if rota:
            largo *= rnd.uniform(0.45, 0.7)
        d = Vector((math.cos(a), 0.12 * rnd.uniform(-1, 1), math.sin(a))).normalized()
        a0 = centro + d * 0.55
        b0 = centro + d * largo
        cana(bm, a0, b0, 0.045 if i % 2 == 0 else 0.035, nudo_cada=0.3, lados=6, punta_rota=rota)
        if not rota and i % 2 == 0 and i % 4 == 0:
            # Vela en la punta, con escurrimientos de cera y su flama
            base = b0
            tubo(bm, [base, base + d * 0.22], 0.06, "Vela", lados=8)
            for k in range(3):
                q = base + d * (0.05 + 0.05 * k) + d.orthogonal().normalized() * 0.06
                tubo(bm, [q, q - d * (0.08 + 0.03 * k)], [0.018, 0.006], "Vela", lados=4)
            tubo(bm, [base + d * 0.22, base + d * 0.36], [0.035, 0.001], "Flama", lados=6, tapas=False)
        elif not rota and rnd.random() < 0.5:
            cempasuchil(bm, centro + d * largo * rnd.uniform(0.5, 0.8), 0.09)
    # Aro de amarre: tres vueltas de cuerda alrededor del centro
    for vuelta in range(3):
        r = 0.5 + 0.06 * vuelta
        aro = [centro + Vector((math.cos(t) * r, 0.04 * vuelta - 0.04, math.sin(t) * r)) for t in (math.tau * i / 48 for i in range(49))]
        cuerda(bm, aro, 0.035)
    # Un segundo aro mas grande, de carrizo, a media vara
    aro = [centro + Vector((math.cos(t) * 1.1, 0.06, math.sin(t) * 1.1)) for t in (math.tau * i / 64 for i in range(65))]
    tubo(bm, aro, 0.03, "Carrizo", lados=6)
    # Va casi derecho detras de la cabeza (no se agacha con ella): solo sigue a donde quedo
    derecho = Matrix.Translation(mc @ centro) @ Matrix.Rotation(_m["INCLINA"] * 0.4, 4, "X") @ Matrix.Translation(-centro)
    bmesh.ops.transform(bm, matrix=derecho, verts=bm.verts)
    ob = objeto(col, "Resplandor_Alta", bm, mats)
    return ob


# --- El vestido: falda colgada del armazon, blusa mojada, mangas caidas, bordado, cola, rebozo ---

VARAS = 10   # las varas del armazon de la falda (las mismas de Carrizo)


def _radio_tela(a, z):
    """La tela colgada del armazon: pegada a cada vara, se mete entre vara y vara (mas abajo, mas
    mojada y pesada), con pliegues finos y bultos de papel mache."""
    r = radio_vestido(z)
    fase = (a * VARAS / math.tau - 0.5) % 1.0
    entre = math.sin(math.pi * fase)
    if z < 2.42:
        abajo = min(max((2.42 - z) / 2.42, 0.0), 1.0)
        r *= 1.0 - 0.07 * entre * (0.3 + abajo)
        r *= 1.0 + 0.018 * math.cos(a * 34 + 3.0 * noise.noise(Vector((a, z * 2, 0)))) * abajo
    elif z > 2.8:
        # La blusa mojada: arrugas que jalan para abajo
        r *= 1.0 + 0.012 * math.sin(z * 28 + a * 3 + 2.0 * noise.noise(Vector((a * 2, z, 1))))
    r *= 1.0 + 0.035 * noise.noise(Vector((math.cos(a) * 1.7, math.sin(a) * 1.7, z * 1.3)))
    return r


def _torno_fino(bm, perfil, lados, paso):
    """Un torno denso: un anillo cada `paso` m entre los puntos del perfil, la tela con
    _radio_tela, el ruedo deshilachado y colgando entre las varas."""
    filas = []
    for k in range(len(perfil) - 1):
        r0, z0, zona0 = perfil[k]
        r1, z1, _ = perfil[k + 1]
        pasos = max(int(abs(z1 - z0) / paso), 1)
        for i in range(pasos):
            filas.append((z0 + (z1 - z0) * i / pasos, zona0))
    filas.append((perfil[-1][1], perfil[-1][2]))
    anillos = []
    rnd = random.Random(5)
    for k, (z, _) in enumerate(filas):
        anillo = []
        for i in range(lados):
            a = math.tau * i / lados
            r = _radio_tela(a, z)
            zz = z
            if k == 0:
                fase = (a * VARAS / math.tau - 0.5) % 1.0
                zz += -0.12 * math.sin(math.pi * fase) + 0.05 * noise.noise(Vector((a * 3, 0, 0))) - 0.05 * (i % 3 == 0) * rnd.random()
                zz = max(zz, 0.0)
            anillo.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, zz)))
        anillos.append(anillo)
    for k in range(len(anillos) - 1):
        for i in range(lados):
            j = (i + 1) % lados
            f = bm.faces.new((anillos[k][i], anillos[k][j], anillos[k + 1][j], anillos[k + 1][i]))
            f.material_index = zona(filas[k][1])


def _sobre_tela(a, z, salir=0.01):
    r = _radio_tela(a, z) + salir
    return Vector((math.cos(a) * r, math.sin(a) * r, z))


def _olan(bm, centro, radio, ancho, ondas, nombre="Blanco"):
    """Un olan: una tira ondulada en anillo que cuelga hacia abajo, con la orilla deshilachada."""
    centro = Vector(centro)
    lados = ondas * 8
    arriba, abajo_ = [], []
    for i in range(lados):
        a = math.tau * i / lados
        onda = 1.0 + 0.12 * math.sin(a * ondas)
        dir_ = Vector((math.cos(a), math.sin(a), 0))
        arriba.append(bm.verts.new(centro + dir_ * radio))
        caida = ancho * (1.0 + 0.25 * noise.noise(dir_ * 5.0))
        abajo_.append(bm.verts.new(centro + dir_ * radio * onda * 1.12 + Vector((0, 0, -caida))))
    caras = [bm.faces.new((arriba[i], arriba[(i + 1) % lados], abajo_[(i + 1) % lados], abajo_[i])) for i in range(lados)]
    pintar(caras, nombre)


def _bordado_ovalo(bm, a0, z0, ancho, alto):
    """Un ovalo bordado en relieve sobre la blusa: hilo grueso siguiendo la tela."""
    pts = []
    for i in range(41):
        t = math.tau * i / 40
        pts.append(_sobre_tela(a0 + math.cos(t) * ancho / 0.9, z0 + math.sin(t) * alto, 0.012))
    tubo(bm, pts, 0.012, "Flor_Naranja", lados=5, tapas=False)


def _roseta(bm, a0, z0, radio, nombre):
    """Una flor bordada: cinco petalos de hilo."""
    for p in range(5):
        b = math.tau * p / 5
        pts = []
        for i in range(13):
            t = math.pi * i / 12
            rr = radio * math.sin(t)
            ang = b + 0.5 * math.cos(t)
            pts.append(_sobre_tela(a0 + rr * math.cos(ang) / 1.2, z0 + rr * math.sin(ang), 0.012))
        tubo(bm, pts, 0.011, nombre, lados=5, tapas=False)


def _zigzag(bm, z, alto, nombre, salir=0.015):
    pts = [_sobre_tela(math.tau * i / 96, z + (alto if i % 2 else -alto), salir) for i in range(97)]
    tubo(bm, pts, 0.01, nombre, lados=4, tapas=False)


def _parche(bm, a0, z0, ancho, alto, nombre="Papel"):
    """Un parche de papel encima de la tela, con puntadas en cruz en la orilla."""
    filas = []
    for i in range(4):
        fila = []
        for j in range(4):
            a = a0 + (j / 3 - 0.5) * ancho / 1.2
            z = z0 + (i / 3 - 0.5) * alto
            fila.append(bm.verts.new(_sobre_tela(a, z, 0.02 + 0.01 * noise.noise(Vector((a * 9, z * 9, 0))))))
        filas.append(fila)
    caras = [bm.faces.new((filas[i][j], filas[i][j + 1], filas[i + 1][j + 1], filas[i + 1][j])) for i in range(3) for j in range(3)]
    pintar(caras, nombre)
    for k in range(10):
        t = k / 9
        for lado_z in (-0.5, 0.5):
            c = _sobre_tela(a0 + (t - 0.5) * ancho / 1.2, z0 + lado_z * alto, 0.03)
            tubo(bm, [c + Vector((0.02, 0, 0.02)), c - Vector((0.02, 0, 0.02))], 0.005, "Cuerda", lados=3)
            tubo(bm, [c + Vector((-0.02, 0, 0.02)), c - Vector((-0.02, 0, 0.02))], 0.005, "Cuerda", lados=3)


def _manga(bm, lado):
    """La manga abombada, mojada: cuelga, con pliegues que bajan al olan."""
    centro = Vector((HOMBRO * lado, 0, HOMBRO_Z))
    vs = esfera(bm, centro, (0.48, 0.46, 0.42), "Tela", seg=40, anillos=24)
    for v in vs:
        rel = v.co - centro
        a = math.atan2(rel.y, rel.x)
        if rel.z < 0:
            v.co.z -= 0.14 * (-rel.z / 0.42) ** 1.5
        v.co += Vector((rel.x, rel.y, 0)).normalized() * 0.03 * math.cos(a * 9) * max(-rel.z, 0) / 0.42
        v.co += rel.normalized() * 0.02 * noise.noise(v.co * 3)
    _olan(bm, centro + Vector((0.02 * lado, 0, -0.5)), 0.4, 0.2, 9)
    for k in range(3):
        a = Vector((HOMBRO * lado + 0.1 * lado, 0.08 * (k - 1), HOMBRO_Z + 0.3))
        cana(bm, a, a + Vector((0.25 * lado, 0.12 * (k - 1), 0.34 + 0.06 * k)), 0.032, nudo_cada=0.15, lados=5, punta_rota=True)


def _cola(bm, rasgada=False):
    """La cola: la falda de atras se arrastra 3.5 m por el piso, con pliegues y la punta deshecha."""
    columnas, filas = 26, 30
    rejilla = []
    for i in range(columnas + 1):
        u = i / columnas - 0.5
        col = []
        for j in range(filas + 1):
            v = j / filas
            a = math.pi / 2 + u * 1.6 * (1.0 - 0.35 * v)
            r0 = _radio_tela(a, 0.25) + 0.02
            base = Vector((math.cos(a) * r0, math.sin(a) * r0, 0.0))
            y = base.y + v * 3.6
            x = base.x * (1.0 + 0.6 * v)
            pliegue = 0.08 * math.sin(u * 26 + v * 3) * (0.3 + v)
            z = 0.55 * (1 - v) ** 3 + max(pliegue, 0.0) + 0.02
            col.append(bm.verts.new((x + 0.04 * noise.noise(Vector((u * 5, v * 5, 0))), y, z)))
        rejilla.append(col)
    caras = []
    for i in range(columnas):
        for j in range(filas):
            c = Vector(rejilla[i][j].co)
            punta = j > filas * 0.75 and noise.noise(c * 2.5) > (0.55 - (j / filas - 0.75) * 3.0)
            hoyo = rasgada and noise.noise(c * 1.4 + Vector((2, 2, 2))) > 0.2
            if punta or hoyo:
                continue
            caras.append(bm.faces.new((rejilla[i][j], rejilla[i + 1][j], rejilla[i + 1][j + 1], rejilla[i][j + 1])))
    pintar(caras, "Tela")
    rnd = random.Random(9)
    for k in range(7):
        p = Vector((rnd.uniform(-1.2, 1.2), rnd.uniform(1.8, 4.2), 0.05))
        cana(bm, p, p + Vector((rnd.uniform(-0.5, 0.5), rnd.uniform(-0.4, 0.4), 0.02)), 0.025, lados=5, punta_rota=True)
    tubo(bm, [Vector((0.4, 3.0, 0.07)), Vector((0.62, 3.1, 0.07))], 0.06, "Vela", lados=8)
    for k in range(5):
        cempasuchil(bm, Vector((rnd.uniform(-1.0, 1.0), rnd.uniform(1.5, 3.8), 0.08)), 0.08, normal=(0, 0, 1))


def _rebozo(bm, rasgado=False):
    """El rebozo: cae de los hombros por la espalda hasta atras de las rodillas, abriendose en
    pliegues que se ensanchan hacia abajo, deshilachado, con flecos largos."""
    columnas, filas = 48, 40
    rejilla = []
    for i in range(columnas + 1):
        u = i / columnas
        a = math.radians(-20) + math.radians(220) * u
        largo = 1.0 + 0.22 * noise.noise(Vector((u * 5.0, 1.3, 0)))
        col = []
        for j in range(filas + 1):
            v = j / filas
            z = 4.55 - v * (4.55 - 0.9) * largo
            if z > 4.15:
                r = 0.75 + (4.55 - z) * 0.85 + 0.3
            else:
                r = _radio_tela(a, max(z, 0.3)) + 0.07 + 0.25 * v
            r += 0.07 * v * math.sin(u * math.tau * 7 + 1.5 * noise.noise(Vector((u * 3, v * 2, 0))))
            col.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        rejilla.append(col)
    caras = []
    for i in range(columnas):
        for j in range(filas):
            c = (Vector(rejilla[i][j].co) + Vector(rejilla[i + 1][j + 1].co)) / 2
            borde = j > filas * 0.85 and noise.noise(c * 3.0) > 0.4 - (j / filas - 0.85) * 4
            hoyo = rasgado and c.z < 3.6 and noise.noise(c * 1.8 + Vector((1, 2, 3))) > 0.15
            if borde or hoyo:
                continue
            caras.append(bm.faces.new((rejilla[i][j], rejilla[i][j + 1], rejilla[i + 1][j + 1], rejilla[i + 1][j])))
    pintar(caras, "Rebozo")
    for i in range(columnas + 1):
        p = Vector(rejilla[i][int(filas * 0.86)].co)
        for k in range(3):
            q = p + Vector(((k - 1) * 0.03, 0, 0))
            tubo(bm, suavizar_linea([q, q + Vector((0.01, 0.02, -0.18)), q + Vector((0.0, 0.04, -0.34 - 0.1 * ((i + k) % 3)))], 3),
                 0.008, "Rebozo", lados=3)


def _rasgar(bm):
    """Hoyos con orillas chuecas en la tela (la textura les quema la orilla), colgajos."""
    hoyos = []
    for f in bm.faces:
        if NOMBRES_ZONAS[f.material_index] != "Tela":
            continue
        c = f.calc_center_median()
        if c.z > 0.35 and c.y < 1.6 and noise.noise(c * 1.5 + Vector((3.1, 7.7, 1.3))) + 0.3 * noise.noise(c * 7.0) > 0.08:
            hoyos.append(f)
    bmesh.ops.delete(bm, geom=hoyos, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    orilla = {v for e in bm.edges if e.is_boundary for v in e.verts}
    for v in orilla:
        if 0.35 < v.co.z < 4.6:
            v.co.z -= 0.03 + 0.1 * (0.5 + 0.5 * noise.noise(v.co * 5.0))
            v.co += Vector((v.co.x, v.co.y, 0)).normalized() * 0.05 * (0.5 + 0.5 * noise.noise(v.co * 3.0))


def _vestido_bm(roto=False):
    bm = bmesh.new()
    _torno_fino(bm, _m["PERFIL_VESTIDO"], 96, 0.05)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if _m["_escote"](f.calc_center_median())], context="FACES")
    for f in bm.faces:
        c = f.calc_center_median()
        if NOMBRES_ZONAS[f.material_index] == "Tela" and c.y < -0.25 and 3.9 < c.z < 4.7 and abs(c.x) < (c.z - 3.95) * 0.72 + 0.2:
            f.material_index = zona("Blanco")
    _olan(bm, (0, 0, 1.16), 1.45, 0.24, 18)
    for lado in (-1, 1):
        _manga(bm, lado)
    # Bordado en relieve: ovalos en la blusa, zigzag en las franjas, rosetas en la falda
    for k in range(8):
        a = math.tau * k / 8 + 0.2
        if abs(((a - math.radians(270)) + math.pi) % math.tau - math.pi) < 0.5:
            continue
        _bordado_ovalo(bm, a, 3.3 + 0.35 * (k % 2), 0.13, 0.2)
    for z, alto, nombre in ((2.5, 0.04, "Flor_Magenta"), (2.62, 0.04, "Verde"), (0.22, 0.05, "Flor_Naranja"), (1.08, 0.03, "Flor_Morada")):
        _zigzag(bm, z, alto, nombre)
    for k in range(12):
        _roseta(bm, math.tau * k / 12, 0.55 + 0.45 * (k % 3), 0.11, ["Flor_Magenta", "Flor_Naranja", "Flor_Rosa"][k % 3])
    # Cuerda en la cintura con el nudo y las puntas
    cuerda(bm, [_sobre_tela(math.tau * i / 64, 2.62 + 0.03 * math.sin(i * 0.7), 0.05) for i in range(65)], 0.035)
    cuerda(bm, suavizar_linea([_sobre_tela(4.9, 2.62, 0.08), _sobre_tela(4.95, 2.3, 0.1), _sobre_tela(4.85, 1.9, 0.08)], 5), 0.03)
    cuerda(bm, suavizar_linea([_sobre_tela(4.8, 2.62, 0.08), _sobre_tela(4.7, 2.2, 0.08)], 5), 0.03)
    # Alambre que remienda, parches cosidos, papel que se despega
    tubo(bm, [_sobre_tela(math.radians(200) + math.radians(150) * i / 40, 1.85 + 0.05 * math.sin(i * 0.9), 0.025) for i in range(41)],
         0.012, "Alambre", lados=4, tapas=False)
    for a0, z0 in ((0.6, 1.5), (2.4, 0.7), (3.7, 1.9), (5.5, 3.4)):
        _parche(bm, a0, z0, 0.3, 0.25)
    rnd = random.Random(4)
    for k in range(20):
        a = rnd.uniform(0, math.tau)
        z = rnd.uniform(0.6, 2.3)
        base = _sobre_tela(a, z, 0.015)
        afuera = Vector((math.cos(a), math.sin(a), 0))
        largo = rnd.uniform(0.3, 0.6)
        pts = suavizar_linea([base, base + afuera * 0.03 + Vector((0, 0, -largo * 0.5)), base + afuera * 0.15 + Vector((0, 0, -largo))], 3)
        lado = afuera.cross(Vector((0, 0, 1)))
        izq = [bm.verts.new(p - lado * 0.08) for p in pts]
        der = [bm.verts.new(p + lado * 0.08) for p in pts]
        pintar([bm.faces.new((izq[i], der[i], der[i + 1], izq[i + 1])) for i in range(len(pts) - 1)], "Papel")
    # Velas derretidas en los hombros
    for (x, y, alto) in ((0.95, -0.12, 0.22), (1.2, 0.1, 0.16), (-1.0, 0.05, 0.2)):
        base = Vector((x, y, HOMBRO_Z + 0.36))
        tubo(bm, [base, base + Vector((0, 0, alto))], 0.065, "Vela", lados=10)
        for k in range(4):
            q = base + Vector((math.cos(k * 1.6) * 0.065, math.sin(k * 1.6) * 0.065, alto * 0.9))
            tubo(bm, [q, q + Vector((0, 0, -alto * (0.4 + 0.15 * k)))], [0.02, 0.008], "Vela", lados=4)
        tubo(bm, [base + Vector((0, 0, alto)), base + Vector((0, 0, alto + 0.14))], [0.035, 0.001], "Flama", lados=6, tapas=False)
    # Con la tela simulada (catrina_tela.py) el rebozo y la cola son objetos aparte
    if bpy.data.objects.get("Rebozo_Alta") is None:
        _rebozo(bm, rasgado=roto)
        _cola(bm, rasgada=roto)
    if roto:
        _rasgar(bm)
    for v in bm.verts:
        v.co = doblar(v.co)
    return bm


def vestido(col, mats):
    obs = []
    for nombre, roto in (("Vestido_Alta", False), ("Vestido_Roto_Alta", True)):
        ob = objeto(col, nombre, _vestido_bm(roto), mats)
        desplazar(ob, textura("cat_tela_fina", "CLOUDS", 0.04, noise_depth=2), 0.006)
        obs.append(ob)
    bpy.data.objects["Vestido_Roto_Alta"].hide_set(True)
    return obs


# --- El cuerpo: huesos con sus cabezas y crestas, manos de coyunturas, costillas, columna ---

def hueso(bm, a, b, r, nombre="Hueso", lados=10, cabezas=1.6):
    """Un hueso largo: cana delgada con las puntas gruesas (epifisis) y una cresta."""
    a, b = Vector(a), Vector(b)
    pasos = max(int((b - a).length / 0.04), 4)
    pts = [a.lerp(b, i / pasos) for i in range(pasos + 1)]

    def radio(t):
        punta = max(math.exp(-(t / 0.12) ** 2), math.exp(-((1 - t) / 0.12) ** 2))
        return r * (0.8 + (cabezas - 0.8) * punta)
    return tubo(bm, pts, radio, nombre, lados=lados, estrias=(2, 0.08), torcer=0.15)


def mano_hueso(bm, muneca, dedos_hacia, palma_hacia, escala=1.45):
    antes = set(bm.verts)
    muneca = Vector(muneca)
    d = Vector(dedos_hacia).normalized()
    adentro = Vector(palma_hacia).normalized()
    lado = d.cross(adentro).normalized()
    adentro = lado.cross(d).normalized()
    for k in range(6):
        esfera(bm, muneca + d * 0.05 + lado * ((k % 3) - 1) * 0.045 + d * 0.04 * (k // 3), (0.035,) * 3, "Hueso", seg=10, anillos=6)
    for k in range(4):
        base = muneca + d * 0.12 + lado * (k - 1.5) * 0.06
        nudillo = base + d * 0.17 + lado * (k - 1.5) * 0.012
        hueso(bm, base, nudillo, 0.02, lados=6)
        esfera(bm, nudillo, (0.032,) * 3, "Hueso", seg=10, anillos=6)
        p = nudillo
        dirr = d
        for paso, largo in enumerate((0.19, 0.16, 0.15)):
            dirr = (dirr + adentro * 0.38).normalized()
            q = p + dirr * largo
            if paso < 2:
                hueso(bm, p, q, 0.02, lados=6, cabezas=1.5)
                esfera(bm, q, (0.03,) * 3, "Hueso", seg=10, anillos=6)
            else:
                tubo(bm, [p, p + dirr * largo * 0.6, q + adentro * 0.02], [0.024, 0.016, 0.002], "Hueso", lados=6)
            p = q
    base = muneca + d * 0.06 + lado * 0.11
    q = base + (d * 0.5 + lado * 0.6 + adentro * 0.3).normalized() * 0.16
    hueso(bm, base, q, 0.022, lados=6)
    esfera(bm, q, (0.03,) * 3, "Hueso", seg=10, anillos=6)
    q2 = q + (d + adentro * 0.6).normalized() * 0.13
    tubo(bm, [q, q2, q2 + (d + adentro).normalized() * 0.1], [0.024, 0.016, 0.002], "Hueso", lados=6)
    for v in bm.verts:
        if v not in antes:
            v.co = muneca + (v.co - muneca) * escala


def brazo_hueso(bm, hombro, codo, muneca, dedos_hacia, palma_hacia):
    hombro, codo, muneca = Vector(hombro), Vector(codo), Vector(muneca)
    esfera(bm, hombro, (0.15,) * 3, "Hueso", seg=16, anillos=10)
    hueso(bm, hombro, codo, 0.1)
    d = (muneca - codo).normalized()
    lado = d.cross(Vector((0, 0, 1))).normalized() if abs(d.z) < 0.95 else Vector((1, 0, 0))
    for s in (-1, 1):
        esfera(bm, codo + lado * 0.06 * s, (0.09,) * 3, "Hueso", seg=14, anillos=8)
        hueso(bm, codo + lado * 0.045 * s, muneca + lado * 0.035 * s, 0.045, lados=8)
    mano_hueso(bm, muneca, dedos_hacia, palma_hacia)
    u = d.orthogonal().normalized()
    w = d.cross(u)
    for k in range(9):
        a = math.tau * k / 9
        n = u * math.cos(a) + w * math.sin(a)
        cempasuchil(bm, muneca - d * 0.08 + n * 0.12, 0.05, normal=n)


def cuerpo(col, mats):
    bm = bmesh.new()
    for k in range(6):
        z = 4.45 + 0.1 * k
        esfera(bm, (0, 0.02, z), (0.13, 0.12, 0.05), "Hueso", seg=14, anillos=6)
        tubo(bm, [Vector((0, 0.06, z)), Vector((0, 0.2, z - 0.04))], [0.03, 0.01], "Hueso", lados=5)
        tubo(bm, [Vector((-0.14, 0.0, z)), Vector((0.14, 0.0, z))], 0.022, "Hueso", lados=5)
    for k, z in enumerate((4.0, 4.14, 4.28, 4.42)):
        r = 0.66 - 0.04 * k
        pts = [Vector((math.cos(a) * r, math.sin(a) * r, z - 0.07 * abs(math.cos(a)))) for a in (math.radians(-90 + t) for t in range(-70, 71, 10))]
        tubo(bm, suavizar_linea(pts, 2), lambda t: 0.032 * (0.8 + 0.4 * math.sin(math.pi * t)), "Hueso", lados=6)
    tubo(bm, [Vector((0, -0.66, 3.92)), Vector((0, -0.6, 4.2)), Vector((0, -0.55, 4.5))], [0.05, 0.055, 0.045], "Hueso", lados=8)
    for lado in (-1, 1):
        tubo(bm, suavizar_linea([Vector((0.06 * lado, -0.48, 4.52)), Vector((0.4 * lado, -0.42, 4.56)), Vector((0.82 * lado, -0.18, 4.48))], 4),
             0.05, "Hueso", lados=8)
    for v in bm.verts:
        v.co = doblar(v.co)
    brazo_hueso(bm, doblar(_m["HOMBRO_D"]), _m["CODO_D"], _m["MUNECA_D"], Vector((0.05, -0.15, -1)), Vector((-1, 0.1, 0)))
    brazo_hueso(bm, doblar(_m["HOMBRO_I"]), _m["CODO_I"], _m["MUNECA_I"], Vector((0.55, -0.45, -0.7)), Vector((0.6, 0.3, -0.2)))
    d = (_m["MUNECA_D"] - _m["CODO_D"]).normalized()
    u = d.orthogonal().normalized()
    w = d.cross(u)
    cuerda(bm, [_m["CODO_D"] + d * (0.25 + 0.3 * t / 60) + (u * math.cos(t * 0.5) + w * math.sin(t * 0.5)) * 0.13 for t in range(61)], 0.02)
    for lado in (-1, 1):
        cadera = Vector((0.3 * lado, 0, 2.5))
        rodilla = Vector((0.4 * lado, -0.08, 1.3))
        tobillo = Vector((0.46 * lado, 0, 0.16))
        hueso(bm, cadera, rodilla, 0.11)
        esfera(bm, rodilla + Vector((0, -0.1, 0)), (0.07, 0.04, 0.08), "Hueso", seg=12, anillos=8)
        hueso(bm, rodilla, tobillo, 0.08)
        hueso(bm, rodilla + Vector((0.08 * lado, 0.03, 0)), tobillo + Vector((0.07 * lado, 0.02, 0)), 0.035, lados=6)
        esfera(bm, tobillo + Vector((0, 0.05, -0.05)), (0.09, 0.12, 0.07), "Hueso", seg=12, anillos=8)
        for k in range(5):
            a = tobillo + Vector(((k - 2) * 0.05, -0.05, -0.08))
            b = a + Vector(((k - 2) * 0.02, -0.3, -0.04))
            hueso(bm, a, b, 0.022, lados=6)
            tubo(bm, [b, b + Vector((0, -0.12, -0.03))], [0.02, 0.002], "Hueso", lados=5)
    ob = objeto(col, "Cuerpo_Alta", bm, mats)
    desplazar(ob, textura("cat_poros", "CLOUDS", 0.05, noise_depth=3), 0.006)
    return [ob]


# --- El armazon y el nudo ---

def carrizo(col, mats):
    bm = bmesh.new()
    varas = 8
    torso = [(Vector((math.cos(a) * 0.7, math.sin(a) * 0.7, 2.65)), Vector((math.cos(a) * 0.55, math.sin(a) * 0.55, 4.4)))
             for a in (math.tau * i / varas for i in range(varas))]
    for a, b in torso:
        cana(bm, a, b, 0.035)
    for t in (0.2, 0.65):
        aro = [a.lerp(b, t) for a, b in torso]
        for i in range(varas):
            cana(bm, aro[i], aro[(i + 1) % varas], 0.025, lados=6)
    for i in range(VARAS):
        a = math.tau * (i + 0.5) / VARAS
        cana(bm, (math.cos(a) * 1.45, math.sin(a) * 1.45, 0.15), (math.cos(a) * 0.78, math.sin(a) * 0.78, 2.5), 0.04)
    for z, r in ((0.6, 1.36), (1.6, 1.12)):
        pts = [Vector((math.cos(math.tau * i / 20) * r, math.sin(math.tau * i / 20) * r, z)) for i in range(20)]
        for i in range(20):
            cana(bm, pts[i], pts[(i + 1) % 20], 0.03, lados=6)
    cruces = [a.lerp(b, t) for a, b in torso for t in (0.2, 0.65)]
    cruces += [Vector((math.cos(math.tau * (i + 0.5) / VARAS) * r, math.sin(math.tau * (i + 0.5) / VARAS) * r, z))
               for i in range(VARAS) for z, r in ((0.6, 1.36), (1.6, 1.12))]
    for k, c in enumerate(cruces):
        afuera = Vector((c.x, c.y, 0)).normalized()
        lado = afuera.cross(Vector((0, 0, 1)))
        if k % 2 == 0:
            cuerda(bm, [c + (lado * math.cos(t * 0.6) + afuera * math.sin(t * 0.6)) * 0.055 + Vector((0, 0, 0.004 * t - 0.06)) for t in range(30)], 0.012)
        else:
            tubo(bm, [c + (lado * math.cos(t * 0.6) + Vector((0, 0, 1)) * math.sin(t * 0.6)) * 0.05 for t in range(24)], 0.005, "Alambre", lados=3, tapas=False)
        tubo(bm, [c + afuera * 0.06, c - afuera * 0.03], [0.008, 0.004], "Alambre", lados=4)
        tubo(bm, [c + afuera * 0.06, c + afuera * 0.065], 0.02, "Alambre", lados=6)
    for v in bm.verts:
        v.co = doblar(v.co)
    ob = objeto(col, "Carrizo_Alta", bm, mats)
    ob.hide_set(True)
    return [ob]


def nudo(col, mats):
    bm = bmesh.new()
    rnd = random.Random(2)
    torsos = [((-0.2, 0.0, 0.08), (0.27, 0.2, 0.36)), ((0.22, -0.05, -0.06), (0.26, 0.2, 0.33)),
              ((0.0, 0.06, 0.32), (0.25, 0.19, 0.3)), ((0.05, 0.1, -0.25), (0.22, 0.18, 0.25))]
    for ofs, r in torsos:
        esfera(bm, NUDO + Vector(ofs), r, "Nudo", seg=32, anillos=20)
    for ofs in ((-0.35, -0.05, 0.42), (0.38, -0.1, 0.25), (0.05, -0.12, 0.62), (-0.3, -0.12, -0.2)):
        c = NUDO + Vector(ofs)
        vs = esfera(bm, c, (0.14, 0.13, 0.15), "Nudo", seg=24, anillos=14)
        for v in vs:
            rel = v.co - c
            if rel.y < -0.08 and abs(rel.x) < 0.06 and -0.09 < rel.z < -0.02:
                v.co.y += 0.05
        for x in (-0.05, 0.05):
            esfera(bm, c + Vector((x, -0.12, 0.03)), (0.025,) * 3, "Brillo", seg=8, anillos=5)
    for a, b in (((-0.3, -0.1, 0.0), (-0.75, -0.3, 0.25)), ((0.3, -0.15, 0.1), (0.7, -0.35, -0.2)),
                 ((0.0, -0.1, -0.2), (0.15, -0.45, -0.5)), ((-0.1, -0.1, 0.45), (-0.45, -0.4, 0.75)),
                 ((0.2, -0.1, 0.4), (0.55, -0.45, 0.6))):
        a, b = NUDO + Vector(a), NUDO + Vector(b)
        tubo(bm, suavizar_linea([a, a.lerp(b, 0.5) + Vector((0, 0, 0.05)), b], 4), lambda t: 0.075 - 0.035 * t, "Nudo", lados=8)
        dir_ = (b - a).normalized()
        u = dir_.orthogonal().normalized()
        for k in range(4):
            tubo(bm, [b, b + dir_ * 0.12 + u * (k - 1.5) * 0.04], [0.018, 0.006], "Nudo", lados=5)
    for k in range(14):
        a = rnd.uniform(0, math.tau)
        z = rnd.uniform(-0.3, 0.5)
        pts = [NUDO + Vector((math.cos(a + 0.15 * i) * 0.3, -0.18 + 0.02 * math.sin(i), z + 0.05 * i)) for i in range(7)]
        tubo(bm, suavizar_linea(pts, 2), 0.012, "Brillo", lados=4, tapas=False)
    for v in bm.verts:
        v.co = doblar(v.co)
    ob = objeto(col, "Nudo_Alta", bm, mats)
    desplazar(ob, textura("cat_arrugas", "VORONOI", 0.06), 0.02)
    ob.hide_set(True)
    return [ob]


PARTES_TODAS = {"cabeza": cabeza, "vestido": vestido, "cuerpo": cuerpo, "carrizo": carrizo, "nudo": nudo}


def armar_alta(partes=None):
    sc, col, cortes = coleccion()
    mats = materiales()
    hechas = []
    for nombre, hacer in PARTES_TODAS.items():
        if partes and nombre not in partes:
            continue
        hechas += hacer(col, cortes, mats) if nombre == "cabeza" else hacer(col, mats)
    # La malla del juego (v2) se esconde mientras se ve la alta
    for nombre in ("Vestido", "Vestido_Roto", "Cuerpo", "Craneo", "Carrizo", "Nudo"):
        ob = bpy.data.objects.get(nombre)
        if ob:
            ob.hide_set(True)
    dg = bpy.context.evaluated_depsgraph_get()
    for ob in hechas:
        ev = ob.evaluated_get(dg)
        print("%-18s %8d tris" % (ob.name, sum(len(p.vertices) - 2 for p in ev.data.polygons)))
    return hechas


if not globals().get("SOLO_FUNCIONES"):
    armar_alta(PARTES)
