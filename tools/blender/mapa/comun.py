# Lo que comparten los scripts del mapa en Blender (tools/blender/mapa/README.md).
#
# Coordenadas: el mapa usa los metros del juego, el mismo marco que resources/map/minimapa.json
# (cada colonia se queda en su lugar real). Godot (x, y, z) = Blender (x, -z, y), como en
# tools/blender/plaza.py, y el giro en y de Godot es el mismo angulo que el giro en z de Blender
# (el frente de Godot, +Z local, queda en -Y de Blender).
#
# Se carga con exec desde los otros scripts:
#   _c = {"__name__": "comun"}; exec(open(RAIZ + r"\tools\blender\mapa\comun.py", encoding="utf-8").read(), _c)

import bpy
import bmesh
import json
import math
import os
import re
from mathutils import Vector

RAIZ = os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito")
MAPA = os.path.join(RAIZ, "tools", "blender", "mapa")
COLONIAS = os.path.join(MAPA, "colonias")
MODELOS = os.path.join(RAIZ, "models", "mapa")
DATOS = os.path.join(RAIZ, "resources", "mapa")

# Colecciones de la escena de una colonia. Solo "Mundo" se exporta.
MUNDO = "Mundo"
MARCAS = "Marcas"           # vacios de las marcas: se mueven a mano y leer() los regresa al .json
REFERENCIA = "Referencia"   # calles y huellas de OSM, solo de guia

# Propiedad que liga un objeto de Blender con su entrada del .json de la colonia
DATO = "dato"


def a_blender(x, z, y=0.0):
    return Vector((x, -z, y))


def a_godot(v):
    """Vector de Blender -> (x, y, z) del juego."""
    return (v.x, v.z, -v.y)


def ruta_colonia(nombre):
    return os.path.join(COLONIAS, nombre + ".json")


def leer_colonia(nombre):
    with open(ruta_colonia(nombre), encoding="utf-8") as f:
        return json.load(f)


def guardar_json(ruta, datos):
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    texto = json.dumps(datos, ensure_ascii=False, indent="\t")
    # Las listas de puros numeros ([x, z], tam, color) en una sola linea
    texto = re.sub(r"\[\s+(-?[\d.eE+-]+(?:,\s+-?[\d.eE+-]+)*)\s+\]",
                   lambda m: "[" + ", ".join(m.group(1).split()).replace(",,", ",") + "]", texto)
    with open(ruta, "w", encoding="utf-8", newline="\n") as f:
        f.write(texto + "\n")


def escena(nombre):
    """La escena de la colonia, vacia y a la vista."""
    sc = bpy.data.scenes.get(nombre) or bpy.data.scenes.new(nombre)
    for ob in list(sc.collection.all_objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for hija in list(sc.collection.children):
        bpy.data.collections.remove(hija)
    for ventana in bpy.context.window_manager.windows:
        ventana.scene = sc
    sc.unit_settings.system = "METRIC"
    return sc


def coleccion(sc, nombre):
    col = bpy.data.collections.new(nombre)
    sc.collection.children.link(col)
    return col


def material(nombre, color):
    """Material liso (las fotos llegan con el kit). Se reusa si ya existe."""
    mat = bpy.data.materials.get(nombre)
    if mat is None:
        mat = bpy.data.materials.new(nombre)
        mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    mat.diffuse_color = (color[0], color[1], color[2], 1.0)
    return mat


def _malla_caja(nombre, tam):
    """Caja de tam = (ancho x, alto y, fondo z) en medidas de Godot, con la base en el origen."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    ancho, alto, fondo = tam
    for v in bm.verts:
        v.co = Vector((v.co.x * ancho, v.co.y * fondo, (v.co.z + 0.5) * alto))
    malla = bpy.data.meshes.new(nombre)
    bm.to_mesh(malla)
    bm.free()
    return malla


def caja(col, nombre, x, z, rot, tam, mat, y=0.0, choca=True):
    """Una caja en el piso: centro (x, z), giro en radianes como el de Godot. Con `choca`
    lleva su caja de choque "-colonly" (Godot la vuelve StaticBody3D, capa 1)."""
    malla = _malla_caja(nombre, tam)
    malla.materials.append(mat)
    ob = bpy.data.objects.new(nombre, malla)
    ob.location = a_blender(x, z, y)
    ob.rotation_euler = (0.0, 0.0, rot)
    col.objects.link(ob)
    if choca:
        colision(col, nombre, x, z, rot, tam, y)
    return ob


def colision(col, nombre, x, z, rot, tam, y=0.0):
    ob = bpy.data.objects.new(nombre + "-colonly", _malla_caja(nombre + "_col", tam))
    ob.location = a_blender(x, z, y)
    ob.rotation_euler = (0.0, 0.0, rot)
    ob.display_type = "WIRE"
    col.objects.link(ob)
    return ob


def vacio(col, nombre, x, z, rot, y=0.0, tamano=1.0):
    """Vacio con flecha: la flecha (+Z local del vacio) se acuesta hacia -Y de Blender, que es
    el frente (+Z) de Godot, para que se vea a donde da la marca."""
    ob = bpy.data.objects.new(nombre, None)
    ob.empty_display_type = "SINGLE_ARROW"
    ob.empty_display_size = tamano
    ob.location = a_blender(x, z, y)
    ob.rotation_euler = (math.pi / 2, 0.0, rot)
    col.objects.link(ob)
    return ob


def frente_de(p):
    """De una pieza con huella ("puntos" relativos a x/z, "rot", "frente"): las dos esquinas del
    lado del frente en metros del mundo, el centro, la normal hacia afuera (x, z) y el fondo."""
    c, s = math.cos(p.get("rot", 0.0)), math.sin(p.get("rot", 0.0))
    pts = [(p["x"] + x * c + z * s, p["z"] - x * s + z * c) for x, z in p["puntos"]]
    cx = sum(q[0] for q in pts) / len(pts)
    cz = sum(q[1] for q in pts) / len(pts)
    i = p.get("frente", 0) % len(pts)
    a, b = pts[i], pts[(i + 1) % len(pts)]
    mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    nx, nz = mx - cx, mz - cz
    # La normal del lado (no la del centro al medio, que se tuerce en huellas raras)
    lx, lz = b[0] - a[0], b[1] - a[1]
    largo = math.hypot(lx, lz) or 1.0
    px, pz = -lz / largo, lx / largo
    if px * nx + pz * nz < 0:
        px, pz = -px, -pz
    fondo = 2 * abs((mx - cx) * px + (mz - cz) * pz)
    return a, b, (cx, cz), (px, pz), max(fondo, 3.0)


def giro_de_vacio(ob):
    """El giro en y de Godot de un vacio armado por vacio()."""
    return ob.rotation_euler.z
