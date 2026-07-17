# FeiBao Architecture

## Project Goal

FeiBao is a mobile-first, portrait-first Godot 4.x application.
**Current version: 0.3.0** — module navigation foundation (Lobby → six modules → back/fallback).

Does **not** claim production gameplay systems are complete.

## Version History

| Version | Milestone |
|---------|-----------|
| 0.1.0 | Architecture foundation |
| 0.2.0 | GameShell, Boot / Login / Lobby |
| **0.3.0 (current)** | Registry metadata, shared ModuleScreen, module navigation |

## Clean-room Principles

- Original code and UI only.
- No APK / decompiled / proprietary commercial content.
- No secrets or signing keys in-repo.

## Key Components

| Piece | Role |
|-------|------|
| AppState | Phase only (`BOOTSTRAP`…`MODULE`) + in-memory player name. **No screen id storage.** |
| NavigationState | Current screen + history; `go_back_or_fallback()` |
| ScreenRegistry | Unified metadata (path/title/kind/fallback) |
| GameShell | Single ScreenHost child; `configure_screen` hook |
| ModuleScreen | Shared module frame |

## Screen Flow

```text
Bootstrap → GameShell → Boot → Login → Lobby ⇄ ModuleScreen (×6 ids)
```

## Explicit Exclusions

Combat, gacha, shop, currency, stamina, real inventory/farm/party/character data, remote backends, Android signing.
