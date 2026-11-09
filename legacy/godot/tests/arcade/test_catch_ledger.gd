extends SceneTree
const Catalog = preload("res://scripts/arcade/fish_catalog.gd")
const Ledger = preload("res://scripts/arcade/catch_ledger.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)
func _init() -> void:
	var ledger = Ledger.new()
	check(Catalog.ENTRIES.size() == 30 and Catalog.available_count() == 20, "30 retained IDs, twenty actually available")
	var ids := {}
	for entry in Catalog.all_species():
		check(not ids.has(entry.id) and not entry.name_zh.is_empty() and not entry.scientific_name.is_empty(), "unique complete catalog entry")
		ids[entry.id] = true
	check(Catalog.species_for_kind(4) == Catalog.species_for_kind(6), "trophy size is same bass species")
	check(Catalog.species_for_kind(-1) == "" and Catalog.species_for_kind(8) == "", "invalid kinds rejected")
	check(ledger.load_from_dictionary({}) and ledger.total_catches() == 0, "legacy missing ledger safely starts zero")
	check(not ledger.record_catch("snail", "junk1") and not ledger.record_catch("weed", "junk2"), "snails and weeds never fish catches")
	check(not ledger.record_catch("common_carp", "future") and not ledger.record_catch("unknown", "x"), "unavailable and unknown species rejected")
	check(not ledger.record_catch("bluegill", ""), "empty event token rejected")
	check(ledger.record_catch("bluegill", "session:1:1"), "first basket recorded")
	check(not ledger.record_catch("bluegill", "session:1:1") and not ledger.record_catch("walleye", "session:1:1"), "event token globally idempotent")
	check(ledger.record_catch("largemouth_bass", "session:1:2") and ledger.record_catch(Catalog.species_for_kind(6), "session:1:3"), "both bass variants aggregate")
	check(ledger.total_catches() == 3 and ledger.count_for("largemouth_bass") == 2 and ledger.caught_species_count() == 2, "accurate total and distinct species")
	var copy = Ledger.new()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(ledger.save_to_dictionary()))
	check(copy.load_from_dictionary(saved) and copy.total_catches() == 3, "JSON roundtrip retains counts")
	check(not copy.record_catch("bluegill", "session:1:1"), "duplicate protection survives reload")
	check(copy.record_catch("bluegill", "session:2:1") and copy.total_catches() == 4, "new run preserves lifetime catches")
	var descending: Array = ledger.sorted_counts()
	check(descending[0].id == "largemouth_bass" and descending[0].count == 2, "descending comparison")
	check(ledger.sorted_counts(false)[0].count == 0 and ledger.sorted_counts(true, false).size() == 20, "ascending comparison and availability filter")
	check(not copy.load_from_dictionary({"version": 999}) and copy.total_catches() == 4, "future schema does not destroy state")
	check(not copy.load_from_dictionary({"version":1,"counts":[],"recent_tokens":[]}) and copy.total_catches() == 4, "invalid containers do not destroy state")
	check(copy.load_from_dictionary({"version":1,"counts":{"bluegill":-1,"walleye":2.5,"pumpkinseed":"8","smallmouth_bass":99,"snail":99,"largemouth_bass":5},"recent_tokens":[]}), "corrupt count payload sanitized")
	check(copy.total_catches() == 104 and copy.count_for("smallmouth_bass") == 99 and copy.count_for("snail") == 0, "preserve historical species counts; unknown junk excluded from fish totals")
	for i in range(Ledger.MAX_RECENT_TOKENS + 10):
		check(copy.record_catch("bluegill", "bounded:%d" % i), "distinct bounded event recorded")
	check(copy.save_to_dictionary().recent_tokens.size() == Ledger.MAX_RECENT_TOKENS, "bounded persistent duplicate window")
	check(not copy.record_catch("bluegill", "bounded:265"), "latest duplicate rejected")
	check(Catalog.ACTIVE_IDS.size() == 20 and Catalog.active_species().size() == 20, "twenty visible species")
	check(Catalog.species_for_kind(6) == "largemouth_bass" and Catalog.species_for_index(6) == "northern_pike", "legacy and new indices remain distinct")
	check(Catalog.species_for_index(18) == "brook_trout" and Catalog.species_for_index(19) == "rainbow_trout", "frozen trout indices")
	check(Catalog.species_for_index(-1) == "" and Catalog.species_for_index(20) == "", "invalid new indices rejected")
	check(copy.sorted_counts(true, true, true).size() == 20, "active-only comparisons")
	var migration = Ledger.new()
	check(migration.load_from_dictionary({"version":1,"counts":{"bluegill":4,"common_carp":11,"retired_species":9,"weed":6},"recent_tokens":["old:event"]}), "version 1 migration accepted")
	check(migration.total_catches() == 15 and migration.count_for("common_carp") == 11, "hidden historical species retained without backfill")
	check(migration.active_caught_species_count() == 1 and migration.caught_species_count() == 2, "active discovery count separate from historical species count")
	var upgraded: Dictionary = migration.save_to_dictionary()
	check(upgraded.version == 2 and upgraded.counts.size() == 30 and upgraded.archived_counts.retired_species == 9 and upgraded.archived_counts.weed == 6, "v2 retains all thirty IDs and quarantines unknown old keys")
	var restored = Ledger.new()
	check(restored.load_from_dictionary(JSON.parse_string(JSON.stringify(upgraded))) and restored.total_catches() == 15, "v2 migration JSON roundtrip")
	check(restored.save_to_dictionary().archived_counts.retired_species == 9 and not restored.record_catch("retired_species", "new:event"), "unknown historical data preserved but cannot become new catch")
	check(not restored.record_catch("bluegill", "old:event"), "v1 migration retains duplicate prevention")
	var all_twenty = Ledger.new()
	for species_id in Catalog.ACTIVE_IDS:
		check(Catalog.is_available(species_id) and all_twenty.record_catch(species_id, "twenty:" + species_id), "integrated species accepts real catch: " + species_id)
		check(not all_twenty.record_catch(species_id, "twenty:" + species_id), "each species catch is idempotent")
	check(all_twenty.total_catches() == 20 and all_twenty.active_caught_species_count() == 20, "all twenty counted distinctly")
	for entry in Catalog.ENTRIES:
		if entry.id not in Catalog.ACTIVE_IDS:
			check(not entry.available and not all_twenty.record_catch(entry.id, "hidden:" + entry.id), "hidden legacy species cannot create catches")
	var empty = Ledger.new()
	for row in empty.sorted_counts():
		check(row.count == 0 and row.fraction == 0.0, "zero state has safe ratios")
	print("Catch ledger: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
