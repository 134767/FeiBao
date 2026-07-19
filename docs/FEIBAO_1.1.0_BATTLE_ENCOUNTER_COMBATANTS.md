# FeiBao 1.1.0 — Battle Encounter & Combatant Foundation

## Purpose

Memory-only battle participants and encounter state on the 1.0.0 board + turn loop:

1. Player combat stat blueprints (`BattleCharacterStatsCatalog`)
2. Original development enemies (`EnemyCatalog`)
3. Stage → enemy encounter linkage (`StageEncounterCatalog`)
4. `BattleAffinity` (ember/tide/leaf/light/shadow) with geometric symbols
5. `BattleCombatantModel` + `BattleEncounterModel`
6. Atomic board + encounter begin/snapshot in `BattleRuntime`
7. BattleScreen party/enemy status cards (HP text + ProgressBar)

No damage, attacks, skills, AI, win/loss, or rewards.

## Architecture

```text
data JSON → catalog parsers → pure combatant/encounter domain → BattleRuntime → BattleScreen
```

- **BattleState**: session metadata only (no board, no HP)
- **BattleRuntime**: sole active battle authority (board + encounter)
- Catalogs/domain: no SceneTree, NavigationState, or PlayerData mutation

## Data

| Catalog | Path | Schema |
|---------|------|--------|
| Character battle stats | `data/battle_character_stats.json` | 1 |
| Enemies | `data/enemies.json` | 1 |
| Stage encounters | `data/stage_encounters.json` | 1 |

PlayerProfile remains **schema 2**. Stage presentation catalog remains **schema 1**.

## Domain

- `BattleAffinity` — all / is_valid / display_name / symbol (▲●◆✦■)
- `BattleCombatantModel` — player|enemy; snapshot with exact keys; catalog immutable stats check
- `BattleEncounterModel` — players 1–3, enemies 1–3, `active_enemy_index` (start 0; inactive −1)

## BattleRuntime

Begin order (candidate then one-shot commit):

1. Validate BattleState binding  
2–5. Build candidate encounter  
6–7. Build candidate board (isolated engine)  
8. Commit board + encounter + binding  
9. Emit signals  

Failure: runtime completely unchanged; zero signals.

Snapshot key `encounter`: `{ player_combatants, enemy_combatants, active_enemy_index }`.

## BattleScreen

- Enemy cards: visual_symbol, name, affinity, HP, bar, active badge (index 0)
- Player cards: name, affinity, HP, bar, ATK/DEF, leader badge (index 0)
- Notice: 「戰鬥單位狀態已建立；傷害與敵人行動尚未啟用。」
- Board turns do not change HP or active enemy index

## Exclusions

Damage, player/enemy attacks, affinity multipliers, skills, AI, target switching, victory/defeat, rewards, schema 3, network, Android export, third-party assets.

## Licensing

Clean-room FeiBao GDScript and project assets only.

## Version

App **1.1.0**.
