# FeiBao 1.0.0 — Battle Board & Turn Loop Foundation

## Purpose

Build an operable, deterministically testable **6×5 match-3 board** and **single-turn resolution loop** on top of the 0.9.0 Battle Session Shell.

This is still a **development sample** of board + turn flow — **not** finished combat content.

## Responsibility split

| Component | Role |
|-----------|------|
| **BattleState** | Entry session snapshot (area/stage/party/leader). Memory-only. No board. |
| **BattleRuntime** | Board, RNG, turns, selection, phase, events + **full session binding** (area/stage/party/leader). Memory-only. |
| **BattleBoardModel / Engine** | Pure domain: generate, match, gravity, refill, swap resolve. No SceneTree. |
| **BattleScreen** | Renders session + board; selection/swap UX; leave transaction. |

## Board contract

- Size: **6 × 5** (30 cells)
- Index: `y * 6 + x` (x ∈ 0..5, y ∈ 0..4)
- Orb kinds (dev sample, no combat effects): `ember` 炎 / `tide` 潮 / `leaf` 葉 / `light` 光 / `shadow` 影
- Getters return **defensive copies**

## Full session binding

BattleRuntime stores and compares:

- `session_area_id`
- `session_stage_id`
- `session_party_character_ids` (order-sensitive defensive copy)
- `session_leader_character_id`

Same-session idempotent begin requires **all four** equal. Same area/stage with different party or leader → fail closed (no overwrite).

## Snapshot / restore

- Active snapshot requires live BattleState with exact full binding match; board 30 valid orbs; RNG ≠ 0.
- Phase/selection: READY → no selection; SELECTED → in-bounds; ERROR → (−1,−1) or in-bounds; **RESOLVING restore rejected**.
- Inactive snapshot is **canonical**: empty session fields, empty board, phase INACTIVE, counters 0, events [], RNG=1.
- Event equality uses deterministic deep compare (not Dictionary stringification).
- Resolution events have a **strict schema validator**; unknown types / illegal kinds fail closed on snapshot restore.
- Unknown event types never compare equal (no string-key fallback).

## Deterministic RNG

- Dedicated **xorshift32** state inside `BattleBoardEngine` (not global `randomize()` / time)
- Seed = stable FNV-1a over fixed field order: `area_id | stage_id | leader | party_ids…`
- Same session → same initial board + RNG state
- Refill order: **row-major** (left→right, top→bottom), empty cells only
- Production domain sources must not call `randi`/`randomize`/`Time.get_*` for seeding

## Initial board guarantees

1. Exactly 6×5, all cells valid kinds  
2. No initial 3+ match  
3. At least one legal adjacent swap  
4. Bounded generation attempts (64); fail closed  

## Selection / swap

- First cell → select; same → deselect; non-adjacent → move selection; adjacent → try swap  
- Adjacent = Manhattan distance 1 (no diagonal)  
- No match → full swap-back; board/RNG/turn unchanged; UI message  
- Match → turn +1, resolve cascades, clear selection, phase READY  

## Match / gravity / cascade

- Horizontal & vertical runs ≥ 3; overlapping cells deduplicated  
- Gravity: per-column sink, relative order kept  
- Cascade hard cap: **64** (test override available); exceed → full move rollback  

## Resolution events

Pure data dictionaries (no Node/timestamps):  
`swap`, `match_found`, `cells_cleared`, `gravity_applied`, `cells_refilled`, `cascade_completed`, `turn_completed`  
(`swap_rejected` for no-match adjacent attempts)

`last_match_count` = total unique cells cleared this turn.  
`last_cascade_count` = cascade rounds executed.

## Enter transaction (Adventure)

1. Enter re-entrancy guard  
2. Capture BattleState + BattleRuntime snapshots  
3. `BattleState.begin_from_prepared_stage()`  
4. `BattleRuntime.begin_from_battle_session()`  
5. Navigate to Battle  
6. Any failure → restore both; stay on Adventure; prepared stage kept  

## Leave transaction (Battle)

Preserves GROK-027 leave guard; order:

1. Guard → capture runtime + state  
2. Clear runtime → clear state → navigate  
3. Nav fail → restore **state then runtime** (binding-safe)  
4. Success → lock until screen disposal  

## Explicit exclusions

No enemies, HP/MP, damage, skills, AI, win/loss, rewards, progression save, schema 3, network, Android/APK, third-party assets.

## Licensing

Clean-room FeiBao GDScript and project assets only.
