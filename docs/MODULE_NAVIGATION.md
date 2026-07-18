# FeiBao Module Navigation (0.4.0)

## Registry Metadata Schema

Each screen entry in `ScreenRegistry` contains:

| Field | Meaning |
|-------|---------|
| `path` | PackedScene path |
| `title` | Display title (Chinese for modules) |
| `kind` | `system` / `auth` / `home` / `module` |
| `back_fallback` | Screen id for empty-history back, or empty |

## Module IDs (fixed order)

1. `adventure` — 冒險 → shared `ModuleScreen`
2. `character` — 角色 → **dedicated** `character_screen.tscn`
3. `party` — 隊伍 → shared `ModuleScreen`
4. `inventory` — 背包 → shared `ModuleScreen`
5. `farm` — 農場 → shared `ModuleScreen`
6. `settings` — 設定 → shared `ModuleScreen`

Constants:

- `PATH_MODULE` = `res://scenes/screens/module/module_screen.tscn`
- `PATH_CHARACTER_SCREEN` = `res://scenes/screens/character/character_screen.tscn`

## Shared ModuleScreen

Still used by five placeholder modules:

- One frame for title / status / back
- Body text: `此功能將於後續版本開放`
- Future modules may switch `path` to a dedicated scene (as character did)

## Character Module

- Title in registry: **角色**
- Screen header: **角色圖鑑**
- Catalog JSON + cards + search + detail
- Development seed badge; no combat / ownership / persistence

## GameShell Configure Hook

If an instance has `configure_screen(screen_id) -> bool`, GameShell calls it **before** `add_child`.
Boot / Login / Lobby do not implement it and remain unchanged.

## Flow

```text
Lobby --navigate_to(module, history)--> ModuleScreen or CharacterScreen
Screen --go_back_or_fallback()--> Lobby
```

- History non-empty → `go_back()`.
- History empty → `replace_with(back_fallback)` (modules → lobby).
- Fallback does **not** push history.
- `ui_cancel` uses the same API (no app quit).

## Not Implemented

No adventure stages, combat, character progression, party build, inventory items, farm systems, or functional settings.

## Testing

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

## Clean-room

No APK-derived assets, commercial content, secrets, or third-party game code.
