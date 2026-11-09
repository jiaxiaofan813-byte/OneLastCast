extends SceneTree
func _initialize():
 var base = "<project-root>/"
 var image = Image.new()
 var error = image.load_svg_from_string(FileAccess.get_file_as_string(base + "assets/source/cover/cover.svg"), 1.0)
 if error != OK:
  push_error("Cover SVG failed")
  quit(1)
  return
 image.convert(Image.FORMAT_RGB8)
 image.save_png(base + "assets/ui/cover/cover.png")
 image.resize(360,640,Image.INTERPOLATE_LANCZOS)
 image.save_png(base + "assets/ui/cover/cover-preview.png")
 print("COVER_OK 1080x1920 opaque source and 360x640 preview")
 quit()
