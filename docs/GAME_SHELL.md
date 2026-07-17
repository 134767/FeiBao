# FeiBao Game Shell (0.2.0)

## Bootstrap vs GameShell

| Component | Responsibility |
|-----------|----------------|
| **Bootstrap** | Project main scene. Sets phase `BOOTSTRAP`. Instantiates **one** GameShell. Does not load Login/Lobby. |
| **GameShell** | Full-viewport shell with SafeAreaContainer + ScreenHost. Swaps active screen Controls based on NavigationState. |

## SceneRouter vs NavigationState

| Service | Scope |
|---------|--------|
| **SceneRouter** | Top-level `SceneTree` scene file changes (`change_scene_to_file`). Future full-scene transitions. |
| **NavigationState** | In-shell screen ids (`boot` / `login` / `lobby`), history stack, back navigation. Does **not** call `change_scene_to_file`. |

Do not mix the two: screens inside GameShell must use NavigationState.

## ScreenRegistry

`res://core/screen_registry.gd` maps stable `StringName` ids to `.tscn` paths:

- `boot` → `scenes/screens/boot/boot_screen.tscn`
- `login` → `scenes/screens/login/login_screen.tscn`
- `lobby` → `scenes/screens/lobby/lobby_screen.tscn`

Paths are not scattered across `match` blocks in GameShell.

## Flow: Boot → Login → Lobby

1. GameShell resets NavigationState to `boot` and shows BootScreen.
2. BootScreen sets phase `BOOT`, then `replace_with(login)` (no Boot history).
3. LoginScreen validates name (1–12 chars, trimmed), stores in AppState memory, `navigate_to(lobby)` (Login kept in history).
4. LobbyScreen greets player; six placeholders only update status text.
5. Back (`ui_cancel` / `go_back`): Lobby → Login; Login with empty history → no-op (false).

## Player Name

- Memory only via AppState.
- No `user://`, ConfigFile, JSON save, or remote account.
- Strip edges on write.

## Back Navigation Rules

- History managed by NavigationState.
- `replace_with` does not push history.
- `navigate_to` pushes previous screen when `add_to_history` is true.
- Failed navigation does not mutate current/history.

## Completed (0.2.0)

- GameShell + ScreenHost
- NavigationState + ScreenRegistry
- Boot / Login / Lobby screens
- Theme resource (default font, StyleBoxFlat)
- Responsive portrait layout + layout probes
- Headless tests

## Not Completed

- Persistent save, accounts, backend
- Real adventure / character / party / inventory / farm / settings
- Combat, gacha, shop, stamina
- Android export / signing
- Complex transition animations

## Clean-room Limits

- No APK-derived assets or decompiled code
- No commercial fonts/images/audio
- No secrets or keystores

## How to Add a New Screen

1. Create `scenes/screens/<id>/<id>_screen.tscn` + `.gd`.
2. Register path in `ScreenRegistry._PATHS`.
3. Add `StringName` constant on NavigationState if needed.
4. Navigate via `NavigationState.navigate_to` / `replace_with`.
5. Extend smoke tests.

## Testing

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```
