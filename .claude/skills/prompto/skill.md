---
name: prompto
description: Decomposes plans, task lists, project briefs, or multi-step workflows into optimized session prompts routed to the right model tier based on task complexity. Use this skill whenever the user says things like "break this plan into prompts", "create session prompts for this", "turn this into tasks for Claude", "generate prompts from this plan", "make me prompts for each step", "route these tasks", or any variation of converting a plan, spec, outline, brief, or roadmap into actionable AI prompts. Also trigger when the user mentions "prompto", "/prompto", or asks to minimize token usage across a set of tasks. Works for software projects, content pipelines, research plans, business workflows, or any multi-step endeavor.
---

# Prompto — Plan-to-Prompt Decomposer

Prompto takes a plan (project brief, task list, spec, roadmap, outline) and produces a set of **self-contained session prompts** — each one sized, scoped, and routed to the right model tier so every token counts.

## Why This Exists

Most plans contain a mix of trivial, moderate, and hard tasks. Sending everything to the strongest model wastes tokens and money. Sending everything to the cheapest model produces garbage on the hard parts. Prompto solves this by classifying each task and generating a prompt tuned to the model that will execute it.

## Core Workflow

### Step 1 — Ingest the Plan

Accept the plan in any format: bullet list, prose paragraph, numbered steps, markdown doc, pasted spec, uploaded file. If the input is vague or underspecified, ask ONE clarifying question before proceeding (e.g., "Is this a software project or a content pipeline?"). If it's clear enough to work with, just proceed.

Parse the plan into discrete **atomic tasks**. An atomic task is one that a single model session can complete without needing to pause for human input midway. If a step in the plan is compound (e.g., "Design and implement the auth system"), split it.

### Step 2 — Classify Complexity

Rate each atomic task on three dimensions, then assign a tier:

**Dimensions (each scored 1–3):**

| Dimension | 1 (Low) | 2 (Medium) | 3 (High) |
|---|---|---|---|
| **Reasoning depth** | Lookup, template fill, straightforward transform | Multi-step logic, conditional branching, moderate judgment | Novel problem-solving, architecture decisions, nuanced tradeoffs |
| **Domain knowledge** | General knowledge, common patterns | Specialized but well-documented domain | Expert-level, cross-domain synthesis |
| **Output precision** | Rough draft is fine, human will edit | Needs to be mostly right, minor fixes OK | Must be correct — errors are costly or hard to catch |

**Tier assignment from composite score (sum of 3 dimensions):**

| Composite Score | Tier | Target Model Class | Examples |
|---|---|---|---|
| 3–4 | **Tier 1 — Light** | Haiku-class (fast, cheap) | Reformatting, boilerplate, simple lookups, renaming, list generation |
| 5–7 | **Tier 2 — Standard** | Sonnet-class (balanced) | Code implementation from clear spec, content drafting, data transformation, testing |
| 8–9 | **Tier 3 — Heavy** | Opus-class (maximum capability) | Architecture design, complex debugging, nuanced writing, cross-system integration |

### Step 3 — Generate Session Prompts

For each task, generate a **self-contained prompt** following the template for its tier. Read `references/prompt_templates.md` for the tier-specific templates and token budget guidelines.

Key principles across all tiers:

1. **Self-contained**: Each prompt includes all context needed. No "as discussed above" — the receiving model has no memory of other sessions.
2. **Explicit output format**: Tell the model exactly what shape the output should take (code file, markdown doc, JSON, bullet list, etc.).
3. **Minimal but sufficient context**: Include only the context this specific task needs. Don't dump the entire project spec into a Tier 1 prompt.
4. **Dependency-aware**: If task B depends on task A's output, say so explicitly in task B's prompt: "You will receive [description of A's output] as input."
5. **Constraint-forward**: State constraints and requirements up front, not buried at the end.

### Step 4 — Build the Execution Plan

Assemble the prompts into an ordered execution plan that respects dependencies. Present it as a structured output:

```
## Execution Plan: [Plan Name]

### Phase 1 — [grouping label] (parallel tasks)
- Task 1.1 [Tier X] — one-line summary
- Task 1.2 [Tier X] — one-line summary

### Phase 2 — [grouping label] (depends on Phase 1)
- Task 2.1 [Tier X] — one-line summary
...

### Token Budget Estimate
- Tier 1 tasks: N × ~[input tokens] in / ~[output tokens] out
- Tier 2 tasks: N × ~[input tokens] in / ~[output tokens] out
- Tier 3 tasks: N × ~[input tokens] in / ~[output tokens] out
- Estimated total: ~[total tokens]
```

Then output each prompt in full, grouped by phase, with clear separators:

```
---
### Task [ID]: [Title]
**Tier**: [1/2/3] → [Model class]
**Depends on**: [task IDs or "none"]
**Estimated tokens**: ~[input] in / ~[output] out

[The actual prompt to send to the model]
---
```

## Token Minimization Strategies

These are baked into prompt generation, not optional add-ons:

- **Tier 1 prompts** are terse. No preamble, no "you are a helpful assistant." Just the instruction and the input. Haiku-class models don't need hand-holding on simple tasks.
- **Tier 2 prompts** use structured context blocks (XML tags or markdown headers) to organize information efficiently. Include a brief role/goal statement only when the task benefits from framing.
- **Tier 3 prompts** invest tokens in context and constraints because the cost of a bad output is high. Include reasoning scaffolding (e.g., "Think through X before Y"), relevant background, and explicit success criteria. The upfront token cost pays for itself by reducing retries.
- **Never repeat the plan verbatim** inside prompts. Distill only what each task needs.
- **Use references, not copies.** If multiple tasks share context (e.g., a data schema), define it once and reference it. In the execution plan, note "attach schema.json to this prompt" rather than inlining it repeatedly.
- **Prune examples.** One good example beats three mediocre ones. Zero examples beats one if the task is unambiguous.

## Output Format

The final deliverable is always a **markdown file** saved to `/mnt/user-data/outputs/` containing:

1. The execution plan overview (phases, dependencies, token estimates)
2. Every prompt in full, clearly separated and labeled
3. A "How to Use" section at the top explaining the tier → model mapping

If the user requests a different format (e.g., JSON, individual files per prompt), accommodate that instead.

## Edge Cases

- **Single-task plans**: Skip the execution plan wrapper. Just output one optimized prompt with its tier.
- **Ambiguous complexity**: When in doubt, tier up. A Sonnet prompt sent to Opus wastes some tokens. A Haiku prompt sent to Haiku on a task that needed Sonnet wastes the user's time on a bad output.
- **Interdependent chains**: If tasks form a strict chain where each output feeds the next, note this clearly and suggest the user run them sequentially, piping outputs forward.
- **User specifies models**: If the user names specific models (e.g., "I only have Sonnet"), generate all prompts for that model, but still classify complexity so the user knows which tasks to watch most carefully.
- **Very large plans (15+ tasks)**: Group into phases first, confirm the grouping with the user, then generate prompts phase by phase to keep output manageable.
