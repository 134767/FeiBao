# FeiBao

Mobile-first, portrait-first Godot 4.x project (clean-room).

**Current version: 0.8.0** — adventure stage selection foundation.

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

## What 0.8.0 Adds

- Dedicated AdventureScreen with area story + stage grid
- Pure StageCatalog (schema 1 development seed: 2 areas × 3 stages)
- AdventureState in-memory stage preparation (no disk / no combat yet)
- PlayerProfile schema remains **2**

## Docs

- `docs/ARCHITECTURE.md`
- `docs/DEVELOPMENT.md`
- `docs/FEIBAO_0.8.0_ADVENTURE_STAGE_SELECTION.md`
- `docs/FEIBAO_0.7.0_ACTIVE_PARTY.md`
- `docs/FEIBAO_0.6.0_CHARACTER_OWNERSHIP.md`
- `docs/FEIBAO_0.5.0_LOCAL_PLAYER_SAVE.md`
- `docs/FEIBAO_0.4.0_CHARACTER_CATALOG.md`

## Explicit Exclusions

No cloud accounts, encryption claims, auto-login, combat stats, marketplace assets, or APK-derived content.
