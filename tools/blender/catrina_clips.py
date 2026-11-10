# La Mojiganga, pasos 3 y 4: las 20 animaciones (docs/prompts/blender_catrina.md, tabla de clips).
# Cada clip es una Action con su nombre, a 30 cuadros por segundo, en su lugar (el juego mueve el
# cuerpo). Las poses se escriben como giros en los ejes del esqueleto (X: adelante/atras, Y: de
# lado, Z: voltear; para un hueso que apunta arriba +X es inclinarse al frente, para uno que
# apunta abajo -X es llevarlo al frente). Todos los huesos que deforman llevan llave en cada cuadro
# clave, asi un clip nunca hereda la pose del anterior. Los tiempos que necesita Catrina.gd son
# los de la tabla (pisoton al 24, agarre 30-40, suelta al 9...).

import bpy
import math
from mathutils import Euler, Vector, Quaternion

P = "mixamorig_"
H, S0, S1, S2, CU, CA = P + "Hips", P + "Spine", P + "Spine1", P + "Spine2", P + "Neck", P + "Head"
BD, AD, MD = P + "RightArm", P + "RightForeArm", P + "RightHand"
BI, AI, MI = P + "LeftArm", P + "LeftForeArm", P + "LeftHand"
HD, HI = P + "RightShoulder", P + "LeftShoulder"
PD, RD, FD = P + "RightUpLeg", P + "RightLeg", P + "RightFoot"
PI_, RI, FI = P + "LeftUpLeg", P + "LeftLeg", P + "LeftFoot"
TR = ["Trenza_%d" % k for k in range(6)]
CO = ["Cola_%d" % k for k in range(4)]


def ola(huesos, fase, amp, eje=0):
    """Una onda que recorre una cadena (trenza, cola)."""
    out = {}
    for k, h in enumerate(huesos):
        r = [0, 0, 0]
        r[eje] = amp * math.sin(fase - k * 0.9)
        out[h] = tuple(r)
    return out


def junta(*dicts):
    out = {}
    for d in dicts:
        out.update(d)
    return out


# Poses que se repiten
RODILLAS = {H: {"loc": (0, 0, -1.4)}, PD: (-80, 0, 0), PI_: (-80, 0, 0), RD: (100, 0, 0), RI: (100, 0, 0),
            S0: (12, 0, 0), S1: (6, 0, 0), CA: (18, 0, 0), BD: (-10, 0, 0)}
# A gatas sin la cabeza (fase 3): se dobla de la espalda, no de la cadera, asi la falda se queda
# en el piso (girando la cadera la falda se levantaba como cola)
GATAS = {H: {"loc": (0, 0, -1.05)}, PD: (-80, 0, 0), PI_: (-80, 0, 0), RD: (100, 0, 0), RI: (100, 0, 0),
         S0: (35, 0, 0), S1: (30, 0, 0), S2: (20, 0, 0), CU: (-35, 0, 0), CA: (-30, 0, 0), BD: (-75, 0, 0), BI: (-70, 30, 20)}
SOSTIENE = {BD: (-105, 0, -10), AD: (-15, 0, 0), S1: (-4, 0, 0), CA: (8, -10, 0)}

