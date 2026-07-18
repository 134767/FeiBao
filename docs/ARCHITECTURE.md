# FeiBao Architecture

## Project Goal

FeiBao is a mobile-first, portrait-first Godot 4.x application.
**Current version: 0.5.0** — local player profile save foundation.

Does **not** claim production multiplayer, combat, or cloud systems.

## Version History

| Version | Milestone |
|---------|-----------|
| 0.1.0 | Architecture foundation |
| 0.2.0 | GameShell, Boot / Login / Lobby |
| 0.3.0 | Registry metadata, shared ModuleScreen, module navigation |
| 0.4.0 | Dedicated character catalog module + development seeds |
| **0.5.0 (current)** | Local versioned player profile, staged save, backup recovery |

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
  ⇄ CharacterScreen (catalog definitions only)
```

## Local Save (0.5.0)

- Paths: `user://feibao/player_profile.json` (+ `.tmp` / `.bak`)
- Missing save is normal first run (memory default, no boot write).
- Corrupt primary may recover from backup; both corrupt → safe default, files kept.
- Only a **validated** primary may refresh backup; invalid primary never overwrites a valid backup.
- Saves with no validated recovery source fail closed (sources unchanged).
- Test paths use canonical containment under `user://feibao_tests/`; production fingerprints must stay unchanged.
- No auto-login; no cloud; no encryption / absolute atomic claims.

See `docs/FEIBAO_0.5.0_LOCAL_PLAYER_SAVE.md`.

## Character Catalog (0.4.0+)

- Definition JSON is separate from player ownership.
- Default owned id: `feibao_dev` only.

## Explicit Exclusions

Combat, gacha, shop, cloud accounts, anti-cheat, multi-slot save UI, Android signing, third-party commercial assets.
