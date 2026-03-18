# Game Development Methodology with Claude Code
### A framework for designing and building games from concept to code

This document captures a working methodology for designing games collaboratively with Claude Code (or any LLM coding assistant). It's tool-agnostic and genre-agnostic — the order-of-operations applies whether you're making an RPG, a platformer, a strategy game, or anything else.

---

## The Core Philosophy

**Abstract to concrete, grammar before sentences, design before code.**

Every step moves from the broadest decisions to the most specific. You never design a specific ability before you've defined what abilities ARE. You never write code before you've defined what the code needs to do in plain english. You never pick a detail before the system it belongs to has a shape.

**The human designs, the LLM generates and implements.** The human brings taste, vision, and creative direction. The LLM brings volume, technical knowledge, and consistency. The human says "I want X" and "not Y." The LLM proposes how, generates options, identifies gaps, and writes the code. Neither is the sole author.

---

## Phase 1: Seed the Project

**Goal:** Get everything out of your head and into a document the LLM can reference.

Write (or dictate) a seed document covering:
- **Who you are** — your skills, what you will and won't do, how you like to work
- **What the game is** — genre, core fantasy, elevator pitch
- **What you love** — specific mechanics, feelings, experiences you want the player to have
- **What you hate** — anti-goals, things to avoid, mechanics that turn you off
- **Reference games** — what to learn from each, what NOT to copy
- **Constraints** — engine, art assets, team size, timeline, budget
- **Previous attempts** — what you've tried before and why it didn't work (if applicable)

Don't worry about completeness or polish. This is a brain dump. The LLM will ask clarifying questions.

**Output:** A seed document and/or persistent memory entries that give the LLM full context on who you are and what you're building.

---

## Phase 2: Define the Core Loop

**Goal:** Answer "what does the player DO, minute to minute?"

Before any systems, mechanics, or content — define the rhythm of play. What activities does the player alternate between? What's the pacing? This is the heartbeat everything else is built around.

Questions to answer:
- What are the **verbs** the player performs? (fight, build, explore, manage, etc.)
- How long is one loop iteration?
- What's the failure state?
- What's the reward structure?
- Is the player actively engaged or passively watching during each phase?

Keep it short. The core loop should fit in a few bullet points. If it takes a page to explain, it's too complex.

**Output:** A core loop document. Short, clear, probably 1-2 pages.

---

## Phase 3: Establish Design Pillars

**Goal:** Define what to lean into and what to avoid, plus any master design rules.

Design pillars are the non-negotiable principles that every future decision gets measured against. They prevent scope creep and keep the vision coherent.

- **Design these hard** — the 3-5 things that make your game YOUR game
- **Anti-goals** — things you will NOT do, even if they seem like good ideas
- **Master design rules** — principles that override other decisions when there's a conflict

Design rules often emerge during other phases. That's fine — add them whenever you discover them. This document is alive.

**Output:** A design pillars document. Revisited and updated throughout the entire process.

---

## Phase 4: Design Systems (Broad to Narrow)

**Goal:** Define each game system at the conceptual level before getting into specifics.

Work through your game's systems in dependency order — systems that other systems reference get designed first. The exact order depends on your game, but the principle is: **don't design something that depends on undefined systems.**

For each system:
1. Define its purpose (what problem does it solve for the player?)
2. Define its boundaries (what is and isn't this system's job?)
3. Define how it connects to other systems
4. Identify open questions to revisit later

**The Spaghetti Method** (brainstorming technique):
1. Establish a solid foundation of things you're confident about. Lock those in.
2. Tell the LLM to "spaghetti it" — go deliberately wide, weird, and unfiltered.
3. The LLM generates volume without self-censoring for feasibility.
4. You trim back. Some ideas stick, some get modified, most get tossed.
5. What survives becomes the new locked foundation.
6. Repeat as needed, going deeper each round.

This works because LLMs are excellent at generating volume and variety but bad at taste and curation. Humans are the opposite. Split the labor accordingly.

**Output:** Design documents per system. Each captures decisions made, rationale, and open questions.

---

## Phase 5: Define the Mechanical Vocabulary

**Goal:** Define the TYPES of interactions that can exist before designing specific interactions.

This is the most important conceptual step and the one most people skip. Before you design any specific ability, item, or character, define the **grammar** — the categories of mechanical interaction your game supports.

For example: instead of designing "Fireball deals 20 fire damage and applies Burn," first define that your game has damage types, status effects, triggers/procs, and AOE targeting as mechanical categories. THEN "Fireball" is just a sentence written in that grammar: [AOE, Projectile] dealing [Fire] damage, applying [Burn] status, triggered by [Cooldown ready].

