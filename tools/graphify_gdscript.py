"""Grafo del codigo GDScript con graphify.

graphify no trae parser de GDScript (.gd no esta en sus CODE_EXTENSIONS), asi que
este script hace la extraccion con expresiones regulares y luego usa las piezas de
graphify (build, cluster, report, export) para el resto. No usa LLM: es gratis y
siempre da lo mismo.

Uso, desde la raiz del repo, con el Python de graphify:
    "$(cat docs/graphify-out/.graphify_python)" tools/graphify_gdscript.py

Escribe en scripts/graphify-out/ (graph.json, graph.html, GRAPH_REPORT.md).

Que extrae:
- un nodo por archivo .gd de scripts/ (class_name y autoload apuntan a el)
- clases internas (class X:), funciones y senales, colgadas de su archivo
- extends a otro script del proyecto (inherits)
- preload/load de .gd y .tscn, por res:// o uid:// (imports / loads_scene)
- Clase.funcion() y Autoload.funcion() hacia otro script (calls), y funcion()
  dentro del mismo archivo (calls)
- Clase.new() (instantiates), tipos `: Clase`, `as Clase`, `is Clase` (uses)
- Autoload.senal.connect() / .emit() (listens / emits)
- escenas .tscn del repo con los scripts que usan (uses_script)
Lo que no ve: llamadas por variable (jugador.recibir_golpe()), call()/call_group,
grupos, senales conectadas en el editor. Esas aristas no salen; mejor faltar que
inventar.

Nombres de comunidades: si scripts/graphify-out/labels.json existe (lista de
{"miembro": "<id de nodo>", "nombre": "..."}), una comunidad que contenga ese
nodo toma ese nombre; si no, se nombra por su carpeta y archivo con mas grado.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SCRIPTS = RAIZ / "scripts"
SALIDA = SCRIPTS / "graphify-out"
IGNORAR_DIRS = {".godot", ".git", "addons", "graphify-out", ".claude"}

RE_CLASS_NAME = re.compile(r"^class_name\s+(\w+)", re.M)
RE_EXTENDS = re.compile(r"^extends\s+(\"[^\"]+\"|\w+)", re.M)
RE_FUNC = re.compile(r"^(\s*)(?:static\s+)?func\s+(\w+)\s*\(")
RE_CLASS_INT = re.compile(r"^(\s*)class\s+(\w+)\s*(?:extends\s+\w+\s*)?:")
RE_SIGNAL = re.compile(r"^\s*signal\s+(\w+)")
RE_LOAD = re.compile(r"\b(?:preload|load|ResourceLoader\.load)\s*\(\s*\"((?:res|uid)://[^\"]+)\"")
RE_CALL_EXT = re.compile(r"\b([A-Z]\w*)\.(\w+)\s*\(")
RE_SENAL_EXT = re.compile(r"\b([A-Z]\w*)\.(\w+)\.(connect|emit)\s*\(")
RE_CALL_LOCAL = re.compile(r"(?<![\.\w])(\w+)\s*\(")
RE_TIPO = re.compile(r"(?::\s*|->\s*|\bas\s+|\bis\s+|Array\[)([A-Z]\w*)")
RE_STR = re.compile(r"\"(?:[^\"\\]|\\.)*\"|'(?:[^'\\]|\\.)*'")
PALABRAS = {"if", "elif", "while", "for", "match", "return", "func", "print", "assert",
            "await", "super", "not", "and", "or", "in", "preload", "load", "str", "int",
            "float", "bool", "len", "range", "Vector2", "Vector3", "Color"}


def rel(p: Path) -> str:
    return p.relative_to(RAIZ).as_posix()


def nid(*partes: str) -> str:
    return "_".join(re.sub(r"[^0-9a-z]+", "_", s.lower()).strip("_") for s in partes)


def sin_comentario(linea: str) -> str:
    """Quita strings y el comentario # (fuera de strings)."""
    s = RE_STR.sub('""', linea)
    i = s.find("#")
    return s[:i] if i >= 0 else s


