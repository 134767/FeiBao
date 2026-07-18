# FeiBao

Mobile-first, portrait-first Godot 4.x project (clean-room).

**Current version: 0.6.0** — character ownership integrated with the catalog.

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

## What 0.6.0 Adds

- Catalog shows owned / unowned / representative / focused states
- Filters: 全部 / 已持有 / 未持有; set representative from detail (owned only)
- `PlayerData.grant_character` / `select_character` with catalog validation
- Profile schema remains **1** (0.5.0 saves need no migration)
- Default still owns only `feibao_dev`; no auto-grant of partners

## Docs

- `docs/ARCHITECTURE.md`
- `docs/DEVELOPMENT.md`
- `docs/FEIBAO_0.6.0_CHARACTER_OWNERSHIP.md`
- `docs/FEIBAO_0.5.0_LOCAL_PLAYER_SAVE.md`
- `docs/FEIBAO_0.4.0_CHARACTER_CATALOG.md`

## Explicit Exclusions

No cloud accounts, encryption claims, auto-login, combat stats, marketplace assets, or APK-derived content.
