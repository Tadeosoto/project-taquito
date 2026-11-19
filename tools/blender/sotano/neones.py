# Los neones del Sotano (docs/sistemas/sotano.md), de tubo como los de verdad: letras y figuras
# hechas de curvas con grosor (bevel), un halo mas grueso alrededor que brilla (asi se ve el
# resplandor sin prender el glow del ambiente), focos que se encienden por turnos y los soportes.
# Exporta models/sotano/neones.glb: un vacio "Neon_<nombre>" por letrero, viendo a +Z de Godot
# (Sotano.gd lo pone en su Marca_Neon_*). Corre en un archivo nuevo y vacio:
#   R = r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender\sotano"
#   exec(open(R + r"\neones.py", encoding="utf-8").read(), {"__name__": "neones"})
#
# Letra de bloque: la de Blender. La de mano: fonts/Pacifico.ttf (OFL, CREDITS.md), que
# sale mas chica que la de bloque al mismo tamano: por eso sus tamanos son mayores.
# Materiales: neon_<color> (el tubo), neon_<color>_halo (el resplandor) y foco_a / foco_b (los
# dos turnos de focos); SotanoPostImport.gd los vuelve materiales que brillan.
# En Blender todo se arma en el plano XZ (x a la derecha, z arriba) viendo a -Y.

import bpy
import bmesh
import math
import os

RAIZ = os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito")
SALIDA = os.path.join(RAIZ, "models", "sotano")
TUBO = 0.009          # radio del tubo (m de la escena)
HALO = 2.8            # el halo: tantas veces el tubo
HALO_TEXTO = 2.0      # en las letras, mas delgado: con 2.8 los colores se encimaban entre letras


def _ovalo(cx, cz, rx, rz, pasos=16, a0=0.0, a1=360.0):
    return [(cx + math.cos(math.radians(a0 + (a1 - a0) * k / pasos)) * rx, cz + math.sin(math.radians(a0 + (a1 - a0) * k / pasos)) * rz) for k in range(pasos + 1)]


# Letras de un trazo, en una caja de 1 de alto: letra -> (ancho, [rayas de (x, z)]). Solo las que
# usan los letreros; una que falte sale como espacio
TRAZOS = {
    "A": (0.62, [[(0, 0), (0.31, 1), (0.62, 0)], [(0.12, 0.38), (0.5, 0.38)]]),
    "B": (0.56, [[(0, 0), (0, 1), (0.36, 1), (0.5, 0.92), (0.52, 0.76), (0.44, 0.6), (0.3, 0.54), (0, 0.54)],
                 [(0.3, 0.54), (0.5, 0.46), (0.56, 0.28), (0.5, 0.08), (0.36, 0), (0, 0)]]),
    "D": (0.6, [[(0, 0), (0, 1), (0.3, 1), (0.5, 0.88), (0.6, 0.64), (0.6, 0.36), (0.5, 0.12), (0.3, 0), (0, 0)]]),
    "E": (0.52, [[(0.52, 1), (0, 1), (0, 0), (0.52, 0)], [(0, 0.52), (0.4, 0.52)]]),
    "G": (0.62, [[(0.6, 0.84), (0.46, 0.98), (0.3, 1), (0.12, 0.92), (0.02, 0.72), (0, 0.5), (0.02, 0.28), (0.12, 0.08),
                  (0.3, 0), (0.48, 0.04), (0.62, 0.18), (0.62, 0.45), (0.36, 0.45)]]),
    "H": (0.58, [[(0, 0), (0, 1)], [(0.58, 0), (0.58, 1)], [(0, 0.52), (0.58, 0.52)]]),
    "I": (0.12, [[(0.06, 0), (0.06, 1)]]),
    "K": (0.56, [[(0, 0), (0, 1)], [(0.56, 1), (0, 0.4)], [(0.2, 0.62), (0.58, 0)]]),
    "L": (0.5, [[(0, 1), (0, 0), (0.5, 0)]]),
    "N": (0.6, [[(0, 0), (0, 1), (0.6, 0), (0.6, 1)]]),
    "Ñ": (0.6, [[(0, 0), (0, 1), (0.6, 0), (0.6, 1)], [(0.04, 1.14), (0.18, 1.22), (0.4, 1.12), (0.56, 1.2)]]),
    "O": (0.64, [_ovalo(0.32, 0.5, 0.32, 0.5)]),
    "Ó": (0.64, [_ovalo(0.32, 0.5, 0.32, 0.5), [(0.26, 1.1), (0.42, 1.26)]]),
    "P": (0.56, [[(0, 0), (0, 1), (0.36, 1), (0.52, 0.9), (0.56, 0.74), (0.52, 0.6), (0.36, 0.5), (0, 0.5)]]),
    "R": (0.58, [[(0, 0), (0, 1), (0.36, 1), (0.52, 0.9), (0.56, 0.74), (0.52, 0.6), (0.36, 0.5), (0, 0.5)], [(0.3, 0.5), (0.58, 0)]]),
    "S": (0.56, [[(0.56, 0.85), (0.42, 0.98), (0.2, 0.98), (0.04, 0.86), (0.04, 0.66), (0.2, 0.54), (0.4, 0.47),
                  (0.56, 0.35), (0.56, 0.14), (0.4, 0.01), (0.16, 0.01), (0, 0.14)]]),
    "T": (0.6, [[(0, 1), (0.6, 1)], [(0.3, 1), (0.3, 0)]]),
    "2": (0.56, [[(0.02, 0.8), (0.14, 0.96), (0.32, 1), (0.5, 0.92), (0.56, 0.74), (0.48, 0.55), (0, 0), (0.58, 0)]]),
    "4": (0.6, [[(0.46, 0), (0.46, 1), (0, 0.3), (0.6, 0.3)]]),
    "!": (0.12, [[(0.06, 1), (0.06, 0.3)], _ovalo(0.06, 0.06, 0.04, 0.04, 6)]),
    "V": (0.6, [[(0, 1), (0.3, 0), (0.6, 1)]]),
    "C": (0.56, [_ovalo(0.32, 0.5, 0.32, 0.5, 14, 50, 310)]),
    "U": (0.56, [[(0, 1), (0, 0.3)] + _ovalo(0.28, 0.3, 0.28, 0.3, 8, 180, 360)[1:] + [(0.56, 1)]]),
}
FOCO = 0.018          # radio de un foco

