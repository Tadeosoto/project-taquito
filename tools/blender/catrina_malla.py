# La Mojiganga, paso 1: las mallas (docs/prompts/blender_catrina.md). v2: mas detalle y mas jefe
# (AG, 2026-11-09): jorobada hacia el frente, brazos largos con garras, craneo con pomulos y
# dientes, costillas en el escote, rebozo rasgado, papel que se despega, cuerdas y alambre,
# carrizo astillado, corona de flores con sartas de cempasuchil, velas en los hombros y brillo
# turquesa (Serenol) en las cuencas.
#
# Se corre dentro de Blender (MCP execute_blender_code con exec(open(ruta).read()), o el editor
# de texto de Blender). Arma desde cero la escena "Catrina": seis objetos con los nombres que
# busca scripts/catrina/Catrina.gd (Vestido, Vestido_Roto, Carrizo, Nudo, Craneo, Cuerpo).
# Metros, Z arriba, mira hacia -Y, origen a los pies. ~6 m de alto.
# Los materiales de aqui son de bloqueo (un color por zona); catrina_textura.py hornea una sola
# textura usando estas mismas zonas. La joroba (doblar) se aplica a todo lo de arriba de la
# cintura; catrina_rig.py usa doblar() para poner los huesos donde quedaron.

import bpy
import bmesh
import math
from mathutils import Vector, Matrix, noise

ESCENA = "Catrina"
LADOS = 24

ZONAS = {
    "Tela": (0.36, 0.09, 0.5),
    "Blanco": (0.92, 0.9, 0.84),
    "Faja": (0.95, 0.93, 0.88),
    "Hueso": (0.88, 0.84, 0.74),
    "Cabello": (0.22, 0.13, 0.08),
    "Carrizo": (0.62, 0.52, 0.3),
    "Nudo": (0.28, 0.33, 0.22),
    "Flor_Magenta": (0.92, 0.15, 0.5),
    "Flor_Naranja": (1.0, 0.45, 0.08),
    "Flor_Morada": (0.5, 0.2, 0.78),
    "Flor_Rosa": (0.95, 0.4, 0.55),
    "Flor_Centro": (0.95, 0.8, 0.15),
    "Verde": (0.25, 0.7, 0.35),
    "Rebozo": (0.16, 0.09, 0.12),
    "Papel": (0.7, 0.62, 0.72),
    "Cuerda": (0.6, 0.5, 0.33),
    "Alambre": (0.4, 0.4, 0.42),
    "Vela": (0.93, 0.88, 0.7),
    "Flama": (1.0, 0.6, 0.15),
    "Brillo": (0.2, 1.0, 0.85),
}
NOMBRES_ZONAS = list(ZONAS)
SUAVES = {"Tela", "Blanco", "Faja", "Hueso", "Cabello", "Nudo", "Rebozo", "Vela"}
BRILLAN = {"Brillo": 4.0, "Flama": 3.0}

# La joroba: el torso se inclina hacia el frente desde la cintura y la cabeza se adelanta
CINTURA_Z = 2.6
CUELLO_Z = 4.6
INCLINA = math.radians(13.0)
CABECEA = math.radians(16.0)


def zona(nombre):
    return NOMBRES_ZONAS.index(nombre)


def _suave(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def _girar_x(p, pivote, angulo):
    q = p - pivote
    c, s = math.cos(angulo), math.sin(angulo)
    return pivote + Vector((q.x, q.y * c - q.z * s, q.y * s + q.z * c))


def doblar(p):
    p = Vector(p)
    z0 = p.z
    w = _suave(2.55, 3.0, z0)
    if w > 0.0:
        p = _girar_x(p, Vector((0, 0, CINTURA_Z)), INCLINA * w)
    w2 = _suave(4.5, 4.8, z0)
    if w2 > 0.0:
        cuello = _girar_x(Vector((0, 0, CUELLO_Z)), Vector((0, 0, CINTURA_Z)), INCLINA)
        p = _girar_x(p, cuello, CABECEA * w2)
    return p


def doblar_bm(bm, verts=None):
    for v in (verts if verts is not None else bm.verts):
        v.co = doblar(v.co)


def materiales():
    mats = []
    for nombre, color in ZONAS.items():
        m = bpy.data.materials.get("cat_" + nombre) or bpy.data.materials.new("cat_" + nombre)
        m.use_nodes = True
        m.use_backface_culling = False
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = 1.0
        if nombre in BRILLAN:
            bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
            bsdf.inputs["Emission Strength"].default_value = BRILLAN[nombre]
        m.diffuse_color = (*color, 1.0)
        mats.append(m)
    return mats


def preparar_escena():
    sc = bpy.data.scenes.get(ESCENA) or bpy.data.scenes.new(ESCENA)
    for ob in list(sc.collection.all_objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    sc.unit_settings.system = "METRIC"
    sc.render.fps = 30
    for ventana in bpy.context.window_manager.windows:
        ventana.scene = sc
    return sc


def caras_de(verts):
    return {f for v in verts for f in v.link_faces}


def pintar(caras, nombre):
    i = zona(nombre)
    for f in caras:
        f.material_index = i


def esfera(bm, centro, radios, nombre, seg=10, anillos=6):
    r = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=anillos, radius=1.0)
    m = Matrix.Translation(Vector(centro)) @ Matrix.Diagonal((*radios, 1.0))
    bmesh.ops.transform(bm, matrix=m, verts=r["verts"])
    pintar(caras_de(r["verts"]), nombre)
    return r["verts"]


def cilindro(bm, a, b, r1, r2, nombre, lados=6, tapas=True):
    a = Vector(a)
    b = Vector(b)
    d = b - a
    r = bmesh.ops.create_cone(bm, cap_ends=tapas, cap_tris=False, segments=lados,
                              radius1=r1, radius2=r2, depth=max(d.length, 0.001))
    giro = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation((a + b) / 2) @ giro, verts=r["verts"])
    pintar(caras_de(r["verts"]), nombre)
    return r["verts"]


