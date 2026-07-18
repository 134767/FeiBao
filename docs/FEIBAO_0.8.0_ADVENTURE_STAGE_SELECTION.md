# FeiBao 0.8.0 — Adventure Stage Selection Foundation

## Summary

Version **0.8.0** replaces the adventure placeholder with a dedicated **AdventureScreen**, a pure **StageCatalog** data layer, and an in-memory **AdventureState** preparation context for future battle systems.

- 2 development-seed areas × 3 stages each (6 stages total)
- Area `story_intro` is shown only on the adventure selection page
- **No real battle**, drops, completion flags, or profile schema change

## Stage Catalog

- Path: `res://data/stage_catalog.json`
- Schema: exact integer **1**, `catalog_kind = development_seed`
- Strict exact-integer validation for schema / sort_order / stage_number
- Global unique area and stage ids; contiguous `stage_number` from 1 per area
- Fail-closed; returned arrays are defensive copies

## AdventureState (autoload)

- Memory only — never writes disk or PlayerProfile
- `prepare_stage` / `clear_prepared_stage` with idempotent no-signal on no-change
- Signal: `prepared_stage_changed(area_id, stage_id)` once per real change

## AdventureScreen

- Registry path: dedicated `PATH_ADVENTURE_SCREEN`
- BodyScroll page scroll; stage grid columns **2 / 2 / 4** on 360 / 390 / 720
- Markers: 檢視中 / 已準備 / 開發樣本 (not color-only)
- Party summary uses **leader**, not representative
- Prepare button sets AdventureState only — no battle scene

## Explicit exclusions

Combat, enemies, HP/ATK, drops, stage completion persistence, stamina, multiplayer, marketplace assets.

## Next

0.9.0 consumes AdventureState prepared stage context for a memory-only battle session shell (see `docs/FEIBAO_0.9.0_BATTLE_SESSION_SHELL.md`).
