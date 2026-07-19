# FeiBao 1.1.0 — Battle Encounter & Combatant Foundation

## Purpose

Add **memory-only battle participants and encounter state** on top of the 1.0.0 board + turn loop:

1. Player party combat stats (catalog blueprints)
2. Development enemy definitions
3. Explicit stage → enemy encounter linkage
4. In-memory `BattleEncounterModel`
5. Atomic board + encounter begin / snapshot in `BattleRuntime`
6. BattleScreen party/enemy HP status display

This is **not** real combat: no damage, attacks, skills, AI, win/loss, or rewards.

## Data catalogs

| Catalog | Path | Schema |
|---------|------|--------|
| Character combat stats | `data/character_combat_stats.json` | 1 |
| Enemy catalog | `data/enemy_catalog.json` | 1 |
| Stage encounters | `data/stage_encounters.json` | 1 |

Stage presentation catalog and character presentation catalog remain **schema 1** (no combat fields embedded).

PlayerProfile remains **schema 2** (IDs only; no combat persistence).

## Core types

- `CharacterCombatStatsDefinition` / `CharacterCombatStatsCatalog`
- `EnemyDefinition` / `EnemyCatalog`
- `StageEncounterDefinition` / `StageEncounterCatalog`
- `BattleCombatant` — side, id, name, slot, max/current HP, ATK, DEF, leader flag
- `BattleEncounterModel` — build from session, snapshot/restore, equality

## BattleRuntime (1.1.0)

- `begin_from_battle_session` / `begin_from_seed_for_tests` build **board + encounter atomically**
- Fail closed: encounter build failure does not leave an active board
- Snapshot key `encounter` required on restore
- Active encounter must match session stage/area/party/leader
- Inactive: empty encounter with board canonical inactive
- Getters: `get_party_combatants`, `get_enemy_combatants`, counts, `has_active_encounter`
- Signal: `encounter_changed`

## BattleScreen

- Party list shows `HP current/max` and leader mark
- Enemy header + list with HP
- Still no target selection, damage, or victory UI

## Explicit exclusions

Board-clear damage, player/enemy attacks, damage formulas, elemental multipliers, skills/leader skills, AI, target switching, win/loss, stage completion, rewards, profile schema 3, battle disk save, network, Android export, third-party assets.

## Version

App **1.1.0**. Profile schema **2**. Stage catalog schema **1**.
