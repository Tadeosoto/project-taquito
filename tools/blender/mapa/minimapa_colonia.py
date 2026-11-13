#!/usr/bin/env python3
"""Dibuja el minimapa propio de una colonia de Blender (la favela de La Gotera): callejones,
casas, claros, tablones/puentes, tuneles y los iconos de azoteas, entradas de tunel, salidas y
tinaco. Escribe textures/map/minimapa_<colonia>.png y resources/mapa/<colonia>/minimapa.json,
que lee scripts/map/MapMinimapa.gd.

Python puro, sin bpy. Se puede correr suelto:
  python3 tools/blender/mapa/minimapa_colonia.py la_gotera_favela
o lo llama exportar.py al final de exportar().
"""

import json
import math
import os
import struct
import sys
import zlib

try:
    _AQUI = os.path.dirname(os.path.abspath(__file__))
except NameError:
    _AQUI = os.getcwd()
RAIZ = os.environ.get("TAQUITO_RAIZ", "") or os.path.dirname(os.path.dirname(os.path.dirname(_AQUI)))
COLONIAS = os.path.join(RAIZ, "tools", "blender", "mapa", "colonias")
TEXTURAS = os.path.join(RAIZ, "textures", "map")
DATOS = os.path.join(RAIZ, "resources", "mapa")

METROS_POR_PIXEL = 0.5
MARGEN = 6.0

TIERRA = (46, 41, 34)
TERRAZA = [(55, 50, 42), (62, 55, 45), (68, 60, 49)]
CASA = (105, 103, 98)
CASA_PINTADA = (125, 120, 100)
PATIO = (88, 76, 57)
CLARO = (112, 100, 66)
CALLE = (188, 180, 160)
TUNEL = (78, 60, 48)
TABLON = (150, 142, 126)
ICONO_AZOTEA = (230, 230, 225)
ICONO_TUNEL = (225, 150, 60)
ICONO_SALIDA = (240, 205, 60)
ICONO_TINACO = (75, 135, 220)


def _mundo(p, lx, lz):
    r = float(p.get("rot", 0.0))
    c, s = math.cos(r), math.sin(r)
    return p["x"] + lx * c + lz * s, p["z"] - lx * s + lz * c


class Lienzo:
    def __init__(self, x0, z0, x1, z1):
        self.x0, self.z0 = x0, z0
        self.w = max(1, int(math.ceil((x1 - x0) / METROS_POR_PIXEL)))
        self.h = max(1, int(math.ceil((z1 - z0) / METROS_POR_PIXEL)))
        self.rgb = bytearray(bytes(TIERRA) * (self.w * self.h))

    def px(self, x, z):
        return (x - self.x0) / METROS_POR_PIXEL, (z - self.z0) / METROS_POR_PIXEL

    def punto(self, col, fila, color):
        if 0 <= col < self.w and 0 <= fila < self.h:
            i = (fila * self.w + col) * 3
            self.rgb[i:i + 3] = bytes(color)

    def poligono(self, pts, color):
        p = [self.px(x, z) for x, z in pts]
        if p[0] != p[-1]:
            p.append(p[0])
        ys = [q[1] for q in p]
        color = bytes(color)
        for fila in range(max(int(min(ys)), 0), min(int(max(ys)) + 1, self.h)):
            cy = fila + 0.5
            cortes = []
            for (ax, ay), (bx, by) in zip(p, p[1:]):
                if (ay <= cy) != (by <= cy):
                    cortes.append(ax + (cy - ay) / (by - ay) * (bx - ax))
            cortes.sort()
            for a, b in zip(cortes[::2], cortes[1::2]):
                c0 = max(int(math.ceil(a - 0.5)), 0)
                c1 = min(int(math.floor(b - 0.5)), self.w - 1)
                if c1 >= c0:
                    i = (fila * self.w + c0) * 3
                    self.rgb[i:i + (c1 - c0 + 1) * 3] = color * (c1 - c0 + 1)

    def linea(self, linea, ancho, color):
        r = max(ancho / 2.0 / METROS_POR_PIXEL, 0.7)
        color = bytes(color)
        pts = [self.px(x, z) for x, z in linea]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            dx, dy = bx - ax, by - ay
            l2 = dx * dx + dy * dy
            for fila in range(max(int(min(ay, by) - r), 0), min(int(max(ay, by) + r) + 1, self.h)):
                cy = fila + 0.5
                for col in range(max(int(min(ax, bx) - r), 0), min(int(max(ax, bx) + r) + 1, self.w)):
                    cx = col + 0.5
                    t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((cx - ax) * dx + (cy - ay) * dy) / l2))
                    ex, ey = ax + dx * t - cx, ay + dy * t - cy
                    if ex * ex + ey * ey <= r * r:
                        i = (fila * self.w + col) * 3
                        self.rgb[i:i + 3] = color

    def rectangulo(self, p, color):
        w, h = p.get("tam", [6.0, 6.0])
        pts = [_mundo(p, x, z) for x, z in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2))]
        self.poligono(pts, color)


def _icono(lienzo, x, z, color):
    c, f = lienzo.px(x, z)
    c, f = int(c), int(f)
    for dx in range(-3, 4):
        for dy in range(-3, 4):
            if dx * dx + dy * dy <= 9:
                lienzo.punto(c + dx, f + dy, (20, 20, 20))
    for dx in range(-2, 3):
        for dy in range(-2, 3):
            lienzo.punto(c + dx, f + dy, color)


