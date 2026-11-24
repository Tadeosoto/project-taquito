#!/usr/bin/env python3
"""Varios trazados de una colonia de favela, cada uno con su minimapa, para escoger uno sin
tener que armar la escena en Blender ni renderear nada.

  python3 tools/blender/mapa/variantes.py la_gotera_favela --semillas=7,23,101 --salida=capturas_favela

Para cada semilla corre favela.py sobre una copia del .json (en una raiz aparte, el .json del
proyecto no se toca) y dibuja su minimapa en <salida>/mapa_<semilla>.png. Imprime el conteo de
cada uno (casas, callejones, claros, cuevas) para comparar.

Ya elegida una:  python3 tools/blender/mapa/variantes.py la_gotera_favela --usar=101
que le pone esa semilla al .json de verdad y lo regenera.
"""

import json
import os
import shutil
import sys
import tempfile

_AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.environ.get("TAQUITO_RAIZ", "") or os.path.dirname(os.path.dirname(os.path.dirname(_AQUI)))
COLONIAS = os.path.join(RAIZ, "tools", "blender", "mapa", "colonias")

SEMILLAS = [7, 23, 41, 73, 101, 157, 211, 307]


def _correr(ruta_modulo, nombre_modulo, raiz, funcion, *args, **ajustes):
    """Corre favela.py o minimapa_colonia.py con TAQUITO_RAIZ apuntando a `raiz`."""
    antes = os.environ.get("TAQUITO_RAIZ")
    os.environ["TAQUITO_RAIZ"] = raiz
    try:
        g = {"__name__": nombre_modulo, "__file__": ruta_modulo}
        exec(open(ruta_modulo, encoding="utf-8").read(), g)
        g.update(ajustes)
        return g[funcion](*args)
    finally:
        if antes is None:
            os.environ.pop("TAQUITO_RAIZ", None)
        else:
            os.environ["TAQUITO_RAIZ"] = antes


def variante(colonia, semilla, salida, escala=0.25):
    """Genera la colonia con esa semilla en una raiz temporal y deja su minimapa en `salida`."""
    tmp = tempfile.mkdtemp(prefix="favela_%d_" % semilla)
    try:
        dest = os.path.join(tmp, "tools", "blender", "mapa", "colonias")
        os.makedirs(dest)
        os.makedirs(os.path.join(tmp, "textures", "map"))
        os.makedirs(os.path.join(tmp, "resources", "mapa", colonia))
        ruta = os.path.join(dest, colonia + ".json")
        shutil.copy(os.path.join(COLONIAS, colonia + ".json"), ruta)
        datos = json.load(open(ruta, encoding="utf-8"))
        datos.setdefault("favela", {})["semilla"] = semilla
        json.dump(datos, open(ruta, "w", encoding="utf-8"), ensure_ascii=False, indent="\t")
        _correr(os.path.join(_AQUI, "favela.py"), "favela", tmp, "generar", colonia)
        datos = json.load(open(ruta, encoding="utf-8"))
        _correr(os.path.join(_AQUI, "minimapa_colonia.py"), "minimapa_colonia", tmp, "generar", datos,
                METROS_POR_PIXEL=escala)
        png = os.path.join(tmp, "textures", "map", "minimapa_%s.png" % colonia)
        os.makedirs(salida, exist_ok=True)
        final = os.path.join(salida, "mapa_%d.png" % semilla)
        shutil.copy(png, final)
        return final
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def usar(colonia, semilla):
    """Le pone esa semilla al .json de verdad y lo regenera."""
    ruta = os.path.join(COLONIAS, colonia + ".json")
    datos = json.load(open(ruta, encoding="utf-8"))
    datos.setdefault("favela", {})["semilla"] = semilla
    json.dump(datos, open(ruta, "w", encoding="utf-8"), ensure_ascii=False, indent="\t")
    _correr(os.path.join(_AQUI, "favela.py"), "favela", RAIZ, "generar", colonia)
    print("semilla %d puesta en %s.json" % (semilla, colonia))


def _principal():
    colonia = "la_gotera_favela"
    semillas = list(SEMILLAS)
    salida = os.path.join(RAIZ, "capturas_favela")
    elegida = None
    escala = 0.25
    for arg in sys.argv[1:]:
        if arg.startswith("--semillas="):
            semillas = [int(s) for s in arg.split("=", 1)[1].split(",") if s.strip()]
        elif arg.startswith("--salida="):
            salida = os.path.join(RAIZ, arg.split("=", 1)[1])
        elif arg.startswith("--escala="):
            escala = float(arg.split("=", 1)[1])
        elif arg.startswith("--usar="):
            elegida = int(arg.split("=", 1)[1])
        elif not arg.startswith("--"):
            colonia = arg
    if elegida is not None:
        usar(colonia, elegida)
        return
    for s in semillas:
        print("--- semilla %d" % s, flush=True)
        print("   ", variante(colonia, s, salida, escala), flush=True)


if __name__ == "__main__":
    _principal()
