# Los dibujos de las cartas de EL GORDO, en 3D (docs/sistemas/sotano.md): un objeto low-poly por
# carta, hecho de primitivas con colores lisos, renderizado con Workbench (luz de estudio, contorno
# negro, sin suavizado) como pixel art con volumen. Sale textures/sotano/cartas_dibujos.png: 8 x 3
# casillas de 80 x 80 con fondo transparente, en el orden de scripts/sotano/Cartas.gd. El marco de
# la carta (cartas.png, arte.py) y el nombre (OlPleyUI) van aparte. Corre en un archivo nuevo:
#   R = r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender\sotano"
#   exec(open(R + r"\cartas3d.py", encoding="utf-8").read(), {"__name__": "cartas3d"})
# Con SOLO = (0, 1, 2) arma solo esas (para verlas); el render siempre es el atlas completo.
#
# En Blender: x a la derecha, z arriba, la camara (ortografica) en -Y viendo a +Y. Cada objeto se
# arma alrededor de (0, 0, 0) en una caja de ~0.8 y luego se mueve a su casilla.

import bpy
import bmesh
import math
import os
from mathutils import Matrix, Vector

RAIZ = os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito")
SALIDA = os.path.join(RAIZ, "textures", "sotano", "cartas_dibujos.png")
CASILLA = 80
COLUMNAS = 8
FILAS = 3


def mat(nombre, color):
    m = bpy.data.materials.get("c_" + nombre) or bpy.data.materials.new("c_" + nombre)
    m.diffuse_color = (*color, 1.0)
    return m


# Colores de todas las cartas
C = {
    "rojo": (0.8, 0.1, 0.08), "rojo_osc": (0.5, 0.05, 0.05), "naranja": (0.95, 0.5, 0.1), "amarillo": (1.0, 0.82, 0.15),
    "oro": (0.9, 0.68, 0.18), "verde": (0.2, 0.6, 0.2), "verde_osc": (0.08, 0.3, 0.1), "verde_claro": (0.45, 0.8, 0.3),
    "azul": (0.15, 0.35, 0.8), "azul_claro": (0.5, 0.75, 0.95), "morado": (0.45, 0.2, 0.65), "cafe": (0.45, 0.27, 0.12),
    "cafe_osc": (0.25, 0.14, 0.06), "piel": (0.85, 0.62, 0.45), "blanco": (0.95, 0.94, 0.9), "hueso": (0.92, 0.88, 0.75),
    "negro": (0.06, 0.06, 0.07), "gris": (0.55, 0.56, 0.58), "gris_osc": (0.28, 0.29, 0.3), "rosa": (0.95, 0.5, 0.65),
    "turquesa": (0.1, 0.65, 0.65), "zombi": (0.5, 0.6, 0.45), "vidrio": (0.65, 0.85, 0.95),
}


