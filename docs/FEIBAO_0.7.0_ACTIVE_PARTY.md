# FeiBao 0.7.0 — Active Party Formation & Profile Schema 2

## Summary

Version **0.7.0** upgrades the party module from a shared placeholder to a dedicated **single active party** formation screen, and advances `PlayerProfile` to **schema 2** with lazy schema 1 migration.

- Active party holds **1–3** owned character IDs.
- Slot **0** is the **party leader** (distinct from representative `selected_character_id`).
- Schema 1 saves load in memory as schema 2 without immediate disk write; the next successful changed save persists schema 2.

## Schema 2

```json
{
  "schema_version": 2,
  "profile_kind": "local_player",
  "player_name": "示例",
  "owned_character_ids": ["feibao_dev"],
  "selected_character_id": "feibao_dev",
  "active_party_character_ids": ["feibao_dev"],
  "revision": 0
}
```

| Field | Rules |
|-------|--------|
| `active_party_character_ids` | Non-empty, max 3, unique, each in owned |
| `selected_character_id` | Must be owned; **need not** be in party |
| Extra keys | Rejected (strict per schema) |

### Schema 1 → 2 migration

- Strict schema 1 parser (no `active_party_character_ids` allowed on disk payload).
- In-memory profile becomes schema 2 with `active_party_character_ids = [selected_character_id]`.
- **Revision unchanged** by migration.
- **No boot-time write**; `PlayerData.is_profile_migration_pending()` until next successful changed save.

## Domain API (`PlayerData`)

- `add_party_member` / `remove_party_member` / `move_party_member`
- Catalog required for **add** only; remove/move allow unknown persisted party IDs
- Party mutations never change ownership or representative
- Signals: `profile_changed` (UI refresh authority), `party_changed` (domain listeners)

## PartyScreen

- Three slots, owned-only roster, add / remove / left / right actions
- Focus, leader, and representative are separate concepts
- Single full-refresh path via `profile_changed`
- Touch targets: actions ≥48px, slots/cards ≥72px
- **BodyScroll** (page-level vertical scroll; horizontal disabled) so 360×640 / 390×844 can reach all actions
- Roster columns: **exactly 2 / 2 / 4** on 360 / 390 / 720 viewports
- UI remove uses **pending focus** applied during the single `profile_changed` rebuild
- Remove fallback:
  1. remaining member at the same index (next slides into the hole),
  2. else the **previous** remaining member (`provisional[last]`),
  3. removing leader (index 0) focuses the new index-0 leader
- Visible slot/roster focus must match internal `_focused_id`
- BodyScroll vertical range is measured as `vbar.max_value - vbar.page` (360/390 must be > 0.5)

## Explicit exclusions

Multi-party, combat stats, captain skills, equipment, gacha, cloud, multi-slot, schema 3+, marketplace assets.