def _write_png(ruta, ancho, alto, rgb):
    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))
    raw = b"".join(b"\0" + bytes(rgb[y * ancho * 3:(y + 1) * ancho * 3]) for y in range(alto))
    with open(ruta, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", ancho, alto, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 6)))
        f.write(chunk(b"IEND", b""))


def generar(datos):
    if not datos.get("favela"):
        return None
    nombre = datos["nombre"]
    x1, z1, x2, z2 = datos["recorte"]
    x0, z0 = x1 - MARGEN, z1 - MARGEN
    x3, z3 = x2 + MARGEN, z2 + MARGEN
    lienzo = Lienzo(x0, z0, x3, z3)

    # Bandas de terraza
    for i, t in enumerate(datos.get("terrazas", [])):
        if t.get("poligono"):
            lienzo.poligono([(p[0], p[1]) for p in t["poligono"]], TERRAZA[i % len(TERRAZA)])

    # Patios, claros y lotes
    for p in datos.get("piezas", []):
        if p.get("tipo") == "patio":
            lienzo.rectangulo(p, PATIO)
        elif p.get("tipo") == "lote":
            lienzo.rectangulo(p, CLARO if p.get("claro") or p.get("variante") == "tinaco" else PATIO)

    # Casas
    for p in datos.get("piezas", []):
        if p.get("tipo") != "casa":
            continue
        pts = [_mundo(p, x, z) for x, z in p.get("puntos", [])]
        if len(pts) >= 3:
            lienzo.poligono(pts, CASA_PINTADA if p.get("color") else CASA)

    # Callejones (encima de las casas, para que se lean)
    for p in datos.get("piezas", []):
        if p.get("tipo") != "calle":
            continue
        pts = [(p["x"] + a, p["z"] + b) for a, b in p.get("puntos", [])]
        if len(pts) >= 2:
            lienzo.linea(pts, max(float(p.get("ancho", 1.5)), 1.6), CALLE)

    # Túneles (punteados)
    for p in datos.get("piezas", []):
        if p.get("tipo") not in ("tunel", "tunel_cuarto"):
            continue
        r = float(p.get("rot", 0.0))
        largo = float(p.get("largo", 8.0))
        dx, dz = math.cos(r), -math.sin(r)
        n = max(2, int(largo / 2.0))
        for i in range(n):
            a = -largo / 2 + i * 2.0
            b = min(a + 1.0, largo / 2)
            lienzo.linea([(p["x"] + dx * a, p["z"] + dz * a), (p["x"] + dx * b, p["z"] + dz * b)], 1.0, TUNEL)

    # Tablones y puentes
    for p in datos.get("piezas", []):
        if p.get("tipo") != "tablon":
            continue
        r = float(p.get("rot", 0.0))
        largo = float(p.get("largo", 3.0))
        dx, dz = math.cos(r), -math.sin(r)
        lienzo.linea([(p["x"] - dx * largo / 2, p["z"] - dz * largo / 2),
                      (p["x"] + dx * largo / 2, p["z"] + dz * largo / 2)], 1.0, TABLON)

    # Iconos: azoteas (escaleras), túneles, salidas y tinaco
    iconos = []
    for p in datos.get("piezas", []):
        if p.get("tipo") == "escalera":
            iconos.append({"tipo": "azotea", "x": round(p["x"], 2), "z": round(p["z"], 2)})
    for m in datos.get("marcas", []):
        if m.get("tipo") == "mision" and str(m.get("nombre", "")).startswith("Tunel_Entrada"):
            iconos.append({"tipo": "tunel", "x": round(m["x"], 2), "z": round(m["z"], 2)})
        elif m.get("tipo") == "paso":
            iconos.append({"tipo": "salida", "x": round(m["x"], 2), "z": round(m["z"], 2)})
        elif m.get("tipo") == "tinaco":
            iconos.append({"tipo": "tinaco", "x": round(m["x"], 2), "z": round(m["z"], 2)})
    for i in iconos:
        color = {"azotea": ICONO_AZOTEA, "tunel": ICONO_TUNEL, "salida": ICONO_SALIDA, "tinaco": ICONO_TINACO}[i["tipo"]]
        _icono(lienzo, i["x"], i["z"], color)

    os.makedirs(TEXTURAS, exist_ok=True)
    os.makedirs(os.path.join(DATOS, nombre), exist_ok=True)
    png = os.path.join(TEXTURAS, "minimapa_%s.png" % nombre)
    _write_png(png, lienzo.w, lienzo.h, lienzo.rgb)
    salida = {
        "x0": round(x0, 2), "z0": round(z0, 2),
        "ancho": lienzo.w, "alto": lienzo.h,
        "metros_por_pixel": METROS_POR_PIXEL,
        "radio": 55.0, "radio_dron": 130.0,
        "iconos": iconos,
    }
    with open(os.path.join(DATOS, nombre, "minimapa.json"), "w", encoding="utf-8") as f:
        json.dump(salida, f, ensure_ascii=False, indent="\t")
        f.write("\n")
    print("minimapa %s: %dx%d px, %d iconos -> %s" % (nombre, lienzo.w, lienzo.h, len(iconos), png))
    return salida


def _principal():
    nombre = sys.argv[1] if len(sys.argv) > 1 else "la_gotera_favela"
    datos = json.load(open(os.path.join(COLONIAS, nombre + ".json"), encoding="utf-8"))
    generar(datos)


if __name__ == "__main__":
    _principal()
