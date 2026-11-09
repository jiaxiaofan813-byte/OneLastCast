extends SceneTree
func _initialize():
 var base = "<project-root>/assets/fish20/"
 var manifest = JSON.parse_string(FileAccess.get_file_as_string(base + "manifest.json"))
 var failures = []
 var widths = [43,43,48,55,62,64,70,59,59,52,65,46,48,47,44,43,66,66,60,63]
 var tiers = [0,0,1,1,2,2,3,2,2,1,3,1,1,0,0,0,2,3,1,2]
 var profiles = {"sun":[340,186,180,80],"crappie":[340,183,187,73],"bass":[340,183,190,52],"perch":[340,181,192,49],"pike":[345,183,200,30],"cat":[345,185,195,46],"trout":[340,183,192,47]}
 for entry in manifest.species:
  var im = Image.new()
  var err = im.load_svg_from_string(FileAccess.get_file_as_string(base + entry.id + ".svg"), 1.0)
  if err != OK:
   failures.append(entry.id)
   continue
  im.save_png(base + entry.id + ".png")
  var used = im.get_used_rect()
  entry.visual_bounds_px = [used.position.x,used.position.y,used.size.x,used.size.y]
  var p = profiles[entry.family]
  entry.anchor_px = [p[0],p[1]]
  entry.body_ellipse_center_px = [p[0],p[1]]
  entry.body_ellipse_radii_px = [p[2],p[3]]
  entry.body_ellipse_center_normalized = [float(p[0])/600.0,float(p[1])/360.0]
  entry.body_ellipse_radii_normalized = [float(p[2])/600.0,float(p[3])/360.0]
  entry.body_hitbox_px = [p[0]-p[2],p[1]-p[3],p[2]*2,p[3]*2]
  entry.recommended_visual_width_pt = minf(widths[entry.index],26.0*float(used.size.x)/float(used.size.y))
  entry.recommended_canvas_size_pt = [entry.recommended_visual_width_pt*600.0/used.size.x,entry.recommended_visual_width_pt*360.0/used.size.x]
  entry.recommended_tier = tiers[entry.index]
  entry.render_note = "Use uniform scale = desired visual width / visual_bounds_px[2]. Draw origin = collision position minus anchor_px * scale. Hit ellipse radii = body_ellipse_radii_px * scale. Preserve proportions."
  print(entry.id, " ",im.get_size()," used=",used," transparent_corner=",im.get_pixel(0,0).a)
 manifest.version = 2
 var mf = FileAccess.open(base + "manifest.json",FileAccess.WRITE)
 mf.store_string(JSON.stringify(manifest,"  "))
 mf.close()
 for name in ["contact-sheet", "contact-sheet-game-size"]:
  var im = Image.new()
  var err = im.load_svg_from_string(FileAccess.get_file_as_string(base + name + ".svg"), 1.0)
  if err == OK: im.save_png(base + name + ".png")
 print("FAILURES=",failures)
 quit(0 if failures.is_empty() else 1)
