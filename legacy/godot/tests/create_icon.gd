extends SceneTree
func _initialize():
	var image=Image.new()
	var error=image.load_svg_from_string(FileAccess.get_file_as_string("res://assets/ui/app_icon.svg"))
	if error!=OK: quit(1); return
	image.convert(Image.FORMAT_RGB8)
	image.save_png("res://assets/ui/app_icon.png")
	var file=FileAccess.open("res://assets/ui/GODOT_LICENSES.txt",FileAccess.WRITE)
	file.store_string(Engine.get_license_text()+"\n\n")
	for component in Engine.get_copyright_info():
		file.store_string(str(component.get("name",""))+"\n")
		for part in component.get("parts",[]):
			for line in part.get("copyright",[]): file.store_string(str(line)+"\n")
	for name in Engine.get_license_info(): file.store_string("\n"+name+"\n"+Engine.get_license_info()[name]+"\n")
	file.close()
	print("ICON_AND_LICENSES_CREATED 1024 RGB")
	quit()
