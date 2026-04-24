# Extraction Survivors — Interaction Diagrams

---

## 1. Game State Machine

```mermaid
stateDiagram-v2
    direction LR
    [*] --> MENU
    MENU --> HUB : start game
    HUB --> RUN_STARTING : begin run
    RUN_STARTING --> PHASE_ACTIVE : arena loaded
    PHASE_ACTIVE --> PHASE_TRANSITION : phase timer ends
    PHASE_TRANSITION --> PHASE_ACTIVE : next phase
    PHASE_TRANSITION --> EXTRACTION : final phase ends
    PHASE_ACTIVE --> RUN_END : player dies
    EXTRACTION --> RUN_END : extracted
    RUN_END --> HUB : always
```

---

## 2. Autoload System Map

```mermaid
graph TD
    classDef manager fill:#4a3f6b,stroke:#9b8ec4,color:#fff
    classDef bus fill:#2d5a3d,stroke:#5db87a,color:#fff
    classDef listener fill:#3d4a5c,stroke:#7a9bc4,color:#fff

    EB((EventBus)):::bus

    GM[GameManager]:::manager
    PM[ProgressionManager]:::manager
    UM[UpgradeManager]:::manager
    ESM[EnemySpawnManager]:::manager
    EM[ExtractionManager]:::manager
    AM[ArenaManager]:::manager

    AUDIO[AudioManager]:::listener
    UI[UIManager]:::listener

    GM -->|phase / run signals| EB
    GM --> ESM & EM & AM
    EM -->|extraction events| EB
    UM -->|upgrade_chosen| EB

    EB -->|on_kill| ESM
    EB -->|extraction_complete| GM
    EB -->|player_died| GM
    EB -->|combat signals| AUDIO & UI
```

---

## 3. Scene Ownership — CombatOrchestrator

```mermaid
graph TD
    classDef root fill:#5c3a1e,stroke:#c47a3a,color:#fff
    classDef sys fill:#1e3a5c,stroke:#3a7ac4,color:#fff

    MA[MainArena<br/>scene root]:::root
    CO[CombatOrchestrator]:::root

    PM[ProjectileManager<br/>256-slot pool]:::sys
    VFX[VfxManager]:::sys
    DS[DisplacementSystem]:::sys
    CFM[CombatFeedbackManager<br/>128-slot damage numbers]:::sys
    SG[SpatialGrid<br/>rebuilt every frame]:::sys
    GZ[Ground Zones<br/>persistent AoE]:::sys
    DD[DebugDraw]:::sys

    MA --> CO
    CO --> PM & VFX & DS & CFM & SG & GZ & DD
```

---

## 4. Entity Component Structure

```mermaid
graph LR
    classDef entity fill:#5c3a1e,stroke:#c47a3a,color:#fff
    classDef comp fill:#1e3a5c,stroke:#3a7ac4,color:#fff
    classDef hub fill:#2d5a3d,stroke:#5db87a,color:#fff

    E[Entity]:::entity

    HC[HealthComponent<br/>HP / shield / death]:::comp
    MC[ModifierComponent<br/>stat modifiers]:::comp
    AC[AbilityComponent<br/>skills / cooldowns]:::comp
    BC[BehaviorComponent<br/>AI / auto-attack]:::comp
    SEC[StatusEffectComponent<br/>active statuses / auras]:::comp
    TC[TriggerComponent<br/>EventBus listeners]:::comp
    ED[EffectDispatcher]:::hub

    E --> HC & MC & AC & BC & SEC & TC
    BC -->|resolve targets| AC
    AC -->|fire ability| ED
    SEC -->|sync| MC
    TC -->|on event| ED
```

---

## 5. Per-Frame Tick Order

```mermaid
flowchart TD
    classDef step fill:#1e3a5c,stroke:#3a7ac4,color:#fff

    A[1 · SpatialGrid rebuild]:::step
    B[2 · StatusEffect.tick]:::step
    C[3 · AbilityComponent.tick_cooldowns]:::step
    D[4 · BehaviorComponent.tick<br/>enemies only]:::step
    E[5 · Ground zone ticks]:::step
    P[Player._physics_process<br/>runs in parallel]:::step

    A --> B --> C --> D --> E
    D -. player self-ticks .-> P
```

