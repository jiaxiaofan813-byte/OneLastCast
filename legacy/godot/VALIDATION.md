# Archive validation

Checked on 2026-11-09 with Godot 4.7.2, using a separate staging copy. These are headless source checks, not physical-device or visual certification.

## Passed

- Clean headless editor asset import.
- Headless startup with the two optional music tracks absent: no script or resource errors.
- `tests/arcade/test_shallow_rules.gd`
- `tests/arcade/test_geometry_access.gd`
- `tests/arcade/test_arcade_integration.gd`
- `tests/arcade/test_catch_ledger.gd`
- `tests/arcade/test_collection_integration.gd`
- `tests/arcade/test_ui_acceptance.gd`
- `tests/arcade/test_frontdoor_ui.gd`
- `tests/arcade/test_frontdoor_integration.gd`
- `tests/arcade/test_frontdoor_localization.gd`
- `tests/arcade/test_english_integration.gd`
- `tests/arcade/test_mobile_safe_area.gd`
- `tests/arcade/test_mobile_targets.gd`
- `tests/arcade/test_mobile_game_integration.gd`
- `tests/arcade/test_visual_physics.gd`

## Not passed / not run

- `test_journey_rules.gd`: stopped at a 30-second limit. No pass is claimed.
- `test_difficulty_curve.gd`: fails its prerequisite because it loads an earlier 0.6 comparison file from `Legacy/`, which is not part of this archive. This is a missing historical test fixture, not a passing difficulty check.
- `test_difficulty_independent.gd`: not run in this archive pass.
- `test_music_controller.gd` and `test_music_integration.gd`: not run because they require the two excluded local tracks.
- Older prototype tests and the font raster audit were not rerun in this archive pass.
- No iPhone/iPad hardware test, visual review, signed app distribution, App Store submission or native Xcode build was performed as part of this archive.

## Packaging checks

- Font and license SHA-256 values match their retained provenance.
- Source review found no private keys, API tokens, workstation/user paths or personal contact data in the staged files. Public third-party license contacts are retained.
- Private saves, caches, logs, recordings, build output, signing settings and uncleared music are excluded from tracked files.
