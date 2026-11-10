# La Mojiganga, pasos 3 y 4: las 20 animaciones (docs/prompts/blender_catrina.md, tabla de clips).
# Cada clip es una Action con su nombre, a 30 cuadros por segundo, en su lugar (el juego mueve el
# cuerpo). Las poses se escriben como giros en los ejes del esqueleto (X: adelante/atras, Y: de
# lado, Z: voltear; para un hueso que apunta arriba +X es inclinarse al frente, para uno que
# apunta abajo -X es llevarlo al frente). Los tiempos que necesita Catrina.gd son los de la tabla
# (pisoton al 24, agarre 30-42, suelta al 9...).
#
# Segunda pasada (AG, 2026-11-10: "no me gustan las animaciones", tiesas, la caminata se desliza,
# no se leen los ataques): cada clip se muestrea cuadro por cuadro en vez de dejar que Blender
# junte poses clave, asi:
#   - cada tramo entre llaves lleva su curva (_c en la llave de llegada): "golpe" acelera hacia la
#     llave (el pisoton cae), "suelta" frena al llegar (el cuerpo se asienta), "quieto" se queda en
#     la pose anterior (amago colgado) y por defecto entra y sale suave;
#   - los huesos de una cadena llegan tarde (RETRASO: la espalda, el cuello y la cabeza tras la
#     cadera, el antebrazo y la mano tras el brazo, la cola de la falda): el movimiento se pasa de
#     hueso en hueso en vez de moverse todo de golpe;
#   - capas que se suman encima (CAPAS): respirar, temblar, el tic de titere del reposo, el meneo
#     del ruedo al caminar.
# La trenza y la cola ademas rebotan en Godot (SpringBoneSimulator3D en Catrina.gd).

import bpy
import math
from mathutils import Euler, Vector

P = "mixamorig_"
H, S0, S1, S2, CU, CA = P + "Hips", P + "Spine", P + "Spine1", P + "Spine2", P + "Neck", P + "Head"
BD, AD, MD = P + "RightArm", P + "RightForeArm", P + "RightHand"
BI, AI, MI = P + "LeftArm", P + "LeftForeArm", P + "LeftHand"
HD, HI = P + "RightShoulder", P + "LeftShoulder"
PD, RD, FD = P + "RightUpLeg", P + "RightLeg", P + "RightFoot"
PI_, RI, FI = P + "LeftUpLeg", P + "LeftLeg", P + "LeftFoot"
RU = "Ruedo"
TR = ["Trenza_%d" % k for k in range(6)]
CO = ["Cola_%d" % k for k in range(4)]

# Cuadros que llega tarde cada hueso (se pasa el movimiento por la cadena)
RETRASO = {S1: 1, S2: 2, CU: 3, CA: 4, HD: 1, HI: 1, AD: 2, MD: 4, AI: 2, MI: 4,
           RD: 1, RI: 1, FD: 2, FI: 2, CO[0]: 2, CO[1]: 4, CO[2]: 6, CO[3]: 8}


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


def c(pose, curva):
    """La pose con la curva del tramo que llega a ella."""
    return junta(pose, {"_c": curva})


# Poses que se repiten
RODILLAS = {H: {"loc": (0, 0, -1.4)}, PD: (-80, 0, 0), PI_: (-80, 0, 0), RD: (100, 0, 0), RI: (100, 0, 0),
            S0: (12, 0, 0), S1: (6, 0, 0), CA: (18, 0, 0), BD: (-10, 0, 0)}
# De rodillas, con los brazos apoyados en el piso (temblando)
APOYADA = junta(RODILLAS, {S0: (22, 0, 0), S1: (14, 0, 0), S2: (8, 0, 0), CA: (26, 0, 0),
                           BD: (-38, -12, 0), AD: (-20, 0, 0), BI: (-38, 12, 0), AI: (-20, 0, 0)})
# A gatas sin la cabeza (fase 3): se dobla de la espalda, no de la cadera, asi la falda se queda
# en el piso. La espalda jorobada sobre el nudo y el cuello (sin cabeza) colgando
GATAS = {H: {"loc": (0, 0, -1.05)}, PD: (-80, 0, 0), PI_: (-80, 0, 0), RD: (100, 0, 0), RI: (100, 0, 0),
         S0: (38, 0, 0), S1: (34, 0, 0), S2: (22, 0, 0), CU: (-20, 0, 0), CA: (-20, 0, 0),
         BD: (-80, 0, 8), AD: (-15, 0, 0), BI: (-80, 0, -8), AI: (-15, 0, 0)}
