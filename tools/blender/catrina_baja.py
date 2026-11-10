# La Mojiganga, paso 1c-B: la malla del juego (~8k triangulos a la vez, AG 2026-11-09). Las mismas
# formas que la alta (catrina_alta.py: la tela colgada del armazon, el craneo, el resplandor, la
# cola, el rebozo) a baja resolucion, con los seis nombres que busca Catrina.gd. El detalle fino
# (dientes sueltos, bordado, grietas, cuerdas delgadas) se queda en la alta y llega por la textura
# horneada (catrina_textura.py).
#
# Se corre en Blender como los demas. Reemplaza los objetos Vestido, Vestido_Roto, Cuerpo, Craneo,
# Carrizo y Nudo de la escena "Catrina".

import bpy
import bmesh
import math
import random
from mathutils import Vector, Matrix, noise

RUTA = r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender"
_a = {"SOLO_FUNCIONES": True, "__name__": "catrina_alta"}
exec(open(RUTA + r"\catrina_alta.py", encoding="utf-8").read(), _a)
_m = _a["_m"]
for _n in ("zona", "pintar", "caras_de", "esfera", "tubo", "suavizar_linea", "matriz_cabeza", "_forma_craneo",
           "_radio_tela", "_sobre_tela", "_torno_fino", "doblar", "radio_vestido", "CABEZA", "FLORES", "CEMPASUCHIL",
           "HOMBRO", "HOMBRO_Z", "NOMBRES_ZONAS", "SUAVES"):
    globals()[_n] = _a[_n]


def prisma(bm, a, b, r1, r2, nombre):
    """Un carrizo de pocos triangulos: prisma de tres lados."""
    return tubo(bm, [Vector(a), Vector(b)], [r1, r2], nombre, lados=3, tapas=False)


def olan_bajo(bm, centro, radio, ancho, ondas, nombre="Blanco"):
    centro = Vector(centro)
    lados = ondas * 2
    arriba, abajo = [], []
    for i in range(lados):
        a = math.tau * i / lados
        d = Vector((math.cos(a), math.sin(a), 0))
        onda = 1.0 + 0.14 * (1 if i % 2 else -1)
        arriba.append(bm.verts.new(centro + d * radio))
        abajo.append(bm.verts.new(centro + d * radio * onda * 1.12 + Vector((0, 0, -ancho))))
    pintar([bm.faces.new((arriba[i], arriba[(i + 1) % lados], abajo[(i + 1) % lados], abajo[i])) for i in range(lados)], nombre)


def manga_baja(bm, lado):
    centro = Vector((HOMBRO * lado, 0, HOMBRO_Z))
    vs = esfera(bm, centro, (0.48, 0.46, 0.42), "Tela", seg=10, anillos=7)
    for v in vs:
        rel = v.co - centro
        if rel.z < 0:
            v.co.z -= 0.14 * (-rel.z / 0.42) ** 1.5
    olan_bajo(bm, centro + Vector((0.02 * lado, 0, -0.5)), 0.4, 0.2, 9)
    for k in range(3):
        a = Vector((HOMBRO * lado + 0.1 * lado, 0.08 * (k - 1), HOMBRO_Z + 0.3))
        prisma(bm, a, a + Vector((0.25 * lado, 0.12 * (k - 1), 0.34 + 0.06 * k)), 0.04, 0.005, "Carrizo")


def rejilla(bm, columnas, filas, punto, nombre, quitar=None):
    """Una tela en rejilla: punto(u, v) -> Vector; quitar(c, u, v) -> True deja un hoyo."""
    vs = [[bm.verts.new(punto(i / columnas, j / filas)) for j in range(filas + 1)] for i in range(columnas + 1)]
    caras = []
    for i in range(columnas):
        for j in range(filas):
            c = (Vector(vs[i][j].co) + Vector(vs[i + 1][j + 1].co)) / 2
            if quitar and quitar(c, i / columnas, j / filas):
                continue
            caras.append(bm.faces.new((vs[i][j], vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j])))
    pintar(caras, nombre)
    bmesh.ops.delete(bm, geom=[v for col in vs for v in col if not v.link_faces], context="VERTS")


