# La Mojiganga, paso 3: el esqueleto. Huesos con nombres de Mixamo (con guion bajo, como el
# Panzon), la trenza (Trenza_0..5), la cola (Cola_0..3) y los marcadores que busca Catrina.gd
# (Mano_R, Mano_L, Pie_R, Cabeza, Trenza_Punta, Arete_L/R, Flor_0..3, Pecho_Nudo, Vela_0..N: no
# deforman; las Vela son las puntas de las flamas del resplandor, para las flamas de pixelfx).
# Los huesos siguen la joroba (catrina_malla.doblar). Los pesos se calculan aqui por distancia a
# cada hueso (las mallas de figuras no se llevan con los pesos automaticos de Blender), con reglas
# por pieza: el craneo, el resplandor y las flores van rigidos a la cabeza; la cola a sus huesos.
#
# Se corre en Blender despues de catrina_baja.py y catrina_textura.py.

import bpy
import math
from mathutils import Vector, Matrix

RAIZ = r"C:\Users\Big Boss\Documents\GitHub\project-taquito"
_a = {"SOLO_FUNCIONES": True, "__name__": "catrina_alta"}
exec(open(RAIZ + r"\tools\blender\catrina_alta.py", encoding="utf-8").read(), _a)
_m = _a["_m"]
doblar = _m["doblar"]
mc = _a["matriz_cabeza"]()
C = _m["CABEZA"]
P = "mixamorig_"
MALLAS = ["Vestido", "Vestido_Roto", "Cuerpo", "Craneo", "Carrizo", "Nudo"]


def _d(x, y, z):
    return doblar(Vector((x, y, z)))


def _cab(x, y, z):
    return mc @ (C + Vector((x, y, z)))


def huesos():
    """nombre -> (cabeza, cola, padre, deforma)"""
    h = {}
    h[P + "Hips"] = (Vector((0, 0, 2.45)), Vector((0, 0, 2.75)), None, True)
    # El ruedo: no se mueve (no tiene clips). La falda va de el (en el piso) a la cadera (en la
    # cintura): al hincarse o gatear la falda se aplasta en vez de hundirse en el piso
    h["Ruedo"] = (Vector((0, 0, 0)), Vector((0, 0, 0.4)), None, True)
    h[P + "Spine"] = (_d(0, 0, 2.75), _d(0, 0, 3.3), P + "Hips", True)
    h[P + "Spine1"] = (_d(0, 0, 3.3), _d(0, 0, 3.9), P + "Spine", True)
    h[P + "Spine2"] = (_d(0, 0, 3.9), _d(0, 0, 4.45), P + "Spine1", True)
    h[P + "Neck"] = (_d(0, 0, 4.45), _d(0, 0, 4.82), P + "Spine2", True)
    h[P + "Head"] = (_d(0, 0, 4.82), _cab(0, 0, 0.6), P + "Neck", True)
    for lado, s in (("Left", -1), ("Right", 1)):
        hombro = doblar(_m["HOMBRO_I"] if s < 0 else _m["HOMBRO_D"])
        codo = _m["CODO_I"] if s < 0 else _m["CODO_D"]
        muneca = _m["MUNECA_I"] if s < 0 else _m["MUNECA_D"]
        dedos = (Vector((0.55, -0.45, -0.7)) if s < 0 else Vector((0.05, -0.15, -1))).normalized()
        h[P + lado + "Shoulder"] = (_d(0.2 * s, 0, 4.3), hombro, P + "Spine2", True)
        h[P + lado + "Arm"] = (hombro, codo, P + lado + "Shoulder", True)
        h[P + lado + "ForeArm"] = (codo, muneca, P + lado + "Arm", True)
        h[P + lado + "Hand"] = (muneca, muneca + dedos * 0.7, P + lado + "ForeArm", True)
        cadera = Vector((0.3 * s, 0, 2.5))
        rodilla = Vector((0.4 * s, -0.08, 1.3))
        tobillo = Vector((0.46 * s, 0, 0.16))
        h[P + lado + "UpLeg"] = (cadera, rodilla, P + "Hips", True)
        h[P + lado + "Leg"] = (rodilla, tobillo, P + lado + "UpLeg", True)
        h[P + lado + "Foot"] = (tobillo, Vector((0.46 * s, -0.55, 0.06)), P + lado + "Leg", True)
    # La trenza: del chongo a la cintura
    arriba = _cab(0, 0.92, -0.1)
    abajo = doblar(Vector((0, 1.15, 2.85)))
    padre = P + "Head"
    for k in range(6):
        a = arriba.lerp(abajo, k / 6)
        b = arriba.lerp(abajo, (k + 1) / 6)
        h["Trenza_%d" % k] = (a, b, padre, True)
        padre = "Trenza_%d" % k
    # La cola: del ruedo de atras hasta la punta (cuelga del ruedo, no de la cadera: no se hunde)
    padre = "Ruedo"
    for k in range(4):
        a = Vector((0, 1.55 + 0.9 * k, 0.45 * (1 - k / 3.5) ** 2 + 0.04))
        b = Vector((0, 1.55 + 0.9 * (k + 1), 0.45 * (1 - (k + 1) / 3.5) ** 2 + 0.04))
        h["Cola_%d" % k] = (a, b, padre, True)
        padre = "Cola_%d" % k
    # Marcadores (no deforman)
    largo = Vector((0, 0, 0.15))
    mano_d = _m["MUNECA_D"] + Vector((0.05, -0.15, -1)).normalized() * 0.35
    mano_i = _m["MUNECA_I"] + Vector((0.55, -0.45, -0.7)).normalized() * 0.35
    h["Mano_R"] = (mano_d, mano_d + largo, P + "RightHand", False)
    h["Mano_L"] = (mano_i, mano_i + largo, P + "LeftHand", False)
    h["Pie_R"] = (Vector((0.46, -0.2, 0.0)), Vector((0.46, -0.2, 0.15)), P + "RightFoot", False)
    h["Cabeza"] = (_cab(0, 0, 0), _cab(0, 0, 0.15), P + "Head", False)
    h["Trenza_Punta"] = (abajo, abajo - largo, "Trenza_5", False)
    for lado, s in (("L", -1), ("R", 1)):
        h["Arete_" + lado] = (_cab(0.6 * s, -0.02, -0.32), _cab(0.6 * s, -0.02, -0.17), P + "Head", False)
    for i, (ofs, _) in enumerate(_m["FLORES"]):
        h["Flor_%d" % i] = (_cab(*ofs), _cab(*ofs) + largo, P + "Head", False)
    # Las puntas de las flamas de las velas del resplandor (catrina_baja.puntas_velas)
    _b = {"SOLO_FUNCIONES": True, "__name__": "catrina_baja"}
    exec(open(RAIZ + r"\tools\blender\catrina_baja.py", encoding="utf-8").read(), _b)
    for i, p in enumerate(_b["puntas_velas"]()):
        h["Vela_%d" % i] = (p, p + largo, P + "Head", False)
    nudo = doblar(_m["NUDO"] + Vector((0, -0.33, 0)))
    h["Pecho_Nudo"] = (nudo, nudo + largo, P + "Spine2", False)
    return h


