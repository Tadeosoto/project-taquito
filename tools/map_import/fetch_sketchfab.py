"""Baja de Sketchfab los modelos de tiendas que usa el mapa (models/tiendas/).

Sketchfab pide cuenta para descargar: copia tu API token de
https://sketchfab.com/settings/password (seccion "API Token") y corre:

    SKETCHFAB_TOKEN=xxxx python3 -I tools/map_import/fetch_sketchfab.py

o guardalo en ~/.config/sketchfab/token. Cada modelo queda en
models/tiendas/<carpeta>/ (glTF con sus texturas, achicadas a 256 px, y un
.import que usa scripts/map/TiendaPostImport.gd para el shader PS1) y su credito se agrega a
CREDITS.md (todos son CC BY: hay que citar al autor).
Despues: asignalos en el nodo Puntos de scenes/map_test.tscn (prefabs).
"""

import glob
import io
import json
import os
import subprocess
import sys
import urllib.request
import zipfile

# Texturas PS1: nada mas grande que esto (px); Sketchfab trae hasta 2048
MAX_TEXTURE = 256

IMPORT_FILE = """[remap]

importer="scene"
importer_version=1

[params]

import_script/path="res://scripts/map/TiendaPostImport.gd"
"""

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "models", "tiendas")

# carpeta -> uid de Sketchfab. Solo los ligeros (< 45k caras); los pesados
# (Farmacias Similares 222k, elotes 2M) habria que simplificarlos en Blender.
MODELS = {
	"tienda_3b": "e3c3ac9a198349479429d5bcee2f39c9",          # Mexican Store (Tienda 3B) PSX, 1k caras
	"oxxo": "636c02e80d7f4ebea822808c002fe26b",               # Tienda Oxxo, 838
	"oxxo_abandonado": "0d9e953705b444e8b1706dc4048ca130",    # abandoned oxxo, 2k
	"oxxo_letrero": "d444a16b316b4b18b9de9c372379a83e",       # Letrero de tienda Oxxo, 570
	"farmacia_guadalajara": "d98a5671fec34796a6a5d26d3a37b83f",  # 2.7k
	"oxxo_mexican": "07f02fc1feee42e380a528f75c44613b",       # Mexican Oxxo, 7k
	"barrio_mexicano": "bd02bfb9db374065a53b1eeb168ef925",    # Small Mexican Neighborhood, 9k
	"puesto_tacos": "03046667e027461baaaa47697d502e74",       # Cara1 Puesto de Tacos, 40k
	"tacos_props": "f8bbafe18488483f8ab79bc52d1edc79",        # Tacos_ Props, 25k
}


def read_token() -> str:
	token = os.environ.get("SKETCHFAB_TOKEN", "").strip()
	path = os.path.expanduser("~/.config/sketchfab/token")
	if not token and os.path.exists(path):
		with open(path, encoding="utf-8") as f:
			token = f.read().strip()
	if not token:
		sys.exit("ERROR: falta SKETCHFAB_TOKEN (ver el inicio de este archivo)")
	return token


def get_json(url: str, token: str | None = None) -> dict:
	headers = {"User-Agent": "taquito-map-import/1.0"}
	if token:
		headers["Authorization"] = f"Token {token}"
	with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60) as response:
		return json.load(response)


def prepare_for_godot(dest: str) -> None:
	"""Achica las texturas y hace que Godot importe con TiendaPostImport (shader PS1)."""
	textures = glob.glob(os.path.join(dest, "textures", "*"))
	if textures:
		subprocess.run(["magick", "mogrify", "-resize", f"{MAX_TEXTURE}x{MAX_TEXTURE}>", *textures], check=True)
	import_path = os.path.join(dest, "scene.gltf.import")
	if not os.path.exists(import_path):
		with open(import_path, "w", encoding="utf-8") as f:
			f.write(IMPORT_FILE)


def main() -> None:
	token = read_token()
	os.makedirs(OUT_DIR, exist_ok=True)
	credits = []
	for folder, uid in MODELS.items():
		dest = os.path.join(OUT_DIR, folder)
		info = get_json(f"https://api.sketchfab.com/v3/models/{uid}")
		license_label = (info.get("license") or {}).get("label", "?")
		author = (info.get("user") or {}).get("displayName") or (info.get("user") or {}).get("username", "?")
		credits.append(f"- [{info['name']}](https://sketchfab.com/3d-models/{uid}) de {author}, "
			f"licencia {license_label} (`models/tiendas/{folder}/`).")
		if os.path.exists(dest):
			print(f"  ya estaba: {folder}")
			prepare_for_godot(dest)
			continue

		download = get_json(f"https://api.sketchfab.com/v3/models/{uid}/download", token)
		# El zip de glTF trae scene.gltf + scene.bin + textures/
		url = download["gltf"]["url"]
		print(f"  bajando {folder} ({download['gltf'].get('size', 0) / 1e6:.1f} MB)...")
		with urllib.request.urlopen(url, timeout=600) as response:
			data = response.read()
		with zipfile.ZipFile(io.BytesIO(data)) as archive:
			for name in archive.namelist():
				target = os.path.normpath(os.path.join(dest, name))
				if not target.startswith(dest + os.sep):
					sys.exit(f"ERROR: ruta rara en el zip de {folder}: {name}")
			archive.extractall(dest)
		# Godot importa license.txt como texto suelto; no hace falta en el proyecto
		license_txt = os.path.join(dest, "license.txt")
		if os.path.exists(license_txt):
			os.rename(license_txt, os.path.join(dest, "LICENSE_sketchfab.txt"))
		prepare_for_godot(dest)

	credits_path = os.path.join(ROOT, "CREDITS.md")
	with open(credits_path, encoding="utf-8") as f:
		text = f.read()
	header = "## Tiendas (`models/tiendas/`, Sketchfab)"
	if header not in text:
		text = text.rstrip() + f"\n\n{header}\n\n"
	new_lines = [line for line in credits if line not in text]
	if new_lines:
		text = text.rstrip() + "\n" + "\n".join(new_lines) + "\n"
		with open(credits_path, "w", encoding="utf-8") as f:
			f.write(text)
	print(f"OK: {len(MODELS)} modelos en {OUT_DIR}; creditos en CREDITS.md")


if __name__ == "__main__":
	main()
