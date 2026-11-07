---
name: narrative-character-design-narrative
description: >-
  Use when creating game characters, NPCs, character arcs, dialogue systems, archetypes, or character bibles. Triggers: character, NPC, dialogue, archetype, character bible, motivation arc.
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

# Character Design (Narrative)

## Purpose

Character archetypes, motivation arcs, dialogue systems, and character bibles for game characters. Genre-agnostic — applies to any game with characters, NPCs, or player-created identities.

## When to Use

Trigger: character design, NPC design, character arc, dialogue system, character bible, character motivation, archetype, companion, antagonist, player character, voice, personality, character writing

## Prerequisites

- `worldbuilding` — characters must fit the world
- `quest-narrative-coherence` — character actions must be consistent with established lore

## Core Principles

> Hideo Kojima: "Characters should feel like they exist beyond the player's experience of them."
> Hidetaka Miyazaki: "Every character has a history. The player sees only the tip of the iceberg."
> Jenova Chen: "Characters don't need words to communicate. Presence and movement tell the story."

1. **Characters want things** — every character (NPC or player) must have a clear motivation that drives their actions
2. **Consistency over surprise** — a character acting out of established personality must be justified by narrative events
3. **Characters exist beyond the player** — NPCs should have lives, routines, and goals independent of the player's actions
4. **Show personality through action** — what a character DOES reveals more than what they SAY
5. **Flaws make characters interesting** — perfect characters are forgettable; memorable characters have contradictions
6. **Archetypes as starting points** — use archetypes for structure, then subvert or deepen them
7. **Voice consistency** — each character should have a distinct way of speaking that a player could identify without names

## Character Archetype Toolkit

| Archetype | Core Trait | Typical Role | Subversion Example |
|-----------|-----------|-------------|-------------------|
| Mentor | Wisdom | Guide player early | Mentor has hidden agenda |
| Trickster | Deception | Comic relief / chaos | Trickster is the most honest character |
| Guardian | Protection | Block progress until ready | Guardian is protecting something terrible |
| Herald | Information | Deliver news / quests | Herald's news is always wrong |
| Shadow | Opposition | Antagonist / dark mirror | Shadow is justified in their actions |
| Ally | Support | Help in challenges | Ally has their own quest that conflicts |
| Shapeshifter | Ambiguity | Uncertain loyalty | Shapeshifter is the only constant |

## Character Bible Structure

For each significant character, document:
1. **Identity**: Name, age, appearance, role, faction
2. **Motivation**: What they want (public) and what they need (hidden)
3. **History**: Backstory that explains their current state
4. **Personality**: 3-5 defining traits, speech patterns, quirks
5. **Relationships**: Connections to other characters
6. **Arc**: How they change over the story (or why they don't)
7. **Gameplay role**: What they do mechanically (quest giver, shop, companion, boss)

## Cross-References

- `worldbuilding` — characters exist within the world's rules
- `quest-narrative-coherence` — character consistency validation
- `story-structure-game` — character arcs within narrative structure
- `quest-mission-design` — characters as quest givers and participants
- `elevenlabs-sound-music` — voice acting for characters

## Pitfalls & Anti-Patterns

- **"Walking exposition"** — NPC exists only to deliver information
- **"Personality-free quest giver"** — NPC with no personality, just a quest marker
- **"Sudden betrayal"** — character betrays without foreshadowing; feels cheap
- **"One-note villain"** — antagonist with no understandable motivation
- **"Static cast"** — no character changes or grows throughout the game
- **"Everyone talks the same"** — all NPCs have identical voice/personality

## Designer Philosophy

**Hideo Kojima** (Metal Gear Solid): Characters are more than their function. The Boss, Ocelot, and Otacon all exist as complete people with histories, philosophies, and motivations. Even minor characters have enough depth that players wonder about their lives off-screen.

**Hidetaka Miyazaki** (Dark Souls, Elden Ring): The most compelling characters are the ones you piece together. Solaire's sunny optimism in a dying world, Siegmeyer's fading courage — their stories unfold through brief encounters and item descriptions, creating a bond stronger than any cutscene.

**Jenova Chen** (Journey): Sometimes the most powerful character is another player. Journey's companions communicate without words, creating genuine emotional connection through shared experience. Characters don't always need dialogue to be memorable.

## Sources

- "Creating Compelling Game Characters" — GDC 2016
- "Writing Diverse Characters" — GDC 2019
- "The Writer's Journey" — Christopher Vogler (adapted for games)
- "Character Design for Games" — GDC 2018
