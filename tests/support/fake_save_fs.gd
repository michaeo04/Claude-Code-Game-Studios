## Recording fake of `SaveFs` for Save & Persistence tests. Framework-free (ADR-0009): no GUT call.
## Every call is appended to `calls` as `[method_name, args]` in order; returns come from `returns` (a
## Dictionary of method name to value) or fall back to the `SaveFs` failure defaults.
extends SaveFs

## Ordered call log: `[method: String, args: Array]`.
var calls: Array[Array] = []
## Scripted returns by method name.
var returns: Dictionary = {}


func read_config(path: String) -> Dictionary:
	calls.append(["read_config", [path]])
	return returns.get("read_config", super.read_config(path))


func write_config(path: String, sections: Dictionary) -> bool:
	calls.append(["write_config", [path, sections]])
	return returns.get("write_config", true)


func exists(path: String) -> bool:
	calls.append(["exists", [path]])
	return returns.get("exists", false)


func size(path: String) -> int:
	calls.append(["size", [path]])
	return returns.get("size", -1)


func rename(from: String, to: String) -> bool:
	calls.append(["rename", [from, to]])
	return returns.get("rename", true)


func delete(path: String) -> bool:
	calls.append(["delete", [path]])
	return returns.get("delete", true)


func list_backups(dir: String, prefix: String) -> PackedStringArray:
	calls.append(["list_backups", [dir, prefix]])
	return returns.get("list_backups", PackedStringArray())


## Method names in call order.
func call_names() -> Array[String]:
	var out: Array[String] = []
	for entry: Array in calls:
		out.append(entry[0] as String)
	return out
