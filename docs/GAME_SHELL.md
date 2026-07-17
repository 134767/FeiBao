# FeiBao Game Shell & Module Navigation

## Versions

- **0.2.0:** Boot → Login → Lobby shell
- **0.3.0:** Lobby six modules → shared `ModuleScreen`

## Bootstrap vs GameShell

| Component | Responsibility |
|-----------|----------------|
| **Bootstrap** | Project main scene. Instantiates one GameShell. |
| **GameShell** | SafeArea + ScreenHost; swaps screens via NavigationState. Calls `configure_for_screen(id)` when present. |

## SceneRouter vs NavigationState

| Service | Scope |
|---------|--------|
| **SceneRouter** | Top-level scene file changes |
| **NavigationState** | In-shell ids + history; `go_back_or_lobby()` for modules |

## ScreenRegistry

Maps stable `StringName` ids to scenes and module metadata:

| ID | Scene |
|----|--------|
| boot / login / lobby | dedicated screens |
| adventure / character / party / inventory / farm / settings | shared `module_screen.tscn` |

Metadata provides Chinese **title** and **description** only (no gameplay data).

## ModuleScreen

- Header: back button + title
- Description from registry
- Body placeholder: 「此模組內容將於後續版本開放」
- Back uses `NavigationState.go_back_or_lobby()`
- No module-specific systems

## Back Rules

1. Prefer history (`go_back`).
2. If history empty and current is a module → navigate to lobby without stacking.
3. Login with empty history → safe no-op.
4. `ui_cancel` handled by GameShell via `go_back_or_lobby`.

## Completed / Not Completed

**Done (0.3.0):** six formal module ids, shared frame, Lobby navigation, back/fallback, tests.

**Not done:** real module content, saves, economy, combat, remote services.
