# FeiBao Module Navigation (0.9.0)

## Module IDs (fixed order)

1. `adventure` — 冒險 → **dedicated** `adventure_screen.tscn`
2. `character` — 角色 → **dedicated** `character_screen.tscn`
3. `party` — 隊伍 → **dedicated** `party_screen.tscn`
4. `inventory` — 背包 → shared `ModuleScreen`
5. `farm` — 農場 → shared `ModuleScreen`
6. `settings` — 設定 → shared `ModuleScreen`

**Session (not a lobby module):**

- `battle` — 戰鬥 → **dedicated** `battle_screen.tscn` (kind `session`, fallback `adventure`)

Constants:

- `PATH_MODULE` = shared placeholder
- `PATH_ADVENTURE_SCREEN` = dedicated adventure
- `PATH_BATTLE_SCREEN` = dedicated battle shell
- `PATH_CHARACTER_SCREEN` = dedicated character
- `PATH_PARTY_SCREEN` = dedicated party

## Adventure Module (0.8.0 / 0.9.0)

- Area story (`story_intro`) shown on adventure selection only
- Stage grid + **準備此關卡** → AdventureState only
- **進入戰鬥** → BattleState session + BattleScreen (transactional)
- No real combat / completion write in this version

## Battle Session (0.9.0)

- Entered only via Adventure **進入戰鬥** (not lobby grid)
- Leave clears BattleState and returns to adventure (history or fallback; nav failure restores session)

## Party Module (0.7.0)

- BodyScroll, columns 2/2/4, pending focus remove fallback

## Character Module (0.6.0+)

- Catalog ownership filters and representative selection

## Flow

```text
Lobby --> AdventureScreen / CharacterScreen / PartyScreen / ModuleScreen
AdventureScreen --prepare--> BattleScreen
BattleScreen --leave--> AdventureScreen (history / fallback)
Screen --go_back_or_fallback()--> Lobby (modules)
```

## Testing

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```
