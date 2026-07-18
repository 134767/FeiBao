# FeiBao

Mobile-first, portrait-first Godot 4.x project (clean-room).

**Current version: 0.7.0** — active party formation with profile schema 2.

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

## What 0.7.0 Adds

- Dedicated PartyScreen: 1–3 member active party, leader at slot 0
- Profile **schema 2** with `active_party_character_ids`
- Lazy schema 1 → 2 migration (no boot write; next successful save persists v2)
- Representative (`selected_character_id`) remains separate from party leader

## Docs

- `docs/ARCHITECTURE.md`
- `docs/DEVELOPMENT.md`
- `docs/FEIBAO_0.7.0_ACTIVE_PARTY.md`
- `docs/FEIBAO_0.6.0_CHARACTER_OWNERSHIP.md`
- `docs/FEIBAO_0.5.0_LOCAL_PLAYER_SAVE.md`
- `docs/FEIBAO_0.4.0_CHARACTER_CATALOG.md`

## Explicit Exclusions

No cloud accounts, encryption claims, auto-login, combat stats, marketplace assets, or APK-derived content.
