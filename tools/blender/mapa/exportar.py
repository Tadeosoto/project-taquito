# Exporta una colonia armada por colonia.py:
#   models/mapa/<colonia>/<colonia>.glb       la coleccion "Mundo" (piezas y cajas "-colonly")
#   models/mapa/<colonia>/fuente/<colonia>.blend   la escena (detras de .gdignore)
#   resources/mapa/<colonia>/marcas.json      las marcas, para scripts/mapa/Colonia.gd
#   resources/mapa/<colonia>/puntos.json      los negocios, con el esquema de MapPuntos (para el
#                                            minimapa, la gente, las misiones y Partida)
# Antes de exportar trae al .json lo movido a mano (colonia.leer), asi que el .json y el .glb
# siempre dicen lo mismo.
#
#   COLONIA = "santa_mugre"; exec(open(r"...\tools\blender\mapa\exportar.py", encoding="utf-8").read())

import bpy
import os

_k = {"__name__": "colonia", "SOLO_FUNCIONES": True}
exec(open(r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender\mapa\colonia.py", encoding="utf-8").read(), _k)
globals().update({k: v for k, v in _k.items() if not k.startswith("__") and k != "SOLO_FUNCIONES"})


def exportar(nombre):
    leer(nombre)
    datos = leer_colonia(nombre)
    sc = bpy.data.scenes[nombre_escena(nombre)]
    salida = os.path.join(MODELOS, nombre)
    os.makedirs(salida, exist_ok=True)

    # Blender le pone ".001" al nombre si la coleccion ya existia en otra escena
    mundo = next(c for c in sc.collection.children if c.name.startswith(MUNDO))
    with bpy.context.temp_override(scene=sc, view_layer=sc.view_layers[0]):
        for ob in sc.objects:
            ob.select_set(False)
        for ob in mundo.all_objects:
            ob.hide_set(False)
            ob.select_set(True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(salida, nombre + ".glb"), export_format="GLB",
                                  use_selection=True, use_active_scene=True, export_animations=False,
                                  export_yup=True, export_materials="EXPORT", export_apply=True)

    carpeta = os.path.join(salida, "fuente")
    os.makedirs(carpeta, exist_ok=True)
    open(os.path.join(carpeta, ".gdignore"), "w").close()
    bpy.data.libraries.write(os.path.join(carpeta, nombre + ".blend"), {sc}, fake_user=True, compress=True)

    datos_dir = os.path.join(DATOS, nombre)
    guardar_json(os.path.join(datos_dir, "marcas.json"), {"colonia": nombre, "marcas": datos.get("marcas", [])})
    guardar_json(os.path.join(datos_dir, "puntos.json"), {"puntos": datos.get("negocios", [])})
    print("colonia %s exportada: %d objetos, %d marcas" % (nombre, len(mundo.all_objects), len(datos.get("marcas", []))))


if not globals().get("SOLO_FUNCIONES"):
    exportar(globals().get("COLONIA", "santa_mugre"))