def caja(bm, centro, tam, nombre, giro=None):
    r = bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix.Translation(Vector(centro)) @ (giro or Matrix.Identity(4)) @ Matrix.Diagonal((*tam, 1.0))
    bmesh.ops.transform(bm, matrix=m, verts=r["verts"])
    pintar(caras_de(r["verts"]), nombre)
    return r["verts"]


def linea(bm, puntos, radio, nombre, lados=4, cerrada=False):
    verts = []
    n = len(puntos) if cerrada else len(puntos) - 1
    for i in range(n):
        verts += cilindro(bm, puntos[i], puntos[(i + 1) % len(puntos)], radio, radio, nombre, lados=lados, tapas=False)
    return verts


def tira(bm, puntos, ancho, lado, nombre):
    """Una tira plana (papel, fleco): puntos a lo largo y `lado` el vector del ancho."""
    lado = Vector(lado).normalized()
    izq = [bm.verts.new(Vector(p) - lado * ancho / 2) for p in puntos]
    der = [bm.verts.new(Vector(p) + lado * ancho / 2) for p in puntos]
    caras = [bm.faces.new((izq[i], der[i], der[i + 1], izq[i + 1])) for i in range(len(puntos) - 1)]
    pintar(caras, nombre)
    return izq + der


# Un torno: anillos (radio, altura, zona) unidos con quads, con bultos de papel mache, pliegues
# verticales (pliegue(z) da su profundidad) y el ruedo ondulado
def torno(bm, perfil, lados=LADOS, bulto=0.04, ondas=0.0, pliegue=None):
    anillos = []
    for k, (r, z, _) in enumerate(perfil):
        anillo = []
        for i in range(lados):
            a = math.tau * i / lados
            p = Vector((math.cos(a), math.sin(a), 0))
            rr = r * (1.0 + bulto * noise.noise(p * 1.7 + Vector((0, 0, z * 1.3))))
            if pliegue:
                rr *= 1.0 + pliegue(z) * math.cos(a * 12)
            zz = z
            if k == 0:
                zz += ondas * (math.sin(a * 5) + 0.6 * noise.noise(p * 3.0))
            anillo.append(bm.verts.new((p.x * rr, p.y * rr, zz)))
        anillos.append(anillo)
    for k in range(len(anillos) - 1):
        for i in range(lados):
            j = (i + 1) % lados
            f = bm.faces.new((anillos[k][i], anillos[k][j], anillos[k + 1][j], anillos[k + 1][i]))
            f.material_index = zona(perfil[k][2])
    return anillos


def radio_vestido(z):
    for k in range(len(PERFIL_VESTIDO) - 1):
        r0, z0, _ = PERFIL_VESTIDO[k]
        r1, z1, _ = PERFIL_VESTIDO[k + 1]
        if z0 <= z <= z1:
            return r0 + (r1 - r0) * (z - z0) / max(z1 - z0, 1e-4)
    return PERFIL_VESTIDO[-1][0]


