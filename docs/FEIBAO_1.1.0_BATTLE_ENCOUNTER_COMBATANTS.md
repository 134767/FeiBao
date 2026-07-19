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

### Catalog numeric contract (WHOLE_JSON_NUMBER)

JSON catalogs cannot reliably distinguish lexical `10` vs `10.0` as different Variant types after parse.

- **Allowed:** finite whole JSON numbers (`10`, `10.0`); normalized to `int` after validation
- **Rejected:** fractional (`10.5`), bool, String, null, Array, Dictionary, Object, Callable
- **Runtime / combatant snapshots** still require strict **TYPE_INT** (not whole-float)

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

- **Cards are the sole visible combatant content** (party/enemy header + cards)
- `PartyListLabel` / `EnemyListLabel` are hidden (zero layout height); summary text is cached for non-visual getters
- Enemy cards: visual_symbol, name, affinity text+symbol, HP (`HP %d/%d`), bar, active badge (index 0)
- Player cards: name, affinity text+symbol, HP, bar, ATK/DEF, leader badge (index 0)
- ProgressBar: min 0, max = max_hp, value = current_hp, actual height ≥ 16, non-focusable
- Wide layouts (≥700px): party/enemy cards may render multi-column to keep 720×1280 within one page
- Notice: 「戰鬥單位狀態已建立；傷害與敵人行動尚未啟用。」
- Board turns do **not** change HP or active enemy index (no damage / attack / victory / defeat events)

## Verification evidence (GROK-038)

Honest test methods (`tests/battle_encounter_combatant_smoke_test.gd` + `tests/assertion_integrity_smoke_test.gd`):

| Area | Method |
|------|--------|
| Clean-start provenance | GROK-038 starts from clean `3a67aa1…`. GROK-037 started dirty (A gate not satisfied); final GROK-037 work is linear 3 commits only. |
| Forced accepted turn | Deterministic match-ready fixture + exact `try_swap_cells(2,0)/(3,0)`; unconditional accepted assertions |
| Adventure enter failures | Real `AdventureScreen`; BattleState / Adventure prepared / Runtime exact snapshots; retry success |
| Snapshot matrix (3×3) | mist_03 + 3 party / 3 enemies; wrong order with contiguous slots; duplicate slot distinct IDs; inactive Runtime+active encounter with 30 empty cells; all fail-closed + zero signals |
| Exact cards | Canonical title/affinity/HP/stats/bar equality (no `find`); repeated configure connection counts unchanged |
| Missing encounter screen | Active BattleState + failed Runtime begin; error exact; 0 cards; 30 disabled cells; retry after override clear |
| Responsive | Independent SubViewport; horizontal containment; scroll-visible rect reachability (not whole-viewport-only); 720 initial fit without ensure_control_visible |
| Keyboard | Real Enter/Space with Button.pressed callback counters + selection domain outcomes |
| Integrity scanner | Separate suite; direct literal/regex only; does not scan itself; pattern-scope only (not full logic proof) |
| Production cleanup | Overrides match DEFAULT_PATH loads; fixture dir empty; profile schema 2 without encounter/current_hp keys |

Not claimed: GROK-037 clean-start gate PASS; generic static analysis proves all assertions; external CI PASS.

## Exclusions

Damage, player/enemy attacks, affinity multipliers, skills, AI, target switching, victory/defeat, rewards, schema 3, network, Android export, third-party assets.

## Licensing

Clean-room FeiBao GDScript and project assets only.

## Version

App **1.1.0**.
