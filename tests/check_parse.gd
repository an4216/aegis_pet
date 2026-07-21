# 모든 GDScript 파일 파스 검증. 실행:
#   godot --headless --path . --script tests/check_parse.gd
extends SceneTree

var fails := 0


func _init() -> void:
	_scan("res://")
	print("PARSE RESULT: %s" % ("OK" if fails == 0 else "%d file(s) failed" % fails))
	quit(1 if fails > 0 else 0)


func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with(".") and entry != "addons":
				_scan(full)
		elif entry.ends_with(".gd"):
			var script = load(full)
			if script == null or not (script as Script).can_instantiate():
				fails += 1
				print("PARSE FAIL: " + full)
		entry = dir.get_next()
	dir.list_dir_end()