def _de_simulada(nombre, cols, filas):
    """Un punto(u, v) que toma la rejilla de tela simulada (catrina_tela.py: vertices columna por
    columna) en el vertice mas cercano; None si no se ha simulado."""
    ob = bpy.data.objects.get(nombre)
    if ob is None:
        return None
    vs = ob.data.vertices
    mw = ob.matrix_world

    def punto(u, v):
        i = round(u * cols)
        j = round(v * filas)
        return mw @ vs[i * (filas + 1) + j].co
    return punto


def rebozo_bajo(bm, rasgado):
    simulada = _de_simulada("Rebozo_Alta", 42, 30)

    def punto(u, v):
        a = math.radians(-20) + math.radians(220) * u
        largo = 1.0 + 0.22 * noise.noise(Vector((u * 5.0, 1.3, 0)))
        z = 4.55 - v * (4.55 - 0.9) * largo
        r = 0.75 + (4.55 - z) * 0.85 + 0.3 if z > 4.15 else _radio_tela(a, max(z, 0.3)) + 0.07 + 0.25 * v
        r += 0.07 * v * math.sin(u * math.tau * 7)
        return Vector((math.cos(a) * r, math.sin(a) * r, z))
    quitar = (lambda c, u, v: c.z < 3.6 and noise.noise(c * 1.8 + Vector((1, 2, 3))) > 0.15) if rasgado else None
    if simulada:
        # 14 x 10 cuadros de los 42 x 30 de la simulada (cada 3), ya con la joroba puesta
        rejilla(bm, 14, 10, simulada, "Rebozo", quitar)
        return "simulada"
    rejilla(bm, 16, 8, punto, "Rebozo", quitar)


def cola_baja(bm, rasgada):
    simulada = _de_simulada("Cola_Alta", 26, 24)

    def punto(u, v):
        u -= 0.5
        a = math.pi / 2 + u * 1.6 * (1.0 - 0.35 * v)
        r0 = _radio_tela(a, 0.25) + 0.02
        x = math.cos(a) * r0 * (1.0 + 0.6 * v)
        y = math.sin(a) * r0 + v * 3.6
        z = 0.55 * (1 - v) ** 3 + max(0.08 * math.sin(u * 26 + v * 3) * (0.3 + v), 0.0) + 0.02
        return Vector((x, y, z))
    quitar = (lambda c, u, v: noise.noise(c * 1.4 + Vector((2, 2, 2))) > 0.2) if rasgada else (lambda c, u, v: v > 0.8 and noise.noise(c * 2.5) > 0.3)
    if simulada:
        rejilla(bm, 13, 8, simulada, "Tela", quitar)
        return "simulada"
    rejilla(bm, 10, 8, punto, "Tela", quitar)