class Pieza:
    """Va juntando primitivas de una carta; al final se mueven todas juntas a su casilla."""
    def __init__(self, nombre):
        self.nombre = nombre
        self.obs = []

    def _ob(self, bm, color, donde, giro=(0, 0, 0), escala=(1, 1, 1)):
        me = bpy.data.meshes.new(self.nombre)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mat(color, C[color]))
        ob = bpy.data.objects.new(self.nombre, me)
        ob.location = donde
        ob.rotation_euler = [math.radians(a) for a in giro]
        ob.scale = escala
        bpy.context.scene.collection.objects.link(ob)
        self.obs.append(ob)
        return ob

    def bola(self, color, donde, r, escala=(1, 1, 1), giro=(0, 0, 0), lados=10):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=lados, v_segments=max(4, lados // 2 + 1), radius=r)
        return self._ob(bm, color, donde, giro, escala)

    def caja(self, color, donde, tam, giro=(0, 0, 0)):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        return self._ob(bm, color, donde, giro, tam)

    def tubo(self, color, donde, r, alto, giro=(0, 0, 0), r2=None, lados=8):
        """Cilindro (o cono con r2) de pie en z, centrado en `donde`."""
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=lados, radius1=r, radius2=r if r2 is None else r2, depth=alto)
        return self._ob(bm, color, donde, giro)

    def palo(self, color, a, b, r=0.02, lados=6):
        """Cilindro de a a b."""
        a, b = Vector(a), Vector(b)
        d = b - a
        ob = self.tubo(color, (a + b) / 2, r, d.length, lados=lados)
        ob.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        return ob

    def torno(self, color, perfil, donde=(0, 0, 0), lados=12):
        """Pieza de revolucion: perfil [(radio, z)] de abajo arriba."""
        bm = bmesh.new()
        anillos = []
        for r, z in perfil:
            if r <= 0:
                anillos.append([bm.verts.new((0, 0, z))])
            else:
                anillos.append([bm.verts.new((r * math.cos(k * math.tau / lados), r * math.sin(k * math.tau / lados), z)) for k in range(lados)])
        for a, b in zip(anillos, anillos[1:]):
            for k in range(lados):
                j = (k + 1) % lados
                if len(a) == 1 and len(b) > 1:
                    bm.faces.new((a[0], b[k], b[j]))
                elif len(b) == 1 and len(a) > 1:
                    bm.faces.new((a[k], a[j], b[0]))
                elif len(a) > 1:
                    bm.faces.new((a[k], a[j], b[j], b[k]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return self._ob(bm, color, donde)

    def plana(self, color, puntos, grueso=0.06, donde=(0, 0, 0), giro=(0, 0, 0)):
        """Una figura plana (x, z) con grosor en y: estrella, aleta, hoja."""
        bm = bmesh.new()
        frente = [bm.verts.new((x, -grueso / 2, z)) for x, z in puntos]
        atras = [bm.verts.new((x, grueso / 2, z)) for x, z in puntos]
        bm.faces.new(frente)
        bm.faces.new(list(reversed(atras)))
        n = len(puntos)
        for k in range(n):
            j = (k + 1) % n
            bm.faces.new((frente[k], frente[j], atras[j], atras[k]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return self._ob(bm, color, donde, giro)

    def poner(self, casilla, giro_z=0.0, escala=1.0, giro_y=0.0):
        col, fila = casilla % COLUMNAS, casilla // COLUMNAS
        centro = Vector((col + 0.5, 0.0, (FILAS / 2.0) - fila - 0.5))
        m = (Matrix.Translation(centro) @ Matrix.Rotation(math.radians(giro_y), 4, "Y")
             @ Matrix.Rotation(math.radians(giro_z), 4, "Z") @ Matrix.Scale(escala, 4))
        for ob in self.obs:
            ob.matrix_basis = m @ ob.matrix_basis


def estrella(r1, r2, puntas=5, a0=90):
    return [((r1 if k % 2 == 0 else r2) * math.cos(math.radians(a0 + k * 180 / puntas)),
             (r1 if k % 2 == 0 else r2) * math.sin(math.radians(a0 + k * 180 / puntas))) for k in range(puntas * 2)]


# --- Las 24 cartas (mismo orden que Cartas.gd) ---

def gallo(p):
    p.bola("rojo_osc", (0.02, 0, -0.02), 0.22, (1.25, 0.9, 1.0))
    p.bola("naranja", (0.2, 0, 0.18), 0.11)
    for k, c in enumerate(("verde_osc", "negro", "verde")):
        p.tubo(c, (-0.24, 0, 0.12 + k * 0.03), 0.06, 0.34, giro=(0, -30 - k * 18, 0), r2=0.0)
    for k in range(3):
        p.caja("rojo", (0.17 + k * 0.05, 0, 0.32 - abs(k - 1) * 0.02), (0.04, 0.03, 0.07))
    p.tubo("amarillo", (0.33, 0, 0.17), 0.035, 0.09, giro=(0, 90, 0), r2=0.0)
    p.bola("rojo", (0.26, 0, 0.08), 0.03, (0.8, 0.6, 1.4))
    for x in (-0.04, 0.08):
        p.palo("amarillo", (x, 0, -0.2), (x, 0, -0.36), 0.018)
        p.caja("amarillo", (x + 0.03, 0, -0.37), (0.09, 0.03, 0.02))
    p.bola("negro", (0.24, -0.08, 0.2), 0.018)


def diablito(p):
    p.bola("rojo", (0, 0, 0.02), 0.25, (1.0, 0.9, 1.05))
    for lado in (-1, 1):
        p.tubo("hueso", (lado * 0.14, 0, 0.28), 0.05, 0.16, giro=(0, lado * 25, 0), r2=0.0)
        p.bola("amarillo", (lado * 0.08, -0.2, 0.06), 0.045)
        p.bola("negro", (lado * 0.08, -0.24, 0.06), 0.02)
    p.caja("negro", (0, -0.22, -0.08), (0.14, 0.03, 0.025), giro=(0, 0, 0))
    p.tubo("negro", (0, -0.05, -0.26), 0.05, 0.12, giro=(180, 0, 0), r2=0.0)
    p.palo("negro", (0.3, 0, -0.38), (0.3, 0, 0.32), 0.015)
    for x in (-0.05, 0, 0.05):
        p.tubo("negro", (0.3 + x, 0, 0.36), 0.015, 0.08, r2=0.0)


def sirena(p):
    p.bola("piel", (-0.02, 0, 0.26), 0.1)
    p.bola("naranja", (-0.05, 0.02, 0.29), 0.11, (1.0, 1.0, 1.15))
    p.tubo("naranja", (-0.1, 0.02, 0.12), 0.07, 0.25, r2=0.03)
    p.tubo("piel", (0.0, 0, 0.06), 0.08, 0.2, r2=0.06)
    p.bola("morado", (-0.02, -0.04, 0.1), 0.05, (1.6, 1.0, 0.8))
    p.tubo("turquesa", (0.04, 0, -0.14), 0.09, 0.24, giro=(0, -15, 0), r2=0.05)
    p.tubo("turquesa", (0.13, 0, -0.3), 0.05, 0.16, giro=(0, -50, 0), r2=0.025)
    p.plana("verde", [(0, 0), (0.18, 0.08), (0.12, -0.02), (0.2, -0.12)], donde=(0.18, 0, -0.38))


def paraguas(p):
    p.tubo("morado", (0, 0, 0.18), 0.4, 0.22, r2=0.02, lados=8)
    p.tubo("negro", (0, 0, 0.32), 0.015, 0.08)
    p.palo("cafe_osc", (0, 0, 0.1), (0, 0, -0.32), 0.02)
    p.palo("cafe_osc", (0, 0, -0.32), (0.06, 0, -0.38), 0.022)
    p.palo("cafe_osc", (0.06, 0, -0.38), (0.12, 0, -0.32), 0.022)


def calavera(p):
    p.bola("hueso", (0, 0, 0.06), 0.26, (1.0, 0.9, 1.05))
    p.caja("hueso", (0, -0.03, -0.2), (0.3, 0.2, 0.12))
    for lado in (-1, 1):
        p.bola("negro", (lado * 0.1, -0.2, 0.05), 0.065)
    p.tubo("negro", (0, -0.22, -0.06), 0.035, 0.06, giro=(90, 0, 0), r2=0.0, lados=3)
    for k in range(5):
        p.caja("negro", (-0.1 + k * 0.05, -0.13, -0.2), (0.012, 0.02, 0.08))
    p.bola("rosa", (0.17, -0.12, 0.2), 0.04, (1.4, 1.0, 1.0))


def nopal(p):
    p.bola("verde", (0, 0, -0.18), 0.17, (0.85, 0.25, 1.15))
    p.bola("verde", (-0.16, 0, 0.1), 0.13, (0.85, 0.25, 1.1), giro=(0, 25, 0))
    p.bola("verde", (0.16, 0, 0.12), 0.13, (0.85, 0.25, 1.1), giro=(0, -25, 0))
    p.bola("verde_claro", (0.0, 0, 0.28), 0.1, (0.85, 0.25, 1.1))
    for x, z in ((-0.2, 0.28), (0.24, 0.3), (0.06, 0.4), (-0.06, 0.4)):
        p.bola("rojo", (x, 0, z), 0.045, (1.0, 1.0, 1.25))
    for x, z in ((0.0, -0.1), (-0.15, 0.1), (0.15, 0.12), (0.05, -0.25)):
        p.bola("amarillo", (x, -0.05, z), 0.012)


def luna(p):
    for k in range(9):
        a = math.radians(-70 + k * 17.5)
        r = 0.12 * (1.0 - abs(k - 4) / 6.0)
        p.bola("amarillo", (math.cos(a) * 0.28 - 0.1, 0, math.sin(a) * 0.32), r + 0.03)
    p.bola("negro", (0.08, -0.12, 0.08), 0.02)
    p.caja("rojo_osc", (0.12, -0.12, -0.05), (0.06, 0.02, 0.015))
    for x, z in ((0.3, 0.3), (0.32, -0.25), (0.18, 0.4)):
        p.plana("blanco", estrella(0.04, 0.016), donde=(x, 0, z))


def sol(p):
    for k in range(10):
        a = k * 36
        p.tubo("naranja", (math.cos(math.radians(a)) * 0.3, 0, math.sin(math.radians(a)) * 0.3), 0.06, 0.16,
               giro=(0, 90 - a, 0), r2=0.0)
    p.bola("amarillo", (0, 0, 0), 0.24, (1.0, 0.6, 1.0))
    for lado in (-1, 1):
        p.bola("negro", (lado * 0.08, -0.15, 0.05), 0.025)
        p.bola("rojo", (lado * 0.14, -0.13, -0.05), 0.03)
    p.caja("rojo_osc", (0, -0.15, -0.08), (0.1, 0.02, 0.02))


def corazon(p):
    for lado in (-1, 1):
        p.bola("rojo", (lado * 0.12, 0, 0.1), 0.17, (1.0, 0.7, 1.0))
    p.tubo("rojo", (0, 0, -0.12), 0.24, 0.36, giro=(180, 0, 0), r2=0.0, lados=12)
    p.bola("blanco", (-0.15, -0.1, 0.18), 0.04)
    p.palo("cafe_osc", (-0.38, 0, -0.3), (0.38, 0, 0.3), 0.015)
    p.tubo("gris", (0.4, 0, 0.32), 0.035, 0.08, giro=(0, -50, 0), r2=0.0)


def campana(p):
    p.torno("oro", [(0.3, -0.25), (0.28, -0.2), (0.18, -0.05), (0.15, 0.15), (0.1, 0.24), (0, 0.27)])
    p.bola("cafe_osc", (0, 0, -0.29), 0.06)
    p.palo("cafe_osc", (0, 0, 0.27), (0, 0, 0.38), 0.03)
    p.caja("cafe_osc", (0, 0, 0.4), (0.4, 0.06, 0.04))


def estrella_c(p):
    p.plana("amarillo", estrella(0.38, 0.16), grueso=0.12)
    p.plana("blanco", estrella(0.12, 0.05), grueso=0.13, donde=(-0.08, -0.01, 0.1))


def venado(p):
    p.bola("cafe", (0, 0, -0.04), 0.16, (1.6, 0.8, 0.9))
    for x in (-0.16, 0.16):
        for y in (-0.05, 0.05):
            p.palo("cafe_osc", (x, y, -0.12), (x, y, -0.38), 0.02)
    p.palo("cafe", (0.2, 0, 0.0), (0.27, 0, 0.18), 0.05)
    p.bola("cafe", (0.3, 0, 0.22), 0.07, (1.4, 0.9, 0.9))
    p.bola("negro", (0.4, -0.02, 0.21), 0.02)
    for lado in (-1, 1):
        p.palo("hueso", (0.28, lado * 0.04, 0.27), (0.24, lado * 0.12, 0.42), 0.012)
        p.palo("hueso", (0.25, lado * 0.09, 0.36), (0.32, lado * 0.15, 0.42), 0.01)
    p.bola("blanco", (-0.25, 0, 0.0), 0.04)


def rana(p):
    p.bola("verde", (0, 0, -0.08), 0.24, (1.2, 0.9, 0.75))
    for lado in (-1, 1):
        p.bola("verde", (lado * 0.12, -0.05, 0.1), 0.08)
        p.bola("blanco", (lado * 0.12, -0.11, 0.12), 0.045)
        p.bola("negro", (lado * 0.12, -0.15, 0.12), 0.022)
        p.bola("verde_osc", (lado * 0.26, 0, -0.24), 0.07, (1.6, 1.0, 0.5))
    p.caja("verde_osc", (0, -0.2, -0.04), (0.18, 0.02, 0.012))
    p.bola("verde_claro", (0, -0.12, -0.14), 0.1, (1.4, 0.5, 0.6))


def pescado(p):
    p.bola("azul", (-0.04, 0, 0), 0.22, (1.5, 0.45, 0.9))
    p.plana("azul_claro", [(0, 0), (0.18, 0.16), (0.12, 0), (0.18, -0.16)], grueso=0.04, donde=(0.28, 0, 0))
    p.plana("azul_claro", [(-0.1, 0), (0.05, 0.12), (0.12, 0)], grueso=0.03, donde=(-0.05, 0, 0.15))
    p.bola("blanco", (-0.26, -0.07, 0.04), 0.035)
    p.bola("negro", (-0.27, -0.09, 0.04), 0.018)
    for k in range(3):
        p.bola("azul_claro", (-0.32 - k * 0.04, 0, 0.18 + k * 0.08), 0.02 + k * 0.006)


def arana(p):
    p.bola("negro", (0, 0, -0.06), 0.16, (1.0, 0.8, 1.1))
    p.bola("negro", (0, 0, 0.14), 0.09)
    p.bola("rojo", (0, -0.13, -0.06), 0.045, (1.0, 0.4, 1.4))
    for lado in (-1, 1):
        p.bola("rojo", (lado * 0.035, -0.08, 0.17), 0.018)
        for k in range(4):
            z = 0.12 - k * 0.07
            rodilla = (lado * 0.26, 0, z + 0.12 - k * 0.03)
            p.palo("negro", (lado * 0.06, 0, z), rodilla, 0.014)
            p.palo("negro", rodilla, (lado * (0.34 + k * 0.01), 0, z - 0.2), 0.012)
    p.palo("gris", (0, 0, 0.22), (0, 0, 0.45), 0.004)


def rosa(p):
    p.palo("verde_osc", (0, 0, -0.4), (0.02, 0, 0.1), 0.02)
    for lado, z in ((-1, -0.15), (1, -0.05)):
        p.bola("verde", (lado * 0.1, 0, z), 0.08, (1.4, 0.3, 0.7), giro=(0, lado * 30, 0))
    p.bola("rojo_osc", (0.02, 0, 0.18), 0.16, (1.0, 0.9, 0.9))
    for k in range(5):
        a = math.radians(k * 72)
        p.bola("rojo", (0.02 + math.cos(a) * 0.1, -0.03, 0.2 + math.sin(a) * 0.08), 0.08)
    p.bola("rojo", (0.02, -0.08, 0.24), 0.07)


def cotorro(p):
    p.bola("verde", (0, 0, 0.0), 0.17, (0.9, 0.85, 1.25))
    p.bola("verde_claro", (0.04, 0, 0.24), 0.11)
    p.bola("rojo", (0.06, -0.02, 0.33), 0.06, (1.0, 1.0, 0.6))
    p.tubo("amarillo", (0.15, 0, 0.21), 0.04, 0.1, giro=(0, 110, 0), r2=0.0)
    p.bola("blanco", (0.08, -0.08, 0.27), 0.025)
    p.bola("negro", (0.09, -0.1, 0.27), 0.013)
    p.plana("azul", [(0, 0), (0.06, 0), (0.0, -0.34), (-0.06, -0.3)], grueso=0.05, donde=(-0.05, 0, -0.16))
    p.bola("rojo", (-0.1, -0.05, 0.02), 0.07, (0.6, 1.0, 1.4))
    p.palo("cafe_osc", (-0.3, 0, -0.22), (0.3, 0, -0.22), 0.025)


def corona(p):
    p.tubo("oro", (0, 0, -0.12), 0.28, 0.14, lados=12)
    for k in range(5):
        a = math.radians(-90 + (k - 2) * 32)
        x, y = math.cos(a) * 0.27, math.sin(a) * 0.27
        p.tubo("oro", (x, y, 0.04), 0.06, 0.2, r2=0.0, lados=6)
        p.bola("blanco", (x, y, 0.15), 0.025)
    for k, c in enumerate(("rojo", "azul", "verde", "rojo")):
        a = math.radians(-90 + (k - 1.5) * 32)
        p.bola(c, (math.cos(a) * 0.29, math.sin(a) * 0.29, -0.12), 0.035)


def apagado(p):
    p.bola("zombi", (0, 0, 0.04), 0.24, (0.95, 0.9, 1.1))
    for lado in (-1, 1):
        p.bola("negro", (lado * 0.09, -0.19, 0.08), 0.05)
        p.bola("rojo", (lado * 0.09, -0.23, 0.08), 0.015)
    p.bola("negro", (0.02, -0.2, -0.12), 0.07, (1.0, 0.5, 0.8))
    for k in range(3):
        p.caja("hueso", (-0.03 + k * 0.03, -0.24, -0.08), (0.02, 0.02, 0.03))
    for x in (-0.12, 0.0, 0.1):
        p.tubo("negro", (x, 0, 0.27), 0.04, 0.1, giro=(0, x * 200, 0), r2=0.0)
    p.caja("zombi", (0, 0, -0.32), (0.16, 0.12, 0.14))
    p.bola("rojo_osc", (0.15, -0.15, 0.17), 0.03, (1.5, 1.0, 1.0))


def pipa(p):
    p.caja("blanco", (0.27, 0, -0.06), (0.2, 0.3, 0.28))
    p.caja("azul_claro", (0.33, -0.15, 0.0), (0.08, 0.01, 0.1))
    p.tubo("azul", (-0.1, 0, -0.02), 0.15, 0.48, giro=(0, 90, 0), lados=12)
    p.caja("gris_osc", (0.02, 0, -0.2), (0.75, 0.3, 0.06))
    for x in (-0.25, 0.0, 0.27):
        p.tubo("negro", (x, -0.16, -0.25), 0.07, 0.06, giro=(90, 0, 0), lados=10)
    p.caja("blanco", (-0.1, -0.16, -0.02), (0.3, 0.005, 0.07))


def machete(p):
    # Derecho: la carta lo inclina entera (giro_y en CARTAS)
    p.plana("gris", [(-0.26, 0.06), (0.3, 0.08), (0.42, 0.0), (0.38, -0.07), (-0.26, -0.05)], grueso=0.03)
    p.plana("blanco", [(-0.26, 0.06), (0.3, 0.08), (0.3, 0.06), (-0.26, 0.04)], grueso=0.032)
    p.palo("negro", (-0.26, 0, 0.0), (-0.46, 0, 0.0), 0.04)
    for x in (-0.32, -0.4):
        p.bola("oro", (x, -0.04, 0.0), 0.013)


def garrafa(p):
    p.torno("vidrio", [(0, -0.36), (0.22, -0.36), (0.24, -0.3), (0.24, 0.12), (0.2, 0.2), (0.08, 0.28), (0.07, 0.34), (0, 0.34)])
    p.tubo("azul", (0, 0, 0.37), 0.075, 0.06)
    for z in (-0.2, 0.0):
        p.torno("azul_claro", [(0.245, z), (0.245, z + 0.03)])
    p.caja("blanco", (0, -0.24, -0.08), (0.2, 0.02, 0.12))


def camion(p):
    p.caja("naranja", (0, 0, 0), (0.78, 0.32, 0.36))
    p.caja("blanco", (0, 0, -0.12), (0.79, 0.33, 0.06))
    for k in range(4):
        p.caja("azul_claro", (-0.27 + k * 0.17, -0.165, 0.07), (0.12, 0.01, 0.12))
    p.caja("azul_claro", (0.4, 0, 0.07), (0.01, 0.26, 0.14))
    for x in (-0.24, 0.24):
        p.tubo("negro", (x, -0.17, -0.2), 0.075, 0.06, giro=(90, 0, 0), lados=10)
    p.caja("gris_osc", (0, 0, 0.2), (0.4, 0.2, 0.03))


def tinaco(p):
    p.torno("negro", [(0, -0.34), (0.26, -0.34), (0.28, -0.3), (0.28, 0.2), (0.24, 0.25), (0.12, 0.3), (0, 0.31)], lados=14)
    for z in (-0.18, -0.02, 0.14):
        p.torno("gris_osc", [(0.285, z), (0.285, z + 0.03)], lados=14)
    p.tubo("negro", (0, 0, 0.34), 0.11, 0.06, lados=12)
    p.caja("blanco", (0, -0.27, 0.0), (0.18, 0.02, 0.1))
    p.palo("gris", (0.27, -0.05, -0.28), (0.4, -0.05, -0.28), 0.02)


CARTAS = [("gallo", gallo, 20), ("diablito", diablito, 0), ("sirena", sirena, 15), ("paraguas", paraguas, 10),
          ("calavera", calavera, 15), ("nopal", nopal, 0), ("luna", luna, 0), ("sol", sol, 0),
          ("corazon", corazon, 10), ("campana", campana, 0), ("estrella", estrella_c, 0), ("venado", venado, 25),
          ("rana", rana, 15), ("pescado", pescado, 20), ("arana", arana, 0), ("rosa", rosa, 10),
          ("cotorro", cotorro, 20), ("corona", corona, 15), ("apagado", apagado, 15), ("pipa", pipa, 30),
          ("machete", machete, 0), ("garrafa", garrafa, 15), ("camion", camion, 30), ("tinaco", tinaco, 15)]


# Las que van mas grandes o inclinadas: nombre -> (escala, giro_y)
AJUSTES = {"sirena": (1.2, 0.0), "machete": (1.0, 30.0), "paraguas": (1.05, 0.0), "pescado": (1.1, 0.0)}


def armar(solo=None):
    for k, (nombre, hacer, giro) in enumerate(CARTAS):
        if solo is not None and k not in solo:
            continue
        p = Pieza("carta_%s" % nombre)
        hacer(p)
        escala, giro_y = AJUSTES.get(nombre, (1.0, 0.0))
        p.poner(k, giro_z=giro, escala=escala, giro_y=giro_y)


def render():
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_object_outline = True
    sc.display.shading.object_outline_color = (0.03, 0.02, 0.02)
    sc.display.shading.show_cavity = True
    sc.display.shading.cavity_type = "WORLD"
    sc.display.shading.show_shadows = False
    sc.display.shading.show_specular_highlight = False
    sc.display.render_aa = "OFF"
    sc.render.resolution_x = CASILLA * COLUMNAS
    sc.render.resolution_y = CASILLA * FILAS
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    cam = bpy.data.cameras.new("cartas_cam")
    cam.type = "ORTHO"
    cam.ortho_scale = COLUMNAS
    ob = bpy.data.objects.new("cartas_cam", cam)
    ob.location = (COLUMNAS / 2.0, -10.0, 0.0)
    ob.rotation_euler = (math.radians(90), 0, 0)
    sc.collection.objects.link(ob)
    sc.camera = ob
    sc.render.filepath = SALIDA
    bpy.ops.render.render(write_still=True)
    print("cartas3d:", SALIDA)


if __name__ == "cartas3d":
    if bpy.data.filepath:
        raise RuntimeError("cartas3d.py borraria " + bpy.data.filepath + ": abre un archivo nuevo primero")
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    armar(globals().get("SOLO"))
    render()
