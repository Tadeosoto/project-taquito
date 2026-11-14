"""Baja modelos CC0 de Poly Haven (https://polyhaven.com/models) sin cuenta, al mismo formato que
fetch_sketchfab.py: models/<carpeta>/scene.gltf + scene.bin + textures/<modelo>_baseColor.jpg
(256 px) y un .import con scripts/map/TiendaPostImport.gd (shader PS1, y la reduccion de
MAX_TRIANGULOS). Del material solo queda el color base: normal, roughness y AO se quitan del glTF.

    python3 -I tools/map_import/fetch_polyhaven.py [carpeta ...]

Despues, como con Sketchfab:
    godot --path . --headless --import
    godot --path . --headless -s tools/map_import/hornear_modelos.gd -- --solo=<modelo>
El juego usa models/<carpeta>/<modelo>.scn; los originales van en el .gitignore.
CC0 no pide credito, pero se anota en CREDITS.md de todos modos.
"""

import io
import json
import os
import shutil
import subprocess
import sys
import urllib.request

MAX_TEXTURE = 256
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "models")
API = "https://api.polyhaven.com"
AGENTE = {"User-Agent": "guadalajaja-fetch-polyhaven"}

# carpeta (dentro de models/) -> id de Poly Haven
MODELS = {
	"props/llanta": "old_tyre",           # Old Tyre, 2.9k tris (se reduce al importar)
	"props/bolsa_basura": "trashbag",     # Trashbag, 4.5k tris (se reduce al importar)
}

IMPORT_FILE = """[remap]

importer="scene"
importer_version=1

[params]

import_script/path="res://scripts/map/TiendaPostImport.gd"
"""


def _bajar(url):
	with urllib.request.urlopen(urllib.request.Request(url, headers=AGENTE), timeout=60) as r:
		return r.read()


def _textura(datos, salida):
	# ImageMagick si esta (como fetch_sketchfab.py); si no, Pillow
	if shutil.which("magick"):
		subprocess.run(["magick", "-", "-resize", f"{MAX_TEXTURE}x{MAX_TEXTURE}>", "-quality", "90", salida],
			input=datos, check=True)
		return
	from PIL import Image
	with Image.open(io.BytesIO(datos)) as imagen:
		imagen = imagen.convert("RGB")
		imagen.thumbnail((MAX_TEXTURE, MAX_TEXTURE), Image.LANCZOS)
		imagen.save(salida, quality=90)


def bajar(carpeta, ident):
	destino = os.path.join(OUT_DIR, carpeta)
	os.makedirs(os.path.join(destino, "textures"), exist_ok=True)
	archivos = json.loads(_bajar(f"{API}/files/{ident}"))
	g = archivos["gltf"]["1k"]["gltf"]
	gltf = json.loads(_bajar(g["url"]))
	incluidos = g["include"]

	# El .bin con otro nombre: scene.bin (el .gitignore y hornear_modelos lo esperan asi)
	for buf in gltf.get("buffers", []):
		uri = buf["uri"]
		with open(os.path.join(destino, "scene.bin"), "wb") as f:
			f.write(_bajar(incluidos[uri]["url"]))
		buf["uri"] = "scene.bin"

	# Solo la textura de color: los materiales pierden normal, ORM y AO
	usadas = set()
	for mat in gltf.get("materials", []):
		for clave in ("normalTexture", "occlusionTexture", "emissiveTexture"):
			mat.pop(clave, None)
		pbr = mat.setdefault("pbrMetallicRoughness", {})
		pbr.pop("metallicRoughnessTexture", None)
		if "baseColorTexture" in pbr:
			usadas.add(pbr["baseColorTexture"]["index"])
	texturas = gltf.get("textures", [])
	imagenes = gltf.get("images", [])
	nuevas_tex, nuevas_img, mapa = [], [], {}
	for i in sorted(usadas):
		tex = dict(texturas[i])
		img = dict(imagenes[tex["source"]])
		nombre = f"{os.path.basename(carpeta)}_baseColor.jpg" if len(usadas) == 1 else f"{os.path.basename(carpeta)}_{i}_baseColor.jpg"
		_textura(_bajar(incluidos[img["uri"]]["url"]), os.path.join(destino, "textures", nombre))
		img["uri"] = "textures/" + nombre
		img.pop("mimeType", None)
		tex["source"] = len(nuevas_img)
		nuevas_img.append(img)
		mapa[i] = len(nuevas_tex)
		nuevas_tex.append(tex)
	for mat in gltf.get("materials", []):
		pbr = mat.get("pbrMetallicRoughness", {})
		if "baseColorTexture" in pbr:
			pbr["baseColorTexture"]["index"] = mapa[pbr["baseColorTexture"]["index"]]
	gltf["textures"] = nuevas_tex
	gltf["images"] = nuevas_img

	with open(os.path.join(destino, "scene.gltf"), "w") as f:
		json.dump(gltf, f)
	with open(os.path.join(destino, "scene.gltf.import"), "w") as f:
		f.write(IMPORT_FILE)
	info = json.loads(_bajar(f"{API}/info/{ident}"))
	autores = ", ".join(info.get("authors", {}).keys())
	with open(os.path.join(destino, "LICENSE_polyhaven.txt"), "w") as f:
		f.write(f"{info.get('name', ident)} de {autores}\nhttps://polyhaven.com/a/{ident}\nCC0 1.0 (dominio publico)\n")
	print(f"{carpeta}: {info.get('name', ident)} ({autores}), {len(nuevas_img)} textura(s)")


def main():
	pedidas = sys.argv[1:] or list(MODELS)
	for carpeta in pedidas:
		if carpeta not in MODELS:
			print(f"no esta en MODELS: {carpeta}")
			continue
		bajar(carpeta, MODELS[carpeta])


if __name__ == "__main__":
	main()
