## Test double: a SaveCore that only counts `boot_load()` and `flush()` calls. No GUT call.
extends SaveCore

var boot_count: int = 0
var flush_count: int = 0


func boot_load() -> void:
	boot_count += 1


func flush() -> void:
	flush_count += 1
