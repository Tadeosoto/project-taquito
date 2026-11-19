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
FOCO = 0.018          # radio de un foco

COLORES = {
    "rosa": (1.0, 0.25, 0.75), "amarillo": (1.0, 0.85, 0.2), "morado": (0.6, 0.3, 1.0),
    "cian": (0.3, 0.9, 1.0), "rojo": (1.0, 0.2, 0.15), "verde": (0.3, 1.0, 0.45), "blanco": (1.0, 0.95, 0.9),
}


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

    def _poner(self, curva, color, grueso=TUBO):
        """La curva (en el plano XY de la curva) se para en XZ, se vuelve malla (tubo y halo) y se
        borra."""
        for halo in (False, True):
            curva.bevel_depth = grueso * (HALO if halo else 1.0)
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

    def texto(self, cuerpo, x, z, tam, color, fuente=None, grueso=TUBO):
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
        self._poner(cu, color, grueso)

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
    s.marco(0, 0, 1.9, 0.82, 0.14, "morado")
    s.texto("EL GORDO", 0, 0.08, 0.34, "amarillo")
    s.texto("¡Suerte!", 0, -0.2, 0.5, "rosa", mano)
    for k in range(13):
        x = -0.84 + k * 0.14
        s.foco(x, 0.5)
        s.foco(x, -0.5)
    for lado in (-1, 1):
        s.linea([(lado * 1.02, 0.22), (lado * 1.16, 0.0), (lado * 1.02, -0.22)], "rosa")
    s.soportes(1.7, -0.3, 0.3)
    s.cerrar()

    # ¡PREMIO! en su liston, con un arco de focos encima (sobre las dos del muro sur)
    s = Letrero("premio")
    s.linea([(-0.78, 0.15), (0.78, 0.15), (0.64, 0.0), (0.78, -0.15), (-0.78, -0.15), (-0.64, 0.0)], "morado", cerrada=True)
    s.texto("¡Premio!", 0, 0.01, 0.46, "rosa", mano)
    s.linea(arco(0, 0.05, 0.62, 15, 165), "rosa")
    for a in range(20, 165, 13):
        s.foco(math.cos(math.radians(a)) * 0.54, 0.05 + math.sin(math.radians(a)) * 0.54)
    s.soportes(1.3, -0.1, 0.3)
    s.cerrar()

    # PÓKER: los cuatro palos arriba, la palabra en su marco y "Texas" de mano abajo
    s = Letrero("poker")
    for k, (palo, color) in enumerate((("♠", "morado"), ("♥", "rosa"), ("♦", "rosa"), ("♣", "morado"))):
        s.texto(palo, -0.45 + k * 0.3, 0.42, 0.22, color)
    s.marco(0, 0.06, 1.3, 0.42, 0.12, "amarillo")
    s.texto("PÓKER", 0, 0.06, 0.27, "amarillo")
    s.texto("Texas", 0, -0.3, 0.5, "rosa", mano)
    s.linea([(-0.65, -0.52), (0.65, -0.52)], "morado")
    s.soportes(1.1, -0.3, 0.3)
    s.cerrar()

    # ABIERTO 24 HRS
    s = Letrero("abierto")
    s.marco(0, 0, 1.4, 0.6, 0.1, "cian")
    s.texto("ABIERTO", 0, 0.1, 0.22, "verde")
    s.texto("24 HRS", 0, -0.16, 0.2, "rojo")
    s.soportes(1.2, -0.2, 0.2)
    s.cerrar()

    # Tecatl de mano con su tarro espumoso
    s = Letrero("barra")
    s.texto("Tecatl", 0.2, 0.02, 0.62, "rojo", mano)
    s.linea(rectangulo(-0.6, -0.04, 0.3, 0.42, 0.04), "amarillo", cerrada=True)
    s.linea(arco(-0.45, -0.04, 0.11, -80, 80, 8), "amarillo")
    for k in range(3):
        s.linea(arco(-0.7 + k * 0.1, 0.2, 0.06, 0, 360, 10), "blanco")
    s.linea([(-0.7, -0.15), (-0.7, 0.08)], "amarillo")
    s.linea([(-0.6, -0.15), (-0.6, 0.08)], "amarillo")
    s.linea([(-0.85, -0.38), (0.75, -0.38)], "rojo")
    s.soportes(1.4, -0.25, 0.25)
    s.cerrar()

    # BAÑO con su flecha hacia la puerta (abajo)
    s = Letrero("bano")
    s.texto("BAÑO", 0, 0.12, 0.2, "cian")
    s.linea([(0, -0.02), (0, -0.28)], "cian")
    s.linea([(-0.08, -0.19), (0, -0.28), (0.08, -0.19)], "cian")
    s.soportes(0.5, -0.1, 0.12)
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
