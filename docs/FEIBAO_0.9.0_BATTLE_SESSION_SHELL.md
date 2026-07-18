# FeiBao 0.9.0 — Battle Session Shell Foundation

## Summary

Version **0.9.0** connects the 0.8.0 prepared stage to a **memory-only Battle Session** and a dedicated **BattleScreen** shell.

- Adventure prepare → create session snapshot → navigate to battle
- Battle screen shows stage + active party snapshot (leader-aware)
- Safe leave clears the session and returns via history / adventure fallback
- **No real combat**, drops, completion flags, or profile schema change

## BattleSession (autoload)

- Memory only — never writes disk or PlayerProfile
- `begin_from_prepared()` snapshots AdventureState stage + PlayerData party
- `clear_session()` / `has_active_session()` with idempotent no-signal on no-change
- Signal: `session_changed(stage_id, active)` once per real change
- Defensive copies for party id / display-name arrays

## BattleScreen

- Registry: dedicated `PATH_BATTLE_SCREEN`, kind `session` (not a lobby module)
- `back_fallback` → `adventure`
- Displays stage name / area / summary and party list with leader mark
- Shell status: 戰鬥系統殼層 · 尚無真實戰鬥
- Leave / back clears session then `go_back_or_fallback()`

## Adventure prepare wiring

- After successful `AdventureState.prepare_stage`, create BattleSession then navigate to battle
- Fail-closed: no PlayerData / prepare fail / session fail / navigate fail stay on adventure
- Prepared stage context is retained when leaving battle (session only clears)

## Explicit exclusions

Combat turns, enemies, HP/ATK, skills, drops, stage completion persistence, stamina, multiplayer, marketplace assets, PlayerProfile schema change (stays **2**), StageCatalog schema change (stays **1**).

## Next

0.10.0+ is expected to grow a real battle vertical slice on top of this session shell.
