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
exec(open(os.path.join(os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito"), "tools", "blender", "mapa", "colonia.py"), encoding="utf-8").read(), _k)
globals().update({k: v for k, v in _k.items() if not k.startswith("__") and k != "SOLO_FUNCIONES"})


def casas_juego(datos):
    """Las casas con el esquema de resources/map/casas_mapa.json (MisionesMundo: a donde mandar a
    visitar; Partida: las de obra negra), con su frente hacia la calle."""
    casas = []
    for p in datos.get("piezas", []):
        if p["tipo"] not in ("casa", "casa_psm"):
            continue
        a, b, (cx, cz), (nx, nz), fondo = frente_de(p)
        casas.append({"modelo": "blender", "x": round(cx, 2), "z": round(cz, 2), "rotacion_y": round(math.atan2(nx, nz), 4),
                      "ancho": round(math.hypot(b[0] - a[0], b[1] - a[1]), 2), "fondo": round(fondo, 2),
                      "pisos": p.get("pisos", 1), "colonia": datos["nombre"].upper()})
    return casas


def banquetas(datos):
    """Por donde camina la gente (Gente.gd): el medio de cada banqueta de cada calle."""
    lineas = []
    for p in datos.get("piezas", []):
        if p["tipo"] != "calle" or p.get("banqueta", 0) <= 0:
            continue
        pts = [(p["x"] + x, p["z"] + z) for x, z in p["puntos"]]
        d = p["ancho"] / 2 + p["banqueta"] / 2
        for lado in (1, -1):
            linea = []
            for i, (x, z) in enumerate(pts):
                a = pts[max(i - 1, 0)]
                b = pts[min(i + 1, len(pts) - 1)]
                ux, uz = b[0] - a[0], b[1] - a[1]
                l = math.hypot(ux, uz) or 1.0
                linea.append([round(x - uz / l * d * lado, 2), round(z + ux / l * d * lado, 2)])
            lineas.append(linea)
    return lineas


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
                                  export_yup=True, export_materials="EXPORT", export_apply=True,
                                  export_image_format="NONE", export_vertex_color="ACTIVE")
        # Las cajas de choque se vuelven a esconder (para exportar tenian que verse) y no se deja
        # nada seleccionado
        for ob in mundo.all_objects:
            ob.select_set(False)
            if ob.name.endswith("-colonly"):
                ob.hide_set(True)

    carpeta = os.path.join(salida, "fuente")
    os.makedirs(carpeta, exist_ok=True)
    open(os.path.join(carpeta, ".gdignore"), "w").close()
    bpy.data.libraries.write(os.path.join(carpeta, nombre + ".blend"), {sc}, fake_user=True, compress=True)

    datos_dir = os.path.join(DATOS, nombre)
    marcas = {"colonia": nombre, "marcas": datos.get("marcas", [])}
    if "deterioro" in datos:
        marcas["deterioro"] = datos["deterioro"]
    guardar_json(os.path.join(datos_dir, "marcas.json"), marcas)
    guardar_json(os.path.join(datos_dir, "puntos.json"), {"puntos": datos.get("negocios", [])})
    guardar_json(os.path.join(datos_dir, "alumbrado.json"), {"postes": datos.get("postes", [])})
    guardar_json(os.path.join(datos_dir, "casas.json"), {"casas": casas_juego(datos)})
    guardar_json(os.path.join(datos_dir, "banquetas.json"), {"banquetas": banquetas(datos)})
    print("colonia %s exportada: %d objetos, %d marcas" % (nombre, len(mundo.all_objects), len(datos.get("marcas", []))))


if not globals().get("SOLO_FUNCIONES"):
    exportar(globals().get("COLONIA", "santa_mugre"))
