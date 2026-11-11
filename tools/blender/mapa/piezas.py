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


def puesto(nombre, p):
    """Puesto de tianguis: cuatro tubos, una lona inclinada, la mesa con su mercancia en cajas."""
    k = Constructor(nombre)
    ancho, fondo, alto = p.get("tam", [3.0, 2.2, 2.4])
    lona = "lona_" + p.get("lona", "rojo")
    for x in (-ancho / 2 + 0.05, ancho / 2 - 0.05):
        for z, h in ((fondo / 2 - 0.05, alto - 0.6), (-fondo / 2 + 0.05, alto)):
            k.caja((x, h / 2, z), (0.05, h, 0.05), "fierro")
    # Lona: inclinada hacia el frente y colgando un poco al centro
    # Bien inclinada: casi plana, a la altura de los ojos solo se veia de canto
    a, b = alto, alto - 0.6
    medio = (a + b) / 2 - 0.12
    k.cara([(-ancho / 2, b, fondo / 2 + 0.2), (ancho / 2, b, fondo / 2 + 0.2), (ancho / 2, medio, 0), (-ancho / 2, medio, 0)], lona)
    k.cara([(-ancho / 2, medio, 0), (ancho / 2, medio, 0), (ancho / 2, a, -fondo / 2), (-ancho / 2, a, -fondo / 2)], lona)
    k.cara([(-ancho / 2, medio, 0), (-ancho / 2, a, -fondo / 2), (ancho / 2, a, -fondo / 2), (ancho / 2, medio, 0)], lona)
    k.cara([(-ancho / 2, b, fondo / 2 + 0.2), (-ancho / 2, medio, 0), (ancho / 2, medio, 0), (ancho / 2, b, fondo / 2 + 0.2)], lona)
    # Mesa y cajas de fruta
    k.caja((0, 0.85, 0.2), (ancho - 0.3, 0.06, fondo * 0.55), "foto_madera", choca=False)
    k.caja((0, 0.42, 0.2), (ancho - 0.4, 0.84, fondo * 0.5), "foto_madera")
    for i, x in enumerate((-0.8, 0.0, 0.8)):
        if abs(x) < ancho / 2 - 0.3:
            fruta = ("rojo", "naranja_gela", "pasto_muerto")[(i + len(nombre)) % 3]
            k.caja((x, 1.0, 0.25), (0.6, 0.24, 0.45), "foto_madera")
            k.caja((x, 1.13, 0.25), (0.52, 0.04, 0.38), fruta)
    k.choques.append(((0, 0.5, 0.2), (ancho - 0.3, 1.0, fondo * 0.55), 0.0))
    return k


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
    for i in range(9):
        k.caja((-hx + 1.0 + i * 0.45, 0.1, hz + 0.5 + (i % 2) * 0.2), (0.12, 0.2, 0.12), "veladora")
    return k


PIEZAS = {"kiosco": kiosco, "puesto": puesto, "banca": banca, "jardinera": jardinera, "fuente": fuente,
          "parroquia": parroquia, "palacio": palacio, "ficus": ficus, "portal": portal, "atrio": atrio}
