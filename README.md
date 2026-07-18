# FeiBao

Mobile-first, portrait-first Godot 4.x project (clean-room).

**Current version: 0.5.0** — local player profile save foundation.

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

## What 0.5.0 Adds

- Versioned local `PlayerProfile` (schema 1) under `user://feibao/`
- Strict JSON codec + staged recoverable write with backup
- `PlayerData` autoload; Boot loads profile before Login
- Login pre-fills saved name but never auto-logs in
- Default owned character id: `feibao_dev` (definitions stay separate)

## Docs

- `docs/ARCHITECTURE.md`
- `docs/DEVELOPMENT.md`
- `docs/FEIBAO_0.5.0_LOCAL_PLAYER_SAVE.md`
- `docs/FEIBAO_0.4.0_CHARACTER_CATALOG.md`

## Explicit Exclusions

No cloud accounts, encryption claims, auto-login, combat stats, marketplace assets, or APK-derived content.