COLORES = {
    "rosa": (1.0, 0.25, 0.75), "amarillo": (1.0, 0.85, 0.2), "morado": (0.6, 0.3, 1.0),
    "cian": (0.3, 0.9, 1.0), "rojo": (1.0, 0.2, 0.15), "verde": (0.3, 1.0, 0.45), "blanco": (1.0, 0.95, 0.9),
    "azul": (0.3, 0.4, 1.0),
}


def dado(cx, cz, r, giro=0.0):
    """Un dado de neon visto de esquina (como el letrero de AG): el contorno de seis lados, las tres
    aristas de en medio y los puntos de sus tres caras. Regresa (rayas, puntos)."""
    v = [(cx + r * math.cos(math.radians(30 + 60 * k + giro)), cz + r * math.sin(math.radians(30 + 60 * k + giro))) for k in range(6)]
    rayas = [v + [v[0]], [(cx, cz), v[1]], [(cx, cz), v[3]], [(cx, cz), v[5]]]
    def cara(a, b, c, d, puntos):
        # puntos en coordenadas (u, w) de 0 a 1 dentro del rombo a-b-c-d
        return [(a[0] + (b[0] - a[0]) * u + (d[0] - a[0]) * w, a[1] + (b[1] - a[1]) * u + (d[1] - a[1]) * w) for u, w in puntos]
    centro = (cx, cz)
    cinco = [(0.25, 0.25), (0.75, 0.25), (0.5, 0.5), (0.25, 0.75), (0.75, 0.75)]
    tres = [(0.25, 0.25), (0.5, 0.5), (0.75, 0.75)]
    seis = [(0.27, 0.22), (0.27, 0.5), (0.27, 0.78), (0.73, 0.22), (0.73, 0.5), (0.73, 0.78)]
    puntos = cara(centro, v[5], v[0], v[1], tres) + cara(centro, v[1], v[2], v[3], cinco) + cara(centro, v[3], v[4], v[5], seis)
    return rayas, puntos


def material(nombre, color):
    m = bpy.data.materials.get(nombre) or bpy.data.materials.new(nombre)
    m.diffuse_color = (*color, 1.0)
    return m