def mapa_uids() -> dict[str, str]:
    uids = {}
    for f in RAIZ.rglob("*.uid"):
        if IGNORAR_DIRS & set(f.relative_to(RAIZ).parts):
            continue
        u = f.read_text(encoding="utf-8", errors="replace").strip()
        uids[u] = "res://" + rel(f)[:-4]
    for f in RAIZ.rglob("*.tscn"):
        if IGNORAR_DIRS & set(f.relative_to(RAIZ).parts):
            continue
        cab = f.open(encoding="utf-8", errors="replace").readline()
        m = re.search(r'uid="(uid://\w+)"', cab)
        if m:
            uids[m.group(1)] = "res://" + rel(f)
    return uids


def autoloads(uids: dict[str, str]) -> dict[str, str]:
    txt = (RAIZ / "project.godot").read_text(encoding="utf-8", errors="replace")
    sec = re.search(r"^\[autoload\]\n(.*?)(?=^\[|\Z)", txt, re.M | re.S)
    out = {}
    for nombre, ruta in re.findall(r'^(\w+)="\*?([^"]+)"', sec.group(1) if sec else "", re.M):
        out[nombre] = uids.get(ruta, ruta)
    return out


def main() -> None:
    uids = mapa_uids()
    archivos = sorted(p for p in SCRIPTS.rglob("*.gd") if not (IGNORAR_DIRS & set(p.relative_to(RAIZ).parts)))
    nodos: dict[str, dict] = {}
    aristas: list[dict] = []
    vistos: set[tuple] = set()

    def nodo(i, label, src, linea=1, **extra):
        nodos.setdefault(i, {"id": i, "label": label, "file_type": "code", "source_file": src,
                             "source_location": f"L{linea}", "_origin": "ast", **extra})

    def arista(a, b, rel_, src, linea, conf="EXTRACTED"):
        if a == b or (a, b, rel_) in vistos:
            return
        vistos.add((a, b, rel_))
        aristas.append({"source": a, "target": b, "relation": rel_, "confidence": conf,
                        "source_file": src, "source_location": f"L{linea}", "weight": 1.0, "_origin": "ast"})

    # Pasada 1: nombres globales -> id de archivo
    textos, id_de_ruta, global_a_id = {}, {}, {}
    for p in archivos:
        r = rel(p)
        txt = p.read_text(encoding="utf-8", errors="replace")
        textos[r] = txt
        i = nid(r[:-3])
        id_de_ruta["res://" + r] = i
        m = RE_CLASS_NAME.search(txt)
        label = p.name + (f" ({m.group(1)})" if m and m.group(1) != p.stem else "")
        nodo(i, label, r)
        if m:
            global_a_id[m.group(1)] = i
    for nombre, ruta in autoloads(uids).items():
        if ruta in id_de_ruta:
            global_a_id[nombre] = id_de_ruta[ruta]
            n = nodos[id_de_ruta[ruta]]
            n["label"] += " [autoload]" if nombre == Path(ruta).stem else f" [autoload {nombre}]"

    # Funciones y senales por archivo (para resolver llamadas)
    funcs_de: dict[str, set[str]] = defaultdict(set)
    senales_de: dict[str, set[str]] = defaultdict(set)
    for r, txt in textos.items():
        fid = id_de_ruta["res://" + r]
        for ln in txt.splitlines():
            m = RE_FUNC.match(ln)
            if m and not m.group(1):
                funcs_de[fid].add(m.group(2))
            m = RE_SIGNAL.match(ln)
            if m:
                senales_de[fid].add(m.group(1))

    escenas: dict[str, str] = {}

    def destino_recurso(ruta: str) -> tuple[str, str] | None:
        ruta = uids.get(ruta, ruta).split("::")[0]
        if ruta in id_de_ruta:
            return id_de_ruta[ruta], "imports"
        if ruta.endswith(".tscn"):
            r = ruta[len("res://"):]
            i = escenas.setdefault(ruta, nid("escena", r[:-5]))
            nodo(i, Path(r).name, r)
            return i, "loads_scene"
        return None

    # Pasada 2: estructura y referencias
    for r, txt in textos.items():
        fid = id_de_ruta["res://" + r]
        m = RE_EXTENDS.search(txt)
        if m:
            base = m.group(1).strip('"')
            linea = txt[:m.start()].count("\n") + 1
            b = id_de_ruta.get(uids.get(base, base)) or global_a_id.get(base)
            if b:
                arista(fid, b, "inherits", r, linea)
        pila: list[tuple[int, str, str]] = []  # (indent, id, tipo) clases internas y funcs abiertas
        for n_linea, ln in enumerate(txt.splitlines(), 1):
            if not ln.strip() or ln.lstrip().startswith("#"):
                continue
            ind = len(ln) - len(ln.lstrip())
            while pila and ind <= pila[-1][0]:
                pila.pop()
            dueno = pila[-1][1] if pila else fid
            for ruta in RE_LOAD.findall(ln):
                d = destino_recurso(ruta)
                if d:
                    arista(dueno, d[0], d[1], r, n_linea)
            m = RE_CLASS_INT.match(ln)
            if m:
                cid = nid(r[:-3], m.group(2))
                nodo(cid, m.group(2), r, n_linea, _callable=True, _callable_class=True)
                arista(dueno, cid, "contains", r, n_linea)
                pila.append((ind, cid, "class"))
                continue
            m = RE_FUNC.match(ln)
            if m:
                fn = nid(dueno, m.group(2))
                nodo(fn, f".{m.group(2)}()" if dueno != fid else f"{m.group(2)}()", r, n_linea, _callable=True)
                arista(dueno, fn, "contains" if dueno == fid else "method", r, n_linea)
                pila.append((ind, fn, "func"))
                cuerpo = ln[ln.find("("):]
            else:
                cuerpo = ln
            m = RE_SIGNAL.match(ln)
            if m and not pila:
                sid = nid(fid, "senal", m.group(1))
                nodo(sid, f"signal {m.group(1)}", r, n_linea)
                arista(fid, sid, "contains", r, n_linea)
                continue
            limpio = sin_comentario(cuerpo)
            for g, s, op in RE_SENAL_EXT.findall(limpio):
                t = global_a_id.get(g)
                if t and s in senales_de[t]:
                    arista(dueno, nid(t, "senal", s), "listens" if op == "connect" else "emits", r, n_linea)
            for g, f in RE_CALL_EXT.findall(limpio):
                t = global_a_id.get(g)
                if not t:
                    continue
                if f == "new":
                    arista(dueno, t, "instantiates", r, n_linea)
                elif f in funcs_de[t]:
                    arista(dueno, nid(t, f), "calls", r, n_linea)
                else:
                    arista(dueno, t, "uses", r, n_linea)
            for g in RE_TIPO.findall(limpio):
                t = global_a_id.get(g)
                if t:
                    arista(fid, t, "uses", r, n_linea)
            if pila:
                for f in RE_CALL_LOCAL.findall(limpio):
                    if f in funcs_de[fid] and f not in PALABRAS:
                        arista(dueno, nid(fid, f), "calls", r, n_linea)
            # Autoload usado sin llamar (Inventory.items, Ciclo.es_noche...)
            for g in re.findall(r"\b([A-Z]\w*)\.\w", limpio):
                t = global_a_id.get(g)
                if t:
                    arista(fid, t, "uses", r, n_linea)

    # Escenas del repo que usan scripts
    for f in sorted(RAIZ.rglob("*.tscn")):
        if IGNORAR_DIRS & set(f.relative_to(RAIZ).parts):
            continue
        txt = f.read_text(encoding="utf-8", errors="replace")
        usados = [(m.group(1), txt[:m.start()].count("\n") + 1) for m in
                  re.finditer(r'\[ext_resource type="Script"[^\]]*path="([^"]+)"', txt)]
        usados = [(id_de_ruta[p], l) for p, l in usados if p in id_de_ruta]
        if not usados:
            continue
        ruta = "res://" + rel(f)
        i = escenas.setdefault(ruta, nid("escena", rel(f)[:-5]))
        nodo(i, f.name, rel(f))
        for s, l in usados:
            arista(i, s, "uses_script", rel(f), l)

    # Funciones/senales ya no colgadas de nada se quedan; quitar aristas a nodos inexistentes
    aristas = [a for a in aristas if a["source"] in nodos and a["target"] in nodos]
    extraccion = {"nodes": list(nodos.values()), "edges": aristas, "hyperedges": [],
                  "input_tokens": 0, "output_tokens": 0}
    construir(extraccion, len(archivos), len(escenas))


