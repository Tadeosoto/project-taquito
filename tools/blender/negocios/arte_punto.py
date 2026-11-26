# El arte de El Punto (punto.py), renderizado en Blender con Workbench plano y sin suavizado,
# con las mismas herramientas que el Sotano (tools/blender/sotano/arte.py):
#   textures/negocios/mural_punto.png    el mural del costado: atardecer de Jalisco con sol, cerros
#                                        y agaves arriba, y letras de grafiti abajo
#   textures/negocios/cantina_punto.png  el rotulo de la cantina sobre el vidrio
#   R = r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender\negocios"
#   exec(open(R + r"\arte_punto.py", encoding="utf-8").read(), {"__name__": "arte_punto"})

import os
import math
import random

_R = os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito")
exec(open(os.path.join(_R, "tools", "blender", "sotano", "arte.py"), encoding="utf-8").read(), globals())
SALIDA = os.path.join(RAIZ, "textures", "negocios")
_mat_lineal = _mat


def _mat(nombre, color):
    """Los colores de aqui son sRGB (como en un programa de dibujo): Workbench los toma lineales y
    salian deslavados."""
    return _mat_lineal(nombre + "_s", tuple(c ** 2.2 for c in color))


def mural():
    random.seed(11)
    sc = _escena("mural_punto", 512, 256, 32)    # 16 x 8 unidades
    # Cielo de atardecer en franjas
    franjas = [(0.18, 0.2, 0.55), (0.45, 0.25, 0.6), (0.85, 0.35, 0.45), (0.98, 0.55, 0.3), (1.0, 0.8, 0.35)]
    for k, c in enumerate(franjas):
        _rect(sc, 0, k * 0.9, 16, k * 0.9 + 0.95, c, -0.1)
    _circulo(sc, 11.5, 3.6, 1.6, (1.0, 0.92, 0.45), -0.05, lados=20)
    for k in range(8):
        a = k * math.tau / 8
        _rect(sc, 11.5 + math.cos(a) * 1.9 - .08, 3.6 + math.sin(a) * 1.9 - .3, 11.5 + math.cos(a) * 1.9 + .08,
              3.6 + math.sin(a) * 1.9 + .3, (1.0, 0.85, 0.3), -0.06)
    # Cerros en dos tonos
    for capa, (c, alto) in enumerate((((0.35, 0.3, 0.55), 3.2), ((0.2, 0.45, 0.35), 4.2))):
        x = -1.0
        while x < 17:
            ancho = random.uniform(2.5, 4.5)
            cima = alto + random.uniform(-0.6, 0.4)
            me = bpy.data.meshes.new("cerro")
            me.from_pydata([(x, -5.2, -0.04 + capa * .005), (x + ancho, -5.2, -0.04 + capa * .005), (x + ancho / 2, -cima, -0.04 + capa * .005)], [], [(0, 1, 2)])
            me.materials.append(_mat("m_%.2f_%.2f_%.2f" % c, c))
            ob = bpy.data.objects.new("cerro", me)
            sc.collection.objects.link(ob)
            x += ancho * 0.7
    _rect(sc, 0, 4.9, 16, 8, (0.15, 0.35, 0.25), -0.035)
    # Agaves (hojas en abanico)
    for ax in (1.2, 3.0, 5.5, 8.4, 14.6):
        for k in range(7):
            a = math.radians(-150 + k * 20)
            me = bpy.data.meshes.new("hoja")
            bx, by = ax, 5.3
            me.from_pydata([(bx - .12, -by, -.03), (bx + .12, -by, -.03), (bx + math.cos(a) * 1.1, -(by + math.sin(a) * 1.1), -.03)], [], [(0, 1, 2)])
            c = (0.3, 0.6, 0.55) if k % 2 else (0.22, 0.5, 0.48)
            me.materials.append(_mat("m_%.2f_%.2f_%.2f" % c, c))
            ob = bpy.data.objects.new("hoja", me)
            sc.collection.objects.link(ob)
    # Letras de grafiti abajo: relleno de colores, contorno negro grueso y brillos blancos
    impact = _fuente("impact.ttf")
    x = 1.3
    for letra, c in zip("SANTA MUGRE", [(0.55, 0.3, 0.85), (0.3, 0.55, 0.95), (0.95, 0.35, 0.6), (0.4, 0.8, 0.95),
                                        (0.85, 0.4, 0.9), (0, 0, 0), (0.35, 0.5, 0.95), (0.9, 0.5, 0.75),
                                        (0.5, 0.35, 0.9), (0.4, 0.75, 0.95), (0.95, 0.4, 0.55)]):
        if letra == " ":
            x += 0.6
            continue
        t = _texto(sc, letra, x, 6.35 + random.uniform(-.2, .2), 3.0, c, impact, z=0.02 + random.uniform(0, .01), contorno=(0.11, (0.05, 0.03, 0.08)))
        t.rotation_euler.z = random.uniform(-0.18, 0.18)
        _circulo(sc, x - .25, 6.0, .07, (1, 1, 1), z=0.05, lados=6)
        x += 1.42
    _render(sc, "mural_punto.png")


def cantina():
    sc = _escena("cantina_punto", 256, 64, 32)   # 8 x 2 unidades
    _rect(sc, 0, 0, 8, 2, (0.08, 0.07, 0.06), -0.1)
    negra = _fuente("ariblk.ttf")
    _texto(sc, "CANTINA", 4.0, 0.75, 0.95, (0.95, 0.8, 0.3), negra, contorno=(0.04, (0.6, 0.15, 0.1)))
    _texto(sc, "EL OLVIDO", 4.0, 1.55, 0.5, (0.95, 0.92, 0.85), negra)
    _render(sc, "cantina_punto.png")


if __name__ == "arte_punto":
    for hacer in (globals().get("SOLO") or ("mural", "cantina")):
        globals()[hacer]()
