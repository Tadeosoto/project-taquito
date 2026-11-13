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

PASO = 7.0              # m de la cuadricula: cada celda es un lote
CALLEJON = (1.2, 2.2)   # m de ancho de los callejones
BOCA_ANCHO = 2.2        # m de las bocas al tianguis
LAZOS = 0.10            # que parte de las paredes entre celdas se abre ademas del arbol
PATIO = 0.06            # que parte de las celdas son patio de tendederos
PLAZUELA = 0.04         # ... o plazuela con un puesto de lona (donde cruzan 3 callejones o mas)
DOBLE = 0.25            # que parte de las casas toman dos celdas
BANDAS = [(55.0, 0.0), (115.0, 0.75), (1e9, 1.5)]   # (hasta tantos m del poniente del recorte, alto de la terraza)
PISO = 2.75
AZOTEA = 0.05
TABLON_MAX = 2.3        # m: callejones mas angostos que esto pueden llevar tablon entre azoteas
PINTADAS = ["azul", "verde", "mostaza", "turquesa", "rosa", "lima", "naranja"]
MARGEN = 1.6            # m libres junto a la muralla
# Tuneles (piezas.tunel): el piso de la galeria y la zanja de cada boca
TUNEL_PISO = -4.2
TUNEL_ANCHO = 2.4
ZANJA_LARGO = 6.6       # la bajada (5.0 m a 40 grados) y el descanso
ZANJA_ANCHO = 2.4       # como la galeria, para que la zanja abra justo en ella
TUNELES = 3             # bocas


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
    cuenta = {"casas": 0, "patios": 0, "plazuelas": 0, "callejones": 0, "bocas": 0, "tablones": 0, "escaleras": 0, "escalinatas": 0, "tuneles": 0}
    _laberinto(datos, libre, reservado, u0, v0, W, H, marco, r, paso, callejon, piezas, terrazas, hundidos, marcas, cuenta, op)
    datos["piezas"] += piezas
    datos["terrazas"] = [t for t in datos.get("terrazas", []) if not t.get("favela")] + terrazas
    datos["hundidos"] += hundidos
    datos["marcas"] = [m for m in datos.get("marcas", []) if not m.get("favela")] + marcas
    json.dump(datos, open(ruta, "w", encoding="utf-8"), ensure_ascii=False, indent="\t")
    _compactar(ruta)
    print("favela %s: %s, theta %.3f" % (nombre, cuenta, theta))


