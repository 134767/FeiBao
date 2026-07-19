# FeiBao Architecture

## Project Goal

FeiBao is a mobile-first, portrait-first Godot 4.x application.
**Current version: 1.1.0** — battle encounter & combatant foundation.

Does **not** claim production multiplayer, finished combat, or cloud systems.

## Version History

| Version | Milestone |
|---------|-----------|
| 0.1.0 | Architecture foundation |
| 0.2.0 | GameShell, Boot / Login / Lobby |
| 0.3.0 | Registry metadata, shared ModuleScreen, module navigation |
| 0.4.0 | Dedicated character catalog module + development seeds |
| 0.5.0 | Local versioned player profile, staged save, backup recovery |
| 0.6.0 | Ownership + representative wired into character catalog UI |
| 0.7.0 | Active party formation + profile schema 2 + lazy schema 1 migration |
| 0.8.0 | Adventure stage selection + StageCatalog + AdventureState preparation |
| 0.9.0 | Battle session shell + BattleScreen (no real combat) |
| 1.0.0 | 6×5 board, BattleRuntime, deterministic turn resolution |
| **1.1.0 (current)** | Encounter combatants, enemy catalog, party/enemy HP display |

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
  ⇄ ModuleScreen (inventory, farm, settings)
  ⇄ AdventureScreen (area/stage selection + preparation)
  ⇄ BattleScreen (board + turn loop; not a lobby module)
  ⇄ CharacterScreen (catalog + ownership / representative)
  ⇄ PartyScreen (active party 1–3, leader ≠ representative)
```

## Battle Encounter & Combatants (1.1.0)

- Character combat stats + enemy + stage-encounter catalogs (memory blueprints only).
- Catalog numerics: **whole JSON numbers** normalized to int (not claimed as Variant TYPE_INT).
- Snapshot combatant fields remain **TYPE_INT only**.
- `BattleEncounterModel` inside BattleRuntime; atomic board+encounter begin/snapshot.
- BattleScreen shows party/enemy HP status; no damage, AI, win/loss, or rewards.
- PlayerProfile schema remains **2**.

See `docs/FEIBAO_1.1.0_BATTLE_ENCOUNTER_COMBATANTS.md`.

## Battle Board & Turn Loop (1.0.0)

- BattleState = session shell; BattleRuntime = board / RNG / turns / events (memory-only).
- Runtime **full session binding**: area + stage + party order + leader.
- Pure domain: `BattleBoardModel`, `BattleBoardEngine`, resolution event dictionaries.
- Deterministic seed from session fields; no global RNG / time seed; hard-cap cascade rollback.
- Enter creates state + runtime; leave clears both with dual-snapshot rollback.

See `docs/FEIBAO_1.0.0_BATTLE_BOARD_TURN_LOOP.md`.

## Battle Session Shell (0.9.0)

- BattleState memory-only session from prepared stage + active party snapshot.
- Two-step Adventure flow: prepare stage, then enter battle (transactional).
- Dedicated BattleScreen (not a lobby module); leave clears session with rollback on nav failure.
- No real combat, completion write, or schema change.

See `docs/FEIBAO_0.9.0_BATTLE_SESSION_SHELL.md`.

## Adventure Stage Selection (0.8.0)

- StageCatalog pure data (no UI / PlayerData).
- AdventureState memory-only prepare_stage for battle entry.
- No combat, drops, or stage completion persistence; profile schema stays 2.

See `docs/FEIBAO_0.8.0_ADVENTURE_STAGE_SELECTION.md`.

## Active Party (0.7.0)

- `PlayerProfile` schema **2** adds `active_party_character_ids`.
- Schema 1 loads migrate in memory; disk upgrades on next successful changed save.
- Party leader is index 0; independent of `selected_character_id`.

See `docs/FEIBAO_0.7.0_ACTIVE_PARTY.md`.

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
