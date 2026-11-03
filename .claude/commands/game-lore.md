---
description: Adds or updates a single world lore entry (faction, location, NPC, or event) — validates against existing lore for consistency, applies the right template, and updates docs/lore.md (y docs/personajes.md).
argument-hint: type and name (e.g. "faction The Iron Court", "location Ashfall Crossing", "npc Mira the Keeper", "event The Founding War")
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

# Game Lore — Lore Entry Command

## Phase 0 — Context Load (silent, mandatory)

Execute in this exact order:

1. READ `.claude/skills/narrative-worldbuilding/SKILL.md`
2. READ `.claude/skills/narrative-quest-narrative-coherence/SKILL.md`
3. READ `docs/lore.md (y docs/personajes.md)`
   - If it does NOT exist: output `⛔ Cannot proceed. docs/lore.md (y docs/personajes.md) not found. Run /game-dev:game-architect first to generate the world foundation, or create docs/lore.md (y docs/personajes.md) manually with a World Overview, Factions, Locations, Characters, and History sections.` and stop.
4. Parse `$ARGUMENTS` to detect entry type:
   - Starts with "faction" → FACTION mode
   - Starts with "location" → LOCATION mode
   - Starts with "npc" or "character" → NPC mode
   - Starts with "event" or "history" → HISTORICAL EVENT mode
   - Not recognized → ask: "What type of lore entry is this? Reply with: faction / location / npc / event"
5. Extract the entry name from `$ARGUMENTS` (the text after the type keyword)
6. READ `docs/misiones.md` if it exists (for cross-reference in Phase 4)

## Phase 1 — Consistency Check (mandatory before creating anything)

Validate the proposed entry against the existing content of `docs/lore.md (y docs/personajes.md)`.

Run through each check — output the checklist explicitly:

```
## Consistency Check: [entry type] — [entry name]

[ ] No name collision — "[name]" does not already exist in world-lore.md
[ ] Faction alignment — faction relationships don't contradict existing alliances/enmities
[ ] Geographic plausibility — location fits within established world geography
[ ] NPC faction match — NPC's stated faction exists and their alignment is consistent with it
[ ] Timeline consistency — any historical events respect the established world timeline
[ ] Tone consistency — entry matches the world's established tone (dark/whimsical/gritty/etc.)
```

Mark each as ✅ (passed), ⚠️ (minor concern — proceed with note), or 🔴 (conflict — must resolve before proceeding).

For any 🔴 conflict:
Output `⚠️ LORE CONFLICT: [describe the contradiction clearly]. Proposed resolution: [specific suggestion that would fix it]. Proceed with the proposed fix? (confirm to continue with correction)`

Wait for user confirmation before continuing if any 🔴 conflicts exist.

## Phase 2 — Entry Creation

Apply the appropriate template based on the entry type detected in Phase 0:

### FACTION template:

```markdown
## Faction: [name]

**Public goal:** [what they publicly claim to want — the face they show to others]
**Hidden goal:** [what they actually want — internal motivation the player can discover]
**Territory:** [regions, cities, or areas they control or heavily influence]
**Resources:** [what they control: trade goods, military, information, wealth, magic, tech]
**Allies:** [faction names — and why they're allied]
**Enemies:** [faction names — and what the conflict is about]
**Neutral toward:** [faction names — and why there's no strong relationship]
**Gameplay role:** [how players interact with them: quest giver, merchant, enemy, obstacle, ally]
**Internal politics:** [sub-factions, internal tensions, succession disputes, or ideological splits]
**Distinguishing trait:** [one thing that makes this faction memorable and unique]
```

### LOCATION template:

```markdown
## Location: [name]

**Region:** [which larger geographic area this is part of]
**Type:** [city / dungeon / wilderness / settlement / landmark / ruin / outpost]
**Climate & Terrain:** [brief environmental description that affects gameplay/mood]
**Notable NPCs:** [named characters who live, work, or frequent this location]
**Factions present:** [which factions control or operate here, and in what capacity]
**Gameplay role:** [what players do here: quest hub, combat zone, trading post, dungeon, safe house]
**Lore significance:** [why this location matters to world history or current events]
**Atmosphere note:** [1-2 sentences on the feeling — helps with future dialogue and description writing]
```

