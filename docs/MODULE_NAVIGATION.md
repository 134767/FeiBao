# FeiBao Module Navigation (0.8.0)

## Module IDs (fixed order)

1. `adventure` — 冒險 → **dedicated** `adventure_screen.tscn`
2. `character` — 角色 → **dedicated** `character_screen.tscn`
3. `party` — 隊伍 → **dedicated** `party_screen.tscn`
4. `inventory` — 背包 → shared `ModuleScreen`
5. `farm` — 農場 → shared `ModuleScreen`
6. `settings` — 設定 → shared `ModuleScreen`

Constants:

- `PATH_MODULE` = shared placeholder
- `PATH_ADVENTURE_SCREEN` = dedicated adventure
- `PATH_CHARACTER_SCREEN` = dedicated character
- `PATH_PARTY_SCREEN` = dedicated party

## Adventure Module (0.8.0)

- Area story (`story_intro`) shown on adventure selection only
- Stage grid + prepare button → AdventureState (memory only)
- No real battle / completion write in this version

## Party Module (0.7.0)

- BodyScroll, columns 2/2/4, pending focus remove fallback

## Character Module (0.6.0+)

- Catalog ownership filters and representative selection

## Flow

```text
Lobby --> AdventureScreen / CharacterScreen / PartyScreen / ModuleScreen
Screen --go_back_or_fallback()--> Lobby
```

## Testing

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```