def vestido_bajo(roto):
    bm = bmesh.new()
    _torno_fino(bm, _m["PERFIL_VESTIDO"], 30, 0.24)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if _m["_escote"](f.calc_center_median())], context="FACES")
    for f in bm.faces:
        c = f.calc_center_median()
        if NOMBRES_ZONAS[f.material_index] == "Tela" and c.y < -0.25 and 3.9 < c.z < 4.7 and abs(c.x) < (c.z - 3.95) * 0.72 + 0.2:
            f.material_index = zona("Blanco")
    olan_bajo(bm, (0, 0, 1.16), 1.45, 0.24, 15)
    for lado in (-1, 1):
        manga_baja(bm, lado)
    # La cuerda de la cintura (un aro de seis lados) y las puntas que cuelgan
    tubo(bm, [_sobre_tela(math.tau * i / 16, 2.62, 0.05) for i in range(17)], 0.035, "Cuerda", lados=4, tapas=False)
    tubo(bm, [_sobre_tela(4.9, 2.62, 0.08), _sobre_tela(4.95, 2.25, 0.1), _sobre_tela(4.85, 1.9, 0.08)], 0.03, "Cuerda", lados=4)
    # Tiras de papel que se despegan (un quad o dos cada una)
    rnd = random.Random(4)
    for k in range(12):
        a = rnd.uniform(0, math.tau)
        z = rnd.uniform(0.6, 2.3)
        base = _sobre_tela(a, z, 0.015)
        afuera = Vector((math.cos(a), math.sin(a), 0))
        lado = afuera.cross(Vector((0, 0, 1)))
        largo = rnd.uniform(0.3, 0.6)
        pts = [base, base + afuera * 0.04 + Vector((0, 0, -largo * 0.5)), base + afuera * 0.15 + Vector((0, 0, -largo))]
        izq = [bm.verts.new(p - lado * 0.08) for p in pts]
        der = [bm.verts.new(p + lado * 0.08) for p in pts]
        pintar([bm.faces.new((izq[i], der[i], der[i + 1], izq[i + 1])) for i in range(2)], "Papel")
    # Velas en los hombros
    for (x, y, alto) in ((0.95, -0.12, 0.22), (1.2, 0.1, 0.16), (-1.0, 0.05, 0.2)):
        base = Vector((x, y, HOMBRO_Z + 0.36))
        tubo(bm, [base, base + Vector((0, 0, alto))], 0.065, "Vela", lados=5)
        tubo(bm, [base + Vector((0, 0, alto)), base + Vector((0, 0, alto + 0.14))], [0.035, 0.001], "Flama", lados=3, tapas=False)
    antes = set(bm.verts)
    simulada = rebozo_bajo(bm, roto) == "simulada"
    cola_baja(bm, roto)
    ya_dobladas = {v for v in bm.verts if v not in antes} if simulada else set()
    if roto:
        tela = [f for f in bm.faces if NOMBRES_ZONAS[f.material_index] == "Tela"]
        bmesh.ops.triangulate(bm, faces=tela)
        hoyos = [f for f in bm.faces if NOMBRES_ZONAS[f.material_index] == "Tela" and (lambda c: c.z > 0.35 and c.y < 1.6 and
                 noise.noise(c * 1.5 + Vector((3.1, 7.7, 1.3))) + 0.3 * noise.noise(c * 7.0) > 0.08)(f.calc_center_median())]
        bmesh.ops.delete(bm, geom=hoyos, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        for v in {v for e in bm.edges if e.is_boundary for v in e.verts}:
            if 0.35 < v.co.z < 4.6:
                v.co.z -= 0.03 + 0.1 * (0.5 + 0.5 * noise.noise(v.co * 5.0))
                v.co += Vector((v.co.x, v.co.y, 0)).normalized() * 0.05
    for v in bm.verts:
        if v not in ya_dobladas:
            v.co = doblar(v.co)
    return bm


def flor_baja(bm, centro, normal, radio, nombre, capas=2):
    centro = Vector(centro)
    giro = Vector((0, 0, 1)).rotation_difference(Vector(normal).normalized()).to_matrix().to_4x4()
    todas = []
    for capa in range(capas):
        rr = radio * (1.0, 0.65, 0.42)[capa]
        medio = bm.verts.new((0, 0, 0.05 * capa + 0.03))
        borde = []
        for i in range(12):
            a = math.tau * i / 12 + 0.4 * capa
            r = rr if i % 2 == 0 else rr * 0.6
            borde.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, 0.05 * capa - 0.03 * (i % 2))))
        pintar([bm.faces.new((medio, borde[i], borde[(i + 1) % 12])) for i in range(12)], nombre)
        todas += [medio] + borde
    bmesh.ops.transform(bm, matrix=Matrix.Translation(centro) @ giro, verts=todas)


