# Prompt Templates by Tier

## Tier 1 — Light (Haiku-class)

**Token budget target:** ~200–500 tokens input, ~100–1000 tokens output

**Philosophy:** Be direct. Haiku-class models excel at clear, constrained tasks. Extra context is noise.

**Template:**

```
[One-sentence instruction.]

Input:
[The data or content to operate on]

Output format: [exact format spec]
```

**Example — reformatting a list:**

```
Convert these items to a markdown table with columns: Name, Category, Status.

Input:
- Auth module (backend, done)
- Login page (frontend, in progress)
- Rate limiter (backend, not started)

Output format: markdown table, no additional text.
```

**What to omit in Tier 1:**
- Role statements ("You are a...")
- Reasoning instructions ("Think step by step")
- Multiple examples (one at most, zero if the task is clear)
- Background context beyond what's needed for the immediate task

---

## Tier 2 — Standard (Sonnet-class)

**Token budget target:** ~500–2000 tokens input, ~500–4000 tokens output

**Philosophy:** Structured and scoped. Give the model enough context to make good decisions, but don't over-explain what's straightforward.

**Template:**

```
<goal>
[What to produce and why it matters — 1-2 sentences]
</goal>

<context>
[Only the background this task requires. Use sub-sections if there are multiple context pieces.]
</context>

<requirements>
[Bullet list of constraints, specs, or acceptance criteria]
</requirements>

<output_format>
[Exact deliverable shape: file type, structure, sections, length bounds]
</output_format>
```

**Example — implementing a function from spec:**

```
<goal>
Write a GDScript function that calculates loot drop probabilities based on player luck stat and zone difficulty.
</goal>

<context>
- Luck stat ranges from 0–100
- Zone difficulty is an enum: EASY, MEDIUM, HARD, NIGHTMARE
- Base drop rates: Common 60%, Uncommon 25%, Rare 10%, Legendary 5%
- Each point of luck shifts 0.3% probability from Common to higher rarities, distributed proportionally
</context>

<requirements>
- Function signature: func calculate_drops(luck: int, difficulty: ZoneDifficulty) -> Dictionary
- Return a Dictionary mapping rarity names to float probabilities (must sum to 1.0)
- NIGHTMARE difficulty doubles the luck bonus
- Clamp all probabilities to [0.01, 0.95]
- Include brief inline comments
</requirements>

<output_format>
Single GDScript function, ready to paste into a file. No surrounding class wrapper.
</output_format>
```

**What to include in Tier 2 that you skip in Tier 1:**
- A goal statement so the model understands intent, not just mechanics
- Structured context blocks
- Explicit requirements list
- Brief inline comments in code output

**What to still omit:**
- Long background narratives
- Multiple alternative approaches to consider
- "Think about edge cases" — instead, name the specific edge cases you care about

---

## Tier 3 — Heavy (Opus-class)

**Token budget target:** ~1000–5000 tokens input, ~1000–8000 tokens output

**Philosophy:** Invest in prompt quality. These are high-stakes tasks where a bad output costs more than the extra input tokens. Give the model room to reason, but channel that reasoning.

**Template:**

```
<role>
[Brief framing: who you are in this context and what lens to apply — 1-2 sentences]
</role>

<objective>
[What to produce, why it matters, what success looks like — 2-4 sentences]
</objective>

<context>
[Comprehensive background. Include:
- System/project overview relevant to this task
- Prior decisions or constraints that shape this work
- Technical environment details
- Anything the model might otherwise guess wrong about]
</context>

<constraints>
[Hard requirements, non-negotiable boundaries, known pitfalls to avoid]
</constraints>

<reasoning_guidance>
[How to approach the problem:
- What to consider before generating output
- Key tradeoffs to weigh
- What "good" vs "great" looks like for this task]
</reasoning_guidance>

<output_format>
[Detailed deliverable spec: structure, sections, length, format, what to include and exclude]
</output_format>

<success_criteria>
[How the human will evaluate this. Be specific — "well-written" is useless, "technically accurate, covers all 3 migration paths, actionable by a mid-level engineer" is useful.]
</success_criteria>
```

**Example — architecture decision:**

```
<role>
You are a senior game systems architect advising on a survivors-like extraction game built in Godot 4.6 with GDScript.
</role>

<objective>
Design the save/load system architecture. The game needs to persist run state (mid-extraction saves), player progression (unlocks, currency, stats), and settings. The architecture should handle future expansion (new unlockable characters, evolving equipment) without requiring save migration on every content update.
</objective>

<context>
- Single-player with potential future co-op
- Runs last 15-30 minutes; extraction saves only at designated points
- Player progression includes: 5 characters (expanding to 10+), weapon evolutions (15+ recipes), currency (scraps), and unlocks
- Current data model: Character resource files, weapon resource files, run state in a singleton
- Platform target: Steam (PC), possible future console ports
- Godot 4.6 uses Resource serialization and ConfigFile natively
</context>

<constraints>
- No external database — file-based only
- Save files must be tamper-resistant (not tamper-proof, just not trivially editable)
- Load time under 500ms on a mid-range PC
- Must handle corrupted saves gracefully (fallback to last known good)
- Save format must be forward-compatible: old saves load in new game versions without migration scripts for at least minor version bumps
</constraints>

<reasoning_guidance>
- Consider Godot's built-in Resource save/load vs custom JSON vs binary serialization
- Weigh the tradeoff between human-readable saves (easier to debug) and binary (harder to tamper with)
- Think about versioning strategy: how does the system know what version a save is, and what does it do when it encounters an old one?
- Consider what data is "run state" vs "progression" — these have very different persistence patterns
</reasoning_guidance>

<output_format>
Markdown document with:
1. Architecture overview (diagram described in text)
2. Data model: what gets saved, where, in what format
3. Save/load flow: step-by-step for both run saves and progression saves
4. Versioning strategy
5. Error handling approach
6. Tradeoff notes: what you chose and why, what alternatives exist
</output_format>

<success_criteria>
A solo developer with GDScript experience (but no systems architecture background) should be able to implement this from your document without needing to make additional design decisions. Every "it depends" should be resolved.
</success_criteria>
```

**What Tier 3 adds over Tier 2:**
- Role framing to set the reasoning lens
- Reasoning guidance to channel thinking productively
- Explicit success criteria
- More comprehensive context (this is where tokens pay for themselves)
- Room for the model to explain tradeoffs, not just produce output

---

## Cross-Tier Rules

These apply regardless of tier:

1. **Never start a prompt with "You are a helpful assistant."** It wastes tokens and adds nothing.
2. **Specify output format in every prompt.** Even Tier 1. "What shape is the answer?" is the single highest-value instruction you can include.
3. **Use XML tags for structure in Tier 2+.** They're cheaper than prose transitions and models parse them reliably.
4. **One task per prompt.** If you're tempted to add "also do X," that's a second prompt.
5. **Name the model's constraints, not its abilities.** "Do not include explanatory text" is more useful than "You can write concise output."
6. **If a task needs input data, show the data.** Don't describe it. "You'll receive a JSON array of user objects" is worse than showing a 2-item sample.
7. **Dependency handoff:** When task B depends on task A, include a placeholder in B's prompt: `[INSERT OUTPUT FROM TASK A.1 HERE]` — and note what that output will look like so the human knows how to paste it.
