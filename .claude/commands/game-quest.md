---
description: Designs a single quest end-to-end — coherence check, objective tree, quest brief, and registry entry. Requires docs/lore.md (y docs/personajes.md) and docs/misiones.md.
argument-hint: quest name (e.g. "The Merchant's Debt", "Rescue at the Crossroads")
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

# Game Quest — Quest Designer Command

## Phase 0 — Context Load (silent, mandatory before producing any output)

Execute in this exact order:

1. READ `docs/lore.md (y docs/personajes.md)`
   - If it does NOT exist: output `⛔ Cannot proceed. docs/lore.md (y docs/personajes.md) not found. Run /game-dev:game-architect first to generate the world foundation, or create docs/lore.md (y docs/personajes.md) manually.` and stop.
2. READ `docs/misiones.md`
   - If it does NOT exist: create it using the template at `.claude/skills/narrative-quest-narrative-coherence/templates/quest-registry.md`. If that template is missing, create an empty registry with headers: Quest ID | Name | Type | NPC | Location | Factions | Rewards | Prerequisites | Arc.
3. READ `.claude/skills/narrative-quest-narrative-coherence/SKILL.md`
4. READ `.claude/skills/design-quest-mission-design/SKILL.md`
5. READ `docs/mvp-first-draft.md` if it exists (for economy and progression context — optional)

## Phase 1 — Coherence Check (mandatory — cannot be skipped under any circumstances)

Run the 5-step check from `quest-narrative-coherence` against `$ARGUMENTS` (the proposed quest name/concept):

**Step 1: Load World State** — already done in Phase 0. Extract from world-lore.md:
- Active factions and their relationships
- Major characters and their current status
- Available locations
- Active conflicts, alliances, treaties
- World timeline

**Step 2: Check Quest Registry** — from docs/misiones.md identify:
- NPCs already assigned to existing quests (cannot be in two places at once)
- Locations that are already primary quest hubs
- Reward amounts already distributed (economy inflation check)

**Step 3: Validate Proposed Quest** — verify:
- [ ] No faction/character/location name conflicts with existing quests
- [ ] No contradictions with established lore
- [ ] Referenced characters are alive and available
- [ ] Referenced locations exist in the world
- [ ] Proposed reward scale is consistent with existing economy

**Step 4: Confirm Lore Reference** — the quest MUST:
- Reference at least one established lore element (character, faction, location, event)
- Build upon or advance at least one existing narrative thread

**Step 5: Prepare Registry Entry** — draft the registry row (will be written in Phase 5 after the quest is finalized)

Output a **Coherence Report** BEFORE proceeding to Phase 2:

```
## Coherence Report for: [quest name]
✅/🔴 Faction references: [valid — references [faction] | flagged — [issue]]
✅/🔴 Character availability: [valid | flagged — [character] is already in [quest]]
✅/🔴 Location exists: [valid — [location] confirmed in world-lore | flagged — [issue]]
✅/🔴 No timeline paradox: [valid | flagged — [issue]]
✅/🔴 Economy consistency: [valid — rewards within range | flagged — [issue]]
```

If ANY item is flagged 🔴: **STOP**. Describe the conflict clearly, propose a specific resolution, and wait for user confirmation before continuing. Do not proceed to Phase 2 until all conflicts are resolved.

## Phase 2 — Quest Type Selection

Based on the quest name/concept and world context, recommend one type from the taxonomy:

| Type | Best for |
|------|---------|
| Main Story | Advances primary narrative arc |
| Side Quest | Optional, enriches world |
| Chain Quest | Multi-step, each unlocks next |
| Branching | Player choice determines outcome |
| Repeatable | Can be done multiple times |
| Discovery | Triggered by exploration |
| Social | Requires other players |
| Timed | Must complete within deadline |
| Collection | Gather a set of items |
| Escort/Protect | Keep something safe |

Ask **at most 1 question** if the type is genuinely ambiguous. If the context makes it clear, proceed without asking.

## Phase 3 — Objective Tree

Apply the principles from `quest-mission-design`:
- Every quest must present meaningful choices (Sid Meier)
- At least 2 ways to complete any significant quest (Jonathan Blow — anti-pattern: "one true path")
- Quest must reveal something about the world (Miyazaki)
- No fetch quests without narrative purpose

Output a Mermaid flow diagram showing the objective tree:

```mermaid
flowchart TD
  A["Objective 1: [description]"] --> B{"Choice Point"}
  B --> C["Path A: [description]"]
  B --> D["Path B: [description]"]
  C --> E["Outcome A: [world consequence]"]
  D --> F["Outcome B: [world consequence]"]
```

Include sub-objectives (required vs optional bonus) where appropriate. If the quest is a simple Side Quest or Discovery type, a linear flow is acceptable — but note if it has no branching and explain why it's acceptable given the type.

## Phase 4 — Quest Brief

Output the complete quest brief in GDD section format:

```markdown
## Quest: [name]

**Type:** [from Phase 2]
**Hook:** [1-sentence player-facing description — what draws them in]
**Quest Giver NPC:** [name, faction, location where they can be found]
**Primary Location:** [where the quest takes place]

### Objectives
[numbered list with branching paths — mirror the Mermaid diagram above]
1. [Required objective]
   - 1a. [Choice A description + consequence]
   - 1b. [Choice B description + consequence]
2. [Final objective — varies based on choice above]

### Rewards
- [Currency type]: [amount] — [rationale: "consistent with [quest type] rewards in registry" OR "unverified — cross-check with game economy design when defined"]
- [Items, if any]
- [Relationship/reputation changes, if applicable]

### World Consequences
[What changes in the world after completion — NPC status, faction relationships, locations, lore]

### Prerequisites
[Other quests that must be complete first, or "None"]

### Failure State
[What happens if the player abandons or fails the quest]

### Economy Note
[Reward amount cross-referenced against mvp-first-draft.md economy params OR flagged as: "⚠️ Economy not yet defined — validate rewards when running /game-dev:game-balance"]
```

## Phase 5 — Register Quest

Append the completed quest to `docs/misiones.md` in the registry format:

```markdown
| [QID] | [Quest Name] | [Type] | [Giver NPC] | [Location] | [Factions Affected] | [Rewards Summary] | [Prerequisites] | [Story Arc] |
```

After writing the entry, output:

```
✅ Quest registered in docs/misiones.md
```

If the quest introduces any NPC or location not currently in `docs/lore.md (y docs/personajes.md)`:
```
⚠️ New [NPC/Location] introduced: [name]
   → Run /game-lore npc [name] to add them to world-lore.md
```

---

## Hard Constraints

1. **Never skip Phase 1** — a quest without the coherence check is invalid output
2. **Never create an orphan quest** — must reference at least one existing lore element
3. **Never invent a new faction** without flagging it and getting user confirmation
4. **Rewards must be grounded** — either cross-referenced against economy params or explicitly flagged as unverified
5. **At least 2 completion paths** for Main Story, Side Quest, Chain, and Branching types
6. **Register every quest** — Phase 5 is not optional
