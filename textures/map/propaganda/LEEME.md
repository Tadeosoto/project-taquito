# Catálogo de propaganda pintada

Las bardas del mapa (`scripts/map/MapBardas.gd`) llevan letreros pintados ("SE VENDE", bailes, fletes...): cada uno es un diseño al azar de esta carpeta. Para agregar uno, basta con poner aquí la imagen y abrir o reimportar el proyecto (`godot --path . --headless --import`). No hay que tocar código.

## Cómo debe ser el diseño

- **Formato**: PNG, WEBP o JPG.
- **Forma**: un letrero rectangular con su fondo pintado; el fondo de la imagen es el fondo del letrero. Se puede usar transparencia (por ejemplo, para letras sueltas sin fondo): lo que tenga alfa < 50 % no se dibuja.
- **Tamaño**: los diseños de aquí son de 128 × 64 px. Las imágenes más grandes se reducen a 128 px de lado sin suavizar, para que sigan pixeleadas (look PS1). Conviene dibujar sin antialias y con letras gruesas, para que se lean a lo lejos.
- **Colores**: se ven tal cual, porque no se tiñen con el color de la barda. Encima se pone la mugre del deterioro de la zona.
- **Textos inventados**: no uses nombres de partidos, negocios, marcas ni teléfonos reales.
- **Nombre**: cualquiera. Los diseños se ordenan por nombre, así que el mismo catálogo siempre da los mismos letreros en las mismas bardas. Agregar o quitar diseños cambia qué letrero sale, pero no los boquetes ni la base de las bardas.

## Cómo se ponen

- Cada lado de cada panel de barda (2.5 m entre castillos) tiene 18 % de probabilidad de llevar propaganda (`PROPAGANDA_PROB` en `MapBardas.gd`).
- Ocupa del 80 % al 95 % del ancho de dos paneles (pasa por encima del castillo de en medio) si el panel de al lado está entero; si no, de uno. No se estira y va a media altura.
- Solo el 10 % de los rótulos tienen grafiti encima (`GRAFITI_SOBRE_ROTULO`); en los demás no hay grafitis de ese lado.

## Archivos generados

`propaganda_foto_*.png` los recorta `python3 -I tools/map_import/recortar_calcomanias.py` de las fotos de bardas pintadas de `Publicidad de barda y grafittis/` (recortes en `BARDAS`). Si se vuelven a recortar, solo se reescriben esos; los demás archivos de esta carpeta no se tocan.
