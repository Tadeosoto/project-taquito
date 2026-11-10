# La Mojiganga, la salida: catrina.glb (esqueleto, las seis mallas con el atlas horneado y las 20
# animaciones como Actions), preview.png y fuente/catrina.blend (con .gdignore). Se corre en
# Blender al final (despues de catrina_clips.py).

import bpy
import os

RAIZ = r"C:\Users\Big Boss\Documents\GitHub\project-taquito"
SALIDA = RAIZ + r"\models\personajes\catrina"
MALLAS = ["Vestido", "Vestido_Roto", "Cuerpo", "Craneo", "Carrizo", "Nudo"]


def exportar():
    sc = bpy.data.scenes["Catrina"]
    for ventana in bpy.context.window_manager.windows:
        ventana.scene = sc
    rig = bpy.data.objects["Catrina_Rig"]
    for ob in sc.objects:
        ob.select_set(False)
    for n in MALLAS + ["Catrina_Rig"]:
        ob = bpy.data.objects[n]
        ob.hide_set(False)
        ob.hide_render = False   # vista_previa() las esconde del render
        ob.select_set(True)
    rig.animation_data.action = bpy.data.actions["Idle_Pose"]
    sc.frame_set(0)
    os.makedirs(SALIDA, exist_ok=True)
    with bpy.context.temp_override(scene=sc, view_layer=sc.view_layers[0]):
        bpy.ops.export_scene.gltf(filepath=os.path.join(SALIDA, "catrina.glb"), export_format="GLB", use_selection=True,
                                  use_active_scene=True, export_apply=False, export_animations=True,
                                  export_animation_mode="ACTIONS", export_def_bones=False, export_anim_slide_to_zero=True,
                                  export_force_sampling=True, export_yup=True, export_materials="EXPORT")
    for n in ("Vestido_Roto", "Carrizo", "Nudo"):
        bpy.data.objects[n].hide_set(True)
    print("catrina.glb listo")


def vista_previa():
    sc = bpy.data.scenes["Catrina"]
    cam = bpy.data.objects.get("Catrina_Camara")
    if cam is None:
        cam = bpy.data.objects.new("Catrina_Camara", bpy.data.cameras.new("Catrina_Camara"))
        sc.collection.objects.link(cam)
    from mathutils import Vector
    cam.location = (9.0, -12.5, 5.0)
    cam.rotation_euler = (Vector((0, 0.8, 3.4)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 40
    sc.camera = cam
    luz = bpy.data.objects.get("Catrina_Luz")
    if luz is None:
        luz = bpy.data.objects.new("Catrina_Luz", bpy.data.lights.new("Catrina_Luz", "SUN"))
        sc.collection.objects.link(luz)
    luz.rotation_euler = (0.8, 0.2, 0.6)
    luz.data.energy = 3.0
    if sc.world is None:
        sc.world = bpy.data.worlds.new("Catrina_Mundo")
    sc.world.color = (0.05, 0.04, 0.06)
    try:
        sc.render.engine = "BLENDER_EEVEE"
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.render.resolution_x = 512
    sc.render.resolution_y = 384
    sc.render.resolution_percentage = 100
    sc.render.filepath = os.path.join(SALIDA, "preview.png")
    bpy.data.collections["Catrina_Alta"].hide_render = True
    for n in MALLAS:
        bpy.data.objects[n].hide_render = n in ("Vestido_Roto", "Carrizo", "Nudo")
    with bpy.context.temp_override(scene=sc):
        bpy.ops.render.render(write_still=True, scene=sc.name)
    print("preview.png listo")


def fuente():
    carpeta = os.path.join(SALIDA, "fuente")
    os.makedirs(carpeta, exist_ok=True)
    open(os.path.join(carpeta, ".gdignore"), "w").close()
    sc = bpy.data.scenes["Catrina"]
    bpy.data.libraries.write(os.path.join(carpeta, "catrina.blend"), {sc}, fake_user=True, compress=True)
    print("fuente/catrina.blend listo")


if not globals().get("SOLO_FUNCIONES"):
    exportar()
    vista_previa()
    fuente()
