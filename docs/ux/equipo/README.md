# Maqueta: pantalla de Equipo (2026-11-26)

Idea, no diseño final (la UX la hará alguien más). Estilo menú de Zelda OoT con arte propio:
una fila por tipo (Filo, Pesadas, De fuego x2, Armadura, Botas, Amuletos), columnas I–IV de
mejora más dos ★ para el equipo escondido en el mapa (lista tentativa en `docs/items.md` §8),
y seis espacios equipados (dos amuletos).

Idea pendiente de dibujar: tres "Bolsillos" para consumibles (Curar Q / D-pad ←,
Buff F o 4 / D-pad ↑, Lanzar 3 / D-pad →; tocar usa, mantener cambia dentro de la familia),
con un HUD de tres iconos con su cuenta en la esquina.

Regenerar (PIL, desde la raíz del repo):

    python3 docs/ux/equipo/maqueta_equipo.py . docs/ux/equipo/maqueta_equipo.png docs/ux/equipo

Los iconos de las pistolas (`armas/`) son capturas de modelos que ya no están en el repo.