SOSTIENE = {BD: (-108, 0, -10), AD: (-18, 0, 0), S0: (-4, 0, 0), S1: (-6, 0, 0), CA: (10, -10, 0), BI: (-15, 10, 0)}


def _paso(lado, alto):
    """Una pose de la caminata pesada: lado +1 = pie derecho al frente (contacto), 0 = paso por
    abajo; alto = cuanto sube la cadera."""
    return {
        H: {"rot": (0, 6 * lado, 10 * lado), "loc": (0.12 * lado, 0, alto)},
        PD: (-22 * lado, 0, 0), PI_: (18 * lado, 0, 0),
        RD: (8 + 14 * max(-lado, 0), 0, 0), RI: (8 + 14 * max(lado, 0), 0, 0),
        # Los hombros al reves que la cadera y la cabeza derecha
        S0: (6, -3 * lado, -4 * lado), S1: (3, -2 * lado, -7 * lado), S2: (0, -3 * lado, -4 * lado), CA: (-4, 6 * lado, 6 * lado),
        BD: (16 * lado, -6, 0), AD: (-10 - 8 * max(lado, 0), 0, 0), BI: (-16 * lado, 6, 0), AI: (-10 - 8 * max(-lado, 0), 0, 0),
        RU: {"rot": (0, 0, 2.5 * lado), "loc": (0.04 * lado, 0, 0)},
    }


def _pasando(lado):
    """El cuerpo pasando sobre el pie de apoyo: arriba, sin giro."""
    return {
        H: {"rot": (0, -1.5 * lado, 0), "loc": (-0.03 * lado, 0, 0.1)},
        PD: (-4 if lado > 0 else 6, 0, 0), PI_: (6 if lado > 0 else -4, 0, 0),
        RD: (4 if lado > 0 else 30, 0, 0), RI: (30 if lado > 0 else 4, 0, 0),
        S0: (5, 0, 0), S1: (2, 0, 0), CA: (-2, 0, 0),
        BD: (0, -6, 0), AD: (-14, 0, 0), BI: (0, 6, 0), AI: (-14, 0, 0),
        RU: {"rot": (0, 0, 0), "loc": (0, 0, 0)},
    }


