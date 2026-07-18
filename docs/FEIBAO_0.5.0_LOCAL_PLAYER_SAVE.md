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

1. **Classify** existing primary/backup as MISSING / VALID / INVALID / UNREADABLE via the validator.
2. Ensure parent directory exists.
3. Write temporary file, flush/close, and check write errors.
4. Re-read temporary and validate with codec.
5. If validation fails, delete temporary and **leave all sources untouched**.
6. **Backup policy:** only a **validated primary** may update backup; invalid primary **never** overwrites a legal backup.
7. When primary is invalid but backup is valid, preserve backup byte-for-byte and still allow writing a new primary.
8. When there is **no** VALID recovery source (e.g. both corrupt), save **fail-closed** and does not modify files.
9. Replace primary with validated temporary content; on failure attempt restore.
10. Remove temporary on all paths.

Recovery after load still never deletes corrupt sources during `initialize()`.

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
4. Valid name forms a **persistence transaction**:
   - capture memory + primary/tmp/backup artifact snapshot
   - `PlayerData.save_player_name` (save_text restores artifacts on its own write failures)
   - navigate Lobby
5. Save failure → stay on Login; save_text leaves no partial artifacts.
6. Navigation failure → **complete transaction rollback** of profile, AppState, PlayerData flags, and exact primary/tmp/backup **raw bytes**.
7. Failed candidate names must not remain on primary, temporary, or backup (and cannot reappear via backup recovery).
8. First-login navigation failure leaves **no** save files.
9. Prior corrupt primary bytes are restored exactly (not silently repaired), including invalid UTF-8 / BOM / NUL payloads.

### Artifact snapshot (v2)

- Kind: `save_artifact_snapshot_v2`
- Authority content: **PackedByteArray** (not String)
- Capture uses `get_buffer` / raw length; SHA-256 hashes the raw bytes
- Restore uses `store_buffer` and re-verifies bytes/length/hash
- Invalid UTF-8 and other non-text corrupt bytes can still be captured and restored exactly
- Snapshots live only in memory for the active transaction
- Normal profile payloads remain UTF-8 JSON via `save_text`

## Character Boundary

- Catalog / `CharacterDefinition` remain definition-only (no ownership fields).
- Profile stores **ids only**, not definition payloads.
- `partner_a` is not owned by default.

## Explicit Non-Goals

No auto-login, cloud sync, encryption, anti-cheat, multi-slot UI, unlock UX, combat stats, or schema migration beyond rejecting non-v1.

## Testing Isolation

- Automated tests use contained paths under `user://feibao_tests/<case>/`.
- Path validation uses **canonical / simplified containment** (not mere string prefix): rejects `../` traversal and lookalike roots such as `user://feibao_tests_case`.
- Cleanup may only delete a case’s primary / `.tmp` / `.bak` (no recursive deletes of parent trees).
- Production artifacts under `user://feibao/` may **pre-exist**; tests fingerprint (exists + SHA-256 + length) before/after and must remain unchanged.
- Tests must not create or repair production saves.
