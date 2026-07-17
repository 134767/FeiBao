# FeiBao Architecture

## Project Goal

FeiBao is a mobile-first, portrait-first Godot 4.x application.
**Current version: 0.2.0** — game shell foundation with Boot → Login → Lobby.

This document describes architecture through the game-shell stage. It does **not** claim production gameplay systems are complete.

## Version History (high level)

| Version | Milestone |
|---------|-----------|
| 0.1.0 (previous) | Architecture foundation, FoundationScreen vertical slice |
| **0.2.0 (current)** | GameShell, NavigationState, Boot / Login / Lobby |

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
| `core/` | Shared constants and ScreenRegistry |
| `data/` | JSON configuration |
| `scenes/bootstrap/` | Application entry |
| `scenes/shell/` | GameShell + ScreenHost |
| `scenes/screens/` | Boot, Login, Lobby screens |
| `scenes/ui/` | Safe-area helpers |
| `ui/themes/` | Original Theme resources (no external fonts/images) |
| `tests/` | Native headless smoke tests |
| `docs/` | Architecture and development documentation |

## Autoload Responsibilities

### AppState

- Tracks phase: `BOOTSTRAP`, `BOOT`, `LOGIN`, `LOBBY`.
- Holds **in-memory** player name only (`set_player_name` strips edges).
- `reset()` returns to `BOOTSTRAP` and clears player name.
- No disk save, ConfigFile, SQLite, or tokens.

### SceneRouter

- Top-level `SceneTree.change_scene_to_file` helper.
- Used for future full-scene transitions; **not** for in-shell screen swaps.
- Safe failure on missing paths.

### NavigationState

- In-app screen history and current screen id (`boot` / `login` / `lobby`).
- `navigate_to`, `replace_with`, `go_back`, `reset`.
- Validates ids via `ScreenRegistry`.
- Distinct from SceneRouter (see `docs/GAME_SHELL.md`).

### GameConfig

- Loads `res://data/game_config.json` with typed validation and defaults.

## Screen Flow (0.2.0)

```text
project.godot main_scene
        │
        ▼
  Bootstrap
        │ instantiate once
        ▼
  GameShell (SafeArea + ScreenHost)
        │
        ├─ BootScreen  --replace--> LoginScreen
        │
        └─ LoginScreen --navigate--> LobbyScreen
                    ▲                  │
                    └──── go_back ─────┘
```

## Data Flow

```text
data/game_config.json → GameConfig
Login name → AppState (memory only)
NavigationState + ScreenRegistry → GameShell ScreenHost
```

## Testing Strategy

- Native headless runner: `res://tests/test_runner.gd`
- Suites: architecture, game shell, layout probes
- No GUT or other external test addons

## Explicit Exclusions

- Production gameplay, combat, inventory, farm systems
- Persistent save / remote accounts / backend
- Third-party commercial assets
- APK / reverse-engineered content
- Android export and signing
