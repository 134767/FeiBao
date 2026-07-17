# FeiBao Game Shell (through 0.3.0)

## Bootstrap vs GameShell

| Component | Responsibility |
|-----------|----------------|
| Bootstrap | Main scene; instantiates one GameShell |
| GameShell | SafeArea + ScreenHost; NavigationState-driven swaps |

## SceneRouter vs NavigationState

| Service | Scope |
|---------|--------|
| SceneRouter | Top-level `change_scene_to_file` |
| NavigationState | In-shell ids + history + `go_back_or_fallback()` |

## Configure Hook

```text
instantiate → configure_screen(id)? → add_child → (active)
```

Only ModuleScreen implements `configure_screen`.

## Back

`ui_cancel` → `NavigationState.go_back_or_fallback()`  
No `quit()`, no OS exit APIs.

See also: `docs/MODULE_NAVIGATION.md`.
