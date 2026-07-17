# FeiBao Module Navigation (0.3.0)

## Registry Metadata Schema

Each screen entry in `ScreenRegistry` contains:

| Field | Meaning |
|-------|---------|
| `path` | PackedScene path |
| `title` | Display title (Chinese for modules) |
| `kind` | `system` / `auth` / `home` / `module` |
| `back_fallback` | Screen id for empty-history back, or empty |

## Module IDs (fixed order)

1. `adventure` — 冒險  
2. `character` — 角色  
3. `party` — 隊伍  
4. `inventory` — 背包  
5. `farm` — 農場  
6. `settings` — 設定  

All six share `res://scenes/screens/module/module_screen.tscn`.

## Why a Shared ModuleScreen

- Avoid six near-duplicate empty scenes.
- One frame for title / status / back.
- Future: change only `path` in Registry to a dedicated scene.

## GameShell Configure Hook

If an instance has `configure_screen(screen_id) -> bool`, GameShell calls it **before** `add_child`.  
Boot / Login / Lobby do not implement it and remain unchanged.

## Flow

```text
Lobby --navigate_to(module, history)--> ModuleScreen
ModuleScreen --go_back_or_fallback()--> Lobby
```

- History non-empty → `go_back()`.
- History empty → `replace_with(back_fallback)` (modules → lobby).
- Fallback does **not** push history.
- `ui_cancel` uses the same API (no app quit).

## Not Implemented

No adventure stages, combat, character stats, party build, inventory items, farm systems, or functional settings.

## Testing

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

## Clean-room

No APK-derived assets, commercial content, secrets, or third-party game code.