def construir(extraccion: dict, n_gd: int, n_tscn: int) -> None:
    from graphify.analyze import god_nodes, suggest_questions, surprising_connections
    from graphify.build import build_from_json
    from graphify.cluster import cluster, score_all
    from graphify.export import to_html, to_json
    from graphify.report import generate

    SALIDA.mkdir(exist_ok=True)
    (SALIDA / ".gdignore").write_text("", encoding="utf-8")  # que Godot no importe el grafo
    G = build_from_json(extraccion, root=str(RAIZ), directed=False)
    if G.number_of_nodes() == 0:
        sys.exit("Grafo vacio")
    comunidades = cluster(G)
    cohesion = score_all(G, comunidades)
    etiquetas = nombrar(G, comunidades)
    dioses = god_nodes(G)
    sorpresas = surprising_connections(G, comunidades)
    preguntas = suggest_questions(G, comunidades, etiquetas)
    try:
        commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=RAIZ,
                                capture_output=True, text=True).stdout.strip() or None
    except OSError:
        commit = None
    deteccion = {"total_files": n_gd + n_tscn, "total_words": 0,
                 "files": {"code": [f"{n_gd} .gd", f"{n_tscn} .tscn"]}}
    to_json(G, comunidades, str(SALIDA / "graph.json"), force=True, built_at_commit=commit,
            community_labels=etiquetas)
    reporte = generate(G, comunidades, cohesion, etiquetas, dioses, sorpresas, deteccion,
                       {"input": 0, "output": 0}, "scripts", suggested_questions=preguntas,
                       built_at_commit=commit)
    reporte = reporte.replace("Run `graphify update .` after code changes (no API cost).",
                              "Rebuild after code changes: `\"$(cat docs/graphify-out/.graphify_python)\" "
                              "tools/graphify_gdscript.py` (no API cost; `graphify update` can't read .gd).")
    (SALIDA / "GRAPH_REPORT.md").write_text(reporte, encoding="utf-8")
    to_html(G, comunidades, str(SALIDA / "graph.html"), community_labels=etiquetas)
    print(f"{G.number_of_nodes()} nodos, {G.number_of_edges()} aristas, {len(comunidades)} comunidades "
          f"({n_gd} .gd, {n_tscn} escenas) -> {SALIDA.relative_to(RAIZ).as_posix()}/")


def nombrar(G, comunidades: dict[int, list[str]]) -> dict[int, str]:
    fijos = []
    f = SALIDA / "labels.json"
    if f.exists():
        fijos = json.loads(f.read_text(encoding="utf-8"))
    out, usados = {}, Counter()
    for cid, miembros in comunidades.items():
        ms = set(miembros)
        nombre = next((x["nombre"] for x in fijos if x["miembro"] in ms), None)
        if not nombre:
            archivos = [m for m in miembros if G.nodes[m].get("source_location") == "L1"
                        and G.nodes[m].get("label", "").split(" ")[0].endswith((".gd", ".tscn"))]
            base = max(archivos or miembros, key=G.degree)
            src = G.nodes[base].get("source_file", "")
            carpeta = Path(src).parent.name
            nombre = f"{carpeta}/{Path(src).name}"
        usados[nombre] += 1
        out[cid] = nombre if usados[nombre] == 1 else f"{nombre} ({usados[nombre]})"
    return out


if __name__ == "__main__":
    main()