CLIPS = {
    # Reposo de 4 s: respira, mueve el peso de pie a pie; el tic de titere va en CAPAS
    "Idle_Pose": (120, True, {
        0: {H: {"rot": (0, 2, 0), "loc": (0.04, 0, 0)}, S1: (2, 0, -2), CA: (6, 4, 3), BD: (-6, -4, 0), AD: (-12, 0, 0), BI: (-4, 4, 0), AI: (-10, 0, 0)},
        60: {H: {"rot": (0, -2, 0), "loc": (-0.04, 0, -0.02)}, S1: (3, 0, 2), CA: (9, -4, -3), BD: (-4, -4, 0), AD: (-10, 0, 0), BI: (-6, 4, 0), AI: (-12, 0, 0)},
        120: {H: {"rot": (0, 2, 0), "loc": (0.04, 0, 0)}, S1: (2, 0, -2), CA: (6, 4, 3), BD: (-6, -4, 0), AD: (-12, 0, 0), BI: (-4, 4, 0), AI: (-10, 0, 0)},
    }),
    # Caminata de gigante: dos pasos en 48 cuadros (1.6 s, ~1.6 m cada uno a CAMINA 2 m/s); la
    # cadera cae en el contacto y sube al pasar, los hombros contra la cadera, la cabeza fija
    "Walk": (48, True, {
        0: _paso(1, -0.12),
        4: c(junta(_paso(1, -0.2), {S0: (9, 0, -3)}), "suelta"),
        12: _pasando(1),
        24: _paso(-1, -0.12),
        28: c(junta(_paso(-1, -0.2), {S0: (9, 0, 3)}), "suelta"),
        36: _pasando(-1),
        48: _paso(1, -0.12),
    }),
    # Pisoton (pega al 24): se agacha tantito, sube la rodilla muy alto echandose para atras, la
    # deja colgada temblando, cae acelerando con todo el cuerpo y se pasa de largo al aplastar
    "Stomp": (51, False, {
        0: {},
        4: {H: {"loc": (0, 0, -0.1)}, S0: (8, 0, 0), CA: (6, 0, 0), BD: (-8, -10, 0)},
        13: c({H: {"loc": (0, 0, 0.12), "rot": (0, -4, 0)}, PD: (-88, 0, 0), RD: (70, 0, 0), S0: (-14, 0, 0), S1: (-6, 0, 0),
               BD: (-35, -40, 0), AD: (-30, 0, 0), BI: (-20, 30, 0), CA: (16, 0, 0), RU: {"rot": (0, 0, -2)}}, "suelta"),
        20: {H: {"loc": (0, 0, 0.15), "rot": (0, -5, 0)}, PD: (-92, 0, 0), RD: (66, 0, 0), S0: (-16, 0, 0), S1: (-7, 0, 0),
             BD: (-40, -44, 0), AD: (-32, 0, 0), BI: (-22, 32, 0), CA: (18, 0, 0)},
        24: c({H: {"loc": (0, 0, -0.3), "rot": (0, 3, 0)}, PD: (-4, 0, 0), RD: (6, 0, 0), S0: (16, 0, 0), S1: (10, 0, 0), S2: (6, 0, 0),
               BD: (18, -12, 0), AD: (-8, 0, 0), BI: (10, 14, 0), CA: (-8, 0, 0), RU: {"loc": (0, 0, -0.03)}}, "golpe"),
        28: c({H: {"loc": (0, 0, -0.38)}, PD: (-6, 0, 0), RD: (10, 0, 0), S0: (22, 0, 0), S1: (14, 0, 0), S2: (8, 0, 0),
               BD: (24, -10, 0), BI: (14, 12, 0), CA: (-12, 0, 0)}, "suelta"),
        38: {H: {"loc": (0, 0, -0.16)}, PD: (-4, 0, 0), S0: (10, 0, 0), S1: (5, 0, 0), CA: (2, 0, 0)},
        51: {},
    }),
    # Agarron (avisa hasta el 30, la mano barre 30-42): se tuerce y echa el brazo atras y arriba
    # con la mano abierta, se encoge un instante y se lanza al frente y abajo; se pasa y se queda
    # doblada (las flores bajas: la ventana del machete) antes de enderezarse
    "Grab_Reach": (69, False, {
        0: {},
        8: {S0: (-6, 0, 10), S1: (-4, 0, 8), BD: (30, -30, -20), AD: (-25, 0, 0), CA: (4, 0, -10)},
        24: c({H: {"rot": (0, 0, 14), "loc": (0, 0, -0.1)}, S0: (-12, 0, 18), S1: (-8, 0, 14), S2: (-4, 0, 8),
               BD: (60, -70, -30), AD: (-40, 0, 0), MD: (-30, 0, 0), BI: (-30, 30, 0), CA: (10, 0, -16)}, "suelta"),
        30: {H: {"rot": (0, 0, 16), "loc": (0, 0, -0.16)}, S0: (-14, 0, 20), S1: (-10, 0, 16), S2: (-5, 0, 9),
             BD: (66, -74, -32), AD: (-44, 0, 0), MD: (-34, 0, 0), BI: (-34, 32, 0), CA: (12, 0, -18)},
        36: c({H: {"rot": (0, 0, -6), "loc": (0, 0, -0.2)}, S0: (24, 0, -6), S1: (22, 0, -4), S2: (16, 0, 0),
               BD: (-80, -10, 0), AD: (-14, 0, 0), MD: (10, 0, 0), BI: (-10, 20, 0), CA: (-26, 0, 0)}, "golpe"),
        41: c({H: {"rot": (0, 0, -10), "loc": (0, 0, -0.26)}, S0: (30, 0, -8), S1: (26, 0, -6), S2: (18, 0, 0),
               BD: (-122, 10, 22), AD: (-6, 0, 0), MD: (14, 0, 0), BI: (-4, 24, 0), CA: (-28, 0, 0)}, "lineal"),
        46: c({H: {"rot": (0, 0, -8), "loc": (0, 0, -0.3)}, S0: (32, 0, -6), S1: (28, 0, -4), S2: (20, 0, 0),
               BD: (-110, 6, 18), AD: (-10, 0, 0), BI: (-8, 24, 0), CA: (-24, 0, 0)}, "suelta"),
        58: {S0: (20, 0, -2), S1: (14, 0, 0), S2: (8, 0, 0), BD: (-60, 0, 8), AD: (-14, 0, 0), CA: (-8, 0, 0), H: {"loc": (0, 0, -0.12)}},
        69: {},
    }),
    # Te tiene en el puno frente a la cara: aprieta cada 15 cuadros (APRIETA_CADA 0.5 s)
    "Grab_Hold": (30, True, {
        0: SOSTIENE,
        5: c(junta(SOSTIENE, {AD: (-30, 0, 0), MD: (-14, 0, 0), S1: (-9, 0, 2), CA: (16, -10, 0)}), "golpe"),
        15: c(SOSTIENE, "suelta"),
        20: c(junta(SOSTIENE, {AD: (-30, 0, 0), MD: (-14, 0, 0), S1: (-9, 0, -2), CA: (16, -10, 0)}), "golpe"),
        30: c(SOSTIENE, "suelta"),
    }),
    # Aventon (suelta al 9): se tuerce para atras cargando, gira de golpe y se pasa
    "Throw": (30, False, {
        0: SOSTIENE,
        5: c({BD: (-100, 0, -60), AD: (-30, 0, 0), S0: (-4, 0, -16), S1: (0, 0, -24), CA: (0, 0, -14), H: {"rot": (0, 0, -10)}}, "suelta"),
        9: c({BD: (-80, 0, 75), AD: (-4, 0, 0), S0: (12, 0, 18), S1: (4, 0, 28), CA: (-4, 0, 16), H: {"rot": (0, 0, 14)}}, "golpe"),
        14: c({BD: (-40, 0, 90), S0: (14, 0, 22), S1: (4, 0, 30), CA: (-2, 0, 18), H: {"rot": (0, 0, 16)}}, "suelta"),
        30: {},
    }),
    # Te zafaste: sacude la mano como quemada y se tambalea
    "Grab_Escape": (39, False, {
        0: SOSTIENE,
        4: {BD: (-80, 0, 20), AD: (-36, 0, 0), MD: (-30, 0, 0), CA: (12, 0, 18), S0: (-8, 0, 0)},
        8: {BD: (-96, 0, -20), AD: (-4, 0, 0), MD: (24, 0, 0), CA: (12, 0, -18), S0: (-10, 0, 0)},
        12: {BD: (-74, 0, 20), AD: (-36, 0, 0), MD: (-30, 0, 0), CA: (12, 0, 18), S0: (-8, 0, 0)},
        16: {BD: (-88, 0, -14), AD: (-10, 0, 0), CA: (10, 0, -12)},
        24: c({BD: (-40, 0, -6), S0: (-6, 0, 4), H: {"loc": (0, 0, -0.1), "rot": (0, 4, 0)}, CA: (6, 0, -8)}, "suelta"),
        39: {},
    }),
    "Braid_Whip": (45, False, None),   # se arma en _latigo(): la onda baja por la trenza
    # Se le doblan las rodillas (de rodillas al 18): cae de golpe, rebota y se queda apoyada
    "Kneel_Stagger": (24, False, {
        0: {},
        5: {S0: (-12, 0, 6), CA: (-20, 0, 8), BD: (-34, -34, 0), BI: (-20, 30, 0), H: {"loc": (0, 0, -0.25)}},
        14: c(junta(APOYADA, {H: {"loc": (0, 0, -1.5)}, S0: (28, 0, 0)}), "golpe"),
        18: c(APOYADA, "suelta"),
        24: junta(APOYADA, {CA: (30, 0, -4)}),
    }),
    # De rodillas: apoyada en los brazos, jadeando (y temblando: CAPAS)
    "Kneel_Idle": (40, True, {
        0: junta(APOYADA, {S1: (12, 0, -3), CA: (26, 0, 4)}),
        20: junta(APOYADA, {S1: (18, 0, 3), S2: (12, 0, 0), CA: (32, 0, -4), H: {"loc": (0, 0, -1.46)}}),
        40: junta(APOYADA, {S1: (12, 0, -3), CA: (26, 0, 4)}),
    }),
    # Se levanta: empuja con los brazos, la cabeza la ultima
    "Rise": (30, False, {
        0: APOYADA,
        10: c(junta(APOYADA, {H: {"loc": (0, 0, -1.2)}, BD: (-50, -12, 0), BI: (-50, 12, 0), S0: (26, 0, 0)}), "suelta"),
        20: {H: {"loc": (0, 0, -0.45)}, PD: (-36, 0, 0), PI_: (-36, 0, 0), RD: (46, 0, 0), RI: (46, 0, 0), S0: (14, 0, 0), CA: (20, 0, 0)},
        30: c({CA: (4, 0, 0)}, "suelta"),
    }),
    # Muere: se le doblan las canas, se va de lado y se dobla al frente (en el piso al 60)
    "Death": (75, False, {
        0: {},
        8: {CA: (-34, 0, 10), S0: (-14, 0, 6), BD: (-50, -44, 0), BI: (-30, 40, 0)},
        20: c(junta(RODILLAS, {S0: (6, 0, -10), CA: (10, 0, -20)}), "golpe"),
        26: c(junta(RODILLAS, {S0: (16, 0, -6), CA: (24, 0, -14)}), "suelta"),
        42: junta(RODILLAS, {S0: (40, 0, 8), S1: (25, 0, 6), CA: (30, 0, 15), H: {"loc": (0, 0, -1.6)}}),
        60: c(junta(RODILLAS, {S0: (64, 0, 10), S1: (32, 0, 6), S2: (22, 0, 0), CA: (44, 0, 25), BD: (-62, 0, 30), BI: (-40, 0, -20), H: {"loc": (0, 0, -2.15)}}), "golpe"),
        64: junta(RODILLAS, {S0: (60, 0, 10), S1: (30, 0, 6), S2: (20, 0, 0), CA: (40, 0, 25), BD: (-60, 0, 30), BI: (-40, 0, -20), H: {"loc": (0, 0, -2.08)}}),
        75: junta(RODILLAS, {S0: (62, 0, 10), S1: (30, 0, 6), S2: (20, 0, 0), CA: (42, 0, 25), BD: (-60, 0, 30), BI: (-40, 0, -20), H: {"loc": (0, 0, -2.12)}}),
    }),
    # --- Lote 2: fases 2 y 3 ---
    # Se rompe el vestido: se encoge, se arquea para atras con los brazos arriba y ruge temblando
    "Tear_Roar": (75, False, {
        0: {},
        8: c({S0: (14, 0, 0), S1: (10, 0, 0), CA: (24, 0, 0), BD: (-10, 20, 0), BI: (-10, -20, 0), H: {"loc": (0, 0, -0.2)}}, "suelta"),
        15: c({S0: (-18, 0, 0), S1: (-12, 0, 0), S2: (-8, 0, 0), CA: (-36, 0, 0), BD: (-118, -42, 0), BI: (-118, 42, 0), H: {"loc": (0, 0, 0.1)}}, "golpe"),
        25: {S0: (-18, 0, 4), S1: (-12, 0, 0), CA: (-38, 0, 6), BD: (-122, -46, 0), BI: (-122, 46, 0)},
        35: {S0: (-18, 0, -4), S1: (-12, 0, 0), CA: (-38, 0, -6), BD: (-116, -40, 0), BI: (-116, 40, 0)},
        45: {S0: (-18, 0, 4), S1: (-12, 0, 0), CA: (-38, 0, 6), BD: (-122, -46, 0), BI: (-122, 46, 0)},
        58: c({S0: (8, 0, 0), CA: (14, 0, 0), BD: (-20, -10, 0), BI: (-16, 10, 0), H: {"loc": (0, 0, -0.08)}}, "suelta"),
        75: {},
    }),
    # Barrida (gira 27-45): se tuerce al reves para cargar con los brazos abiertos, da dos vueltas
    # y se queda mareada, tambaleandose
    "Skirt_Spin": (60, False, {
        0: {},
        10: {H: {"rot": (0, 0, -12), "loc": (0, 0, -0.08)}, S0: (4, 0, -10), BD: (0, -50, 0), BI: (0, 50, 0), CA: (0, 0, 10)},
        24: c({H: {"rot": (0, 0, -40), "loc": (0, 0, -0.16)}, S0: (8, 0, -18), S1: (4, 0, -10), BD: (0, -70, 20), BI: (0, 70, -20), CA: (6, 0, 18)}, "suelta"),
        27: {H: {"rot": (0, 0, -42), "loc": (0, 0, -0.16)}, S0: (8, 0, -18), S1: (4, 0, -10), BD: (0, -72, 20), BI: (0, 72, -20), CA: (6, 0, 18)},
        36: c({H: {"rot": (0, 0, 330), "loc": (0, 0, -0.05)}, S0: (-4, 0, 6), BD: (0, -86, 0), BI: (0, 86, 0), CA: (-6, 0, -10)}, "golpe"),
        45: c({H: {"rot": (0, 0, 720), "loc": (0, 0, -0.1)}, S0: (-2, 0, 8), BD: (0, -78, 0), BI: (0, 78, 0), CA: (-4, 0, -12)}, "lineal"),
        50: c({H: {"rot": (0, 0, 734), "loc": (0, 0, -0.14)}, S0: (6, 0, 10), BD: (0, -40, 0), BI: (0, 40, 0), CA: (10, 6, -8)}, "suelta"),
        55: {H: {"rot": (0, 0, 716), "loc": (0, 0, -0.06)}, S0: (4, 0, -6), CA: (6, -6, 6)},
        60: {H: {"rot": (0, 0, 720)}},
    }),
    # Aretes (los arranca al 18): agacha la cabeza, la sacude de un lado al otro y los avienta
    "Earrings_Snap": (36, False, {
        0: {},
        10: c({CA: (34, 0, 0), CU: (16, 0, 0), S1: (10, 0, 0), S0: (6, 0, 0), BD: (-20, -10, 0), BI: (-20, 10, 0)}, "suelta"),
        14: c({CA: (32, 0, 26), CU: (16, 0, 10), S1: (10, 0, 6)}, "golpe"),
        18: c({CA: (28, 0, -28), CU: (14, 0, -10), S1: (8, 0, -6), BD: (-30, -30, 0), BI: (-30, 30, 0)}, "golpe"),
        24: c({CA: (18, 0, 8), CU: (8, 0, 0)}, "suelta"),
        36: {},
    }),
    # Grito (al 24): jala aire encogiendose, avienta la cabeza para atras con los brazos abiertos
    # y tiembla gritando
    "Scream": (60, False, {
        0: {},
        16: c({CA: (26, 0, 0), CU: (10, 0, 0), S1: (14, 0, 0), S0: (8, 0, 0), BD: (6, 20, 0), BI: (6, -20, 0), H: {"loc": (0, 0, -0.18)}}, "suelta"),
        21: {CA: (30, 0, 0), CU: (12, 0, 0), S1: (16, 0, 0), S0: (10, 0, 0), BD: (8, 22, 0), BI: (8, -22, 0), H: {"loc": (0, 0, -0.22)}},
        24: c({CA: (-44, 0, 0), CU: (-18, 0, 0), S1: (-12, 0, 0), S0: (-8, 0, 0), BD: (-66, -46, 0), BI: (-66, 46, 0), H: {"loc": (0, 0, 0.08)}}, "golpe"),
        42: {CA: (-38, 0, 0), CU: (-14, 0, 0), S1: (-10, 0, 0), BD: (-58, -38, 0), BI: (-58, 38, 0)},
        60: c({}, "suelta"),
    }),
    # Se le cae la cabeza: se le tuerce el cuello, se ladea y se va a gatas
    "Head_Fall": (75, False, {
        0: {},
        12: {CA: (36, 0, 32), CU: (22, 0, 12), S1: (-4, 0, -6)},
        20: c({CA: (64, 0, 44), CU: (34, 0, 14), S0: (12, 0, 0), BD: (-40, -30, 0), BI: (-40, 30, 0)}, "golpe"),
        32: c(junta(RODILLAS, {S0: (24, 0, 0), BD: (-60, 0, 0), BI: (-60, 0, 0)}), "golpe"),
        45: c(GATAS, "suelta"),
        75: GATAS,
    }),
    # A gatas: jala con un brazo y luego con el otro, los hombros rodando, la joroba sube y baja
    "Crawl": (40, True, {
        0: junta(GATAS, {BD: (-112, 0, 6), AD: (-6, 0, 0), BI: (-56, 0, -12), AI: (-34, 0, 0), S1: (34, 0, 6), S2: (22, -4, 4),
                         H: {"rot": (0, 3, 5), "loc": (0, 0, -1.05)}, RU: {"rot": (0, 0, 2)}}),
        10: junta(GATAS, {BD: (-90, 0, 6), AD: (-24, 0, 0), BI: (-80, 0, -8), AI: (-18, 0, 0), S0: (42, 0, 0), S1: (36, 0, 0),
                          H: {"rot": (0, 0, 0), "loc": (0, 0, -0.96)}}),
        20: junta(GATAS, {BD: (-56, 0, 12), AD: (-34, 0, 0), BI: (-112, 0, -6), AI: (-6, 0, 0), S1: (34, 0, -6), S2: (22, 4, -4),
                          H: {"rot": (0, -3, -5), "loc": (0, 0, -1.05)}, RU: {"rot": (0, 0, -2)}}),
        30: junta(GATAS, {BD: (-80, 0, 8), AD: (-18, 0, 0), BI: (-90, 0, -6), AI: (-24, 0, 0), S0: (42, 0, 0), S1: (36, 0, 0),
                          H: {"rot": (0, 0, 0), "loc": (0, 0, -0.96)}}),
        40: junta(GATAS, {BD: (-112, 0, 6), AD: (-6, 0, 0), BI: (-56, 0, -12), AI: (-34, 0, 0), S1: (34, 0, 6), S2: (22, -4, 4),
                          H: {"rot": (0, 3, 5), "loc": (0, 0, -1.05)}, RU: {"rot": (0, 0, 2)}}),
    }),
    # Manotazo (al 24): alza el brazo hasta atras, lo deja colgado y lo azota con toda la espalda
    "Crawl_Slam": (45, False, {
        0: GATAS,
        14: c(junta(GATAS, {BD: (-190, 0, 10), AD: (-30, 0, 0), S0: (26, 0, 8), S1: (12, 0, 10), CU: (-34, 0, 0), BI: (-90, 0, -16)}), "suelta"),
        20: junta(GATAS, {BD: (-196, 0, 12), AD: (-34, 0, 0), S0: (24, 0, 8), S1: (10, 0, 10), CU: (-36, 0, 0), BI: (-92, 0, -16)}),
        24: c(junta(GATAS, {BD: (-52, 0, 0), AD: (-4, 0, 0), S0: (46, 0, -4), S1: (40, 0, -6), CU: (-10, 0, 0), H: {"loc": (0, 0, -1.2)}}), "golpe"),
        28: c(junta(GATAS, {BD: (-46, 0, 0), S0: (50, 0, -4), S1: (42, 0, -6), H: {"loc": (0, 0, -1.25)}}), "suelta"),
        45: GATAS,
    }),
    # Embestida (sale al 18): se echa para atras enroscada y se avienta con los dos brazos
    "Crawl_Lunge": (48, False, {
        0: GATAS,
        16: c(junta(GATAS, {H: {"loc": (0, 0.7, -1.2)}, S0: (50, 0, 0), S1: (40, 0, 0), BD: (-46, 0, 0), BI: (-46, 0, 0)}), "suelta"),
        18: junta(GATAS, {H: {"loc": (0, 0.72, -1.22)}, S0: (52, 0, 0), S1: (42, 0, 0), BD: (-44, 0, 0), BI: (-44, 0, 0)}),
        24: c(junta(GATAS, {H: {"loc": (0, -0.6, -0.85)}, S0: (22, 0, 0), S1: (18, 0, 0), BD: (-140, 0, 4), BI: (-140, 0, -4), CU: (-40, 0, 0)}), "golpe"),
        33: c(junta(GATAS, {H: {"loc": (0, -0.45, -1.05)}, BD: (-104, 0, 0), BI: (-104, 0, 0)}), "suelta"),
        48: GATAS,
    }),
}