def _dist_segmento(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def _pesar(ob, h, candidatos, regla=None):
    """Cada vertice a los dos huesos mas cercanos de `candidatos`, mas pesado el mas cercano.
    regla(p) puede devolver un hueso para forzarlo (rigido)."""
    ob.vertex_groups.clear()
    grupos = {n: ob.vertex_groups.new(name=n) for n in h if h[n][3]}
    for v in ob.data.vertices:
        p = ob.matrix_world @ v.co
        forzado = regla(p) if regla else None
        if forzado:
            grupos[forzado].add([v.index], 1.0, "REPLACE")
            continue
        lista = candidatos(p) if callable(candidatos) else candidatos
        ds = sorted((_dist_segmento(p, h[n][0], h[n][1]), n) for n in lista)
        (d0, n0), (d1, n1) = ds[0], ds[1]
        w0 = 1.0 / max(d0, 0.01) ** 4
        w1 = 1.0 / max(d1, 0.01) ** 4
        grupos[n0].add([v.index], w0 / (w0 + w1), "REPLACE")
        grupos[n1].add([v.index], w1 / (w0 + w1), "REPLACE")


def armar_rig():
    sc = bpy.data.scenes["Catrina"]
    for ventana in bpy.context.window_manager.windows:
        ventana.scene = sc
    vieja = bpy.data.objects.get("Catrina_Rig")
    if vieja:
        bpy.data.objects.remove(vieja, do_unlink=True)
    h = huesos()
    arm = bpy.data.armatures.new("Catrina_Rig")
    rig = bpy.data.objects.new("Catrina_Rig", arm)
    sc.collection.objects.link(rig)
    rig.show_in_front = True
    sc.view_layers[0].objects.active = rig
    for ob in sc.objects:
        ob.select_set(False)
    rig.select_set(True)
    ctx = _a["_m"].get("_contexto_3d") or None
    with bpy.context.temp_override(**_contexto()):
        bpy.ops.object.mode_set(mode="EDIT")
        for n, (a, b, padre, deforma) in h.items():
            e = arm.edit_bones.new(n)
            e.head = a
            e.tail = b
            e.use_deform = deforma
        for n, (a, b, padre, deforma) in h.items():
            if padre:
                arm.edit_bones[n].parent = arm.edit_bones[padre]
        bpy.ops.object.mode_set(mode="OBJECT")
    deforman = [n for n in h if h[n][3]]
    cuerpo = [n for n in deforman if not n.startswith(("Trenza", "Cola"))]
    tronco = [P + n for n in ("Hips", "Spine", "Spine1", "Spine2", "Neck", "LeftShoulder", "RightShoulder", "LeftArm", "RightArm",
                              "LeftUpLeg", "RightUpLeg")]
    cola = ["Cola_%d" % k for k in range(4)] + [P + "Hips"]
    trenza = ["Trenza_%d" % k for k in range(6)]
    falda = [P + "Hips", P + "LeftUpLeg", P + "RightUpLeg"]
    centro_cabeza = mc @ C

    def regla_craneo(p):
        if (p - centro_cabeza).length > 1.1 and p.y > 0.5 and p.z < 5.0:
            return None      # la trenza: por distancia
        return P + "Head"

    def regla_vestido(p):
        return None

    for nombre in MALLAS:
        ob = bpy.data.objects[nombre]
        if nombre == "Craneo":
            _pesar(ob, h, trenza + [P + "Head"], regla_craneo)
        elif nombre.startswith("Vestido"):
            # La cola (atras y en el piso) a sus huesos; lo demas al tronco y los muslos
            ob.vertex_groups.clear()
            # Abajo de la cintura la falda solo sigue a la cadera y los muslos: si la jalaba la
            # espalda, a gatas se doblaba como barril
            _pesar(ob, h, lambda p: (falda + cola[:-1]) if p.z < 2.55 else (tronco + cola[:-1]))
            for v in ob.data.vertices:
                p = ob.matrix_world @ v.co
                if not (p.y > 1.5 and p.z < 0.8):
                    for g in list(ob.vertex_groups):
                        if g.name.startswith("Cola"):
                            g.remove([v.index])
            # Lo que no es cola y quedo sin peso (los que eran cola) se va a la cadera
            caderas = ob.vertex_groups[P + "Hips"]
            for v in ob.data.vertices:
                if sum(g.weight for g in v.groups) < 0.01:
                    caderas.add([v.index], 1.0, "REPLACE")
            _normalizar(ob)
            _al_ruedo(ob, solo_falda=True)
        elif nombre == "Cuerpo":
            _pesar(ob, h, cuerpo)
        else:
            _pesar(ob, h, lambda p: falda if p.z < 2.55 else [P + n for n in ("Hips", "Spine", "Spine1", "Spine2")])
            if nombre == "Carrizo":
                _al_ruedo(ob)
        ob.parent = rig
        ob.matrix_parent_inverse = rig.matrix_world.inverted()
        mod = ob.modifiers.get("Armature") or ob.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
    print("rig listo:", len(h), "huesos,", len(deforman), "deforman")
    return rig


def _al_ruedo(ob, solo_falda=False):
    """Abajo de la cintura, una parte del peso pasa al ruedo segun la altura: 1 en el piso, 0 en
    la cintura. La cola (atras, en el piso) se queda con sus huesos."""
    ruedo = ob.vertex_groups.get("Ruedo") or ob.vertex_groups.new(name="Ruedo")
    for v in ob.data.vertices:
        p = ob.matrix_world @ v.co
        if p.z >= 2.55 or (solo_falda and p.y > 1.5 and p.z < 0.8):
            continue
        t = max(p.z, 0.0) / 2.55
        for g in v.groups:
            if g.group != ruedo.index:
                g.weight *= t
        ruedo.add([v.index], 1.0 - t, "REPLACE")


def _normalizar(ob):
    for v in ob.data.vertices:
        total = sum(g.weight for g in v.groups)
        if total > 0:
            for g in v.groups:
                g.weight /= total


def _contexto():
    for ventana in bpy.context.window_manager.windows:
        for area in ventana.screen.areas:
            if area.type == "VIEW_3D":
                region = next(r for r in area.regions if r.type == "WINDOW")
                return dict(window=ventana, area=area, region=region, screen=ventana.screen)
    return {}


if not globals().get("SOLO_FUNCIONES"):
    armar_rig()
