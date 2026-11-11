# Textura de lona de rafia (tejido plastico) que se repite, en gris claro para teñirla en Godot.
# Corre en Blender (trae numpy): blender --background --python textura_lona.py -- models/tianguis/carpas
# Escribe lona.png y lona_normal.png.
import numpy as np, bpy, sys, os
SAL = sys.argv[sys.argv.index("--") + 1]
N = 512
rng = np.random.default_rng(3)
y, x = np.mgrid[0:N, 0:N].astype(np.float32)
p = 8
cx, cy = (x // p).astype(int), (y // p).astype(int)
arriba = (cx + cy) % 2 == 0
fx, fy = (x % p) / p, (y % p) / p
tej = np.where(arriba, 0.86 + 0.14 * np.sin(fy * np.pi), 0.86 + 0.14 * np.sin(fx * np.pi))
tej *= 0.95 + 0.05 * rng.random((N // p + 1, N // p + 1))[cy, cx]
tej *= np.where((x % p < 1) | (y % p < 1), 0.88, 1.0)

def ruido(celdas, semilla):
    """Ruido suave que se repite: rejilla aleatoria con interpolacion bilineal envuelta."""
    g = np.random.default_rng(semilla).random((celdas, celdas)).astype(np.float32)
    u, v = x / N * celdas, y / N * celdas
    i0, j0 = u.astype(int) % celdas, v.astype(int) % celdas
    i1, j1 = (i0 + 1) % celdas, (j0 + 1) % celdas
    fu, fv = u % 1, v % 1
    fu, fv = fu * fu * (3 - 2 * fu), fv * fv * (3 - 2 * fv)
    return (g[j0, i0] * (1 - fu) + g[j0, i1] * fu) * (1 - fv) + (g[j1, i0] * (1 - fu) + g[j1, i1] * fu) * fv

mugre = ruido(8, 1) * 0.5 + ruido(32, 2) * 0.3 + ruido(128, 4) * 0.2
manchas = np.clip((ruido(6, 5) * 0.7 + ruido(24, 6) * 0.3 - 0.6) * 4, 0, 1)
arr = 0.5 + 0.5 * np.sin((x + y * 0.3) / N * np.pi * 8 + ruido(4, 9) * 6)
val = np.clip(tej * (0.86 + 0.14 * mugre) * (1 - 0.2 * manchas) * (0.93 + 0.07 * arr), 0, 1)

def guardar(nombre, rgb):
    im = bpy.data.images.new(nombre, N, N, alpha=False)
    px = np.dstack([rgb, np.ones((N, N, 1), np.float32)])[::-1].ravel()
    im.pixels.foreach_set(px)
    im.filepath_raw = os.path.join(SAL, nombre + ".png")
    im.file_format = "PNG"
    im.save()
    print("TEXTURA", im.filepath_raw)

guardar("lona", np.dstack([val] * 3))
a = tej / tej.max()
dx = (np.roll(a, -1, 1) - np.roll(a, 1, 1)) * 1.5
dy = (np.roll(a, -1, 0) - np.roll(a, 1, 0)) * 1.5
n = np.dstack([-dx, dy, np.ones_like(a)])
n /= np.linalg.norm(n, axis=2, keepdims=True)
guardar("lona_normal", n * 0.5 + 0.5)