def _latigo():
    """El latigazo de la trenza: cada hueso sigue la misma curva un poco despues que el de arriba
    (1.5 cuadros), asi el golpe viaja hasta la punta. Hacia atras hasta el 18 (preparacion), al
    frente sobre el hombro 21-28 (el golpe, TRENZA_PEGA), se pasa, rebota y se asienta al 45. El
    cuerpo se enrosca al reves para cargar y se desenrosca con el golpe."""
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
        carga = min(f / 18, 1) if f <= 21 else max(1 - (f - 21) / 6, -0.6) if f <= 30 else -0.6 * (1 - (f - 30) / 15)
        cabeza_z = 30 * min(f / 21, 1) if f <= 21 else 30 - 45 * min((f - 21) / 7, 1) if f <= 28 else -15 * (1 - (f - 28) / 17)
        pose[CA] = (-15 if f <= 21 else 20 if f <= 30 else 5, 0, cabeza_z)
        pose[S0] = (-4 * carga, 0, 14 * carga)
        pose[S1] = (0 if f <= 21 else 9, 0, 12 * carga)
        pose[H] = {"rot": (0, 0, 8 * carga), "loc": (0, 0, -0.08 * abs(carga))}
        pose[BD] = (10 * carga, -20 - 10 * abs(carga), 0)
        pose[BI] = (-10 * carga, 20 + 10 * abs(carga), 0)
        llaves[f] = pose
    llaves[45] = {}
    return llaves


