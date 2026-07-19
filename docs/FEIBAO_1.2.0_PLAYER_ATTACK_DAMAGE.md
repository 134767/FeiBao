# FeiBao 1.2.0 — Player Attack & Damage Foundation

## Purpose

Convert board `cells_cleared.orb_kinds` into deterministic player attacks against the active enemy, with pure domain combat events and atomic board + HP commit.

## Completed

- Orb-kind aggregation across the full accepted turn (no combo/cascade multipliers)
- Deterministic player attack order (party slot 0 → n−1)
- Active enemy HP damage via `BattleCombatantModel.apply_damage`
- `BattleCombatEvent` schema (`player_damage`, `player_combat_completed`)
- Pure `BattleDamageResolver` (no Runtime/UI/PlayerData writes)
- Atomic board + encounter + combat event commit in `BattleRuntime`
- `last_combat_events` in runtime snapshot (memory-only)
- BattleScreen attack log + enemy HP refresh
- Lethal HP clamp to 0 (no win/loss flow)

## Damage formula

```text
scaled_attack = floor(attacker_attack * cleared_orb_count / 3)
calculated_damage = max(1, scaled_attack - target_defense)
actual_damage = min(calculated_damage, hp_before)
hp_after = hp_before - actual_damage
```

- No affinity multiplier
- No cascade / combo multiplier
- No random factor
- No critical hits
- Subsequent party members stop if target HP reaches 0

## Architecture

```text
BattleResolutionEvent
  → BattleDamageResolver
  → BattleCombatEvent + candidate BattleEncounterModel
  → BattleRuntime (sole active battle authority)
  → BattleScreen
```

- **BattleResolutionEvent**: board swap/clear/gravity/refill/turn only
- **BattleCombatEvent**: player attack + enemy HP only
- **BattleRuntime**: owns board events, combat events, and encounter
- No second combat autoload
- No PlayerProfile mutation; no disk combat persistence

## Signal contract (accepted turn)

| Signal | Delta |
|--------|-------|
| runtime_changed | 0 |
| board_changed | 1 |
| combat_changed | 1 |
| encounter_changed | 1 if HP changed, else 0 |
| phase_changed | ready (no PHASE_RESOLVING emit on candidate-fail path) |

Rejected swap: combat events cleared; `combat_changed` only if prior combat was non-empty.

Resolver failure: full runtime exact prior; all signal deltas 0.

## Exclusions (not in 1.2.0)

- Enemy turn / enemy attack
- Affinity multipliers
- Combo / cascade multipliers
- Critical hits
- Skills / leader skills
- Buff / debuff / status
- Manual target switch
- Auto switch next enemy
- Victory / defeat flow
- Stage complete / rewards / XP / gold
- Combat disk save
- PlayerProfile schema 3
- Network / Firebase
- Android export
- Third-party assets

## Licensing

Clean-room FeiBao GDScript and project assets only.

## Version

App **1.2.0**. PlayerProfile schema **2**. StageCatalog schema **1**.