CLIPS = {
    "Idle_Pose": (60, True, {
        0: junta({S1: (0, 0, -2), CA: (0, 0, 3)}, ola(TR, 0, 4), ola(CO, 0, 2)),
        30: junta({S1: (0, 0, 2), CA: (0, 0, -3)}, ola(TR, math.pi, 4), ola(CO, math.pi, 2)),
        60: junta({S1: (0, 0, -2), CA: (0, 0, 3)}, ola(TR, 0, 4), ola(CO, 0, 2)),
    }),
    "Walk": (48, True, {
        0: junta({H: {"rot": (0, 0, 6), "loc": (0, 0, 0)}, PD: (-18, 0, 0), PI_: (14, 0, 0), RI: (10, 0, 0), BD: (12, 0, 0), S1: (0, 0, -4)},
                 ola(TR, 0, 6), ola(CO, 0, 4, 2)),
        12: junta({H: {"rot": (0, 0, 0), "loc": (0, 0, 0.05)}, PD: (0, 0, 0), PI_: (0, 0, 0), RD: (20, 0, 0)}, ola(TR, 1.5, 6), ola(CO, 1.5, 4, 2)),
        24: junta({H: {"rot": (0, 0, -6), "loc": (0, 0, 0)}, PD: (14, 0, 0), PI_: (-18, 0, 0), RD: (10, 0, 0), BD: (-12, 0, 0), S1: (0, 0, 4)},
                  ola(TR, math.pi, 6), ola(CO, math.pi, 4, 2)),
        36: junta({H: {"rot": (0, 0, 0), "loc": (0, 0, 0.05)}, PD: (0, 0, 0), PI_: (0, 0, 0), RI: (20, 0, 0)}, ola(TR, 4.6, 6), ola(CO, 4.6, 4, 2)),
        48: junta({H: {"rot": (0, 0, 6), "loc": (0, 0, 0)}, PD: (-18, 0, 0), PI_: (14, 0, 0), RI: (10, 0, 0), BD: (12, 0, 0), S1: (0, 0, -4)},
                  ola(TR, 0, 6), ola(CO, 0, 4, 2)),
    }),
    "Stomp": (51, False, {
        0: {},
        6: {PD: (-65, 0, 0), RD: (45, 0, 0), S0: (-8, 0, 0), BD: (-20, -25, 0), CA: (10, 0, 0)},
        21: {PD: (-70, 0, 0), RD: (40, 0, 0), S0: (-10, 0, 0), BD: (-25, -30, 0), CA: (12, 0, 0)},
        24: {PD: (-5, 0, 0), RD: (5, 0, 0), S0: (12, 0, 0), S1: (6, 0, 0), BD: (10, -10, 0), CA: (-5, 0, 0), H: {"loc": (0, 0, -0.12)}},
        32: {PD: (-5, 0, 0), S0: (8, 0, 0), H: {"loc": (0, 0, -0.08)}},
        51: {},
    }),
    "Grab_Reach": (69, False, {
        0: {},
        30: {S0: (22, 0, 0), S1: (20, 0, 0), S2: (15, 0, 0), BD: (10, -15, 0), AD: (-20, 0, 0), CA: (-20, 0, 0)},
        35: {S0: (25, 0, 0), S1: (24, 0, 0), S2: (18, 0, 0), BD: (-70, -10, 0), CA: (-25, 0, 0)},
        40: {S0: (24, 0, 0), S1: (22, 0, 0), S2: (16, 0, 0), BD: (-118, 10, 20), AD: (-10, 0, 0), CA: (-25, 0, 0)},
        52: {S0: (14, 0, 0), S1: (10, 0, 0), BD: (-80, 0, 10)},
        69: {},
    }),
    "Grab_Hold": (30, True, {
        0: SOSTIENE,
        8: junta(SOSTIENE, {AD: (-25, 0, 0), S1: (-6, 0, 0)}),
        15: SOSTIENE,
        23: junta(SOSTIENE, {AD: (-25, 0, 0), S1: (-6, 0, 0)}),
        30: SOSTIENE,
    }),
    "Throw": (30, False, {
        0: SOSTIENE,
        5: {BD: (-100, 0, -50), S1: (0, 0, -20), CA: (0, 0, -10)},
        9: {BD: (-80, 0, 70), S1: (0, 0, 25), S0: (10, 0, 0)},
        18: {BD: (-40, 0, 80), S1: (0, 0, 10)},
        30: {},
    }),
    "Grab_Escape": (39, False, {
        0: SOSTIENE,
        4: {BD: (-80, 0, 15), AD: (-30, 0, 0), CA: (10, 0, 15)},
        8: {BD: (-95, 0, -15), AD: (-5, 0, 0), CA: (10, 0, -15)},
        12: {BD: (-75, 0, 15), AD: (-30, 0, 0), CA: (10, 0, 15)},
        18: {BD: (-60, 0, -10), CA: (5, 0, -10)},
        39: {},
    }),
    "Braid_Whip": (45, False, None),   # se arma en _latigo(): la onda baja por la trenza
    "Kneel_Stagger": (24, False, {
        0: {},
        8: {S0: (-10, 0, 0), CA: (-15, 0, 0), BD: (-30, -30, 0), H: {"loc": (0, 0, -0.3)}},
        18: RODILLAS,
        24: junta(RODILLAS, {CA: (24, 0, 0)}),
    }),
    "Kneel_Idle": (40, True, {
        0: junta(RODILLAS, {S1: (6, 0, -3), CA: (20, 0, 4)}),
        20: junta(RODILLAS, {S1: (10, 0, 3), CA: (24, 0, -4)}),
        40: junta(RODILLAS, {S1: (6, 0, -3), CA: (20, 0, 4)}),
    }),
    "Rise": (30, False, {
        0: RODILLAS,
        15: {H: {"loc": (0, 0, -0.6)}, PD: (-40, 0, 0), PI_: (-40, 0, 0), RD: (50, 0, 0), RI: (50, 0, 0), S0: (15, 0, 0)},
        30: {},
    }),
    "Death": (75, False, {
        0: {},
        10: {CA: (-30, 0, 0), S0: (-12, 0, 0), BD: (-40, -40, 0)},
        20: RODILLAS,
        40: junta(RODILLAS, {S0: (40, 0, 0), S1: (25, 0, 0), CA: (30, 0, 15), H: {"loc": (0, 0, -1.6)}}),
        60: junta(RODILLAS, {S0: (60, 0, 0), S1: (30, 0, 0), S2: (20, 0, 0), CA: (40, 0, 25), BD: (-60, 0, 30), H: {"loc": (0, 0, -2.1)}}),
        75: junta(RODILLAS, {S0: (62, 0, 0), S1: (30, 0, 0), S2: (20, 0, 0), CA: (42, 0, 25), BD: (-60, 0, 30), H: {"loc": (0, 0, -2.15)}}),
    }),
    # --- Lote 2: fases 2 y 3 ---
    "Tear_Roar": (75, False, {
        0: {},
        15: {S0: (-15, 0, 0), S1: (-10, 0, 0), CA: (-30, 0, 0), BD: (-110, -40, 0), BI: (-110, 40, 0), AI: (0, 0, 0)},
        25: {S0: (-18, 0, 4), S1: (-12, 0, 0), CA: (-35, 0, 6), BD: (-120, -45, 0), BI: (-120, 45, 0)},
        35: {S0: (-18, 0, -4), S1: (-12, 0, 0), CA: (-35, 0, -6), BD: (-115, -40, 0), BI: (-115, 40, 0)},
        45: {S0: (-18, 0, 4), S1: (-12, 0, 0), CA: (-35, 0, 6), BD: (-120, -45, 0), BI: (-120, 45, 0)},
        60: {S0: (5, 0, 0), CA: (10, 0, 0), BD: (-20, -10, 0)},
        75: {},
    }),
    "Skirt_Spin": (60, False, {
        0: {},
        9: {H: {"rot": (0, 0, 10)}, BD: (0, -50, 0), BI: (0, 50, 0)},
        18: {H: {"rot": (0, 0, -10)}, BD: (0, -60, 0), BI: (0, 60, 0)},
        27: {H: {"rot": (0, 0, 0)}, BD: (0, -75, 0), BI: (0, 75, 0)},
        36: {H: {"rot": (0, 0, 360)}, BD: (0, -80, 0), BI: (0, 80, 0)},
        45: {H: {"rot": (0, 0, 720)}, BD: (0, -75, 0), BI: (0, 75, 0)},
        60: {H: {"rot": (0, 0, 720)}},
    }),
    "Earrings_Snap": (36, False, {
        0: {},
        12: {CA: (30, 0, 0), CU: (15, 0, 0), S1: (8, 0, 0)},
        15: {CA: (30, 0, 20), CU: (15, 0, 0), S1: (8, 0, 0)},
        18: {CA: (30, 0, -20), CU: (15, 0, 0), S1: (8, 0, 0)},
        22: {CA: (25, 0, 10), CU: (10, 0, 0)},
        36: {},
    }),
    "Scream": (60, False, {
        0: {},
        16: {CA: (20, 0, 0), S1: (10, 0, 0)},
        24: {CA: (-38, 0, 0), CU: (-15, 0, 0), S1: (-10, 0, 0), BD: (-60, -40, 0), BI: (-60, 40, 0)},
        40: {CA: (-34, 0, 0), CU: (-12, 0, 0), S1: (-8, 0, 0), BD: (-55, -35, 0), BI: (-55, 35, 0)},
        60: {},
    }),
    "Head_Fall": (75, False, {
        0: {},
        15: {CA: (35, 0, 30), CU: (20, 0, 10)},
        25: {CA: (60, 0, 40), CU: (30, 0, 10), S0: (10, 0, 0)},
        45: GATAS,
        75: GATAS,
    }),
    "Crawl": (40, True, {
        0: junta(GATAS, {BD: (-95, 0, 0), BI: (-60, 30, 20), H: {"rot": (0, 0, 4), "loc": (0, 0, -1.05)}}, ola(CO, 0, 6, 2)),
        20: junta(GATAS, {BD: (-60, 0, 0), BI: (-95, 30, 20), H: {"rot": (0, 0, -4), "loc": (0, 0, -1.0)}}, ola(CO, math.pi, 6, 2)),
        40: junta(GATAS, {BD: (-95, 0, 0), BI: (-60, 30, 20), H: {"rot": (0, 0, 4), "loc": (0, 0, -1.05)}}, ola(CO, 0, 6, 2)),
    }),
    "Crawl_Slam": (45, False, {
        0: GATAS,
        18: junta(GATAS, {BD: (-185, 0, 0), S1: (15, 0, 0), CA: (-45, 0, 0)}),
        24: junta(GATAS, {BD: (-55, 0, 0), S1: (36, 0, 0), CA: (-20, 0, 0)}),
        45: GATAS,
    }),
    "Crawl_Lunge": (48, False, {
        0: GATAS,
        18: junta(GATAS, {H: {"loc": (0, 0.6, -1.15)}, S0: (45, 0, 0), BD: (-50, 0, 0), BI: (-50, 30, 20)}),
        25: junta(GATAS, {H: {"loc": (0, -0.5, -0.9)}, S0: (25, 0, 0), BD: (-130, 0, 0), BI: (-130, 30, 20), CA: (-45, 0, 0)}),
        33: junta(GATAS, {H: {"loc": (0, -0.4, -1.0)}, BD: (-100, 0, 0), BI: (-100, 30, 20)}),
        48: GATAS,
    }),
}