Why this matters:
- Without a shared vocabulary, every new mechanic requires inventing new systems
- With a shared vocabulary, every new mechanic is just a new combination of existing building blocks
- The vocabulary IS your framework — it defines what the code needs to support
- Synergies and combos emerge naturally from the vocabulary rather than being hardcoded

**Stress-test the vocabulary:** Take weird, out-there ideas and see if they can be described using only vocabulary terms. If they can, the vocabulary is complete. If they can't, identify what's missing and add it.

**Output:** A vocabulary document listing all mechanical categories, what each contains, and illustrative examples of how they interact.

---

## Phase 6: Asset Inventory

**Goal:** Know what you have to work with before designing specific content.

If you're working with existing assets (asset packs, programmer art, licensed content), catalogue what's available BEFORE designing characters, levels, enemies, etc. Design from constraints, not into constraints.

- What character/entity sprites exist and what animations do they have?
- What effects, particles, UI elements are available?
- What environments/tilesets exist?
- What gaps exist and how can they be filled? (palette swaps, layered effects, modular assembly)

If you're creating custom art, this phase is about defining the art style and scope constraints instead.

**Output:** An asset catalogue organized by usability tier (what's ready to go, what needs work, what's missing).

---

## Phase 7: Architecture Blueprint (Plain English)

**Goal:** Define the code structure in plain english before writing any code.

This is where you transition from game design to software architecture — but still WITHOUT coding. Define:

- **What systems exist** in code (stat system, combat system, UI system, etc.)
- **What each system is responsible for** and what it is NOT responsible for
- **How systems communicate** with each other
- **What data structures are needed** (what does a character definition look like? an ability? an item?)
- **What is code vs. what is data** (critical: anything that should be easily added/modified without changing code should be DATA, not hardcoded)

The data-driven principle: if you're going to have 30+ of something (characters, abilities, items, enemies, levels), those should be data files interpreted by generic systems, not individual scripts. Adding a new character should be filling out a form, not writing new code.

Walk through concrete examples: "Here's what a specific character looks like as a data file. Here's what happens when they use an ability — which systems are involved, in what order, what data flows where."

**Output:** An architecture document with system diagrams, data structure examples, and a clear separation between code (built once) and data (added repeatedly).

---

## Phase 8: Core Framework Decisions

**Goal:** Lock down the fundamental calculations and systems the framework needs before implementation.

Some decisions need to be made before any code is written because they affect everything:

- **Core stats / attributes** — what numbers define an entity?
- **Core formulas** — how is damage calculated? How does defense work? How does scaling work?
- **AI / behavior** — how do autonomous entities make decisions? (if applicable)
- **Spatial model** — how does the game represent physical space?
- **Resource systems** — what currencies/resources exist and how do they flow?

These are the hardest decisions to change later because everything references them. Get them right on paper. Prototype the MATH (spreadsheets are fine) before prototyping the code.

**Output:** Added to the architecture document. Concrete formulas, not vague descriptions.

---

## Phase 9: Prototype

**Goal:** Get something running as fast as possible to validate the feel.

Build the minimum systems needed to demonstrate the core loop. NOT the full framework — just enough to answer "does this feel right?"

Pick 2-3 maximally different test cases (characters, levels, scenarios) that stress-test the framework. If the prototype handles all of them without special-casing, the architecture is sound. If it can't, iterate on the architecture while the codebase is still small.

**The prototype is disposable.** Its purpose is to validate decisions, not to be the foundation of the final game. If it reveals that something fundamental is wrong, throw it away and redesign. That's success, not failure.

**Output:** A playable (however ugly) prototype that demonstrates the core loop.

---

## Phase 10: Build Out

**Goal:** Expand from the validated prototype into the full game.

Now that the framework is validated, building content becomes mechanical:
1. Design a new character/level/item using the vocabulary
2. Express it as a data definition using the established data structures
3. Plug it into the framework
4. Test and tune
5. Repeat

This is where the data-driven approach pays off. Each new piece of content is fast to add because the systems are already built.

---

## General Principles

**Design docs are living documents.** Update them when decisions change. Cross off resolved open questions. Add new ones. If a document doesn't match reality, the document is wrong, not reality.

**Every phase can loop back.** Discovering something in Phase 7 that breaks a Phase 4 assumption is normal. Go back and fix it. Better to fix a design doc than refactor code.

**The LLM forgets. You don't have to.** Use persistent memory, design docs, and architecture docs to maintain continuity across conversations. Every major decision should be written down with its rationale so future conversations (or future LLMs) have full context.

**Underdone is better than overdone.** At every phase, do the minimum needed to move to the next phase with confidence. You can always come back and add depth. You can't easily un-build something that's overengineered.

**The most dangerous moment is when design feels "done."** The temptation is to keep designing forever. Set a hard boundary: once the architecture is blueprinted and the core formulas are locked, prototype. You will learn more from 30 minutes of something on screen than from 3 more hours of design docs.
