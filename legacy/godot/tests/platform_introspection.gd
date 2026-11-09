extends SceneTree
func _initialize():
	for p in ClassDB.class_get_property_list("Control"):
		if "accessibility" in p.name: print("CONTROL_PROPERTY ",p.name)
	for p in ProjectSettings.get_property_list():
		if "accessibility" in p.name: print("PROJECT_PROPERTY ",p.name,"=",ProjectSettings.get_setting(p.name))
	quit()