CLIPS["Braid_Whip"] = (45, False, _latigo())


# --- Capas que se suman encima de las llaves ---

def _capa_reposo(f, n):
    out = {}
    respira = math.sin(f / n * math.tau * 2)     # dos respiraciones en el clip
    out[S1] = (1.5 * respira, 0, 0)
    out[S2] = (1.2 * respira, 0, 0)
    out[HD] = (0, 0, 1.5 * respira)
    out[HI] = (0, 0, -1.5 * respira)
    # El tic de titere: un jalon del cuello y la mano a los 74-82 (el nudo de adentro se mueve)
    tic = max(0.0, 1 - abs(f - 76) / 5) if 70 <= f <= 82 else 0.0
    out[CA] = (-8 * tic, 0, 16 * tic)
    out[CU] = (-4 * tic, 0, 6 * tic)
    out[AD] = (-14 * tic, 0, 0)
    out[S2] = (out[S2][0], 0, -5 * tic)
    out.update(ola(CO, f / n * math.tau, 2))
    out.update(ola(TR, f / n * math.tau * 2, 3))
    return out


def _capa_tiembla(f, n, fuerza=1.0):
    out = {}
    for k, h in enumerate((S1, CA, BD, BI, AD, AI)):
        out[h] = (fuerza * 1.6 * math.sin(f * 2.3 + k * 1.7), 0, fuerza * 1.2 * math.sin(f * 3.1 + k))
    return out


