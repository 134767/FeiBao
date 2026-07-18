# FeiBao Architecture

## Project Goal

FeiBao is a mobile-first, portrait-first Godot 4.x application.
**Current version: 0.4.0** — character catalog foundation (first dedicated module).

Does **not** claim production gameplay systems are complete.

## Version History

| Version | Milestone |
|---------|-----------|
| 0.1.0 | Architecture foundation |
| 0.2.0 | GameShell, Boot / Login / Lobby |
| 0.3.0 | Registry metadata, shared ModuleScreen, module navigation |
| **0.4.0 (current)** | Dedicated character catalog module + development seed data |

## Clean-room Principles

- Original code and UI only.
- No APK / decompiled / proprietary commercial content.
- No secrets or signing keys in-repo.
- No marketplace art/fonts/audio/plugins without Cloud Director review.

## Key Components

| Piece | Role |
|-------|------|
| AppState | Phase only (`BOOTSTRAP`…`MODULE`) + in-memory player name. **No screen id storage.** |
| NavigationState | Current screen + history; `go_back_or_fallback()` |
| ScreenRegistry | Unified metadata (path/title/kind/fallback) |
| GameShell | Single ScreenHost child; `configure_screen` hook |
| ModuleScreen | Shared placeholder frame for five modules |
| CharacterDefinition / CharacterCatalog | Read-only character data contract + JSON loader |
| CharacterScreen / CharacterCard | Dedicated 角色 module UI |

## Screen Flow

```text
Bootstrap → GameShell → Boot → Login → Lobby
  ⇄ ModuleScreen (adventure, party, inventory, farm, settings)
  ⇄ CharacterScreen (character catalog)
```

## Character Catalog (0.4.0)

- JSON schema version `1`, kind `development_seed`.
- Six informal seed records (not final lore).
- Search / select / detail; native glyph placeholder when `portrait_path` is empty.
- No ownership, progression, combat stats, or persistence.

See `docs/FEIBAO_0.4.0_CHARACTER_CATALOG.md`.

## Explicit Exclusions

Combat, gacha, shop, currency, stamina, real inventory/farm/party systems, remote backends, Android signing, third-party commercial assets.
