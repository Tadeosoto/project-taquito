# El desague de abajo del bano del Sotano: la pelea con LA DESAGUADORA (docs/sistemas/sotano.md),
# a lo Silent Hill 2 pero nuestra: oxido, carne en los muros, rejas, tubos, cadenas, focos rojos
# enjaulados, agua negra en medio y cuatro coladeras por donde ella se hunde y sale.
# Exporta:
#   models/sotano/desague.glb       la arena (16 x 16 m de la escena, centro en el origen, piso en 0)
#   models/sotano/desaguadora.glb   la jefa: mujer hinchada sin cara, de pelo de coladera y agua
#                                   negra; vacios Hombro_L/R (brazos), Cabeza, Pelo, Corazon
#   models/armas/varilla/varilla.glb el premio: la varilla oxidada con cadena (Desague.gd)
# Usa las funciones de sotano.py (caja, girar, tubo_curva...). Corre en un archivo nuevo y vacio:
#   R = r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender\sotano"
#   exec(open(R + r"\desague.py", encoding="utf-8").read(), {"__name__": "desague"})
# Texturas: arte.py desague() (oxido.png, reja.png, carne.png). Escala: metros de la escena del
# Sotano (CasaPropia agranda x1.25).

import bpy
import math
import os
import random
from mathutils import Matrix, Vector

