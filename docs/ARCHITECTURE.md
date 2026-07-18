# FeiBao Architecture

## Project Goal

FeiBao is a mobile-first, portrait-first Godot 4.x application.
**Current version: 0.6.0** — character ownership integrated with the catalog.

Does **not** claim production multiplayer, combat, or cloud systems.

## Version History

| Version | Milestone |
|---------|-----------|
| 0.1.0 | Architecture foundation |
| 0.2.0 | GameShell, Boot / Login / Lobby |
| 0.3.0 | Registry metadata, shared ModuleScreen, module navigation |
| 0.4.0 | Dedicated character catalog module + development seeds |
| 0.5.0 | Local versioned player profile, staged save, backup recovery |
| **0.6.0 (current)** | Ownership + representative wired into character catalog UI |

## Clean-room Principles

- Original code and UI only.
- No APK / decompiled / proprietary commercial content.
- No secrets or signing keys in-repo.
- No marketplace art/fonts/audio/plugins without Cloud Director review.

## Key Components

| Piece | Role |
|-------|------|
| AppState | Phase + **session** player name only. **No file I/O.** |
| PlayerData | Autoload profile owner; codec + SaveFileStore; syncs AppState |
| PlayerProfile / Codec | Versioned local profile contract (schema 1) |
| SaveFileStore | Staged recoverable text write under `user://` |
| NavigationState | Current screen + history |
| ScreenRegistry | Unified metadata (path/title/kind/fallback) |
| GameShell | Single ScreenHost child |
| CharacterCatalog | Read-only character definitions (not ownership) |

## Screen Flow

```text
Bootstrap → GameShell → Boot (PlayerData.initialize)
  → Login (prefill name; manual submit) → Lobby
  ⇄ ModuleScreen (adventure, party, inventory, farm, settings)
  ⇄ CharacterScreen (catalog + ownership / representative)
```

## Character Ownership (0.6.0)

- `PlayerProfile` still stores only character IDs (schema 1, no migration).
- `PlayerData.grant_character` / `select_character` validate IDs against `CharacterCatalog`.
- CharacterScreen shows owned/unowned/representative, filters, and set-representative action.
- No grant UI; no auto-grant of partners; definitions stay free of ownership fields.

See `docs/FEIBAO_0.6.0_CHARACTER_OWNERSHIP.md`.

## Local Save (0.5.0)

- Paths: `user://feibao/player_profile.json` (+ `.tmp` / `.bak`)
- Missing save is normal first run (memory default, no boot write).
- Corrupt primary may recover from backup; both corrupt → safe default, files kept.
- Only a **validated** primary may refresh backup; invalid primary never overwrites a valid backup.
- Saves with no validated recovery source fail closed (sources unchanged).
- Login name save + Lobby navigation is a **persistence transaction** with full primary/tmp/backup **binary-exact** snapshot rollback on navigation failure.
- Artifact snapshots store PackedByteArray bytes + raw SHA-256/length (invalid UTF-8 safe).
- Failed login candidates never remain recoverable via backup.
- Test paths use canonical containment under `user://feibao_tests/`; production fingerprints must stay unchanged.
- No auto-login; no cloud; no encryption / absolute atomic claims.

See `docs/FEIBAO_0.5.0_LOCAL_PLAYER_SAVE.md`.

## Character Catalog (0.4.0+)

- Definition JSON is separate from player ownership.
- Default owned id: `feibao_dev` only.

## Explicit Exclusions

Combat, gacha, shop, cloud accounts, anti-cheat, multi-slot save UI, Android signing, third-party commercial assets.
