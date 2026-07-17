# FeiBao Architecture

## Project Goal

FeiBao is a mobile-first, portrait-first Godot 4.x application.
**Current version: 0.3.0** — module navigation foundation on top of the game shell.

This document does **not** claim production gameplay systems are complete.

## Version History (high level)

| Version | Milestone |
|---------|-----------|
| 0.1.0 (previous) | Architecture foundation, FoundationScreen vertical slice |
| 0.2.0 (previous) | GameShell, NavigationState, Boot / Login / Lobby |
| **0.3.0 (current)** | Six Lobby module entries → shared ModuleScreen + back/fallback |

## Clean-room Principles

- Build original structure, code, UI, and data.
- Do **not** import proprietary assets, scripts, or reverse-engineered content from commercial games or APKs.
- Do **not** place commercial APK source, unpacked assets, or decompiled code into this repository.
- Prefer modular, data-driven, offline-first design.
- Keep secrets, tokens, and signing keys out of the repo.

## Directory Responsibilities

| Path | Role |
|------|------|
| `autoload/` | Global services (AppState, GameConfig, SceneRouter, NavigationState) |
| `core/` | Shared constants and ScreenRegistry (+ module metadata) |
| `data/` | JSON configuration |
| `scenes/bootstrap/` | Application entry |
| `scenes/shell/` | GameShell + ScreenHost |
| `scenes/screens/` | Boot, Login, Lobby, Module screens |
| `scenes/ui/` | Safe-area helpers |
| `ui/themes/` | Original Theme resources (no external fonts/images) |
| `tests/` | Native headless smoke tests |
| `docs/` | Architecture and development documentation |

## Autoload Responsibilities

### AppState

- Phases: `BOOTSTRAP`, `BOOT`, `LOGIN`, `LOBBY`, `MODULE`.
- In-memory player name only.
- Optional `active_module` id while viewing a module frame.
- No disk save.

### SceneRouter

- Top-level `SceneTree.change_scene_to_file` helper.
- Not used for in-shell module swaps.

### NavigationState

- In-app screen history and current id.
- `navigate_to`, `replace_with`, `go_back`, `go_back_or_lobby`, `reset`.
- Validates ids via ScreenRegistry.

### GameConfig

- Loads `res://data/game_config.json` (version **0.3.0**).

## Screen Flow (0.3.0)

```text
Bootstrap → GameShell
  Boot --replace--> Login --navigate--> Lobby
                                      │
                    ┌── adventure ────┤
                    ├── character ────┤  shared ModuleScreen
                    ├── party ────────┤  (metadata title/body)
                    ├── inventory ────┤
                    ├── farm ─────────┤
                    └── settings ─────┘
                                      │
                         back / ui_cancel / go_back_or_lobby
                                      ▼
                                    Lobby
```

## Explicit Exclusions

- Real adventure / combat / character progression
- Inventory items, farm production, party composition
- Settings persistence, accounts, remote APIs
- Commercial assets, APK content, signing keys