# Una flor de papel: capas de petalos en zigzag y el centro, mirando hacia `normal`
def flor(bm, centro, normal, radio, nombre, capas=3):
    centro = Vector(centro)
    giro = Vector((0, 0, 1)).rotation_difference(Vector(normal).normalized()).to_matrix().to_4x4()
    todas = []
    for capa in range(capas):
        rr = radio * (1.0, 0.72, 0.45)[capa]
        alto = 0.045 * capa
        desfase = 0.37 * capa
        medio = bm.verts.new((0, 0, alto + 0.03))
        borde = []
        for i in range(16):
            a = math.tau * i / 16 + desfase
            r = rr if i % 2 == 0 else rr * 0.6
            borde.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, alto - 0.035 * (i % 2))))
        caras = [bm.faces.new((medio, borde[i], borde[(i + 1) % 16])) for i in range(16)]
        pintar(caras, nombre)
        todas += [medio] + borde
    todas += esfera(bm, (0, 0, 0.04 * capas + 0.04), (radio * 0.2,) * 3, "Flor_Centro", seg=6, anillos=4)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(centro) @ giro, verts=todas)


def objeto(sc, nombre, bm, mats):
    for f in bm.faces:
        f.smooth = NOMBRES_ZONAS[f.material_index] in SUAVES
    malla = bpy.data.meshes.new(nombre)
    bm.to_mesh(malla)
    bm.free()
    for m in mats:
        malla.materials.append(m)
    ob = bpy.data.objects.new(nombre, malla)
    sc.collection.objects.link(ob)
    usados = sorted({p.material_index for p in malla.polygons})
    for i in reversed(range(len(malla.materials))):
        if i not in usados:
            malla.materials.pop(index=i)
    return ob


# --- El vestido (y el rebozo, las velas y lo que trae pegado) ---

PERFIL_VESTIDO = [
    (1.68, 0.0, "Blanco"), (1.68, 0.16, "Blanco"), (1.63, 0.3, "Tela"), (1.53, 0.75, "Tela"),
    (1.43, 1.04, "Blanco"), (1.53, 1.12, "Blanco"), (1.37, 1.2, "Tela"), (1.25, 1.5, "Tela"),
    (1.06, 2.0, "Tela"), (0.88, 2.42, "Faja"), (0.91, 2.52, "Faja"), (0.94, 2.68, "Faja"),
    (0.88, 2.8, "Tela"), (0.84, 2.9, "Tela"), (0.87, 3.3, "Tela"), (0.93, 3.75, "Tela"),
    (0.87, 4.12, "Tela"), (0.75, 4.38, "Tela"), (0.5, 4.56, "Tela"), (0.24, 4.65, "Tela"),
]
HOMBRO = 1.08
HOMBRO_Z = 4.33


def _pliegue_falda(z):
    return 0.05 * min(max((2.4 - z) / 2.4, 0.0), 1.0)


def _escote(c):
    """El escote en V del frente: aqui no hay tela, se ven las costillas."""
    return c.y < -0.3 and 3.95 < c.z < 4.66 and abs(c.x) < (c.z - 3.95) * 0.72 + 0.04


