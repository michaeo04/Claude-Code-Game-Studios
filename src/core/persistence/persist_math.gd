## Pure helpers for Save & Persistence: schema compatibility (F1), read validity and error precedence (F2)
## and the serializable-type check.
##
## Static and stateless; no engine call (no file, config or clock access). Untrusted values arrive as
## `Variant`, so every comparison is guarded by a `typeof` check first.
class_name PersistMath
extends RefCounted

## Stable log codes of Save & Persistence. A log line always carries its code.
const FILE_UNREADABLE: String = "FILE_UNREADABLE"
const SCHEMA_INCOMPATIBLE: String = "SCHEMA_INCOMPATIBLE"
const TYPE_MISMATCH: String = "TYPE_MISMATCH"
const UNSERIALIZABLE_VALUE: String = "UNSERIALIZABLE_VALUE"
const WRITE_FAILED: String = "WRITE_FAILED"
const FILE_MISSING: String = "FILE_MISSING"


## F1: true when `version` is an `int` in `[1, current_schema_version]`.
## A `String`, `bool`, `Array` or any other non-int Variant is incompatible and is never compared.
static func schema_compatible(version: Variant, current_schema_version: int) -> bool:
	if typeof(version) != TYPE_INT:
		return false
	var v: int = version
	return v >= 1 and v <= current_schema_version


## F2: a key is read as valid only when the file parsed, the schema is compatible, the key exists and its type matches.
static func read_valid(parsed_ok: bool, compatible: bool, has_key: bool, type_matches: bool) -> bool:
	return parsed_ok and compatible and has_key and type_matches


## F2: the log code of a failed read, by precedence: unreadable file, incompatible schema, (absent key: no code),
## type mismatch. Returns an empty string when there is nothing to log.
static func read_error_code(parsed_ok: bool, compatible: bool, has_key: bool, type_matches: bool) -> String:
	if not parsed_ok:
		return FILE_UNREADABLE
	if not compatible:
		return SCHEMA_INCOMPATIBLE
	if not has_key:
		return ""
	if not type_matches:
		return TYPE_MISMATCH
	return ""


## True when `value` can be written to a `ConfigFile` (ADR-0007 Decision 4). False for any `Object`
## (including `RefCounted`), `Callable`, `Signal`, `RID`, and for a NaN or infinite `float`.
## Container contents are not inspected.
static func is_serializable_type(value: Variant) -> bool:
	match typeof(value):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return false
		TYPE_FLOAT:
			var f: float = value
			return is_finite(f)
		_:
			return true


## SP-2 pre-parse sniff (ADR-0007; GDD Open Question 1). `ConfigFile`'s parser instantiates objects and runs
## attached scripts while parsing `Object(...)` and loads `Resource(...)`, `ExtResource(...)` and
## `SubResource(...)` values (confirmed on Godot 4.7.2). A save file holds only plain values, so a file that
## names one of these constructors is rejected before it reaches the parser. Deliberately conservative: the
## token is matched even inside a quoted string, because failing safe to defaults is the cheaper error.
## Example: `PersistMath.has_object_constructor("x=Object(Node)")` is `true`; `"x=Vector2(1, 2)"` is `false`.
static func has_object_constructor(text: String) -> bool:
	for token: String in ["Object", "Resource"]:
		var from: int = 0
		while true:
			var at: int = text.find(token, from)
			if at < 0:
				break
			var next: int = at + token.length()
			while next < text.length() and (text[next] == " " or text[next] == "\t"):
				next += 1
			if next < text.length() and text[next] == "(":
				return true
			from = at + token.length()
	return false
