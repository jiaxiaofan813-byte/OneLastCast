# Opening cover: Homeward light

## Delivered artwork

- `assets/ui/cover/cover.png`: final opaque 1080 × 1920 PNG, designed at 360 × 640 logical points.
- `assets/ui/cover/cover-preview.png`: 360 × 640 inspection preview.
- `assets/source/cover/cover.svg`: complete editable vector scene, no linked raster images, fonts or external dependencies.
- `assets/source/cover/build_cover.py`: deterministic original scene generator.
- `assets/source/cover/render_cover.gd`: Godot headless SVG-to-PNG exporter.

## Story and visual system

A slightly comic, determined angler tries one final cast while a warm cabin window waits across the lake. An oversized stitched fishing hat, feather and lure, scruffy beard, creel weave, coat pockets, tiny reel, cedar plank seams, rivets, oar grain, tea cup and glowing lantern reward closer inspection. The surrounding pine forest, distant mountain, quiet sunset and small reflected strokes keep the setting freshwater and welcoming.

Cream, olive-gold and teal deliberately match the existing natural-history fish drawings. The two underwater glimpses are the actual project-authored bluegill and brook-trout vectors, preserved with unique SVG ID prefixes and reduced opacity. They are not invented tropical substitutes.

## Integration contract

The artwork contains no baked title, button, logo or credit. Display with preserved 9:16 aspect ratio. Upper y=70–235 is quiet cream title space. Hero occupies approximately x=75–275, y=252–390; the oar tip extends to x=48, y=406. Bottom y=410–610 is quiet dark teal menu space, with subdued fish at the far edges. A menu card beginning at y=394 will cover a small part of the oar tip, but no principal character or boat content. The cabin and fishing line should not be separately cropped.

A separate title background is optional because the sky is already designed for dark teal title typography. The image may receive a restrained fade or subtle pan, but the scene does not require new animation layers. Do not distort or stretch the individual art.

## Rebuild

From the project directory on the SSD:

1. `python3 assets/source/cover/build_cover.py`
2. `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script assets/source/cover/render_cover.gd`

The generator checks SVG XML syntax before writing. The exporter uses Godot's SVG loader without opening a game window. No new software is installed.

## Verification and rights

Inspected the exported 360 × 640 image directly. Character face, hat, hand, rod, reel, boat rails, cabin, wicker basket, lantern, water reflections and both fish render cleanly. Main title and menu regions remain quiet. Full export is 1080 × 1920 with opaque background.

This scene is newly authored original project artwork, including the code-authored illustration. No photograph, third-party illustration, traced outline, external font, licensed art package or AI-generated image is embedded. The fish are reused from this project's original fish20 set. Supplied for use and modification in One Last Cast with no third-party asset attribution obligation. No invented artist credits are required.