---

## 6. Damage Pipeline — 8 Steps

```mermaid
flowchart LR
    classDef step fill:#3d2020,stroke:#c45a5a,color:#fff
    classDef out fill:#2d5a3d,stroke:#5db87a,color:#fff

    S1[1 · Base damage<br/>+ attribute scaling]:::step
    S2[2 · Type conversion]:::step
    S3[3 · Offensive mods<br/>bonus for type + All]:::step
    S4[4 · Dodge check]:::step
    S5[5 · Block check<br/>+ mitigation]:::step
    S6[6 · Resistance<br/>raw × 1−R÷R+100]:::step
    S7[7 · Damage taken mods<br/>+ vulnerability]:::step
    S8[8 · Crit roll]:::step
    HD([HitData<br/>amount / type / flags]):::out

    S1 --> S2 --> S3 --> S4 --> S5 --> S6 --> S7 --> S8 --> HD
```

---

## 7. EffectDispatcher — Effect Types

```mermaid
graph LR
    classDef dispatch fill:#2d5a3d,stroke:#5db87a,color:#fff
    classDef dmg fill:#3d2020,stroke:#c45a5a,color:#fff
    classDef buff fill:#1e3a5c,stroke:#3a7ac4,color:#fff
    classDef util fill:#3d3a20,stroke:#c4b45a,color:#fff

    ED[EffectDispatcher]:::dispatch

    subgraph Damage
        D1[DealDamage]:::dmg
        D2[HealEffect]:::dmg
        D3[AreaDamage]:::dmg
        D4[OverflowChain]:::dmg
    end

    subgraph Buffs & Statuses
        B1[ApplyStatus]:::buff
        B2[ApplyShield]:::buff
        B3[ApplyModifier]:::buff
        B4[ConsumeStacks]:::buff
        B5[SetMaxStacks]:::buff
        B6[Cleanse]:::buff
    end

    subgraph World
        W1[SpawnProjectiles]:::util
        W2[Displacement]:::util
        W3[GroundZone]:::util
        W4[Summon]:::util
        W5[Resurrect]:::util
    end

    ED --> D1 & D2 & D3 & D4
    ED --> B1 & B2 & B3 & B4 & B5 & B6
    ED --> W1 & W2 & W3 & W4 & W5
```

---

## 8. Kill Event — Full Sequence

```mermaid
sequenceDiagram
    actor Player
    participant BC as BehaviorComponent
    participant ED as EffectDispatcher
    participant PM as ProjectileManager
    participant DC as DamageCalculator
    participant HC as HealthComponent
    participant EB as EventBus

    BC->>ED: execute_effects(auto_attack)
    ED->>PM: SpawnProjectilesEffect
    PM-->>PM: projectile travels
    PM->>ED: on_hit → DealDamageEffect
    ED->>DC: calculate_damage()
    DC-->>ED: HitData
    ED->>HC: apply_damage(HitData)
    HC->>EB: on_hit_dealt
    EB-->>EB: CombatFeedbackManager (number popup)

    alt HP ≤ 0
        HC->>EB: on_death + on_kill
        EB-->>EB: TriggerComponent → on_kill effects
        EB-->>EB: EnemySpawnManager notified
        HC->>EB: on_overkill [if overkill > 0]
        HC-->>Player: spawn XP gem + loot roll
    end
```

---

## 9. Status Effect Lifecycle

```mermaid
sequenceDiagram
    participant ED as EffectDispatcher
    participant SEC as StatusEffectComponent
    participant MC as ModifierComponent
    participant TC as TriggerComponent
    participant EB as EventBus

    ED->>SEC: apply_status(def, stacks, duration)
    alt Immune
        SEC->>EB: on_status_resisted
    else Apply
        SEC->>MC: sync modifiers
        SEC->>TC: register trigger listeners
        SEC->>EB: on_status_applied
    end

    loop Every tick_interval
        SEC->>ED: execute tick_effects
    end
    loop Every frame (aura_radius > 0)
        SEC->>ED: execute aura_tick_effects on nearby
    end

    alt Duration expires
        SEC->>MC: remove modifiers
        SEC->>TC: unregister listeners
        SEC->>EB: on_status_expired
    end
```

---

## 10. Targeting Resolution

