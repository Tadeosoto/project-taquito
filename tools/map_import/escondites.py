#!/usr/bin/env python3
"""Los escondites de los drops raros (S5 de docs/plan-noche.md) en map_test.

Escoge lugares escondidos de los datos del mapa, sin abrir Godot:
  - callejon: la punta de una banqueta sin otra cerca (una calle cerrada o un rincon),
  - bodega: atras de una bodega (resources/map/bodegas_mapa.json), del lado contrario a su frente.
La mayoria van en las orillas, fuera del cuadro del contenido (docs/mapa/zona-enfoque.md: "las orillas
son para cosas escondidas") y unos cuantos adentro. Nunca dentro de una fortaleza ni pegados a los
tinacos de la defensa. Quedan separados al menos SEPARADOS m. DropsRaros.gd los revisa en el juego
(piso libre) y cada dia pone drops en unos cuantos al azar.

    python3 tools/map_import/escondites.py      # escribe resources/map/escondites.json
"""
import json
import math
import random
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
BANQUETAS = RAIZ / "resources/map/banquetas_mapa.json"
BODEGAS = RAIZ / "resources/map/bodegas_mapa.json"
SALIDA = RAIZ / "resources/map/escondites.json"

# El cuadro del contenido (zona-enfoque.md): x0, z0, x1, z1
CONTENIDO = (-616.0, -858.0, 914.0, 622.0)
# El mapa entero (minimapa.json)
MAPA = (-913.0, -897.5, 914.0, 898.5)
ORILLA_MAPA = 25.0          # m de la orilla del mapa: ahi se acaba el piso
SEPARADOS = 110.0
ORILLAS = 24                # cuantos en las orillas
ADENTRO = 12                # cuantos dentro del cuadro
SOLO = 10.0                 # m: una punta de banqueta sin otra banqueta asi de cerca es un callejon
DETRAS = 2.0                # m detras de la pared de la bodega
FORTALEZA_MARGEN = 40.0

# Las barda de las fortalezas de map_test (MuroColonia): Santa Mugre, La Gotera y Los Reservorios
FORTALEZAS = [[tuple(v) for v in f["poligono"]]
              for k, f in json.loads((RAIZ / "resources/map/fortalezas.json").read_text()).items()
              if not k.startswith("_")]
# SitiosTinaco.SITIOS (zona-enfoque.md)
TINACOS = [(-336, -1), (-331, -359), (157, -344), (494, -529), (330, 95)]
TINACO_MARGEN = 50.0


def adentro_poligono(x, z, poli):
    dentro = False
    j = len(poli) - 1
    for i in range(len(poli)):
        xi, zi = poli[i]
        xj, zj = poli[j]
        if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi:
            dentro = not dentro
        j = i
    return dentro


def dist_poligono(x, z, poli):
    mejor = math.inf
    for i in range(len(poli)):
        ax, az = poli[i]
        bx, bz = poli[(i + 1) % len(poli)]
        dx, dz = bx - ax, bz - az
        t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / max(dx * dx + dz * dz, 1e-9)))
        mejor = min(mejor, math.hypot(x - (ax + t * dx), z - (az + t * dz)))
    return mejor


def prohibido(x, z):
    x0, z0, x1, z1 = MAPA
    if not (x0 + ORILLA_MAPA < x < x1 - ORILLA_MAPA and z0 + ORILLA_MAPA < z < z1 - ORILLA_MAPA):
        return True
    for poli in FORTALEZAS:
        if adentro_poligono(x, z, poli) or dist_poligono(x, z, poli) < FORTALEZA_MARGEN:
            return True
    return any(math.hypot(x - tx, z - tz) < TINACO_MARGEN for tx, tz in TINACOS)


def en_orilla(x, z):
    x0, z0, x1, z1 = CONTENIDO
    return not (x0 <= x <= x1 and z0 <= z <= z1)


def callejones():
    lineas = json.loads(BANQUETAS.read_text())["banquetas"]
    # Todos los vertices, por celda, para saber si una punta tiene otra banqueta cerca
    celdas = {}
    for n, linea in enumerate(lineas):
        for x, z in linea:
            celdas.setdefault((int(x // SOLO), int(z // SOLO)), []).append((n, x, z))
    salida = []
    for n, linea in enumerate(lineas):
        if len(linea) < 2:
            continue
        for x, z in (linea[0], linea[-1]):
            cx, cz = int(x // SOLO), int(z // SOLO)
            sola = True
            for dx in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for otra, ox, oz in celdas.get((cx + dx, cz + dz), []):
                        if otra != n and math.hypot(ox - x, oz - z) < SOLO:
                            sola = False
            if sola and linea[0] != linea[-1]:
                salida.append({"x": round(x, 1), "z": round(z, 1), "tipo": "callejon"})
    return salida


def detras_de_bodegas():
    salida = []
    for b in json.loads(BODEGAS.read_text())["bodegas"]:
        ry = b["rotacion_y"]
        frente = (math.sin(ry), math.cos(ry))
        atras = b["fondo"] / 2.0 + DETRAS
        x = b["x"] - frente[0] * atras
        z = b["z"] - frente[1] * atras
        salida.append({"x": round(x, 1), "z": round(z, 1), "tipo": "bodega", "colonia": b.get("colonia", "")})
    return salida


def escoger(candidatos, cuantos, ya):
    escogidos = []
    for c in candidatos:
        if len(escogidos) >= cuantos:
            break
        if all(math.hypot(c["x"] - o["x"], c["z"] - o["z"]) >= SEPARADOS for o in ya + escogidos):
            escogidos.append(c)
    return escogidos


def main():
    random.seed(47)   # siempre los mismos al volver a correrlo
    todos = [c for c in callejones() + detras_de_bodegas() if not prohibido(c["x"], c["z"])]
    # Revueltos y alternando: una bodega, un callejon, para que no sean puras bodegas
    bodegas = [c for c in todos if c["tipo"] == "bodega"]
    calles = [c for c in todos if c["tipo"] == "callejon"]
    random.shuffle(bodegas)
    random.shuffle(calles)
    todos = [c for par in zip(bodegas, calles) for c in par] + bodegas[len(calles):] + calles[len(bodegas):]
    orillas = escoger([c for c in todos if en_orilla(c["x"], c["z"])], ORILLAS, [])
    adentro = escoger([c for c in todos if not en_orilla(c["x"], c["z"])], ADENTRO, orillas)
    lugares = []
    for c in orillas + adentro:
        c["orilla"] = en_orilla(c["x"], c["z"])
        lugares.append(c)
    SALIDA.write_text(json.dumps({"escondites": lugares}, ensure_ascii=False, indent=1) + "\n")
    print(f"{len(orillas)} en las orillas y {len(adentro)} adentro -> {SALIDA.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