def craneo_bajo():
    mc = matriz_cabeza()
    C = CABEZA
    bm = bmesh.new()
    vs = esfera(bm, C, (0.6, 0.62, 0.62), "Hueso", seg=22, anillos=16)
    for v in vs:
        _forma_craneo(v, v.co - C)
    for x in (-0.24, 0.24):
        esfera(bm, C + Vector((x, -0.18, 0.04)), (0.09, 0.05, 0.08), "Brillo", seg=6, anillos=4)
    # Los dientes como dos tiras curvas (la textura dibuja cada diente, los que faltan y los rotos)
    dientes_abajo = []
    for z0, z1, y0 in ((-0.28, -0.44, -0.58), (-0.47, -0.6, -0.54)):
        arriba, abajo = [], []
        for i in range(9):
            x = -0.34 + 0.68 * i / 8
            y = y0 + 0.5 * x * x
            arriba.append(bm.verts.new(C + Vector((x, y, z0))))
            abajo.append(bm.verts.new(C + Vector((x, y, z1))))
        pintar([bm.faces.new((arriba[i], arriba[i + 1], abajo[i + 1], abajo[i])) for i in range(8)], "Hueso")
        if z0 < -0.4:
            dientes_abajo = arriba + abajo
    # Quijada zafada
    pts = [C + Vector((-0.42, -0.05, -0.28))] + [C + Vector((x, -0.2 - 0.36 * (1 - (x / 0.4) ** 2), -0.64 + 0.06 * (x / 0.4) ** 2))
                                                  for x in (-0.4 + 0.8 * i / 6 for i in range(7))] + [C + Vector((0.42, -0.05, -0.28))]
    q = tubo(bm, pts, 0.08, "Hueso", lados=5)
    bisagra = C + Vector((0.42, -0.05, -0.28))
    zafar = Matrix.Translation(bisagra) @ Matrix.Rotation(math.radians(-9), 4, "X") @ Matrix.Rotation(math.radians(7), 4, "Y") @ Matrix.Translation(-bisagra)
    bmesh.ops.transform(bm, matrix=zafar, verts=q + dientes_abajo)
    # Peinado
    vs = esfera(bm, C + Vector((0, 0.16, 0.16)), (0.66, 0.6, 0.6), "Cabello", seg=14, anillos=8)
    for v in vs:
        rel = v.co - C
        if rel.y < -0.38 and rel.z < 0.45:
            v.co.y += 0.12
    esfera(bm, C + Vector((0, 0.66, 0.08)), (0.42, 0.38, 0.4), "Cabello", seg=10, anillos=6)
    trenza = tubo(bm, [(C + Vector((0, 0.92, -0.1))).lerp(Vector((0, 1.15, 2.85)), t / 8) for t in range(9)],
                  lambda t: 0.11 - 0.04 * t, "Cabello", lados=5)
    # Flores grandes, cempasuchiles, sartas y aretes
    for ofs, nombre in FLORES:
        flor_baja(bm, C + Vector(ofs), Vector(ofs) + Vector((0, -0.5, 0)), 0.3, nombre, capas=3)
    for ofs in CEMPASUCHIL:
        esfera(bm, C + Vector(ofs), (0.12,) * 3, "Flor_Naranja", seg=6, anillos=4)
    for lado in (-1, 1):
        for k in range(5):
            esfera(bm, C + Vector((0.7 * lado, -0.12, 0.12 - 0.21 * k)), (0.08,) * 3, "Flor_Naranja", seg=5, anillos=3)
        for k, nombre in enumerate(["Verde", "Flor_Naranja", "Flor_Rosa"]):
            esfera(bm, C + Vector((0.6 * lado, -0.02, -0.32 - 0.19 * k)), (0.1,) * 3, nombre, seg=6, anillos=4)
    cabeza_vs = [v for v in bm.verts if v not in set(trenza)]
    bmesh.ops.transform(bm, matrix=mc, verts=cabeza_vs)
    for v in trenza:
        v.co = doblar(v.co)
    # El resplandor: prismas de carrizo, el aro, velas
    rnd = random.Random(3)
    centro = C + Vector((0, 0.55, 0.05))
    res = []
    for i in range(32):
        a = math.tau * i / 32
        largo = (2.0 if i % 2 == 0 else 1.25) * rnd.uniform(0.9, 1.08)
        rota = rnd.random() < 0.28
        if rota:
            largo *= rnd.uniform(0.45, 0.7)
        d = Vector((math.cos(a), 0.12 * rnd.uniform(-1, 1), math.sin(a))).normalized()
        res += prisma(bm, centro + d * 0.55, centro + d * largo, 0.055 if i % 2 == 0 else 0.045, 0.03 if rota else 0.04, "Carrizo")
        if not rota and i % 4 == 0:
            res += tubo(bm, [centro + d * largo, centro + d * (largo + 0.22)], 0.06, "Vela", lados=4)
            res += tubo(bm, [centro + d * (largo + 0.22), centro + d * (largo + 0.36)], [0.035, 0.001], "Flama", lados=3, tapas=False)
        elif not rota and rnd.random() < 0.5:
            rnd.uniform(0.5, 0.8)   # el cempasuchil de la alta: mismo orden de azar, mismas varas
    res += tubo(bm, [centro + Vector((math.cos(t) * 0.52, 0, math.sin(t) * 0.52)) for t in (math.tau * i / 16 for i in range(17))], 0.07, "Cuerda", lados=4, tapas=False)
    res += tubo(bm, [centro + Vector((math.cos(t) * 1.1, 0.06, math.sin(t) * 1.1)) for t in (math.tau * i / 24 for i in range(25))], 0.035, "Carrizo", lados=3, tapas=False)
    derecho = Matrix.Translation(mc @ centro) @ Matrix.Rotation(_m["INCLINA"] * 0.4, 4, "X") @ Matrix.Translation(-centro)
    bmesh.ops.transform(bm, matrix=derecho, verts=res)
    return bm