def _laberinto(datos, libre, reservado, u0, v0, W, H, marco0, r, paso, callejon, piezas, terrazas, hundidos, marcas, cuenta, op):
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
    # La cuadricula gruesa sobre todo el raster
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
    nodos = [k for k, v in dentro.items() if v]
    if len(nodos) < 2:
        return

    def vecino(a, b, lado):
        da, db = {"E": (1, 0), "O": (-1, 0), "S": (0, 1), "N": (0, -1)}[lado]
        return (a + da, b + db)

    def centro(a, b):
        return (a + 0.5) * pu, (b + 0.5) * pv

    def da_a_reserva(a, b, lado):
        if dentro.get(vecino(a, b, lado)):
            return False
        cu, cv = centro(a, b)
        d = {"E": (pu / 2 + 1.5, 0), "O": (-pu / 2 - 1.5, 0), "S": (0, pv / 2 + 1.5), "N": (0, -pv / 2 - 1.5)}[lado]
        i, j = int(cu + d[0]), int(cv + d[1])
        return 0 <= i < W and 0 <= j < H and reservado[j][i]
    # Las bocas: las marcas "paso" del .json, cada una a la celda dentro mas cercana de la orilla poniente
    bocas = []    # (celda, (u, v) de la marca)
    for m in datos.get("marcas", []):
        if m.get("tipo") != "paso":
            continue
        mu, mv = marco.local(m["x"], m["z"])
        b = min(max(int(mv / pv), 0), nz - 1)
        a = next((a for a in range(nx) if dentro.get((a, b))), None)
        if a is not None:
            bocas.append(((a, b), (mu, mv)))
    # El arbol de callejones: DFS desde la primera boca (o la celda mas al poniente)
    inicio = bocas[0][0] if bocas else min(nodos, key=lambda k: (k[0], abs(k[1] - nz / 2)))
    visitado = {inicio}
    abiertas = set()
    pila = [inicio]
    while pila:
        a, b = pila[-1]
        opciones = [vecino(a, b, l) for l in "ENOS" if dentro.get(vecino(a, b, l)) and vecino(a, b, l) not in visitado]
        if not opciones:
            pila.pop()
            continue
        # Prefiere seguir derecho un poco (callejones largos) pero quiebra seguido
        sig = r.choice(opciones)
        visitado.add(sig)
        abiertas.add(frozenset(((a, b), sig)))
        pila.append(sig)
    for (a, b) in nodos:
        for l in "ES":
            v = vecino(a, b, l)
            if dentro.get(v) and frozenset(((a, b), v)) not in abiertas and r.random() < LAZOS:
                abiertas.add(frozenset(((a, b), v)))
    # Las bandas de terrazas, por columnas de celdas (la distancia al poniente)
    def banda(a):
        du = (a + 0.5) * pu
        for n, (hasta, alto) in enumerate(BANDAS):
            if du < hasta:
                return n
        return len(BANDAS) - 1
    def alto_de(a):
        return BANDAS[banda(a)][1]
    bordes_banda = sorted({a for a in range(1, nx) if banda(a) != banda(a - 1)})
    for n, (hasta, alto) in enumerate(BANDAS):
        if alto <= 0:
            continue
        cols = [a for a in range(nx) if banda(a) == n]
        if not cols:
            continue
        a0, a1 = min(cols), max(cols) + 1
        # La terraza cubre toda la banda hasta la muralla (menos el margen): un rectangulo del marco
        poligono = [marco.mundo(a0 * pu, 0.3), marco.mundo(a1 * pu, 0.3), marco.mundo(a1 * pu, H - 0.3), marco.mundo(a0 * pu, H - 0.3)]
        terrazas.append({"nombre": "Banda_%d_Terraza" % n, "favela": True, "poligono": [[round(x, 2), round(z, 2)] for x, z in poligono], "alto": alto})

    # --- Callejones: tramos rectos lo mas largos posible (menos piezas, menos tendederos) ---
    ancho_par = {}
    def ancho(par):
        if par not in ancho_par:
            ancho_par[par] = round(r.uniform(*callejon), 2)
        return ancho_par[par]
    hechos = set()
    runs = []     # (celda inicial, lado "E"/"S", cuantas celdas avanza, ancho)
    for (a, b) in sorted(nodos, key=lambda k: (k[1], k[0])):
        for l in "ES":
            par = frozenset(((a, b), vecino(a, b, l)))
            if par not in abiertas or par in hechos:
                continue
            w = ancho(par)
            n = 0
            c = (a, b)
            while True:
                sig = vecino(c[0], c[1], l)
                p2 = frozenset((c, sig))
                if p2 not in abiertas or p2 in hechos:
                    break
                # Un tramo no cruza el borde de una banda (ahi va la escalinata): se corta
                if l == "E" and sig[0] in bordes_banda and n > 0:
                    break
                hechos.add(p2)
                ancho_par[p2] = w
                n += 1
                c = sig
                if l == "E" and c[0] in bordes_banda:
                    break
                if r.random() < 0.18:
                    break    # tramos que se quiebran
            if n > 0:
                runs.append(((a, b), l, n, w))
    def mitad(a, b, lado):
        par = frozenset(((a, b), vecino(a, b, lado)))
        return ancho_par[par] / 2 if par in abiertas else 0.0
    for (a, b), l, n, w in runs:
        ua, va = centro(a, b)
        c = (a + n, b) if l == "E" else (a, b + n)
        uc, vc = centro(*c)
        xa, za = marco.mundo(ua, va)
        xc, zc = marco.mundo(uc, vc)
        k = cuenta["callejones"]
        cruza = l == "E" and c[0] in bordes_banda and alto_de(c[0]) != alto_de(a)
        if cruza:
            # Dos piezas: hasta el borde de la banda (a la altura de abajo) y del borde al centro (arriba);
            # colonia._en_terraza sube cada una por el medio de su tramo
            borde_u = c[0] * pu
            xm, zm = marco.mundo(borde_u - 0.02, vc)
            xn, zn = marco.mundo(borde_u + 0.02, vc)
            piezas.append({"nombre": "Callejon_%d" % k, "tipo": "calle", "favela": True, "x": round(xa, 2), "z": round(za, 2),
                           "puntos": [[0.0, 0.0], [round(xm - xa, 2), round(zm - za, 2)]], "ancho": w, "banqueta": 0.0, "material": "empedrado", "real": ""})
            piezas.append({"nombre": "Callejon_%d_b" % k, "tipo": "calle", "favela": True, "x": round(xn, 2), "z": round(zn, 2),
                           "puntos": [[0.0, 0.0], [round(xc - xn, 2), round(zc - zn, 2)]], "ancho": w, "banqueta": 0.0, "material": "empedrado", "real": ""})
        else:
            piezas.append({"nombre": "Callejon_%d" % k, "tipo": "calle", "favela": True, "x": round(xa, 2), "z": round(za, 2),
                           "puntos": [[0.0, 0.0], [round(xc - xa, 2), round(zc - za, 2)]], "ancho": w, "banqueta": 0.0,
                           "material": "empedrado", "real": ""})
        cuenta["callejones"] += 1
        if cruza:
            # La escalinata justo en el borde, subiendo hacia la banda alta (+u)
            sube = alto_de(c[0]) - alto_de(a)
            largo = 1.0 if abs(sube) <= 0.8 else 2.0
            borde_u = c[0] * pu
            if sube > 0:
                xe, ze = marco.mundo(borde_u - largo, vc)
                rot = marco.rot
            else:
                xe, ze = marco.mundo(borde_u + largo, vc)
                rot = round(marco.rot + math.pi, 4)
            piezas.append({"nombre": "Escalinata_%d" % k, "tipo": "escalinata", "favela": True, "x": round(xe, 2), "z": round(ze, 2),
                           "y": min(alto_de(a), alto_de(c[0])), "rot": rot, "largo": largo, "ancho": round(w - 0.1, 2), "alto": abs(sube)})
            cuenta["escalinatas"] += 1
    # Las bocas al tianguis: de la orilla poniente del recorte a su celda
    for (a, b), (mu, mv) in bocas:
        ua, va = centro(a, b)
        xa, za = marco.mundo(ua, va)
        xb, zb = marco.mundo(-1.0, va)
        piezas.append({"nombre": "Boca_%d" % cuenta["bocas"], "tipo": "calle", "favela": True, "x": round(xa, 2), "z": round(za, 2),
                       "puntos": [[0.0, 0.0], [round(xb - xa, 2), round(zb - za, 2)]], "ancho": BOCA_ANCHO, "banqueta": 0.0,
                       "material": "empedrado", "real": ""})
        cuenta["bocas"] += 1
    boca_celdas = {c for c, _m in bocas}
    # Bocas a las reservas (la plaza de los Gotera, la casa de don Nemesio): una de cada tres celdas que dan a una
    entradas_reserva = {}
    n_res = 0
    for (a, b) in sorted(nodos, key=lambda k: (k[1], k[0])):
        for l in "NSEO":
            if da_a_reserva(a, b, l):
                n_res += 1
                if n_res % 3 != 1:
                    continue
                ua, va = centro(a, b)
                d = {"E": (pu / 2 + 2.0, 0), "O": (-pu / 2 - 2.0, 0), "S": (0, pv / 2 + 2.0), "N": (0, -pv / 2 - 2.0)}[l]
                xa, za = marco.mundo(ua, va)
                xb, zb = marco.mundo(ua + d[0], va + d[1])
                w = round(r.uniform(1.6, 2.2), 2)
                piezas.append({"nombre": "Entrada_%d" % n_res, "tipo": "calle", "favela": True, "x": round(xa, 2), "z": round(za, 2),
                               "puntos": [[0.0, 0.0], [round(xb - xa, 2), round(zb - za, 2)]], "ancho": w, "banqueta": 0.0,
                               "material": "empedrado", "real": ""})
                entradas_reserva[(a, b)] = (l, w)
                cuenta["bocas"] += 1

    # --- Lotes: casas, patios, plazuelas ---
    usada = set()
    patios = []
    casas = {}
    for (a, b) in sorted(nodos, key=lambda k: (k[1], k[0])):
        if (a, b) in usada:
            continue
        usada.add((a, b))
        frentes = [l for l in "NSEO" if mitad(a, b, l) > 0]
        if (a, b) in boca_celdas:
            frentes.append("O")
        cruces = len(frentes)
        dado = r.random()
        tipo = "casa"
        if cruces >= 3 and dado < PLAZUELA * 6:
            tipo = "plazuela"
        elif dado < PATIO and frentes and (a, b) not in boca_celdas:
            tipo = "patio"
        u_a = a * pu + mitad(a, b, "O")
        u_b = (a + 1) * pu - mitad(a, b, "E")
        v_a = b * pv + mitad(a, b, "N")
        v_b = (b + 1) * pv - mitad(a, b, "S")
        if (a, b) in boca_celdas:
            # La boca pasa por la mitad de la celda: la casa queda en una de las dos mitades
            if r.random() < 0.5:
                v_b = b * pv + pv / 2 - BOCA_ANCHO / 2
            else:
                v_a = b * pv + pv / 2 + BOCA_ANCHO / 2
            tipo = "casa"
        elif (a, b) in entradas_reserva:
            l, w = entradas_reserva[(a, b)]
            if l in "EO":
                if r.random() < 0.5:
                    v_b = b * pv + pv / 2 - w / 2
                else:
                    v_a = b * pv + pv / 2 + w / 2
            else:
                if r.random() < 0.5:
                    u_b = a * pu + pu / 2 - w / 2
                else:
                    u_a = a * pu + pu / 2 + w / 2
            tipo = "casa"
            frentes.append(l)
        if tipo == "casa" and r.random() < DOBLE:
            v = (a + 1, b)
            if dentro.get(v) and v not in usada and mitad(a, b, "E") == 0 and v not in boca_celdas and banda(a + 1) == banda(a):
                usada.add(v)
                u_b = (a + 2) * pu - mitad(a + 1, b, "E")
                v_a = max(v_a, b * pv + mitad(a + 1, b, "N"))
                v_b = min(v_b, (b + 1) * pv - mitad(a + 1, b, "S"))
                frentes += [l for l in "NSE" if mitad(a + 1, b, l) > 0]
        cu, cv = (u_a + u_b) / 2, (v_a + v_b) / 2
        hw, hh = (u_b - u_a) / 2, (v_b - v_a) / 2
        if hw < 1.4 or hh < 1.4:
            continue
        x, z = marco.mundo(cu, cv)
        nombre = "%d_%d" % (a, b)
        if tipo == "patio":
            patios.append(((a, b), (cu, cv)))
            piezas.append({"nombre": "Patio_" + nombre, "tipo": "patio", "favela": True, "x": round(x, 2), "z": round(z, 2), "rot": marco.rot,
                           "tam": [round(hw * 2 - 0.3, 2), round(hh * 2 - 0.3, 2)]})
            cuenta["patios"] += 1
            continue
        if tipo == "plazuela":
            piezas.append({"nombre": "Plazuela_" + nombre, "tipo": "lote", "favela": True, "x": round(x, 2), "z": round(z, 2), "rot": marco.rot,
                           "tam": [round(hw * 2, 2), round(hh * 2, 2)], "variante": "fonda" if r.random() < 0.6 else "baldio"})
            cuenta["plazuelas"] += 1
            continue
        # Huella relativa: 0 (-hw,-hh) 1 (hw,-hh) 2 (hw,hh) 3 (-hw,hh): lado 0 = N (v chica), 1 = E, 2 = S, 3 = O
        lados = {"N": 0, "E": 1, "S": 2, "O": 3}
        frente = lados[r.choice(frentes)] if frentes else lados[r.choice("NSEO")]
        dado = r.random()
        pisos = 1 if dado < 0.25 else 2 if dado < 0.85 else 3
        obra = None
        if pisos == 3:
            pisos, obra = 2, "castillos"      # el tercero, solo castillos
        elif r.random() < 0.25:
            obra = "castillos" if r.random() < 0.7 else "losa"
        casa = {"nombre": "Casa_" + nombre, "tipo": "casa", "favela": True, "grupo": "Favela_%d_%d" % (a // 6, b // 6), "x": round(x, 2), "z": round(z, 2), "rot": marco.rot,
                "puntos": [[round(-hw, 2), round(-hh, 2)], [round(hw, 2), round(-hh, 2)], [round(hw, 2), round(hh, 2)], [round(-hw, 2), round(hh, 2)]],
                "pisos": pisos, "frente": frente, "desgaste": round(r.uniform(0.4, 0.8), 2), "tapado": 0.3, "detalles": False}
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
        # Escalera a la azotea en algunas casas de dos pisos (las rutas de arriba), pegada a la fachada del frente
        if pisos == 2 and r.random() < 0.1:
            l = "NESO"[frente]
            normal = {"N": (0, -1), "S": (0, 1), "E": (1, 0), "O": (-1, 0)}[l]
            largo_f = (u_b - u_a) if l in "NS" else (v_b - v_a)
            if largo_f < 4.0:
                continue
            if l == "N":
                pu0, pv0 = u_a + 0.3, v_a - 0.12
            elif l == "S":
                pu0, pv0 = u_b - 0.3, v_b + 0.12
            elif l == "E":
                pu0, pv0 = u_b + 0.12, v_a + 0.3
            else:
                pu0, pv0 = u_a - 0.12, v_b - 0.3
            xe, ze = marco.mundo(pu0, pv0)
            nx_, nz_ = marco.c * normal[0] - marco.s * normal[1], marco.s * normal[0] + marco.c * normal[1]
            piezas.append({"nombre": "Escalera_" + nombre, "tipo": "escalera", "favela": True, "x": round(xe, 2), "z": round(ze, 2),
                           "rot": round(math.atan2(nx_, nz_), 4), "alto": round(pisos * PISO + AZOTEA, 2), "ancho": 0.9, "sentido": 1})
            cuenta["escaleras"] += 1
    # Tablones entre azoteas de dos pisos a los dos lados de un callejon angosto
    for par in abiertas:
        if ancho_par.get(par, 9.0) > TABLON_MAX or r.random() > 0.35:
            continue
        (a, b), (c, d) = sorted(par)
        ca, cc = casas.get((a, b)), casas.get((c, d))
        if not ca or not cc or ca["pisos"] != 2 or cc["pisos"] != 2 or banda(a) != banda(c):
            continue
        ua, va = centro(a, b)
        uc, vc = centro(c, d)
        x, z = marco.mundo((ua + uc) / 2, (va + vc) / 2)
        a_lo_largo_u = (c != a)
        rot = marco.rot if a_lo_largo_u else marco.rot_v
        piezas.append({"nombre": "Tablon_%d" % cuenta["tablones"], "tipo": "tablon", "favela": True, "x": round(x, 2), "z": round(z, 2),
                       "y": round(2 * PISO + AZOTEA + 0.02 + alto_de(a), 2), "rot": rot, "largo": round(ancho_par[par] + 1.2, 2), "ancho": 0.7})
        cuenta["tablones"] += 1
    if op.get("tuneles", True):
        _tuneles(marco, r, patios, casas, nx, nz, pu, pv, banda, piezas, hundidos, marcas, cuenta)


def _tuneles(marco, r, patios, casas, nx, nz, pu, pv, banda, piezas, hundidos, marcas, cuenta):
    """Las bocas de los tuneles bajo TUNELES patios de la primera banda (a nivel), la galeria de cada
    una hasta una espina que corre de norte a sur, y de la espina la galeria principal al oriente
    con sus ramales: cuartos (dormitorio, garrafones, armas), dos tiendas, el pozo de la valvula y
    la boca final tapada hacia los carcamos. Todo a TUNEL_PISO bajo el piso."""
    candidatos = [p for p in patios if banda(p[0][0]) == 0]
    if len(candidatos) < TUNELES:
        # Se vuelven patio algunas celdas de la banda 0 que tengan casa
        for (a, b), casa in sorted(casas.items(), key=lambda kv: (kv[0][1] % 3, kv[0][0])):
            if banda(a) != 0 or a == 0:
                continue
            if any(abs(b - q[0][1]) < 4 for q in candidatos):
                continue
            piezas.remove(casa)
            cuenta["casas"] -= 1
            cu, cv = (a + 0.5) * pu, (b + 0.5) * pv
            piezas.append({"nombre": "Patio_%d_%d" % (a, b), "tipo": "patio", "favela": True, "x": round(marco.mundo(cu, cv)[0], 2),
                           "z": round(marco.mundo(cu, cv)[1], 2), "rot": marco.rot, "tam": [round(pu - 1.8, 2), round(pv - 1.8, 2)]})
            cuenta["patios"] += 1
            candidatos.append(((a, b), (cu, cv)))
            if len(candidatos) >= TUNELES:
                break
    candidatos.sort(key=lambda p: p[0][1])
    bocas = candidatos[:TUNELES]
    if not bocas:
        return
    # Un patio con boca no lleva lavadero ni tinaco encima de la zanja: la pieza patio se quita y queda
    # la zanja con su barandal (bajada) en medio del piso de concreto
    for (a, b), (cu, cv) in bocas:
        for p in piezas:
            if p["tipo"] == "patio" and p["nombre"] == "Patio_%d_%d" % (a, b):
                piezas.remove(p)
                cuenta["patios"] -= 1
                break
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
            xd, zd = marco.mundo(du, v_main + lado * (TUNEL_ANCHO / 2 + 0.9))
            marcas.append({"nombre": "Puerta_%s" % nombre, "tipo": "puerta", "favela": True, "giro": "tiendita", "texto": ["Fayuca del Túnel", "Balas y Veladoras"][i % 2],
                           "x": round(xd, 2), "z": round(zd, 2), "y": TUNEL_PISO, "rot": round(marco.rot + (math.pi if lado > 0 else 0.0), 4)})
        elif uso == "valvula":
            marcas.append({"nombre": "Valvula", "tipo": "mision", "favela": True, "x": round(x, 2), "z": round(z, 2), "y": TUNEL_PISO, "rot": rot})
            marcas.append({"nombre": "Letrero_Valvula", "tipo": "letrero", "favela": True, "texto": "La toma. Ni la toques.",
                           "x": round(x, 2), "z": round(z, 2), "y": TUNEL_PISO + 1.9, "rot": rot})
        elif uso == "garrafones":
            marcas.append({"nombre": "Bodega_Agua", "tipo": "mision", "favela": True, "x": round(x, 2), "z": round(z, 2), "y": TUNEL_PISO, "rot": rot})
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


if __name__ == "__main__":
    generar(sys.argv[1] if len(sys.argv) > 1 else "la_gotera_favela")