def _capa_camina(f, n):
    out = ola(CO, f / n * math.tau, 5, 2)
    out.update(ola(TR, f / n * math.tau * 2 + 1.0, 6))
    return out


def _capa_gatea(f, n):
    out = ola(CO, f / n * math.tau, 7, 2)
    out[CU] = (4 * math.sin(f / n * math.tau * 2 + 0.6), 0, 6 * math.sin(f / n * math.tau + 0.5))
    return out


def _capa_grito(f, n):
    return _capa_tiembla(f, n, 1.4 if 24 <= f <= 46 else 0.0)


CAPAS = {
    "Idle_Pose": _capa_reposo,
    "Walk": _capa_camina,
    "Kneel_Idle": lambda f, n: _capa_tiembla(f, n, 1.2),
    "Crawl": _capa_gatea,
    "Scream": _capa_grito,
    "Tear_Roar": lambda f, n: _capa_tiembla(f, n, 1.2 if 15 <= f <= 50 else 0.0),
    "Stomp": lambda f, n: _capa_tiembla(f, n, 0.8 if 13 <= f <= 21 else 0.0),
    "Crawl_Slam": lambda f, n: _capa_tiembla(f, n, 0.8 if 14 <= f <= 21 else 0.0),
    "Grab_Hold": lambda f, n: ola(TR, f / n * math.tau, 4),
}


