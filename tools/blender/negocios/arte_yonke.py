# Los carteles del Yonke (yonke.py), en un solo atlas para que sean un solo material:
#   textures/negocios/yonke_carteles.png   512 x 512, 2 columnas x 4 filas de 256 x 128 px
# Celdas (columna, fila desde arriba), las usa yonke.py CARTELES:
#   (0,0) la pizarra de precios "SE COMPRA"        (1,0) REFACCIONES USADAS
#   (0,1) NO SE ACEPTA MATERIAL ROBADO              (1,1) SE VENDEN RINES
#   (0,2) HOJALATERIA Y PINTURA con telefono        (1,2) la funcion de lucha libre
#   (0,3) la Virgen del Tinaco                      (1,3) CUIDADO CON EL PERRO
#   R = r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender\negocios"
#   exec(open(R + r"\arte_yonke.py", encoding="utf-8").read(), {"__name__": "arte_yonke"})

import os
import math

_R = os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito")
exec(open(os.path.join(_R, "tools", "blender", "negocios", "arte_punto.py"), encoding="utf-8").read(), globals())

CELDA = (8.0, 4.0)       # en unidades (32 px)
NEGRO = (0.08, 0.07, 0.06)
BLANCO = (0.95, 0.93, 0.88)
ROJO = (0.8, 0.12, 0.1)
AMARILLO = (0.98, 0.8, 0.15)
AZUL = (0.15, 0.3, 0.7)


_texto_base = _texto


def _texto(sc, cuerpo, x, y, tam, *resto, **kw):
    """Las letras mas grandes que en arte.py (en la celda de 256 x 128 se perdian); ancho_max las
    encoge si no caben en la celda."""
    kw.setdefault("ancho_max", 7.4)
    return _texto_base(sc, cuerpo, x, y, tam * 1.45, *resto, **kw)


def _celda(c, f):
    return c * CELDA[0], f * CELDA[1]


