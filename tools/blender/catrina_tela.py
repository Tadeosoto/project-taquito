# La Mojiganga: el rebozo y la cola con simulacion de tela de verdad (AG pidio quitar el drapeado
# hecho a mano). Dos rejillas de tela que caen por gravedad: el rebozo prendido de los hombros
# sobre la espalda (choca con un cuerpo simple: falda y blusa), la cola prendida del ruedo de
# atras sobre el piso. Se dejan asentar SIM_CUADROS cuadros y se guarda la forma final:
#   Rebozo_Alta, Cola_Alta (enteros) y Rebozo_Roto_Alta, Cola_Roto_Alta (con hoyos), en la
#   coleccion Catrina_Alta. catrina_alta.py ya no pone su rebozo y cola dibujados cuando existen;
#   catrina_baja.py toma de estas rejillas (cada tantos vertices) los de la malla del juego.
#
# Se corre en Blender despues de catrina_alta.py y antes de catrina_baja.py.

import bpy
import bmesh
import math
from mathutils import Vector, Matrix, noise

RAIZ = r"C:\Users\Big Boss\Documents\GitHub\project-taquito"
_a = {"SOLO_FUNCIONES": True, "__name__": "catrina_alta"}
exec(open(RAIZ + r"\tools\blender\catrina_alta.py", encoding="utf-8").read(), _a)
_m = _a["_m"]
doblar = _m["doblar"]

SIM_CUADROS = 60
# Rejillas (columnas x filas de cuadros); catrina_baja toma cada PASO de ellas
REBOZO = (42, 30)
COLA = (26, 24)


def _rebozo_inicio(u, v):
    """Donde empieza cada punto del rebozo: un cilindro holgado alrededor de la espalda; el
    simulador lo deja caer y pegarse al cuerpo."""
    a = math.radians(-20) + math.radians(220) * u
    largo = 1.0 + 0.22 * noise.noise(Vector((u * 5.0, 1.3, 0)))
    z = 4.55 - v * (4.55 - 0.9) * largo
    if z > 4.15:
        r = 0.75 + (4.55 - z) * 0.85 + 0.38
    else:
        r = _m["radio_vestido"](max(z, 0.3)) + 0.25 + 0.2 * v
    return doblar(Vector((math.cos(a) * r, math.sin(a) * r, z)))


def _cola_inicio(u, v):
    u -= 0.5
    a = math.pi / 2 + u * 1.6 * (1.0 - 0.35 * v)
    r0 = _m["radio_vestido"](0.25) + 0.06
    x = math.cos(a) * r0 * (1.0 + 0.6 * v)
    y = math.sin(a) * r0 + v * 3.6
    # Arranca en el aire con ondas: al caer se le hacen pliegues
    z = 0.6 * (1 - v) ** 2 + 0.25 + 0.12 * math.sin(u * 22)
    return Vector((x, y, z))


def _rejilla(nombre, cols, filas, inicio, prender, col):
    """Una tela en rejilla, vertices en orden columna por columna (asi catrina_baja la muestrea),
    con el grupo 'Prende' en los que no se mueven."""
    vieja = bpy.data.objects.get(nombre)
    if vieja:
        bpy.data.objects.remove(vieja, do_unlink=True)
    bm = bmesh.new()
    vs = [[bm.verts.new(inicio(i / cols, j / filas)) for j in range(filas + 1)] for i in range(cols + 1)]
    for i in range(cols):
        for j in range(filas):
            bm.faces.new((vs[i][j], vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j]))
    malla = bpy.data.meshes.new(nombre)
    bm.to_mesh(malla)
    bm.free()
    ob = bpy.data.objects.new(nombre, malla)
    col.objects.link(ob)
    grupo = ob.vertex_groups.new(name="Prende")
    fijos = [i * (filas + 1) + j for i in range(cols + 1) for j in range(filas + 1) if prender(i / cols, j / filas)]
    grupo.add(fijos, 1.0, "REPLACE")
    return ob


