extends RefCounted
## Pure save data; caller owns file I/O and writes only after confirmed basket events.
const Catalog = preload("res://scripts/arcade/fish_catalog.gd")
const VERSION := 2
const MAX_RECENT_TOKENS := 256
const MAX_COUNT := 1000000000
var _counts: Dictionary = {}
# Preserve unknown legacy keys verbatim as valid counts, excluded from fish totals.
var _archived_counts: Dictionary = {}
var _recent_tokens: Array[String] = []

func _init() -> void:
	setup()

func setup() -> void:
	_counts.clear()
	_archived_counts.clear()
	_recent_tokens.clear()
	for entry in Catalog.ENTRIES:
		_counts[entry.id] = 0

## Pass only the nested catch_ledger dictionary. Old settings have none: pass {}.
## Unknown schema is rejected without changing existing state. Missing legacy data
## initializes zero, never reconstructing species or catch counts from best scores.
func load_from_dictionary(data: Dictionary) -> bool:
	if data.is_empty():
		setup()
		return true
	var version: Variant = data.get("version", null)
	if not (version is int or version is float) or (version != 1 and version != VERSION):
		return false
	if not data.get("counts", null) is Dictionary or not data.get("recent_tokens", null) is Array:
		return false
	setup()
	var incoming: Dictionary = data.counts
	for key in incoming:
		var value: Variant = incoming[key]
		if not key is String or not _valid_count(value):
			continue
		if _counts.has(key):
			# Existing historical facts survive changes in visibility/availability.
			_counts[key] = int(value)
		else:
			_archived_counts[key] = int(value)
	var archived: Variant = data.get("archived_counts", {})
	if archived is Dictionary:
		for key in archived:
			if key is String and _valid_count(archived[key]) and not _counts.has(key) and not _archived_counts.has(key):
				_archived_counts[key] = int(archived[key])
	var tokens: Array = data.recent_tokens
	for index in range(maxi(0, tokens.size() - MAX_RECENT_TOKENS), tokens.size()):
		var token: Variant = tokens[index]
		if token is String and not token.is_empty() and token.length() <= 256 and not _recent_tokens.has(token):
			_recent_tokens.append(token)
	return true

func save_to_dictionary() -> Dictionary:
	return {"version": VERSION, "counts": _counts.duplicate(true), "archived_counts": _archived_counts.duplicate(true), "recent_tokens": _recent_tokens.duplicate()}

## Idempotent within a persisted bounded recent window, not arbitrary ancient replay.
## Caller supplies globally unique session/run/catch-counter tokens (never fish ID).
func record_catch(species_id: String, unique_catch_token: String) -> bool:
	if not Catalog.is_available(species_id) or unique_catch_token.is_empty() or unique_catch_token.length() > 256:
		return false
	if _recent_tokens.has(unique_catch_token) or count_for(species_id) >= MAX_COUNT:
		return false
	_counts[species_id] = count_for(species_id) + 1
	_recent_tokens.append(unique_catch_token)
	if _recent_tokens.size() > MAX_RECENT_TOKENS:
		_recent_tokens.pop_front()
	return true

func count_for(species_id: String) -> int:
	return int(_counts.get(species_id, 0))

func total_catches() -> int:
	var total := 0
	for count in _counts.values():
		total += int(count)
	return total

func caught_species_count() -> int:
	var total := 0
	for count in _counts.values():
		if int(count) > 0:
			total += 1
	return total

## Full catalog rows plus count and fraction (0 when total is 0), deterministic ties.
func sorted_counts(descending: bool = true, include_unavailable: bool = true, active_only: bool = false) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var total := total_catches()
	for entry in (Catalog.active_species() if active_only else Catalog.all_species()):
		if not include_unavailable and not entry.available:
			continue
		entry["count"] = count_for(entry.id)
		entry["fraction"] = float(entry["count"]) / total if total > 0 else 0.0
		rows.append(entry)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.count == b.count:
			return String(a.id) < String(b.id)
		return a.count > b.count if descending else a.count < b.count)
	return rows

func active_caught_species_count() -> int:
	var total := 0
	for species_id in Catalog.ACTIVE_IDS:
		if count_for(species_id) > 0:
			total += 1
	return total

func _valid_count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= MAX_COUNT and float(value) == floor(float(value))