```mermaid
flowchart TD
    classDef query fill:#1e3a5c,stroke:#3a7ac4,color:#fff
    classDef mode fill:#3d3a20,stroke:#c4b45a,color:#fff
    classDef out fill:#2d5a3d,stroke:#5db87a,color:#fff

    BC[BehaviorComponent.tick]:::query
    SG[SpatialGrid query]:::query
    TYPE{targeting.type}

    BC --> SG --> TYPE

    TYPE -->|nearest_enemy| N1[closest 1]:::mode
    TYPE -->|nearest_enemies| N2[closest N]:::mode
    TYPE -->|highest_hp_enemy| N3[sort HP desc]:::mode
    TYPE -->|self_centered_burst| N4[all in radius]:::mode
    TYPE -->|frontal_rectangle| N5[rect ahead]:::mode
    TYPE -->|all_allies| N6[faction filter]:::mode
    TYPE -->|self| N7[source only]:::mode

    N1 & N2 & N3 & N4 & N5 & N6 & N7 --> FILT[min_nearby cluster filter]:::query
    FILT --> ED[EffectDispatcher.execute_effects]:::out
```

---

## 11. Modifier Query

```mermaid
flowchart LR
    classDef op fill:#3d3a20,stroke:#c4b45a,color:#fff

    Q[sum_modifiers<br/>tag + operation] --> CACHE{cache hit?}
    CACHE -->|yes| RET([cached value])
    CACHE -->|no| SCAN[scan modifier list] --> ADD[sum matching] --> WRITE[update cache] --> RET

    subgraph Operations
        direction TB
        O1[add · flat bonus]:::op
        O2[bonus · % multiplier]:::op
        O3[resist · damage reduction]:::op
        O4[negate · immunity flag]:::op
        O5[pierce · bypass resist]:::op
        O6[cooldown_reduce]:::op
        O7[vulnerability · % more taken]:::op
        O8[damage_taken · multiplier]:::op
    end
```

---

## 12. Extraction Flow

```mermaid
sequenceDiagram
    participant GM as GameManager
    participant EM as ExtractionManager
    participant EB as EventBus
    participant UI as UIManager
    participant Player

    GM->>EB: phase_ending
    EB->>EM: activate extraction point
    EM->>EB: extraction_warning (10 s)
    EB->>UI: show warning

    Note over EM: 10 seconds

    EM->>EB: extraction_available
    EB->>UI: show portal marker

    Player->>EM: enter zone (Area2D)
    EM->>EB: extraction_channel_started
    EB->>UI: channel progress bar

    Note over EM: channel completes

    EM->>EB: extraction_complete
    EB->>GM: → RUN_END
    EB->>UI: success screen
    GM->>GM: → HUB
```

---

## 13. EventBus Signal Hub

```mermaid
graph TD
    classDef emitter fill:#3d2020,stroke:#c45a5a,color:#fff
    classDef bus fill:#2d5a3d,stroke:#5db87a,color:#fff
    classDef listener fill:#1e3a5c,stroke:#3a7ac4,color:#fff

    EB((EventBus)):::bus

    subgraph Emitters
        E1[HealthComponent]:::emitter
        E2[DamageCalculator]:::emitter
        E3[StatusEffectComponent]:::emitter
        E4[GameManager]:::emitter
        E5[ExtractionManager]:::emitter
    end

    subgraph Combat Signals
        S1(on_hit_dealt / received)
        S2(on_kill / on_death)
        S3(on_crit / block / dodge)
        S4(on_overkill / reflect)
    end

    subgraph Status Signals
        S5(on_status_applied / expired)
        S6(on_status_resisted / cleanse)
    end

    E1 --> S1 & S2 & S3 & S4
    E2 --> S3
    E3 --> S5 & S6
    E4 & E5 --> EB

    S1 & S2 & S3 & S4 --> EB
    S5 & S6 --> EB

    EB --> L1[TriggerComponent<br/>reactive effects]:::listener
    EB --> L2[CombatFeedbackManager<br/>damage numbers]:::listener
    EB --> L3[VfxManager]:::listener
    EB --> L4[AudioManager]:::listener
    EB --> L5[UIManager]:::listener
    EB --> L6[EnemySpawnManager]:::listener
```