class Letrero:
    def __init__(self, nombre):
        self.nombre = nombre
        self.raiz = bpy.data.objects.new("Neon_" + nombre, None)
        self.raiz.empty_display_size = 0.2
        bpy.context.scene.collection.objects.link(self.raiz)
        self.n = 0
        self.focos = {"a": [], "b": []}

    def _poner(self, curva, color, grueso=TUBO, halo_veces=HALO, lleno=False):
        """La curva (en el plano XY de la curva) se para en XZ, se vuelve malla (tubo y halo) y se
        borra. `lleno`: letra rellena (de mano) en vez de tubo; su halo es un tubo por la orilla."""
        for halo in (False, True):
            if lleno and not halo:
                curva.bevel_depth = 0.0
                curva.extrude = 0.003
            else:
                curva.extrude = 0.0
                curva.bevel_depth = grueso * (halo_veces if halo else 1.0)
            curva.bevel_resolution = 0 if halo else 1
            ob = bpy.data.objects.new("tmp", curva)
            ob.rotation_euler = (math.radians(90), 0, 0)
            bpy.context.scene.collection.objects.link(ob)
            dg = bpy.context.evaluated_depsgraph_get()
            me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
            me.transform(ob.matrix_world)
            me.materials.clear()
            me.materials.append(material("neon_%s%s" % (color, "_halo" if halo else ""), COLORES[color]))
            bpy.data.objects.remove(ob, do_unlink=True)
            pieza = bpy.data.objects.new("%s_%02d%s" % (self.raiz.name, self.n, "_halo" if halo else ""), me)
            pieza.parent = self.raiz
            bpy.context.scene.collection.objects.link(pieza)
        bpy.data.curves.remove(curva)
        self.n += 1

    def texto(self, cuerpo, x, z, tam, color, fuente=None, grueso=TUBO, lleno=False):
        cu = bpy.data.curves.new("t", "FONT")
        cu.body = cuerpo
        if fuente:
            cu.font = fuente
        cu.size = tam
        cu.align_x = "CENTER"
        cu.align_y = "CENTER"
        cu.resolution_u = 2
        cu.offset_x = x
        cu.offset_y = z
        self._poner(cu, color, grueso, HALO_TEXTO if lleno else HALO, lleno)

    def mano(self, cuerpo, x, z, tam, color, fuente):
        """Palabra de mano (Pacifico) rellena: se lee como una sola linea de tubo."""
        self.texto(cuerpo, x, z, tam, color, fuente, TUBO * 0.8, lleno=True)

    def trazo(self, texto, cx, cz, alto, color, separa=0.22, grueso=TUBO):
        """Letras de bloque de un solo trazo (TRAZOS), como el neon de verdad: un tubo por raya,
        centradas en (cx, cz), de `alto`; `separa` es el espacio entre letras (en altos)."""
        anchos = [TRAZOS[c][0] if c in TRAZOS else 0.35 for c in texto]
        total = (sum(anchos) + separa * (len(texto) - 1)) * alto
        x = cx - total / 2
        polis = []
        for c, ancho in zip(texto, anchos):
            for raya in (TRAZOS[c][1] if c in TRAZOS else []):
                polis.append([(x + px * alto, cz - alto / 2 + pz * alto) for px, pz in raya])
            x += (ancho + separa) * alto
        self.rayas(polis, color, grueso, HALO_TEXTO)

    def rayas(self, polis, color, grueso=TUBO, halo_veces=HALO):
        """Varias polilineas (x, z) en una sola malla de tubo (una curva con varias rayas)."""
        cu = bpy.data.curves.new("r", "CURVE")
        cu.dimensions = "3D"
        for puntos in polis:
            sp = cu.splines.new("POLY")
            sp.points.add(len(puntos) - 1)
            for q, (px, pz) in zip(sp.points, puntos):
                q.co = (px, pz, 0.0, 1.0)
            sp.use_cyclic_u = len(puntos) > 2 and puntos[0] == puntos[-1]
        self._poner(cu, color, grueso, halo_veces)

    def linea(self, puntos, color, cerrada=False, grueso=TUBO):
        """Un tubo por los puntos (x, z)."""
        cu = bpy.data.curves.new("l", "CURVE")
        cu.dimensions = "3D"      # en 3D el bevel es un tubo redondo (en 2D sale plano)
        sp = cu.splines.new("POLY")
        sp.points.add(len(puntos) - 1)
        for p, (x, z) in zip(sp.points, puntos):
            p.co = (x, z, 0.0, 1.0)
        sp.use_cyclic_u = cerrada
        self._poner(cu, color, grueso)

    def foco(self, x, z):
        self.focos["a" if len(self.focos["a"]) <= len(self.focos["b"]) else "b"].append((x, z))

    def marco(self, cx, cz, ancho, alto, radio, color, grueso=TUBO):
        self.linea(rectangulo(cx, cz, ancho, alto, radio), color, cerrada=True, grueso=grueso)

    def soportes(self, ancho, z0, z1):
        """Dos rieles negros detras de los tubos, hacia la pared (+Y en Blender)."""
        me = bpy.data.meshes.new(self.raiz.name + "_soporte")
        bm = bmesh.new()
        for z in (z0, z1):
            r = bmesh.ops.create_cube(bm, size=1.0)
            bmesh.ops.scale(bm, vec=(ancho, 0.015, 0.02), verts=r["verts"])
            bmesh.ops.translate(bm, vec=(0.0, 0.04, z), verts=r["verts"])
            for x in (-ancho * 0.4, ancho * 0.4):
                r = bmesh.ops.create_cube(bm, size=1.0)
                bmesh.ops.scale(bm, vec=(0.012, 0.04, 0.012), verts=r["verts"])
                bmesh.ops.translate(bm, vec=(x, 0.02, z), verts=r["verts"])
        bm.to_mesh(me)
        bm.free()
        me.materials.append(material("neon_soporte", (0.05, 0.05, 0.06)))
        ob = bpy.data.objects.new(self.raiz.name + "_soporte", me)
        ob.parent = self.raiz
        bpy.context.scene.collection.objects.link(ob)

    def cerrar(self):
        """Los focos, en dos mallas (un turno cada una: Sotano.gd las prende por turnos)."""
        for turno, puntos in self.focos.items():
            if not puntos:
                continue
            me = bpy.data.meshes.new("%s_focos_%s" % (self.raiz.name, turno))
            bm = bmesh.new()
            for x, z in puntos:
                r = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=FOCO)
                bmesh.ops.translate(bm, vec=(x, -0.01, z), verts=r["verts"])
            bm.to_mesh(me)
            bm.free()
            me.materials.append(material("foco_" + turno, COLORES["amarillo"]))
            ob = bpy.data.objects.new("%s_focos_%s" % (self.raiz.name, turno), me)
            ob.parent = self.raiz
            bpy.context.scene.collection.objects.link(ob)


