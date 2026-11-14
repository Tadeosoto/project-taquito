# El laberinto de la favela de La Gotera (docs/mapa/colonias/la_gotera.md): toda la zona de la
# favela es un solo laberinto de casas de obra negra pegadas unas a otras (block y ladrillo, de vez
# en cuando una pintada), con callejones quebrados de 1.2 a 2.2 m, muchos sin salida, patios,
# plazuelas con un puesto, terrazas por distancia a la avenida (mas adentro, mas alto) con sus
# escalinatas, tablones entre azoteas, escaleras a las azoteas y, bajo tres patios, las bocas de
# los tuneles de ladrillo (lore §11). Sin calles de OSM: la favela se comio la traza (JJ, 2026-11-13)
# y no deja huecos. Determinista por semilla.
#
# Python puro (sin bpy), despues de bloqueo.py y antes de colonia.py:
#
#   python3 tools/blender/mapa/favela.py la_gotera_favela
#
# Todo lo que pone lleva "favela": true y se rehace al correr otra vez; lo puesto a mano se queda.
# Del bloqueo solo se queda la muralla: quita sus calles, casas, lotes, tapones y postes.
#
# Como funciona: se trabaja en un marco girado `theta` (el de las calles de Haciendas, unos 5 grados,
# para que la favela quede paralela a la muralla poniente y a sus bocas). Se rasteriza el recorte a
# 1 m: todo es libre menos la orilla de la muralla y las `reservas` (la plaza de los Gotera, la casa
# de don Nemesio, la bodega). Encima va una cuadricula de PASO m; cada celda es un lote y los
# callejones corren entre celdas vecinas: un recorrido en profundidad (DFS) desde la boca del
# poniente abre un arbol de callejones, se abren LAZOS mas para que haya vueltas, y cada marca "paso"
# del .json (las bocas al tianguis) se conecta al arbol. Cada celda queda como casa (con su frente
# al callejon), dos celdas juntas como casa grande, o como patio o plazuela.
#
# "favela" del .json: {"semilla", "paso", "callejon": [min, max], "theta", "tuneles": true}.

import json
import math
import os
import random
import sys

RAIZ = os.environ.get("TAQUITO_RAIZ", os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))))
COLONIAS = os.path.join(RAIZ, "tools", "blender", "mapa", "colonias")

PASO = 7.8              # m de la cuadricula: cada celda es un lote (mas grande = menos caminos)
CALLEJON = (2.0, 3.0)   # m de ancho de los callejones (mas anchos)
# Las tiendas de los cuartos "tienda" del tunel: [giro, letrero]; el giro abre su interior
# (Interiores.escenas en scenes/mapa.tscn: scenes/interiores/tunel_fayuca.tscn y tunel_armas.tscn)
TIENDAS_TUNEL = [("fayuca_tunel", "Fayuca del Túnel"), ("armas_tunel", "Balas y Veladoras")]
BOCA_ANCHO = 2.4        # m de las bocas al tianguis
BOCA_LLEGADA = 6.0      # m de la orilla poniente del recorte (como mucho: antes de la esquina) a la llegada de una boca
BOCA_FLECHA = 2.5       # m antes de la llegada, la flecha de regreso al tianguis
LAZOS = 0.10            # que parte de las paredes entre celdas se abre ademas del arbol
PATIO = 0.06            # que parte de las celdas son patio de tendederos
PLAZUELA = 0.04         # ... o plazuela con un puesto de lona (donde cruzan 3 callejones o mas)
DOBLE = 0.25            # que parte de las casas toman dos celdas
BANDAS = [(1e9, 0.0)]   # la favela es plana: todo al nivel del piso (sin terrazas ni rampas)
PISO = 2.75
AZOTEA = 0.05
TABLON_MAX = 3.2        # m: callejones mas angostos que esto pueden llevar tablon entre azoteas
PINTADAS = ["azul", "verde", "mostaza", "turquesa", "rosa", "lima", "naranja"]
MARGEN = 1.6            # m libres junto a la muralla
# Tuneles (piezas.tunel): el piso de la galeria y la zanja de cada boca
TUNEL_PISO = -4.2
TUNEL_ANCHO = 2.4
TUNEL_ALTO = 2.5        # como piezas.TUNEL_ALTO: al arranque de la boveda
ZANJA_LARGO = 6.6       # la bajada (5.0 m a 40 grados) y el descanso
ZANJA_ANCHO = 2.4       # como la galeria, para que la zanja abra justo en ella
TUNELES = 3             # bocas
# La plaza del tinaco y los claros (docs/mapa/colonias/la_gotera.md): el del tinaco es 3x3 y va lo
# mas cerca del centro; los demas son 2x2 y se reparten. Ya no hay Bodega del Agua.
TINACO_LITROS = 50000
CLAROS_EXTRA = 4
CLAROS_SEPARACION = 40.0
# Ademas del claro del tinaco (3x3), otros 3 claros grandes 3x3 repartidos; los CLAROS_EXTRA
# siguen siendo los pequenos 2x2.
CLAROS_GRANDES = 3
CLAROS_GRANDES_SEPARACION = 45.0
TINACO_SEPARACION = 40.0
# Las tiendas de favela: un giro de MapPuntos.GIROS_LOCAL por tienda (la gasolinera no va)
TIENDAS_FAVELA = [
    ("abarrotes", "Abarrotes Doña Chelo"),
    ("licoreria", "La Última Gota"),
    ("farmacia", "Farmacia La Bendición"),
    ("ferreteria", "El Tornillo Flojo"),
    ("oxxo", "OXO"),
    ("taqueria", "Tacos El Callejón"),
]
TIENDAS_SEPARACION = 35.0
# Lo que se cruza por dentro (JJ, 2026-11-13): casas abandonadas con un marco de puerta abierto
# en dos lados (pasantes), cadenas de casas abandonadas comunicadas por dentro (pasadizos) y
# callejones techados. Vacias, sin gente, con un foco adentro que a veces parpadea. Por ahora
# pocas y cerca del spawn, para verlas (vista previa).
ABANDONADAS = {"pasantes": 2, "pasadizos": 2, "techados": 2}
# Los pasadizos son cuevas: una hilera larga de casas abandonadas que da vueltas por dentro de la
# manzana, con focos que fallan mas. Las dos tiendas del tunel (con su flecha e interior propio)
# van en casas de en medio del primero.
PASADIZO_CASAS = 6
PASADIZO_PARPADEA = 0.6
# Por ahora (JJ, 2026-11-13): sin la red subterranea bajo el tinaco ni escaleras a las azoteas
SUBTERRANEO = False
ESCALERAS_AZOTEA = 0
ABANDONADA_PUERTA = 1.5
ABANDONADA_PARPADEA = 0.4
TIENDA_TUNEL_ADENTRO = 0.8  # m de la flecha al muro (como PUERTA_AFUERA en Colonia.gd)
TECHADO_ESQUINA = 1.3     # m que el techo de un callejon se queda antes de cada esquina
# Puentes largos entre azoteas de dos pisos (los tablones normales ya existen)
PUENTES = 4
PUENTE_ANCHO = 1.35
PUENTE_HUECO = (2.0, 2.9)
# Toldos de lona sobre los callejones: uno de cada 3 o 4, a 3.0-3.4 m
TOLDO_CADA = (25.0, 45.0)
TOLDO_LARGO = (2.5, 4.5)
TOLDO_ALTO = (3.0, 3.4)


def _dentro(x, z, pol):
    dentro = False
    j = len(pol) - 1
    for i in range(len(pol)):
        xi, zi = pol[i]
        xj, zj = pol[j]
        if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi or 1e-9) + xi:
            dentro = not dentro
        j = i
    return dentro


class Marco:
    """El marco girado: (u, v) locales <-> (x, z) del mundo. El eje u va al oriente, v al sur."""
    def __init__(self, cx, cz, theta):
        self.cx, self.cz, self.c, self.s = cx, cz, math.cos(theta), math.sin(theta)
        self.theta = theta

    def local(self, x, z):
        dx, dz = x - self.cx, z - self.cz
        return self.c * dx + self.s * dz, -self.s * dx + self.c * dz

    def mundo(self, u, v):
        return self.cx + self.c * u - self.s * v, self.cz + self.s * u + self.c * v

    # Giro en y de Godot de una pieza cuyo +X local es el eje u (su +Z queda en v):
    # rot = atan2(-dz, dx) con (dx, dz) = (c, s)
    @property
    def rot(self):
        return round(math.atan2(-self.s, self.c), 4)

    @property
    def rot_v(self):
        """Giro de una pieza cuyo +X local es el eje v (su +Z queda en -u)."""
        return round(math.atan2(-self.c, -self.s), 4)


def _compactar(ruta):
    import re
    texto = open(ruta, encoding="utf-8").read()
    texto = re.sub(r"\[\s+(-?[\d.eE+-]+(?:,\s+-?[\d.eE+-]+)*)\s+\]",
                   lambda m: "[" + ", ".join(m.group(1).split()).replace(",,", ",") + "]", texto)
    open(ruta, "w", encoding="utf-8", newline="\n").write(texto + ("\n" if not texto.endswith("\n") else ""))


def generar(nombre):
    ruta = os.path.join(COLONIAS, nombre + ".json")
    datos = json.load(open(ruta, encoding="utf-8"))
    op = datos.get("favela", {})
    r = random.Random(op.get("semilla", 7))
    paso = op.get("paso", PASO)
    callejon = tuple(op.get("callejon", CALLEJON))
    x1, z1, x2, z2 = datos["recorte"]
    theta = op.get("theta", 0.089)
    marco = Marco((x1 + x2) / 2, (z1 + z2) / 2, theta)
    # Lo del bloqueo que sobra: la favela no respeta la traza (se queda la muralla)
    def sobra(p):
        return p.get("auto") and p["tipo"] != "muralla"
    datos["piezas"] = [p for p in datos.get("piezas", []) if not p.get("favela") and not sobra(p)]
    datos["postes"] = []
    datos["nombres_calles"] = {}
    datos["hundidos"] = [h for h in datos.get("hundidos", []) if not h.get("favela")]
    # La Bodega del Agua ya no existe (JJ): fuera su reserva, su casa-local, su puerta, su negocio
    # y la marca de mision del cuarto de garrafones. El cuarto sigue; su marca se rehace abajo.
    datos["reservas"] = [r for r in datos.get("reservas", []) if r.get("nombre") != "Bodega_Agua"]
    datos["piezas"] = [p for p in datos["piezas"] if p.get("nombre") != "Bodega_Agua"]
    datos["marcas"] = [m for m in datos.get("marcas", [])
        if m.get("nombre") not in ("Puerta_purificadora_0", "Bodega_Agua")
        and not (m.get("tipo") == "puerta" and m.get("giro") == "purificadora")]
    datos["negocios"] = [n for n in datos.get("negocios", [])
        if n.get("nombre") != "Bodega del Agua" and n.get("origen") != "Bodega del Agua"
        and n.get("tipo") != "purificadora" and not n.get("favela")
        and not str(n.get("origen", "")).startswith("Favela_")]
    # Perfil detallado (el de ~52 MB): detalles de azotea y adornos de callejon por omision.
    # Al quitar "callejones" del .json, colonia._cada() usa TENDEDERO_CADA/BASURA_CADA/FOCO_CADA.
    datos.pop("callejones", None)
    datos["gente"] = []
    reservas = [res["puntos"] for res in datos.get("reservas", [])]
    # El raster a 1 m en el marco local, hasta donde alcance el recorte girado
    esquinas = [marco.local(x, z) for x, z in ((x1, z1), (x2, z1), (x2, z2), (x1, z2))]
    u0, u1 = math.floor(min(e[0] for e in esquinas)), math.ceil(max(e[0] for e in esquinas))
    v0, v1 = math.floor(min(e[1] for e in esquinas)), math.ceil(max(e[1] for e in esquinas))
    W, H = u1 - u0, v1 - v0
    libre = [[False] * W for _ in range(H)]
    reservado = [[False] * W for _ in range(H)]
    for j in range(H):
        for i in range(W):
            x, z = marco.mundo(u0 + i + 0.5, v0 + j + 0.5)
            if not (x1 + MARGEN < x < x2 - MARGEN and z1 + MARGEN < z < z2 - MARGEN):
                continue
            if any(_dentro(x, z, res) for res in reservas):
                reservado[j][i] = True
                continue
            libre[j][i] = True
    piezas, terrazas, hundidos, marcas = [], [], [], []
    cuenta = {"casas": 0, "patios": 0, "plazuelas": 0, "callejones": 0, "bocas": 0, "tablones": 0, "escaleras": 0, "rampas": 0, "tuneles": 0, "tiendas_tunel": 0,
              "tiendas": 0, "claros": 0, "grandes": 0, "tinacos": 0, "puentes": 0, "toldos": 0, "postes": 0, "podados": 0}
    _laberinto(datos, libre, reservado, u0, v0, W, H, marco, r, paso, callejon, piezas, terrazas, hundidos, marcas, cuenta, op)
    datos["piezas"] += piezas
    datos["terrazas"] = [t for t in datos.get("terrazas", []) if not t.get("favela")] + terrazas
    datos["hundidos"] += hundidos
    datos["marcas"] = [m for m in datos.get("marcas", []) if not m.get("favela")] + marcas
    json.dump(datos, open(ruta, "w", encoding="utf-8"), ensure_ascii=False, indent="\t")
    _compactar(ruta)
    print("favela %s: %s, theta %.3f" % (nombre, cuenta, theta))


