# Bundled iOS font

## Asset and load contract

- Runtime path: `res://assets/fonts/NotoSansSC-Regular.ttf`.
- Godot 4.7.2 imports it as `FontFile`; use `load(...) as FontFile` or `preload(...)`.
- Regular weight 400, static TrueType, family `Noto Sans SC`.
- This is the full official Google Fonts asset, not a project-specific subset. It supports 30,890 characters and leaves room for future localized text.
- `.ttf.import` sets `allow_system_fallback=false` and has no fallback fonts. Keep those settings to avoid the iOS system-font path/FreeType failure. A defensive runtime `font.allow_system_fallback = false` is safe.
- Integrate on iOS only initially. Existing Mac SystemFont typography and released Mac applications are intentionally untouched by this asset task.
- Keep `NotoSansSC-OFL.txt` with redistributed copies. Godot does not automatically export arbitrary text files: add `assets/fonts/NotoSansSC-OFL.txt` to the iOS export preset's `include_filter`.
- `source/` is audit material, excluded from Godot import by `.gdignore`. It need not ship.

## License and provenance

SIL Open Font License 1.1. The unmodified license is retained in `NotoSansSC-OFL.txt`. Its notice credits Adobe (2014–2021), with Reserved Font Name `Source`. No Apple system font was copied, embedded, installed, or changed.

Official public stylesheet (no project text or private content was transmitted):
https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400

Exact font URL from that stylesheet:
https://fonts.gstatic.com/s/notosanssc/v41/k3kCo84MPvpLmixcA63oeAL7Iqp5IZJF9bmaG9_FnYw.ttf

Official license source:
https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/OFL.txt

Font: 10,540,644 bytes.
SHA-256: `450625c8d46ab3df97b7904ded955ec2746d17ec76740cb1e91d1ba63a0f89af`.

License SHA-256: `1c05c68c34f9708415aada51f17e1b0092d2cea709bf4a94cd38114f9e73d7d9`.

The downloaded font bytes are unmodified. No font tools or system fonts were installed. Machine-readable provenance and source checksums are in `source/manifest.json`.

## Local verification

Run from the project root:

`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/arcade/test_bundled_font.gd`

This loads the real imported FontFile, disables all system fallback, checks every printable character in the current scripts/scenes plus ASCII, checks the English/Chinese/scientific names of all 20 active fish, visits the live frontdoor pages in both languages, records text metrics, and rasterizes bilingual samples with Godot's FreeType into an audit image. It does not run the game or load/change player saves. It opens no window.

Artifacts:
- `source/godot-validation.log` and `.json`: actual checks, glyph coverage and metric results.
- `source/godot-font-raster-proof.png`: actual FreeType glyph raster audit, not a game or simulator screenshot. It is manually composed from Godot glyph bitmaps; native screen layout must be checked separately.

Initial coverage: all 539 source/scene/ASCII characters were present, with no `.notdef` glyphs. The full font contains 30,890 supported characters. No missing glyph was found in live English/Chinese menus or any of the 20 fish names.

## Metrics and integration notes

At Godot's default imported hinting, size 12 has ascent 14 / descent 4 / height 18; size 16 has 19 / 5 / 24; size 28 has 33 / 9 / 42. Chinese advance is exactly the requested size. This font's line height is taller than the previously selected Mac system font.

The isolated frontdoor audit found no width overflows. It reports three vertical allowances to check in the iOS integration: English title tutorial needs 36 px where the existing fixed rectangle is 34 px, and the Settings heading needs 42 px where its rectangle is 40 px in both languages. These are layout warnings, not missing-glyph failures. Main/frontdoor code was not changed in this asset task.

## Engine diagnosis boundary

Godot 4.7.2's `platform/ios/os_ios.h` inherits `OS_AppleEmbedded`. The inherited implementation in `drivers/apple_embedded/os_apple_embedded.mm` provides `get_system_font_path` and `get_system_font_path_for_text` via CoreText `kCTFontURLAttribute` (around lines 615–738). It advertises system-font support. It is therefore incorrect to claim that iOS has no implementation. A CoreText family name or URL does not itself prove FreeType can read usable font bytes in the app/simulator. The existing empty-font errors and missing native labels motivate bypassing that path with the bundled FontFile. This task does not claim to have reproduced the platform URL failure inside iOS; that requires the separate native integration run.
