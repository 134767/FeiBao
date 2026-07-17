# FeiBao Architecture

## Project Goal

FeiBao is a mobile-first, portrait-first Godot 4.x application. This foundation establishes a clean, testable project shell so later features can grow without rewriting startup, configuration, routing, or UI layout basics.

This document describes the **architecture foundation only**. It does not claim that production gameplay systems are complete.

## Clean-room Principles

- Build original structure, code, UI, and data.
- Do **not** import proprietary assets, scripts, or reverse-engineered content from commercial games or APKs.
- Do **not** place commercial APK source, unpacked assets, or decompiled code into this repository.
- Prefer modular, data-driven, offline-first design.
- Keep secrets, tokens, and signing keys out of the repo.

## Directory Responsibilities

| Path | Role |
|------|------|
| `autoload/` | Global services registered in Project Settings |
| `core/` | Shared constants and non-UI utilities |
| `data/` | JSON and other data-driven configuration |
| `scenes/bootstrap/` | Application entry scene and boot flow |
| `scenes/ui/` | Foundation UI and safe-area helpers |
| `tests/` | Native headless smoke tests (no external addon) |
| `docs/` | Architecture and development documentation |

## Autoload Responsibilities

### AppState (`res://autoload/app_state.gd`)

- Tracks a minimal application phase (`BOOTSTRAP`, `FOUNDATION`).
- Provides `set_phase()`, `get_phase()`, and `reset()`.
- Does **not** store formal player save data.

### SceneRouter (`res://autoload/scene_router.gd`)

- Centralizes scene changes via `change_scene(path) -> bool`.
- Rejects empty paths, missing files, and in-progress duplicate switches.
- Returns `false` on failure and does not crash the process.

### GameConfig (`res://autoload/game_config.gd`)

- Loads `res://data/game_config.json` at startup.
- Validates required fields and types.
- Falls back to safe defaults and emits errors when data is missing or invalid.
- Exposes read-only helpers such as `get_value()` and typed getters.

## Scene Flow

```text
project.godot main_scene
        │
        ▼
  Bootstrap (Node)
        │
        │ instantiate once
        ▼
  FoundationScreen (Control)
        │
        ├─ SafeAreaContainer
        ├─ App name / version labels
        ├─ Runtime info
        └─ Smoke Test button (UI-only success state)
```

1. Godot launches `res://scenes/bootstrap/bootstrap.tscn`.
2. Bootstrap sets phase to `BOOTSTRAP`, loads FoundationScreen, then sets `FOUNDATION`.
3. FoundationScreen shows static shell UI; no gameplay systems are started.

## Data Flow

```text
data/game_config.json
        │
        ▼
    GameConfig (autoload)
        │
        ├─ validate / merge defaults
        └─ FoundationScreen / future systems read via getters
```

Minimum schema keys: `app_name`, `app_version`, `design_width`, `design_height`, `orientation`, `data_version`, `debug_mode`.

## UI & Safe Area

- Design resolution: **720×1280**, orientation **portrait**.
- UI uses `Control` anchors and containers for narrow screens (e.g. 390×844 class).
- `SafeAreaContainer` reads `DisplayServer.get_display_safe_area()`, maps insets to the viewport, and uses **zero margins** when safe-area data is unavailable (desktop).

## Testing Strategy

- Native headless runner: `res://tests/test_runner.gd`.
- Suite: `res://tests/architecture_smoke_test.gd`.
- No GUT or other external test addons required.
- Assertions cover main scene, bootstrap load, foundation instantiation, autoload scripts, config values, SceneRouter safe failure, and AppState reset.
- Exit code `0` when all pass; non-zero when any fail.

## Explicit Exclusions

- Production gameplay systems
- Third-party commercial game assets
- APK / reverse-engineered content
- Android export and signing setup
- Formal login, economy, combat, map, or building systems
