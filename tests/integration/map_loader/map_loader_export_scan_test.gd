## Story ML-001 AC-4: MapConfig is never an export type (scans src/; real file access belongs here).
extends GutTest


func test_map_config_is_never_an_export_type() -> void:
	var offenders: Array[String] = []
	var stack: Array[String] = ["res://src"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		for sub: String in DirAccess.get_directories_at(dir_path):
			stack.append(dir_path + "/" + sub)
		for file: String in DirAccess.get_files_at(dir_path):
			if not file.ends_with(".gd"):
				continue
			var text: String = FileAccess.get_file_as_string(dir_path + "/" + file)
			var rx: RegEx = RegEx.create_from_string("@export[^\\n]*var [^\\n:]*:\\s*MapConfig")
			if rx.search(text) != null:
				offenders.append(dir_path + "/" + file)
	assert_eq(offenders, [] as Array[String])
