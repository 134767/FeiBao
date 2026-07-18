# FeiBao

Mobile-first, portrait-first Godot 4.x project (clean-room).

**Current version: 0.4.0** — character catalog foundation.

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

## What 0.4.0 Adds

- Read-only character definition contract + JSON catalog loader
- Six **development seed** characters (not final lore)
- Dedicated **角色圖鑑** screen: cards, search, selection, detail
- Other five Lobby modules remain shared placeholders

## Docs

- `docs/ARCHITECTURE.md`
- `docs/DEVELOPMENT.md`
- `docs/MODULE_NAVIGATION.md`
- `docs/FEIBAO_0.4.0_CHARACTER_CATALOG.md`

## Explicit Exclusions

No combat stats, gacha, ownership, disk saves, remote backends, marketplace assets, or APK-derived content.
