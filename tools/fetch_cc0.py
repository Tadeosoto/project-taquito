"""Baja assets CC0 que no vienen de Sketchfab (hoy: las animaciones de Quaternius).

    python3 -I tools/fetch_cc0.py

Cada zip se descomprime en su carpeta de DESCARGAS quedandose solo con los
formatos que Godot usa (EXTENSIONES) y la licencia (SUELTOS); si la carpeta ya existe se
salta. El credito se agrega a CREDITS.md aunque CC0 no lo pida.
"""

import io
import os
import sys
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# carpeta (dentro del proyecto) -> (nombre, url del zip, pagina)
DESCARGAS = {
	"models/animaciones/quaternius_ual1": (
		"Universal Animation Library (Standard) de Quaternius",
		"https://opengameart.org/sites/default/files/universal_animation_librarystandard.zip",
		"https://opengameart.org/content/universal-animation-library"),
	"models/animaciones/quaternius_ual2": (
		"Universal Animation Library 2 (Standard) de Quaternius",
		"https://opengameart.org/sites/default/files/universal_animation_library_2standard.zip",
		"https://opengameart.org/content/universal-animation-library-2"),
}

# Los zips traen copias para Unity/Unreal (.fbx) e imagenes de instrucciones
EXTENSIONES = (".glb", ".gltf", ".bin")
SUELTOS = ("License.txt", "Godot_Setup.png")

CREDIT_HEADER = "## Animaciones (`models/animaciones/`, CC0)"


def main() -> None:
	credits = []
	for folder, (name, url, page) in DESCARGAS.items():
		credits.append(f"- [{name}]({page}), licencia CC0 (`{folder}/`).")
		dest = os.path.join(ROOT, folder)
		if os.path.exists(dest):
			print(f"  ya estaba: {folder}")
			continue
		print(f"  bajando {folder}...")
		request = urllib.request.Request(url, headers={"User-Agent": "taquito-assets/1.0"})
		with urllib.request.urlopen(request, timeout=600) as response:
			data = response.read()
		kept = 0
		with zipfile.ZipFile(io.BytesIO(data)) as archive:
			for info in archive.infolist():
				if info.is_dir() or not (info.filename.lower().endswith(EXTENSIONES)
						or os.path.basename(info.filename) in SUELTOS):
					continue
				target = os.path.normpath(os.path.join(dest, info.filename))
				if not target.startswith(dest + os.sep):
					sys.exit(f"ERROR: ruta rara en el zip de {folder}: {info.filename}")
				os.makedirs(os.path.dirname(target), exist_ok=True)
				with archive.open(info) as source, open(target, "wb") as out:
					out.write(source.read())
				kept += 1
		print(f"    {kept} archivos")

	credits_path = os.path.join(ROOT, "CREDITS.md")
	with open(credits_path, encoding="utf-8") as f:
		text = f.read()
	new_lines = [line for line in credits if line not in text]
	if new_lines:
		if CREDIT_HEADER not in text:
			text = text.rstrip() + f"\n\n{CREDIT_HEADER}\n\n"
		# Las lineas nuevas van al final de su seccion
		start = text.index(CREDIT_HEADER)
		end = text.find("\n## ", start + len(CREDIT_HEADER))
		end = len(text) if end < 0 else end
		section = text[start:end].rstrip() + "\n" + "\n".join(new_lines) + "\n"
		text = text[:start] + section + ("\n" + text[end:].lstrip("\n") if end < len(text) else "")
		with open(credits_path, "w", encoding="utf-8") as f:
			f.write(text)
	print("OK")


if __name__ == "__main__":
	main()