def puntas_velas():
    """Donde quedan las puntas de las flamas de las velas del resplandor (mundo, pose de reposo):
    la misma secuencia de azar que craneo_bajo. catrina_rig.py pone ahi los huesos Vela_0..N, de
    los que Catrina.gd cuelga las flamas de pixelfx."""
    mc = matriz_cabeza()
    C = CABEZA
    rnd = random.Random(3)
    centro = C + Vector((0, 0.55, 0.05))
    puntas = []
    for i in range(32):
        a = math.tau * i / 32
        largo = (2.0 if i % 2 == 0 else 1.25) * rnd.uniform(0.9, 1.08)
        rota = rnd.random() < 0.28
        if rota:
            largo *= rnd.uniform(0.45, 0.7)
        d = Vector((math.cos(a), 0.12 * rnd.uniform(-1, 1), math.sin(a))).normalized()
        if not rota and i % 4 == 0:
            puntas.append(centro + d * (largo + 0.3))
        elif not rota and rnd.random() < 0.5:
            rnd.uniform(0.5, 0.8)
    derecho = Matrix.Translation(mc @ centro) @ Matrix.Rotation(_m["INCLINA"] * 0.4, 4, "X") @ Matrix.Translation(-centro)
    return [derecho @ p for p in puntas]


def cuerpo_bajo():
    bm = bmesh.new()
    _m["cuerpo"](bm)
    return bm


def armar_baja():
    sc = bpy.data.scenes["Catrina"]
    for ventana in bpy.context.window_manager.windows:
        ventana.scene = sc
    mats = _m["materiales"]()
    piezas = {}
    hacer = {
        "Vestido": lambda: vestido_bajo(False),
        "Vestido_Roto": lambda: vestido_bajo(True),
        "Cuerpo": cuerpo_bajo,
        "Craneo": craneo_bajo,
        "Carrizo": lambda: (lambda b: (_m["carrizo"](b), b)[1])(bmesh.new()),
        "Nudo": lambda: (lambda b: (_m["nudo"](b), b)[1])(bmesh.new()),
    }
    for nombre, f in hacer.items():
        vieja = bpy.data.objects.get(nombre)
        if vieja:
            bpy.data.objects.remove(vieja, do_unlink=True)
        piezas[nombre] = _m["objeto"](sc, nombre, f(), mats)
    for nombre in ("Vestido_Roto", "Carrizo", "Nudo"):
        piezas[nombre].hide_set(True)
    cuenta = {n: sum(len(p.vertices) - 2 for p in ob.data.polygons) for n, ob in piezas.items()}
    for n, c in cuenta.items():
        print("%-13s %5d tris" % (n, c))
    print("a la vez: fase 1 %d, fase 2 %d, fase 3 %d" % (
        cuenta["Vestido"] + cuenta["Cuerpo"] + cuenta["Craneo"],
        cuenta["Vestido_Roto"] + cuenta["Cuerpo"] + cuenta["Craneo"] + cuenta["Carrizo"],
        cuenta["Vestido_Roto"] + cuenta["Cuerpo"] + cuenta["Carrizo"] + cuenta["Nudo"]))
    return piezas


if not globals().get("SOLO_FUNCIONES"):
    armar_baja()