def _chocador(col):
    """Un cuerpo simple para que la tela choque: falda y blusa del perfil, con la joroba, y el piso."""
    obs = []
    for nombre in ("Tela_Choca_Cuerpo", "Tela_Choca_Piso"):
        vieja = bpy.data.objects.get(nombre)
        if vieja:
            bpy.data.objects.remove(vieja, do_unlink=True)
    bm = bmesh.new()
    _a["_torno_fino"](bm, _m["PERFIL_VESTIDO"], 32, 0.15)
    for v in bm.verts:
        v.co = doblar(v.co)
    for lado in (-1, 1):
        _a["esfera"](bm, (_m["HOMBRO"] * lado, 0, _m["HOMBRO_Z"]), (0.5, 0.48, 0.44), "Tela", seg=12, anillos=8)
    malla = bpy.data.meshes.new("Tela_Choca_Cuerpo")
    bm.to_mesh(malla)
    bm.free()
    ob = bpy.data.objects.new("Tela_Choca_Cuerpo", malla)
    col.objects.link(ob)
    obs.append(ob)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=2, y_segments=2, size=12.0)
    malla = bpy.data.meshes.new("Tela_Choca_Piso")
    bm.to_mesh(malla)
    bm.free()
    ob = bpy.data.objects.new("Tela_Choca_Piso", malla)
    col.objects.link(ob)
    obs.append(ob)
    for ob in obs:
        mod = ob.modifiers.new("Choca", "COLLISION")
        ob.collision.thickness_outer = 0.03
        ob.collision.cloth_friction = 8.0
    return obs


def _tela(ob, masa, rigidez):
    mod = ob.modifiers.new("Tela", "CLOTH")
    s = mod.settings
    s.quality = 6
    s.mass = masa
    s.tension_stiffness = rigidez
    s.compression_stiffness = rigidez
    s.shear_stiffness = rigidez * 0.5
    s.bending_stiffness = 0.6
    s.air_damping = 2.0
    s.vertex_group_mass = "Prende"
    c = mod.collision_settings
    c.use_collision = True
    c.distance_min = 0.02
    c.use_self_collision = False
    mod.point_cache.frame_start = 1
    mod.point_cache.frame_end = SIM_CUADROS
    return mod


def _congelar(ob, zona):
    """Se queda con la forma del ultimo cuadro (malla nueva, sin modificadores) y le pone su zona."""
    dg = bpy.context.evaluated_depsgraph_get()
    nueva = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    vieja = ob.data
    ob.modifiers.clear()
    ob.data = nueva
    bpy.data.meshes.remove(vieja)
    mats = _a["materiales"]()
    for m in mats:
        nueva.materials.append(m)
    i = _a["zona"](zona)
    for p in nueva.polygons:
        p.material_index = i
        p.use_smooth = True


def _rasgada(ob, nombre, umbral, alto_max, col):
    vieja = bpy.data.objects.get(nombre)
    if vieja:
        bpy.data.objects.remove(vieja, do_unlink=True)
    copia = ob.copy()
    copia.data = ob.data.copy()
    copia.name = nombre
    col.objects.link(copia)
    bm = bmesh.new()
    bm.from_mesh(copia.data)
    hoyos = [f for f in bm.faces if f.calc_center_median().z < alto_max and noise.noise(f.calc_center_median() * 1.8 + Vector((1, 2, 3))) > umbral]
    bmesh.ops.delete(bm, geom=hoyos, context="FACES")
    bm.to_mesh(copia.data)
    bm.free()
    copia.hide_set(True)
    return copia


def simular():
    sc = bpy.data.scenes["Catrina"]
    for ventana in bpy.context.window_manager.windows:
        ventana.scene = sc
    col = bpy.data.collections["Catrina_Alta"]
    col.hide_viewport = False
    choques = _chocador(col)
    rebozo = _rejilla("Rebozo_Alta", REBOZO[0], REBOZO[1], _rebozo_inicio, lambda u, v: v <= 0.07, col)
    cola = _rejilla("Cola_Alta", COLA[0], COLA[1], _cola_inicio, lambda u, v: v <= 0.04, col)
    _tela(rebozo, 0.4, 20.0)
    _tela(cola, 0.6, 12.0)
    sc.frame_start = 1
    sc.frame_end = SIM_CUADROS
    for f in range(1, SIM_CUADROS + 1):
        sc.frame_set(f)
    _congelar(rebozo, "Rebozo")
    _congelar(cola, "Tela")
    sc.frame_set(1)
    for ob in choques:
        bpy.data.objects.remove(ob, do_unlink=True)
    _rasgada(rebozo, "Rebozo_Roto_Alta", 0.15, 3.6, col)
    _rasgada(cola, "Cola_Roto_Alta", 0.2, 5.0, col)
    print("tela simulada:", len(rebozo.data.vertices), "+", len(cola.data.vertices), "vertices")


if not globals().get("SOLO_FUNCIONES"):
    simular()