def carteles():
    sc = _escena("yonke_carteles", 512, 512, 32)     # 16 x 16 unidades
    negra = _fuente("ariblk.ttf")
    impact = _fuente("impact.ttf")
    arial = _fuente("arialbd.ttf")

    # (0,0) Pizarra de precios: blanca, letras a mano en rojo y negro
    x, y = _celda(0, 0)
    _rect(sc, x, y, x + 8, y + 4, BLANCO, -0.1)
    _rect(sc, x, y, x + 8, y + .9, ROJO, -0.09)
    _texto(sc, "SE COMPRA", x + 4, y + .48, .62, BLANCO, impact)
    for k, (cosa, precio) in enumerate((("COBRE", "$95 KG"), ("ALUMINIO", "$22 KG"), ("FIERRO", "$3 KG"), ("BATERIAS", "$80 PZ"))):
        _texto(sc, cosa, x + .4, y + 1.3 + k * .7, .5, NEGRO, impact, centro=False)
        _texto(sc, precio, x + 7.6 - 2.0, y + 1.3 + k * .7, .5, ROJO, impact, centro=False)

    # (1,0) Refacciones usadas: amarillo con letra negra
    x, y = _celda(1, 0)
    _rect(sc, x, y, x + 8, y + 4, AMARILLO, -0.1)
    _texto(sc, "REFACCIONES", x + 4, y + 1.1, .95, NEGRO, negra)
    _texto(sc, "USADAS", x + 4, y + 2.1, .75, ROJO, negra)
    _texto(sc, "MOTORES · TRANSMISIONES · RINES", x + 4, y + 3.2, .34, NEGRO, arial)

    # (0,1) No se acepta material robado
    x, y = _celda(0, 1)
    _rect(sc, x, y, x + 8, y + 4, BLANCO, -0.1)
    _rect(sc, x + .15, y + .15, x + 7.85, y + 3.85, ROJO, -0.09)
    _rect(sc, x + .35, y + .35, x + 7.65, y + 3.65, BLANCO, -0.08)
    _texto(sc, "NO SE ACEPTA", x + 4, y + 1.3, .65, ROJO, impact)
    _texto(sc, "MATERIAL ROBADO", x + 4, y + 2.4, .75, NEGRO, impact)

    # (1,1) Se venden rines: azul con rines dibujados
    x, y = _celda(1, 1)
    _rect(sc, x, y, x + 8, y + 4, AZUL, -0.1)
    _texto(sc, "SE VENDEN", x + 4.9, y + 1.3, .6, BLANCO, impact)
    _texto(sc, "RINES", x + 4.9, y + 2.6, 1.1, AMARILLO, impact)
    for k, cx in enumerate((1.3,)):
        _circulo(sc, x + cx, y + 2.0, 1.2, (0.15, 0.15, 0.15), -0.05)
        _circulo(sc, x + cx, y + 2.0, .8, (0.75, 0.76, 0.78), -0.04)
        for r in range(5):
            a = r * math.tau / 5
            _rect(sc, x + cx + math.cos(a) * .5 - .1, y + 2.0 + math.sin(a) * .5 - .1, x + cx + math.cos(a) * .5 + .1,
                  y + 2.0 + math.sin(a) * .5 + .1, (0.3, 0.3, 0.32), -0.03)

    # (0,2) Hojalateria y pintura con su telefono
    x, y = _celda(0, 2)
    _rect(sc, x, y, x + 8, y + 4, (0.9, 0.9, 0.85), -0.1)
    _texto(sc, "HOJALATERIA", x + 4, y + 1.0, .8, AZUL, negra)
    _texto(sc, "Y PINTURA", x + 4, y + 1.95, .6, ROJO, negra)
    _texto(sc, "TEL. 33-2048-1177", x + 4, y + 3.15, .5, NEGRO, impact)

    # (1,2) La funcion de lucha libre
    x, y = _celda(1, 2)
    _rect(sc, x, y, x + 8, y + 4, (0.95, 0.35, 0.6), -0.1)
    _rect(sc, x, y, x + 8, y + .8, AMARILLO, -0.09)
    _texto(sc, "LUCHA LIBRE", x + 4, y + .42, .6, NEGRO, impact)
    _texto(sc, "ARENA SANTA MUGRE · DOMINGO", x + 4, y + 1.25, .3, BLANCO, arial)
    _texto(sc, "EL TINACO ENMASCARADO", x + 4, y + 2.05, .45, AMARILLO, impact)
    _texto(sc, "VS", x + 4, y + 2.6, .4, BLANCO, impact)
    _texto(sc, "EL APAGADO", x + 4, y + 3.3, .62, AMARILLO, impact)

    # (0,3) La Virgen del Tinaco: manto azul y el tinaco negro de aureola
    x, y = _celda(0, 3)
    _rect(sc, x, y, x + 8, y + 4, (0.95, 0.88, 0.65), -0.1)
    _circulo(sc, x + 1.6, y + 1.05, .62, (0.1, 0.1, 0.12), -0.06)
    me = bpy.data.meshes.new("manto")
    me.from_pydata([(x + 1.6, -(y + 1.2), -.05), (x + .5, -(y + 3.8), -.05), (x + 2.7, -(y + 3.8), -.05)], [], [(0, 1, 2)])
    me.materials.append(_mat("m_manto", (0.2, 0.45, 0.75)))
    ob = bpy.data.objects.new("manto", me)
    sc.collection.objects.link(ob)
    _circulo(sc, x + 1.6, y + 1.6, .32, (0.85, 0.65, 0.5), -0.04)
    _texto(sc, "VIRGEN DEL", x + 5.2, y + 1.3, .55, AZUL, negra)
    _texto(sc, "TINACO", x + 5.2, y + 2.2, .8, AZUL, negra)
    _texto(sc, "CUIDA ESTE NEGOCIO", x + 5.2, y + 3.1, .3, ROJO, arial)

    # (1,3) Cuidado con el perro
    x, y = _celda(1, 3)
    _rect(sc, x, y, x + 8, y + 4, AMARILLO, -0.1)
    _texto(sc, "CUIDADO", x + 4, y + 1.2, .95, NEGRO, impact)
    _texto(sc, "CON EL PERRO", x + 4, y + 2.4, .7, ROJO, impact)
    _texto(sc, "(SI MUERDE)", x + 4, y + 3.3, .35, NEGRO, arial)
    _render(sc, "yonke_carteles.png")


if __name__ == "arte_yonke":
    carteles()
