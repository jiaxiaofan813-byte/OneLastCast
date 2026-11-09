class_name GameStore
extends RefCounted
var directory: String
var recovered_backup = false
var writable = true
func _init(testing: bool = false) -> void:
	directory = "res://runtime/qa-isolated" if testing else ("res://runtime" if OS.has_feature("editor") else "user://")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
func path(name: String) -> String:
	return directory.path_join(name)
func load_state() -> Dictionary:
	for name in ["save-v2.json","save-v2.json.bak"]:
		var file = path(name)
		if not FileAccess.file_exists(file): continue
		var data = _parse(FileAccess.get_file_as_string(file))
		if data is Dictionary and data.get("version",0)==2 and data.get("settings") is Dictionary and data.get("best") is Dictionary:
			recovered_backup = name.ends_with(".bak")
			return data
	# Import the initial prototype's records without affecting gameplay.
	var old = path("settings.json")
	if FileAccess.file_exists(old):
		var data = _parse(FileAccess.get_file_as_string(old))
		if data is Dictionary and data.get("version",0)==1:
			return {"version":2,"settings":{"muted":data.get("muted",false),"reduced_motion":data.get("reduced_motion",false)},"best":data.get("best",{"A":0,"B":0}),"rounds":data.get("rounds",0)}
	return {}
func save_state(data: Dictionary) -> bool:
	var temp = FileAccess.open(path("save-v2.json.tmp"),FileAccess.WRITE)
	if not temp: writable = false; return false
	temp.store_string(JSON.stringify(data))
	temp.flush()
	temp.close()
	if FileAccess.file_exists(path("save-v2.json")):
		# Keep only a known-valid preceding document as the recovery copy.
		var previous = _parse(FileAccess.get_file_as_string(path("save-v2.json")))
		if previous is Dictionary and previous.get("version",0)==2:
			DirAccess.copy_absolute(ProjectSettings.globalize_path(path("save-v2.json")),ProjectSettings.globalize_path(path("save-v2.json.bak")))
	var error = DirAccess.rename_absolute(ProjectSettings.globalize_path(path("save-v2.json.tmp")),ProjectSettings.globalize_path(path("save-v2.json")))
	writable = error == OK
	return writable
func append_round(data: Dictionary) -> void:
	if not OS.has_feature("editor"): return
	var file = FileAccess.open(path("rounds-v2.jsonl"),FileAccess.READ_WRITE) if FileAccess.file_exists(path("rounds-v2.jsonl")) else FileAccess.open(path("rounds-v2.jsonl"),FileAccess.WRITE)
	if file: file.seek_end(); file.store_line(JSON.stringify(data))

func _parse(text: String) -> Variant:
	var parser=JSON.new()
	return parser.data if parser.parse(text)==OK else null
