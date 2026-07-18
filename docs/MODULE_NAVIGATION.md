# FeiBao Module Navigation (0.7.0)

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
3. `party` — 隊伍 → **dedicated** `party_screen.tscn`
4. `inventory` — 背包 → shared `ModuleScreen`
5. `farm` — 農場 → shared `ModuleScreen`
6. `settings` — 設定 → shared `ModuleScreen`

Constants:

- `PATH_MODULE` = `res://scenes/screens/module/module_screen.tscn`
- `PATH_CHARACTER_SCREEN` = `res://scenes/screens/character/character_screen.tscn`
- `PATH_PARTY_SCREEN` = `res://scenes/screens/party/party_screen.tscn`

## Shared ModuleScreen

Used by remaining placeholder modules (adventure / inventory / farm / settings):

- One frame for title / status / back
- Body text: `此功能將於後續版本開放`

## Character Module

- Dedicated catalog screen with ownership filters and representative selection (0.6.0+)

## Party Module (0.7.0)

- Dedicated `PartyScreen` for a single active party (1–3 members)
- **BodyScroll**: page-level vertical scroll (horizontal disabled) so 360×640 / 390×844 can reach all slots, roster, and action buttons
- Roster columns: **exactly 2 / 2 / 4** on 360 / 390 / 720 viewports
- Focus vs leader vs representative remain separate concepts
- Remove focus fallback: next remaining member, or new leader; visible slot/roster focus matches internal focus
- Full UI refresh only on successful changed `profile_changed` (count=1); failure/no-change = 0

## GameShell Configure Hook

If an instance has `configure_screen(screen_id) -> bool`, GameShell calls it **before** `add_child`.
Boot / Login / Lobby do not implement it and remain unchanged.

## Flow

```text
Lobby --navigate_to(module, history)--> ModuleScreen / CharacterScreen / PartyScreen
Screen --go_back_or_fallback()--> Lobby
```

- History non-empty → `go_back()`.
- History empty → `replace_with(back_fallback)` (modules → lobby).
- Fallback does **not** push history.
- `ui_cancel` uses the same API (no app quit).

## Not Implemented

No adventure stages, combat, multi-party, inventory items, farm systems, or functional settings.

## Testing

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

## Clean-room

No APK-derived assets, commercial content, secrets, or third-party game code.
