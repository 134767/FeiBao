# FeiBao 0.9.0 — Battle Session Shell Foundation

## Version purpose

Establish a **memory-only BattleState session** and dedicated **BattleScreen** entered from Adventure prepare → enter battle, with transactional navigation rollback. This is a shell foundation, **not** a combat system.

## BattleState boundary

Autoload: `BattleState` (`res://autoload/battle_state.gd`)

- Creates / clears in-memory battle session
- Captures immutable session snapshots
- Restores snapshots on failed navigation
- **No** disk I/O, **no** navigation, **no** PlayerProfile / party / representative / AdventureState mutation

## Battle Session fields

| Field | Notes |
|-------|--------|
| `area_id` | From prepared stage area |
| `stage_id` | From prepared stage |
| `party_character_ids` | Defensive copy; size 1–3 |
| `leader_character_id` | Must equal party index 0 |
| `active` | Session active flag |

Display helpers (stage/area names, number, summary) are also snapshotted for UI. No non-deterministic timestamps as required domain fields.

## API (contract)

- `has_active_session()`
- `begin_from_prepared_stage()`
- `clear_session()`
- `capture_session_snapshot()` / `restore_session_snapshot()`
- Getters: area/stage/party/leader (+ display helpers)

### begin_from_prepared_stage rules

1. Requires valid AdventureState prepared stage
2. Requires PlayerData available + active party 1–3
3. Leader = party index 0
4. All party IDs non-empty, unique, in CharacterCatalog, owned
5. Defensive copy of party IDs
6. Success mutates BattleState memory only
7. Failure preserves prior session
8. Same session → `ok=true, changed=false`, no signal
9. Different active session → fail closed, no overwrite
10. Signal only on real create / clear / restore change

## Adventure → Battle transaction

Two-step UI (prepare kept separate from enter):

1. **準備此關卡** → `AdventureState.prepare_stage` only
2. **進入戰鬥** (enabled when prepared + party valid):
   1. `capture_session_snapshot()`
   2. `begin_from_prepared_stage()`
   3. `NavigationState.navigate_to(battle)`
   4. On nav success: keep session
   5. On nav failure: `restore_session_snapshot(prior)` — stay on Adventure, no new session

## Battle → Adventure transaction

Leave / back:

1. `capture_session_snapshot()`
2. `clear_session()`
3. `go_back_or_fallback()` (fallback = Adventure)
4. On nav success: session stays cleared
5. On nav failure: restore prior session (still on BattleScreen)

## Explicit exclusions

No damage, HP/MP, enemies, skills, attack UI, auto-battle, AI turns, win/loss, stage completion, stars, drops, rewards, XP, gold, stamina, unlocks, progression save, PlayerProfile schema 3, migration, network, accounts, Android export, APK content, third-party commercial assets.

Screen banner: **戰鬥系統殼層 · 開發樣本 · 尚無真實戰鬥**.

## Persistence

BattleState never uses FileAccess, SaveFileStore, JSON persistence, PlayerData save, or profile revision bumps. Production `user://feibao/` fingerprints must remain byte-exact across the suite.

## Asset / licensing statement

Clean-room FeiBao assets and GDScript only. No marketplace art/fonts/audio, no commercial game APK content, no proprietary third-party materials.

## Test evidence

- Native suite includes `tests/battle_session_smoke_test.gd` (domain, enter, leave, registry, responsive 360/390/720, party sizes 1–3).
- Regression suites (catalog, ownership, save, party, adventure, navigation, fingerprints) remain green.
- Final native count must be **> 2197** with **0 failed**.