### NPC template:

```markdown
## NPC: [name]

**Faction:** [primary faction affiliation — must exist in world-lore.md Factions section]
**Role:** [their function: merchant, quest giver, antagonist, ally, informant, guard, etc.]
**Personality:** [3 traits that define how they interact — keep it concrete, not vague]
**Current status:** [alive/dead/unknown, current location, what they're actively doing]
**Relationships:**
  - [NPC name]: [relationship type and why]
  - [Faction name]: [loyal / disillusioned / secretly opposed / etc.]
**Quest involvement:** [quests they're part of — reference quest-registry.md IDs if applicable, or "none yet"]
**Voice & Dialogue notes:** [speech patterns, vocabulary level, what topics they avoid, verbal tics]
**Personal secret:** [something about them the player can discover — makes them feel real]
```

### HISTORICAL EVENT template:

```markdown
## Event: [name]

**When:** [relative timeline — "~50 years ago", "before the Founding", "during the Third Era", etc. — use the world's own time markers]
**What happened:** [factual summary — 2-4 sentences, no editorializing]
**Factions involved:** [who participated and what role they played]
**Casualties/Cost:** [scale of the event — optional, include if significant]
**Consequences:** [direct effects on the present world: borders changed, factions formed/dissolved, power shifted, locations destroyed]
**Player-facing traces:** [ruins, surviving NPCs, items, architecture, or lore fragments the player can find today]
**Common knowledge vs. hidden truth:** [what most people believe happened vs. what actually happened — optional but adds depth]
```

Fill in all fields completely. Do not leave placeholders — if a field is genuinely unknown, write "Unknown / to be determined" and flag it as an open question.

## Phase 3 — Update docs/lore.md (y docs/personajes.md)

Append the completed entry to the appropriate section of `docs/lore.md (y docs/personajes.md)`:
- Factions → append under the Factions section
- Locations → append under the Locations/Geography section
- NPCs/Characters → append under the Characters/Notable NPCs section
- Events → append under the History/Timeline section

If the appropriate section doesn't exist in world-lore.md, create it with a clear heading.

**Bidirectional consistency:** If the new entry creates a relationship with an existing entry (e.g., "Enemy of The Silver Hand"), find The Silver Hand's entry in world-lore.md and add the reciprocal relationship note:
```
// Updated: [The Silver Hand] entry — added enemy relationship with [new faction]
```

After writing, output:
```
Updated: docs/lore.md (y docs/personajes.md)
  ✅ Added [type]: [name]
  [If any existing entries modified]: ✏️ Updated: [entry name] — [what was added]
```

## Phase 4 — Cross-Reference Check

If `docs/misiones.md` exists:
- Scan it for any references to the entry name (or close variants)
- List any quests that now directly reference or are affected by this new entry

Output:
```
🔗 Quest registry cross-reference:
  Quests referencing this entry: [list with quest IDs and names, or "none found"]
  [If quests reference it]: Consider running /game-quest to update those quests with the new lore.
```

If `docs/misiones.md` doesn't exist:
```
🔗 Quest registry: not yet created — run /game-quest to start creating quests that use this lore.
```

---

## Hard Constraints

1. **Never skip Phase 1** — writing new lore without a consistency check leads to contradictions
2. **Never use vague personality traits** for NPCs ("nice", "mean", "mysterious") — always use concrete, actionable descriptions
3. **Faction relationships must be bidirectional** — if faction A is enemy of faction B, check faction B and update if needed
4. **Tone must match the world** — extract the tone from world-lore.md before writing; whimsy in a grim dark world is a bug
5. **Never invent new factions or major locations inside an NPC or Event entry** — if a new faction is implied, stop and ask if user wants to run game-lore for that faction first
6. **All timeline references must use the world's own time markers** — never use real-world dates (AD/BC/CE)
