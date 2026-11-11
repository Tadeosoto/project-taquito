# Piezas armadas del kit (lugares y adornos), en coordenadas de Godot con kit.Constructor.
# Cada una es una funcion pieza(nombre, p) -> Constructor, registrada en PIEZAS con su "tipo"
# del .json de la colonia; colonia.py pone la malla y sus cajas de choque "-colonly".
# Las medidas van en metros; el frente de cada pieza es su +Z (la calle o la plaza).

import math

_k = {"__name__": "kit", "SOLO_FUNCIONES": True}
exec(open(r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender\mapa\kit.py", encoding="utf-8").read(), _k)
globals().update({k: v for k, v in _k.items() if not k.startswith("__") and k != "SOLO_FUNCIONES"})

LONAS = {"rojo": (0.8, 0.18, 0.2), "azul": (0.15, 0.4, 0.78), "amarillo": (0.92, 0.75, 0.15),
         "verde": (0.2, 0.62, 0.32), "rosa": (0.9, 0.42, 0.62), "naranja": (0.92, 0.5, 0.15)}
for _n, _c in LONAS.items():
    COLORES_PIEZA["lona_" + _n] = _c
# Pintura del piso de la cancha (franjas como la de la foto de AG)
COLORES_PIEZA["cancha_verde"] = (0.16, 0.36, 0.3)
COLORES_PIEZA["cancha_amarilla"] = (0.9, 0.7, 0.1)
COLORES_PIEZA["cancha_muro"] = (0.16, 0.33, 0.78)
# Basura de los callejones (colonia._vida_callejones)
COLORES_PIEZA["bolsa_negra"] = (0.05, 0.05, 0.06)
COLORES_PIEZA["carton"] = (0.6, 0.45, 0.28)


def puesto(nombre, p):
    """Puesto de tianguis: cuatro tubos, una lona inclinada, la mesa con su mercancia en cajas.
    La lona y la mercancia van en `k.dia` (solo de dia, docs/mapa/colonias/santa_mugre.md: de
    noche quedan los fierros y el tablon)."""
    k = Constructor(nombre)
    tubos = k
    k = Constructor(nombre + "_Dia")
    tubos.dia = k
    ancho, fondo, alto = p.get("tam", [3.0, 2.2, 2.4])
    lona = "lona_" + p.get("lona", "rojo")
    for x in (-ancho / 2 + 0.05, ancho / 2 - 0.05):
        for z, h in ((fondo / 2 - 0.05, alto - 0.6), (-fondo / 2 + 0.05, alto)):
            tubos.caja((x, h / 2, z), (0.05, h, 0.05), "fierro")
    # Lona: inclinada hacia el frente y colgando un poco al centro
    # Bien inclinada: casi plana, a la altura de los ojos solo se veia de canto
    a, b = alto, alto - 0.6
    medio = (a + b) / 2 - 0.12
    k.cara([(-ancho / 2, b, fondo / 2 + 0.2), (ancho / 2, b, fondo / 2 + 0.2), (ancho / 2, medio, 0), (-ancho / 2, medio, 0)], lona)
    k.cara([(-ancho / 2, medio, 0), (ancho / 2, medio, 0), (ancho / 2, a, -fondo / 2), (-ancho / 2, a, -fondo / 2)], lona)
    k.cara([(-ancho / 2, medio, 0), (-ancho / 2, a, -fondo / 2), (ancho / 2, a, -fondo / 2), (ancho / 2, medio, 0)], lona)
    k.cara([(-ancho / 2, b, fondo / 2 + 0.2), (-ancho / 2, medio, 0), (ancho / 2, medio, 0), (ancho / 2, b, fondo / 2 + 0.2)], lona)
    # Mesa y cajas de fruta
    tubos.caja((0, 0.85, 0.2), (ancho - 0.3, 0.06, fondo * 0.55), "foto_madera", choca=False)
    tubos.caja((0, 0.42, 0.2), (ancho - 0.4, 0.84, fondo * 0.5), "foto_madera")
    for i, x in enumerate((-0.8, 0.0, 0.8)):
        if abs(x) < ancho / 2 - 0.3:
            fruta = ("rojo", "naranja_gela", "pasto_muerto")[(i + len(nombre)) % 3]
            k.caja((x, 1.0, 0.25), (0.6, 0.24, 0.45), "foto_madera")
            k.caja((x, 1.13, 0.25), (0.52, 0.04, 0.38), fruta)
    tubos.choques.append(((0, 0.5, 0.2), (ancho - 0.3, 1.0, fondo * 0.55), 0.0))
    return tubos


def banca(nombre, p):
    k = Constructor(nombre)
    largo = p.get("largo", 2.0)
    k.caja((0, 0.42, 0), (largo, 0.08, 0.45), "concreto", choca=True)
    k.caja((0, 0.75, -0.2), (largo, 0.45, 0.08), "concreto")
    for x in (-largo / 2 + 0.15, largo / 2 - 0.15):
        k.caja((x, 0.2, 0), (0.12, 0.4, 0.4), "concreto")
    return k


def jardinera(nombre, p):
    """Arriate de cantera con el pasto muerto y un arbol seco."""
    k = Constructor(nombre)
    ancho, fondo = p.get("tam", [4.0, 2.0])
    h = 0.45
    for (cx, cz, sx, sz) in ((0, fondo / 2, ancho, 0.25), (0, -fondo / 2, ancho, 0.25), (ancho / 2, 0, 0.25, fondo), (-ancho / 2, 0, 0.25, fondo)):
        k.caja((cx, h / 2, cz), (sx, h, sz), "foto_cantera", choca=True)
    k.cara([(-ancho / 2, h - 0.1, fondo / 2), (ancho / 2, h - 0.1, fondo / 2), (ancho / 2, h - 0.1, -fondo / 2), (-ancho / 2, h - 0.1, -fondo / 2)], "tierra")
    if p.get("arbol", True):
        k.cilindro((0, h, 0), 0.14, 2.6, "foto_madera", lados=5, radio_arriba=0.08)
        for i in range(3):
            a = i * math.tau / 3 + len(nombre)
            k.caja((math.cos(a) * 0.4, h + 2.3 + i * 0.2, math.sin(a) * 0.4), (0.06, 0.06, 1.0), "foto_madera", a)
    return k


def fuente(nombre, p):
    """Fuente seca: la taza de cantera con lodo al fondo y la columna sin agua."""
    k = Constructor(nombre)
    r = p.get("radio", 2.5)
    k.cilindro((0, 0, 0), r, 0.6, "foto_cantera", lados=12, tapa=False, choca=True)
    k.cilindro((0, 0, 0), r - 0.25, 0.6, "foto_cantera_oscura", lados=12, tapa=False)
    k.cilindro((0, 0, 0), r - 0.25, 0.15, "tierra", lados=12)
    k.cilindro((0, 0, 0), 0.35, 1.6, "foto_cantera", lados=8)
    k.cilindro((0, 1.6, 0), 0.9, 0.2, "foto_cantera", lados=8)
    return k


def kiosco(nombre, p):
    """El kiosco de la plaza (como el de Arandas: basamento octagonal de cantera con arquitos,
    galeria de vidrio con marcos de fierro verde, techo verde abombado y linternilla), que se
    volvio la torre de agua del barrio: el tinaco comunitario va montado arriba, con su
    escalera, la manguera que baja a la llave y el letrero de GelA."""
    k = Constructor(nombre)
    r = p.get("radio", 4.4)
    lados = 8
    giro0 = math.tau / 16
    def anillo(radio, y):
        return [(math.cos(i * math.tau / lados + giro0) * radio, y, math.sin(i * math.tau / lados + giro0) * radio) for i in range(lados)]
    # Escalones y basamento con un arquito oscuro en cada cara
    k.cilindro((0, 0, 0), r + 0.9, 0.2, "foto_cantera_rosa", lados=lados, choca=True)
    k.cilindro((0, 0.2, 0), r + 0.5, 0.2, "foto_cantera_rosa", lados=lados)
    k.cilindro((0, 0.4, 0), r, 1.0, "foto_cantera_rosa", lados=lados, choca=True)
    ab = anillo(r + 0.01, 0.4)
    for i in range(lados):
        a, b = ab[i], ab[(i + 1) % lados]
        mx, mz = (a[0] + b[0]) / 2, (a[2] + b[2]) / 2
        giro = math.atan2(mx, mz)
        k.caja((mx, 0.85, mz), (0.9, 0.6, 0.05), "vidrio", giro)
    piso = 1.4
    # Galeria: marcos de fierro verde, vidrio entre ellos, una puerta al frente
    rg = r - 0.4
    pg = anillo(rg, piso)
    alto_g = 2.6
    for i in range(lados):
        a = pg[i]
        k.cilindro((a[0], piso, a[2]), 0.09, alto_g + 0.6, "fierro_verde", lados=5)
    for i in range(lados):
        a, b = pg[i], pg[(i + 1) % lados]
        if i == 2:          # la puerta (frente, +Z)
            k.caja(((a[0] + b[0]) / 2, piso + alto_g, (a[2] + b[2]) / 2), (math.hypot(b[0] - a[0], b[2] - a[2]), 0.12, 0.12),
                   "fierro_verde", math.atan2((a[0] + b[0]) / 2, (a[2] + b[2]) / 2))
            continue
        k.cara([(b[0], piso + 0.1, b[2]), (a[0], piso + 0.1, a[2]), (a[0], piso + alto_g, a[2]), (b[0], piso + alto_g, b[2])], "vidrio")
        k.cara([(a[0], piso + 0.1, a[2]), (b[0], piso + 0.1, b[2]), (b[0], piso + alto_g, b[2]), (a[0], piso + alto_g, a[2])], "vidrio")
        for y in (piso + 0.1, piso + 1.0, piso + alto_g):
            k.caja(((a[0] + b[0]) / 2, y, (a[2] + b[2]) / 2), (math.hypot(b[0] - a[0], b[2] - a[2]), 0.08, 0.08),
                   "fierro_verde", math.atan2((a[0] + b[0]) / 2, (a[2] + b[2]) / 2))
    # Techo: cornisa, faldon verde abombado (dos tramos) y la linternilla
    techo = piso + alto_g + 0.6
    k.cilindro((0, techo - 0.25, 0), r + 0.4, 0.3, "fierro_verde", lados=lados)
    k.cilindro((0, techo + 0.05, 0), r + 0.4, 0.9, "foto_lamina_verde", lados=lados, radio_arriba=r * 0.6, tapa=False)
    k.cilindro((0, techo + 0.95, 0), r * 0.6, 0.7, "foto_lamina_verde", lados=lados, radio_arriba=1.9, tapa=False)
    losa = techo + 1.65
    k.cilindro((0, losa, 0), 2.0, 0.25, "concreto", lados=lados)
    # El tinaco comunitario (2.2 m, 10 mil litros) con su tapa, en lugar de la linternilla
    tinaco = losa + 0.25
    k.cilindro((0, tinaco, 0), 1.5, 2.2, "tinaco", lados=12)
    k.cono((0, tinaco + 2.2, 0), 1.5, 0.45, "tinaco", lados=12)
    # Escalera de gato por atras, de la galeria al tinaco
    atras = -(r + 0.45)
    for lado in (-0.25, 0.25):
        k.caja((lado, (piso + tinaco + 2.2) / 2, atras), (0.05, tinaco + 2.2 - piso, 0.05), "fierro")
    for y in range(int((tinaco + 2.2 - piso) / 0.35)):
        k.caja((0, piso + 0.3 + y * 0.35, atras), (0.5, 0.04, 0.04), "fierro")
    # La manguera baja por un marco a la llave, al pie del basamento, y su letrero de GelA
    col = pg[1]
    k.caja((col[0] * 1.08, (0.6 + losa) / 2, col[2] * 1.08), (0.08, losa - 0.6, 0.08), "manguera")
    k.caja((col[0] * 1.2, 0.9, col[2] * 1.2), (0.14, 0.14, 0.4), "llave", math.atan2(col[0], col[2]))
    k.caja((r + 0.55, 1.6, -1.6), (0.05, 0.8, 1.4), "azul_gela", math.pi / 2)
    return k


def ficus(nombre, p):
    """Ficus podado en bola, como los de la plaza de Arandas, en su cajete de cantera con pasto."""
    k = Constructor(nombre)
    alto = p.get("alto", 4.2)
    radio = p.get("radio", 2.0)
    k.caja((0, 0.15, 0), (1.6, 0.3, 1.6), "foto_cantera_rosa")
    k.cara([(-0.7, 0.31, 0.7), (0.7, 0.31, 0.7), (0.7, 0.31, -0.7), (-0.7, 0.31, -0.7)], "hojas")
    k.cilindro((0, 0.3, 0), 0.18, alto - radio, "foto_madera", lados=6, radio_arriba=0.13)
    k.esfera((0, alto, 0), radio, "hojas", seg=8, anillos=6, aplastar=0.85)
    k.choques.append(((0, 0.9, 0), (0.6, 1.8, 0.6), 0.0))
    return k


def _pilastra(k, x, y0, z, alto, mat, giro=0.0, ancho=0.45):
    k.caja((x, y0 + alto / 2, z), (ancho, alto, ancho), mat, giro)


def _columna_toscana(k, x, z, alto, mat="foto_cantera_rosa", radio=0.28):
    """Basa cuadrada, fuste redondo y capitel cuadrado (las columnas de los portales)."""
    k.caja((x, 0.15, z), (radio * 2.6, 0.3, radio * 2.6), mat)
    k.cilindro((x, 0.3, z), radio, alto - 0.6, mat, lados=8, radio_arriba=radio * 0.88)
    k.caja((x, alto - 0.15, z), (radio * 2.6, 0.3, radio * 2.6), mat)


def _ojo_de_buey(k, x, y, z, ancho, alto, marco="foto_cantera_rosa"):
    """Ventana ovalada con su marco de cantera, de frente a +Z en el plano z."""
    puntos = [(x + math.cos(a) * ancho / 2, y + math.sin(a) * alto / 2) for a in (i * math.tau / 10 for i in range(10))]
    k.cara([(px + (px - x) * 0.35, py + (py - y) * 0.35, z) for px, py in puntos], marco)
    k.cara([(px, py, z + 0.02) for px, py in puntos], "vidrio")


def _arcada(k, largo, fondo, alto_arco, pared, alto, color_tienda=(0.9, 0.9, 0.88)):
    """Arcos sobre columnas toscanas a lo largo de x en z = +fondo/2, con la pared de las
    tiendas atras (cortinas y puertas del atlas), techo de vigas y faroles colgados."""
    arcos = max(1, round(largo / 4.0))
    paso = largo / arcos
    frente = fondo / 2
    portal = 3.6
    grueso = 0.6
    pilar = 0.7                    # lo que ocupa cada columna entre dos arcos
    r = (paso - pilar) / 2
    arranque = alto_arco - r       # donde nace cada arco: el capitel de la columna
    zf, za = frente, frente - grueso
    lados = 8
    # El muro de aplanado blanco con los vanos de los arcos: un poligono por tramo (de columna a
    # columna, del arranque hasta arriba, sin el medio circulo), por delante y por detras
    for i in range(arcos):
        x0 = -largo / 2 + paso * i
        x1, cx = x0 + paso, x0 + paso / 2
        curva = [(cx + math.cos(math.pi * (1 - j / lados)) * r, arranque + math.sin(math.pi * (1 - j / lados)) * r) for j in range(lados + 1)]
        perfil = [(x0, alto), (x0, arranque)] + curva + [(x1, arranque), (x1, alto)]
        k.cara([(x, y, zf) for x, y in perfil], "foto_aplanado_blanco")
        k.cara([(x, y, za) for x, y in perfil[::-1]], "foto_aplanado_blanco")
        # El intrados (la cara de abajo del arco) y la moldura de cantera alrededor
        for (ax, ay), (bx, by) in zip(curva, curva[1:]):
            k.cara([(ax, ay, za), (bx, by, za), (bx, by, zf), (ax, ay, zf)], "foto_cantera_rosa")
        afuera = [(cx + (x - cx) * (r + 0.28) / r, arranque + (y - arranque) * (r + 0.28) / r) for x, y in curva]
        for (ax, ay), (bx, by), (cx2, cy2), (dx, dy) in zip(curva, curva[1:], afuera[1:], afuera):
            k.cara([(ax, ay, zf + 0.03), (bx, by, zf + 0.03), (cx2, cy2, zf + 0.03), (dx, dy, zf + 0.03)], "foto_cantera_rosa")
    # Las puntas del muro y su tapa
    for x, signo in ((-largo / 2, -1), (largo / 2, 1)):
        k.cara([(x, 0, za), (x, 0, zf), (x, alto, zf), (x, alto, za)][::(-signo)], "foto_aplanado_blanco")
    k.cara([(-largo / 2, alto, zf), (largo / 2, alto, zf), (largo / 2, alto, za), (-largo / 2, alto, za)], "foto_aplanado_blanco")
    # Columnas toscanas redondas, del piso al arranque de los arcos
    for i in range(arcos + 1):
        x = -largo / 2 + paso * i
        _columna_toscana(k, x, frente - grueso / 2, arranque)
        k.choques.append(((x, arranque / 2, frente - grueso / 2), (0.6, arranque, 0.6), 0.0))
    k.choques.append(((0, (alto_arco + alto) / 2, frente - grueso / 2), (largo, alto - alto_arco, grueso), 0.0))
    for i in range(arcos + 1):
        x = -largo / 2 + paso * i
        _ojo_de_buey(k, x, alto_arco + 0.55, frente + 0.02, 0.9, 1.2)
    # Techo del portal (vigas de madera) y la pared de atras con las tiendas
    # (de la cara de atras del muro de los arcos a la pared de las tiendas: si no, se asomaban)
    techo = portal - grueso
    k.caja((0, alto_arco + 0.35, za - techo / 2), (largo, 0.15, techo), "foto_madera")
    for i in range(int(largo / 0.9)):
        k.caja((-largo / 2 + 0.45 + i * 0.9, alto_arco + 0.2, za - techo / 2), (0.15, 0.2, techo), "foto_madera")
    atras = frente - portal
    tiendas = max(1, round(largo / 2.75))
    ancho_t = largo / tiendas
    for i in range(tiendas):
        x0 = -largo / 2 + ancho_t * i
        celda = (CORTINA, PUERTA, CORTINA, ZAGUAN)[i % 4]
        k.mosaico([(x0, 0, atras), (x0 + ancho_t, 0, atras), (x0 + ancho_t, PISO, atras), (x0, PISO, atras)], celda, color_tienda)
        k.mosaico([(x0, PISO, atras), (x0 + ancho_t, PISO, atras), (x0 + ancho_t, alto_arco + 0.3, atras), (x0, alto_arco + 0.3, atras)], LISO, color_tienda)
    # Faroles colgados a media arcada
    for i in range(arcos):
        x = -largo / 2 + paso * (i + 0.5)
        k.caja((x, alto_arco - 0.3, frente - 1.6), (0.03, 0.6, 0.03), "fierro")
        k.caja((x, alto_arco - 0.8, frente - 1.6), (0.3, 0.45, 0.3), "farol")
        k.cono((x, alto_arco - 0.58, frente - 1.6), 0.25, 0.2, "fierro", lados=4)
    return atras


def portal(nombre, p):
    """Portales: fila de tiendas de un piso detras de arcos de cantera sobre columnas toscanas,
    con aplanado blanco, ojos de buey sobre las columnas, techo de vigas y faroles (los de la
    calle Juarez de Arandas)."""
    k = Constructor(nombre)
    largo, fondo = p.get("largo", 20.0), p.get("fondo", 12.0)
    alto_arco, alto = 4.6, 6.4
    atras = _arcada(k, largo, fondo, alto_arco, None, alto)
    # El cuerpo de las tiendas detras de la pared, con su azotea y pretil
    cuerpo = fondo - 3.6
    k.caja((0, alto / 2, atras - cuerpo / 2 - 0.01), (largo, alto, cuerpo), "foto_aplanado_blanco", choca=True)
    k.caja((0, alto + 0.25, fondo / 2 - 0.3), (largo + 0.6, 0.5, 0.7), "foto_cantera_rosa")
    return k


def palacio(nombre, p):
    """Palacio de gobierno: los portales en la planta baja y un segundo piso de aplanado blanco
    con ventanas de marco de cantera, el balcon corrido, el escudo de los Lazcano, el asta y las
    mantas de GelA colgadas de los arcos."""
    k = Constructor(nombre)
    ancho, alto, fondo = p.get("tam", [50.0, 9.5, 18.0])
    alto_arco = 4.8
    atras = _arcada(k, ancho, fondo, alto_arco, None, alto_arco + 1.6)
    frente = fondo / 2
    # Cuerpo de dos pisos detras del portal
    cuerpo = fondo - 3.6
    k.caja((0, alto / 2, atras - cuerpo / 2 - 0.01), (ancho, alto, cuerpo), "foto_aplanado_blanco", choca=True)
    # Segundo piso: el muro corre sobre el portal hasta el frente, con sus ventanas
    k.caja((0, (alto_arco + 1.6 + alto) / 2, frente - 1.8), (ancho + 0.6, alto - alto_arco - 1.6, 3.6), "foto_aplanado_blanco")
    k.choques.append(((0, alto_arco + 0.8, frente - 1.8), (ancho, 0.8, 3.6), 0.0))
    arcos = max(1, round(ancho / 4.0))
    paso = ancho / arcos
    y_v = alto_arco + 2.9
    for i in range(arcos):
        x = -ancho / 2 + paso * (i + 0.5)
        k.caja((x, y_v, frente + 0.02), (1.2, 2.0, 0.08), "vidrio")
        k.caja((x, y_v + 1.15, frente + 0.06), (1.6, 0.3, 0.16), "foto_cantera_rosa")
        k.caja((x, y_v - 1.05, frente + 0.25), (1.6, 0.12, 0.5), "foto_cantera_rosa")
        for j in range(5):
            k.caja((x - 0.6 + j * 0.3, y_v - 0.7, frente + 0.48), (0.03, 0.6, 0.03), "fierro")
        k.caja((x, y_v - 0.4, frente + 0.48), (1.5, 0.04, 0.04), "fierro")
    # Cornisa, remate con el escudo y el asta
    k.caja((0, alto + 0.2, frente - 1.8), (ancho + 0.8, 0.4, 3.8), "foto_cantera_rosa")
    k.caja((0, alto + 1.4, frente - 0.4), (7.0, 2.4, 0.5), "foto_cantera_rosa")
    # El escudo de los Lazcano: un octagono dorado parado en el remate
    k.cara([(math.cos(a) * 0.9, alto + 1.4 + math.sin(a) * 0.9, frente - 0.12) for a in (i * math.tau / 8 + math.tau / 16 for i in range(8))], "oro")
    k.caja((0, alto + 4.5, frente - 0.6), (0.1, 4.5, 0.1), "fierro")
    # Mantas de GelA colgadas de los arcos
    for x in (-ancho * 0.3, ancho * 0.3):
        k.caja((x, alto_arco + 0.9, frente + 0.12), (5.0, 1.4, 0.04), "azul_gela")
        k.caja((x, alto_arco + 0.9, frente + 0.15), (4.4, 0.8, 0.03), "manta_gela")
    return k


def parroquia(nombre, p):
    """La parroquia, como la de Santa Maria de Guadalupe en Arandas: nave de mamposteria con
    cornisa de cantera rosa, portada labrada de columnas pareadas con nicho y remate de volutas,
    un ojo de buey, la torre alta a la izquierda (campanario, reloj, balaustrada, cupula de
    azulejo amarillo, linternilla y cruz de fierro) y una torrecilla a la derecha. Frente a +Z."""
    k = Constructor(nombre)
    ancho, fondo = p.get("tam", [18.0, 28.0])
    alto = p.get("alto", 11.0)
    hz = fondo / 2
    frente = hz + 0.02
    # Nave y cornisa
    k.caja((0, alto / 2, 0), (ancho, alto, fondo), "foto_mamposteria", choca=True)
    k.caja((0, alto + 0.25, 0), (ancho + 0.5, 0.5, fondo + 0.5), "foto_cantera_rosa")
    k.cilindro((0, alto + 0.5, -hz * 0.4), ancho * 0.24, 1.4, "foto_mamposteria", lados=10)
    k.cilindro((0, alto + 1.9, -hz * 0.4), ancho * 0.24, 1.4, "foto_azulejo_amarillo", lados=10, radio_arriba=ancho * 0.1)
    k.cilindro((0, alto + 3.3, -hz * 0.4), ancho * 0.1, 0.9, "foto_azulejo_amarillo", lados=10, radio_arriba=0.25)
    # Portada labrada: pares de columnas a los lados de la puerta, entablamento, nicho y volutas
    ancho_p = 6.0
    k.caja((0, 4.6, frente + 0.15), (ancho_p, 9.2, 0.3), "foto_cantera_rosa")
    k.arco((0, 0, frente + 0.4), 2.6, 5.2, 0.4, "foto_cantera_rosa")
    k.caja((0, 2.3, frente + 0.32), (2.5, 4.6, 0.06), "fierro")
    for lado in (-1, 1):
        for d in (1.8, 2.5):
            k.cilindro((lado * d, 0, frente + 0.55), 0.22, 4.6, "foto_cantera_rosa", lados=8)
            k.cilindro((lado * d, 5.0, frente + 0.5), 0.18, 2.6, "foto_cantera_rosa", lados=8)
    k.caja((0, 4.8, frente + 0.55), (ancho_p + 0.4, 0.4, 0.5), "foto_cantera_rosa")
    k.caja((0, 7.6, frente + 0.5), (ancho_p + 0.2, 0.3, 0.4), "foto_cantera_rosa")
    k.caja((0, 6.3, frente + 0.36), (1.2, 2.0, 0.06), "vidrio")
    k.arco((0, 5.2, frente + 0.42), 1.2, 2.2, 0.15, "foto_cantera_rosa")
    for lado in (-1, 1):
        k.esfera((lado * 1.6, 8.3, frente + 0.4), 0.55, "foto_cantera_rosa", seg=6, anillos=4, aplastar=0.6)
    k.esfera((0, 8.8, frente + 0.4), 0.8, "foto_cantera_rosa", seg=6, anillos=4, aplastar=0.6)
    # Ojo de buey y ventanita del lado de la torre
    _ojo_de_buey(k, -ancho * 0.33, alto - 2.0, frente, 1.4, 1.4)
    k.caja((-ancho * 0.33, alto - 4.4, frente + 0.02), (0.8, 0.9, 0.06), "vidrio")
    # Torre alta a la izquierda (vista de frente: -x)
    t = 5.6
    tx, tz = -ancho / 2 + t / 2, hz - t / 2
    k.caja((tx, alto / 2, tz), (t, alto, t), "foto_mamposteria")
    k.caja((tx, alto + 0.25, tz), (t + 0.5, 0.5, t + 0.5), "foto_cantera_rosa")
    camp = alto + 0.5
    k.caja((tx, camp + 2.3, tz), (t - 0.3, 4.6, t - 0.3), "foto_mamposteria")
    for giro in (0.0, math.pi / 2, math.pi, -math.pi / 2):
        ox, oz = math.sin(giro) * (t / 2 - 0.12), math.cos(giro) * (t / 2 - 0.12)
        k.caja((tx + ox, camp + 1.8, tz + oz), (1.6, 3.0, 0.08), "hueco", giro)
        k.arco((tx + ox, camp, tz + oz), 1.6, 3.6, 0.3, "foto_cantera_rosa", giro)
    k.cono((tx, camp + 0.8, tz + 0.2), 0.7, 1.0, "bronce", lados=6)
    k.caja((tx, camp + 4.75, tz), (t + 0.3, 0.4, t + 0.3), "foto_cantera_rosa")
    reloj = camp + 4.95
    k.caja((tx, reloj + 2.0, tz), (t - 0.6, 4.0, t - 0.6), "foto_mamposteria")
    for giro in (0.0, math.pi / 2, math.pi, -math.pi / 2):
        ox, oz = math.sin(giro) * (t / 2 - 0.28), math.cos(giro) * (t / 2 - 0.28)
        c, s = math.cos(giro), math.sin(giro)
        caratula = [(tx + ox + math.cos(a) * 0.7 * c, reloj + 2.4 + math.sin(a) * 0.7, tz + oz - math.cos(a) * 0.7 * s)
                    for a in (i * math.tau / 10 for i in range(10))]
        k.cara(caratula, "blanco_reloj")
        k.caja((tx + ox * 1.02, reloj + 2.6, tz + oz * 1.02), (0.06, 0.5, 0.06), "fierro", giro)
    k.caja((tx, reloj + 4.15, tz), (t, 0.3, t), "foto_cantera_rosa")
    for i in range(12):
        lado = i // 3
        u = (i % 3 - 1) * (t / 3)
        ox = [u, t / 2 - 0.1, -u, -t / 2 + 0.1][lado]
        oz = [t / 2 - 0.1, u, -t / 2 + 0.1, -u][lado]
        k.cilindro((tx + ox, reloj + 4.3, tz + oz), 0.1, 0.6, "foto_cantera_rosa", lados=5)
    domo = reloj + 4.3
    k.cilindro((tx, domo, tz), t / 2 - 0.7, 0.9, "blanco_reloj", lados=8)
    k.cilindro((tx, domo + 0.9, tz), t / 2 - 0.7, 1.2, "foto_azulejo_amarillo", lados=8, radio_arriba=t / 4 - 0.2)
    k.cilindro((tx, domo + 2.1, tz), t / 4 - 0.2, 0.6, "foto_azulejo_amarillo", lados=8, radio_arriba=0.4)
    k.cilindro((tx, domo + 2.7, tz), 0.35, 1.2, "foto_cantera_rosa", lados=6, radio_arriba=0.2)
    k.caja((tx, domo + 4.5, tz), (0.1, 2.0, 0.1), "fierro")
    k.caja((tx, domo + 4.9, tz), (0.9, 0.1, 0.1), "fierro")
    # Torrecilla a la derecha
    t2 = 3.8
    rx, rz = ancho / 2 - t2 / 2, hz - t2 / 2
    k.caja((rx, (alto + 2.6) / 2, rz), (t2, alto + 2.6, t2), "foto_mamposteria")
    k.caja((rx, alto + 2.8, rz), (t2 + 0.3, 0.4, t2 + 0.3), "foto_cantera_rosa")
    k.cilindro((rx, alto + 3.0, rz), t2 / 2 - 0.3, 0.6, "blanco_reloj", lados=8)
    k.cilindro((rx, alto + 3.6, rz), t2 / 2 - 0.3, 1.1, "foto_azulejo_amarillo", lados=8, radio_arriba=0.35)
    k.caja((rx, alto + 5.4, rz), (0.08, 1.4, 0.08), "fierro")
    k.caja((rx, alto + 5.7, rz), (0.6, 0.08, 0.08), "fierro")
    return k


def atrio(nombre, p):
    """El atrio de la parroquia: piso de cantera, barda baja de piedra con reja de fierro,
    dos obeliscos con farol de globo a la entrada (al frente, +Z) y veladoras con estampitas del
    tinaco al pie de la reja (el culto que se cuela, docs/mapa/colonias/santa_mugre.md)."""
    k = Constructor(nombre)
    ancho, fondo = p.get("tam", [20.0, 8.0])
    hx, hz = ancho / 2, fondo / 2
    k.cara([(-hx, 0.04, hz), (hx, 0.04, hz), (hx, 0.04, -hz), (-hx, 0.04, -hz)], "foto_cantera_rosa")
    puerta = 3.4
    for (x0, x1) in ((-hx, -puerta / 2), (puerta / 2, hx)):
        largo = x1 - x0
        cx = (x0 + x1) / 2
        k.caja((cx, 0.45, hz), (largo, 0.9, 0.5), "foto_mamposteria", choca=True)
        k.caja((cx, 0.95, hz), (largo + 0.1, 0.1, 0.6), "foto_cantera_rosa")
        k.caja((cx, 1.6, hz), (largo, 0.05, 0.05), "fierro")
        for i in range(int(largo / 0.25)):
            k.caja((x0 + 0.12 + i * 0.25, 1.3, hz), (0.03, 0.7, 0.03), "fierro")
        k.choques.append(((cx, 1.3, hz), (largo, 0.8, 0.2), 0.0))
    for lado in (-1, 1):
        # Barda de los lados, hasta la parroquia
        k.caja((lado * hx, 0.45, 0), (0.5, 0.9, fondo), "foto_mamposteria", choca=True)
        # Obeliscos de la entrada y los pilares de las esquinas
        for x, alto in ((lado * (puerta / 2 + 0.4), 4.0), (lado * hx, 2.6)):
            k.caja((x, 0.6, hz), (0.9, 1.2, 0.9), "foto_cantera_rosa", choca=True)
            k.cilindro((x, 1.2, hz), 0.42, alto - 1.2, "foto_cantera_rosa", lados=4, radio_arriba=0.25)
            k.cono((x, alto, hz), 0.3, 0.4, "foto_cantera_rosa", lados=4)
            if alto > 3:
                k.esfera((x, alto + 0.7, hz), 0.3, "farol", seg=6, anillos=4)
    # Veladoras al pie de la reja: vasos con su flama, la mitad con el tinaco impreso (una franja
    # negra), y en medio el tinaquito de yeso de la Virgen con flores. Si el atrio va sobre un
    # basamento (`y`), van en la calle: al piso y mas alla de los escalones
    abajo = -p.get("y", 0.0)
    sale = 0.0 if abajo == 0.0 else 0.75
    for i in range(13):
        x, z = -hx + 0.9 + i * 0.32, hz + 0.45 + sale + (i % 3) * 0.14
        alto = 0.16 + (i % 2) * 0.08
        k.cilindro((x, abajo, z), 0.05, alto, "veladora", lados=6)
        k.esfera((x, abajo + alto + 0.03, z), 0.025, "farol", seg=4, anillos=3)
        if i % 2 == 0:
            k.caja((x, abajo + alto * 0.55, z + 0.045), (0.06, 0.04, 0.01), "tinaco")
    tx = -hx + 0.9 + 6 * 0.32
    k.caja((tx, abajo + 0.12, hz + 0.95 + sale), (0.5, 0.24, 0.4), "foto_cantera_rosa")
    k.cilindro((tx, abajo + 0.24, hz + 0.95 + sale), 0.15, 0.3, "tinaco", lados=8)
    k.cono((tx, abajo + 0.54, hz + 0.95 + sale), 0.16, 0.08, "tinaco", lados=8)
    for j, col in enumerate(("lona_rosa", "lona_amarillo", "lona_rojo", "blanco_cal")):
        k.esfera((tx - 0.3 + j * 0.2, abajo + 0.12, hz + 1.25 + sale), 0.07, col, seg=5, anillos=3)
    # Estampitas pegadas en la reja de los dos lados de la entrada
    for lado in (-1, 1):
        for i in range(7):
            x = lado * (puerta / 2 + 0.95 + i * 0.32)
            y = 1.15 + (i % 3) * 0.13
            k.caja((x, y, hz + 0.04), (0.12, 0.17, 0.01), ("blanco_cal", "lona_azul", "lona_amarillo")[i % 3])
            k.caja((x, y, hz + 0.05), (0.05, 0.06, 0.005), "tinaco")
    return k


def cancha(nombre, p):
    """Cancha de futbolito encajonada entre casas (la foto de AG de la favela): losa pintada a
    franjas verde y amarillo con rayas blancas, muro de block pintado de azul con murales por
    dentro, malla ciclonica encima con lonas de anuncios, porterias con red, dos postes con
    reflectores, un escalon por dentro para los que miran y la entrada (`entrada`: "+x", "-x",
    "+z" o "-z") a media cancha. `tam` = [ancho (x), largo (z)] de las rayas."""
    k = Constructor(nombre)
    ancho, largo = p.get("tam", [11.0, 18.0])        # x, z
    orilla = p.get("orilla", 0.8)                    # concreto entre las rayas y el muro
    muro = p.get("muro_alto", 2.2)                   # block pintado; arriba, la malla
    alto = p.get("alto", 5.0)                        # hasta donde llega la malla
    pintura = p.get("pintura", "cancha_muro")        # material liso del muro (COLORES_PIEZA)
    entrada = p.get("entrada", "+x")
    semilla = sum((i + 1) * ord(c) for i, c in enumerate(nombre))
    hx, hz = ancho / 2 + orilla, largo / 2 + orilla
    w, l = ancho / 2, largo / 2

    # Losa verde con franjas amarillas a lo ancho, como la pintura de la foto
    k.cara([(-hx, 0.05, hz), (hx, 0.05, hz), (hx, 0.05, -hz), (-hx, 0.05, -hz)], "cancha_verde")
    franjas = max(4, round(largo / 2.2))
    paso = 2 * hz / franjas
    for i in range(1, franjas, 2):
        z0, z1 = -hz + i * paso, -hz + (i + 1) * paso
        k.cara([(-hx, 0.055, z1), (hx, 0.055, z1), (hx, 0.055, z0), (-hx, 0.055, z0)], "cancha_amarilla")

    def raya(x0, z0, x1, z1, grueso=0.1):
        dx, dz = x1 - x0, z1 - z0
        ll = math.hypot(dx, dz) or 1.0
        nx, nz = -dz / ll * grueso / 2, dx / ll * grueso / 2
        k.cara([(x0 - nx, 0.06, z0 - nz), (x1 - nx, 0.06, z1 - nz), (x1 + nx, 0.06, z1 + nz), (x0 + nx, 0.06, z0 + nz)], "blanco_cal")
    for a, b in (((-w, -l), (w, -l)), ((w, -l), (w, l)), ((w, l), (-w, l)), ((-w, l), (-w, -l)), ((-w, 0), (w, 0))):
        raya(a[0], a[1], b[0], b[1])
    r_centro = min(2.0, ancho / 4)
    circulo = [(math.cos(i * math.tau / 16) * r_centro, math.sin(i * math.tau / 16) * r_centro) for i in range(17)]
    for a, b in zip(circulo, circulo[1:]):
        raya(a[0], a[1], b[0], b[1])
    r_area = min(3.5, ancho / 3, largo / 5)
    for signo in (-1, 1):                            # areas: medio circulo frente a cada porteria
        arco = [(math.cos(math.pi * i / 10) * r_area, signo * (l - math.sin(math.pi * i / 10) * r_area)) for i in range(11)]
        for a, b in zip(arco, arco[1:]):
            raya(a[0], a[1], b[0], b[1])

    # Porterias de futbolito (3 x 2 m) con red de alambre atras
    for signo in (-1, 1):
        z = signo * l
        for x in (-1.5, 1.5):
            k.caja((x, 1.0, z), (0.1, 2.0, 0.1), "blanco_cal")
            k.caja((x, 0.05, z + signo * 0.5), (0.06, 0.06, 1.0), "blanco_cal")
        k.caja((0, 2.0, z), (3.1, 0.1, 0.1), "blanco_cal")
        k.caja((0, 1.0, z + signo * 0.6), (3.0, 2.0, 0.02), "malla")
        k.choques.append(((0, 1.0, z + signo * 0.3), (3.2, 2.0, 0.7), 0.0))

    # Lados: (nombre, a, b, normal hacia adentro). Ojo: a -> b va al reves que en barda()
    # (alla la direccion es (n.z, -n.x)), por eso los murales se piden de b a a; si no, se leen
    # en espejo desde adentro
    lados = [("-z", (hx, -hz), (-hx, -hz), (0.0, 1.0)), ("+z", (-hx, hz), (hx, hz), (0.0, -1.0)),
             ("-x", (-hx, -hz), (-hx, hz), (1.0, 0.0)), ("+x", (hx, hz), (hx, -hz), (-1.0, 0.0))]
    puerta = 1.2
    puerta_en = None
    n_mural = 0
    for nom, (ax, az), (bx, bz), (nx, nz) in lados:
        dx, dz = bx - ax, bz - az
        lado = math.hypot(dx, dz)
        ux, uz = dx / lado, dz / lado
        giro = math.atan2(-uz, ux)
        tramos = [(0.0, lado)]
        if nom == entrada:
            tramos = [(0.0, lado / 2 - puerta / 2), (lado / 2 + puerta / 2, lado)]
            puerta_en = ((ax + bx) / 2, (az + bz) / 2, ux, uz, nx, nz, giro)
        for t0, t1 in tramos:
            mx, mz = ax + ux * (t0 + t1) / 2, az + uz * (t0 + t1) / 2
            tl = t1 - t0
            k.caja((mx, muro / 2, mz), (tl, muro, 0.2), pintura, giro)
            k.caja((mx, muro + 0.04, mz), (tl, 0.08, 0.26), "concreto", giro)
            k.choques.append(((mx, alto / 2, mz), (tl, alto, 0.2), giro))
            # Murales por dentro, en tramos de ~4 m (no todos)
            for i in range(int(tl / 4.0)):
                n_mural += 1
                if (semilla * 31 + n_mural * 17) % 100 >= 60:
                    continue
                s0 = t0 + i * 4.0 + 0.3
                s1 = s0 + 3.4
                diseno = elegir_mural(semilla + n_mural * 13, "propaganda" if (semilla + n_mural) % 3 == 0 else "grafiti")
                a = (ax + ux * s0, az + uz * s0)
                b = (ax + ux * s1, az + uz * s1)
                esquinas, uvs = esquinas_mural(b, a, 0.25, (nx, nz), diseno, 3.4, muro - 0.45, salir=0.13)
                k.cara([(x, z, y) for x, y, z in esquinas], "mural", uvs=uvs)
            # Malla ciclonica encima del muro: tubos, alambres parados cada 0.4 m y postes cada 2.5 m
            for y in (muro + 0.1, (muro + alto) / 2, alto):
                k.caja((mx, y, mz), (tl, 0.06, 0.06), "fierro_verde", giro)
            for i in range(int(tl / 0.4)):
                t = t0 + 0.2 + i * 0.4
                k.caja((ax + ux * t, (muro + alto) / 2, az + uz * t), (0.025, alto - muro, 0.025), "malla", giro)
            n = max(1, round(tl / 2.5))
            for i in range(n + 1):
                t = t0 + tl * i / n
                k.cilindro((ax + ux * t, muro, az + uz * t), 0.05, alto - muro, "fierro_verde", lados=5)
        # Lonas de anuncio amarradas a la malla de los lados largos (el anuncio por dentro, el
        # reverso azul por fuera)
        if nom in ("-x", "+x") and nom != entrada:
            for i, s in enumerate((lado * 0.3, lado * 0.7)):
                diseno = elegir_mural(semilla * 3 + i * 7 + (11 if nom == "+x" else 0), "propaganda")
                a = (ax + ux * (s - 1.8), az + uz * (s - 1.8))
                b = (ax + ux * (s + 1.8), az + uz * (s + 1.8))
                esquinas, uvs = esquinas_mural(b, a, muro + 0.3, (nx, nz), diseno, 3.6, alto - muro - 0.8, salir=0.06)
                frente = [(x, z, y) for x, y, z in esquinas]
                k.cara(frente, "mural", uvs=uvs)
                # El reverso 3 cm mas afuera: el mural no tiene culling y en el mismo plano peleaban
                k.cara([(x - nx * 0.03, y, z - nz * 0.03) for x, y, z in frente][::-1], "lona_azul")

    # Entrada: marco de fierro con dintel (la malla sigue arriba) y la reja abierta hacia adentro
    if puerta_en:
        ex, ez, ux, uz, nx, nz, giro = puerta_en
        for s in (-1, 1):
            k.caja((ex + ux * s * puerta / 2, 1.15, ez + uz * s * puerta / 2), (0.08, 2.3, 0.08), "fierro_verde")
        k.caja((ex, 2.3, ez), (puerta + 0.1, 0.08, 0.08), "fierro_verde", giro)
        for i in range(3):
            t = -puerta / 2 + 0.2 + i * 0.4
            k.caja((ex + ux * t, (2.3 + alto) / 2, ez + uz * t), (0.025, alto - 2.3, 0.025), "malla", giro)
        # La hoja de la reja, abierta 90 grados contra el muro de adentro
        cx, cz = ex + ux * puerta / 2 + nx * puerta / 2, ez + uz * puerta / 2 + nz * puerta / 2
        giro_hoja = math.atan2(-nz, nx)
        for y in (0.1, 1.0, 2.0):
            k.caja((cx, y, cz), (puerta - 0.1, 0.06, 0.06), "fierro_verde", giro_hoja)
        for i in range(4):
            t = -puerta / 2 + 0.2 + i * 0.27
            k.caja((cx + nx * t, 1.05, cz + nz * t), (0.025, 1.9, 0.025), "malla", giro_hoja)
        # Banca de los que esperan turno, por dentro junto a la entrada (afuera llegan las casas)
        bx, bz = ex + nx * 0.45 - ux * 2.6, ez + nz * 0.45 - uz * 2.6
        k.caja((bx, 0.45, bz), (2.4, 0.06, 0.4), "concreto", giro, choca=True)
        for s in (-0.9, 0.9):
            k.caja((bx + ux * s, 0.22, bz + uz * s), (0.12, 0.44, 0.35), "concreto", giro)

    # Escalon de concreto por dentro, en el lado de enfrente de la entrada: ahi se sientan y se
    # paran los que miran (como los ninos de la foto)
    opuesto = {"+x": "-x", "-x": "+x", "+z": "-z", "-z": "+z"}[entrada]
    for nom, (ax, az), (bx, bz), (nx, nz) in lados:
        if nom != opuesto:
            continue
        dx, dz = bx - ax, bz - az
        lado = math.hypot(dx, dz)
        giro = math.atan2(-dz / lado, dx / lado)
        mx, mz = (ax + bx) / 2 + nx * 0.35, (az + bz) / 2 + nz * 0.35
        k.caja((mx, 0.225, mz), (lado - 2.4, 0.45, 0.5), "concreto", giro, choca=True)

    # Dos postes en esquinas opuestas con reflectores viendo a la cancha
    for sx, sz in ((-1, -1), (1, 1)):
        x, z = sx * (hx - 0.25), sz * (hz - 0.25)
        k.cilindro((x, 0, z), 0.12, 7.5, "concreto", lados=6, radio_arriba=0.08)
        k.caja((x - sx * 0.75, 7.35, z - sz * 0.75), (0.4, 0.3, 0.25), "farol")
        k.caja((x - sx * 0.35, 7.5, z - sz * 0.35), (0.08, 0.08, 1.0), "fierro", math.atan2(sz, -sx))
        k.choques.append(((x, 3.75, z), (0.3, 7.5, 0.3), 0.0))
    return k


def _mural_por_archivo(texto, semilla=0):
    """El primer diseño de propaganda cuyo archivo lleva `texto` (o uno cualquiera)."""
    lista = [d for d in lista_murales() if d["tipo"] == "propaganda" and texto in d["archivo"]]
    return lista[semilla % len(lista)] if lista else elegir_mural(semilla, "propaganda")


def espectacular(nombre, p):
    """Espectacular de azotea (se ve de lejos: sirve para orientarse): un poste de fierro, el
    marco con el anuncio por las dos caras (`anuncio`: texto del archivo de propaganda, "gela"
    por omision), pasarela y tres reflectores. Su frente (+Z) es la cara principal."""
    k = Constructor(nombre)
    alto = p.get("alto", 7.0)                        # del piso de la pieza a la orilla de abajo
    ancho, alto_panel = p.get("tam", [7.0, 3.5])
    semilla = sum((i + 1) * ord(c) for i, c in enumerate(nombre))
    k.cilindro((0, 0, 0), 0.3, alto, "fierro", lados=8)
    k.choques.append(((0, alto / 2, 0), (0.6, alto, 0.6), 0.0))
    for x in (-ancho / 4, ancho / 4):                # brazos del poste al marco
        k.caja((x / 2, alto - 0.4, 0), (abs(x) + 0.1, 0.12, 0.12), "fierro")
    k.caja((0, alto + alto_panel / 2, -0.05), (ancho + 0.2, alto_panel + 0.2, 0.2), "fierro")
    for lado, texto in ((1, p.get("anuncio", "gela")), (-1, p.get("anuncio_atras", "gela"))):
        diseno = _mural_por_archivo(texto, semilla + (0 if lado > 0 else 7))
        a, b = ((-ancho / 2, 0.0), (ancho / 2, 0.0)) if lado > 0 else ((ancho / 2, 0.0), (-ancho / 2, 0.0))
        esquinas, uvs = esquinas_mural(a, b, alto + 0.05, (0.0, lado), diseno, ancho - 0.1, alto_panel - 0.1,
                                       salir=0.07 if lado > 0 else 0.17)
        k.cara([(x, z, y) for x, y, z in esquinas], "mural", uvs=uvs)
    # Pasarela y reflectores por el frente
    k.caja((0, alto - 0.05, 0.55), (ancho, 0.06, 0.8), "fierro")
    k.caja((0, alto + 0.9, 0.93), (ancho, 0.04, 0.04), "fierro")
    for x in (-ancho / 3, 0, ancho / 3):
        k.caja((x, alto + 0.45, 0.93), (0.04, 0.9, 0.04), "fierro")
        k.caja((x, alto + 0.3, 1.3), (0.06, 0.06, 0.8), "fierro")
        k.caja((x, alto + 0.3, 1.7), (0.35, 0.25, 0.3), "farol")
    return k


def antena_radio(nombre, p):
    """Torre de antena de fierro de tres patas (la radio pirata de Sofia: se ve de toda la colonia
    aunque el taller no tenga letrero), franjas rojas y blancas, dipolos arriba y vientos a la
    azotea. `alto` desde la base de la pieza."""
    k = Constructor(nombre)
    alto = p.get("alto", 12.0)
    base, punta = 0.7, 0.25
    tramos = max(4, round(alto / 1.5))
    def pata(i, y):
        a = math.tau * i / 3 + math.pi / 2
        r = base + (punta - base) * y / alto
        return (math.cos(a) * r, y, math.sin(a) * r)
    for t in range(tramos):
        y0, y1 = alto * t / tramos, alto * (t + 1) / tramos
        mat = "rojo" if t % 2 == 0 else "blanco_cal"
        for i in range(3):
            a0, a1 = pata(i, y0), pata(i, y1)
            k.caja(((a0[0] + a1[0]) / 2, (y0 + y1) / 2, (a0[2] + a1[2]) / 2), (0.06, y1 - y0, 0.06), mat)
            # Travesano horizontal y diagonal hacia la pata de al lado
            b0, b1 = pata((i + 1) % 3, y1), pata((i + 1) % 3, y0)
            dx, dz = b0[0] - a1[0], b0[2] - a1[2]
            k.caja(((a1[0] + b0[0]) / 2, y1, (a1[2] + b0[2]) / 2), (math.hypot(dx, dz), 0.04, 0.04), mat, math.atan2(-dz, dx))
            dx, dz = b1[0] - a1[0], b1[2] - a1[2]
            largo = math.hypot(math.hypot(dx, dz), y1 - y0)
            for s in (0.25, 0.5, 0.75):                  # diagonal como tres trocitos (las cajas no se inclinan)
                k.caja((a1[0] + dx * s, y1 + (y0 - y1) * s, a1[2] + dz * s), (largo / 3, 0.035, 0.035), mat, math.atan2(-dz, dx))
    k.choques.append(((0, alto / 2, 0), (base * 1.6, alto, base * 1.6), 0.0))
    # Dipolos y un foquito rojo en la punta
    for i, y in enumerate((alto - 1.2, alto - 0.5)):
        k.caja((0, y, 0), (1.6 - i * 0.5, 0.04, 0.04), "fierro", i * 1.2)
    k.cilindro((0, alto, 0), 0.03, 1.4, "fierro", lados=4)
    k.esfera((0, alto + 1.45, 0), 0.1, "rojo", seg=6, anillos=4)
    # Vientos: tres cables de la punta a la azotea
    for i in range(3):
        a = math.tau * i / 3 + math.pi / 6
        ax, az = math.cos(a) * p.get("vientos", 3.0), math.sin(a) * p.get("vientos", 3.0)
        y_top = alto * 0.7
        g = 0.02                                     # un listón de dos caras, como los cables de poste
        q = [(0, y_top - g, 0), (ax, -g, az), (ax, g, az), (0, y_top + g, 0)]
        k.cara(q, "cable")
        k.cara(q[::-1], "cable")
    return k


def _prisma_x(k, x0, x1, y, z, radio, mat, lados=8):
    """Prisma (cilindro de pocos lados) acostado a lo largo de x, con sus tapas: el tanque."""
    # Medio lado girado, para que haya una cara plana viendo a +z (ahi va el anuncio). Cada cara
    # va por los dos lados: asi no importa el sentido de los puntos
    anillo = [(y + math.sin((i + 0.5) * math.tau / lados) * radio, z + math.cos((i + 0.5) * math.tau / lados) * radio) for i in range(lados)]
    for i in range(lados):
        (y0, z0), (y1, z1) = anillo[i], anillo[(i + 1) % lados]
        q = [(x0, y0, z0), (x0, y1, z1), (x1, y1, z1), (x1, y0, z0)]
        k.cara(q, mat)
        k.cara(q[::-1], mat)
    for xx in (x0, x1):
        tapa = [(xx, yy, zz) for yy, zz in anillo]
        k.cara(tapa, mat)
        k.cara(tapa[::-1], mat)


def base_gela(nombre, p):
    """Reten de GelA en un carril de la avenida: caseta blanca y azul, pipa de agua estacionada,
    vallas atravesadas, conos y garrafones apilados. A lo largo de x (14 m) y de ancho un carril
    (z de -3.5 a 3.5); su frente (+Z) da a la banqueta."""
    k = Constructor(nombre)
    semilla = sum((i + 1) * ord(c) for i, c in enumerate(nombre))
    # Caseta
    cx = -3.6
    k.caja((cx, 1.3, 0.6), (3.2, 2.6, 2.4), "blanco_cal", choca=True)
    k.caja((cx, 1.0, 0.6), (3.24, 0.35, 2.44), "azul_gela")
    k.caja((cx, 2.68, 0.6), (3.6, 0.16, 2.8), "azul_gela")
    k.caja((cx, 1.65, 1.81), (1.5, 0.75, 0.04), "vidrio")
    k.caja((cx + 1.61, 1.0, 0.9), (0.04, 2.0, 0.9), "fierro")
    diseno = _mural_por_archivo("gela", semilla)
    esquinas, uvs = esquinas_mural((cx - 1.6, -0.6), (cx - 1.6, 1.8), 0.2, (-1.0, 0.0), diseno, 2.2, 2.2, salir=0.02)
    k.cara([(x, z, y) for x, y, z in esquinas], "mural", uvs=uvs)
    # Pipa: chasis, llantas, cabina azul con parabrisas y el tanque blanco con su anuncio
    px = 2.6
    k.caja((px, 0.75, -0.4), (6.6, 0.35, 2.2), "fierro")
    for x in (px - 2.4, px - 1.3, px + 2.4):
        for z in (-1.45, 0.65):
            k.caja((x, 0.48, z), (0.95, 0.95, 0.35), "hueco")
    k.caja((px + 2.5, 1.95, -0.4), (1.7, 2.1, 2.2), "azul_gela")
    k.caja((px + 3.36, 2.35, -0.4), (0.04, 0.8, 1.9), "vidrio")
    _prisma_x(k, px - 3.2, px + 1.5, 2.0, -0.4, 1.05, "blanco_cal")
    k.caja((px - 0.85, 2.0, -0.4), (0.25, 2.16, 2.16), "azul_gela")
    esquinas, uvs = esquinas_mural((px - 3.0, 0.57), (px + 1.3, 0.57), 1.65, (0.0, 1.0), _mural_por_archivo("gela", semilla + 3), 3.8, 0.72, salir=0.03)
    k.cara([(x, z, y) for x, y, z in esquinas], "mural", uvs=uvs)
    k.choques.append(((px, 1.5, -0.4), (6.8, 3.0, 2.3), 0.0))
    # Vallas atravesadas en las dos puntas del carril (rayas naranja y blanco)
    for x in (-6.8, 7.0):
        for z in (-2.6, 2.6):
            k.caja((x, 0.55, z), (0.08, 1.1, 0.08), "fierro")
        for i in range(6):
            k.caja((x, 0.85, -3.0 + i + 0.5), (0.1, 0.3, 1.0), "naranja_gela" if i % 2 == 0 else "blanco_cal")
        k.choques.append(((x, 0.6, 0.0), (0.2, 1.2, 6.2), 0.0))
    # Conos a lo largo de la orilla de la banqueta y garrafones junto a la caseta
    for i in range(6):
        x = -5.6 + i * 2.2
        k.cono((x, 0.0, 3.1), 0.2, 0.7, "naranja_gela", lados=6)
        k.caja((x, 0.32, 3.1), (0.24, 0.08, 0.24), "blanco_cal")
    for i in range(6):
        gx, gz = cx - 1.3 + (i % 3) * 0.34, 2.3 + (i // 3) * 0.34
        k.cilindro((gx, 0.0, gz), 0.15, 0.48, "lona_azul", lados=6)
    for i in range(2):
        k.cilindro((cx - 1.13 + i * 0.34, 0.5, 2.47), 0.15, 0.48, "lona_azul", lados=6)
    # Asta con bandera de GelA
    k.cilindro((cx + 1.9, 0.0, 2.0), 0.04, 5.0, "fierro", lados=5)
    k.caja((cx + 2.6, 4.6, 2.0), (1.4, 0.8, 0.03), "azul_gela")
    return k


def _toldo(k, ancho, sale, alto, mat):
    """Toldo de lona saliendo de la fachada (z = 0) hacia +Z, con dos postes al frente."""
    k.cara([(-ancho / 2, alto, 0.0), (ancho / 2, alto, 0.0), (ancho / 2, alto - 0.35, sale), (-ancho / 2, alto - 0.35, sale)], mat)
    k.cara([(-ancho / 2, alto - 0.35, sale), (ancho / 2, alto - 0.35, sale), (ancho / 2, alto, 0.0), (-ancho / 2, alto, 0.0)], mat)
    for x in (-ancho / 2 + 0.1, ancho / 2 - 0.1):
        k.caja((x, (alto - 0.35) / 2, sale - 0.05), (0.06, alto - 0.35, 0.06), "fierro")


def tiendita(nombre, p):
    """Tiendita en la cochera de una casa (pegada a su fachada, frente a +Z): toldo rojo, el refri
    rojo de refrescos y el blanco de paletas, rejas de plastico apiladas y un banquito. El letrero
    lo pone Godot con la marca "puerta"."""
    k = Constructor(nombre)
    ancho = p.get("ancho", 3.4)
    _toldo(k, ancho, 1.4, 2.5, "lona_rojo")
    k.caja((-ancho / 2 + 0.55, 0.95, 0.45), (0.8, 1.9, 0.7), "rojo", choca=True)
    k.caja((-ancho / 2 + 0.55, 1.05, 0.81), (0.62, 1.4, 0.02), "vidrio")
    k.caja((-ancho / 2 + 0.55, 1.75, 0.82), (0.66, 0.22, 0.02), "blanco_cal")
    k.caja((ancho / 2 - 0.6, 0.45, 0.45), (0.95, 0.9, 0.6), "blanco_cal", choca=True)
    k.caja((ancho / 2 - 0.6, 0.91, 0.45), (0.9, 0.04, 0.55), "vidrio")
    for i, (x, z) in enumerate(((0.2, 0.5), (0.2, 0.5), (0.2, 0.5), (0.65, 0.4))):
        alto = i * 0.3 if i < 3 else 0.0
        k.caja((x, alto + 0.15, z), (0.42, 0.3, 0.34), "lona_amarillo" if i % 2 == 0 else "lona_azul")
    k.cilindro((0.6, 0.0, 1.0), 0.17, 0.45, "lona_rojo", lados=6)
    return k


def tortilleria(nombre, p):
    """Tortilleria pegada a la fachada (frente a +Z): toldo verde, mostrador de azulejo con la
    bascula y las tortillas envueltas, la maquina de fierro con su banda y su chimenea atras y
    costales de harina. El letrero lo pone Godot con la marca "puerta"."""
    k = Constructor(nombre)
    ancho = p.get("ancho", 4.0)
    _toldo(k, ancho, 1.8, 2.6, "lona_verde")
    k.caja((0.0, 0.5, 1.2), (ancho - 0.8, 1.0, 0.6), "foto_azulejo_amarillo", choca=True)
    k.caja((0.0, 1.02, 1.2), (ancho - 0.7, 0.05, 0.66), "blanco_cal")
    k.caja((0.8, 1.13, 1.2), (0.35, 0.18, 0.3), "fierro")
    for i in range(4):
        k.cilindro((-0.9 + i * 0.32, 1.05, 1.2), 0.13, 0.12 + (i % 2) * 0.06, "veladora", lados=6)
    # La maquina: cuerpo, la banda por donde salen y la chimenea
    k.caja((-0.3, 0.7, 0.45), (2.0, 1.0, 0.6), "fierro", choca=True)
    k.caja((-0.3, 1.23, 0.45), (2.1, 0.05, 0.5), "concreto")
    k.cilindro((-1.1, 1.2, 0.3), 0.08, 1.6, "fierro", lados=5)
    for i in range(3):
        k.caja((ancho / 2 - 0.5, 0.18 + i * 0.3, 0.5), (0.5, 0.28, 0.75), "blanco_cal")
    return k


def tope(nombre, p):
    """Tope de concreto atravesado en la calle (a lo largo de x, `ancho` m), con franjas
    amarillas y negras. Su choque es una rampa (Constructor.rampas): se pasa por encima."""
    k = Constructor(nombre)
    ancho = p.get("ancho", 6.0)
    alto, base, corona = 0.1, 0.35, 0.12
    n = max(2, round(ancho / 0.5))
    for i in range(n):
        x0, x1 = -ancho / 2 + ancho * i / n, -ancho / 2 + ancho * (i + 1) / n
        mat = "lona_amarillo" if i % 2 == 0 else "hueco"
        k.cara([(x0, 0.0, base), (x1, 0.0, base), (x1, alto, corona), (x0, alto, corona)], mat)
        k.cara([(x0, alto, corona), (x1, alto, corona), (x1, alto, -corona), (x0, alto, -corona)], mat)
        k.cara([(x0, alto, -corona), (x1, alto, -corona), (x1, 0.0, -base), (x0, 0.0, -base)], mat)
    h = ancho / 2
    k.rampas.append([(-h, 0.0, base), (h, 0.0, base), (-h, alto, corona), (h, alto, corona),
                     (-h, alto, -corona), (h, alto, -corona), (-h, 0.0, -base), (h, 0.0, -base),
                     (-h, -0.2, 0.0), (h, -0.2, 0.0)])
    return k


def mercado(nombre, p):
    """Mercado techado (el tianguis que se quedo): losa de concreto, postes de fierro y techo de
    lamina a dos aguas a lo largo de x, dos filas de puestos con su mercancia (fruta, chiles,
    costales) y pasillo en medio. `tam` = [largo (x), fondo (z)]; frente a +Z."""
    k = Constructor(nombre)
    largo, fondo = p.get("tam", [30.0, 18.0])
    hx, hz = largo / 2, fondo / 2
    alero, cumbre = 4.0, 5.4
    semilla = sum((i + 1) * ord(c) for i, c in enumerate(nombre))
    k.cara([(-hx, 0.05, hz), (hx, 0.05, hz), (hx, 0.05, -hz), (-hx, 0.05, -hz)], "banqueta")
    n = max(2, round(largo / 5.0))
    for i in range(n + 1):
        x = -hx + largo * i / n
        for z in (-hz + 0.2, hz - 0.2):
            k.caja((x, alero / 2, z), (0.14, alero, 0.14), "fierro", choca=True)
        k.caja((x, cumbre - 0.2, 0.0), (0.12, 0.4, 0.12), "fierro")
        for lado in (-1, 1):                         # tirante del alero a la cumbre
            k.caja((x, (alero + cumbre) / 2, lado * hz / 2), (0.08, 0.08, hz), "fierro")
    for lado in (-1, 1):
        q = [(-hx - 0.4, alero - 0.1, lado * (hz + 0.6)), (hx + 0.4, alero - 0.1, lado * (hz + 0.6)),
             (hx + 0.4, cumbre, 0.0), (-hx - 0.4, cumbre, 0.0)]
        k.cara(q, "foto_lamina_verde")
        k.cara(q[::-1], "foto_lamina_verde")
    # Puestos: dos filas a lo largo de x, de cara al pasillo de en medio
    colores = ["lona_rojo", "lona_azul", "lona_amarillo", "lona_verde", "lona_rosa", "lona_naranja"]
    frutas = ["lona_rojo", "lona_amarillo", "lona_verde", "naranja_gela"]
    por_fila = max(2, int(largo / 5.5))
    for fila, z in ((0, -hz + 3.0), (1, hz - 3.0)):
        mira = 1 if z < 0 else -1                    # hacia el pasillo
        for i in range(por_fila):
            x = -hx + largo * (i + 0.5) / por_fila
            col = colores[(semilla + i + fila * 3) % len(colores)]
            k.caja((x, 0.45, z), (3.4, 0.9, 1.0), col, choca=True)
            k.caja((x, 0.92, z), (3.5, 0.04, 1.1), "foto_madera")
            k.caja((x, 1.0, z - mira * 0.9), (3.4, 2.0, 0.06), "foto_madera")
            tipo = (semilla + i * 7 + fila) % 3
            for j in range(6):
                fx = x - 1.3 + j * 0.52
                if tipo == 0:                        # montones de fruta
                    for m in range(3):
                        k.esfera((fx + (m - 1) * 0.12, 1.02 + (m % 2) * 0.1, z + mira * 0.1), 0.09,
                                 frutas[(i + j + m) % len(frutas)], seg=5, anillos=3)
                elif tipo == 1:                      # cajas de chiles y jitomates
                    k.caja((fx, 1.0, z + mira * 0.1), (0.42, 0.12, 0.34), "foto_madera")
                    k.caja((fx, 1.07, z + mira * 0.1), (0.38, 0.04, 0.3), frutas[(i + j) % 2])
                else:                                # costales de frijol y maiz
                    k.cilindro((fx, 0.94, z + mira * 0.1), 0.18, 0.4, "carton", lados=6)
            # Foco colgado del techo y mecate
            k.caja((x, alero - 0.6, z + mira * 0.3), (0.015, 1.2, 0.015), "cable")
            k.esfera((x, alero - 1.25, z + mira * 0.3), 0.08, "farol", seg=6, anillos=4)
    return k


def bajada(nombre, p):
    """Bajada en zanja a algo hundido (la cancha): escalones de concreto que bajan `fondo` m a lo
    largo de +x en `largo` m, muros de contencion a los lados y barandal arriba. `ancho` en z.
    Su choque es una rampa (el CharacterBody3D no sube escalones). Va dentro de un `hundidos`."""
    k = Constructor(nombre)
    largo, ancho, hondo = p.get("largo", 4.0), p.get("ancho", 1.4), p.get("fondo", 1.2)
    w = ancho / 2
    escalones = max(3, round(hondo / 0.18))
    paso = largo / escalones
    for i in range(escalones):
        y = -hondo * (i + 1) / escalones
        k.caja(((i + 0.5) * paso, (y - hondo - 0.02) / 2 + 0.0, 0.0), (paso, abs(y + hondo) + 0.04 if y > -hondo else 0.04, ancho), "concreto")
    for lado in (-1, 1):
        k.caja((largo / 2, -hondo / 2, lado * (w + 0.1)), (largo, hondo, 0.2), "concreto", choca=True)
        k.caja((largo / 2, 0.9, lado * (w + 0.1)), (largo, 0.05, 0.05), "fierro")
        for i in range(int(largo / 1.0) + 1):
            k.caja((min(i * 1.0, largo), 0.45, lado * (w + 0.1)), (0.04, 0.9, 0.04), "fierro")
    k.rampas.append([(-0.2, 0.0, -w), (-0.2, 0.0, w), (largo + 0.2, -hondo, -w), (largo + 0.2, -hondo, w),
                     (largo + 0.2, -hondo - 0.3, -w), (largo + 0.2, -hondo - 0.3, w), (-0.2, -0.3, -w), (-0.2, -0.3, w)])
    return k


def basamento(nombre, p):
    """Basamento de cantera bajo un edificio (el palacio): una losa de `alto` m del tamaño `tam`
    [ancho (x), fondo (z)] con escalones a todo lo ancho del frente (+Z). Se camina encima;
    los escalones chocan como rampa."""
    k = Constructor(nombre)
    ancho, fondo = p.get("tam", [50.0, 18.0])
    alto = p.get("alto", 0.45)
    hx, hz = ancho / 2, fondo / 2
    k.caja((0, alto / 2, 0), (ancho, alto, fondo), "foto_cantera_rosa", choca=True)
    escalones = max(2, round(alto / 0.15))
    huella = 0.32
    for i in range(1, escalones):
        y = alto * (escalones - i) / escalones
        k.caja((0, y / 2, hz + (i - 0.5) * huella), (ancho, y, huella), "foto_cantera_rosa")
    largo = (escalones - 1) * huella
    k.rampas.append([(-hx, alto, hz), (hx, alto, hz), (-hx, 0.0, hz + largo + 0.1), (hx, 0.0, hz + largo + 0.1),
                     (-hx, -0.2, hz), (hx, -0.2, hz)])
    return k


def puente(nombre, p):
    """Puente peatonal de fierro sobre la avenida: el piso a `alto` m, a lo largo de z (`largo`
    m, de banqueta a banqueta), barandales, columnas en las puntas y en medio, y mantas de GelA
    colgadas a los dos lados. Las escaleras son piezas `escalera` aparte, en cada banqueta."""
    k = Constructor(nombre)
    largo, alto, ancho = p.get("largo", 18.0), p.get("alto", 5.0), p.get("ancho", 1.6)
    w = ancho / 2
    semilla = sum((i + 1) * ord(c) for i, c in enumerate(nombre))
    k.caja((0, alto - 0.1, largo / 2), (ancho, 0.2, largo), "fierro", choca=True)
    k.caja((0, alto - 0.35, largo / 2), (ancho - 0.3, 0.3, largo), "fierro_verde")
    # Las escaleras llegan por un lado en cada punta (oeste al empezar, este al acabar, como las
    # pone el .json): ahi el barandal se abre ABRE m
    abre = p.get("abre", 1.5)
    for lado in (-1, 1):
        z0, z1 = (abre, largo) if lado < 0 else (0.0, largo - abre)
        k.caja((lado * w, alto + 1.0, (z0 + z1) / 2), (0.06, 0.06, z1 - z0), "fierro_verde")
        for i in range(int((z1 - z0) / 0.6) + 1):
            k.caja((lado * w, alto + 0.5, min(z0 + i * 0.6, z1)), (0.03, 1.0, 0.03), "fierro_verde")
        k.choques.append(((lado * w, alto + 0.5, (z0 + z1) / 2), (0.1, 1.0, z1 - z0), 0.0))
        # Manta de GelA por fuera del barandal
        diseno = _mural_por_archivo("gela", semilla + (0 if lado > 0 else 5))
        # Como en barda(): con la normal n, de a a b se va hacia (n.z, -n.x)
        a, b = ((0.0, largo * 0.7), (0.0, largo * 0.3)) if lado > 0 else ((0.0, largo * 0.3), (0.0, largo * 0.7))
        a, b = (lado * (w + 0.05), a[1]), (lado * (w + 0.05), b[1])
        esquinas, uvs = esquinas_mural(a, b, alto - 0.5, (lado, 0.0), diseno, largo * 0.4, 1.4, salir=0.02)
        k.cara([(xx, zz, yy) for xx, yy, zz in esquinas], "mural", uvs=uvs)
    # Columnas lejos de las puntas: ahi llegan las escaleras, y una columna bajo su ultimo escalon
    # atoraba al que subia
    for z in (abre + 0.6, largo / 2, largo - abre - 0.6):
        for lado in (-1, 1):
            k.caja((lado * (w - 0.1), (alto - 0.4) / 2, z), (0.2, alto - 0.4, 0.2), "fierro", choca=True)
    return k


def plinto(nombre, p):
    """Plataforma octagonal de cantera (bajo el kiosco): `radio` arriba, `alto` m, con escalones
    alrededor hasta el piso. Su choque son ocho cuñas en rampa, del centro a cada lado."""
    k = Constructor(nombre)
    r, alto = p.get("radio", 5.6), p.get("alto", 0.45)
    lados = 8
    escalones = max(2, round(alto / 0.15))
    huella = 0.3
    giro0 = math.tau / 16
    def anillo(radio, y):
        return [(math.cos(i * math.tau / lados + giro0) * radio, y, math.sin(i * math.tau / lados + giro0) * radio) for i in range(lados)]
    for e in range(escalones):
        y = alto * (escalones - e) / escalones
        rad = r + e * huella
        arriba = anillo(rad, y)
        k.cara(arriba[::-1], "foto_cantera_rosa")
        abajo = anillo(rad, 0.0)
        for i in range(lados):
            j = (i + 1) % lados
            k.cara([abajo[j], abajo[i], arriba[i], arriba[j]], "foto_cantera_rosa")
    fuera = r + escalones * huella
    for i in range(lados):
        a0, a1 = i * math.tau / lados + giro0, (i + 1) * math.tau / lados + giro0
        k.rampas.append([(0.0, alto, 0.0), (0.0, -0.2, 0.0),
                         (math.cos(a0) * r, alto, math.sin(a0) * r), (math.cos(a1) * r, alto, math.sin(a1) * r),
                         (math.cos(a0) * fuera, 0.0, math.sin(a0) * fuera), (math.cos(a1) * fuera, 0.0, math.sin(a1) * fuera),
                         (math.cos(a0) * fuera, -0.2, math.sin(a0) * fuera), (math.cos(a1) * fuera, -0.2, math.sin(a1) * fuera)])
    return k


def barda(nombre, p):
    """Barda de block (o de lamina) a lo largo de x, con murales pintados en sus dos caras:
    grafitis y propaganda (catalogos de textures/map/, kit.murales)."""
    k = Constructor(nombre)
    largo, alto, grueso = p.get("largo", 10.0), p.get("alto", 2.6), p.get("grueso", 0.25)
    mat = p.get("material", "foto_block")
    color = tuple(p.get("color", (1.0, 1.0, 1.0)))
    k.caja((0, alto / 2, 0), (largo, alto, grueso), mat, color=color, choca=True)
    # Castillos cada 3 m (las bardas de block los llevan)
    if mat == "foto_block":
        for i in range(int(largo / 3.0) + 1):
            k.caja((-largo / 2 + min(i * 3.0, largo), alto / 2, 0), (0.3, alto + 0.1, grueso + 0.06), "concreto")
    semilla = sum((i + 1) * ord(c) for i, c in enumerate(nombre))
    tramo = 4.5
    n = 0
    for lado in (1, -1):
        for i in range(int(largo / tramo)):
            n += 1
            if (semilla * 31 + n * 17) % 100 >= p.get("murales", 55):
                continue
            x0 = -largo / 2 + i * tramo + 0.3
            x1 = x0 + tramo - 0.6
            diseno = elegir_mural(semilla + n * 13, "propaganda" if (semilla + n) % 3 == 0 else "grafiti")
            base = 0.9 if diseno["tipo"] == "propaganda" else 0.2
            # En coordenadas de Godot: el muro va en x, la cara en z = lado * grueso / 2
            a, b = ((x0, 0.0), (x1, 0.0)) if lado > 0 else ((x1, 0.0), (x0, 0.0))
            esquinas, uvs = esquinas_mural(a, b, base, (0.0, lado), diseno, 3.2, alto - base - 0.15, salir=grueso / 2 + 0.03)
            k.cara([(x, z, y) for x, y, z in esquinas], "mural", uvs=uvs)
    return k


def _carro(k, x, z, giro, color, quemado=False, ladrillos=False):
    """Un vochito de cajas: carroceria, cabina, vidrios y llantas (sin llantas si esta quemado;
    sobre bloques si esta en ladrillos, un poco mas abajo)."""
    c, s_ = math.cos(giro), math.sin(giro)
    def p(lx, y, lz):
        return (x + lx * c + lz * s_, y, z - lx * s_ + lz * c)
    cuerpo = "hueco" if quemado else color
    baja = -0.1 if ladrillos else 0.0
    k.caja(p(0, 0.65 + baja, 0), (1.6, 0.7, 3.8), cuerpo, giro)
    k.caja(p(0, 1.25 + baja, -0.2), (1.4, 0.55, 1.9), cuerpo, giro)
    k.caja(p(0, 1.25 + baja, 0.78), (1.3, 0.45, 0.05), "hueco" if quemado else "vidrio", giro)
    _ruedas(k, p, (-0.8, 0.8), (-1.2, 1.2), quemado, ladrillos)
    k.choques.append((p(0, 0.75, 0), (1.6, 1.5, 3.8), giro))


def _llantas(k, x, z, n):
    for i in range(n):
        k.cilindro((x, i * 0.25, z), 0.35, 0.24, "fierro", lados=8)


def lote(nombre, p):
    """Un baldio con vida (frente a +Z, tam = [frente, fondo]): "taller" mecanico al aire libre,
    "juegos" oxidados, "fonda" de lona con sillas de plastico, "basquet" (media canchita con aro
    sin red) o "baldio" con su basura."""
    k = Constructor(nombre)
    ancho, fondo = p.get("tam", [8.0, 12.0])
    hx, hz = ancho / 2, fondo / 2
    variante = p.get("variante", "baldio")
    semilla = sum((i + 1) * ord(c) for i, c in enumerate(nombre))
    k.cara([(-hx, 0.03, hz), (hx, 0.03, hz), (hx, 0.03, -hz), (-hx, 0.03, -hz)], "tierra")
    colores = ["rojo", "azul_gela", "naranja_gela", "blanco_cal", "pasto_muerto"]
    if variante == "taller":
        # Tejaban de lamina al fondo, dos carros y llantas apiladas, tambos de aceite
        for x in (-hx + 0.3, hx - 0.3):
            for z in (-hz + 0.3, -hz + 4.0):
                k.caja((x, 1.4, z), (0.12, 2.8, 0.12), "fierro")
        k.caja((0, 2.9, -hz + 2.15), (ancho, 0.08, 4.4), "foto_lamina_verde")
        k.caja((-hx + 1.0, 0.5, -hz + 2.0), (1.2, 1.0, 0.6), "foto_madera", choca=True)
        _carro(k, -hx / 2, 0.5, 0.15, colores[semilla % 5])
        _carro(k, hx / 2, -hz + 2.2, 1.57, colores[(semilla + 2) % 5])
        _llantas(k, hx - 0.8, hz - 1.2, 4)
        _llantas(k, hx - 1.6, hz - 1.0, 3)
        for i in range(2):
            k.cilindro((-hx + 0.8 + i * 0.7, 0, hz - 1.0), 0.3, 0.9, "azul_gela", lados=8, choca=True)
    elif variante == "juegos":
        # Columpios (marco con dos asientos), resbaladilla y sube y baja, todo oxidado
        for sx in (-1.6, 1.6):
            for dz in (-0.35, 0.35):
                k.caja((sx, 1.2, -hz / 2 + dz), (0.08, 2.5, 0.08), "fierro_verde")
        k.caja((0, 2.4, -hz / 2), (3.4, 0.08, 0.08), "fierro_verde")
        for x in (-0.6, 0.6):
            k.caja((x, 1.5, -hz / 2), (0.03, 1.8, 0.03), "fierro")
            k.caja((x, 0.55, -hz / 2), (0.5, 0.05, 0.25), "rojo")
        k.choques.append(((0, 1.2, -hz / 2), (3.4, 2.4, 0.6), 0.0))
        k.caja((hx - 1.2, 1.0, 1.0), (0.6, 2.0, 0.6), "fierro_verde", choca=True)
        k.cara([(hx - 1.5, 2.0, 1.3), (hx - 0.9, 2.0, 1.3), (hx - 0.9, 0.2, 4.0), (hx - 1.5, 0.2, 4.0)], "naranja_gela")
        k.cara([(hx - 0.9, 2.0, 1.3), (hx - 1.5, 2.0, 1.3), (hx - 1.5, 0.2, 4.0), (hx - 0.9, 0.2, 4.0)], "naranja_gela")
        k.caja((-hx + 1.5, 0.35, hz - 2.5), (0.25, 0.7, 0.25), "fierro_verde")
        k.caja((-hx + 1.5, 0.6, hz - 2.5), (0.3, 0.06, 3.2), "azul_gela")
    elif variante == "basquet":
        # Media canchita de basquet: losa de concreto, poste al fondo con tablero y aro sin red,
        # rayas gastadas y un balon olvidado
        k.cara([(-hx + 0.3, 0.05, hz - 0.3), (hx - 0.3, 0.05, hz - 0.3), (hx - 0.3, 0.05, -hz + 0.3), (-hx + 0.3, 0.05, -hz + 0.3)], "banqueta")
        zp = -hz + 0.7
        k.cilindro((0, 0, zp), 0.08, 3.4, "fierro_verde", lados=6)
        k.choques.append(((0, 1.7, zp), (0.2, 3.4, 0.2), 0.0))
        k.caja((0, 3.3, zp + 0.25), (0.08, 0.08, 0.5), "fierro_verde")
        k.caja((0, 3.35, zp + 0.5), (1.4, 0.95, 0.05), "blanco_cal")
        k.caja((0, 3.25, zp + 0.53), (0.5, 0.4, 0.02), "rojo")
        for i in range(10):
            a0 = i * math.tau / 10
            k.caja((math.cos(a0) * 0.23, 3.05, zp + 0.78 + math.sin(a0) * 0.23), (0.15, 0.03, 0.03), "naranja_gela", -a0 + math.pi / 2)
        def raya(x0, z0, x1, z1):
            dx, dz = x1 - x0, z1 - z0
            ll = math.hypot(dx, dz) or 1.0
            nx, nz = -dz / ll * 0.05, dx / ll * 0.05
            k.cara([(x0 - nx, 0.06, z0 - nz), (x1 - nx, 0.06, z1 - nz), (x1 + nx, 0.06, z1 + nz), (x0 + nx, 0.06, z0 + nz)], "blanco_cal")
        r3 = min(hx - 0.6, 3.5)
        arco = [(math.cos(math.pi * i / 12) * r3, zp + 0.8 + math.sin(math.pi * i / 12) * r3) for i in range(13)]
        for p0, p1 in zip(arco, arco[1:]):
            raya(p0[0], p0[1], p1[0], p1[1])
        raya(-1.0, -hz + 0.3, -1.0, zp + 3.0)
        raya(1.0, -hz + 0.3, 1.0, zp + 3.0)
        raya(-1.0, zp + 3.0, 1.0, zp + 3.0)
        k.esfera((hx - 1.0, 0.12, hz - 1.5), 0.12, "naranja_gela", seg=6, anillos=4)
    elif variante == "fonda":
        # Lona amarilla sobre tres mesas con sillas de plastico rojas y el carrito de tacos al frente
        for x in (-hx + 0.4, hx - 0.4):
            for z in (-hz + 1.0, hz - 1.5):
                k.caja((x, 1.3, z), (0.08, 2.6, 0.08), "fierro")
        k.caja((0, 2.6, -0.25), (ancho - 0.6, 0.05, fondo - 2.5), "lona_amarillo")
        for z in (-hz + 2.5, 0.0, hz - 3.0):
            k.caja((0, 0.72, z), (1.2, 0.05, 0.8), "blanco_cal", choca=True)
            k.caja((0, 0.36, z), (0.08, 0.7, 0.08), "blanco_cal")
            for dx in (-0.85, 0.85):
                k.caja((dx, 0.22, z), (0.42, 0.44, 0.42), "rojo")
                k.caja((dx * 1.25, 0.65, z), (0.06, 0.45, 0.42), "rojo")
        k.caja((hx - 1.2, 0.6, hz - 0.8), (1.6, 1.2, 0.8), "blanco_cal", choca=True)
        k.caja((hx - 1.2, 1.9, hz - 0.8), (1.8, 0.05, 1.0), "lona_rojo")
        k.cilindro((hx - 1.2, 1.2, hz - 0.8), 0.35, 0.05, "fierro", lados=8)
    else:
        # Basura: bolsas negras, llantas viejas, un colchon y escombro
        for i in range(5):
            x = -hx + 1.0 + (semilla * (i + 3) % int(max(ancho - 2, 1) * 10)) / 10
            z = -hz + 1.0 + (semilla * (i + 7) % int(max(fondo - 2, 1) * 10)) / 10
            k.esfera((x, 0.25, z), 0.35, "hueco", seg=6, anillos=4, aplastar=0.7)
        _llantas(k, hx - 1.0, -hz + 1.5, 2)
        k.caja((-hx + 2.0, 0.12, -hz + 2.5), (1.4, 0.24, 1.9), "blanco_cal", 0.3)
        k.caja((0.5, 0.3, -hz + 1.2), (2.0, 0.6, 1.2), "foto_block", 0.6)
    return k


def carro(nombre, p):
    """Carro suelto (o quemado: los tapones de las calles, docs/mapa/colonias/santa_mugre.md).
    `estado`: "normal", "ladrillos" (sin llantas, sobre bloques) o "quemado"; `modelo`: "vocho"
    o "combi". Su largo va a lo largo de z."""
    k = Constructor(nombre)
    estado = p.get("estado", "quemado" if p.get("quemado", False) else "normal")
    if p.get("modelo") == "combi":
        _combi(k, p.get("color", "blanco_cal"), estado)
    else:
        _carro(k, 0, 0, 0.0, p.get("color", "rojo"), estado == "quemado", estado == "ladrillos")
    return k


def _combi(k, color, estado):
    """La combi de pasaje: una caja alta con su franja de ventanas, parabrisas y llantas (o
    bloques, o quemada)."""
    quemada = estado == "quemado"
    sube = 0.15 if estado == "ladrillos" else 0.0
    cuerpo = "hueco" if quemada else color
    k.caja((0, 1.15 + sube, 0), (1.8, 1.7, 4.4), cuerpo)
    vidrio = "hueco" if quemada else "vidrio"
    for lado in (-1, 1):
        k.caja((lado * 0.91, 1.5 + sube, -0.3), (0.02, 0.5, 3.0), vidrio)
    k.caja((0, 1.45 + sube, 2.21), (1.6, 0.6, 0.02), vidrio)
    if not quemada:
        k.caja((0, 0.6 + sube, 2.21), (1.7, 0.12, 0.03), "blanco_cal")
    _ruedas(k, lambda lx, y, lz: (lx, y, lz), (-0.85, 0.85), (-1.5, 1.5), quemada, estado == "ladrillos")
    k.choques.append(((0, 1.0, 0), (1.8, 2.0, 4.4), 0.0))


def _ruedas(k, p, xs, zs, quemado, ladrillos):
    """Llantas, o nada si esta quemado, o dos bloques apilados donde iban si esta en ladrillos."""
    for lx in xs:
        for lz in zs:
            if ladrillos:
                k.caja(p(lx * 0.8, 0.16, lz), (0.4, 0.32, 0.2), "foto_block")
            elif not quemado:
                k.cilindro(p(lx, 0.0, lz), 0.32, 0.3, "fierro", lados=6)


def patio(nombre, p):
    """Patio de atras a media cuadra (donde se ensancha un callejon): piso de cemento, lavadero,
    tendederos con ropa colgada, un tinaco en su base, cubetas y una silla."""
    k = Constructor(nombre)
    ancho, fondo = p.get("tam", [7.0, 7.0])
    hx, hz = ancho / 2, fondo / 2
    k.cara([(-hx, 0.04, hz), (hx, 0.04, hz), (hx, 0.04, -hz), (-hx, 0.04, -hz)], "concreto")
    # Lavadero de cemento con su pileta
    k.caja((-hx + 0.8, 0.45, -hz + 0.6), (1.4, 0.9, 0.8), "concreto", choca=True)
    k.caja((-hx + 0.8, 0.93, -hz + 0.6), (1.2, 0.06, 0.6), "azul_gela")
    # Tinaco en su base de block
    k.caja((hx - 1.0, 0.6, -hz + 1.0), (1.4, 1.2, 1.4), "foto_block", choca=True)
    k.cilindro((hx - 1.0, 1.2, -hz + 1.0), 0.6, 1.2, "tinaco", lados=10)
    # Tendederos: dos postes, dos lazos y ropa de colores
    ropa = ["rojo", "azul_gela", "blanco_cal", "lona_amarillo", "lona_rosa", "lona_verde"]
    for x in (-hx + 0.4, hx - 0.4):
        k.caja((x, 1.2, 0.5), (0.08, 2.4, 0.08), "fierro")
    for j, z in enumerate((0.2, 0.8)):
        k.caja((0, 2.2, z), (ancho - 0.8, 0.02, 0.02), "cable")
        for i in range(5):
            x = -hx + 1.0 + i * (ancho - 2.0) / 4
            k.caja((x, 1.85, z), (0.55, 0.7, 0.02), ropa[(i + j * 2 + len(nombre)) % len(ropa)])
    # Cubetas y una silla de plastico
    k.cilindro((0.5, 0.0, -hz + 0.6), 0.18, 0.35, "lona_rojo", lados=6)
    k.cilindro((1.0, 0.0, -hz + 0.5), 0.18, 0.35, "azul_gela", lados=6)
    k.caja((hx - 1.2, 0.22, hz - 1.0), (0.42, 0.44, 0.42), "rojo")
    return k


def escalera(nombre, p):
    """Escalera de fierro pegada a la fachada, de la banqueta a la azotea: sube a lo largo de x
    (hacia +x, o -x con "sentido": -1), de ancho en z (de z = 0 hacia +z, la calle). Su choque es
    una rampa (Constructor.rampas): el CharacterBody3D no sube escalones."""
    k = Constructor(nombre)
    alto = p.get("alto", 5.55)
    ancho = p.get("ancho", 1.0)
    sentido = p.get("sentido", 1)
    escalones = max(4, round(alto / 0.26))      # unos 40 grados: a 43 apenas se subia (el piso llega a 45)
    paso = 0.3
    largo = escalones * paso
    subida = alto / escalones
    for i in range(escalones):
        x = sentido * (i + 0.5) * paso
        k.caja((x, (i + 1) * subida - 0.03, ancho / 2), (paso, 0.06, ancho), "fierro")
    # Zancas y barandal (por el lado de la calle), como planos inclinados
    for z in (0.02, ancho - 0.02):
        x1 = sentido * largo
        k.cara([(0, 0, z), (x1, alto, z), (x1, alto - 0.25, z), (0, -0.25, z)][::sentido], "fierro")
        k.cara([(0, -0.25, z), (x1, alto - 0.25, z), (x1, alto, z), (0, 0, z)][::sentido], "fierro")
    for i in range(0, escalones + 1, 3):
        x = sentido * i * paso
        k.caja((x, i * subida + 0.5, ancho - 0.03), (0.05, 1.0, 0.05), "fierro")
    x1 = sentido * largo
    k.cara([(0, 1.0, ancho - 0.03), (x1, alto + 1.0, ancho - 0.03), (x1, alto + 0.95, ancho - 0.03), (0, 0.95, ancho - 0.03)][::sentido], "fierro")
    k.cara([(0, 0.95, ancho - 0.03), (x1, alto + 0.95, ancho - 0.03), (x1, alto + 1.0, ancho - 0.03), (0, 1.0, ancho - 0.03)][::sentido], "fierro")
    # Rampa de choque: de la banqueta (un poco antes del primer escalon) a la orilla de la azotea
    x0, x1 = -sentido * 0.3, sentido * (largo + 0.2)
    k.rampas.append([(x0, 0.0, 0.0), (x0, 0.0, ancho), (x1, alto, 0.0), (x1, alto, ancho),
                     (x1, alto - 0.3, 0.0), (x1, alto - 0.3, ancho), (x0, -0.3, 0.0), (x0, -0.3, ancho)])
    return k


def tablon(nombre, p):
    """Tablon de una azotea a otra por encima de un callejon (a lo largo de x), con su choque."""
    k = Constructor(nombre)
    largo, ancho = p.get("largo", 4.0), p.get("ancho", 0.6)
    k.caja((0, -0.03, 0), (largo, 0.06, ancho), "foto_madera", choca=True)
    for z in (-ancho / 3, ancho / 3):
        k.caja((0, -0.08, z), (largo, 0.05, 0.08), "foto_madera")
    return k


def vecindad(nombre, p):
    """La vecindad del jugador (docs/mapa/colonias/santa_mugre.md): dos tiras de cuartos de dos
    pisos a lo largo de z con un patio largo en medio; cada cuarto con su color, su puerta y su
    ventana al patio; corredor de arriba con barandal de fierro y una escalera; lavaderos,
    tendederos, macetas y sillas en el patio; zaguan con arco al frente (+Z, la privada) y barda
    al fondo; tinacos en las azoteas."""
    k = Constructor(nombre)
    ancho, fondo = p.get("tam", [52.0, 35.0])        # x (largo de las tiras), z (de la privada al fondo)
    hx, hz = ancho / 2, fondo / 2
    tira = p.get("tira", 7.0)                         # fondo de los cuartos
    alto = 2 * PISO
    patio_x = hx - tira                               # el patio va de -patio_x a patio_x
    colores = [PALETA[n] for n in ("terracota", "rosa", "mostaza", "turquesa", "crema", "lima", "azul", "naranja")]
    k.cara([(-patio_x, 0.04, hz), (patio_x, 0.04, hz), (patio_x, 0.04, -hz), (-patio_x, 0.04, -hz)], "concreto")
    cuarto = 3.5
    n = int(fondo // cuarto)
    paso = fondo / n
    for lado in (-1, 1):
        xc = lado * (hx - tira / 2)
        k.caja((xc, alto / 2, 0), (tira, alto, fondo), "foto_aplanado_blanco", choca=True)
        k.cara([(xc - tira / 2, alto + 0.01, fondo / 2), (xc + tira / 2, alto + 0.01, fondo / 2),
                (xc + tira / 2, alto + 0.01, -fondo / 2), (xc - tira / 2, alto + 0.01, -fondo / 2)], "azotea")
        cara_x = lado * patio_x                        # la fachada al patio
        for piso in range(2):
            y0, y1 = piso * PISO, (piso + 1) * PISO
            for i in range(n):
                z0, z1 = -hz + i * paso, -hz + (i + 1) * paso
                color = colores[(i * 3 + piso * 5 + (lado > 0) * 2) % len(colores)]
                celda = PUERTA if (i + piso) % 2 == 0 else (VENTANA_ABAJO if piso == 0 else VENTANA_ARRIBA[i % 4])
                # Puntos en el plano x = cara_x, viendo al patio (hacia -lado en x)
                if lado < 0:
                    esquinas = [(cara_x + 0.02, y0, z1), (cara_x + 0.02, y0, z0), (cara_x + 0.02, y1, z0), (cara_x + 0.02, y1, z1)]
                else:
                    esquinas = [(cara_x - 0.02, y0, z0), (cara_x - 0.02, y0, z1), (cara_x - 0.02, y1, z1), (cara_x - 0.02, y1, z0)]
                k.mosaico(esquinas, celda, color)
        # Corredor del segundo piso: losa volada de 1.4 m, barandal y su choque
        cx = cara_x - lado * 0.7
        k.caja((cx, PISO - 0.1, 0), (1.4, 0.2, fondo), "concreto")
        k.choques.append(((cx, PISO - 0.1, 0), (1.4, 0.2, fondo), 0.0))
        bx = cara_x - lado * 1.35
        k.caja((bx, PISO + 0.95, 0), (0.05, 0.05, fondo), "fierro")
        for i in range(int(fondo / 0.5)):
            k.caja((bx, PISO + 0.5, -hz + 0.25 + i * 0.5), (0.03, 0.9, 0.03), "fierro")
        k.choques.append(((bx, PISO + 0.5, 0), (0.1, 1.0, fondo), 0.0))
        # Tinacos en la azotea
        for i in range(4):
            k.cilindro((xc + (i % 2 - 0.5) * 2.0, alto + 0.05, -hz + 4 + i * (fondo - 8) / 3), 0.6, 1.1, "tinaco", lados=10)
    # Escalera de fierro del patio al corredor del lado -x, junto al zaguan (sube hacia -z)
    escalones = 11
    for i in range(escalones):
        z = hz - 2.0 - (i + 0.5) * 0.3
        k.caja((-patio_x + 1.9, (i + 1) * PISO / escalones - 0.03, z), (1.0, 0.06, 0.3), "fierro")
    zf, zi = hz - 2.0 + 0.3, hz - 2.0 - escalones * 0.3 - 0.2
    k.rampas.append([(-patio_x + 1.4, 0.0, zf), (-patio_x + 2.4, 0.0, zf), (-patio_x + 1.4, PISO, zi), (-patio_x + 2.4, PISO, zi),
                     (-patio_x + 1.4, PISO - 0.3, zi), (-patio_x + 2.4, PISO - 0.3, zi), (-patio_x + 1.4, -0.3, zf), (-patio_x + 2.4, -0.3, zf)])
    # Barda del fondo y el frente con el zaguan (4 m, con arco)
    k.caja((0, 1.5, -hz + 0.15), (2 * patio_x, 3.0, 0.3), "foto_aplanado_blanco", choca=True)
    zaguan = 4.0
    for signo in (-1, 1):
        largo = patio_x - zaguan / 2
        k.caja((signo * (zaguan / 2 + largo / 2), 1.6, hz - 0.15), (largo, 3.2, 0.3), "foto_aplanado_blanco", choca=True)
    k.arco((0, 0, hz - 0.15), zaguan, 4.0, 0.4, "foto_cantera_rosa")
    k.caja((0, 4.3, hz - 0.15), (zaguan + 1.0, 0.6, 0.4), "foto_aplanado_blanco")
    # Lavaderos en fila, tendederos de lado a lado, macetas y sillas
    for i in range(4):
        z = -hz + 3.0 + i * 3.0
        k.caja((patio_x - 2.0, 0.45, z), (0.8, 0.9, 1.4), "concreto", choca=True)
        k.caja((patio_x - 2.0, 0.93, z), (0.6, 0.06, 1.2), "azul_gela")
    ropa = ["rojo", "azul_gela", "blanco_cal", "lona_amarillo", "lona_rosa", "lona_verde", "lona_naranja"]
    for j in range(5):
        z = -hz + 5.0 + j * (fondo - 10) / 4
        k.caja((0, 2.3 + (j % 2) * 0.3, z), (2 * patio_x - 0.4, 0.02, 0.02), "cable")
        for i in range(int(patio_x)):
            if (i + j) % 3 == 0:
                continue
            k.caja((-patio_x + 1.0 + i * 2.0, 1.95 + (j % 2) * 0.3, z), (0.6, 0.7, 0.02), ropa[(i + j) % len(ropa)])
    for i in range(10):
        lado = 1 if i % 2 else -1
        z = -hz + 1.5 + i * (fondo - 3) / 9
        k.cilindro((lado * (patio_x - 0.4), 0.0, z), 0.25, 0.35, "foto_cantera_rosa", lados=6)
        k.esfera((lado * (patio_x - 0.4), 0.55, z), 0.3, "hojas", seg=6, anillos=4)
    for z in (-3.0, 2.5):
        k.caja((-patio_x + 1.2, 0.22, z), (0.42, 0.44, 0.42), "rojo")
    return k


def valla_gela(nombre, p):
    """Valla de obra de GelA atravesada en la calle (a lo largo de x, de frente a +Z): paneles
    naranjas con franja blanca, la manta azul "Trabajamos para llevarte agua" (un cartel de
    textures/map/propaganda) y tubos de concreto apilados atras."""
    k = Constructor(nombre)
    largo = p.get("largo", 10.0)
    alto = 2.2
    n = max(1, round(largo / 2.5))
    paso = largo / n
    for i in range(n):
        x = -largo / 2 + paso * (i + 0.5)
        k.caja((x, alto / 2 + 0.1, 0), (paso - 0.08, alto, 0.06), "naranja_gela")
        k.caja((x, alto * 0.55, 0.04), (paso - 0.1, 0.25, 0.02), "blanco_cal")
        for lado in (-1, 1):
            k.caja((x + lado * (paso / 2 - 0.1), 0.06, 0), (0.12, 0.12, 0.8), "concreto")
    k.choques.append(((0, alto / 2, 0), (largo, alto + 0.2, 0.4), 0.0))
    # La manta azul con un cartel de GelA encima
    k.caja((0, alto * 0.6, 0.06), (min(largo * 0.6, 5.0), 1.1, 0.02), "azul_gela")
    diseno = next((d for d in lista_murales() if d["archivo"].startswith("propaganda_gela")), None)
    if diseno:
        esquinas, uvs = esquinas_mural((-1.6, 0.0), (1.6, 0.0), alto * 0.6 - 0.45, (0.0, 1.0), diseno, 3.0, 1.0, salir=0.08)
        k.cara([(x, z, y) for x, y, z in esquinas], "mural", uvs=uvs)
    # Tubos de concreto (del drenaje que nunca se acabo) apilados atras
    for i, (x, y) in enumerate(((-2.0, 0.0), (0.0, 0.0), (2.0, 0.0), (-1.0, 1.15), (1.0, 1.15))):
        if abs(x) + 1.0 > largo / 2:
            continue
        cx, cz = x, -1.6
        lados = 10
        r = 0.6
        anillo = [(cx - 0.9, y + r + math.sin(j * math.tau / lados) * r, cz + math.cos(j * math.tau / lados) * r) for j in range(lados)]
        for j in range(lados):
            a, b = anillo[j], anillo[(j + 1) % lados]
            k.cara([a, b, (b[0] + 1.8, b[1], b[2]), (a[0] + 1.8, a[1], a[2])], "concreto")
        k.choques.append(((cx, y + r, cz), (1.8, 2 * r, 2 * r), 0.0))
    return k


def camion_volteado(nombre, p):
    """Camion de redilas volteado atravesado en la calle (a lo largo de x): cabina, caja con
    redilas y llantas para arriba, con garrafones regados."""
    k = Constructor(nombre)
    largo = min(p.get("largo", 10.0), 9.0)
    color = p.get("color", "azul_gela")
    # Acostado de lado: lo que era el ancho ahora es el alto
    k.caja((-largo / 2 + 1.2, 1.1, 0), (2.4, 2.2, 2.2), color, choca=True)
    k.caja((-largo / 2 + 0.05, 1.2, 0), (0.1, 1.2, 1.6), "vidrio")
    k.caja((1.0, 1.25, 0), (largo - 2.6, 2.5, 0.15), "foto_madera", choca=True)
    for x in range(int(largo - 2.6)):
        k.caja((-largo / 2 + 2.9 + x, 1.25, 0.6), (0.08, 2.5, 1.1), "foto_madera")
    k.caja((1.0, 0.25, 0.6), (largo - 2.6, 0.5, 1.2), "fierro")
    for x in (-largo / 2 + 1.4, largo / 2 - 1.6, largo / 2 - 0.6):
        k.cilindro((x, 2.2, -0.6), 0.5, 0.35, "fierro", lados=8)
    for i in range(6):
        k.cilindro((-1.5 + i * 0.9, 0.0, 1.6 + (i % 2) * 0.5), 0.17, 0.5, "azul_gela", lados=6)
    return k


def escombro(nombre, p):
    """Casa derrumbada sobre la calle (a lo largo de x): monton de block y varillas, una losa
    rota inclinada y un carro quemado aplastado."""
    k = Constructor(nombre)
    largo = p.get("largo", 10.0)
    semilla = sum((i + 1) * ord(c) for i, c in enumerate(nombre))
    for i in range(14):
        x = -largo / 2 + 0.5 + (semilla * (i + 3) % int(largo * 10)) / 10
        z = -1.5 + (semilla * (i + 5) % 30) / 10
        s = 0.8 + (semilla * (i + 11) % 10) / 10
        k.caja((x, s / 2, z), (s * 1.4, s, s), "foto_block", (i * 0.7) % math.pi)
    k.cara([(-largo / 2, 0.2, 1.5), (largo / 2 - 1.0, 2.6, 1.0), (largo / 2 - 1.0, 2.6, -1.8), (-largo / 2, 0.2, -1.2)], "concreto")
    k.cara([(-largo / 2, 0.2, -1.2), (largo / 2 - 1.0, 2.6, -1.8), (largo / 2 - 1.0, 2.6, 1.0), (-largo / 2, 0.2, 1.5)], "concreto")
    for i in range(6):
        k.caja((-largo / 2 + 1.5 + i * 1.2, 2.4, 0.0), (0.04, 1.6, 0.04), "varilla", i * 0.4)
    _carro(k, largo / 2 - 2.0, 2.5, 0.4, "rojo", quemado=True)
    k.choques.append(((0, 1.3, 0), (largo, 2.6, 3.4), 0.0))
    return k


PIEZAS = {"kiosco": kiosco, "puesto": puesto, "banca": banca, "jardinera": jardinera, "fuente": fuente,
          "parroquia": parroquia, "palacio": palacio, "ficus": ficus, "portal": portal, "atrio": atrio,
          "cancha": cancha, "espectacular": espectacular, "base_gela": base_gela, "tiendita": tiendita, "tortilleria": tortilleria, "tope": tope, "mercado": mercado, "bajada": bajada, "basamento": basamento, "plinto": plinto, "puente": puente, "antena_radio": antena_radio, "barda": barda, "lote": lote, "carro": carro, "patio": patio,
          "escalera": escalera, "tablon": tablon, "vecindad": vecindad,
          "valla_gela": valla_gela, "camion_volteado": camion_volteado, "escombro": escombro}
