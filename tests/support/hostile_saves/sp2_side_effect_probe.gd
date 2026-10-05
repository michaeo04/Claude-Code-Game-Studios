## SP-2 probe: if any code path instantiates this script while parsing a hostile save, `fired` becomes true.
## Framework-free: no GUT call.
extends RefCounted

static var fired: bool = false


func _init() -> void:
	fired = true
