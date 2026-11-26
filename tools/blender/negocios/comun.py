# Piezas comunes de los negocios hechos en Blender (yonke.py, punto.py, jefe_punto.py).
# Reusa las funciones de tools/blender/sotano/sotano.py (caja, plano, cilindro, girar, juntar,
# marca, esfera, tubo_curva, limpiar, material...) cargandolo sin correr su parte de abajo, y suma
# lo que los negocios necesitan: prismas de perfil (carros), letreros de texto y materiales con la
# textura del juego para verlos en Blender (el .glb sale SIN imagenes: NegocioPostImport.gd pone
# las del juego por el nombre del material).
#
# Coordenadas de Godot en todo: x al este, y arriba, z al sur. Blender: (x, -z, y).

import bpy
import bmesh
import math
import os
import random
from mathutils import Matrix, Vector

RAIZ = os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito")
_SOTANO = os.path.join(RAIZ, "tools", "blender", "sotano", "sotano.py")
exec(open(_SOTANO, encoding="utf-8").read(), globals())   # __name__ no es "sotano": no arma nada

# Textura del juego por material (solo para verlo en Blender; la misma tabla esta en
# scripts/negocios/NegocioPostImport.gd, que es la que cuenta): nombre -> (ruta, repeticiones por m)
TEXTURAS_VISTA = {}


def mat_tex(nombre, ruta, color=(1, 1, 1), escala=1.0):
    """Material con la textura del juego (filtro nearest) para la vista en Blender."""
    m = bpy.data.materials.get(nombre)
    if m:
        return m
    m = material(nombre, color)
    TEXTURAS_VISTA[nombre] = (ruta, escala)
    archivo = os.path.join(RAIZ, ruta.replace("res://", "").replace("/", os.sep))
    if not os.path.exists(archivo):
        return m
    arbol = m.node_tree
    bsdf = next(n for n in arbol.nodes if n.type == "BSDF_PRINCIPLED")
    img = bpy.data.images.load(archivo, check_existing=True)
    tex = arbol.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    mapeo = arbol.nodes.new("ShaderNodeMapping")
    coord = arbol.nodes.new("ShaderNodeTexCoord")
    e = escala if escala > 0 else 1.0   # 0: la textura entera en el UV del plano (como en el juego)
    mapeo.inputs["Scale"].default_value = (e, e, 1.0)
    arbol.links.new(coord.outputs["UV"], mapeo.inputs["Vector"])
    arbol.links.new(mapeo.outputs["Vector"], tex.inputs["Vector"])
    mezcla = arbol.nodes.new("ShaderNodeMix")
    mezcla.data_type = "RGBA"
    mezcla.blend_type = "MULTIPLY"
    mezcla.inputs["Factor"].default_value = 1.0
    mezcla.inputs[6].default_value = (*color, 1.0)
    arbol.links.new(tex.outputs["Color"], mezcla.inputs[7])
    arbol.links.new(mezcla.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    return m


def prisma(nombre, perfil, ancho, mat, col):
    """Una pieza de perfil `perfil` [(u, v)] (u a lo largo de x, v hacia arriba, en orden) con
    `ancho` en z, centrada en z = 0. Los carros, cofres y techos salen de aqui."""
    me = bpy.data.meshes.new(nombre)
    bm = bmesh.new()
    a = [bm.verts.new(_b(u, v, -ancho / 2)) for u, v in perfil]
    b = [bm.verts.new(_b(u, v, ancho / 2)) for u, v in perfil]
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    n = len(perfil)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    _uv_caja(me)
    me.materials.append(mat)
    ob = bpy.data.objects.new(nombre, me)
    col.objects.link(ob)
    return ob


def letrero(nombre, texto, tamano, mat, col, grueso=0.0):
    """Texto en malla (sin curvas: pocas caras) parado viendo hacia +Z, con su base en y = 0 y
    centrado en x = 0."""
    cu = bpy.data.curves.new(nombre, "FONT")
    cu.body = texto
    cu.size = tamano
    cu.align_x = "CENTER"
    cu.resolution_u = 1
    cu.extrude = grueso
    cu.fill_mode = "BOTH"
    tmp = bpy.data.objects.new(nombre + "_tmp", cu)
    col.objects.link(tmp)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(tmp, do_unlink=True)
    bpy.data.curves.remove(cu)
    # La fuente esta en el plano XY de Blender: pararla (rotar 90 en X) para que vea a -Y (+Z de Godot)
    me.transform(Matrix.Rotation(math.radians(90), 4, "X"))
    me.materials.clear()
    me.materials.append(mat)
    ob = bpy.data.objects.new(nombre, me)
    col.objects.link(ob)
    return ob


def mover(ob, x, y, z, giro_y=0.0):
    """Pone una pieza armada en el origen en (x, y, z) de Godot, girada `giro_y` grados en Y."""
    ob.matrix_basis = Matrix.Translation(_b(x, y, z)) @ Matrix.Rotation(math.radians(giro_y), 4, "Z") @ ob.matrix_basis
    return ob


def matriz(x, y, z, giro_y=0.0, giro_x=0.0, giro_z=0.0):
    """Matriz de Blender para juntar(): en (x, y, z) de Godot, girada en grados (Godot)."""
    return (Matrix.Translation(_b(x, y, z)) @ Matrix.Rotation(math.radians(giro_y), 4, "Z")
            @ Matrix.Rotation(math.radians(giro_x), 4, "X") @ Matrix.Rotation(math.radians(-giro_z), 4, "Y"))


def cilindro_eje(nombre, radio, largo, eje, mat, col, lados=8, radio2=None):
    """Un cilindro centrado en el origen a lo largo de `eje` ('x', 'y' o 'z' de Godot)."""
    me = bpy.data.meshes.new(nombre)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=lados, radius1=radio,
                          radius2=radio if radio2 is None else radio2, depth=largo)
    if eje == "x":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Y"))
    elif eje == "z":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"))
    bm.to_mesh(me)
    bm.free()
    _uv_caja(me)
    me.materials.append(mat)
    ob = bpy.data.objects.new(nombre, me)
    col.objects.link(ob)
    return ob