_R = os.path.join(os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito"), "tools", "blender", "sotano")
# Las funciones de sotano.py en este mismo espacio (sin correr su parte de abajo: otro __name__)
_g = globals()
_nombre = _g.get("__name__")
_g["__name__"] = "sotano_funciones"
exec(open(os.path.join(_R, "sotano.py"), encoding="utf-8").read(), _g)
_g["__name__"] = _nombre

LADO = 8.0          # media arena
ALTO = 4.2          # techo
POZA = 3.4          # radio del agua negra de en medio
COLADERAS = ((-5.0, -5.0), (5.0, -5.0), (5.0, 5.0), (-5.0, 5.0), (0.0, 0.0))
ENTRADA = (0.0, -7.2)   # la escalera de marinero que baja de la escotilla


def arena():
    col = coleccion("Desague")
    oxido = material("oxido", (0.32, 0.16, 0.08))
    carne = material("carne", (0.45, 0.12, 0.12))
    reja = material("reja", (0.4, 0.25, 0.15))
    rejilla = material("rejilla", (0.18, 0.12, 0.08))
    agua = material("agua_negra", (0.02, 0.025, 0.03))
    tubo = material("tubo_oxidado", (0.4, 0.22, 0.12))
    cadena = material("cadena", (0.2, 0.18, 0.17))
    L, H = LADO, ALTO
    g = 0.3
    # La caja: piso, techo y muros de lamina oxidada
    caja("Des_piso", -L - g, L + g, -g, 0.0, -L - g, L + g, rejilla, col)
    caja("Des_techo", -L - g, L + g, H, H + g, -L - g, L + g, oxido, col)
    for nombre, a, b, c, d in (("n", -L - g, L + g, -L - g, -L), ("s", -L - g, L + g, L, L + g), ("o", -L - g, -L, -L, L), ("e", L, L + g, -L, L)):
        caja("Des_muro_" + nombre, a, b, 0.0, H, c, d, oxido, col)
    # Lineas de la rejilla del piso (el piso es rejilla sobre lo oscuro)
    for k in range(-15, 16):
        caja("Des_rejilla_x_%d" % (k + 15), k * 0.5 - 0.015, k * 0.5 + 0.015, 0.0, 0.012, -L, L, material("rejilla_borde", (0.1, 0.06, 0.04)), col, choca=False)
        caja("Des_rejilla_z_%d" % (k + 15), -L, L, 0.0, 0.012, k * 0.5 - 0.015, k * 0.5 + 0.015, material("rejilla_borde"), col, choca=False)
    # El agua negra de en medio, con su orilla oxidada
    girar("Des_poza", [(0, 0.02), (POZA, 0.02), (POZA, 0.025), (0, 0.025)], agua, col, lados=48)
    girar("Des_poza_orilla", [(POZA, 0.0), (POZA + 0.25, 0.0), (POZA + 0.25, 0.08), (POZA, 0.08)], tubo, col, lados=48)
    # Las coladeras: rejas redondas por donde ella baja y sube
    for k, (cx, cz) in enumerate(COLADERAS):
        cola = girar("Des_coladera_%d" % k, [(0, 0.03), (0.6, 0.03), (0.6, 0.06), (0, 0.06)], material("coladera", (0.08, 0.07, 0.07)), col, lados=24)
        cola.location = _b(cx, 0.0, cz)
        for j in range(5):
            caja("Des_coladera_%d_barra_%d" % (k, j), cx - 0.55, cx + 0.55, 0.06, 0.08, cz - 0.4 + j * 0.2 - 0.02, cz - 0.4 + j * 0.2 + 0.02, tubo, col, choca=False)
        marca("Coladera_%d" % k, cx, 0.0, cz, col, 0)
    # Carne que le crece a los muros: bultos aplastados contra la lamina
    rnd = random.Random(9)
    for k in range(26):
        lado = rnd.randrange(4)
        t = rnd.uniform(-L + 0.8, L - 0.8)
        y = rnd.uniform(0.3, H - 0.4)
        r = rnd.uniform(0.35, 0.9)
        x, z, esc = {0: (t, -L + 0.05, (1, 0.35, 1)), 1: (t, L - 0.05, (1, 0.35, 1)), 2: (-L + 0.05, t, (0.35, 1, 1)), 3: (L - 0.05, t, (0.35, 1, 1))}[lado]
        b = esfera("Des_carne_%d" % k, r, carne, col)
        b.location = _b(x, y, z)
        b.scale = (esc[0], esc[1], esc[2] * rnd.uniform(0.7, 1.3))
    # Rejas ciclonicas: un corral alrededor de la poza con huecos
    for k in range(12):
        if k in (0, 6):
            continue
        a0, a1 = k * math.tau / 12, (k + 1) * math.tau / 12
        rr = POZA + 1.4
        p0 = (math.cos(a0) * rr, math.sin(a0) * rr)
        p1 = (math.cos(a1) * rr, math.sin(a1) * rr)
        tubo_curva("Des_poste_%d" % k, [Vector((p0[0], 0.0, p0[1])), Vector((p0[0], 2.0, p0[1]))], 0.035, tubo, col, lados=8)
        centro = ((p0[0] + p1[0]) / 2, 1.0, (p0[1] + p1[1]) / 2)
        largo = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        normal = (math.cos((a0 + a1) / 2), 0, math.sin((a0 + a1) / 2))
        plano("Des_reja_%d" % k, centro, largo, 2.0, normal, reja, col, uv=(0, 0, largo / 1.5, 2.0 / 1.5))
        plano("Des_reja_%d_b" % k, centro, largo, 2.0, (-normal[0], 0, -normal[2]), reja, col, uv=(0, 0, largo / 1.5, 2.0 / 1.5))
    # Tubos gruesos por los muros y el techo, con sus valvulas
    for k, (pa, pb) in enumerate((((-L + 0.3, 3.2, -L + 0.3), (L - 0.3, 3.2, -L + 0.3)), ((L - 0.3, 3.5, -L + 0.3), (L - 0.3, 3.5, L - 0.3)),
                                   ((-L + 0.3, 2.6, L - 0.3), (L - 0.3, 2.6, L - 0.3)), ((-3.0, H - 0.3, -L), (-3.0, H - 0.3, L)),
                                   ((3.0, H - 0.4, -L), (3.0, H - 0.4, L)))):
        tubo_curva("Des_tubo_%d" % k, [Vector(pa), Vector(pb)], 0.18 if k < 3 else 0.12, tubo, col, lados=12)
    for k, (vx, vy, vz) in enumerate(((-4.0, 3.2, -L + 0.3), (4.5, 2.6, L - 0.3), (L - 0.3, 3.5, 2.0))):
        rueda = girar("Des_valvula_%d" % k, [(0.18, -0.02), (0.22, -0.02), (0.22, 0.02), (0.18, 0.02)], material("valvula", (0.55, 0.08, 0.06)), col, lados=16)
        rueda.location = _b(vx, vy, vz + (0.25 if vz < 0 else -0.25))
        rueda.rotation_euler = (math.radians(90), 0, 0)
    # Cadenas colgando del techo con ganchos
    for k in range(9):
        cx, cz = rnd.uniform(-L + 1.0, L - 1.0), rnd.uniform(-L + 1.0, L - 1.0)
        if math.hypot(cx, cz) < 2.0:
            continue
        largo = rnd.uniform(1.0, 2.6)
        for j in range(int(largo / 0.12)):
            eslabon = girar("Des_cadena_%d_%d" % (k, j), [(0.03, -0.05), (0.045, -0.05), (0.045, 0.05), (0.03, 0.05)], cadena, col, lados=6)
            eslabon.location = _b(cx, H - 0.06 - j * 0.12, cz)
            eslabon.rotation_euler = (math.radians(90), 0, math.radians(90 * (j % 2)))
        tubo_curva("Des_gancho_%d" % k, [Vector((cx, H - largo, cz)), Vector((cx, H - largo - 0.15, cz)), Vector((cx + 0.08, H - largo - 0.2, cz)),
                                         Vector((cx + 0.12, H - largo - 0.1, cz))], 0.015, cadena, col, lados=6)
    # Focos rojos enjaulados en los muros
    for k, (fx, fz) in enumerate(((-L + 0.15, -3.0), (-L + 0.15, 3.0), (L - 0.15, -3.0), (L - 0.15, 3.0), (-3.0, L - 0.15), (3.0, -L + 0.15))):
        esfera("Des_foco_%d" % k, 0.07, material("foco_rojo", (1.0, 0.15, 0.1), emision=2.0), col).location = _b(fx, 2.3, fz)
        for j in range(4):
            a = j * math.tau / 4
            tubo_curva("Des_jaula_%d_%d" % (k, j), [Vector((fx + math.cos(a) * 0.1, 2.18, fz + math.sin(a) * 0.1)), Vector((fx + math.cos(a) * 0.1, 2.42, fz + math.sin(a) * 0.1))],
                       0.008, cadena, col, lados=4)
        marca("Luz_des_%d" % k, fx + (0.4 if fx < 0 else -0.4) * (abs(fx) > 7), 2.3, fz + (0.4 if fz < 0 else -0.4) * (abs(fz) > 7), col, 0)
    # El ventilador grande del muro este (el codigo gira Des_ventilador_aspas)
    girar("Des_ventilador_marco", [(1.0, -0.05), (1.15, -0.05), (1.15, 0.12), (1.0, 0.12)], tubo, col, lados=24).location = _b(L - 0.1, 2.2, 0.0)
    bpy.data.objects["Des_ventilador_marco"].rotation_euler = (0, math.radians(90), 0)
    centro_v = bpy.data.objects.new("Des_ventilador_aspas", None)
    centro_v.location = _b(L - 0.2, 2.2, 0.0)
    col.objects.link(centro_v)
    for k in range(4):
        aspa = caja("Des_aspa_%d" % k, -0.02, 0.02, -0.08, 0.08, 0.05, 0.95, material("aspa", (0.25, 0.22, 0.2)), col, choca=False)
        aspa.parent = centro_v
        aspa.location = Vector((0, 0, 0))
        aspa.rotation_euler = (k * math.pi / 2, 0, 0)
    # Una camilla oxidada y una silla de ruedas volteada (recuerdos de hospital)
    caja("Des_camilla", -6.2, -4.4, 0.75, 0.82, 1.6, 2.3, material("lamina_camilla", (0.5, 0.48, 0.45)), col)
    for sx in (-6.1, -4.5):
        for sz in (1.7, 2.2):
            tubo_curva("Des_camilla_pata_%d_%d" % (int(sx), int(sz * 10)), [Vector((sx, 0.0, sz)), Vector((sx, 0.75, sz))], 0.02, tubo, col, lados=6)
    caja("Des_camilla_sabana", -6.15, -4.45, 0.82, 0.86, 1.62, 2.28, material("sabana_sucia", (0.6, 0.55, 0.45)), col, choca=False)
    for k in range(2):
        rueda = girar("Des_silla_rueda_%d" % k, [(0.28, -0.02), (0.32, -0.02), (0.32, 0.02), (0.28, 0.02)], tubo, col, lados=16)
        rueda.location = _b(5.2, 0.32, -2.0 + k * 0.5)
        rueda.rotation_euler = (math.radians(90), 0, math.radians(15))
    caja("Des_silla_asiento", 4.9, 5.5, 0.2, 0.25, -1.95, -1.55, material("cuero_negro", (0.08, 0.06, 0.06)), col, choca=False)
    # La escalera de marinero de la entrada, con la escotilla arriba
    ex, ez = ENTRADA
    for lado in (-0.25, 0.25):
        tubo_curva("Des_escalera_%d" % (lado > 0), [Vector((ex + lado, 0.0, ez - 0.55)), Vector((ex + lado, H, ez - 0.55))], 0.025, tubo, col, lados=6)
    for k in range(13):
        tubo_curva("Des_peldano_%d" % k, [Vector((ex - 0.25, 0.3 + k * 0.3, ez - 0.55)), Vector((ex + 0.25, 0.3 + k * 0.3, ez - 0.55))], 0.018, tubo, col, lados=6)
    girar("Des_escotilla", [(0, -0.03), (0.5, -0.03), (0.5, 0.0), (0, 0.0)], material("lamina_puerta", (0.25, 0.3, 0.28)), col, lados=16).location = _b(ex, H, ez - 0.55)
    marca("Entrada", ex, 0.0, ez + 0.3, col, 180)
    marca("Salida", ex, 0.0, ez - 0.1, col, 180)
    marca("Centro", 0.0, 0.0, 0.0, col, 0)
    marca("Premio", 0.0, 0.0, 1.2, col, 0)
    return col


def curva(pts, pasos=4):
    """Catmull-Rom por los puntos: mas puntos en medio, para que los mechones y los brazos se
    vean redondos y no quebrados."""
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


# El perfil del torso (radio, alto) de abajo arriba, suavizado: la cintura en 1.15
PERFIL_TORSO = suavizar([(0, 1.15), (0.4, 1.15), (0.62, 1.5), (0.58, 1.8), (0.48, 2.05), (0.46, 2.2), (0.2, 2.4), (0.13, 2.5), (0, 2.55)], 3)


def desaguadora():
    """La jefa (3.2 m de la escena): de la cintura para abajo una falda de pelo mojado que cae al
    agua, el torso hinchado, gris y azul, jorobado (con las costillas y el espinazo marcados), la
    cabeza agachada sin cara tapada de pelo, y dos brazos larguisimos y huesudos con dedos de mas
    (en Hombro_L/R, que el codigo mueve). Corazon: el punto debil, que brilla cuando se le abre el
    pecho. En alta (AG 2026-11-19, mas resolucion): torso de 40 lados, mechones y brazos curvos de
    6 a 12 lados, el doble de pelo."""
    col = coleccion("Desaguadora")
    piel = material("piel_ahogada", (0.5, 0.56, 0.6))
    piel_osc = material("piel_ahogada_sombra", (0.36, 0.42, 0.47))
    pelo = material("pelo_mojado", (0.03, 0.03, 0.035))
    agua = material("agua_negra", (0.02, 0.025, 0.03))
    raiz = bpy.data.objects.new("Desaguadora", None)
    col.objects.link(raiz)
    rnd = random.Random(4)
    cintura, inclina, ancho, hondo = 1.15, math.radians(-16), 1.15, 0.9

    def cuerpo(x, y, z):
        """Un punto del cuerpo (coordenadas de Godot, como si estuviera derecha) llevado a donde
        queda con el torso ensanchado e inclinado desde la cintura: asi la falda, los hombros, la
        cabeza y el corazon quedan pegados al torso."""
        dx, dy, dz = x * ancho, y - cintura, z * hondo
        return Vector((dx, cintura + dy * math.cos(inclina) - dz * math.sin(inclina), dy * math.sin(inclina) + dz * math.cos(inclina)))

    def radio_torso(y):
        """El radio del torso (antes de ensancharlo) a la altura y, del perfil suavizado."""
        for (r0, y0), (r1, y1) in zip(PERFIL_TORSO, PERFIL_TORSO[1:]):
            if y0 <= y <= y1 and y1 > y0:
                return r0 + (r1 - r0) * (y - y0) / (y1 - y0)
        return 0.0

    def hijo(ob, padre=raiz):
        ob.parent = padre
        return ob

    # El charco a sus pies, con onditas
    hijo(girar("Des_charco", [(0, 0.0), (1.1, 0.0), (1.15, 0.02), (0, 0.03)], agua, col, lados=48))
    for k, r in enumerate((0.75, 0.95, 1.25)):
        hijo(girar("Des_onda_%d" % k, [(r, 0.031), (r + 0.025, 0.031), (r + 0.025, 0.036), (r, 0.036)], agua, col, lados=48))
    # La falda de pelo: mechones curvos que salen de la orilla del torso (un poco arriba de la
    # cintura, para que no quede hueco) y caen al agua abriendose (el doble que antes)
    for k in range(72):
        a = k * math.tau / 72 + rnd.uniform(-0.03, 0.03)
        arriba = cuerpo(math.cos(a) * radio_torso(1.32) * 0.96, 1.32, math.sin(a) * radio_torso(1.32) * 0.96)
        r1 = 0.66 + rnd.uniform(-0.05, 0.18)
        abajo = Vector((math.cos(a) * r1, 0.0, math.sin(a) * r1))
        pts = []
        for j in range(6):
            t = j / 5.0
            q = arriba.lerp(abajo, t)
            q += Vector((math.cos(a), 0, math.sin(a))) * (math.sin(t * math.pi) * 0.06 + math.sin(t * 5.0 + k) * 0.03)
            pts.append(q + Vector((0, rnd.uniform(-0.02, 0.02) if 0 < j < 5 else 0.0, 0)))
        hijo(tubo_curva("Des_mechon_%d" % k, curva(pts, 3), 0.026 + rnd.uniform(0.0, 0.012), pelo, col, lados=6))
    # El torso hinchado y jorobado, suave
    # (girado desde la cintura, no desde el piso: si no, arriba quedaba 60 cm adelante de los hombros)
    torso = girar("Des_torso", [(r, y - cintura) for r, y in PERFIL_TORSO], piel, col, lados=40)
    torso.location = _b(0.0, cintura, 0.0)
    torso.rotation_euler = (inclina, 0, 0)
    torso.scale = (ancho, hondo, 1.0)
    hijo(torso)
    # Costillas marcadas a los lados y el espinazo de nudos por la espalda
    for lado in (-1, 1):
        for k in range(5):
            yk = 1.72 + k * 0.1
            r = radio_torso(yk) * 1.02
            pts = [cuerpo(lado * r * math.cos(math.radians(a)), yk, -r * math.sin(math.radians(a))) for a in (60, 30, 0, -30)]
            hijo(tubo_curva("Des_costilla_%d_%d" % (lado > 0, k), curva(pts, 4), 0.02, piel_osc, col, lados=6))
    for k in range(9):
        yk = 1.4 + k * 0.12
        nudo = hijo(esfera("Des_espinazo_%d" % k, 0.045 - k * 0.002, piel_osc, col, lados=12, anillos=8))
        nudo.location = _b(*cuerpo(0.0, yk, radio_torso(yk) * 1.0))
    # La cabeza agachada y el pelo que la tapa (Cabeza y Pelo los mece el codigo)
    cabeza = bpy.data.objects.new("Cabeza", None)
    cabeza.location = _b(*(cuerpo(0.0, 2.5, -0.1) + Vector((0, 0.05, -0.12))))
    hijo(cabeza)
    hijo(esfera("Des_craneo", 0.3, piel, col, lados=24, anillos=16), cabeza).location = Vector((0, -0.05, 0.12))
    pelo_v = bpy.data.objects.new("Pelo", None)
    pelo_v.location = Vector((0, 0, 0))
    hijo(pelo_v, cabeza)
    # Mucho pelo y largo por delante (su frente es -Z de Godot, sin(a) < 0): cae hacia afuera,
    # sobre la cara y el pecho
    for k in range(120):
        a = k * math.tau / 120 + rnd.uniform(-0.02, 0.02)
        frente = max(-math.sin(a), 0.0)
        largo = rnd.uniform(1.3, 2.1) if frente > 0.2 else rnd.uniform(0.7, 1.15)
        pts = [Vector((math.cos(a) * 0.26, 0.22, math.sin(a) * 0.26))]
        for j in range(1, 7):
            t = j / 6.0
            pts.append(Vector((math.cos(a) * (0.3 + t * 0.12) + rnd.uniform(-0.015, 0.015), 0.22 - largo * t,
                               math.sin(a) * (0.3 + t * 0.12) - math.sin(t * math.pi * 0.8) * 0.55 * frente)))
        m = tubo_curva("Des_pelo_%d" % k, curva(pts, 3), 0.026 + rnd.uniform(0.0, 0.014), pelo, col, lados=6)
        hijo(m, pelo_v)
    # Los brazos larguisimos y huesudos (Hombro_L/R los levanta el codigo): hombro, codo marcado,
    # antebrazo flaco, muneca y seis dedos largos con nudillos
    for lado, nombre in ((-1, "Hombro_L"), (1, "Hombro_R")):
        hombro = bpy.data.objects.new(nombre, None)
        hombro.location = _b(*cuerpo(lado * radio_torso(2.12) * 0.92, 2.12, 0.0))
        hijo(hombro)
        hijo(esfera("Des_hombro_%s" % nombre, 0.11, piel, col, lados=16, anillos=10), hombro).location = Vector((0, 0, 0))
        brazo = [Vector((0, 0, 0)), Vector((lado * 0.08, -0.45, -0.02)), Vector((lado * 0.12, -0.9, -0.08)), Vector((lado * 0.11, -1.4, -0.14)),
                 Vector((lado * 0.08, -1.9, -0.2))]
        # Largo a la altura del hombro: las puntas de los dedos rozan el agua, no atraviesan el piso
        f = (hombro.location.z - 0.06) / 2.44
        brazo = [Vector((v.x, v.y * f, v.z)) for v in brazo]
        hijo(tubo_curva("Des_brazo_%s" % nombre, curva(brazo, 5), 0.065, piel, col, lados=12), hombro)
        hijo(esfera("Des_codo_%s" % nombre, 0.08, piel_osc, col, lados=14, anillos=10), hombro).location = _b(lado * 0.12, -0.9 * f, -0.08)
        hijo(esfera("Des_muneca_%s" % nombre, 0.06, piel, col, lados=12, anillos=8), hombro).location = _b(lado * 0.08, -1.9 * f, -0.2)
        for d in range(6):
            dd = (d - 2.5) * 0.04
            dedo = [Vector((lado * 0.08 + dd, -1.92, -0.2)), Vector((lado * 0.08 + dd * 1.6, -2.1, -0.26)), Vector((lado * 0.08 + dd * 2.0, -2.28, -0.28)),
                    Vector((lado * 0.08 + dd * 2.2, -2.44, -0.22))]
            dedo = [Vector((v.x, v.y * f, v.z)) for v in dedo]
            hijo(tubo_curva("Des_dedo_%s_%d" % (nombre, d), curva(dedo, 4), 0.016, piel, col, lados=6), hombro)
            hijo(esfera("Des_nudillo_%s_%d" % (nombre, d), 0.02, piel_osc, col, lados=8, anillos=6), hombro).location = _b(lado * 0.08 + dd * 1.6, -2.1 * f, -0.26)
    # El corazon: punto debil (el codigo pone su PuntoDebil aqui y prende Corazon_luz)
    corazon = bpy.data.objects.new("Corazon", None)
    corazon.location = _b(*cuerpo(0.0, 1.88, -radio_torso(1.88) * 1.0))
    hijo(corazon)
    hijo(esfera("Corazon_luz", 0.13, material("corazon_luz", (0.3, 1.0, 0.85), emision=3.0), col, lados=16, anillos=12), corazon).location = Vector((0, 0, 0))
    return col


def varilla():
    """El premio: la varilla oxidada del desague, doblada en la punta, con cadena enredada y el mango
    con cinta (mide 0.9; su origen en el mango)."""
    col = coleccion("Varilla")
    oxido = material("tubo_oxidado", (0.4, 0.22, 0.12))
    raiz = bpy.data.objects.new("Varilla", None)
    col.objects.link(raiz)
    piezas = [tubo_curva("Var_barra", [Vector((0, 0, 0)), Vector((0, 0.7, 0)), Vector((0.03, 0.85, 0)), Vector((0.1, 0.92, 0))], 0.016, oxido, col, lados=8),
              tubo_curva("Var_mango", [Vector((0, -0.02, 0)), Vector((0, 0.18, 0))], 0.024, material("cinta_negra", (0.06, 0.06, 0.07)), col, lados=8)]
    for k in range(10):
        a = k * 1.3
        piezas.append(girar("Var_cadena_%d" % k, [(0.02, -0.012), (0.03, -0.012), (0.03, 0.012), (0.02, 0.012)], material("cadena", (0.2, 0.18, 0.17)), col, lados=6))
        piezas[-1].location = _b(math.cos(a) * 0.01, 0.35 + k * 0.035, math.sin(a) * 0.01)
        piezas[-1].rotation_euler = (math.radians(90), 0, a)
    ob = juntar("Varilla_malla", piezas, col)
    ob.parent = raiz
    return col


def exportar_coleccion(nombre, ruta):
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.data.collections[nombre].all_objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB", use_selection=True, export_apply=True, export_yup=True, export_materials="EXPORT")


if __name__ == "desague":
    if bpy.data.filepath:
        raise RuntimeError("desague.py borraria " + bpy.data.filepath + ": abre un archivo nuevo primero")
    limpiar()
    raiz_ = os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito")
    arena()
    desaguadora()
    varilla()
    exportar_coleccion("Desague", os.path.join(raiz_, "models", "sotano", "desague.glb"))
    exportar_coleccion("Desaguadora", os.path.join(raiz_, "models", "sotano", "desaguadora.glb"))
    exportar_coleccion("Varilla", os.path.join(raiz_, "models", "armas", "varilla", "varilla.glb"))
    print("desague: %d objetos" % len(bpy.data.objects))
