"""La copia del Simi de Sketchfab para el jefe (JJ 2026-11-22): el mismo scene.gltf de
models/personajes/dr_simi, pero apuntando a su scene.bin y sus texturas, para importarlo aparte con
retarget al perfil humanoide (simi_jefe.gltf.import) sin tocar la botarga de las farmacias.

    python3 -I tools/simi/simi_jefe_gltf.py

Necesita el original (python3 -I tools/map_import/fetch_sketchfab.py personajes/dr_simi).
Despues: godot --path . --headless --import y tools/simi/separar_simi_jefe.gd."""
import json
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FUENTE = os.path.join(RAIZ, "models/personajes/dr_simi/scene.gltf")
SALIDA = os.path.join(RAIZ, "models/personajes/simi_jefe/simi_jefe.gltf")

with open(FUENTE, encoding="utf-8") as f:
    gltf = json.load(f)
for b in gltf.get("buffers", []):
    b["uri"] = "../dr_simi/" + b["uri"]
for i in gltf.get("images", []):
    if "uri" in i:
        i["uri"] = "../dr_simi/" + i["uri"]
os.makedirs(os.path.dirname(SALIDA), exist_ok=True)
with open(SALIDA, "w", encoding="utf-8") as f:
    json.dump(gltf, f)
print("simi_jefe.gltf:", len(gltf.get("meshes", [])), "mallas")
