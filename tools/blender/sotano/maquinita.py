# El adorno de la maquinita de frutas (scripts/map/Maquinita.gd), hecho en Blender: lo que la malla
# del juego no tiene y no necesita el shader. La malla que juega (focos, contadores, botones) se
# queda como esta, porque ps1_maquinita.gdshader lee sus UV del atlas y sus colores de vertice;
# esto se le pega encima como hijo (Maquinita._adorno):
#   copete arqueado con "CÓCTEL DE FRUTAS" y una fila de focos, una fresa de caricatura arriba,
#   molduras de cromo en las esquinas y la repisa, lamina antiderrapante al pie, calcomanias en los
#   costados y etiquetas, la chapa de la puerta, el monedero del costado y el cable.
# Exporta models/maquinita/adorno_frutas.glb. Dos materiales: "adorno_frutas" (un atlas,
# textures/maquinita/adorno_frutas.png de arte.py: dibujos y colores lisos) y "foco_frutas".
#   (en un archivo nuevo y vacio, o en adorno_frutas.blend)
#   R = r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender\sotano"
#   exec(open(R + r"\maquinita.py", encoding="utf-8").read(), {"__name__": "maquinita"})
# Coordenadas de Godot (x, y arriba, z al frente), como Maquinita.gd: sus medidas van aqui igual.

import bpy
import bmesh
import math
import os
from mathutils import Vector

RAIZ = os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito")
SALIDA = os.path.join(RAIZ, "models", "maquinita")

# Maquinita.gd
ANCHO, FONDO, ALTO, ALTO_HOMBRO, PANEL_ABAJO = 0.64, 0.6, 1.98, 1.86, 1.16
RAMPA_HASTA_Z = 0.06
FRENTE_ABAJO = 0.2         # z del frente de abajo (Maquinita.malla: pata)
REPISA = 0.86              # y de la repisa
RIEL = 0.018               # el riel dorado de los lados (Maquinita.malla) sobresale esto arriba de la repisa

# Regiones del atlas (u0, v0, u1, v1; v hacia arriba)
COPETE = (0.0, 0.78, 1.0, 1.0)
COSTADO_ALTO = (0.0, 0.25, 0.5, 0.75)
COSTADO_BAJO = (0.5, 0.25, 1.0, 0.75)
ETIQUETAS = [(k * 0.25 + 0.01, 0.01, k * 0.25 + 0.24, 0.24) for k in range(3)]
ROJO = (0.79, 0.16, 0.83, 0.21)
VERDE = (0.92, 0.16, 0.96, 0.21)
CROMO = (0.79, 0.04, 0.83, 0.09)
NEGRO = (0.92, 0.04, 0.96, 0.09)


def _b(p):
    return Vector((p[0], -p[2], p[1]))


def _alto_panel(x):
    u = x / (ANCHO / 2.0)
    return ALTO - (ALTO - ALTO_HOMBRO) * u * u


def _z_panel(y):
    return RAMPA_HASTA_Z + (0.0 - RAMPA_HASTA_Z) * (y - PANEL_ABAJO) / (ALTO - PANEL_ABAJO)


