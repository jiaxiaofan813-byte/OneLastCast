# Godot 0.7.0 archive

This is the historical Godot version of **One Last Cast / 最后一竿**, archived on 2026-11-09. Future development uses **Xcode and native iOS**. This folder is not the active development platform.

## Run

Use Godot **4.7.2**. Import `project.godot` and run the project, or use:

```sh
godot --path .
```

English is the default language. Settings can switch between English and Chinese. The portrait arcade prototype includes a cover, tutorial, pause/settings screens, 20-species fish catalog, original effects, and persistent catch records.

## Controls

1. Start from the cover. The hook casts automatically.
2. Click, tap or press Space to dive toward a visible fish.
3. Click, tap or press Space again when the rings meet.
4. A successful catch lands in the basket and starts the next cast. An early, late or empty attempt ends the run. Retry starts a new run without clearing lifetime catches.

Esc pauses. F1 opens tuning controls. N starts the next run from the result screen.

## Public archive changes

- Removed the original workstation-specific save-directory override. Editor runs use `res://runtime`; exported runs use Godot's `user://` location.
- Music startup now safely returns without playing when the optional local tracks are absent.
- Updated the save-location test for portable behavior. Gameplay rules and artwork are otherwise retained.
- Excluded personal saves, logs, screenshots, recordings, import/build caches, exported applications, local export/signing settings, earlier prototype backups, and the separately developed native project.
- Excluded the two local music files. The music controller is preserved for reference, but this public copy has **no background music**. See `assets/music/README.md`.

The source version remains 0.7.0. This is a source archive, not a release certification or a claim of verified physical-iPhone performance.

## Checks

First import assets:

```sh
godot --headless --editor --path . --quit
```

Run a test from this directory, for example:

```sh
godot --headless --path . --script tests/arcade/test_shallow_rules.gd
godot --headless --path . --script tests/arcade/test_journey_rules.gd
godot --headless --path . --script tests/arcade/test_collection_integration.gd
```

See `VALIDATION.md` for checks actually run against this archive. `test_music_controller.gd` and `test_music_integration.gd` require the excluded tracks and are not passing checks for the public copy. `test_difficulty_curve.gd` additionally requires an older comparison fixture that is not included. `test_arcade_rules.gd` targets the older long-press prototype and is not the 0.7.0 acceptance entry point.

## Assets and rights

See `ASSET_NOTICES.md`. The original asset generators are included under `assets/source/`. No new project-wide license has been applied.
