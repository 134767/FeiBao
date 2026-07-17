# FeiBao Development Guide

## Godot Version

- **Engine:** Godot **4.7.1** Standard (not mono / .NET)
- **Renderer:** Mobile
- **App version:** **0.2.0**
- **Language:** GDScript
- **CLI:** `C:\Godot\godot.exe` (`godot` on PATH)

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

- Prints `[PASS]` / `[FAIL]` per assertion
- Ends with `TEST SUMMARY: X passed, Y failed`
- Exit code `0` only when failed == 0

## Runtime Boot Check

```powershell
godot --headless --path . --quit-after 3
```

Expect exit code `0`. Flow: Bootstrap → GameShell → Boot → Login.

## Git Branch & PR Rules

- Do **not** commit feature work directly to `main`.
- Branch from latest `main`:

```powershell
git fetch origin --prune
git checkout main
git pull --ff-only origin main
git checkout -b feature/<task-name>
```

- Open **Draft** PRs against `main`.
- No force push to shared branches.
- No merge until Cloud Director review authorizes it.

## What Not to Commit

- `.godot/`
- Export / build outputs
- Secrets, tokens, signing keys
- APK, AAB, PCK, proprietary assets
- Test temp logs (`_*.txt`)

## Safety Reminders

- Offline-first and clean-room: original work only.
- Player name is memory-only in 0.2.0 — do not add disk saves without a dedicated task.
- Do not unpack or import commercial game APK content.