# --- Muestreo ---

def _ease(u, curva):
    if curva == "golpe":
        return u * u * u
    if curva == "suelta":
        return 1 - (1 - u) ** 3
    if curva == "lineal":
        return u
    if curva == "quieto":
        return 0.0 if u < 1.0 else 1.0
    return u * u * (3 - 2 * u)


def _valor(pose, hueso):
    v = pose.get(hueso, (0, 0, 0))
    if isinstance(v, dict):
        return Vector(v.get("rot", (0, 0, 0))), Vector(v.get("loc", (0, 0, 0)))
    return Vector(v), Vector((0, 0, 0))


def _pose_en(llaves, t, hueso):
    """Giro y lugar del hueso en el cuadro t (puede ser fraccion), entre las llaves que lo rodean."""
    cuadros = sorted(llaves)
    if t <= cuadros[0]:
        return _valor(llaves[cuadros[0]], hueso)
    if t >= cuadros[-1]:
        return _valor(llaves[cuadros[-1]], hueso)
    for a, b in zip(cuadros, cuadros[1:]):
        if t <= b:
            u = _ease((t - a) / (b - a), llaves[b].get("_c"))
            ra, la = _valor(llaves[a], hueso)
            rb, lb = _valor(llaves[b], hueso)
            return ra.lerp(rb, u), la.lerp(lb, u)