def _latigo():
    """El latigazo de la trenza: cada hueso sigue la misma curva un poco despues que el de arriba
    (1.5 cuadros), asi el golpe viaja hasta la punta. Hacia atras hasta el 18 (preparacion), al
    frente sobre el hombro 21-28 (el golpe, TRENZA_PEGA), se pasa, rebota y se asienta al 45."""
    curva = [(0, 0), (18, 38), (21, 10), (24, -38), (27, -46), (31, 12), (36, -6), (45, 0)]

    def angulo(t):
        if t <= curva[0][0]:
            return curva[0][1]
        for (t0, a0), (t1, a1) in zip(curva, curva[1:]):
            if t <= t1:
                u = (t - t0) / (t1 - t0)
                u = u * u * (3 - 2 * u)
                return a0 + (a1 - a0) * u
        return curva[-1][1]
    llaves = {}
    for f in range(0, 46, 3):
        pose = {t: (angulo(f - 1.5 * k), 0, 6 * math.sin(f * 0.3)) for k, t in enumerate(TR)}
        cabeza_z = 30 * min(f / 21, 1) if f <= 21 else 30 - 45 * min((f - 21) / 7, 1) if f <= 28 else -15 * (1 - (f - 28) / 17)
        pose[CA] = (-15 if f <= 21 else 20 if f <= 30 else 5, 0, cabeza_z)
        pose[S1] = (0 if f <= 21 else 9, 0, 10 if f <= 21 else -7)
        llaves[f] = pose
    llaves[45] = {}
    return llaves


