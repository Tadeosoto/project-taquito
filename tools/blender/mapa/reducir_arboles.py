# Reduce las mallas de resources/mapa/arboles_modelos.json (las deja extraer_arboles.gd, completas) para el
# juego: la corteza con el modificador Decimate de Blender (colapso) y las hojas quitando tarjetas
# (una de cada tantas) y agrandando las que quedan, para que la copa no se aclare. Se corre despues del
# extractor y reescribe el archivo (si ya estaba reducido, no lo toca):
#
#   flatpak run --filesystem=home --env=TAQUITO_RAIZ=$HOME/proyectos/project-taquito-alan org.blender.Blender --background --python tools/blender/mapa/reducir_arboles.py

import bpy
import bmesh
import json
import math
import os

RAIZ = os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito")
ARCHIVO = os.path.join(RAIZ, "resources", "mapa", "arboles_modelos.json")

# arbol -> (fraccion de triangulos de la corteza que se queda, fraccion de las tarjetas de hojas)
# arce 12.4k -> ~5k, realista 19.9k -> ~6k, roble 7.1k -> ~3.5k
REDUCCION = {"arce": (0.4, 0.5), "realista": (0.3, 0.4), "roble": (0.45, 1.0)}


def decimar(malla, razon):
    """(vertices, uvs, indices) de la malla con `razon` de sus triangulos; sin vertices compartidos
    (un vertice por esquina) para conservar las UV de cada esquina."""
    v, uv, idx = malla["v"], malla["uv"], malla["i"]
    me = bpy.data.meshes.new("t")
    me.from_pydata([tuple(p) for p in v], [], [tuple(idx[k:k + 3]) for k in range(0, len(idx), 3)])
    capa = me.uv_layers.new(name="UV")
    for bucle in me.loops:
        capa.data[bucle.index].uv = uv[bucle.vertex_index]
    ob = bpy.data.objects.new("t", me)
    bpy.context.scene.collection.objects.link(ob)
    mod = ob.modifiers.new("d", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = razon
    with bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob]):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    me = ob.data
    me.calc_loop_triangles()
    capa = me.uv_layers[0]
    nv, nuv, ni = [], [], []
    for tri in me.loop_triangles:
        for bucle in tri.loops:
            ni.append(len(nv))
            nv.append([round(c, 4) for c in me.vertices[me.loops[bucle].vertex_index].co])
            nuv.append([round(c, 4) for c in capa.data[bucle].uv])
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)
    return {"v": nv, "uv": nuv, "i": ni}


def quitar_tarjetas(malla, queda):
    """Se queda con una de cada 1/`queda` tarjetas (componentes conectados) y agranda las que quedan
    1/sqrt(queda) alrededor de su centro."""
    v, uv, idx = malla["v"], malla["uv"], malla["i"]
    tris = [tuple(idx[k:k + 3]) for k in range(0, len(idx), 3)]
    padre = list(range(len(v)))

    def raiz(a):
        while padre[a] != a:
            padre[a] = padre[padre[a]]
            a = padre[a]
        return a

    for a, b, c in tris:
        padre[raiz(a)] = raiz(b)
        padre[raiz(b)] = raiz(c)
    componentes = {}
    for t in tris:
        componentes.setdefault(raiz(t[0]), []).append(t)
    agrandar = 1.0 / math.sqrt(queda)
    nv, nuv, ni = [], [], []
    acumulado = 0.0
    for tarjeta in componentes.values():
        acumulado += queda
        if acumulado < 1.0:
            continue
        acumulado -= 1.0
        usados = sorted({i for t in tarjeta for i in t})
        centro = [sum(v[i][c] for i in usados) / len(usados) for c in range(3)]
        mapa = {}
        for i in usados:
            mapa[i] = len(nv)
            nv.append([round(centro[c] + (v[i][c] - centro[c]) * agrandar, 4) for c in range(3)])
            nuv.append(uv[i])
        for t in tarjeta:
            ni.extend(mapa[i] for i in t)
    return {"v": nv, "uv": nuv, "i": ni}


def main():
    with open(ARCHIVO, encoding="utf-8") as f:
        arboles = json.load(f)
    for nombre, arbol in arboles.items():
        if arbol.get("reducido"):
            print(nombre, "ya estaba reducido")
            continue
        corteza, hojas = REDUCCION[nombre]
        antes = {rol: len(arbol[rol]["i"]) // 3 for rol in ("corteza", "hojas") if rol in arbol}
        if corteza < 1.0 and "corteza" in arbol:
            arbol["corteza"] = decimar(arbol["corteza"], corteza)
        if hojas < 1.0 and "hojas" in arbol:
            arbol["hojas"] = quitar_tarjetas(arbol["hojas"], hojas)
        arbol["reducido"] = True
        print(nombre, {rol: (antes[rol], len(arbol[rol]["i"]) // 3) for rol in antes})
    with open(ARCHIVO, "w", encoding="utf-8") as f:
        json.dump(arboles, f, separators=(",", ":"))


main()
