# Twenty original fish illustrations

## Delivered assets

- `assets/fish20/<species_id>.svg`: 20 independent right-facing original vector illustrations; each is 600 × 360, with transparent surroundings.
- `assets/fish20/<species_id>.png`: matching transparent 600 × 360 raster exports, rendered by Godot 4.7.2.
- `assets/fish20/manifest.json`: authoritative index/ID paths, exact alpha bounds, body anchor, body ellipse and proportional gameplay sizing.
- `assets/fish20/contact-sheet.png`: bilingual 20-card large/detail sheet with three small samples per fish.
- `assets/fish20/contact-sheet-game-size.png`: bilingual small-size review sheet.
- `assets/fish20/validation.json`: unique PNG hashes, dimensions, SVG syntax checks, bounds and maximum gameplay height checks.

The ordering is identical to `Catalog.ACTIVE_IDS`. Legacy numeric fish kinds are **not** species indices.

## Art direction and anatomy

Warm natural-history illustration: teal ink, olive/cream body shading, fine scale engraving, individual fin-ray strokes and restrained highlights. Every species has an independently authored body Bézier outline. Family fin architectures are shared where biologically appropriate, but diagnostic anatomy and markings are species-specific. This is illustrative identification artwork, not a scientific field-identification key.

Distinctive packages include deep small-mouthed sunfish, large-jawed largemouth bass, short-jawed barred smallmouth, belly dot rows on spotted bass, deep white bass versus long striped bass, spotted versus barred crappie with different dorsal-spine counts, rear-dorsal duckbill pike, reflective-eyed walleye with white lower tail tip, long versus short/red ear flaps, straight versus curved anal fins and barbels on catfish, brook-trout worm markings/blue-haloed red spots/white-edged lower fins, and rainbow-trout pink stripe/black spots. Both trout and catfish have adipose fins. Catfish have no scale engraving.

Sources for anatomical facts and official species links: `docs/fish-morphology.md`. **No source photo, illustration, traced outline or third-party image file was incorporated.** These are newly authored project drawings. The deliverable is supplied for use and modification in One Last Cast with no third-party image-license obligations or attribution requirement from reused assets. No external asset package or new software was installed.

Sex, age, water clarity and season affect natural colors. Channel-catfish spots represent a smaller adult; longear colors represent a colorful adult male. Game display width/tier are readability choices, not physical body length or scientifically measured size ratios. Real-world length values are intentionally not invented in the art manifest.

## Integration contract

Use the PNG or SVG unchanged. All fish face right. Preserve aspect ratio.

Let `s = desired_visible_width / visual_bounds_px[2]`.

- Draw the full image at top-left `collision_position - anchor_px * s` and size `(600, 360) * s`.
- Body ellipse center is exactly `collision_position`.
- Body ellipse radii are `body_ellipse_radii_px * s`.
- `body_ellipse_center_normalized` and `body_ellipse_radii_normalized` are fractions of the full 600 × 360 canvas, **not** fractions of trimmed alpha bounds.
- Negative horizontal scale mirrors around that same collision anchor. Do not mirror around canvas center without adjusting the offset.
- `recommended_visual_width_pt` caps the total visible fish height at 26 points, protecting the seven-row field. Deep fish are narrower, while pike can use 70 points.
- Exclude tail, fin tips and whiskers from the body collision ellipse. Do not derive hit radius from the full transparent image dimensions.
- Use `recommended_tier` only as an art/gameplay suggestion. The rules/catalog own authoritative encounter difficulty.

## Rebuilding on SSD

From the project directory, run in this order:

1. `python3 assets/source/fish20/build_fish_art.py`
2. `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script assets/source/fish20/render_fish_art.gd`
3. `CLANG_MODULE_CACHE_PATH="$PWD/assets/source/fish20/.module-cache" /usr/bin/swift assets/source/fish20/label_contact_sheets.swift`
4. `python3 assets/source/fish20/validate_fish_art.py`

The Python generator validates XML before each SVG write. Godot checks actual loaded dimensions and transparent corners, computes exact alpha bounds, writes the manifest v2 and exports PNGs. Native macOS text rendering supplies English/Chinese sheet labels, because Godot's SVG image loader omits SVG text. The Swift step changes contact sheets only, never the individual fish.

## Visual QA

Inspected all 20 rendered fish at large size and downscaled sizes, including eyes, jaws, gills, tail joins, fins and neighboring-species differences. Corrected a detached rock-bass dorsal and fin-ray clipping; a malformed intermediate sheet was caught during independent review and fixed by enforcing well-formed XML before rendering. The final sheet has no detached eye/fin/spot clusters. Small detail necessarily disappears around 33 points, so catfish barbels, fine spots and fin counts are best read in the catalog; silhouette and primary pattern remain the gameplay cues.

Artifact review does not by itself prove in-game integration, actual collision alignment or catch/ledger mapping. Those require the parent integration and gameplay verification.
