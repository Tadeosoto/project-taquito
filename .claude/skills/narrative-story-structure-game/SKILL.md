---
name: narrative-story-structure-game
description: >-
  Use when designing interactive narratives, branching storylines, player agency systems, non-linear story structures, or act frameworks for games. Triggers: branching narrative, player agency, story arc, interactive story, dialogue.
---

> **Adaptación a Guadalajaja (manda sobre todo lo de abajo).** Copiado de `fcsouza/agent-skills` (plugin `game-dev`, commit a06a4d1, MIT: `.claude/skills/LICENSE-game-dev.txt`) y adaptado a este proyecto.
>
> - **Los archivos de este proyecto.** Donde abajo dice `world-lore.md` o `docs/world-lore.md`, usa `docs/lore.md` (el mundo, el régimen, el culto, la línea de tiempo) y `docs/personajes.md` (las voces, con su querer, secreto y precio). Donde dice `quest-registry.md` o `docs/quest-registry.md`, usa `docs/misiones.md`. Lo que da o cobra una misión está en `docs/items.md`, y la economía y las mecánicas en `docs/especificaciones.md`; `docs/mvp-first-draft.md` y `MEMORY.md` no existen, así que ahí no busques economía. No crees `world-lore.md`, `quest-registry.md`, `docs/characters/` ni `docs/stories/`: lo nuevo va en la sección que le toca del doc que ya existe.
> - **El grafo del lore.** `docs/graphify-out/graph.json` es un grafo de los seis docs de narrativa (lore, personajes, misiones, items, especificaciones, revisión). Antes de leer un doc entero, pregúntale desde la raíz con `graphify query "<pregunta>" --graph docs/graphify-out/graph.json` (o `graphify explain "<nodo>"` / `graphify path "<A>" "<B>" --undirected` con el mismo `--graph`): te dice qué secciones tocan el tema, y lees solo esas. Puede ir atrasado: si choca con el doc, manda el doc. Si cambias un doc de narrativa, avisa que hay que rehacer el grafo con `/graphify docs --update`.
> - **Las reglas de los docs ganan.** Antes de escribir, lee "Cómo usar este documento" del doc que vas a tocar y síguelo: etiquetas ✅ Canon / 💡 Propuesta / ❓ Abierto (🧱 Ya existe en misiones), la regla de oro del lore ("¿qué gana GelA?"), la regla de todo personaje (un querer, un secreto y un precio; si no, es habitante) y la regla de toda misión (quién la da, qué se hace, cuánto paga, qué riesgo tiene y qué sistema reusa). Las plantillas de `templates/` son guía; el formato de los docs manda.
> - **Nada nuevo es canon.** Todo lo que propongas entra como 💡 Propuesta. Nunca marques algo ✅ Canon ni cambies algo que ya es ✅ sin que el usuario lo pida: ese cambio se habla con el equipo. Las preguntas abiertas van a la sección de preguntas abiertas del doc.
> - **Choques.** Si el lore y la spec se contradicen, gana la spec en lo técnico y el lore en lo narrativo, y se arregla en uno de los dos. Avisa del choque, no lo dejes.
> - **Idioma y tono.** Escribe en español informal, como los docs, y respeta la sección "1. Cómo se cuenta" de `docs/lore.md`. Los informes de coherencia también van en español.
> - **Al terminar,** actualiza la "Última actualización" del doc que tocaste. Las misiones siguen además el procedimiento de "6. Cómo se agrega una misión" de `docs/misiones.md`. No se instaló lo demás del plugin (`game-architect`, `game-balance`, `game-economy-design`, `game-design-fundamentals`, `elevenlabs-sound-music`, `postgres-game-schema`): ignora esas referencias.

# Story Structure for Games

## Purpose

Branching narratives, player agency, non-linear story structure, and act frameworks adapted for interactive media. Genre-agnostic — works for any game with narrative elements.

## When to Use

Trigger: story structure, branching narrative, player agency, non-linear story, act structure, story beats, narrative arc, dialogue tree, multiple endings, player choice, consequence system, narrative design

## Prerequisites

- `quest-narrative-coherence` — ensures all story content is consistent
- `worldbuilding` — provides the world context for the story

## Core Principles

> Hideo Kojima: "Games can tell stories that no other medium can — stories where the audience is the protagonist."
> Ken Levine: "Narrative should emerge from systems, not just scripted sequences."
> Hidetaka Miyazaki: "The best stories are the ones players piece together themselves."

1. **Player agency is sacred** — the player must feel their choices matter; never invalidate a meaningful decision
2. **Show consequences** — choices without visible consequences feel meaningless; show the impact
3. **Non-linear doesn't mean random** — structure the narrative so any path through it feels intentional
4. **Environmental storytelling first** — the world tells the story; dialogue and cutscenes support it (Miyazaki)
5. **Dramatic structure still applies** — even branching narratives need tension, climax, and resolution
6. **Multiple endings must all feel earned** — no "good ending" and "bad ending"; each ending should reflect the player's journey
7. **Pacing is controlled by the player** — design for players who rush AND players who explore

## Narrative Frameworks

### Three-Act Structure (Adapted for Games)
```
Act 1 — Setup (10-20% of game)
  Hook → World introduction → Inciting incident → Player given agency

Act 2 — Confrontation (60-70% of game)
  Rising challenges → Major choices → Consequences compound → Midpoint twist

Act 3 — Resolution (10-20% of game)
  Climax → Final choice → Resolution shaped by prior decisions → Denouement
```

### Branching Narrative Model
```
         [Start]
        /       \
    [Choice A] [Choice B]
      /    \      \
  [A1]    [A2]  [B1]
    \      |     /
     [Convergence Point]
        /       \
   [Final A]  [Final B]
```

### Kishōtenketsu (Eastern Structure — No Conflict Required)
```
Ki (Introduction) → Shō (Development) → Ten (Twist/Revelation) → Ketsu (Conclusion)
```

## Cross-References

- `quest-narrative-coherence` — story consistency validation
- `worldbuilding` — world context
- `character-design-narrative` — character arcs within the story
- `quest-mission-design` — quests as story delivery mechanism

## Pitfalls & Anti-Patterns

- **"Illusion of choice"** — choices that all lead to the same outcome; players notice and feel cheated
- **"Ludonarrative dissonance"** — gameplay contradicts the story (hero kills 500 people then mourns one death)
- **"Cutscene prison"** — long non-interactive sequences that remove player agency
- **"Exposition dump"** — characters explaining plot instead of showing it
- **"Disconnected side stories"** — narrative content that feels irrelevant to the main arc

## Designer Philosophy

**Hideo Kojima** (Metal Gear Solid): Games have a unique narrative advantage — the player IS the character. Use this. Break the fourth wall. Make the player's real-world actions part of the story. The controller, the save file, the screen itself can all be narrative tools.

**Ken Levine** (BioShock): "Would you kindly" works because it uses game mechanics as narrative. The best game stories are inseparable from the gameplay — they can't be a movie, they can't be a book. They can ONLY be a game.

**Hidetaka Miyazaki** (Dark Souls): Not every player needs to understand the story. Layer narrative so casual players get the broad strokes, and dedicated players who read item descriptions and explore every corner find a deeper, richer story beneath.

## Sources

- "Narrative Design for Indie Games" — GDC 2020
- "Writing for Games" — GDC 2018
- "The Art of Game Design" — Jesse Schell, Chapters on Story
- "Interactive Storytelling" — Chris Crawford
- "Designing BioShock's Narrative" — Ken Levine, GDC 2014
