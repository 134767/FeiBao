# FeiBao 0.6.0 — Character Ownership & Catalog Integration

## Summary

Version **0.6.0** connects existing `PlayerProfile` ownership fields to the character catalog UI.

- Catalog shows **owned / unowned / representative / focused** states with visible text markers.
- Players may inspect every catalog character, but only **owned** characters may become the representative.
- Domain APIs `PlayerData.grant_character` and `PlayerData.select_character` support future rewards; **no grant UI** in this version.
- **Profile schema remains version 1** — 0.5.0 saves load without migration.

## Architecture

| Layer | Responsibility |
|-------|----------------|
| `CharacterDefinition` / `CharacterCatalog` | Pure definitions only (no owned/selected fields) |
| `PlayerProfile` | Immutable snapshot of IDs + player state |
| `PlayerData` | Catalog ID validation, immutable mutations, save, signals |
| `CharacterScreen` / `CharacterCard` | Read PlayerData and render; no direct FileAccess/JSON encode |

## Profile Schema (`schema_version = 1`, unchanged)

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

Default profile still owns and selects only `feibao_dev`. Partners are **not** auto-granted.

## Domain API

### `PlayerProfile` (immutable)

- `with_character_granted(character_id) -> { ok, changed, profile, error }`
- `with_selected_character(character_id) -> { ok, changed, profile, error }`

Rules:

- ID non-empty and `^[a-z0-9_]+$`.
- Grant appends without duplicates; does not change selected id.
- Select requires ownership; does not modify owned list.
- Duplicate grant/select: `ok=true`, `changed=false`, revision unchanged.
- Failures return a defensive duplicate of the original snapshot.

### `PlayerData`

- `grant_character(character_id) -> { ok, changed, error, profile_revision, character_id }`
- `select_character(character_id) -> { ok, changed, error, profile_revision, character_id }`
- `get_owned_character_ids()`, `is_known_character()`, `get_known_owned_count()`

Validation:

- Loads `CharacterCatalog.load_default()` on each production mutation.
- Unknown catalog IDs are rejected (regex alone is insufficient).
- Catalog load failure does not mutate memory or disk.
- Save failure: memory profile, disk artifacts, and revision stay prior; state = `SAVE_FAILED`.
- Duplicate mutation: no encode, no disk write, no signals.
- `grant_character` never auto-selects the granted character.
- AppState player name is not changed by grant/select.

Signals (only on successful changed writes):

- `profile_changed(revision)`
- `character_granted(character_id, revision)`
- `selected_character_changed(character_id, revision)`

## UI

### CharacterCard

`configure(definition, is_owned, is_representative)` plus `set_focused`.

Visible markers (not color-only):

| State | Text |
|-------|------|
| Owned | 已持有 |
| Unowned | 未持有 |
| Representative | 代表 |
| Focused (detail inspect) | 檢視中 |

Unowned cards remain pressable for detail inspect.

### CharacterScreen

- Summary: `已持有 N / total`
- Filters: 全部 / 已持有 / 未持有 (combine with search)
- Detail action: 設為代表角色 (owned only; disabled when already representative or unowned)
- Focus vs representative are separate fields
- Initial focus prefers current representative when visible
- Subscribes to PlayerData signals; bindings are idempotent and cleared on exit

## Explicit Exclusions

Gacha, shop, stage/quest rewards UI, character fragments, revoke ownership, stats, party, equipment, multi-slot, cloud sync, auto-login, marketplace assets, schema migration.

## Related

- `docs/FEIBAO_0.5.0_LOCAL_PLAYER_SAVE.md` — schema 1 save foundation
- `docs/FEIBAO_0.4.0_CHARACTER_CATALOG.md` — catalog definitions