def _laberinto(datos, libre, reservado, u0, v0, W, H, marco0, r, paso, callejon, piezas, terrazas, hundidos, marcas, cuenta, op):
    """El laberinto sobre la cuadricula: los lotes son las celdas y los callejones corren por las
    lineas de la cuadricula (los lados de las celdas). El grafo del DFS son las esquinas de la
    cuadricula: cada arista abierta es un tramo de callejon de una esquina a la otra, asi que la red
    siempre esta conectada y sus hojas son callejones sin salida. Cada celda se encoge la mitad del
    ancho del callejon por cada lado que lo tenga."""
    x1, z1, x2, z2 = datos["recorte"]
    # Aqui todo va en metros del raster (celda (i, j) = local (u0 + i, v0 + j)): este marco suma el corrido
    class _Marco:
        c, s, rot, rot_v = marco0.c, marco0.s, marco0.rot, marco0.rot_v
        def mundo(self, i, j):
            return marco0.mundo(u0 + i, v0 + j)
        def local(self, x, z):
            u, v = marco0.local(x, z)
            return u - u0, v - v0
    marco = _Marco()
    nx, nz = max(1, int(W / paso)), max(1, int(H / paso))
    pu, pv = W / nx, H / nz
    dentro = {}
    for a in range(nx):
        for b in range(nz):
            total = ok = 0
            for i in range(int(a * pu), int((a + 1) * pu)):
                for j in range(int(b * pv), int((b + 1) * pv)):
                    total += 1
                    ok += libre[j][i]
            dentro[(a, b)] = total > 0 and ok / total > 0.9
    celdas = [k for k, v in dentro.items() if v]
    if len(celdas) < 2:
        return
    # Bandas de terraza por columna
    def banda(a):
        du = (a + 0.5) * pu
        for n, (hasta, alto) in enumerate(BANDAS):
            if du < hasta:
                return n
        return len(BANDAS) - 1
    def alto_de(a):
        return BANDAS[banda(a)][1]
    bordes_banda = {a for a in range(1, nx) if banda(a) != banda(a - 1)}
    # El grafo: esquinas (a, b) de las celdas dentro; aristas por los lados de las celdas dentro.
    # Las aristas verticales sobre el borde de una banda no van: ahi el muro de la terraza queda entre casas
    def celdas_de(e):
        """Las dos celdas a los lados de la arista e = (esquina, "h"|"v") (h: hacia +a, v: hacia +b)."""
        (a, b), d = e
        return [(a, b - 1), (a, b)] if d == "h" else [(a - 1, b), (a, b)]
    aristas = {}
    for a in range(nx + 1):
        for b in range(nz + 1):
            for d in "hv":
                if (d == "h" and a >= nx) or (d == "v" and b >= nz):
                    continue
                if d == "v" and a in bordes_banda:
                    continue
                par = celdas_de(((a, b), d))
                lados = [c for c in par if dentro.get(c)]
                if not lados:
                    continue
                if len(lados) == 1:
                    # Una arista de la orilla: solo si del otro lado hay una reserva (la plaza, la casa de
                    # Nemesio); pegada a la muralla o fuera del recorte, no (el muro tapaba el callejon)
                    otra = [c for c in par if not dentro.get(c)][0]
                    cu, cv = (otra[0] + 0.5) * pu, (otra[1] + 0.5) * pv
                    i, j = int(cu), int(cv)
                    if not (0 <= i < W and 0 <= j < H and reservado[j][i]):
                        continue
                aristas[((a, b), d)] = lados
    def extremos(e):
        (a, b), d = e
        return (a, b), ((a + 1, b) if d == "h" else (a, b + 1))
    vecinas = {}
    for e in aristas:
        p0, p1 = extremos(e)
        vecinas.setdefault(p0, []).append((e, p1))
        vecinas.setdefault(p1, []).append((e, p0))
    # Las bocas: las marcas "paso" del .json, a la esquina mas cercana de la orilla poniente
    bocas = []
    for m in datos.get("marcas", []):
        if m.get("tipo") != "paso":
            continue
        mu, mv = marco.local(m["x"], m["z"])
        b = min(max(int(round(mv / pv)), 0), nz)
        a = next((a for a in range(nx + 1) if (a, b) in vecinas), None)
        if a is not None:
            bocas.append(((a, b), (mu, mv)))
            # La flecha y la llegada, sobre el eje del callejon de la boca (la linea b de la cuadricula,
            # hasta 3.5 m de la marca a mano) y antes de su esquina: si no, se llegaba junto a una casa
            # o encima de un tablon
            x0, x1 = marco.mundo(0.0, b * pv)[0], marco.mundo(1.0, b * pv)[0]
            def u_en_x(xt):
                return (xt - x0) / (x1 - x0)
            u_llega = min(u_en_x(datos["recorte"][0] + BOCA_LLEGADA), a * pu - 1.2)
            u_llega = max(u_llega, u_en_x(datos["recorte"][0] + BOCA_FLECHA + 0.8))
            x, z = marco.mundo(u_llega - BOCA_FLECHA, b * pv)
            m["x"], m["z"] = round(x, 2), round(z, 2)
            x, z = marco.mundo(u_llega, b * pv)
            m["llegada"] = [round(x, 2), round(z, 2)]
    # Sin lado (las pruebas, entrar directo) se aparece en la llegada de la boca de en medio
    pasos = [m for m in datos.get("marcas", []) if m.get("tipo") == "paso" and "llegada" in m]
    for m in datos.get("marcas", []):
        if m.get("tipo") == "spawn" and pasos:
            m["x"], m["z"] = pasos[len(pasos) // 2]["llegada"]
    inicio =bocas[0][0] if bocas else min(vecinas, key=lambda k: (k[0], abs(k[1] - nz / 2)))
    visitado = {inicio}
    abiertas = set()
    pila = [inicio]
    while pila:
        actual = pila[-1]
        opciones = [(e, q) for e, q in vecinas.get(actual, []) if q not in visitado]
        if not opciones:
            pila.pop()
            continue
        e, q = r.choice(opciones)
        visitado.add(q)
        abiertas.add(e)
        pila.append(q)
    for e in aristas:
        if e not in abiertas and r.random() < LAZOS:
            p0, p1 = extremos(e)
            if p0 in visitado and p1 in visitado:
                abiertas.add(e)
    # Donde un callejon horizontal llega al borde de una banda, sigue del otro lado (la escalinata no da a un muro)
    for e in list(abiertas):
        (a, b), d = e
        if d != "h":
            continue
        if (a + 1) in bordes_banda and ((a + 1, b), "h") in aristas:
            abiertas.add(((a + 1, b), "h"))
        if a in bordes_banda and ((a - 1, b), "h") in aristas:
            abiertas.add(((a - 1, b), "h"))
    # Cada celda con al menos un lado de callejon (si no, se le abre uno)
    def lados_celda(a, b):
        return {"N": ((a, b), "h"), "S": ((a, b + 1), "h"), "O": ((a, b), "v"), "E": ((a + 1, b), "v")}
    for (a, b) in celdas:
        ls = lados_celda(a, b)
        if not any(e in abiertas for e in ls.values()):
            posibles = [e for e in ls.values() if e in aristas]
            if posibles:
                abiertas.add(r.choice(posibles))
    # Menos caminos y menos callejones sin salida: una pasada de poda de hojas. Un nodo de grado 1
    # es el fondo de un callejon sin salida; se quita su unico tramo y esa celda queda como casa
    # cerrada. No se tocan las bocas (sus nodos estan protegidos). Se hace antes de medir anchos.
    grado = {}
    for e in abiertas:
        p0, p1 = extremos(e)
        grado[p0] = grado.get(p0, 0) + 1
        grado[p1] = grado.get(p1, 0) + 1
    protegidos_poda = {b[0] for b in bocas}
    for nodo, g in list(grado.items()):
        if g != 1 or nodo in protegidos_poda:
            continue
        for e, _q in vecinas.get(nodo, []):
            if e in abiertas:
                abiertas.discard(e)
                cuenta["podados"] += 1
                break
    # Ancho por tramo recto: cadenas de aristas abiertas colineales (hasta 4), con quiebres al azar
    ancho_de = {}
    runs = []
    hechas = set()
    for e in sorted(abiertas, key=lambda e: (e[1], e[0][1], e[0][0])):
        if e in hechas:
            continue
        (a, b), d = e
        w = round(r.uniform(*callejon), 2)
        cadena = [e]
        hechas.add(e)
        ancho_de[e] = w
        while len(cadena) < 4 and r.random() > 0.3:
            ea, eb = cadena[-1][0]
            sig = ((ea + 1, eb), "h") if d == "h" else ((ea, eb + 1), "v")
            if sig not in abiertas or sig in hechas:
                break
            # Un tramo horizontal no cruza el borde de una banda: ahi se corta (escalinata)
            if d == "h" and sig[0][0] in bordes_banda:
                break
            cadena.append(sig)
            hechas.add(sig)
            ancho_de[sig] = w
        runs.append((cadena, w))
    def ancho_lado(a, b, lado):
        e = lados_celda(a, b)[lado]
        return ancho_de.get(e, 0.0) if e in abiertas else 0.0
    # Terrazas: las bandas, de orilla a orilla del raster
    for n, (hasta, alto) in enumerate(BANDAS):
        if alto <= 0:
            continue
        cols = [a for a in range(nx) if banda(a) == n]
        if not cols:
            continue
        a0, a1 = min(cols), max(cols) + 1
        poligono = [marco.mundo(a0 * pu, 0.3), marco.mundo(a1 * pu, 0.3), marco.mundo(a1 * pu, H - 0.3), marco.mundo(a0 * pu, H - 0.3)]
        terrazas.append({"nombre": "Banda_%d_Terraza" % n, "favela": True, "poligono": [[round(x, 2), round(z, 2)] for x, z in poligono], "alto": alto})
    # --- Las piezas de los callejones ---
    def pieza_calle(nombre, ua, va, ub, vb, w):
        xa, za = marco.mundo(ua, va)
        xb, zb = marco.mundo(ub, vb)
        return {"nombre": nombre, "tipo": "calle", "favela": True, "x": round(xa, 2), "z": round(za, 2),
                "puntos": [[0.0, 0.0], [round(xb - xa, 2), round(zb - za, 2)]], "ancho": w, "banqueta": 0.0, "material": "empedrado", "real": ""}
    escalinatas_en = set()   # (columna del borde, fila): dos cadenas que se juntan ahi ponian dos escalinatas
    for cadena, w in runs:
        (a, b), d = cadena[0]
        (c, e_), _d = cadena[-1]
        if d == "h":
            ua, va, ub, vb = a * pu, b * pv, (c + 1) * pu, b * pv
            # Si la cadena termina en el borde de una banda (su ultima arista llega a el), ahi va la escalinata
            k = cuenta["callejones"]
            if (c + 1) in bordes_banda and c + 1 < nx and alto_de(c + 1) != alto_de(c) and (c + 1, b) not in escalinatas_en:
                escalinatas_en.add((c + 1, b))
                sube = alto_de(c + 1) - alto_de(c)
                largo = 1.0 if abs(sube) <= 0.8 else 2.0
                piezas.append(pieza_calle("Callejon_%d" % k, ua, va, ub - 0.02, vb, w))
                xe, ze = marco.mundo(ub - largo, vb)
                piezas.append({"nombre": "Rampa_%d" % k, "tipo": "rampa", "favela": True, "x": round(xe, 2), "z": round(ze, 2),
                               "y": alto_de(c), "rot": marco.rot, "largo": largo, "ancho": round(w - 0.1, 2), "alto": sube})
                cuenta["rampas"] += 1
            elif a in bordes_banda and a > 0 and alto_de(a) != alto_de(a - 1) and (a, b) not in escalinatas_en:
                escalinatas_en.add((a, b))
                # La cadena arranca en el borde: la escalinata sube desde el lado de abajo (poniente)
                sube = alto_de(a) - alto_de(a - 1)
                largo = 1.0 if abs(sube) <= 0.8 else 2.0
                piezas.append(pieza_calle("Callejon_%d" % k, ua + 0.02, va, ub, vb, w))
                xe, ze = marco.mundo(ua - largo, va)
                piezas.append({"nombre": "Rampa_%d" % k, "tipo": "rampa", "favela": True, "x": round(xe, 2), "z": round(ze, 2),
                               "y": alto_de(a - 1), "rot": marco.rot, "largo": largo, "ancho": round(w - 0.1, 2), "alto": sube})
                cuenta["rampas"] += 1
                # Y abajo del borde, un pedacito de callejon a la altura de abajo que llegue a la escalinata
                piezas.append(pieza_calle("Callejon_%d_b" % k, ua - largo - 0.6, va, ua - largo, vb, w))
            else:
                piezas.append(pieza_calle("Callejon_%d" % k, ua, va, ub, vb, w))
        else:
            piezas.append(pieza_calle("Callejon_%d" % cuenta["callejones"], a * pu, b * pv, a * pu, (e_ + 1) * pv, w))
        cuenta["callejones"] += 1
    # Las bocas al tianguis: de la orilla poniente del recorte a su esquina
    for (a, b), (mu, mv) in bocas:
        piezas.append(pieza_calle("Boca_%d" % cuenta["bocas"], -1.0, b * pv, a * pu + 0.3, b * pv, BOCA_ANCHO))
        cuenta["bocas"] += 1
    # Los lotes de los tuneles: tres pares de celdas de la banda a nivel sin callejon entre ellas
    zanjas = []
    if op.get("tuneles", True):
        for (a, b) in sorted(celdas, key=lambda k: (k[1] % 5, k[0])):
            if banda(a) != 0 or banda(a + 1) != 0 or not dentro.get((a + 1, b)) or len(zanjas) >= TUNELES:
                continue
            if ancho_lado(a, b, "E") > 0 or any(abs(b - zb) < 5 for (_c, zb) in [z[0] for z in zanjas]):
                continue
            zanjas.append(((a, b), (a + 1, b)))
    celdas_zanja = {c for par in zanjas for c in par}
    # --- Lotes ---
    usada = set()
    casas = {}
    for (a, b) in sorted(celdas, key=lambda k: (k[1], k[0])):
        if (a, b) in usada:
            continue
        usada.add((a, b))
        frentes = [l for l in "NSEO" if ancho_lado(a, b, l) > 0]
        u_a = a * pu + ancho_lado(a, b, "O") / 2
        u_b = (a + 1) * pu - ancho_lado(a, b, "E") / 2
        v_a = b * pv + ancho_lado(a, b, "N") / 2
        v_b = (b + 1) * pv - ancho_lado(a, b, "S") / 2
        if (a, b) in celdas_zanja:
            # El lote doble de una boca de tunel: piso pelon con la zanja (la pone _tuneles)
            usada.add((a + 1, b))
            u_b = (a + 2) * pu - ancho_lado(a + 1, b, "E") / 2
            v_a = max(v_a, b * pv + ancho_lado(a + 1, b, "N") / 2)
            v_b = min(v_b, (b + 1) * pv - ancho_lado(a + 1, b, "S") / 2)
            cu, cv = (u_a + u_b) / 2, (v_a + v_b) / 2
            zanjas[[z[0] for z in zanjas].index((a, b))] = ((a, b), (cu, cv), (u_a, u_b))
            continue
        cruces = len(frentes)
        dado = r.random()
        tipo = "casa"
        if cruces >= 3 and dado < PLAZUELA:
            tipo = "plazuela"
        elif dado < PATIO and frentes:
            tipo = "patio"
        if tipo == "casa" and r.random() < DOBLE:
            v = (a + 1, b)
            if dentro.get(v) and v not in usada and v not in celdas_zanja and ancho_lado(a, b, "E") == 0 and banda(a + 1) == banda(a):
                usada.add(v)
                u_b = (a + 2) * pu - ancho_lado(a + 1, b, "E") / 2
                v_a = max(v_a, b * pv + ancho_lado(a + 1, b, "N") / 2)
                v_b = min(v_b, (b + 1) * pv - ancho_lado(a + 1, b, "S") / 2)
                frentes += [l for l in "NSE" if ancho_lado(a + 1, b, l) > 0]
        cu, cv = (u_a + u_b) / 2, (v_a + v_b) / 2
        hw, hh = (u_b - u_a) / 2, (v_a - v_a + v_b - v_a) / 2
        hh = (v_b - v_a) / 2
        if hw < 1.4 or hh < 1.4:
            continue
        x, z = marco.mundo(cu, cv)
        nombre = "%d_%d" % (a, b)
        if tipo == "patio":
            piezas.append({"nombre": "Patio_" + nombre, "tipo": "patio", "favela": True, "x": round(x, 2), "z": round(z, 2), "rot": marco.rot,
                           "tam": [round(hw * 2 - 0.3, 2), round(hh * 2 - 0.3, 2)]})
            cuenta["patios"] += 1
            continue
        if tipo == "plazuela":
            piezas.append({"nombre": "Plazuela_" + nombre, "tipo": "lote", "favela": True, "x": round(x, 2), "z": round(z, 2), "rot": marco.rot,
                           "tam": [round(hw * 2, 2), round(hh * 2, 2)], "variante": "fonda" if r.random() < 0.6 else "baldio"})
            cuenta["plazuelas"] += 1
            continue
        lados = {"N": 0, "E": 1, "S": 2, "O": 3}
        frente = lados[r.choice(frentes)] if frentes else lados[r.choice("NSEO")]
        # Los otros lados que dan a un callejon llevan ventanas (sin puerta): no son muro ciego
        ventanas = sorted({lados[l] for l in frentes} - {frente})
        dado = r.random()
        pisos = 1 if dado < 0.25 else 2 if dado < 0.85 else 3
        obra = None
        if pisos == 3:
            pisos, obra = 2, "castillos"
        elif r.random() < 0.25:
            obra = "castillos" if r.random() < 0.7 else "losa"
        casa = {"nombre": "Casa_" + nombre, "tipo": "casa", "favela": True, "grupo": "Favela_%d_%d" % (a // 6, b // 6), "x": round(x, 2), "z": round(z, 2), "rot": marco.rot,
                "puntos": [[round(-hw, 2), round(-hh, 2)], [round(hw, 2), round(-hh, 2)], [round(hw, 2), round(hh, 2)], [round(-hw, 2), round(hh, 2)]],
                "pisos": pisos, "frente": frente, "desgaste": round(r.uniform(0.4, 0.8), 2), "tapado": 0.3, "detalles": True,
                "ventanas": ventanas}
        if r.random() < 0.12:
            casa["color"] = r.choice(PINTADAS)
            casa["desgaste"] = 0.85
        else:
            casa["acabado"] = "block" if r.random() < 0.6 else "ladrillo"
            casa["ventanal"] = r.random() < 0.25
        if obra:
            casa["obra"] = obra
        piezas.append(casa)
        casas[(a, b)] = casa
        cuenta["casas"] += 1
    # Tablones: sobre una arista angosta entre dos casas de dos pisos
    # En orden fijo: las aristas llevan "h"/"v" y un set con texto cambia de orden en cada corrida
    # (PYTHONHASHSEED), y con el el azar de todo lo que sigue
    for e in sorted(abiertas, key=lambda e: (e[1], e[0][1], e[0][0])):
        if ancho_de.get(e, 9.0) > TABLON_MAX:
            continue
        c0, c1 = celdas_de(e)
        ca, cc = casas.get(c0), casas.get(c1)
        if not ca or not cc or ca["pisos"] != 2 or cc["pisos"] != 2 or banda(c0[0]) != banda(c1[0]):
            continue
        (a, b), d = e
        if d == "h":
            um, vm = (a + 0.5) * pu, b * pv
            rot = marco.rot_v
        else:
            um, vm = a * pu, (b + 0.5) * pv
            rot = marco.rot
        x, z = marco.mundo(um, vm)
        piezas.append({"nombre": "Tablon_%d" % cuenta["tablones"], "tipo": "tablon", "favela": True, "x": round(x, 2), "z": round(z, 2),
                       "y": round(2 * PISO + AZOTEA + 0.02 + alto_de(a if d == "v" else a), 2), "rot": rot, "largo": round(ancho_de[e] + 1.2, 2), "ancho": 1.2})
        cuenta["tablones"] += 1
    surcos = _post_favela(datos, piezas, marcas, casas, celdas, celdas_zanja, marco, banda, alto_de, nx, nz, pu, pv, abiertas, ancho_de, celdas_de, cuenta, op)
    if op.get("subterraneo", SUBTERRANEO):
        _tuneles_mini(datos, piezas, hundidos, marcas, cuenta, surcos, marco)


_BORDES = {"N": lambda a, b: ((a, b), "h"), "E": lambda a, b: ((a + 1, b), "v"),
           "S": lambda a, b: ((a, b + 1), "h"), "O": lambda a, b: ((a, b), "v")}
_VECINO = {"N": (0, -1), "E": (1, 0), "S": (0, 1), "O": (-1, 0)}


def _abandonadas(piezas, marcas, casas, abiertas, ancho_de, marco, pu, pv, protegidos, spawn, cuenta, op):
    """Casas pasantes, pasadizos y callejones techados (ABANDONADAS), los mas cercanos a `spawn`.
    Cada casa abandonada sustituye a su casa (misma huella y pisos, tipo "abandonada", con sus
    "puertas"); cada una lleva su foco y una marca "interior" con los techos que Colonia.gd
    esconde mientras estas adentro."""
    rng = random.Random(int(op.get("semilla", 7)) + 106)
    hechas = []     # centros, para no amontonarlas

    def libre(x, z, cerca=12.0):
        return all(_dist((x, z), q) >= cerca for q in protegidos + hechas)

    # Las casas dobles ocupan su celda y la de al lado (+u): cada celda -> la celda llave de su casa
    dueno = {}
    for llave, casa in casas.items():
        if casa.get("local"):
            continue
        dueno[llave] = llave
        if not _celda_simple(casa, pu, pv):
            dueno[(llave[0] + 1, llave[1])] = llave

    def celdas_de_casa(llave):
        return [c for c, k in dueno.items() if k == llave]

    def lados_abiertos(llave):
        """[(lado, celda)] de los lados de la casa que dan a un callejon de ancho para pasar."""
        fuera = []
        for c in sorted(celdas_de_casa(llave)):
            for l in "NESO":
                borde = _BORDES[l](*c)
                if borde in abiertas and ancho_de.get(borde, 0.0) >= 1.6:
                    fuera.append((l, c))
        return fuera

    def sirve(cell):
        casa = casas.get(cell)
        return casa is not None and not casa.get("local") and _celda_simple(casa, pu, pv)

    def punto_de_arista(c, l):
        a, b = c
        u, v = {"N": ((a + 0.5) * pu, b * pv), "E": ((a + 1) * pu, (b + 0.5) * pv),
                "S": ((a + 0.5) * pu, (b + 1) * pv), "O": (a * pu, (b + 0.5) * pv)}[l]
        return marco.mundo(u, v)

    def t_en_lado(casa, lado, punto):
        """Donde cae `punto` a lo largo del lado (desde su punto inicial, como en piezas.abandonada)."""
        hw, hh = _lados(casa)
        c, s_ = math.cos(casa["rot"]), math.sin(casa["rot"])
        dx, dz = punto[0] - casa["x"], punto[1] - casa["z"]
        lx, lz = dx * c - dz * s_, dx * s_ + dz * c
        largo = 2 * (hw if lado in "NS" else hh)
        t = {"N": lx + hw, "E": lz + hh, "S": hw - lx, "O": hh - lz}[lado]
        m = ABANDONADA_PUERTA / 2 + 0.25
        return min(max(t, m), largo - m)

    def pegado(casa, lado, punto):
        """El muro de ese lado pasa por `punto` (no esta recorrido por un callejon de enfrente)."""
        hw, hh = _lados(casa)
        c, s_ = math.cos(casa["rot"]), math.sin(casa["rot"])
        dx, dz = punto[0] - casa["x"], punto[1] - casa["z"]
        lx, lz = dx * c - dz * s_, dx * s_ + dz * c
        return abs({"N": lz + hh, "E": lx - hw, "S": lz - hh, "O": lx + hw}[lado]) < 0.15

    def abandonar(cell, puertas, techos, n, parpadea=ABANDONADA_PARPADEA):
        casa = casas.pop(cell)
        nombre = "Abandonada_%d_%d" % cell
        nueva = {"nombre": nombre, "tipo": "abandonada", "favela": True, "x": casa["x"], "z": casa["z"], "rot": casa["rot"],
                 "puntos": casa["puntos"], "pisos": casa.get("pisos", 1), "acabado": casa.get("acabado", "block"),
                 "puertas": [["NESO".index(l), round(t, 2), ABANDONADA_PUERTA] for l, t in puertas]}
        piezas[:] = [p for p in piezas if p is not casa]
        piezas.append(nueva)
        marcas.append({"nombre": "Foco_" + nombre, "tipo": "foco", "favela": True, "x": casa["x"], "z": casa["z"],
                       "y": round(PISO - 0.5, 2), "siempre": True, "parpadea": rng.random() < parpadea})
        hw, hh = _lados(casa)
        techos.append(nombre)
        hechas.append((casa["x"], casa["z"]))
        cuenta["abandonadas"] = cuenta.get("abandonadas", 0) + 1
        return {"nombre": "Interior_" + nombre, "tipo": "interior", "favela": True, "x": casa["x"], "z": casa["z"],
                "rot": casa["rot"], "tam": [round(hw * 2, 2), round(hh * 2, 2)], "grupo": n}

    def cerca_del_spawn(cell):
        return _dist((casas[cell]["x"], casas[cell]["z"]), spawn)

    # Pasadizos (cuevas): PASADIZO_CASAS casas pegadas (sencillas o dobles, sin callejon entre
    # ellas) que dan vueltas; la primera y la ultima salen a callejones; adentro se pasa de una a
    # otra por un marco en el muro compartido
    opuesto = {"N": "S", "S": "N", "E": "O", "O": "E"}

    def vecinas(llave):
        """[(llave vecina, lado, celda propia)] de las casas pegadas por un muro sin callejon."""
        res = []
        for c in sorted(celdas_de_casa(llave)):
            for l in "NESO":
                da, db = _VECINO[l]
                otra = dueno.get((c[0] + da, c[1] + db))
                if otra is None or otra == llave or _BORDES[l](*c) in abiertas:
                    continue
                punto = punto_de_arista(c, l)
                if pegado(casas[llave], l, punto) and pegado(casas[otra], opuesto[l], punto):
                    res.append((otra, l, c))
        return res

    cadenas = []
    usadas = set()
    for llave in sorted(set(dueno.values()), key=cerca_del_spawn):
        if len(cadenas) >= ABANDONADAS["pasadizos"]:
            break
        if llave in usadas or not lados_abiertos(llave) or not libre(casas[llave]["x"], casas[llave]["z"], 20.0):
            continue
        pila = [([llave], [])]
        pasos = 0
        while pila and pasos < 20000:
            pasos += 1
            camino, pasos_ = pila.pop()
            if len(camino) == PASADIZO_CASAS:
                entra = [x for x in lados_abiertos(camino[0]) if x[0] != pasos_[0][1]]
                sale = [x for x in lados_abiertos(camino[-1]) if x[0] != opuesto[pasos_[-1][1]]]
                if entra and sale:
                    cadenas.append((camino, pasos_, entra[0], sale[0]))
                    usadas.update(camino)
                    break
                continue
            for otra, l, c in vecinas(camino[-1]):
                if otra not in camino and otra not in usadas:
                    pila.append((camino + [otra], pasos_ + [(c, l)]))
    n_grupo = 0
    for camino, pasos_, entra, sale in cadenas:
        puertas = {k: [] for k in camino}
        for i, (c, l) in enumerate(pasos_):
            punto = punto_de_arista(c, l)
            puertas[camino[i]].append((l, t_en_lado(casas[camino[i]], l, punto)))
            puertas[camino[i + 1]].append((opuesto[l], t_en_lado(casas[camino[i + 1]], opuesto[l], punto)))
        for k, (l, c) in ((camino[0], entra), (camino[-1], sale)):
            puertas[k].append((l, t_en_lado(casas[k], l, punto_de_arista(c, l))))
        techos = []
        if not cuenta.get("tiendas_tunel"):
            # Las tiendas del tunel en dos casas de en medio, en un muro sin puerta, viendo hacia adentro
            for k, (giro, texto) in zip((len(camino) // 3, 2 * len(camino) // 3), TIENDAS_TUNEL):
                casa = casas[camino[k]]
                usados = {l for l, _t in puertas[camino[k]]}
                lado = next(l for l in "NESO" if l not in usados)
                hw, hh = _lados(casa)
                n = {"N": (0.0, -1.0), "E": (1.0, 0.0), "S": (0.0, 1.0), "O": (-1.0, 0.0)}[lado]
                fondo = (hh if lado in "NS" else hw) - 0.2 - TIENDA_TUNEL_ADENTRO
                mx, mz = _mundo_local(casa, n[0] * fondo, n[1] * fondo)
                nx, nz = _girar(casa, (-n[0], -n[1]))
                marcas.append({"nombre": "Puerta_Tunel_Tienda_%d" % (k + 1), "tipo": "puerta", "favela": True,
                               "giro": giro, "texto": texto, "letrero_alto": 2.35, "x": round(mx, 2), "z": round(mz, 2), "y": 0.0,
                               "rot": round(math.atan2(nx, nz), 4)})
                cuenta["tiendas_tunel"] = cuenta.get("tiendas_tunel", 0) + 1
        interiores = [abandonar(k, puertas[k], techos, n_grupo, PASADIZO_PARPADEA) for k in camino]
        for i in interiores:
            i["techos"] = techos
            marcas.append(i)
        cuenta["pasadizos"] = cuenta.get("pasadizos", 0) + 1
        n_grupo += 1

    # Casas pasantes: un marco en dos lados que dan a callejones distintos (de preferencia opuestos)
    pasantes = 0
    for cell in sorted([c for c in casas if sirve(c)], key=cerca_del_spawn):
        if pasantes >= ABANDONADAS["pasantes"]:
            break
        abiertos = [l for l, _c in lados_abiertos(cell)]
        if len(abiertos) < 2 or not libre(casas[cell]["x"], casas[cell]["z"]):
            continue
        par = next(([x, y] for x, y in (("N", "S"), ("E", "O")) if x in abiertos and y in abiertos), abiertos[:2])
        techos = []
        i = abandonar(cell, [(l, t_en_lado(casas[cell], l, punto_de_arista(cell, l))) for l in par], techos, n_grupo)
        i["techos"] = techos
        marcas.append(i)
        pasantes += 1
        n_grupo += 1
    cuenta["pasantes"] = pasantes

    # Callejones techados: tramos de una sola arista, con casa de los dos lados
    def en_casa(x, z):
        for c in casas.values():
            lx, lz = marco.local(x, z)
            cx, cz = marco.local(c["x"], c["z"])
            hw, hh = _lados(c)
            if abs(lx - cx) <= hw and abs(lz - cz) <= hh:
                return True
        return False
    techados = 0
    callejones = [p for p in piezas if p.get("tipo") == "calle" and p.get("nombre", "").startswith("Callejon")]
    def medio(p):
        return p["x"] + p["puntos"][1][0] / 2, p["z"] + p["puntos"][1][1] / 2
    for p in sorted(callejones, key=lambda p: _dist(medio(p), spawn)):
        if techados >= ABANDONADAS["techados"]:
            break
        dx, dz = p["puntos"][1]
        largo = math.hypot(dx, dz)
        if largo < 3.0 + 2 * TECHADO_ESQUINA or largo > max(pu, pv) * 1.1:
            continue
        mx, mz = medio(p)
        ux, uz = dx / largo, dz / largo
        lado = p["ancho"] / 2 + 1.0
        if not libre(mx, mz) or not (en_casa(mx - uz * lado, mz + ux * lado) and en_casa(mx + uz * lado, mz - ux * lado)):
            continue
        nombre = "Techado_%d" % techados
        rot = math.atan2(-dz, dx)
        # El tramo va de esquina a esquina; en las esquinas cruzan o dan vuelta los otros callejones,
        # asi que el techo y sus marcos se quedan entre las fachadas
        largo -= 2 * TECHADO_ESQUINA
        piezas.append({"nombre": nombre, "tipo": "techo_callejon", "favela": True, "x": round(mx, 2), "z": round(mz, 2),
                       "rot": round(rot, 4), "largo": round(largo, 2), "ancho": round(p["ancho"], 2)})
        # Sin toldo sobre la losa
        piezas[:] = [t for t in piezas if not (t.get("tipo") == "toldo" and _dist((t["x"], t["z"]), (mx, mz)) < largo / 2 + 1.0)]
        marcas.append({"nombre": "Foco_" + nombre, "tipo": "foco", "favela": True, "x": round(mx, 2), "z": round(mz, 2),
                       "y": round(PISO - 0.5, 2), "siempre": True, "parpadea": rng.random() < ABANDONADA_PARPADEA})
        marcas.append({"nombre": "Interior_" + nombre, "tipo": "interior", "favela": True, "x": round(mx, 2), "z": round(mz, 2),
                       "rot": round(rot, 4), "tam": [round(largo, 2), round(p["ancho"], 2)], "techos": [nombre], "grupo": n_grupo})
        hechas.append((mx, mz))
        techados += 1
        n_grupo += 1
    cuenta["techados"] = techados


def _tuneles(marco, r, zanjas, nx, nz, pu, pv, piezas, hundidos, marcas, cuenta):
    """Las bocas de los tuneles bajo tres lotes dobles de la banda a nivel (`zanjas`: celda, centro
    (u, v) y (u_a, u_b) del lote), la galeria de cada una hasta una espina que corre de norte a sur,
    y de la espina la galeria principal al oriente con sus ramales: cuartos (dormitorio, garrafones,
    armas), dos tiendas, el pozo de la valvula y la boca final tapada hacia los carcamos. Todo a
    TUNEL_PISO bajo el piso."""
    bocas = [(c, (cu, cv)) for c, (cu, cv), _u in sorted(zanjas, key=lambda z: z[1][1])]
    hondo = -TUNEL_PISO
    espina_u = max(cu for _c, (cu, cv) in bocas) + pu * 0.8
    tramos = []   # (u_a, v_a, u_b, v_b, extras)
    for n, ((a, b), (cu, cv)) in enumerate(bocas):
        # La zanja a lo largo de +u, centrada en el patio; abierta por su lado oriente (lado 1)
        ua, ub = cu - ZANJA_LARGO / 2, cu + ZANJA_LARGO / 2
        pol = [marco.mundo(ua, cv - ZANJA_ANCHO / 2), marco.mundo(ub, cv - ZANJA_ANCHO / 2), marco.mundo(ub, cv + ZANJA_ANCHO / 2), marco.mundo(ua, cv + ZANJA_ANCHO / 2)]
        hundidos.append({"nombre": "Tunel_Boca_%d" % n, "favela": True, "fondo": hondo, "abiertos": [1],
                         "poligono": [[round(x, 2), round(z, 2)] for x, z in pol]})
        xb, zb = marco.mundo(ua, cv)
        piezas.append({"nombre": "Tunel_Bajada_%d" % n, "tipo": "bajada", "favela": True, "x": round(xb, 2), "z": round(zb, 2), "rot": marco.rot,
                       "largo": 5.0, "ancho": ZANJA_ANCHO - 0.2, "fondo": hondo})
        marcas.append({"nombre": "Tunel_Entrada_%d" % n, "tipo": "mision", "favela": True, "x": round(xb, 2), "z": round(zb, 2), "rot": marco.rot})
        # La galeria de la boca a la espina
        tramos.append((ub, cv, espina_u - TUNEL_ANCHO / 2 + 0.05, cv, {}))
    vs = sorted(cv for _c, (cu, cv) in bocas)
    tramos.append((espina_u, vs[0] - TUNEL_ANCHO / 2, espina_u, vs[-1] + TUNEL_ANCHO / 2, {}))
    # La principal: de la espina al oriente, por la v de la boca de en medio, hasta cerca de la muralla
    v_main = vs[len(vs) // 2]
    u_fin = nx * pu - 7.0
    largo_main = u_fin - espina_u
    # Los cuartos a lo largo de la principal, alternando lado
    usos = [("dormitorio", [5.0, 4.0]), ("garrafones", [6.0, 5.0]), ("tienda", [5.0, 4.0]), ("armas", [5.0, 4.0]),
            ("tienda", [5.0, 4.0]), ("dormitorio", [5.0, 4.0]), ("valvula", [6.0, 6.0])]
    n_cuartos = min(len(usos), int(largo_main / 16.0))
    huecos = []
    for i in range(n_cuartos):
        uso, tam = usos[i] if i < n_cuartos - 1 else usos[-1]
        du = espina_u + TUNEL_ANCHO + 8.0 + i * (largo_main - 14.0) / max(1, n_cuartos - 1) * 0.95
        lado = 1 if i % 2 == 0 else -1
        # El cuarto pegado a la galeria por ese lado, con su frente (+Z) hacia la galeria
        cv_cuarto = v_main + lado * (TUNEL_ANCHO / 2 + tam[1] / 2 + 0.3)
        x, z = marco.mundo(du, cv_cuarto)
        rot = round(marco.rot + math.pi, 4) if lado > 0 else marco.rot
        nombre = "Tunel_%s_%d" % (uso.capitalize(), i)
        piezas.append({"nombre": nombre, "tipo": "tunel_cuarto", "favela": True, "x": round(x, 2), "z": round(z, 2), "y": TUNEL_PISO,
                       "rot": rot, "tam": tam, "uso": uso})
        huecos.append([du, 1.4, lado])
        # Un pasito de galeria entre el hueco y la puerta del cuarto
        xp, zp = marco.mundo(du, v_main + lado * (TUNEL_ANCHO / 2 + 0.15))
        piezas.append({"nombre": nombre + "_Paso", "tipo": "tunel", "favela": True, "x": round(xp, 2), "z": round(zp, 2), "y": TUNEL_PISO,
                       "rot": marco.rot_v, "largo": 0.6, "ancho": 1.4})
        if uso == "tienda":
            # Las tiendas del tunel, en orden: su giro abre su interior (scenes/interiores/tunel_*.tscn)
            giro, texto = TIENDAS_TUNEL[cuenta["tiendas_tunel"] % len(TIENDAS_TUNEL)]
            cuenta["tiendas_tunel"] += 1
            xd, zd = marco.mundo(du, v_main + lado * (TUNEL_ANCHO / 2 + 0.9))
            marcas.append({"nombre": "Puerta_%s" % nombre, "tipo": "puerta", "favela": True, "giro": giro, "texto": texto,
                           "x": round(xd, 2), "z": round(zd, 2), "y": TUNEL_PISO, "rot": round(marco.rot + (math.pi if lado > 0 else 0.0), 4)})
        elif uso == "valvula":
            marcas.append({"nombre": "Valvula", "tipo": "mision", "favela": True, "x": round(x, 2), "z": round(z, 2), "y": TUNEL_PISO, "rot": rot})
            marcas.append({"nombre": "Letrero_Valvula", "tipo": "letrero", "favela": True, "texto": "La toma. Ni la toques.",
                           "x": round(x, 2), "z": round(z, 2), "y": TUNEL_PISO + 1.9, "rot": rot})
        elif uso == "garrafones":
            marcas.append({"nombre": "Garrafones_Tunel", "tipo": "mision", "favela": True, "x": round(x, 2), "z": round(z, 2), "y": TUNEL_PISO, "rot": rot})
    tramos.append((espina_u + TUNEL_ANCHO / 2 - 0.05, v_main, u_fin, v_main, {"huecos": huecos, "cerrado": "b"}))
    # La boca final, tapada: una marca y su letrero
    xf, zf = marco.mundo(u_fin - 1.2, v_main)
    marcas.append({"nombre": "Boca_Tuneles", "tipo": "mision", "favela": True, "x": round(xf, 2), "z": round(zf, 2), "y": TUNEL_PISO, "rot": round(marco.rot + math.pi, 4)})
    marcas.append({"nombre": "Letrero_Tuneles", "tipo": "letrero", "favela": True, "texto": "A los cárcamos. No pasar",
                   "x": round(xf, 2), "z": round(zf, 2), "y": TUNEL_PISO + 1.8, "rot": round(marco.rot + math.pi, 4)})
    for n, (ua, va, ub, vb, extra) in enumerate(tramos):
        largo = math.hypot(ub - ua, vb - va)
        cu, cv = (ua + ub) / 2, (va + vb) / 2
        x, z = marco.mundo(cu, cv)
        a_lo_largo_u = abs(ub - ua) > abs(vb - va)
        pieza = {"nombre": "Tunel_%d" % n, "tipo": "tunel", "favela": True, "x": round(x, 2), "z": round(z, 2), "y": TUNEL_PISO,
                 "rot": marco.rot if a_lo_largo_u else marco.rot_v, "largo": round(largo, 2), "ancho": TUNEL_ANCHO}
        if "huecos" in extra:
            pieza["huecos"] = [[round(hu - cu, 2), hw, lado] for hu, hw, lado in extra["huecos"]]
        if "cerrado" in extra:
            pieza["cerrado"] = extra["cerrado"]
        # La espina (a lo largo de v) lleva huecos donde entran las galerias de las bocas y sale la principal
        if not a_lo_largo_u:
            # (su +Z local es -u: las galerias de las bocas llegan por +Z, la principal sale por -Z)
            pieza["huecos"] = [[round(cvb - cv, 2), TUNEL_ANCHO, 1] for _c, (_cu, cvb) in bocas] + [[round(v_main - cv, 2), TUNEL_ANCHO, -1]]
        piezas.append(pieza)
        cuenta["tuneles"] += 1



# --- Lo nuevo de la favela (JJ, 2026-11-13): Plaza del Tinaco, claros, tiendas, escaleras, puentes,
# toldos y lineas de gente. Todo se elige DESPUES de _laberinto, con RNG aparte, para no volver a
# sortear el laberinto; solo se quitan/anaden casas y piezas.

def _mundo_local(casa, lx, lz):
    c, s = math.cos(casa["rot"]), math.sin(casa["rot"])
    return casa["x"] + lx * c + lz * s, casa["z"] - lx * s + lz * c


def _girar(casa, v):
    """Un vector local de la casa al mundo, con el mismo giro que _mundo_local."""
    c, s = math.cos(casa["rot"]), math.sin(casa["rot"])
    return v[0] * c + v[1] * s, -v[0] * s + v[1] * c


def _celda_simple(casa, pu, pv):
    xs = [p[0] for p in casa["puntos"]]
    zs = [p[1] for p in casa["puntos"]]
    return (max(xs) - min(xs)) <= pu * 0.95 and (max(zs) - min(zs)) <= pv * 0.95


def _lados(casa):
    xs = [p[0] for p in casa["puntos"]]
    zs = [p[1] for p in casa["puntos"]]
    return (max(xs) - min(xs)) / 2.0, (max(zs) - min(zs)) / 2.0


def _frente(casa, pu, pv):
    """(lado, normal local, normal mundo, ancho, fondo) de la fachada de una casa."""
    hw, hh = _lados(casa)
    l = "NESO"[int(casa.get("frente", 0)) % 4]
    normal = {"N": (0.0, -1.0), "E": (1.0, 0.0), "S": (0.0, 1.0), "O": (-1.0, 0.0)}[l]
    nx, nz = _girar(casa, normal)
    if l in "NS":
        ancho, fondo = hw * 2.0, hh * 2.0
    else:
        ancho, fondo = hh * 2.0, hw * 2.0
    return l, normal, (nx, nz), ancho, fondo


def _en_patio(x, z, piezas, margen=1.2):
    """True si el punto cae dentro (o casi) de un lote/patio abierto."""
    for p in piezas:
        if p.get("tipo") not in ("lote", "patio"):
            continue
        w, h = p.get("tam", [0.0, 0.0])
        if w <= 0.0 or h <= 0.0:
            continue
        c, s = math.cos(p.get("rot", 0.0)), math.sin(p.get("rot", 0.0))
        dx, dz = x - p["x"], z - p["z"]
        lx = dx * c - dz * s
        lz = dx * s + dz * c
        if abs(lx) <= w / 2.0 + margen and abs(lz) <= h / 2.0 + margen:
            return True
    return False


# Interiores._salir te deja 3 m delante de la fachada (la flecha a 0.8 m y 2.2 m mas): a esa
# distancia, mas el radio del jugador, tiene que haber patio y no la casa de enfrente
SALIDA_TIENDA = 3.6


def _lado_a_patio(casa, piezas):
    """(lado, normal local, normal mundo, ancho, fondo, ancho de frente) del lado de la casa que
    da a un patio o claro abierto (pegado o del otro lado del callejon), o None. Lo que cuenta es
    que el punto donde te deja la salida de la tienda caiga en el patio."""
    hw, hh = _lados(casa)
    for lado, lx, lz in (("N", 0.0, -hh), ("E", hw, 0.0), ("S", 0.0, hh), ("O", -hw, 0.0)):
        ancho, fondo = (hw * 2.0, hh * 2.0) if lado in "NS" else (hh * 2.0, hw * 2.0)
        if ancho < 2.0:
            continue
        normal = {"N": (0.0, -1.0), "E": (1.0, 0.0), "S": (0.0, 1.0), "O": (-1.0, 0.0)}[lado]
        nx, nz = _girar(casa, normal)
        mx, mz = _mundo_local(casa, lx, lz)
        if _en_patio(mx + nx * SALIDA_TIENDA, mz + nz * SALIDA_TIENDA, piezas, margen=0.0):
            return lado, normal, (nx, nz), ancho, fondo, ancho
    return None


def _quitar_casas(casas, piezas, celdas):
    """Quita las casas del bloque y lo que colgaba de ellas (tablones y escaleras) para que el
    claro no deje una tabla o una escalera flotando."""
    casas_quitadas = []
    for c in celdas:
        casa = casas.pop(c, None)
        if casa is not None:
            casas_quitadas.append(casa)
            piezas[:] = [p for p in piezas if p is not casa]
    if not casas_quitadas:
        return
    xs = [c["x"] for c in casas_quitadas]
    zs = [c["z"] for c in casas_quitadas]
    x0, x1 = min(xs) - 2.0, max(xs) + 2.0
    z0, z1 = min(zs) - 2.0, max(zs) + 2.0
    piezas[:] = [p for p in piezas
                 if not (p.get("tipo") in ("tablon", "escalera")
                         and x0 <= p.get("x", 0.0) <= x1 and z0 <= p.get("z", 0.0) <= z1)]


def _casa_bbox(casa):
    c, s = math.cos(casa["rot"]), math.sin(casa["rot"])
    xs, zs = [], []
    for lx, lz in casa["puntos"]:
        xs.append(casa["x"] + lx * c + lz * s)
        zs.append(casa["z"] - lx * s + lz * c)
    return min(xs), min(zs), max(xs), max(zs)


def _quitar_casas_bb(casas, piezas, bloque, marco, pu, pv):
    """Quita tambien casas dobles cuyo cuerpo se mete al claro aunque su centro no sea una de las
    celdas (antes dejaban una casa encima del claro y el cuadro grande no se veia)."""
    a0 = min(a for a, _b in bloque); a1 = max(a for a, _b in bloque) + 1
    b0 = min(b for _a, b in bloque); b1 = max(b for _a, b in bloque) + 1
    puntos = [marco.mundo(a0 * pu, b0 * pv), marco.mundo(a1 * pu, b0 * pv),
              marco.mundo(a1 * pu, b1 * pv), marco.mundo(a0 * pu, b1 * pv)]
    bx0, bx1 = min(p[0] for p in puntos), max(p[0] for p in puntos)
    bz0, bz1 = min(p[1] for p in puntos), max(p[1] for p in puntos)
    for cell, casa in list(casas.items()):
        hx0, hz0, hx1, hz1 = _casa_bbox(casa)
        if hx1 < bx0 - 0.2 or hx0 > bx1 + 0.2 or hz1 < bz0 - 0.2 or hz0 > bz1 + 0.2:
            continue
        casas.pop(cell, None)
        piezas[:] = [p for p in piezas if p is not casa]


def _dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def _centro_reserva(r):
    pts = r["puntos"]
    return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))


def _poste_luz(piezas, marcas, cuenta, x, z, y, nombre):
    piezas.append({"nombre": nombre, "tipo": "poste_luz", "favela": True, "x": round(x, 2), "z": round(z, 2),
                   "rot": 0.0, "alto": 3.5})
    marcas.append({"nombre": nombre + "_Foco", "tipo": "foco", "favela": True,
                   "x": round(x, 2), "z": round(z, 2), "y": round(y + 3.3, 2)})
    cuenta["postes"] += 1


def _lote(piezas, nombre, x, z, rot, tam, variante, extra=None):
    p = {"nombre": nombre, "tipo": "lote", "favela": True, "x": round(x, 2), "z": round(z, 2), "rot": rot,
         "tam": [round(tam[0], 2), round(tam[1], 2)], "variante": variante}
    if extra:
        p.update(extra)
    piezas.append(p)
    return p


def _post_favela(datos, piezas, marcas, casas, celdas, celdas_zanja, marco, banda, alto_de, nx, nz, pu, pv,
                 abiertas, ancho_de, celdas_de, cuenta, op):
    x1, z1, x2, z2 = datos["recorte"]
    centro_mapa = ((x1 + x2) / 2.0, (z1 + z2) / 2.0)
    tinaco_centro = None
    grandes_centros = []
    # Lo que no debe quedar pegado a una tienda o a un claro
    protegidos = []
    for r in datos.get("reservas", []):
        if r.get("nombre") != "Bodega_Agua":
            protegidos.append(_centro_reserva(r))
    for m in datos.get("marcas", []):
        if m.get("tipo") in ("spawn", "paso", "Tunel_Entrada"):
            protegidos.append((m["x"], m["z"]))

    def libre_de(casa, cerca):
        p = (casa["x"], casa["z"])
        return all(_dist(p, q) >= cerca for q in protegidos)

    def frente_abierto(cell, casa):
        """La puerta da a un callejon abierto, no a una casa ni a un lote cerrado."""
        a, b = cell
        lado = "NESO"[int(casa.get("frente", 0)) % 4]
        borde = {"N": ((a, b), "h"), "E": ((a + 1, b), "v"),
                 "S": ((a, b + 1), "h"), "O": ((a, b), "v")}[lado]
        return ancho_de.get(borde, 0.0) if borde in abiertas else 0.0

    # 1. Plaza del Tinaco: bloque 3x3 de casas simples de un piso, lo mas cerca del centro.
    libres = set(celdas)
    mejor = None
    for a in range(nx - 2):
        for b in range(nz - 2):
            if any(banda(a + i) != banda(a) for i in range(3)):
                continue
            bloque = [(a + i, b + j) for i in range(3) for j in range(3)]
            if any(c not in libres or c in celdas_zanja for c in bloque):
                continue
            cx, cz = marco.mundo((a + 1.5) * pu, (b + 1.5) * pv)
            d = _dist((cx, cz), centro_mapa)
            if mejor is None or d < mejor[0]:
                mejor = (d, a, b, bloque, cx, cz)
    if mejor:
        _d, a, b, bloque, cx, cz = mejor
        _quitar_casas(casas, piezas, bloque)
        _quitar_casas_bb(casas, piezas, bloque, marco, pu, pv)
        libres.difference_update(bloque)
        y = alto_de(a)
        _lote(piezas, "Plaza_Tinaco", cx, cz, marco.rot, (3 * pu - 0.3, 3 * pv - 0.3), "tinaco",
              {"claro": True, "tinaco": True, "sin_piso": True})
        marcas.append({"nombre": "Tinaco_Favela", "tipo": "tinaco", "favela": True,
                       "x": round(cx, 2), "z": round(cz, 2), "y": round(y + 0.03, 2),
                       "litros": TINACO_LITROS, "sin_virgen": True, "sin_defensa": True})
        # Poste en una esquina del claro, no encima del tinaco
        px, pz = marco.mundo((a + 0.35) * pu, (b + 0.35) * pv)
        _poste_luz(piezas, marcas, cuenta, px, pz, y, "Poste_Tinaco")
        cuenta["tinacos"] += 1
        cuenta["claros"] += 1
        protegidos.append((cx, cz))
        tinaco_centro = (cx, cz, y)

    # 2. Tres claros grandes 3x3, repartidos; el del tinaco ya es el cuarto grande.
    rng_g = random.Random(int(op.get("semilla", 7)) + 106)
    candidatos_g = []
    for a in range(nx - 2):
        for b in range(nz - 2):
            if any(banda(a + i) != banda(a) for i in range(3)):
                continue
            bloque = [(a + i, b + j) for i in range(3) for j in range(3)]
            if any(c not in libres or c in celdas_zanja for c in bloque):
                continue
            cx, cz = marco.mundo((a + 1.5) * pu, (b + 1.5) * pv)
            if not all(_dist((cx, cz), q) >= CLAROS_GRANDES_SEPARACION for q in protegidos):
                continue
            candidatos_g.append((a, b, bloque, cx, cz))
    rng_g.shuffle(candidatos_g)
    grandes = []
    for (a, b, bloque, cx, cz) in candidatos_g:
        if len(grandes) >= CLAROS_GRANDES:
            break
        if all(_dist((cx, cz), (q[3], q[4])) >= CLAROS_GRANDES_SEPARACION for q in grandes):
            grandes.append((a, b, bloque, cx, cz))
    variantes_g = ["plaza", "plaza", "plaza"]
    for i, (a, b, bloque, cx, cz) in enumerate(grandes):
        _quitar_casas(casas, piezas, bloque)
        _quitar_casas_bb(casas, piezas, bloque, marco, pu, pv)
        libres.difference_update(bloque)
        y = alto_de(a)
        _lote(piezas, "Claro_Grande_%d" % i, cx, cz, marco.rot, (3 * pu - 0.3, 3 * pv - 0.3),
              variantes_g[i % len(variantes_g)], {"claro": True, "grande": True})
        px, pz = marco.mundo(a * pu + 1.2, b * pv + 1.2)
        _poste_luz(piezas, marcas, cuenta, px, pz, y, "Poste_Grande_%d" % i)
        protegidos.append((cx, cz))
        grandes_centros.append((cx, cz, y))
        cuenta["claros"] += 1
        cuenta["grandes"] += 1

    # 3. Cuatro claros 2x2, lejos del tinaco, de los grandes y entre si.
    claros = []
    candidatos = []
    for a in range(nx - 1):
        for b in range(nz - 1):
            if any(banda(a + i) != banda(a) for i in range(2)):
                continue
            bloque = [(a + i, b + j) for i in range(2) for j in range(2)]
            if any(c not in libres or c in celdas_zanja for c in bloque):
                continue
            cx, cz = marco.mundo((a + 1.0) * pu, (b + 1.0) * pv)
            if not all(_dist((cx, cz), q) >= 20.0 for q in protegidos):
                continue
            candidatos.append((a, b, bloque, cx, cz))
    rng = random.Random(int(op.get("semilla", 7)) + 102)
    rng.shuffle(candidatos)
    separacion = CLAROS_SEPARACION
    for separacion in (CLAROS_SEPARACION, 30.0, 22.0):
        claros = []
        for (a, b, celdas, cx, cz) in candidatos:
            if len(claros) >= CLAROS_EXTRA:
                break
            if all(_dist((cx, cz), (q[3], q[4])) >= separacion for q in claros):
                claros.append((a, b, celdas, cx, cz))
        if len(claros) >= CLAROS_EXTRA:
            break
    variantes = ["baldio", "baldio", "baldio", "baldio"]
    for i, (a, b, bloque, cx, cz) in enumerate(claros[:CLAROS_EXTRA]):
        _quitar_casas(casas, piezas, bloque)
        _quitar_casas_bb(casas, piezas, bloque, marco, pu, pv)
        libres.difference_update(bloque)
        y = alto_de(a)
        _lote(piezas, "Claro_%d" % i, cx, cz, marco.rot, (2 * pu - 0.3, 2 * pv - 0.3), variantes[i % len(variantes)],
              {"claro": True})
        px, pz = marco.mundo(a * pu + 1.2, b * pv + 1.2)
        _poste_luz(piezas, marcas, cuenta, px, pz, y, "Poste_Claro_%d" % i)
        protegidos.append((cx, cz))
        cuenta["claros"] += 1

    # 3. Tiendas de favela: una por giro, repartidas, todas en una casa que da directamente a un
    # patio, plazuela o claro (JJ, 2026-11-13): con la puerta a un callejon se atoraba uno al
    # entrar y al salir. La Farmacia La Bendicion va primero.
    candidatos = []
    for cell, casa in list(casas.items()):
        if casa.get("local") or casa.get("pisos") != 1:
            continue
        if not _celda_simple(casa, pu, pv):
            continue
        if cell in celdas_zanja or not libre_de(casa, 20.0):
            continue
        info = _lado_a_patio(casa, piezas)
        if info is not None and info[3] >= 2.0:
            candidatos.append((cell, casa, info))
    rng = random.Random(int(op.get("semilla", 7)) + 101)
    rng.shuffle(candidatos)
    tiendas = []
    for separacion in (TIENDAS_SEPARACION, 28.0, 22.0, 18.0, 12.0):
        tiendas = []
        for cell, casa, info in candidatos:
            if len(tiendas) >= len(TIENDAS_FAVELA):
                break
            if all(_dist((casa["x"], casa["z"]), (t[1]["x"], t[1]["z"])) >= separacion for t in tiendas):
                tiendas.append((cell, casa, info))
        if len(tiendas) >= len(TIENDAS_FAVELA):
            break
    if len(tiendas) < len(TIENDAS_FAVELA):
        print("favela: solo %d casas de tienda dan a un patio (faltan %d giros)" % (len(tiendas), len(TIENDAS_FAVELA) - len(tiendas)))
    giros = [("farmacia", "Farmacia La Bendición")] + [g for g in TIENDAS_FAVELA if g[0] != "farmacia"]
    for i, (cell, casa, info) in enumerate(tiendas[:len(TIENDAS_FAVELA)]):
        giro, nombre = giros[i]
        a, b = cell
        y = alto_de(a)
        lado, normal_local, normal, ancho, fondo, frente_ancho = info
        local_frente = "NESO".index(lado)
        rot = math.atan2(normal[0], normal[1])
        # La casa local sigue en casas.json y en el minimapa, pero colonia.py no la dibuja
        local = dict(casa)
        local["local"] = True
        local["tienda"] = True
        local["favela"] = True
        local["detalles"] = True
        local["frente"] = local_frente
        local.pop("grupo", None)
        piezas[:] = [p for p in piezas if p is not casa]
        piezas.append(local)
        casas[cell] = local
        datos.setdefault("negocios", []).append({
            "tipo": giro, "giro": giro, "nombre": nombre,
            "x": round(casa["x"], 2), "z": round(casa["z"], 2), "y": round(y, 2),
            "rotacion_y": round(rot, 4), "ancho": round(ancho, 2), "fondo": round(fondo, 2), "pisos": 1,
            "interactivo": True, "aire_libre": False, "origen": "Favela_%s" % giro,
            "ajustado": True, "favela": True, "sin_gente": True,
            "puerta_transitable": True, "frente_lado": lado,
            "frente_ancho": round(frente_ancho, 2)})
        # La flecha va 0.8 m delante del centro de la fachada
        hw, hh = _lados(casa)
        fx, fz = {"N": (0.0, -hh), "E": (hw, 0.0), "S": (0.0, hh), "O": (-hw, 0.0)}[lado]
        mx, mz = _mundo_local(casa, fx, fz)
        mx += normal[0] * 0.8
        mz += normal[1] * 0.8
        marcas.append({"nombre": "Puerta_%s" % giro, "tipo": "puerta", "favela": True, "local": True,
                       "giro": giro, "texto": nombre, "x": round(mx, 2), "z": round(mz, 2),
                       "y": round(y, 2), "rot": round(rot, 4)})
        protegidos.append((casa["x"], casa["z"]))
        cuenta["tiendas"] += 1

    # 3b. Lo que se cruza por dentro
    spawn = next(((m["x"], m["z"]) for m in datos.get("marcas", []) if m.get("tipo") == "spawn"), centro_mapa)
    _abandonadas(piezas, marcas, casas, abiertas, ancho_de, marco, pu, pv, protegidos, spawn, cuenta, op)

    # 4. Escaleras extra: 2 de dos pisos (fachada larga) y 2 de un piso.
    rng = random.Random(int(op.get("semilla", 7)) + 103)
    # La ruta de techos se garantiza en la componente mas grande de casas de dos pisos: las
    # escaleras se ponen en esa componente y todos sus tramos llevan tablon/puente.
    dos_pisos = {cell for cell, casa in casas.items() if not casa.get("local") and casa.get("pisos") == 2}
    componente_grande = set()
    vistos = set()
    for cell in dos_pisos:
        if cell in vistos:
            continue
        comp = set()
        cola = [cell]
        vistos.add(cell)
        while cola:
            act = cola.pop()
            comp.add(act)
            for e in abiertas:
                if act not in celdas_de(e):
                    continue
                for vecino in celdas_de(e):
                    if vecino in dos_pisos and vecino not in vistos:
                        vistos.add(vecino)
                        cola.append(vecino)
        if len(comp) > len(componente_grande):
            componente_grande = comp
    hechas = []
    existentes = [(p["x"], p["z"]) for p in piezas if p["tipo"] == "escalera"]
    tablones_previos = [p for p in piezas if p.get("tipo") == "tablon"]
    def tablones_de(casa):
        """Los tablones que salen de la azotea de esta casa: su centro queda en el callejon
        pegado a una de sus fachadas."""
        hw, hh = _lados(casa)
        c, s = math.cos(casa["rot"]), math.sin(casa["rot"])
        de = []
        for t in piezas:
            if t.get("tipo") != "tablon":
                continue
            dx, dz = t["x"] - casa["x"], t["z"] - casa["z"]
            lx, lz = dx * c - dz * s, dx * s + dz * c
            if abs(lx) <= hw + 2.0 and abs(lz) <= hh + 2.0 and (abs(lx) > hw - 0.5 or abs(lz) > hh - 0.5):
                de.append(t)
        return de

    def tiene_tablon(casa):
        return bool(tablones_de(casa))

    def estorba(t, sx, sz, dx, dz, largo):
        """Un tablon encima de la mitad alta de la escalera le pega en la cabeza al subir."""
        rx, rz = t["x"] - sx, t["z"] - sz
        a = rx * dx + rz * dz                 # a lo largo de la escalera
        b = abs(-rx * dz + rz * dx)           # hacia el callejon
        return largo * 0.4 - 1.0 <= a <= largo + 1.2 and b <= 3.0
    for pisos, cuantas in ((2, ESCALERAS_AZOTEA),):
        candidatos = []
        for cell, casa in list(casas.items()):
            if casa.get("local") or casa.get("pisos") != pisos:
                continue
            ancho_calle = frente_abierto(cell, casa)
            if ancho_calle < 2.4:      # la escalera ocupa 1.1 m; deja al menos 1.3 m de paso
                continue
            lado, normal_local, normal, ancho, fondo = _frente(casa, pu, pv)
            alto_e = pisos * PISO + AZOTEA
            largo_e = max(4, round(alto_e / 0.26)) * 0.3 + 0.2
            if ancho < largo_e + 0.6:
                continue
            if pisos == 2 and not tiene_tablon(casa):
                continue
            if any(_dist((casa["x"], casa["z"]), q) < 25.0 for q in existentes + hechas):
                continue
            candidatos.append((cell, casa, lado, normal, ancho, alto_e, largo_e, ancho_calle))
        rng.shuffle(candidatos)
        for (cell, casa, lado, normal, ancho, alto_e, largo_e, ancho_calle) in candidatos:
            if sum(1 for h in hechas if h[2] == pisos) >= cuantas:
                break
            if any(_dist((casa["x"], casa["z"]), h[:2]) < 24.0 for h in hechas):
                continue
            hw, hh = _lados(casa)
            # El extremo de la fachada: la escalera corre hacia el otro extremo y su +Z mira al
            # callejon (normal). Se empieza en el extremo para que no se salga de la fachada.
            # Con rot = atan2(normal) el +x de la escalera es la normal girada -90 grados: en la
            # fachada N corre hacia -x local, en la E hacia -z, en la S hacia +x y en la O hacia +z.
            ex, ez = {"N": (hw, -hh), "E": (hw, hh), "S": (-hw, hh), "O": (-hw, -hh)}[lado]
            sx, sz = _mundo_local(casa, ex, ez)
            sx += normal[0] * 0.12
            sz += normal[1] * 0.12
            rot = math.atan2(normal[0], normal[1])
            dx, dz = math.cos(rot), -math.sin(rot)
            # Sin tablon que le estorbe y con al menos uno que siga desde esa azotea: si no, la
            # escalera sube a un techo sin salida.
            quitar = [t for t in tablones_de(casa) if estorba(t, sx, sz, dx, dz, largo_e)]
            if len(quitar) == len(tablones_de(casa)):
                continue
            piezas.append({"nombre": "Escalera_%s_%d" % (cell, len(hechas)), "tipo": "escalera", "favela": True,
                           "x": round(sx, 2), "z": round(sz, 2), "rot": round(rot, 4),
                           "alto": round(alto_e, 2), "ancho": 1.0, "sentido": 1})
            # El tablon que pasa encima de la escalera le tapa la subida: se quita
            piezas[:] = [t for t in piezas if not any(t is q for q in quitar)]
            hechas.append((casa["x"], casa["z"], pisos, cell, casa, ancho_calle))
            cuenta["escaleras"] += 1

    # 5. Puentes: los 4 tablones mas anchos (1.8-2.3 m de hueco) se ensanchan a 1.1 m y llevan
    # barandales. No hay calles mas anchas en la favela; el resto de tablones se queda como tabla.
    rng = random.Random(int(op.get("semilla", 7)) + 104)
    tablones = [p for p in piezas if p.get("tipo") == "tablon" and float(p.get("largo", 0.0)) - 1.2 >= 1.8]
    rng.shuffle(tablones)
    puentes = []
    for p in tablones:
        if any(_dist((p["x"], p["z"]), q) < 22.0 for q in puentes):
            continue
        p["puente"] = True
        p["ancho"] = PUENTE_ANCHO
        p["nombre"] = "Puente_%d" % len(puentes)
        puentes.append((p["x"], p["z"]))
        cuenta["puentes"] += 1
        if len(puentes) >= PUENTES:
            break

    # 6. Toldos de lona sobre los callejones (uno de cada 3 o 4).
    rng = random.Random(int(op.get("semilla", 7)) + 105)
    colores = ["lona_rojo", "lona_azul", "lona_verde", "lona_amarillo", "lona_rosa", "blanco_cal"]
    for p in [q for q in piezas if q["tipo"] == "calle" and q.get("nombre", "").startswith("Callejon")]:
        if rng.random() > 0.32:
            continue
        ax, az = p["x"], p["z"]
        bx, bz = ax + p["puntos"][1][0], az + p["puntos"][1][1]
        dx, dz = bx - ax, bz - az
        largo_calle = math.hypot(dx, dz)
        if largo_calle < 3.0:
            continue
        largo = min(rng.uniform(*TOLDO_LARGO), largo_calle - 0.8)
        if largo < 1.5:
            continue
        f = rng.uniform(0.3, 0.7)
        x, z = ax + dx * f, az + dz * f
        c1 = rng.choice(colores)
        c2 = rng.choice([c for c in colores if c != c1])
        piezas.append({"nombre": "Toldo_%d" % cuenta["toldos"], "tipo": "toldo", "favela": True,
                       "x": round(x, 2), "z": round(z, 2), "rot": round(math.atan2(-dz, dx), 4),
                       "largo": round(largo, 2), "ancho": round(p["ancho"] + 0.8, 2),
                       "alto": round(rng.uniform(*TOLDO_ALTO), 2), "color": c1, "color2": c2})
        cuenta["toldos"] += 1

    # 7. Lineas de gente por las rampas entre terrazas (sin escalones que los hagan tropezar).
    for p in piezas:
        if p["tipo"] != "rampa":
            continue
        rot = float(p.get("rot", 0.0))
        largo = float(p.get("largo", 1.0))
        ax, az = p["x"], p["z"]
        bx, bz = ax + math.cos(rot) * largo, az - math.sin(rot) * largo
        datos.setdefault("gente", []).append([[round(ax, 2), round(az, 2)], [round(bx, 2), round(bz, 2)]])
    cuenta["tablones"] = sum(1 for p in piezas if p.get("tipo") == "tablon")
    cuenta["puentes"] = sum(1 for p in piezas if p.get("tipo") == "tablon" and p.get("puente"))
    return {"tinaco": tinaco_centro, "grandes": grandes_centros}



def _tuneles_bodega(datos, piezas, hundidos, marcas, cuenta, surcos, marco):
    """Red compacta de tuneles: una bodega subterranea bajo la Plaza del Tinaco, con una puerta
    en cada lado, y una galeria corta desde los tres claros grandes y desde la propia plaza. En vez
    de la espina y la galeria principal largas de antes, todo entra a la bodega; no hay tramos
    rectos vacios y todos los pisos y muros quedan cerrados (no se cae al vacio)."""
    if not surcos:
        return
    tinaco = surcos.get("tinaco")
    grandes = surcos.get("grandes", [])
    if tinaco is None and grandes:
        tinaco = grandes[0]
    if tinaco is None:
        return
    hx, hz, hy = tinaco[0], tinaco[1], tinaco[2]
    hub = (hx, hz)
    by = TUNEL_PISO
    # Bodega con sus cuatro puertas y sus tambos/garrafones
    piezas.append({"nombre": "Tunel_Bodega", "tipo": "bodega_tunel", "favela": True,
                   "x": round(hx, 2), "z": round(hz, 2), "y": by, "rot": 0.0,
                   "tam": [14.0, 12.0], "alto": 3.4})
    cuenta["tuneles"] += 1
    marcas.append({"nombre": "Garrafones_Tunel", "tipo": "mision", "favela": True,
                   "x": round(hx, 2), "z": round(hz, 2), "y": by, "rot": 0.0})
    for i, (fx, fz) in enumerate(((-4.0, -3.0), (4.0, 3.0), (0.0, 0.0))):
        marcas.append({"nombre": "Foco_Bodega_%d" % i, "tipo": "foco", "favela": True,
                       "x": round(hx + fx, 2), "z": round(hz + fz, 2), "y": round(by + 3.0, 2)})
    # Las dos tiendas del tunel son mostradores dentro de la bodega (marcas de puerta)
    marcas.append({"nombre": "Puerta_Tunel_Tienda_2", "tipo": "puerta", "favela": True,
                   "giro": "fayuca_tunel", "texto": "Fayuca del Túnel",
                   "x": round(hx, 2), "z": round(hz - 3.7, 2), "y": by, "rot": 0.0})
    marcas.append({"nombre": "Puerta_Tunel_Tienda_4", "tipo": "puerta", "favela": True,
                   "giro": "armas_tunel", "texto": "Balas y Veladoras",
                   "x": round(hx, 2), "z": round(hz + 3.7, 2), "y": by, "rot": 0.0})
    cuenta["tiendas_tunel"] = 2
    # Bocas: los tres claros grandes y la Plaza del Tinaco (desplazada del tanque)
    bocas = []
    for i, (gx, gz, gy) in enumerate(grandes[:3]):
        dx, dz = hx - gx, hz - gz
        d = math.hypot(dx, dz) or 1.0
        bocas.append((gx + dx / d * 5.0, gz + dz / d * 5.0, gy, "Claro_%d" % i))
    bocas.append((hx + 7.0, hz + 7.0, hy, "Tinaco"))
    for i, (mx, mz, my, nombre) in enumerate(bocas):
        # Puerta de la bodega mas cercana: el eje dominante
        dx, dz = hx - mx, hz - mz
        if abs(dx) >= abs(dz):
            door = (hx + (7.0 if dx > 0 else -7.0), hz)
        else:
            door = (hx, hz + (6.0 if dz > 0 else -6.0))
        ddx, ddz = door[0] - mx, door[1] - mz
        dist = math.hypot(ddx, ddz)
        if dist < 2.5:
            continue
        ux, uz = ddx / dist, ddz / dist
        largo_rampa = min(5.0, max(2.0, dist * 0.4))
        pit = largo_rampa + 1.0
        rot = math.atan2(-uz, ux)
        # Zanja y bajada, con sus muros y barandales; el fondo es el piso del tunel
        px, pz = mx + ux * (pit / 2.0), mz + uz * (pit / 2.0)
        perp = (-uz, ux)
        pol = [(mx - perp[0] * 1.2, mz - perp[1] * 1.2),
               (mx + ux * pit - perp[0] * 1.2, mz + uz * pit - perp[1] * 1.2),
               (mx + ux * pit + perp[0] * 1.2, mz + uz * pit + perp[1] * 1.2),
               (mx + perp[0] * 1.2, mz + perp[1] * 1.2)]
        hundidos.append({"nombre": "Tunel_Boca_%d" % i, "favela": True, "fondo": hondo,
                         "abiertos": [1, 3], "poligono": [[round(x, 2), round(z, 2)] for x, z in pol]})
        piezas.append({"nombre": "Tunel_Bajada_%d" % i, "tipo": "bajada", "favela": True,
                       "x": round(mx, 2), "z": round(mz, 2), "y": round(my, 2), "rot": round(rot, 4),
                       "largo": round(largo_rampa, 2), "ancho": 2.4, "fondo": by})
        marcas.append({"nombre": "Tunel_Entrada_%d" % i, "tipo": "mision", "favela": True,
                       "x": round(mx, 2), "z": round(mz, 2), "y": round(my, 2), "rot": round(rot, 4)})
        # Galeria continua hasta la puerta de la bodega. Su piso y sus muros son los del tunel.
        largo_gal = dist - pit
        if largo_gal > 0.8:
            cx, cz = mx + ux * (pit + largo_gal / 2.0), mz + uz * (pit + largo_gal / 2.0)
            piezas.append({"nombre": "Tunel_Galeria_%d" % i, "tipo": "tunel", "favela": True,
                           "x": round(cx, 2), "z": round(cz, 2), "y": by, "rot": round(rot, 4),
                           "largo": round(largo_gal, 2), "ancho": 2.4})
            cuenta["tuneles"] += 1
        # Un tramo de piso extra bajo la boca: si algo queda abierto, se cae al piso y no al vacio
        piezas.append({"nombre": "Tunel_Piso_%d" % i, "tipo": "caja", "favela": True,
                       "x": round(px, 2), "z": round(pz, 2), "y": round(by - 0.35, 2),
                       "rot": round(rot, 4), "tam": [round(pit + 1.0, 2), 0.25, 3.0],
                       "material": "concreto"})




def _tuneles_mini(datos, piezas, hundidos, marcas, cuenta, surcos, marco):
    """La red subterranea de la favela, toda bajo la Plaza del Tinaco (el patio mas grande): una
    escalera en el borde, un pasillo corto, la bodega central con tambos y garrafones, dos tiendas
    y dos casas. Sustituye la red de tuneles que conectaba los tres claros grandes: ahora hay una
    sola entrada/salida y no se cruza el mapa por abajo."""
    if not surcos or not surcos.get("tinaco"):
        return
    hx, hz, hy = surcos["tinaco"]
    by = TUNEL_PISO
    hondo = -by
    # Bodega central, con una puerta en cada lado
    piezas.append({"nombre": "Tunel_Bodega", "tipo": "bodega_tunel", "favela": True,
                   "x": round(hx, 2), "z": round(hz, 2), "y": by, "rot": 0.0,
                   "tam": [14.0, 12.0], "alto": 3.4})
    cuenta["tuneles"] += 1
    marcas.append({"nombre": "Garrafones_Tunel", "tipo": "mision", "favela": True,
                   "x": round(hx, 2), "z": round(hz, 2), "y": by, "rot": 0.0})
    for i, (fx, fz) in enumerate(((-4.0, -3.0), (4.0, 3.0), (0.0, 0.0))):
        marcas.append({"nombre": "Foco_Bodega_%d" % i, "tipo": "foco", "favela": True,
                       "x": round(hx + fx, 2), "z": round(hz + fz, 2), "y": round(by + 3.0, 2)})
    # Escalera dentro del patio, al poniente del tinaco: baja hacia el oriente, a cielo abierto en
    # su zanja, y en su pie arranca el pasillo (asi la boveda no le queda encima).
    cor_z = hz - 7.2
    largo_esc = 5.5                         # 4.2 m en 5.5 m: unos 37 grados
    pie_x = hx - 4.0                        # la cabecera queda 1.5 m adentro del muro bajo de la plaza
    escalera_x = pie_x - largo_esc
    piezas.append({"nombre": "Tunel_Escalera", "tipo": "bajada", "favela": True,
                   "x": round(escalera_x, 2), "z": round(cor_z, 2), "y": round(hy, 2),
                   "rot": 0.0, "largo": largo_esc, "ancho": 2.4, "fondo": hondo})
    # Mismo sentido (antihorario) que los hundidos de los tuneles viejos: tessellate_polygon
    # solo resta el hueco si el anillo va en ese sentido. Abiertos: el pie (1) y la cabecera (3).
    pol = [(escalera_x - 0.2, cor_z - 1.2), (pie_x, cor_z - 1.2),
           (pie_x, cor_z + 1.2), (escalera_x - 0.2, cor_z + 1.2)]
    hundidos.append({"nombre": "Tunel_Boca", "favela": True, "fondo": hondo,
                     "abiertos": [1, 3], "poligono": [[round(x, 2), round(z, 2)] for x, z in pol]})
    # La frente de ladrillo sobre la boca del pasillo: tapa la tierra entre la boveda y el patio.
    # Va ya dentro del pasillo, donde el piso es plano: sobre la escalera se pegaba la cabeza
    piezas.append({"nombre": "Tunel_Frente", "tipo": "caja", "favela": True,
                   "x": round(pie_x + 0.15, 2), "z": round(cor_z, 2), "y": round(by + TUNEL_ALTO, 2),
                   "rot": 0.0, "tam": [0.3, round(hondo - TUNEL_ALTO + hy, 2), 2.8],
                   "material": "foto_ladrillo_rojo"})
    marcas.append({"nombre": "Tunel_Entrada_0", "tipo": "mision", "favela": True,
                   "x": round(escalera_x, 2), "z": round(cor_z, 2), "y": round(hy, 2), "rot": 0.0})
    marcas.append({"nombre": "Letrero_Tuneles", "tipo": "letrero", "favela": True,
                   "texto": "TÚNELES", "x": round(escalera_x + 0.5, 2), "z": round(cor_z - 1.8, 2),
                   "y": round(hy, 2), "rot": round(math.pi * 0.75, 4)})
    # Pasillo del pie de la escalera a la casa del oriente; su pared sur (+Z) se abre a la puerta
    # norte de la bodega
    cor_b = hx + 7.0
    cor_x = (pie_x + cor_b) / 2.0
    piezas.append({"nombre": "Tunel_Pasillo", "tipo": "tunel", "favela": True,
                   "x": round(cor_x, 2), "z": round(cor_z, 2), "y": by, "rot": 0.0,
                   "largo": round(cor_b - pie_x, 2), "ancho": 2.4, "huecos": [[round(hx - cor_x, 2), 2.8, 1]]})
    cuenta["tuneles"] += 1
    # Casa al final oriente del pasillo
    casa_e = {"nombre": "Tunel_Casa_Este", "tipo": "tunel_cuarto", "favela": True,
              "x": round(hx + 9.0, 2), "z": round(cor_z, 2), "y": by, "rot": round(-math.pi / 2.0, 4),
              "tam": [5.0, 4.0], "alto": 3.2, "uso": "casa"}
    piezas.append(casa_e)
    # Casa al poniente de la bodega (su puerta oeste)
    piezas.append({"nombre": "Tunel_Casa_Oeste", "tipo": "tunel_cuarto", "favela": True,
                   "x": round(hx - 9.0, 2), "z": round(hz, 2), "y": by, "rot": round(math.pi / 2.0, 4),
                   "tam": [5.0, 4.0], "alto": 3.2, "uso": "casa"})
    # Tienda Fayuca al sur de la bodega
    piezas.append({"nombre": "Tunel_Tienda_Fayuca", "tipo": "tunel_cuarto", "favela": True,
                   "x": round(hx, 2), "z": round(hz + 8.0, 2), "y": by, "rot": round(math.pi, 4),
                   "tam": [5.0, 4.0], "alto": 3.2, "uso": "tienda"})
    marcas.append({"nombre": "Puerta_Tunel_Tienda_2", "tipo": "puerta", "favela": True,
                   "giro": "fayuca_tunel", "texto": "Fayuca del Túnel",
                   "x": round(hx, 2), "z": round(hz + 6.0, 2), "y": by, "rot": round(math.pi, 4)})
    # Tienda de armas al oriente de la bodega
    piezas.append({"nombre": "Tunel_Tienda_Armas", "tipo": "tunel_cuarto", "favela": True,
                   "x": round(hx + 9.0, 2), "z": round(hz, 2), "y": by, "rot": round(-math.pi / 2.0, 4),
                   "tam": [5.0, 4.0], "alto": 3.2, "uso": "armas"})
    marcas.append({"nombre": "Puerta_Tunel_Tienda_4", "tipo": "puerta", "favela": True,
                   "giro": "armas_tunel", "texto": "Balas y Veladoras",
                   "x": round(hx + 7.0, 2), "z": round(hz, 2), "y": by, "rot": round(math.pi / 2.0, 4)})
    cuenta["tiendas_tunel"] = 2


if __name__ == "__main__":
    generar(sys.argv[1] if len(sys.argv) > 1 else "la_gotera_favela")
