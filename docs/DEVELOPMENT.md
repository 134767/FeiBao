# FeiBao Development Guide

## Godot Version

- **Engine:** Godot **4.7.1** Standard (not mono / .NET)
- **Renderer:** Mobile
- **App version:** **1.1.0**
- **Language:** GDScript
- **CLI:** `C:\Godot\godot.exe`

## Open the Project

```powershell
Set-Location "C:\Users\v5990\fei-bao"
godot --path .
```

## Headless Project Parse

```powershell
godot --headless --editor --path . --quit
```

Expect exit code `0`.

## Run Tests

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

- Ends with `TEST SUMMARY: X passed, Y failed`
- Exit code `0` only when failed == 0
- Suites isolate saves under `user://feibao_tests/` and must not touch production `user://feibao/`

## Runtime Boot Check

```powershell
godot --headless --path . --quit-after 5
```

Expect exit code `0`. Flow: Bootstrap → GameShell → Boot (PlayerData.initialize) → Login.

## Local Player Save (0.5.0+)

- Production: `user://feibao/player_profile.json`
- Codec: exact-integer schema/revision; no silent fractional truncation
- Staged write + backup recovery (not absolute atomic guarantee)
- Only validated primary updates backup; recovery-after-corrupt must preserve legal backup
- Fail closed when primary/backup are both invalid
- Corrupt files are not deleted on initialize
- Login persistence transaction rolls back full **byte-exact** artifact snapshots on navigation failure
- save_text write failures restore full pre-write raw-byte artifact snapshots
- Snapshot authority is PackedByteArray (`get_buffer` / `store_buffer`), not String decode/re-encode
- Tests: `user://feibao_tests/<case>/` with canonical containment; fingerprint production artifacts instead of requiring them to be absent
- 0.6.0: `grant_character` / `select_character` share the same commit helper; schema stays 1

## Character Ownership (0.6.0)

- Default ownership: `feibao_dev` only; partners are not auto-granted
- Catalog UI filters and representative selection; no grant UI in this version
- See `docs/FEIBAO_0.6.0_CHARACTER_OWNERSHIP.md`

## Active Party (0.7.0)

- Profile schema **2**; schema 1 loads with lazy migration (no boot write)
- Dedicated PartyScreen; party mutations via `PlayerData` only
- PartyScreen uses page-level vertical scroll for narrow reachability
- Roster columns contract: 360→2, 390→2, 720→4
- See `docs/FEIBAO_0.7.0_ACTIVE_PARTY.md`

## Adventure Stage Selection (0.8.0)

- StageCatalog development seeds; AdventureState prepare context
- Dedicated AdventureScreen; stage grid columns 2/2/4
- See `docs/FEIBAO_0.8.0_ADVENTURE_STAGE_SELECTION.md`

## Battle Session Shell (0.9.0)

- BattleState memory-only; BattleScreen shell (no real combat)
- Adventure: prepare stage, then enter battle (separate CTA, transactional nav)
- See `docs/FEIBAO_0.9.0_BATTLE_SESSION_SHELL.md`

## Battle Board & Turn Loop (1.0.0)

- BattleRuntime + pure board engine; 6×5 deterministic match board
- Full session binding (area/stage/party/leader); canonical inactive snapshot
- Global RNG isolation + forced hard-cap fixture + keyboard/responsive rect evidence
- Enter creates state + runtime; leave clears both with dual rollback
- See `docs/FEIBAO_1.0.0_BATTLE_BOARD_TURN_LOOP.md`

## Battle Encounter & Combatants (1.1.0)

- Combat stats / enemy / stage-encounter catalogs; BattleEncounterModel
- Atomic board+encounter begin; snapshot includes `encounter`
- BattleScreen party/enemy HP lines; no damage or victory
- See `docs/FEIBAO_1.1.0_BATTLE_ENCOUNTER_COMBATANTS.md`

## Git Branch & PR Rules

- Do **not** commit feature work directly to `main`.
- Open **Draft** PRs against `main`.
- No force push to shared branches.
- No merge until Cloud Director review authorizes it.

## What Not to Commit

- `.godot/`
- Export / build outputs
- Secrets, tokens, signing keys
- Production or test save JSON under the repository
- Marketplace downloads
- Test temp logs (keep under Windows TEMP)

## Safety Reminders

- Offline-first and clean-room.
- AppState has no disk I/O; PlayerData owns persistence.
- Character definitions are not ownership records.
- Do not unpack commercial game APK content.
