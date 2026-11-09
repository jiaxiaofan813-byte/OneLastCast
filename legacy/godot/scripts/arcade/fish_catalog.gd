extends RefCounted
## Stable species IDs are save keys. Kind 6 is a size variant, not a species.
const KIND_TO_ID := ["bluegill", "pumpkinseed", "black_crappie", "yellow_perch", "largemouth_bass", "walleye", "largemouth_bass", "northern_pike"]
## Twenty verified integrated species; legacy records remain in ENTRIES below.
const ACTIVE_IDS := ["bluegill", "pumpkinseed", "black_crappie", "yellow_perch", "largemouth_bass", "walleye", "northern_pike", "smallmouth_bass", "spotted_bass", "white_bass", "striped_bass", "rock_bass", "white_crappie", "green_sunfish", "redear_sunfish", "longear_sunfish", "channel_catfish", "blue_catfish", "brook_trout", "rainbow_trout"]
const ENTRIES := [
	{"id": "bluegill", "name_zh": "蓝鳃太阳鱼", "name_en": "Bluegill", "scientific_name": "Lepomis macrochirus", "available": true},
	{"id": "pumpkinseed", "name_zh": "南瓜籽太阳鱼", "name_en": "Pumpkinseed", "scientific_name": "Lepomis gibbosus", "available": true},
	{"id": "black_crappie", "name_zh": "黑莓鲈", "name_en": "Black crappie", "scientific_name": "Pomoxis nigromaculatus", "available": true},
	{"id": "yellow_perch", "name_zh": "黄鲈", "name_en": "Yellow perch", "scientific_name": "Perca flavescens", "available": true},
	{"id": "largemouth_bass", "name_zh": "大口黑鲈", "name_en": "Largemouth bass", "scientific_name": "Micropterus salmoides", "available": true},
	{"id": "walleye", "name_zh": "大眼梭鲈", "name_en": "Walleye", "scientific_name": "Sander vitreus", "available": true},
	{"id": "northern_pike", "name_zh": "白斑狗鱼", "name_en": "Northern pike", "scientific_name": "Esox lucius", "available": true},
	{"id": "smallmouth_bass", "name_zh": "小口黑鲈", "name_en": "Smallmouth bass", "scientific_name": "Micropterus dolomieu", "available": true},
	{"id": "spotted_bass", "name_zh": "斑点黑鲈", "name_en": "Spotted bass", "scientific_name": "Micropterus punctulatus", "available": true},
	{"id": "white_bass", "name_zh": "白鲈", "name_en": "White bass", "scientific_name": "Morone chrysops", "available": true},
	{"id": "striped_bass", "name_zh": "条纹鲈", "name_en": "Striped bass", "scientific_name": "Morone saxatilis", "available": true},
	{"id": "rock_bass", "name_zh": "岩钝鲈", "name_en": "Rock bass", "scientific_name": "Ambloplites rupestris", "available": true},
	{"id": "white_crappie", "name_zh": "白莓鲈", "name_en": "White crappie", "scientific_name": "Pomoxis annularis", "available": true},
	{"id": "green_sunfish", "name_zh": "绿太阳鱼", "name_en": "Green sunfish", "scientific_name": "Lepomis cyanellus", "available": true},
	{"id": "redear_sunfish", "name_zh": "红耳太阳鱼", "name_en": "Redear sunfish", "scientific_name": "Lepomis microlophus", "available": true},
	{"id": "longear_sunfish", "name_zh": "长耳太阳鱼", "name_en": "Longear sunfish", "scientific_name": "Lepomis megalotis", "available": true},
	{"id": "channel_catfish", "name_zh": "斑点叉尾鮰", "name_en": "Channel catfish", "scientific_name": "Ictalurus punctatus", "available": true},
	{"id": "blue_catfish", "name_zh": "蓝鲶", "name_en": "Blue catfish", "scientific_name": "Ictalurus furcatus", "available": true},
	{"id": "flathead_catfish", "name_zh": "扁头鲶", "name_en": "Flathead catfish", "scientific_name": "Pylodictis olivaris", "available": false},
	{"id": "brown_bullhead", "name_zh": "褐首鲶", "name_en": "Brown bullhead", "scientific_name": "Ameiurus nebulosus", "available": false},
	{"id": "black_bullhead", "name_zh": "黑首鲶", "name_en": "Black bullhead", "scientific_name": "Ameiurus melas", "available": false},
	{"id": "yellow_bullhead", "name_zh": "黄首鲶", "name_en": "Yellow bullhead", "scientific_name": "Ameiurus natalis", "available": false},
	{"id": "rainbow_trout", "name_zh": "虹鳟", "name_en": "Rainbow trout", "scientific_name": "Oncorhynchus mykiss", "available": true},
	{"id": "brown_trout", "name_zh": "褐鳟", "name_en": "Brown trout", "scientific_name": "Salmo trutta", "available": false},
	{"id": "brook_trout", "name_zh": "溪红点鲑", "name_en": "Brook trout", "scientific_name": "Salvelinus fontinalis", "available": true},
	{"id": "lake_trout", "name_zh": "湖红点鲑", "name_en": "Lake trout", "scientific_name": "Salvelinus namaycush", "available": false},
	{"id": "common_carp", "name_zh": "鲤鱼", "name_en": "Common carp", "scientific_name": "Cyprinus carpio", "available": false},
	{"id": "freshwater_drum", "name_zh": "淡水石首鱼", "name_en": "Freshwater drum", "scientific_name": "Aplodinotus grunniens", "available": false},
	{"id": "muskellunge", "name_zh": "北美狗鱼", "name_en": "Muskellunge", "scientific_name": "Esox masquinongy", "available": false},
	{"id": "chain_pickerel", "name_zh": "网纹狗鱼", "name_en": "Chain pickerel", "scientific_name": "Esox niger", "available": false},
 ]

static func all_species() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in ENTRIES:
		result.append(entry.duplicate(true))
	return result

static func species_for_kind(kind: int) -> String:
	return KIND_TO_ID[kind] if kind >= 0 and kind < KIND_TO_ID.size() else ""

static func get_species(species_id: String) -> Dictionary:
	for entry in ENTRIES:
		if entry.id == species_id:
			return entry.duplicate(true)
	return {}

static func is_available(species_id: String) -> bool:
	var entry := get_species(species_id)
	return bool(entry.get("available", false))

static func available_count() -> int:
	var result := 0
	for entry in ENTRIES:
		if entry.available:
			result += 1
	return result

## New gameplay indices are deliberately separate from legacy kinds 0..7.
static func species_for_index(index: int) -> String:
	return ACTIVE_IDS[index] if index >= 0 and index < ACTIVE_IDS.size() else ""

static func index_for_species(species_id: String) -> int:
	return ACTIVE_IDS.find(species_id)

static func active_species() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for species_id in ACTIVE_IDS:
		rows.append(get_species(species_id))
	return rows
