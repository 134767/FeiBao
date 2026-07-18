# FeiBao Development Guide

## Godot Version

- **Engine:** Godot **4.7.1** Standard (not mono / .NET)
- **Renderer:** Mobile
- **App version:** **0.5.0**
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

## Local Player Save (0.5.0)

- Production: `user://feibao/player_profile.json`
- Codec: exact-integer schema/revision; no silent fractional truncation
- Staged write + backup recovery (not absolute atomic guarantee)
- Only validated primary updates backup; recovery-after-corrupt must preserve legal backup
- Fail closed when primary/backup are both invalid
- Corrupt files are not deleted on initialize
- Tests: `user://feibao_tests/<case>/` with canonical containment; fingerprint production artifacts instead of requiring them to be absent

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
