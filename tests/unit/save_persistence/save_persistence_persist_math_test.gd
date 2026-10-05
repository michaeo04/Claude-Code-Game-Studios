## Story SP-001: PersistMath F1 schema compatibility, F2 read validity and precedence, serializable types.
extends GutTest

const SCHEMA_TEST: int = 3


func _compat(v: Variant) -> bool:
	return PersistMath.schema_compatible(v, SCHEMA_TEST)


func test_schema_zero_incompatible() -> void:
	assert_false(_compat(0))


func test_schema_negative_incompatible() -> void:
	assert_false(_compat(-1))


func test_schema_one_two_three_compatible() -> void:
	assert_true(_compat(1))
	assert_true(_compat(2))
	assert_true(_compat(3))


func test_schema_four_incompatible() -> void:
	assert_false(_compat(4))


func test_schema_non_int_types_incompatible_without_error() -> void:
	assert_false(_compat("1"))
	assert_false(_compat(true))
	assert_false(_compat([1]))
	assert_false(_compat(1.0))
	assert_false(_compat(null))


func test_read_valid_all_true() -> void:
	assert_eq(PersistMath.read_valid(true, true, true, true), true)


func test_read_valid_each_single_factor_false() -> void:
	assert_eq(PersistMath.read_valid(false, true, true, true), false)
	assert_eq(PersistMath.read_valid(true, false, true, true), false)
	assert_eq(PersistMath.read_valid(true, true, false, true), false)
	assert_eq(PersistMath.read_valid(true, true, true, false), false)


func test_read_valid_all_false() -> void:
	assert_eq(PersistMath.read_valid(false, false, false, false), false)


func test_error_code_unreadable_file() -> void:
	assert_eq(PersistMath.read_error_code(false, true, true, true), PersistMath.FILE_UNREADABLE)


func test_error_code_schema_incompatible() -> void:
	assert_eq(PersistMath.read_error_code(true, false, true, true), PersistMath.SCHEMA_INCOMPATIBLE)


func test_error_code_absent_key_has_no_code() -> void:
	assert_eq(PersistMath.read_error_code(true, true, false, true), "")


func test_error_code_type_mismatch() -> void:
	assert_eq(PersistMath.read_error_code(true, true, true, false), PersistMath.TYPE_MISMATCH)


func test_error_code_unreadable_beats_schema() -> void:
	assert_eq(PersistMath.read_error_code(false, false, true, true), PersistMath.FILE_UNREADABLE)


func test_error_code_all_valid_has_no_code() -> void:
	assert_eq(PersistMath.read_error_code(true, true, true, true), "")


func test_log_code_names_are_exact() -> void:
	assert_eq(PersistMath.FILE_UNREADABLE, "FILE_UNREADABLE")
	assert_eq(PersistMath.SCHEMA_INCOMPATIBLE, "SCHEMA_INCOMPATIBLE")
	assert_eq(PersistMath.TYPE_MISMATCH, "TYPE_MISMATCH")
	assert_eq(PersistMath.UNSERIALIZABLE_VALUE, "UNSERIALIZABLE_VALUE")
	assert_eq(PersistMath.WRITE_FAILED, "WRITE_FAILED")
	assert_eq(PersistMath.FILE_MISSING, "FILE_MISSING")


func test_serializable_plain_types_true() -> void:
	assert_true(PersistMath.is_serializable_type(7))
	assert_true(PersistMath.is_serializable_type(1.5))
	assert_true(PersistMath.is_serializable_type("text"))
	assert_true(PersistMath.is_serializable_type(true))
	assert_true(PersistMath.is_serializable_type(Vector2(1.0, 2.0)))
	assert_true(PersistMath.is_serializable_type([1, 2]))
	assert_true(PersistMath.is_serializable_type({"a": 1}))


func test_serializable_object_false() -> void:
	var obj: Object = Object.new()
	assert_false(PersistMath.is_serializable_type(obj))
	obj.free()


func test_serializable_ref_counted_false() -> void:
	assert_false(PersistMath.is_serializable_type(RefCounted.new()))


func test_serializable_non_finite_float_false() -> void:
	assert_false(PersistMath.is_serializable_type(NAN))
	assert_false(PersistMath.is_serializable_type(INF))
	assert_false(PersistMath.is_serializable_type(-INF))


func test_sniff_flags_object_and_resource_constructors() -> void:
	assert_true(PersistMath.has_object_constructor("x=Object(Node)"))
	assert_true(PersistMath.has_object_constructor("x=Object (Node)"))
	assert_true(PersistMath.has_object_constructor("x=Resource(\"res://a.gd\")"))
	assert_true(PersistMath.has_object_constructor("x=ExtResource(\"1\")"))
	assert_true(PersistMath.has_object_constructor("x=SubResource(\"1\")"))


func test_sniff_passes_plain_values_and_bare_words() -> void:
	assert_false(PersistMath.has_object_constructor(""))
	assert_false(PersistMath.has_object_constructor("[_meta]\nschema_version=1\nv=Vector2(1, 2)\nc=Color(1, 0, 0, 1)\n"))
	assert_false(PersistMath.has_object_constructor("name=\"Object\"\nother=\"Resource here\"\n"))
