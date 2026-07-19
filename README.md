# FeiBao

Mobile-first, portrait-first Godot 4.x project (clean-room).

**Current version: 1.0.0** — battle board & turn-loop foundation.

## Requirements

- Godot **4.7.1** Standard
- Windows CLI example: `C:\Godot\godot.exe`

## Quick Start

```powershell
Set-Location "C:\Users\v5990\fei-bao"
godot --path .
```

## Tests

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

## What 1.0.0 Adds

- Operable **6×5** match board with deterministic seed/RNG
- Memory-only **BattleRuntime** (board, turns, selection, resolution events)
- Swap → match → clear → gravity → refill → cascade turn loop
- Adventure enter creates BattleState **and** BattleRuntime (transactional)
- Battle leave clears both with exact rollback on nav failure
- PlayerProfile schema remains **2**; StageCatalog schema remains **1**
- No enemies / damage / win-loss / rewards / board persistence

## Docs

- `docs/ARCHITECTURE.md`
- `docs/DEVELOPMENT.md`
- `docs/FEIBAO_1.0.0_BATTLE_BOARD_TURN_LOOP.md`
- `docs/FEIBAO_0.9.0_BATTLE_SESSION_SHELL.md`
- `docs/FEIBAO_0.8.0_ADVENTURE_STAGE_SELECTION.md`
- `docs/FEIBAO_0.7.0_ACTIVE_PARTY.md`
- `docs/FEIBAO_0.6.0_CHARACTER_OWNERSHIP.md`
- `docs/FEIBAO_0.5.0_LOCAL_PLAYER_SAVE.md`
- `docs/FEIBAO_0.4.0_CHARACTER_CATALOG.md`

## Explicit Exclusions

No cloud accounts, encryption claims, auto-login, finished combat systems, marketplace assets, or APK-derived content.
