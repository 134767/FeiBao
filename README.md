# FeiBao

Mobile-first, portrait-first Godot 4.x project (clean-room).

**Current version: 0.9.0** — battle session shell foundation.

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

## What 0.9.0 Adds

- Memory-only BattleState session (stage + party snapshot, no disk)
- Dedicated BattleScreen shell (not a lobby module)
- Adventure two-step: prepare stage, then enter battle (transactional leave/enter)
- PlayerProfile schema remains **2**; StageCatalog schema remains **1**
- No real combat / completion persistence

## Docs

- `docs/ARCHITECTURE.md`
- `docs/DEVELOPMENT.md`
- `docs/FEIBAO_0.9.0_BATTLE_SESSION_SHELL.md`
- `docs/FEIBAO_0.8.0_ADVENTURE_STAGE_SELECTION.md`
- `docs/FEIBAO_0.7.0_ACTIVE_PARTY.md`
- `docs/FEIBAO_0.6.0_CHARACTER_OWNERSHIP.md`
- `docs/FEIBAO_0.5.0_LOCAL_PLAYER_SAVE.md`
- `docs/FEIBAO_0.4.0_CHARACTER_CATALOG.md`

## Explicit Exclusions

No cloud accounts, encryption claims, auto-login, combat stats, marketplace assets, or APK-derived content.