def vestido(bm):
    torno(bm, PERFIL_VESTIDO, ondas=0.09, pliegue=_pliegue_falda)
    # El escote en V, con su orilla bordada (blanca)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if _escote(f.calc_center_median())], context="FACES")
    for f in bm.faces:
        c = f.calc_center_median()
        if NOMBRES_ZONAS[f.material_index] == "Tela" and c.y < -0.25 and 3.9 < c.z < 4.7 \
                and abs(c.x) < (c.z - 3.95) * 0.72 + 0.2:
            f.material_index = zona("Blanco")
    for lado in (-1, 1):
        # Manga abombada, su olan blanco y el carrizo astillado que se asoma del hombro
        esfera(bm, (HOMBRO * lado, 0, HOMBRO_Z), (0.47, 0.45, 0.41), "Tela", seg=12, anillos=7)
        cilindro(bm, (HOMBRO * lado * 1.02, 0, 4.02), (HOMBRO * lado * 1.03, 0, 3.88), 0.4, 0.45, "Blanco", lados=12, tapas=False)
        for k in range(3):
            a = Vector((HOMBRO * lado + 0.1 * lado, 0.08 * (k - 1), HOMBRO_Z + 0.3))
            b = a + Vector((0.25 * lado, 0.12 * (k - 1), 0.32 + 0.06 * k))
            cilindro(bm, a, b, 0.035, 0.004, "Carrizo", lados=4)
    # Cuerda amarrada en la cintura, con el nudo y las puntas colgando
    pts = [Vector((math.cos(math.tau * i / 16) * 0.97, math.sin(math.tau * i / 16) * 0.97, 2.62 + 0.03 * math.sin(i * 1.7))) for i in range(16)]
    linea(bm, pts, 0.035, "Cuerda", cerrada=True)
    linea(bm, [Vector((0.55, -0.8, 2.6)), Vector((0.6, -0.86, 2.2)), Vector((0.55, -0.9, 1.85))], 0.03, "Cuerda")
    linea(bm, [Vector((0.48, -0.82, 2.6)), Vector((0.42, -0.9, 2.3))], 0.03, "Cuerda")
    # Alambre que remienda la falda
    pts = [Vector((math.cos(a) * (radio_vestido(1.85) + 0.03), math.sin(a) * (radio_vestido(1.85) + 0.03), 1.85 + 0.05 * math.sin(a * 7)))
           for a in (math.radians(200) + math.radians(150) * i / 10 for i in range(11))]
    linea(bm, pts, 0.015, "Alambre", lados=3)
    # Papel que se despega del vestido: tiras que cuelgan y se enroscan
    for k in range(16):
        a = math.tau * ((k * 0.618) % 1.0)
        z = 0.6 + (k * 0.37 % 1.0) * 1.6
        r = radio_vestido(z) * (1.0 + _pliegue_falda(z) * math.cos(a * 12)) + 0.02
        afuera = Vector((math.cos(a), math.sin(a), 0))
        base = Vector((afuera.x * r, afuera.y * r, z))
        largo = 0.35 + 0.25 * ((k * 0.73) % 1.0)
        puntos = [base + afuera * (0.05 * t * t) + Vector((0, 0, -largo * t)) for t in (0.0, 0.35, 0.7, 1.0)]
        puntos[-1] += afuera * 0.08
        tira(bm, puntos, 0.16 + 0.06 * (k % 3), afuera.cross(Vector((0, 0, 1))), "Papel")
    # Papel picado viejo pegado a la falda
    for k in range(7):
        a = math.tau * ((k * 0.41 + 0.1) % 1.0)
        z = 0.5 + (k * 0.29 % 1.0) * 1.3
        r = radio_vestido(z) * (1.0 + _pliegue_falda(z)) + 0.035
        afuera = Vector((math.cos(a), math.sin(a), 0))
        lado = afuera.cross(Vector((0, 0, 1)))
        c = Vector((afuera.x * r, afuera.y * r, z))
        tira(bm, [c + Vector((0, 0, 0.17)), c - Vector((0, 0, 0.17))], 0.26, lado,
             ["Flor_Magenta", "Flor_Naranja", "Verde", "Flor_Morada"][k % 4])
    # Velas derretidas en los hombros, con su flama
    for (x, y, alto) in ((0.95, -0.12, 0.22), (1.2, 0.1, 0.16), (-1.0, 0.05, 0.2)):
        base = Vector((x, y, HOMBRO_Z + 0.36))
        cilindro(bm, base, base + Vector((0, 0, alto)), 0.065, 0.06, "Vela", lados=6)
        cilindro(bm, base + Vector((0, 0, alto)), base + Vector((0, 0, alto + 0.12)), 0.035, 0.0, "Flama", lados=4, tapas=False)
    rebozo(bm)


def rebozo(bm):
    """El rebozo: cuelga de los hombros por la espalda hasta las rodillas, con fleco roto."""
    columnas = 14
    filas = 9
    rejilla = []
    for i in range(columnas + 1):
        u = i / columnas
        a = math.radians(-15) + math.radians(210) * u     # de un hombro al otro, por atras (+Y)
        largo = 1.0 + 0.3 * noise.noise(Vector((u * 4.0, 1.3, 0)))
        col = []
        for j in range(filas + 1):
            v = j / filas
            z = 4.5 - v * (4.5 - 1.25) * largo
            r = (radio_vestido(z) if z > 0.0 else 1.68) + 0.08 + 0.1 * v
            r += 0.06 * v * math.sin(u * math.tau * 4)    # pliegues que se abren hacia abajo
            if z > 4.2:
                r = 0.75 + (4.5 - z) * 0.6 + 0.35   # sobre los hombros
            col.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        rejilla.append(col)
    caras = []
    for i in range(columnas):
        for j in range(filas):
            caras.append(bm.faces.new((rejilla[i][j], rejilla[i][j + 1], rejilla[i + 1][j + 1], rejilla[i + 1][j])))
    pintar(caras, "Rebozo")
    # Fleco: tiras delgadas colgando del borde de abajo
    for i in range(columnas + 1):
        p = Vector(rejilla[i][-1].co)
        afuera = Vector((p.x, p.y, 0)).normalized()
        lado = afuera.cross(Vector((0, 0, 1)))
        for k in range(2):
            q = p + lado * (0.07 * k - 0.035)
            tira(bm, [q, q + Vector((0, 0, -0.22 - 0.1 * ((i + k) % 3)))], 0.025, lado, "Rebozo")