def _local(pb, rot_grados, loc):
    m = pb.bone.matrix_local.to_3x3()
    r = Euler([math.radians(a) for a in rot_grados], "XYZ").to_matrix()
    q = (m.inverted() @ r @ m).to_quaternion()
    l = m.inverted() @ Vector(loc)
    return q, l


def armar_clips(solo=None, cada=1):
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
        capa = CAPAS.get(nombre)
        muestras = sorted(set(range(0, cuadros + 1, cada)) | {k for k in llaves if k <= cuadros})
        # Los cuaterniones de un hueso no deben brincar al lado contrario entre muestras
        antes = {}
        for f in muestras:
            extra = capa(f, cuadros) if capa else {}
            for pb in deforman:
                lag = RETRASO.get(pb.name, 0)
                t = f - lag
                if bucle:
                    t %= cuadros
                elif f >= cuadros:
                    t = cuadros     # el ultimo cuadro, todos en la pose final
                rot, loc = _pose_en(llaves, t, pb.name)
                if pb.name in extra:
                    er, el = _valor(extra, pb.name)
                    rot = rot + er
                    loc = loc + el
                q, l = _local(pb, tuple(rot), tuple(loc))
                if pb.name in antes and antes[pb.name].dot(q) < 0.0:
                    q.negate()
                antes[pb.name] = q.copy()
                pb.rotation_quaternion = q
                pb.location = l
                pb.keyframe_insert("rotation_quaternion", frame=f)
                pb.keyframe_insert("location", frame=f)
        accion.frame_range = (0, cuadros)
        hechas.append(nombre)
    # El reposo de exhibicion
    rig.animation_data.action = bpy.data.actions.get("Idle_Pose")
    sc.frame_start = 0
    sc.frame_end = 120
    print("clips:", len(hechas), hechas)


if not globals().get("SOLO_FUNCIONES"):
    armar_clips()