def rectangulo(cx, cz, ancho, alto, radio, pasos=4):
    """Un rectangulo de esquinas redondas, como polilinea (x, z)."""
    pts = []
    esquinas = ((cx + ancho / 2 - radio, cz + alto / 2 - radio, 0), (cx - ancho / 2 + radio, cz + alto / 2 - radio, 90),
                (cx - ancho / 2 + radio, cz - alto / 2 + radio, 180), (cx + ancho / 2 - radio, cz - alto / 2 + radio, 270))
    for ex, ez, a0 in esquinas:
        for k in range(pasos + 1):
            a = math.radians(a0 + 90 * k / pasos)
            pts.append((ex + math.cos(a) * radio, ez + math.sin(a) * radio))
    return pts


def arco(cx, cz, r, a0, a1, pasos=16):
    return [(cx + math.cos(math.radians(a0 + (a1 - a0) * k / pasos)) * r, cz + math.sin(math.radians(a0 + (a1 - a0) * k / pasos)) * r) for k in range(pasos + 1)]


def limpiar():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)


def letreros():
    mano = bpy.data.fonts.load(os.path.join(RAIZ, "fonts", "Pacifico.ttf"), check_existing=True)

    # EL GORDO, sobre las maquinitas: marco morado con focos arriba y abajo, flechas a los lados
    s = Letrero("gordo")
    s.marco(0, 0, 2.0, 0.86, 0.14, "morado")
    s.trazo("EL GORDO", 0, 0.1, 0.3, "amarillo")
    s.mano("¡Suerte!", 0, -0.21, 0.42, "rosa", mano)
    for k in range(13):
        x = -0.84 + k * 0.14
        s.foco(x, 0.5)
        s.foco(x, -0.5)
    for lado in (-1, 1):
        s.linea([(lado * 1.02, 0.22), (lado * 1.16, 0.0), (lado * 1.02, -0.22)], "rosa")
    s.soportes(1.7, -0.43, 0.43)
    s.cerrar()

    # ¡PREMIO! en su liston, con un arco de focos encima (sobre las dos del muro sur)
    s = Letrero("premio")
    s.linea([(-0.78, 0.15), (0.78, 0.15), (0.64, 0.0), (0.78, -0.15), (-0.78, -0.15), (-0.64, 0.0)], "morado", cerrada=True)
    s.mano("¡Premio!", 0, 0.0, 0.4, "rosa", mano)
    s.linea(arco(0, 0.05, 0.62, 15, 165), "rosa")
    for a in range(20, 165, 13):
        s.foco(math.cos(math.radians(a)) * 0.54, 0.05 + math.sin(math.radians(a)) * 0.54)
    s.soportes(1.3, -0.15, 0.15)
    s.cerrar()

    # PÓKER: los cuatro palos arriba, la palabra en su marco y "Texas" de mano abajo
    s = Letrero("poker")
    for k, (palo, color) in enumerate((("♠", "morado"), ("♥", "rosa"), ("♦", "rosa"), ("♣", "morado"))):
        s.texto(palo, -0.45 + k * 0.3, 0.42, 0.22, color)
    s.marco(0, 0.06, 1.3, 0.42, 0.12, "amarillo")
    s.trazo("PÓKER", 0, 0.05, 0.24, "amarillo")
    s.mano("Texas", 0, -0.31, 0.42, "rosa", mano)
    s.linea([(-0.65, -0.52), (0.65, -0.52)], "morado")
    s.soportes(1.1, -0.15, 0.27)
    s.cerrar()

    # ABIERTO 24 HRS
    s = Letrero("abierto")
    s.marco(0, 0, 1.4, 0.6, 0.1, "cian")
    s.trazo("ABIERTO", 0, 0.11, 0.18, "verde")
    s.trazo("24 HRS", 0, -0.15, 0.16, "rojo")
    s.soportes(1.2, -0.3, 0.3)
    s.cerrar()

    # Tecatl de mano con su tarro espumoso
    s = Letrero("barra")
    s.mano("Tecatl", 0.2, 0.02, 0.6, "rojo", mano)
    s.linea(rectangulo(-0.6, -0.04, 0.3, 0.42, 0.04), "amarillo", cerrada=True)
    s.linea(arco(-0.45, -0.04, 0.11, -80, 80, 8), "amarillo")
    for k in range(3):
        s.linea(arco(-0.7 + k * 0.1, 0.2, 0.06, 0, 360, 10), "blanco")
    s.linea([(-0.7, -0.15), (-0.7, 0.08)], "amarillo")
    s.linea([(-0.6, -0.15), (-0.6, 0.08)], "amarillo")
    s.linea([(-0.85, -0.38), (0.75, -0.38)], "rojo")
    s.soportes(1.4, -0.38, 0.26)
    s.cerrar()

    # BAÑO con su flecha hacia la puerta (abajo)
    # Dos dados, uno rojo y uno azul, junto al refri (la foto de AG)
    s = Letrero("dados")
    for color, cx, cz, giro in (("rojo", -0.32, 0.02, 8.0), ("azul", 0.33, -0.04, -12.0)):
        rayas, puntos = dado(cx, cz, 0.3, giro)
        s.rayas(rayas, color)
        s.rayas([arco(px, pz, 0.028, 0, 360, 8) for px, pz in puntos], "blanco", grueso=TUBO * 0.8, halo_veces=HALO_TEXTO)
    s.soportes(1.1, -0.2, 0.2)
    s.cerrar()

    # VIP: dorado, con su corona, marco y focos (sobre la puerta del cuarto VIP)
    s = Letrero("vip")
    s.marco(0, 0, 0.9, 0.42, 0.1, "amarillo")
    s.trazo("VIP", 0, -0.02, 0.24, "amarillo", separa=0.35)
    s.linea([(-0.18, 0.28), (-0.18, 0.4), (-0.09, 0.32), (0, 0.44), (0.09, 0.32), (0.18, 0.4), (0.18, 0.28)], "amarillo", cerrada=True)
    for k in range(7):
        s.foco(-0.36 + k * 0.12, -0.27)
    s.soportes(0.7, -0.2, 0.2)
    s.cerrar()

    # CLUB, rosa, adentro del VIP junto al escenario
    s = Letrero("club")
    s.trazo("CLUB", 0, 0.05, 0.26, "rosa", separa=0.3)
    s.mano("noche", 0, -0.24, 0.36, "morado", mano)
    s.soportes(0.8, -0.25, 0.25)
    s.cerrar()

    s = Letrero("bano")
    s.trazo("BAÑO", 0, 0.12, 0.16, "cian")
    s.linea([(0, -0.02), (0, -0.28)], "cian")
    s.linea([(-0.08, -0.19), (0, -0.28), (0.08, -0.19)], "cian")
    s.soportes(0.5, -0.28, 0.24)
    s.cerrar()


def exportar():
    os.makedirs(SALIDA, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(SALIDA, "neones.glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="EXPORT")


if __name__ == "neones":
    if bpy.data.filepath:
        raise RuntimeError("neones.py borraria " + bpy.data.filepath + ": abre un archivo nuevo primero")
    limpiar()
    letreros()
    exportar()
    print("neones: %d objetos" % len(bpy.data.objects))