def roto(bm):
    # Hoyos de carton deshecho con orillas chuecas: se triangula la tela y se quitan los
    # triangulos donde el ruido pasa el umbral
    tela = [f for f in bm.faces if NOMBRES_ZONAS[f.material_index] == "Tela"]
    bmesh.ops.triangulate(bm, faces=tela)
    hoyos = []
    for f in bm.faces:
        nombre = NOMBRES_ZONAS[f.material_index]
        c = f.calc_center_median()
        if nombre == "Tela" and c.z > 0.35 and noise.noise(c * 1.5 + Vector((3.1, 7.7, 1.3))) + 0.25 * noise.noise(c * 6.0) > 0.05:
            hoyos.append(f)
        elif nombre == "Rebozo" and c.z < 3.6 and noise.noise(c * 2.0 + Vector((1.0, 2.0, 3.0))) > 0.2:
            hoyos.append(f)
    bmesh.ops.delete(bm, geom=hoyos, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # Las orillas cuelgan (colgajos) y salen astillas de carrizo
    orilla = {v for e in bm.edges if e.is_boundary for v in e.verts}
    for v in orilla:
        if v.co.z > 0.35:
            caida = 0.04 + 0.08 * (0.5 + 0.5 * noise.noise(v.co * 4.0))
            v.co.z -= caida
            v.co += Vector((v.co.x, v.co.y, 0)).normalized() * 0.04
    for k, v in enumerate(sorted(orilla, key=lambda v: (round(v.co.z, 2), round(v.co.x, 2)))):
        if k % 23 == 0 and 0.5 < v.co.z < 4.3:
            afuera = Vector((v.co.x, v.co.y, 0)).normalized()
            cilindro(bm, v.co, v.co + afuera * 0.3 + Vector((0, 0, 0.12)), 0.03, 0.003, "Carrizo", lados=4)


# --- El cuerpo: cuello, costillas, brazos con garras, piernas ---

MANO = 1.45   # las manos grandes: se tienen que ver de lejos


def garra(bm, muneca, dedos_hacia, palma_hacia):
    """Una mano huesuda: palma, cuatro dedos largos de dos coyunturas con punta y un pulgar."""
    antes = set(bm.verts)
    d = Vector(dedos_hacia).normalized()
    adentro = Vector(palma_hacia).normalized()
    lado = d.cross(adentro).normalized()
    adentro = lado.cross(d).normalized()
    giro = Matrix((lado, adentro, d)).transposed().to_4x4()
    palma = muneca + d * 0.16
    caja(bm, palma, (0.24, 0.08, 0.3), "Hueso", giro)
    for k in range(4):
        p = palma + d * 0.15 + lado * (k - 1.5) * 0.065
        dirr = d
        for paso, largo in enumerate((0.2, 0.17, 0.15)):
            # Se cierran hacia la palma en cada coyuntura: garra
            dirr = (dirr + adentro * 0.35).normalized()
            q = p + dirr * largo
            if paso < 2:
                cilindro(bm, p, q, 0.032, 0.026, "Hueso", lados=5)
                esfera(bm, q, (0.034,) * 3, "Hueso", seg=5, anillos=3)
            else:
                cilindro(bm, p, q, 0.026, 0.003, "Hueso", lados=5)
            p = q
    base = palma - d * 0.06 + lado * 0.14
    q = base + (d * 0.5 + lado * 0.6 + adentro * 0.3).normalized() * 0.17
    cilindro(bm, base, q, 0.035, 0.028, "Hueso", lados=5)
    cilindro(bm, q, q + (d + adentro * 0.6).normalized() * 0.15, 0.028, 0.003, "Hueso", lados=5)
    for v in bm.verts:
        if v not in antes:
            v.co = muneca + (v.co - muneca) * MANO


def brazo(bm, hombro, codo, muneca, dedos_hacia, palma_hacia):
    cilindro(bm, hombro, codo, 0.13, 0.1, "Hueso", lados=7)
    esfera(bm, codo, (0.14,) * 3, "Hueso", seg=7, anillos=5)
    cilindro(bm, codo, muneca, 0.1, 0.075, "Hueso", lados=7)
    esfera(bm, muneca, (0.095,) * 3, "Hueso", seg=6, anillos=4)
    garra(bm, Vector(muneca), dedos_hacia, palma_hacia)
    # Pulsera de flores en la muneca
    d = (Vector(muneca) - Vector(codo)).normalized()
    u = d.orthogonal().normalized()
    w = d.cross(u)
    for k in range(7):
        a = math.tau * k / 7
        p = Vector(muneca) - d * 0.08 + (u * math.cos(a) + w * math.sin(a)) * 0.11
        esfera(bm, p, (0.055,) * 3, ["Flor_Magenta", "Flor_Naranja", "Flor_Rosa"][k % 3], seg=5, anillos=3)


HOMBRO_D = Vector((HOMBRO, 0, HOMBRO_Z))
HOMBRO_I = Vector((-HOMBRO, 0, HOMBRO_Z))
CODO_D = Vector((1.28, -0.38, 3.0))
MUNECA_D = Vector((1.36, -0.5, 1.95))
CODO_I = Vector((-1.9, 0.0, 3.45))
MUNECA_I = Vector((-1.06, -0.3, 2.86))


def cuerpo(bm):
    antes = set(bm.verts)
    cilindro(bm, (0, 0, 4.45), (0, 0, 5.0), 0.15, 0.13, "Hueso", lados=8)
    for z in (4.62, 4.78, 4.92):
        esfera(bm, (0, 0.04, z), (0.18, 0.17, 0.06), "Hueso", seg=8, anillos=4)
    # Costillas que se ven por el escote, el esternon y las claviculas
    for k, z in enumerate((4.02, 4.17, 4.32, 4.46)):
        r = 0.64 - 0.04 * k
        pts = [Vector((math.cos(a) * r, math.sin(a) * r, z - 0.06 * abs(math.cos(a))))
               for a in (math.radians(-90 + t) for t in (-62, -42, -22, 0, 22, 42, 62))]
        linea(bm, pts, 0.035, "Hueso", lados=5)
    cilindro(bm, (0, -0.64, 3.95), (0, -0.56, 4.5), 0.05, 0.045, "Hueso", lados=5)
    for lado in (-1, 1):
        cilindro(bm, (0.06 * lado, -0.48, 4.52), (0.8 * lado, -0.18, 4.48), 0.055, 0.045, "Hueso", lados=5)
    doblar_bm(bm, [v for v in bm.verts if v not in antes])
    # Brazos largos (la derecha cuelga hasta la rodilla, la izquierda en la cadera) desde donde
    # quedo el hombro con la joroba
    brazo(bm, doblar(HOMBRO_D), CODO_D, MUNECA_D, Vector((0.05, -0.15, -1)), Vector((-1, 0.1, 0)))
    brazo(bm, doblar(HOMBRO_I), CODO_I, MUNECA_I, Vector((0.55, -0.45, -0.7)), Vector((0.6, 0.3, -0.2)))
    # Cuerda amarrada en el brazo derecho, abajo del codo
    d = (MUNECA_D - CODO_D).normalized()
    u = d.orthogonal().normalized()
    w = d.cross(u)
    for vuelta in range(3):
        c = CODO_D + d * (0.3 + 0.08 * vuelta)
        linea(bm, [c + (u * math.cos(a) + w * math.sin(a)) * 0.12 for a in (math.tau * i / 8 for i in range(8))], 0.022, "Cuerda", cerrada=True)
    # Piernas escondidas bajo la falda (el pisoton alza la derecha)
    for lado in (-1, 1):
        cadera = Vector((0.3 * lado, 0, 2.5))
        rodilla = Vector((0.4 * lado, -0.08, 1.3))
        tobillo = Vector((0.46 * lado, 0, 0.16))
        cilindro(bm, cadera, rodilla, 0.13, 0.1, "Hueso", lados=7)
        esfera(bm, rodilla, (0.13,) * 3, "Hueso", seg=7, anillos=5)
        cilindro(bm, rodilla, tobillo, 0.1, 0.08, "Hueso", lados=7)
        caja(bm, (0.46 * lado, -0.2, 0.07), (0.24, 0.5, 0.14), "Hueso")
        for k in range(3):
            a = Vector((0.46 * lado + (k - 1) * 0.07, -0.43, 0.06))
            cilindro(bm, a, a + Vector((0, -0.14, -0.03)), 0.03, 0.004, "Hueso", lados=4)


# --- El craneo, el peinado y la corona ---

CABEZA = Vector((0, 0, 5.42))
FLORES = [((-0.5, -0.24, 0.42), "Flor_Magenta"), ((-0.18, -0.24, 0.66), "Flor_Morada"),
          ((0.19, -0.22, 0.66), "Flor_Naranja"), ((0.52, -0.24, 0.42), "Flor_Rosa")]
CEMPASUCHIL = [(-0.66, -0.05, 0.25), (-0.34, -0.3, 0.6), (0.0, -0.28, 0.74), (0.36, -0.28, 0.6),
               (0.68, -0.05, 0.25), (-0.3, 0.2, 0.62), (0.3, 0.2, 0.62)]


def craneo(bm):
    verts = esfera(bm, CABEZA, (0.6, 0.62, 0.62), "Hueso", seg=18, anillos=12)
    for v in verts:
        rel = v.co - CABEZA
        n = rel.normalized()
        # Cuencas hondas, el hueco de la nariz, pomulos salidos y la ceja de hueso
        for centro, hondo, radio in (((-0.23, -0.55, 0.06), 0.2, 0.24), ((0.23, -0.55, 0.06), 0.2, 0.24),
                                     ((0, -0.6, -0.15), 0.07, 0.12)):
            d = (rel - Vector(centro)).length
            if d < radio:
                v.co -= n * hondo * (1 - d / radio)
        for centro in ((-0.42, -0.42, -0.14), (0.42, -0.42, -0.14)):
            d = (rel - Vector(centro)).length
            if d < 0.2:
                v.co += n * 0.07 * (1 - d / 0.2)
        if rel.y < -0.4 and 0.14 < rel.z < 0.26 and abs(rel.x) < 0.45:
            v.co += Vector((0, -0.05, 0.01))
    # El brillo de Serenol en el fondo de las cuencas
    for x in (-0.22, 0.22):
        esfera(bm, CABEZA + Vector((x, -0.5, 0.05)), (0.075, 0.04, 0.075), "Brillo", seg=6, anillos=4)
    # Quijada colgando, con dientes grandes arriba y abajo
    esfera(bm, CABEZA + Vector((0, -0.22, -0.62)), (0.41, 0.33, 0.16), "Hueso", seg=12, anillos=6)
    for k in range(8):
        x = (k - 3.5) * 0.078
        y = -0.56 + 0.45 * x * x
        caja(bm, CABEZA + Vector((x, y, -0.31)), (0.066, 0.06, 0.16), "Hueso")
        caja(bm, CABEZA + Vector((x, y + 0.03, -0.55)), (0.062, 0.055, 0.14), "Hueso")
    # El cabello: casquete, chongo trenzado y la trenza gruesa hasta la cintura
    esfera(bm, CABEZA + Vector((0, 0.16, 0.16)), (0.65, 0.59, 0.59), "Cabello", seg=14, anillos=8)
    chongo = CABEZA + Vector((0, 0.64, 0.08))
    esfera(bm, chongo, (0.4, 0.36, 0.38), "Cabello", seg=10, anillos=6)
    for k in range(9):
        a = math.tau * k / 9
        esfera(bm, chongo + Vector((math.cos(a) * 0.36, 0.08, math.sin(a) * 0.36)), (0.13, 0.12, 0.13), "Cabello", seg=6, anillos=4)
    arriba = CABEZA + Vector((0, 0.9, -0.1))
    abajo = Vector((0, 1.1, 2.9))
    pasos = 12
    for k in range(pasos):
        t = (k + 0.5) / pasos
        p = arriba.lerp(abajo, t) + Vector((0.05 * (1 if k % 2 else -1), 0, 0))
        esfera(bm, p, (0.16 - 0.04 * t, 0.12, 0.17), "Cabello", seg=7, anillos=4)
    esfera(bm, abajo + Vector((0, 0, -0.14)), (0.08,) * 3, "Flor_Magenta", seg=6, anillos=4)
    # Las cuatro flores grandes (los puntos debiles) y los cempasuchiles chicos entre ellas
    for (ofs, nombre) in FLORES:
        flor(bm, CABEZA + Vector(ofs), Vector(ofs) + Vector((0, -0.5, 0)), 0.3, nombre)
    for ofs in CEMPASUCHIL:
        flor(bm, CABEZA + Vector(ofs), Vector(ofs) + Vector((0, -0.2, 0.2)), 0.13, "Flor_Naranja", capas=2)
    # Sartas de cempasuchil que cuelgan junto a la cara, y los aretes de pompones
    for lado in (-1, 1):
        for k in range(6):
            p = CABEZA + Vector((0.7 * lado, -0.12, 0.1 - 0.19 * k))
            esfera(bm, p, (0.08,) * 3, "Flor_Naranja", seg=6, anillos=4)
        base = CABEZA + Vector((0.6 * lado, -0.02, -0.32))
        for k, nombre in enumerate(["Verde", "Flor_Naranja", "Flor_Rosa"]):
            esfera(bm, base + Vector((0, 0, -0.19 * k)), (0.1,) * 3, nombre, seg=7, anillos=5)
    doblar_bm(bm)


# --- El armazon y el nudo ---

def carrizo(bm):
    varas = 8
    torso = [(Vector((math.cos(a) * 0.7, math.sin(a) * 0.7, 2.65)), Vector((math.cos(a) * 0.55, math.sin(a) * 0.55, 4.4)))
             for a in (math.tau * i / varas for i in range(varas))]
    for a, b in torso:
        cilindro(bm, a, b, 0.035, 0.03, "Carrizo", lados=4)
    for t in (0.2, 0.65):
        linea(bm, [a.lerp(b, t) for a, b in torso], 0.025, "Carrizo", cerrada=True)
    falda = 10
    for i in range(falda):
        a = math.tau * (i + 0.5) / falda
        cilindro(bm, (math.cos(a) * 1.45, math.sin(a) * 1.45, 0.15), (math.cos(a) * 0.78, math.sin(a) * 0.78, 2.5), 0.04, 0.035, "Carrizo", lados=4)
    for z, r in ((0.6, 1.36), (1.6, 1.12)):
        linea(bm, [Vector((math.cos(math.tau * i / 12) * r, math.sin(math.tau * i / 12) * r, z)) for i in range(12)],
              0.03, "Carrizo", cerrada=True)
    # Amarres de alambre en los cruces
    for a, b in torso[::2]:
        c = a.lerp(b, 0.2)
        linea(bm, [c + Vector((math.cos(t) * 0.06, math.sin(t) * 0.06, 0.03 * math.sin(t * 2))) for t in (math.tau * i / 6 for i in range(6))],
              0.008, "Alambre", lados=3, cerrada=True)
    doblar_bm(bm)


NUDO = Vector((0, -0.22, 3.7))


def nudo(bm):
    torsos = [((-0.2, 0.0, 0.08), (0.27, 0.2, 0.36)), ((0.22, -0.05, -0.06), (0.26, 0.2, 0.33)),
              ((0.0, 0.06, 0.32), (0.25, 0.19, 0.3))]
    for ofs, r in torsos:
        esfera(bm, NUDO + Vector(ofs), r, "Nudo", seg=10, anillos=6)
    for ofs in ((-0.35, -0.05, 0.42), (0.38, -0.1, 0.25), (0.05, -0.12, 0.62)):
        esfera(bm, NUDO + Vector(ofs), (0.14, 0.13, 0.15), "Nudo", seg=8, anillos=5)
        # Ojos lechosos que brillan tantito
        for x in (-0.05, 0.05):
            esfera(bm, NUDO + Vector(ofs) + Vector((x, -0.12, 0.02)), (0.025,) * 3, "Brillo", seg=4, anillos=3)
    for a, b in (((-0.3, -0.1, 0.0), (-0.75, -0.3, 0.25)), ((0.3, -0.15, 0.1), (0.7, -0.35, -0.2)),
                 ((0.0, -0.1, -0.2), (0.15, -0.45, -0.5)), ((-0.1, -0.1, 0.45), (-0.45, -0.4, 0.75))):
        cilindro(bm, NUDO + Vector(a), NUDO + Vector(b), 0.07, 0.05, "Nudo", lados=6)
        for k in range(3):
            p = NUDO + Vector(b)
            cilindro(bm, p, p + (Vector(b) - Vector(a)).normalized() * 0.12 + Vector(((k - 1) * 0.04, 0, (k - 1) * 0.04)), 0.02, 0.008, "Nudo", lados=4)
    doblar_bm(bm)


def armar():
    sc = preparar_escena()
    mats = materiales()
    piezas = {}
    for nombre, hacer in (("Vestido", vestido), ("Cuerpo", cuerpo), ("Craneo", craneo), ("Carrizo", carrizo), ("Nudo", nudo)):
        bm = bmesh.new()
        hacer(bm)
        if nombre == "Vestido":
            doblar_bm(bm)
        piezas[nombre] = objeto(sc, nombre, bm, mats)
    bm = bmesh.new()
    vestido(bm)
    roto(bm)
    doblar_bm(bm)
    piezas["Vestido_Roto"] = objeto(sc, "Vestido_Roto", bm, mats)
    # Como empieza en el juego: lo de las fases 2 y 3 escondido
    for nombre in ("Vestido_Roto", "Carrizo", "Nudo"):
        piezas[nombre].hide_set(True)
        piezas[nombre].hide_render = True
    cuenta = {}
    for nombre, ob in piezas.items():
        cuenta[nombre] = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        print("%-13s %5d tris" % (nombre, cuenta[nombre]))
    fase1 = cuenta["Vestido"] + cuenta["Cuerpo"] + cuenta["Craneo"]
    fase2 = cuenta["Vestido_Roto"] + cuenta["Cuerpo"] + cuenta["Craneo"] + cuenta["Carrizo"]
    fase3 = cuenta["Vestido_Roto"] + cuenta["Cuerpo"] + cuenta["Carrizo"] + cuenta["Nudo"]
    print("a la vez: fase 1 %d, fase 2 %d, fase 3 %d tris" % (fase1, fase2, fase3))
    return piezas


# catrina_alta.py carga este archivo solo por sus funciones (SOLO_FUNCIONES = True)
if not globals().get("SOLO_FUNCIONES"):
    armar()
