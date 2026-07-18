# FeiBao Development Guide

## Godot Version

- **Engine:** Godot **4.7.1** Standard (not mono / .NET)
- **Renderer:** Mobile
- **App version:** **0.4.0**
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

Expect exit code `0`. After 0.3.0 canonical `project.godot` ordering, editor launches should not dirty the worktree.

## Run Tests

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

- Prints `[PASS]` / `[FAIL]` per assertion
- Ends with `TEST SUMMARY: X passed, Y failed`
- Exit code `0` only when failed == 0
- 0.4.0 adds `tests/character_catalog_smoke_test.gd` (total passed **> 697**)

## Runtime Boot Check

```powershell
godot --headless --path . --quit-after 5
```

Expect exit code `0`. Flow: Bootstrap → GameShell → Boot → Login.

## Character Catalog Data

- Default path: `res://data/character_catalog.json`
- Loader: `CharacterCatalog.parse_json_text` / `load_default` (pure, no UI)
- Seeds are **development samples only** — not final worldbuilding
- Empty `portrait_path` → native text glyph placeholder (no external images)

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
- Marketplace downloads (art, fonts, audio, plugins)
- Test temp logs (keep under Windows TEMP)

## Safety Reminders

- Offline-first and clean-room: original work only.
- Player name remains memory-only — do not add disk saves without a dedicated task.
- Character catalog is read-only seeds — no ownership or progression yet.
- Do not unpack or import commercial game APK content.
