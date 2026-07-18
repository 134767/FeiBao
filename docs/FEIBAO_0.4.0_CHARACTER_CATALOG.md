# FeiBao 0.4.0 — Character Catalog Foundation

## Summary

Version **0.4.0** upgrades the Lobby **角色** entry from the shared placeholder `ModuleScreen` to a dedicated, data-driven **character catalog** module.

Players can:

1. Open 角色 from the Lobby
2. Browse six **development seed** characters
3. Search by name / species / tags
4. Select a card and read details
5. Return to Lobby via history or fallback

## JSON Schema (`data/character_catalog.json`)

```json
{
  "schema_version": 1,
  "catalog_kind": "development_seed",
  "characters": [
    {
      "id": "feibao_dev",
      "display_name": "…",
      "species": "…",
      "summary": "…",
      "description": "…",
      "tags": ["development", "…"],
      "sort_order": 0,
      "portrait_path": "",
      "is_development_seed": true
    }
  ]
}
```

| Field | Rules |
|-------|--------|
| `schema_version` | Must be exactly `1` |
| `catalog_kind` | Must be `development_seed` |
| `id` | Non-empty, unique, `^[a-z0-9_]+$` |
| `display_name` / `species` / `summary` / `description` | Non-empty strings |
| `tags` | Non-empty array of non-empty strings |
| `sort_order` | Non-negative int; primary sort key |
| `portrait_path` | String; empty → native placeholder glyph |
| `is_development_seed` | Bool; all current seeds must be `true` |

Sort order: `sort_order` ascending, then `id` ascending.

## Development Seed Policy

- All six records are **informal development samples**, not final lore.
- First seed: **飛寶（開發樣本）**.
- Others: **夥伴 A–E**.
- UI shows an explicit **開發樣本** badge / seed hint.
- Do **not** describe seeds as playable production characters.
- Do **not** add commercial game names, art, or third-party assets.

## Replacing Seeds Later

1. Author a new JSON that still satisfies schema_version `1` (or bump with a dedicated migration task).
2. Keep loader validation strict (no silent partial loads).
3. Point `CharacterCatalog.DEFAULT_PATH` / file content at the new catalog.
4. Expand tests for the new records.
5. Formal art (if any) must be Cloud Director–approved and licensed; empty `portrait_path` remains valid.

## Explicit Non-Goals (0.4.0)

- No ownership / inventory of characters
- No level, EXP, breakthrough
- No rarity / gacha
- No combat stats, skills, or damage formulas
- No party formation
- No equipment
- No disk persistence or remote backend
- No marketplace / third-party art, fonts, audio, plugins
- No Android export or APK-derived content

## Key Files

| Path | Role |
|------|------|
| `core/character_definition.gd` | Immutable-ish definition (`RefCounted`) |
| `core/character_catalog.gd` | Pure JSON parse + validate loader |
| `data/character_catalog.json` | Development seed catalog |
| `scenes/screens/character/character_card.*` | Reusable card component |
| `scenes/screens/character/character_screen.*` | Dedicated module screen |
| `core/screen_registry.gd` | `SCREEN_CHARACTER` → dedicated path |

## Navigation

- Kind remains `module`; back_fallback remains `lobby`.
- `_MODULE_ORDER` unchanged.
- Adventure / Party / Inventory / Farm / Settings still use shared `ModuleScreen`.
- GameShell still owns navigation; screen uses `NavigationState.go_back_or_fallback()`.

## Testing

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Suite includes `tests/character_catalog_smoke_test.gd` (contract, card, screen, shell, layout probes).
