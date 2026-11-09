extends RefCounted
## Canonical sprite/collision geometry generated from the verified original-art manifest.
## Pixel anchor is the body ellipse center, not the transparent canvas center.
const DATA := {
	"bluegill": {"texture":"res://assets/fish20/bluegill.png", "anchor":Vector2(340,186), "canvas":Vector2(600.0,360.0), "radii":Vector2(180,80), "width":43.0, "bounds_width":467, "tier":0},
	"pumpkinseed": {"texture":"res://assets/fish20/pumpkinseed.png", "anchor":Vector2(340,186), "canvas":Vector2(600.0,360.0), "radii":Vector2(180,80), "width":43.0, "bounds_width":465, "tier":0},
	"black_crappie": {"texture":"res://assets/fish20/black_crappie.png", "anchor":Vector2(340,183), "canvas":Vector2(600.0,360.0), "radii":Vector2(187,73), "width":48.0, "bounds_width":487, "tier":1},
	"yellow_perch": {"texture":"res://assets/fish20/yellow_perch.png", "anchor":Vector2(340,181), "canvas":Vector2(600.0,360.0), "radii":Vector2(192,49), "width":55.0, "bounds_width":495, "tier":1},
	"largemouth_bass": {"texture":"res://assets/fish20/largemouth_bass.png", "anchor":Vector2(340,183), "canvas":Vector2(600.0,360.0), "radii":Vector2(190,52), "width":62.0, "bounds_width":494, "tier":2},
	"walleye": {"texture":"res://assets/fish20/walleye.png", "anchor":Vector2(340,181), "canvas":Vector2(600.0,360.0), "radii":Vector2(192,49), "width":64.0, "bounds_width":500, "tier":2},
	"northern_pike": {"texture":"res://assets/fish20/northern_pike.png", "anchor":Vector2(345,183), "canvas":Vector2(600.0,360.0), "radii":Vector2(200,30), "width":70.0, "bounds_width":513, "tier":3},
	"smallmouth_bass": {"texture":"res://assets/fish20/smallmouth_bass.png", "anchor":Vector2(340,183), "canvas":Vector2(600.0,360.0), "radii":Vector2(190,52), "width":59.0, "bounds_width":480, "tier":2},
	"spotted_bass": {"texture":"res://assets/fish20/spotted_bass.png", "anchor":Vector2(340,183), "canvas":Vector2(600.0,360.0), "radii":Vector2(190,52), "width":59.0, "bounds_width":486, "tier":2},
	"white_bass": {"texture":"res://assets/fish20/white_bass.png", "anchor":Vector2(340,183), "canvas":Vector2(600.0,360.0), "radii":Vector2(190,52), "width":52.0, "bounds_width":489, "tier":1},
	"striped_bass": {"texture":"res://assets/fish20/striped_bass.png", "anchor":Vector2(340,183), "canvas":Vector2(600.0,360.0), "radii":Vector2(190,52), "width":65.0, "bounds_width":501, "tier":3},
	"rock_bass": {"texture":"res://assets/fish20/rock_bass.png", "anchor":Vector2(340,186), "canvas":Vector2(600.0,360.0), "radii":Vector2(180,80), "width":46.0, "bounds_width":471, "tier":1},
	"white_crappie": {"texture":"res://assets/fish20/white_crappie.png", "anchor":Vector2(340,183), "canvas":Vector2(600.0,360.0), "radii":Vector2(187,73), "width":48.0, "bounds_width":488, "tier":1},
	"green_sunfish": {"texture":"res://assets/fish20/green_sunfish.png", "anchor":Vector2(340,186), "canvas":Vector2(600.0,360.0), "radii":Vector2(180,80), "width":47.0, "bounds_width":476, "tier":0},
	"redear_sunfish": {"texture":"res://assets/fish20/redear_sunfish.png", "anchor":Vector2(340,186), "canvas":Vector2(600.0,360.0), "radii":Vector2(180,80), "width":44.0, "bounds_width":466, "tier":0},
	"longear_sunfish": {"texture":"res://assets/fish20/longear_sunfish.png", "anchor":Vector2(340,186), "canvas":Vector2(600.0,360.0), "radii":Vector2(180,80), "width":43.0, "bounds_width":460, "tier":0},
	"channel_catfish": {"texture":"res://assets/fish20/channel_catfish.png", "anchor":Vector2(345,185), "canvas":Vector2(600.0,360.0), "radii":Vector2(195,46), "width":66.0, "bounds_width":532, "tier":2},
	"blue_catfish": {"texture":"res://assets/fish20/blue_catfish.png", "anchor":Vector2(345,185), "canvas":Vector2(600.0,360.0), "radii":Vector2(195,46), "width":66.0, "bounds_width":532, "tier":3},
	"brook_trout": {"texture":"res://assets/fish20/brook_trout.png", "anchor":Vector2(340,183), "canvas":Vector2(600.0,360.0), "radii":Vector2(192,47), "width":60.0, "bounds_width":497, "tier":1},
	"rainbow_trout": {"texture":"res://assets/fish20/rainbow_trout.png", "anchor":Vector2(340,183), "canvas":Vector2(600.0,360.0), "radii":Vector2(192,47), "width":63.0, "bounds_width":500, "tier":2},
}
static func scale_for(species_id: String) -> float:
	return float(DATA[species_id].width)/float(DATA[species_id].bounds_width) if DATA.has(species_id) else 1.0
static func radius_for(species_id: String) -> Vector2:
	return DATA[species_id].radii*scale_for(species_id)+Vector2(4,4) if DATA.has(species_id) else Vector2(20,14)
static func tier_for(species_id: String) -> int:
	return int(DATA[species_id].tier) if DATA.has(species_id) else 0
