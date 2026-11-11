"""Exporta la casa base de Parques de Santa Maria (casa_psm.py) para las casas modelo de map_test
(MapCasas.gd), en lugar de la Urbi:

    flatpak run --env=TAQUITO_RAIZ=$PWD org.blender.Blender --background --python $PWD/tools/blender/mapa/exportar_casas_psm.py

Deja models/casas/psm/casas_psm.glb: las VARIANTES en hilera sobre X, cada una centrada en
SEPARACION * i, como la Urbi (MapCasas saca cada una con modelo_rango_x y comparte un solo atlas).
Van sin color de vertice y con el muro gris: el color de cada casa lo pone MapCasas en el muro y los
arcos (recolor_materiales), y la luz es la del juego, no la horneada. La fachada ve a +Z (la cochera
queda al frente) y el piso de la cochera y el jardin van incluidos.

Antes: python3 -I tools/blender/mapa/texturas_casa.py (las texturas) y, para el tinaco,
godot --path . --headless -s tools/blender/mapa/exportar_tinaco.gd.
"""
import os

import bpy
import numpy as np

RAIZ = os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito")
SALIDA = os.path.join(RAIZ, "models", "casas", "psm", "casas_psm.glb")
SEPARACION = 10.0

# nombre: argumentos de casa_psm. Sin reja, con la barda baja de un lado; con reja, bardas a los dos
# lados. data/map/casas.json reparte un tercio sin reja y dos tercios con reja.
VARIANTES = {
    "psm_1p_a": {"pisos": 1, "puerta": "blanca", "herreria": "blanca"},
    "psm_1p_b": {"pisos": 1, "puerta": "cafe", "herreria": "negra"},
    "psm_1p_c": {"pisos": 1, "puerta": "negra", "herreria": "blanca"},
    "psm_1p_tablones": {"pisos": 1, "puerta": "blanca", "herreria": "negra", "reja": "tablones", "reja_color": "negro"},
    "psm_1p_barrotes": {"pisos": 1, "puerta": "cafe", "herreria": "blanca", "reja": "barrotes", "reja_color": "blanco"},
    "psm_1p_persiana": {"pisos": 1, "puerta": "negra", "herreria": "blanca", "reja": "persiana", "reja_color": "gris"},
    "psm_2p_a": {"pisos": 2, "puerta": "cafe", "herreria": "blanca"},
    "psm_2p_b": {"pisos": 2, "puerta": "blanca", "herreria": "negra"},
    "psm_2p_c": {"pisos": 2, "puerta": "negra", "herreria": "negra"},
    "psm_2p_tablones": {"pisos": 2, "puerta": "cafe", "herreria": "blanca", "reja": "tablones", "reja_color": "cafe"},
    "psm_2p_barrotes": {"pisos": 2, "puerta": "blanca", "herreria": "blanca", "reja": "barrotes", "reja_color": "negro"},
    "psm_2p_persiana": {"pisos": 2, "puerta": "blanca", "herreria": "negra", "reja": "persiana", "reja_color": "blanco"},
}
# El tinaco de Sketchfab es beige: en Blender lo oscurece el color de vertice, aqui la textura
TINACO_OSCURO = 0.2

G = {"__name__": "casa_psm"}
exec(open(os.path.join(RAIZ, "tools", "blender", "mapa", "casa_psm.py"), encoding="utf-8").read(), G)


def _para_gltf(m):
    """El material con la imagen directo al color base (el exportador de glTF no entiende la mezcla
    con el color de vertice); el tinaco con su textura oscurecida."""
    a = m.node_tree
    tex = next((n for n in a.nodes if n.type == "TEX_IMAGE"), None)
    bsdf = a.nodes["Principled BSDF"]
    if tex is None:
        return
    if m.name == "casa_psm_tinaco":
        img = tex.image
        w, h = img.size
        px = np.empty(w * h * 4, np.float32)
        img.pixels.foreach_get(px)
        px = px.reshape(-1, 4)
        px[:, :3] *= TINACO_OSCURO
        oscura = bpy.data.images.new("casa_psm_tinaco", w, h, alpha=True)
        oscura.pixels.foreach_set(px.ravel())
        oscura.update()
        tex.image = oscura
    a.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])


def main():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    objetos = []
    for i, (nombre, kw) in enumerate(VARIANTES.items()):
        ob = G["casa_psm"](nombre, color=(1.0, 1.0, 1.0), **kw)
        ob.location.x = i * SEPARACION
        objetos.append(ob)
    for m in bpy.data.materials:
        if m.name.startswith("casa_psm_"):
            _para_gltf(m)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objetos:
        ob.select_set(True)
    os.makedirs(os.path.dirname(SALIDA), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=SALIDA, export_format="GLB", use_selection=True,
                              export_vertex_color="NONE", export_yup=True, export_apply=True)
    print("casas_psm.glb: %d variantes, %s" % (len(objetos), ", ".join(
        "%s %+.0f m" % (n, i * SEPARACION) for i, n in enumerate(VARIANTES))))


main()
