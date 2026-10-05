## Editor entry of the offline content preflight (ADR-0008 Decision 5; Story OBS-011): File > Run prints every P1
## record of the library so a designer can check a chunk while authoring. Set `LIBRARY_PATH` and run.
## Reads the authored classes as data only; never shipped on the device.
@tool
extends EditorScript

const LIBRARY_PATH: String = "res://assets/data/chunks/chunk_library_01.tres"


func _run() -> void:
	var library: ChunkLibrary = load(LIBRARY_PATH) as ChunkLibrary
	if library == null:
		print("ContentPreflight: no ChunkLibrary at ", LIBRARY_PATH)
		return
	var records: Array[Dictionary] = ContentPreflight.run(library, ContentPreflightConfig.new())
	print("ContentPreflight P1: %d record(s)" % records.size())
	for rec: Dictionary in records:
		print("  %s chunk=%s s0=%s %s" % [rec["code"], rec["chunk_id"], rec["s0"], rec["detail"]])