class Malla:
    """Junta todo en una malla con dos materiales (0: atlas, 1: focos)."""
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UV")

    def cara(self, pts, uvs, mat=0):
        vs = [self.bm.verts.new(_b(p)) for p in pts]
        f = self.bm.faces.new(vs)
        f.material_index = mat
        for loop, uv in zip(f.loops, uvs):
            loop[self.uv].uv = uv
        return f

    def caja(self, a, b, rect, mat=0):
        (x0, y0, z0), (x1, y1, z1) = a, b
        u0, v0, u1, v1 = rect
        uvs = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
        P = lambda x, y, z: (x, y, z)
        for pts in (
            [P(x0, y0, z1), P(x1, y0, z1), P(x1, y1, z1), P(x0, y1, z1)],   # frente
            [P(x1, y0, z0), P(x0, y0, z0), P(x0, y1, z0), P(x1, y1, z0)],   # atras
            [P(x0, y0, z0), P(x0, y0, z1), P(x0, y1, z1), P(x0, y1, z0)],   # izq
            [P(x1, y0, z1), P(x1, y0, z0), P(x1, y1, z0), P(x1, y1, z1)],   # der
            [P(x0, y1, z1), P(x1, y1, z1), P(x1, y1, z0), P(x0, y1, z0)],   # arriba
            [P(x0, y0, z0), P(x1, y0, z0), P(x1, y0, z1), P(x0, y0, z1)],   # abajo
        ):
            self.cara(pts, uvs, mat)

    def plano(self, centro, ancho, alto, normal, rect, mat=0):
        n = Vector(normal).normalized()
        arriba = Vector((0, 1, 0)) if abs(n.y) < 0.9 else Vector((0, 0, -1))
        lado = arriba.cross(n).normalized()
        arriba = n.cross(lado).normalized()
        c = Vector(centro)
        pts = [c - lado * ancho / 2 - arriba * alto / 2, c + lado * ancho / 2 - arriba * alto / 2,
               c + lado * ancho / 2 + arriba * alto / 2, c - lado * ancho / 2 + arriba * alto / 2]
        u0, v0, u1, v1 = rect
        self.cara([tuple(p) for p in pts], [(u0, v0), (u1, v0), (u1, v1), (u0, v1)], mat)

    def tubo(self, a, b, r, rect, lados=6, mat=0):
        a, b = Vector(a), Vector(b)
        d = (b - a).normalized()
        x = d.cross(Vector((0, 0, 1)))
        if x.length < 0.01:
            x = d.cross(Vector((1, 0, 0)))
        x = x.normalized()
        y = d.cross(x).normalized()
        anillo = lambda c: [tuple(c + (x * math.cos(t) + y * math.sin(t)) * r) for t in (i * math.tau / lados for i in range(lados))]
        ra, rb = anillo(a), anillo(b)
        u0, v0, u1, v1 = rect
        uvs = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
        for i in range(lados):
            j = (i + 1) % lados
            self.cara([ra[i], ra[j], rb[j], rb[i]], uvs, mat)

    def esfera(self, c, r, rect, mat=0, escala=(1, 1, 1), lados=8, anillos=5):
        c = Vector(c)
        u0, v0, u1, v1 = rect
        uvs = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
        pts = []
        for k in range(anillos + 1):
            fi = math.pi * k / anillos
            fila = []
            for i in range(lados):
                t = math.tau * i / lados
                fila.append(tuple(c + Vector((math.sin(fi) * math.cos(t) * r * escala[0], math.cos(fi) * r * escala[1], math.sin(fi) * math.sin(t) * r * escala[2]))))
            pts.append(fila)
        for k in range(anillos):
            for i in range(lados):
                j = (i + 1) % lados
                quad = [pts[k][i], pts[k][j], pts[k + 1][j], pts[k + 1][i]]
                if k == 0:
                    self.cara([quad[0], quad[2], quad[3]], uvs[:3], mat)
                elif k == anillos - 1:
                    self.cara([quad[0], quad[1], quad[2]], uvs[:3], mat)
                else:
                    self.cara(quad, uvs, mat)

    def objeto(self, nombre, materiales):
        me = bpy.data.meshes.new(nombre)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.0001)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for m in materiales:
            me.materials.append(m)
        ob = bpy.data.objects.new(nombre, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def material(nombre, color, emision=0.0):
    m = bpy.data.materials.get(nombre) or bpy.data.materials.new(nombre)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    if emision:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emision
    return m


def adorno():
    m = Malla()
    x = ANCHO / 2.0
    atras = -FONDO / 2.0
    # 1. El copete: una tira arqueada sobre el arco del panel, 0.2 de alto, con su frente al atlas
    tiras = 14
    alto_copete = 0.2
    grueso = 0.07
    for i in range(tiras):
        xa = -x + ANCHO * i / tiras
        xb = -x + ANCHO * (i + 1) / tiras
        ya, yb = _alto_panel(xa) - 0.01, _alto_panel(xb) - 0.01
        za, zb = _z_panel(ya) + 0.005, _z_panel(yb) + 0.005
        ua, ub = COPETE[0] + (COPETE[2] - COPETE[0]) * i / tiras, COPETE[0] + (COPETE[2] - COPETE[0]) * (i + 1) / tiras
        m.cara([(xa, ya, za), (xb, yb, zb), (xb, yb + alto_copete, zb), (xa, ya + alto_copete, za)],
               [(ua, COPETE[1]), (ub, COPETE[1]), (ub, COPETE[3]), (ua, COPETE[3])])
        # canto de arriba y espalda del copete (rojo liso)
        m.cara([(xa, ya + alto_copete, za), (xb, yb + alto_copete, zb), (xb, yb + alto_copete, zb - grueso), (xa, ya + alto_copete, za - grueso)],
               [(ROJO[0], ROJO[1]), (ROJO[2], ROJO[1]), (ROJO[2], ROJO[3]), (ROJO[0], ROJO[3])])
        m.cara([(xb, yb, zb - grueso), (xa, ya, za - grueso), (xa, ya + alto_copete, za - grueso), (xb, yb + alto_copete, zb - grueso)],
               [(ROJO[0], ROJO[1]), (ROJO[2], ROJO[1]), (ROJO[2], ROJO[3]), (ROJO[0], ROJO[3])])
    for lado in (-1, 1):
        xl = lado * x
        y0 = _alto_panel(xl) - 0.01
        z0 = _z_panel(y0) + 0.005
        m.cara([(xl, y0, z0 - grueso), (xl, y0, z0), (xl, y0 + alto_copete, z0), (xl, y0 + alto_copete, z0 - grueso)][::(1 if lado > 0 else -1)],
               [(ROJO[0], ROJO[1]), (ROJO[2], ROJO[1]), (ROJO[2], ROJO[3]), (ROJO[0], ROJO[3])])
    # Los focos por el canto del copete (material 1)
    for i in range(11):
        xf = -x + 0.03 + (ANCHO - 0.06) * i / 10
        yf = _alto_panel(xf) - 0.01 + alto_copete + 0.018
        m.esfera((xf, yf, _z_panel(yf - alto_copete) - 0.03), 0.018, (0, 0, 1, 1), mat=1, lados=6, anillos=4)
    # 2. La fresa de arriba: cuerpo rojo, hojas verdes y su rabito
    tope = ALTO - 0.01 + alto_copete
    m.esfera((0.0, tope + 0.11, -0.03), 0.1, ROJO, escala=(1.0, 1.15, 0.8), lados=10, anillos=6)
    for i in range(5):
        a = math.tau * i / 5
        m.tubo((0.0, tope + 0.22, -0.03), (math.cos(a) * 0.09, tope + 0.19, -0.03 + math.sin(a) * 0.07), 0.018, VERDE, lados=4)
    m.tubo((0.0, tope + 0.21, -0.03), (0.0, tope + 0.27, -0.03), 0.01, VERDE, lados=4)
    for i in range(7):    # semillas
        a = -0.9 + i * 0.3
        m.esfera((math.sin(a) * 0.07, tope + 0.06 + (i % 3) * 0.04, 0.03 + math.cos(a) * 0.02), 0.008, (0.95, 0.85, 0.99, 0.95), lados=4, anillos=3)
    # 3. Molduras de cromo: esquinas del frente de abajo, la repisa y las orillas del panel
    for lado in (-1, 1):
        m.tubo((lado * (x + 0.004), 0.08, FRENTE_ABAJO), (lado * (x + 0.004), REPISA, FRENTE_ABAJO), 0.012, CROMO)
        m.tubo((lado * (x + 0.004), PANEL_ABAJO, RAMPA_HASTA_Z), (lado * (x + 0.004), ALTO_HOMBRO - 0.02, _z_panel(ALTO_HOMBRO)), 0.012, CROMO)
    m.tubo((-x, REPISA, FRENTE_ABAJO + 0.004), (x, REPISA, FRENTE_ABAJO + 0.004), 0.012, CROMO)
    m.tubo((-x, PANEL_ABAJO - 0.005, RAMPA_HASTA_Z + 0.01), (x, PANEL_ABAJO - 0.005, RAMPA_HASTA_Z + 0.01), 0.01, CROMO)
    # 4. Lamina antiderrapante al pie (frente y costados), con un patron de rombos de cromo y negro
    m.caja((-x - 0.006, 0.0, FRENTE_ABAJO - 0.002), (x + 0.006, 0.08, FRENTE_ABAJO + 0.008), CROMO)
    for lado in (-1, 1):
        m.caja((lado * x - 0.004, 0.0, atras), (lado * x + 0.004, 0.08, FRENTE_ABAJO), CROMO)
    for i in range(16):
        cx = -x + 0.03 + i * 0.039
        for fila in range(2):
            cy = 0.025 + fila * 0.03
            m.cara([(cx, cy - 0.008, FRENTE_ABAJO + 0.0085), (cx + 0.012, cy, FRENTE_ABAJO + 0.0085),
                    (cx, cy + 0.008, FRENTE_ABAJO + 0.0085), (cx - 0.012, cy, FRENTE_ABAJO + 0.0085)],
                   [(NEGRO[0], NEGRO[1]), (NEGRO[2], NEGRO[1]), (NEGRO[2], NEGRO[3]), (NEGRO[0], NEGRO[3])])
    # 5. Calcomanias de los costados y etiquetas del frente
    for lado in (-1, 1):
        n = (lado, 0, 0)
        m.plano((lado * (x + 0.003), 0.47, -0.05), 0.42, 0.66, n, COSTADO_BAJO)
        m.plano((lado * (x + RIEL + 0.003), 1.5, -0.15), 0.26, 0.5, n, COSTADO_ALTO)
        m.plano((lado * (x + 0.003), 1.0, -0.12), 0.11, 0.11, n, ETIQUETAS[1])
    m.plano((0.2, 0.15, FRENTE_ABAJO + 0.003), 0.1, 0.1, (0, 0, 1), ETIQUETAS[0])
    m.plano((-0.22, 0.15, FRENTE_ABAJO + 0.003), 0.1, 0.1, (0, 0, 1), ETIQUETAS[2])
    # 6. La chapa de la puerta y el monedero del costado derecho
    m.caja((0.19, 0.62, FRENTE_ABAJO), (0.24, 0.7, FRENTE_ABAJO + 0.02), CROMO)
    m.caja((0.208, 0.645, FRENTE_ABAJO + 0.02), (0.222, 0.675, FRENTE_ABAJO + 0.024), NEGRO)
    m.caja((x + RIEL, 1.3, -0.12), (x + RIEL + 0.05, 1.46, -0.02), CROMO)
    m.caja((x + RIEL + 0.05, 1.37, -0.09), (x + RIEL + 0.054, 1.42, -0.05), NEGRO)
    # 7. El cable, de la espalda al piso
    m.tubo((0.15, 0.3, atras - 0.005), (0.15, 0.02, atras - 0.08), 0.008, NEGRO, lados=4)
    m.tubo((0.15, 0.02, atras - 0.08), (0.35, 0.01, atras - 0.4), 0.008, NEGRO, lados=4)
    atlas = material("adorno_frutas", (1, 1, 1))
    foco = material("foco_frutas", (1.0, 0.9, 0.5), emision=3.0)
    return m.objeto("Adorno_frutas", [atlas, foco])


def exportar(ob):
    os.makedirs(SALIDA, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(SALIDA, "adorno_frutas.glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="EXPORT")
    fuente = os.path.join(SALIDA, "fuente")
    os.makedirs(fuente, exist_ok=True)
    open(os.path.join(fuente, ".gdignore"), "w").close()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(fuente, "adorno_frutas.blend"))


if __name__ == "maquinita":
    if bpy.data.filepath and not bpy.data.filepath.endswith("adorno_frutas.blend"):
        raise RuntimeError("maquinita.py borraria " + bpy.data.filepath + ": abre un archivo nuevo primero")
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    # Los materiales tambien: uno con una textura de vista previa la metia al .glb
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)
    exportar(adorno())
    print("adorno de la maquinita listo")
