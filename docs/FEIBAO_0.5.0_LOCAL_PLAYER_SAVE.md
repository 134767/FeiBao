# FeiBao 0.5.0 — Local Player Profile Save Foundation

## Summary

Version **0.5.0** adds a versioned, local, recoverable player profile under Godot `user://` storage.

- Player name can persist across restarts.
- Login pre-fills a saved name but **never auto-logs in**.
- Character catalog definitions stay separate from player ownership state.

## Profile Schema (`schema_version = 1`)

```json
{
  "schema_version": 1,
  "profile_kind": "local_player",
  "player_name": "示例",
  "owned_character_ids": ["feibao_dev"],
  "selected_character_id": "feibao_dev",
  "revision": 1
}
```

| Field | Rules |
|-------|--------|
| `schema_version` | Exact integer `1` (`1.0` ok; fractional rejected) |
| `profile_kind` | Must be `local_player` |
| `player_name` | Already trimmed; length 0..12 (empty = not yet logged in) |
| `owned_character_ids` | Non-empty unique `^[a-z0-9_]+$` ids |
| `selected_character_id` | Must be one of owned ids |
| `revision` | Non-negative exact integer |
| Extra top-level keys | Rejected (explicit migration required) |

Default ownership: only `feibao_dev` owned and selected.

## Production Paths

| Role | Path |
|------|------|
| Directory | `user://feibao` |
| Primary | `user://feibao/player_profile.json` |
| Temporary | `user://feibao/player_profile.json.tmp` |
| Backup | `user://feibao/player_profile.json.bak` |

## Staged / Recoverable Write

`SaveFileStore` performs a **staged recoverable write** (not a claim of absolute cross-platform atomic write):

1. Ensure parent directory exists.
2. Write temporary file and flush/close.
3. Re-read temporary and validate with codec.
4. If validation fails, delete temporary and **leave primary untouched**.
5. If primary exists, copy it to backup.
6. Replace primary with validated content.
7. Remove temporary.

## Load / Recovery

| Situation | Result |
|-----------|--------|
| Primary valid | `LOADED_PRIMARY` |
| Primary invalid, backup valid | `RECOVERED_BACKUP` (files not deleted) |
| Both invalid | `SAFE_DEFAULT_CORRUPT` memory default; **files preserved** |
| Missing both | `NEW_PROFILE` memory default; **no write on boot** |

Corrupt files are **not** overwritten during `initialize()`.

## Components

| Piece | Role |
|-------|------|
| `PlayerProfile` | Immutable-ish snapshot model |
| `PlayerProfileCodec` | Pure JSON parse/encode |
| `SaveFileStore` | Text file staged write + backup recovery |
| `PlayerData` | Autoload coordinator; syncs AppState name |
| `AppState` | Session only (no file I/O) |

## Boot / Login Behavior

1. Boot calls `PlayerData.initialize()` once, then goes to Login.
2. Login pre-fills saved name when present.
3. User must still press **開始遊戲**.
4. Valid name → `PlayerData.save_player_name` → then navigate Lobby.
5. Save failure → stay on Login with user message.
6. Navigation failure → restore prior AppState name and profile snapshot (disk write attempted).

## Character Boundary

- Catalog / `CharacterDefinition` remain definition-only (no ownership fields).
- Profile stores **ids only**, not definition payloads.
- `partner_a` is not owned by default.

## Explicit Non-Goals

No auto-login, cloud sync, encryption, anti-cheat, multi-slot UI, unlock UX, combat stats, or schema migration beyond rejecting non-v1.

## Testing Isolation

Automated tests use `user://feibao_tests/<case>/` only and must not touch `user://feibao/player_profile.json`.
