# Catálogo de grafitis

Cada barda (`scripts/map/MapBardas.gd`), fachada de casa modelo (`MapCasas.gd`) y muro de bodega (`MapBodegas.gd`) que lleva grafiti toma un diseño al azar de esta carpeta (el atlas lo arma `scripts/map/Calcomanias.gd`). Para agregar uno, basta con poner aquí la imagen y abrir o reimportar el proyecto (`godot --path . --headless --import`). No hay que tocar código.

## Cómo debe ser el diseño

- **Formato**: PNG (también sirven WEBP y JPG, pero esos no tienen transparencia).
- **Fondo transparente**: lo transparente no se dibuja (alfa < 50 %), así que solo se ve la pinta y debajo queda la barda.
- **Recortado a lo que ocupa**: el ancho y el alto de la imagen son la forma del grafiti en la barda. Si sobra espacio transparente alrededor, el grafiti sale más chico de lo que parece.
- **Tamaño**: lo ideal es de 32 a 128 px de lado. Las imágenes más grandes se reducen a 128 px sin suavizar, para que sigan pixeleadas (look PS1). Una barda de 2.5 m mide 64 px en las texturas del mapa.
- **Colores**: se ven tal cual, porque no se tiñen con el color de la barda. Encima se pone la mugre del deterioro de la zona.
- **Nombre**: cualquiera. Los diseños se ordenan por nombre, así que el mismo catálogo siempre da los mismos grafitis en las mismas bardas. Agregar o quitar diseños cambia qué grafiti sale, pero no los boquetes ni la base de las bardas.

## Cómo se ponen

- Cada lado de cada panel de barda (2.5 m entre castillos) puede llevar un grafiti. La probabilidad es mayor en las zonas con más deterioro (35 % a 95 %).
- Su ancho va del 55 % al 95 % del panel, sin estirarse: el alto sale de la proporción de la imagen y nunca pasa del 85 % del alto de la barda.
- Solo el 10 % de los rótulos de propaganda (`../propaganda/`) tienen un grafiti encima (`GRAFITI_SOBRE_ROTULO` en `MapBardas.gd`).

## Archivos generados

`grafiti_hoja_NN.png` (piezas de colores) y `grafiti_firma_NN.png` (firmas, casi todas negras y algunas rojas o azules) los recorta `python3 -I tools/map_import/recortar_calcomanias.py` de las hojas de `Publicidad de barda y grafittis/`. Si se vuelven a recortar, solo se reescriben esos; los demás archivos de esta carpeta no se tocan.
