---
name: design-quest-mission-design
description: >-
  Use when designing quests, missions, objectives, quest trees, or reward structures. Requires quest-narrative-coherence check before any quest creation. Triggers: quest, mission, objectives, quest tree, rewards.
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

# Quest & Mission Design

## Purpose

Quest types, objective trees, reward structures, and mission flow design for any game genre. Enforces narrative coherence through mandatory lore checks.

## When to Use

Trigger: quest design, mission design, objectives, quest types, quest rewards, quest tree, mission flow, side quests, main quest, quest chain, objective design

## Prerequisites

- `quest-narrative-coherence` — **MANDATORY**. Read and follow the 5-step coherence check before creating ANY quest.
- `game-design-fundamentals` — core loop and reward system knowledge
- `worldbuilding` — world context for quest setting

## Core Principles

> Jonathan Blow: "Every puzzle should feel like a genuine insight, not busywork."
> Sid Meier: "A game is a series of interesting decisions."
> Hidetaka Miyazaki: "Quests should reveal the world, not just provide objectives."

1. **Every quest must pass the coherence check** — no orphan quests, no lore contradictions (see `quest-narrative-coherence`)
2. **Objectives must present meaningful choices** — not just "go here, collect that" (Sid Meier)
3. **Quest rewards must match the game economy** — cross-reference `game-economy-design` for balance
4. **Multi-path solutions** — at least 2 ways to complete any significant quest (Jonathan Blow)
5. **Quests reveal world** — every quest should teach the player something about the world (Miyazaki)
6. **Pacing matches the game** — quest length and density fit the session cadence from `game-design-fundamentals`
7. **No fetch quests without narrative purpose** — if a quest is mechanically simple, it must be narratively rich

## Step-by-Step Instructions

### 1. Run Coherence Check
Follow the 5-step check from `quest-narrative-coherence`. Load lore, check registry, validate, reference existing content, register.

### 2. Define Quest Type
Choose from the quest type taxonomy (see below).

### 3. Design Objective Tree
Map out the objectives, branching paths, and completion conditions.

### 4. Balance Rewards
Cross-reference `game-economy-design` for appropriate reward scale.

### 5. Write Quest Brief
Use the quest template in `templates/`.

### 6. Register Quest
Add to quest-registry.md per the coherence clause.

## Quest Type Taxonomy

| Type | Description | Example (abstract) |
|------|-------------|-------------------|
| Main Story | Advances primary narrative arc | "Uncover the truth about [event]" |
| Side Quest | Optional, enriches world | "Help [NPC] with [problem]" |
| Chain Quest | Multi-step, each unlocks next | "Phase 1 → Phase 2 → Phase 3" |
| Branching | Player choice determines outcome | "Side with [A] or [B]" |
| Repeatable | Can be done multiple times | "Daily challenge: [task]" |
| Discovery | Triggered by exploration | "Find [hidden thing] to unlock" |
| Social | Requires other players | "Complete [task] with a group" |
| Timed | Must complete within deadline | "Finish before [timer] expires" |
| Collection | Gather a set of items/objects | "Find all [N] pieces of [set]" |
| Escort/Protect | Keep something safe | "Protect [target] during [event]" |

## Objective Tree Structure

```
Quest: [Name]
├── Objective 1: [Required]
│   ├── Sub-objective 1a: [Required]
│   └── Sub-objective 1b: [Optional bonus]
├── Objective 2: [Choice A OR Choice B]
│   ├── Choice A: [Path with consequence X]
│   └── Choice B: [Path with consequence Y]
└── Objective 3: [Final — depends on choice above]
    ├── Outcome A: [If chose A above]
    └── Outcome B: [If chose B above]
```

## Cross-References

- `quest-narrative-coherence` — MANDATORY prerequisite
- `worldbuilding` — world context for quest setting
- `game-economy-design` — reward balancing
- `game-design-fundamentals` — core loop integration
- `character-design-narrative` — NPC involvement
- `postgres-game-schema` — quest data persistence

## Pitfalls & Anti-Patterns

- **"Go collect 10 things"** — collection quests without narrative justification
- **"Orphan quest"** — quest that connects to nothing in the world (caught by coherence check)
- **"Reward inflation"** — quest gives too much, breaking economy
- **"One true path"** — quest with only one solution removes player agency
- **"Lore dump quest"** — NPC talks for 5 minutes, player does nothing
- **"Invisible prerequisite"** — quest requires something the player can't know about

## Designer Philosophy

**Jonathan Blow** (Braid, The Witness): Every quest objective should feel like a genuine insight. If the player is just following a marker, the quest has failed. The best quests make players think, experiment, and discover.

**Sid Meier** (Civilization): Quests are decisions. "Go kill X" is not a decision. "Choose between helping faction A (gaining their trust but angering B) or helping faction B" IS a decision.

**Hidetaka Miyazaki** (Dark Souls, Elden Ring): The best quests don't announce themselves. They emerge from exploration, environmental clues, and NPC conversations. The player should feel like they discovered the quest, not that it was assigned.

## Sources

- "Designing Quests That Don't Suck" — GDC 2018
- "The Art of Game Design" — Jesse Schell, Chapter on Stories
- "Narrative Design for Indie Games" — GDC 2020
- "Quest Design in Open World Games" — GDC 2019