CLIPS["Braid_Whip"] = (45, False, _latigo())


def _local(pb, rot_grados, loc):
    m = pb.bone.matrix_local.to_3x3()
    r = Euler([math.radians(a) for a in rot_grados], "XYZ").to_matrix()
    q = (m.inverted() @ r @ m).to_quaternion()
    l = m.inverted() @ Vector(loc)
    return q, l


def armar_clips(solo=None):
    sc = bpy.data.scenes["Catrina"]
    sc.render.fps = 30
    rig = bpy.data.objects["Catrina_Rig"]
    rig.animation_data_create()
    deforman = [pb for pb in rig.pose.bones if pb.bone.use_deform]
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    hechas = []
    for nombre, (cuadros, bucle, llaves) in CLIPS.items():
        if solo and nombre not in solo:
            continue
        vieja = bpy.data.actions.get(nombre)
        if vieja:
            bpy.data.actions.remove(vieja)
        accion = bpy.data.actions.new(nombre)
        accion.use_fake_user = True
        rig.animation_data.action = accion
        for cuadro, pose in sorted(llaves.items()):
            for pb in deforman:
                valor = pose.get(pb.name, (0, 0, 0))
                if isinstance(valor, dict):
                    rot, loc = valor.get("rot", (0, 0, 0)), valor.get("loc", (0, 0, 0))
                else:
                    rot, loc = valor, (0, 0, 0)
                # Los giros de 360 en adelante: en cuaterniones se pierden; la Z de la cadera se
                # pasa en pasos de 120 entre llaves (_vueltas abajo)
                q, l = _local(pb, rot, loc)
                pb.rotation_quaternion = q
                pb.location = l
                pb.keyframe_insert("rotation_quaternion", frame=cuadro)
                pb.keyframe_insert("location", frame=cuadro)
        _vueltas(rig, accion, nombre, llaves)
        accion.frame_range = (0, cuadros)
        hechas.append(nombre)
    # El reposo de exhibicion
    rig.animation_data.action = bpy.data.actions.get("Idle_Pose")
    sc.frame_start = 0
    sc.frame_end = 60
    print("clips:", len(hechas), hechas)


def _vueltas(rig, accion, nombre, llaves):
    """El giro de la falda (720 grados): llaves intermedias cada 90 grados para que el
    cuaternion no tome el camino corto."""
    if nombre != "Skirt_Spin":
        return
    pb = rig.pose.bones[H]
    for c0, c1, a0, a1 in ((27, 36, 0, 360), (36, 45, 360, 720)):
        for k in range(1, 4):
            t = k / 4
            cuadro = c0 + (c1 - c0) * t
            q, l = _local(pb, (0, 0, a0 + (a1 - a0) * t), (0, 0, 0))
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=cuadro)


if not globals().get("SOLO_FUNCIONES"):
    armar_clips()
