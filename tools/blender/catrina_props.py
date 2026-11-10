# La Mojiganga, paso 5: las piezas sueltas. femur.glb (el arma que suelta), corona.glb (el amuleto),
# craneo_caido.glb (la cabeza que cae en la fase 3) y pompon.glb (el arete que rueda). Pocos
# triangulos, con la misma pintura que la Catrina (catrina_textura.py) horneada a su propia
# textura chica. Se corre en Blender despues de catrina_textura.py.

import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix

RAIZ = r"C:\Users\Big Boss\Documents\GitHub\project-taquito"
SALIDA = RAIZ + r"\models\personajes\catrina"
_t = {"SOLO_FUNCIONES": True, "__name__": "catrina_textura"}
exec(open(RAIZ + r"\tools\blender\catrina_textura.py", encoding="utf-8").read(), _t)
_a = _t["_a"]
_m = _t["_m"]
tubo, esfera, cana, cempasuchil = _a["tubo"], _a["esfera"], _a["cana"], _a["cempasuchil"]
C = _m["CABEZA"]
mc = _a["matriz_cabeza"]()


def _objeto(nombre, bm):
    sc = bpy.data.scenes["Catrina"]
    vieja = bpy.data.objects.get(nombre)
    if vieja:
        bpy.data.objects.remove(vieja, do_unlink=True)
    mats = _m["materiales"]()
    ob = _m["objeto"](sc, nombre, bm, mats)
    return ob


def femur():
    bm = bmesh.new()
    # Hueso de carton: cabezas gruesas, cana delgada; sale el carrizo de la punta rota
    # Menos de 300 triangulos: hueso de 5 lados con sus cabezas, carrizo de 3, cuerda de 3
    tubo(bm, [Vector((0, 0, z)) for z in (0.02, 0.1, 0.2, 0.5, 0.75, 0.84)], [0.06, 0.075, 0.04, 0.036, 0.045, 0.07], "Hueso", lados=5)
    esfera(bm, (0.03, 0, 0.88), (0.07, 0.065, 0.07), "Hueso", seg=6, anillos=4)
    tubo(bm, [Vector((0, 0, 0.8)), Vector((0.02, 0.01, 0.97))], [0.018, 0.006], "Carrizo", lados=3)
    tubo(bm, [Vector((math.cos(t) * 0.05, math.sin(t) * 0.05, 0.12 + 0.01 * t)) for t in (math.tau * i / 5 for i in range(11))], 0.008, "Cuerda", lados=3, tapas=False)
    return _objeto("Prop_Femur", bm)


def corona():
    bm = bmesh.new()
    tubo(bm, [Vector((math.cos(t) * 0.15, math.sin(t) * 0.15, 0)) for t in (math.tau * i / 10 for i in range(11))], 0.008, "Alambre", lados=3, tapas=False)
    # Cinco cempasuchiles de bolita encrespada (pocos triangulos)
    for k in range(5):
        a = math.tau * k / 5
        p = Vector((math.cos(a) * 0.15, math.sin(a) * 0.15, 0.02))
        vs = esfera(bm, p, (0.055,) * 3, "Flor_Naranja", seg=6, anillos=4)
        for v in vs:
            n = (v.co - p).normalized()
            v.co += n * 0.015 * (1 if (round(n.x * 9) + round(n.y * 9)) % 2 else -1)
    return _objeto("Prop_Corona", bm)


def craneo_caido():
    """El craneo de la cabeza, con su pintura: se arma donde esta la cabeza (asi la pintura de la
    cara cae en su lugar), se hornea y luego se pasa al origen."""
    bm = bmesh.new()
    vs = esfera(bm, C, (0.6, 0.62, 0.62), "Hueso", seg=14, anillos=9)
    for v in vs:
        _a["_forma_craneo"](v, v.co - C)
    for x in (-0.24, 0.24):
        esfera(bm, C + Vector((x, -0.18, 0.04)), (0.09, 0.05, 0.08), "Brillo", seg=4, anillos=3)
    arriba, abajo = [], []
    for i in range(7):
        x = -0.3 + 0.6 * i / 6
        y = -0.58 + 0.5 * x * x
        arriba.append(bm.verts.new(C + Vector((x, y, -0.28))))
        abajo.append(bm.verts.new(C + Vector((x, y, -0.44))))
    _a["pintar"]([bm.faces.new((arriba[i], arriba[i + 1], abajo[i + 1], abajo[i])) for i in range(6)], "Hueso")
    bmesh.ops.transform(bm, matrix=mc, verts=bm.verts)
    return _objeto("Prop_Craneo", bm)


def pompon():
    bm = bmesh.new()
    cempasuchil(bm, Vector((0, 0, 0)), 0.42, normal=(0, 0, 1))
    vs = esfera(bm, (0, 0, 0), (0.4,) * 3, "Flor_Rosa", seg=10, anillos=7)
    return _objeto("Prop_Pompon", bm)


def _hornear_propio(ob, lado):
    """Hornea la pintura del propio objeto a su textura (sin alta: color de su material)."""
    sc = bpy.data.scenes["Catrina"]
    vl = sc.view_layers[0]
    for o in sc.objects:
        o.select_set(False)
    ob.select_set(True)
    vl.objects.active = ob
    with bpy.context.temp_override(**_t["_contexto_3d"]()):
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
    img = _t["_imagen"](ob.name.lower(), lado)
    nodos = []
    for mat in ob.data.materials:
        n = mat.node_tree.nodes.new("ShaderNodeTexImage")
        n.image = img
        mat.node_tree.nodes.active = n
        nodos.append((mat, n))
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 16
    with bpy.context.temp_override(**_t["_contexto_3d"]()):
        bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_selected_to_active=False, margin=4, use_clear=True)
    for mat, n in nodos:
        mat.node_tree.nodes.remove(n)
    final = bpy.data.materials.get(ob.name + "_mat") or bpy.data.materials.new(ob.name + "_mat")
    final.use_nodes = True
    arbol = final.node_tree
    arbol.nodes.clear()
    salida = arbol.nodes.new("ShaderNodeOutputMaterial")
    bsdf = arbol.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 1.0
    tex = arbol.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    arbol.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    arbol.links.new(bsdf.outputs[0], salida.inputs[0])
    ob.data.materials.clear()
    ob.data.materials.append(final)
    return img


def _exportar(ob, archivo):
    sc = bpy.data.scenes["Catrina"]
    for o in sc.objects:
        o.select_set(False)
    ob.hide_set(False)
    ob.select_set(True)
    with bpy.context.temp_override(scene=sc, view_layer=sc.view_layers[0]):
        bpy.ops.export_scene.gltf(filepath=os.path.join(SALIDA, archivo), export_format="GLB", use_selection=True,
                                  use_active_scene=True, export_animations=False, export_yup=True, export_materials="EXPORT")
    ob.hide_set(True)


def armar_props():
    sc = bpy.data.scenes["Catrina"]
    for ventana in bpy.context.window_manager.windows:
        ventana.scene = sc
    for hacer, archivo, lado in ((femur, "femur.glb", 128), (corona, "corona.glb", 128), (craneo_caido, "craneo_caido.glb", 256), (pompon, "pompon.glb", 128)):
        ob = hacer()
        _hornear_propio(ob, lado)
        if archivo == "craneo_caido.glb":
            # Al origen, derecho, la cara hacia -Y
            ob.data.transform(Matrix.Translation(-C) @ mc.inverted())
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        _exportar(ob, archivo)
        print(archivo, tris, "tris")


if not globals().get("SOLO_FUNCIONES"):
    armar_props()