def dona(nombre, radio, grueso, alto, mat, col, lados=10):
    """Una llanta: anillo de radio exterior `radio`, hueco de `radio - grueso`, de `alto`, acostada."""
    me = bpy.data.meshes.new(nombre)
    bm = bmesh.new()
    r0, r1, h = radio - grueso, radio, alto / 2
    aros = []
    for r, z in ((r0, -h), (r1, -h * 0.7), (r1, h * 0.7), (r0, h)):
        aros.append([bm.verts.new((r * math.cos(k * math.tau / lados), r * math.sin(k * math.tau / lados), z)) for k in range(lados)])
    for i in range(4):
        a, b = aros[i], aros[(i + 1) % 4]
        for k in range(lados):
            j = (k + 1) % lados
            bm.faces.new((a[k], a[j], b[j], b[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(nombre, me)
    col.objects.link(ob)
    return ob


def preparar_vista(mostrar, esconder):
    """Deja el archivo listo para verlo en Blender: el interior y el exterior estan los dos en el
    origen (asi los quiere Godot), asi que solo se ve `mostrar`; nada seleccionado, cielo y sol, y
    la vista en Material Preview (en Solid no se ven las texturas). No cambia lo exportado."""
    capas = bpy.context.view_layer.layer_collection.children
    for nombre in esconder:
        if nombre in capas:
            capas[nombre].hide_viewport = True
    if mostrar in capas:
        capas[mostrar].hide_viewport = False
    for ob in bpy.context.view_layer.objects:
        ob.select_set(False)
        # Los empties de marcas y las cajas de solo choque estorban la vista
        if ob.type == "EMPTY" or ob.name.endswith(("-colonly", "-convcolonly")):
            ob.hide_set(True)
    mundo = bpy.data.worlds.get("Vista") or bpy.data.worlds.new("Vista")
    mundo.use_nodes = True
    fondo = next(n for n in mundo.node_tree.nodes if n.type == "BACKGROUND")
    fondo.inputs["Color"].default_value = (0.55, 0.65, 0.8, 1.0)
    fondo.inputs["Strength"].default_value = 1.0
    bpy.context.scene.world = mundo
    if not bpy.data.objects.get("Vista_sol"):
        sol = bpy.data.objects.new("Vista_sol", bpy.data.lights.new("Vista_sol", "SUN"))
        sol.data.energy = 3.0
        sol.rotation_euler = (math.radians(50), 0, math.radians(30))
        bpy.context.scene.collection.objects.link(sol)   # fuera de las colecciones exportadas
    for pantalla in bpy.data.screens:
        for area in pantalla.areas:
            if area.type == "VIEW_3D":
                area.spaces[0].shading.type = "MATERIAL"


def guardar_fuente(ruta_blend):
    carpeta = os.path.dirname(ruta_blend)
    os.makedirs(carpeta, exist_ok=True)
    open(os.path.join(carpeta, ".gdignore"), "w").close()
    bpy.ops.wm.save_as_mainfile(filepath=ruta_blend)


def exportar_coleccion(nombre_col, ruta_glb):
    """Exporta una coleccion a .glb (sin imagenes: el juego pone sus texturas)."""
    os.makedirs(os.path.dirname(ruta_glb), exist_ok=True)
    capa = bpy.context.view_layer.layer_collection.children.get(nombre_col)
    if capa:
        capa.hide_viewport = False   # en una coleccion escondida no se puede seleccionar
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.data.collections[nombre_col].all_objects:
        ob.hide_set(False)
        ob.select_set(True)
    import contextlib
    import io
    import logging
    # El exportador escribe una linea por pieza: callado
    logging.disable(logging.INFO)
    try:
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            bpy.ops.export_scene.gltf(filepath=ruta_glb, export_format="GLB", use_selection=True,
                                      export_apply=True, export_yup=True, export_materials="EXPORT",
                                      export_image_format="NONE", export_extras=False)
    finally:
        logging.disable(logging.NOTSET)
