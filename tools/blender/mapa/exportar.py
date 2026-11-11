# Exporta una colonia armada por colonia.py:
#   models/mapa/<colonia>/<colonia>.glb       la coleccion "Mundo" (piezas y cajas "-colonly")
#   models/mapa/<colonia>/fuente/<colonia>.blend   la escena (detras de .gdignore)
#   resources/mapa/<colonia>/marcas.json      las marcas, para scripts/mapa/Colonia.gd
#                                            (y los tramos de tianguis, tianguis_marcas)
#   resources/mapa/<colonia>/puntos.json      los negocios, con el esquema de MapPuntos (para el
#                                            minimapa, la gente, las misiones y Partida)
# Antes de exportar trae al .json lo movido a mano (colonia.leer), asi que el .json y el .glb
# siempre dicen lo mismo.
#
#   COLONIA = "santa_mugre"; exec(open(r"...\tools\blender\mapa\exportar.py", encoding="utf-8").read())

import bpy
import json
import os

_k = {"__name__": "colonia", "SOLO_FUNCIONES": True}
exec(open(os.path.join(os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito"), "tools", "blender", "mapa", "colonia.py"), encoding="utf-8").read(), _k)
globals().update({k: v for k, v in _k.items() if not k.startswith("__") and k != "SOLO_FUNCIONES"})


def casas_juego(datos):
    """Las casas con el esquema de resources/map/casas_mapa.json (MisionesMundo: a donde mandar a
    visitar; Partida: las de obra negra), con su frente hacia la calle."""
    casas = []
    for p in datos.get("piezas", []):
        if p["tipo"] != "casa":
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

# Frente a una puerta o un negocio el tianguis deja un hueco de 2 * PUESTO_LIBRE m de ese lado
PUESTO_LIBRE = 2.5


def tianguis_marcas(datos):
    """Los tramos de "tianguis" del .json como marcas para Colonia.gd (scripts/mapa/Tianguis.gd):
    la marca va en "a" (en medio del arroyo) con su +X hacia "b". Los huecos (lado, desde, hasta,
    en metros a lo largo del tramo) salen de las puertas de las marcas y los negocios, mas los
    "libres" a mano ([x, z, ancho]: las calles que cruzan); los reservados, de los puestos_calle con
    "bajo_carpa" (una carpa vacia encima del carrito de MapPuntos)."""
    puertas = [(m["x"], m["z"]) for m in datos.get("marcas", [])
               if m.get("tipo") in ("puerta", "casa_vecino", "casa_propia", "yonke")]
    for n in datos.get("negocios", []):
        r, f = n.get("rotacion_y", 0.0), n.get("fondo", 0.0) / 2
        puertas.append((n["x"] + math.sin(r) * f, n["z"] + math.cos(r) * f))
    marcas = []
    for t in datos.get("tianguis", []):
        (ax, az), (bx, bz) = t["a"], t["b"]
        largo = math.hypot(bx - ax, bz - az)
        rot = math.atan2(-(bz - az), bx - ax)
        arroyo = t.get("arroyo", 8.0)

        def local(x, z):
            dx, dz = x - ax, z - az
            return dx * math.cos(rot) - dz * math.sin(rot), dx * math.sin(rot) + dz * math.cos(rot)

        huecos = []
        libres = [(x, z, PUESTO_LIBRE * 2) for x, z in puertas] + [tuple(l) for l in t.get("libres", [])]
        for x, z, ancho in libres:
            lx, lz = local(x, z)
            if -ancho / 2 < lx < largo + ancho / 2 and abs(lz) < arroyo / 2 + t.get("banqueta", 1.5) + 3.0:
                huecos.append([1 if lz > 0 else -1, round(lx - ancho / 2, 2), round(lx + ancho / 2, 2)])
        reservados = []
        for p in datos.get("puestos_calle", []):
            if p.get("bajo_carpa"):
                lx, lz = local(p["x"], p["z"])
                if 0 < lx < largo and abs(lz) < arroyo / 2:
                    reservados.append([1 if lz > 0 else -1, round(lx, 2), round(p["ancho"] + 0.5, 2)])
        marcas.append({"nombre": t["nombre"], "tipo": "tianguis", "x": ax, "z": az, "rot": round(rot, 4),
                       "largo": round(largo, 2), "arroyo": arroyo, "pasillo": t.get("pasillo", 2.6),
                       "semilla": t.get("semilla", 7), "huecos": huecos, "reservados": reservados})
    return marcas


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
    # Los focos colgados de los callejones (colonia.focos_callejones) van como marcas "foco"
    focos = [{"nombre": "Foco_%d" % i, "tipo": "foco", "x": x, "z": z, "y": round(y - 0.36, 2)}
             for i, (x, y, z, *_resto) in enumerate(focos_callejones(datos))]
    # Y el botin de las azoteas (colonia.botin_azoteas) como marcas "botin"
    botin = [{"nombre": "Botin_%d" % i, "tipo": "botin", "que": que, "x": x, "z": z, "y": y}
             for i, (x, y, z, que) in enumerate(botin_azoteas(datos))]
    # Y las placas de las calles (colonia.placas_calles) como marcas "placa"
    placas = [dict(pl, nombre="Placa_%d" % i, tipo="placa") for i, pl in enumerate(placas_calles(datos))]
    # Y los tramos de tianguis como marcas "tianguis"
    tianguis = tianguis_marcas(datos)
    guardar_json(os.path.join(datos_dir, "marcas.json"), {"colonia": nombre, "marcas": datos.get("marcas", []) + focos + botin + placas + tianguis})
    guardar_json(os.path.join(datos_dir, "puntos.json"), {"puntos": datos.get("negocios", []) + datos.get("puestos_calle", [])})
    # Los arboles de Sketchfab (tipos 1 a 3 de kit.arbol_tipo): [x, z, altura, ancho de copa, nombre]
    arbol_tipo, extra = _kit()["arbol_tipo"], _kit()["ARBOLES_EXTRA"]
    modelo = [[p["x"], p["z"], round((p.get("alto", 4.2) + p.get("radio", 2.0)) * 1.5, 1), round(p.get("radio", 2.0) * 4.6, 1), extra[arbol_tipo(p["nombre"]) - 1]]
              for p in datos.get("piezas", []) if p["tipo"] == "ficus" and arbol_tipo(p["nombre"]) >= 1]
    guardar_json(os.path.join(datos_dir, "arboles_modelo.json"), {"arboles": modelo})
    # Los carros de Sketchfab (models/vehiculos): [x, z, giro, modelo, estado, y]; los dibuja scripts/mapa/CarrosColonia.gd
    guardar_json(os.path.join(datos_dir, "carros_modelo.json"), {"carros": json.loads(sc.get("carros_modelo", "[]"))})
    guardar_json(os.path.join(datos_dir, "alumbrado.json"), {"postes": datos.get("postes", [])})
    guardar_json(os.path.join(datos_dir, "casas.json"), {"casas": casas_juego(datos)})
    guardar_json(os.path.join(datos_dir, "banquetas.json"), {"banquetas": banquetas(datos)})
    print("colonia %s exportada: %d objetos, %d marcas" % (nombre, len(mundo.all_objects), len(datos.get("marcas", []))))


if not globals().get("SOLO_FUNCIONES"):
    exportar(globals().get("COLONIA", "santa_mugre"))
