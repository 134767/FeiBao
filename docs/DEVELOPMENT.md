# FeiBao Development Guide

## Godot Version

- **Engine:** Godot **4.7.1** Standard (not mono / .NET)
- **Renderer:** Mobile
- **Language:** GDScript
- **CLI path (local convention):** `C:\Godot\godot.exe` (`godot` on PATH)

## Open the Project

1. Install or place Godot 4.7.x Standard.
2. Open Godot → Import / Open → select `C:\Users\v5990\fei-bao` (or clone path).
3. Or from a terminal:

```powershell
Set-Location "C:\Users\v5990\fei-bao"
godot --path .
```

VS Code: open the folder; recommended extension is `geequlim.godot-tools` (see `.vscode/extensions.json`).

## Headless Project Parse

Validates that the project loads in the editor without fatal parse errors:

```powershell
Set-Location "C:\Users\v5990\fei-bao"
godot --headless --editor --path . --quit
```

Expect exit code `0`.

## Run Architecture Smoke Tests

```powershell
Set-Location "C:\Users\v5990\fei-bao"
godot --headless --path . --script res://tests/test_runner.gd
```

- Prints `[PASS]` / `[FAIL]` per assertion.
- Ends with `TEST SUMMARY: X passed, Y failed`.
- Exit code `0` if `Y == 0`, otherwise non-zero.

## Runtime Boot Check

Runs the main scene briefly:

```powershell
godot --headless --path . --quit-after 3
```

Expect exit code `0` once a main scene is configured.

## Git Branch & PR Rules

- **Default branch:** `main` — do **not** commit feature work directly to `main`.
- Create feature branches from the latest `main`:

```powershell
git fetch origin --prune
git checkout main
git pull --ff-only origin main
git checkout -b feature/<task-name>
```

- Open **Draft** PRs against `main` for Cloud Director review.
- Do not merge until review is complete (unless explicitly authorized).
- **No force push** to shared branches.
- **No rebase** of already-pushed history without explicit instruction.

## What Not to Commit

- `.godot/` (generated cache)
- Export / build outputs (`build/`, `dist/`, `exports/`)
- Screenshots (keep under untracked `tmp-review/` if needed)
- Secrets: `.env`, tokens, credentials, signing keys
- APK, AAB, PCK, or third-party proprietary assets

## Safety Reminders

- Offline-first and clean-room: original work only.
- Do not unpack or import commercial game APK content.
- Do not add Android signing keys in this foundation phase.
