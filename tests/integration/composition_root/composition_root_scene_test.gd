## Story CR-001 AC-1: the GameRoot scene file sets the process mode (a guard against future pausing).
## The scene is the project's composition root (ADR-0002 Decision 1); the code default in `_init` is only a fallback.
extends GutTest

const GAME_ROOT_SCENE: String = "res://src/core/game_root.tscn"


func test_scene_root_is_a_game_root_node_with_process_mode_always() -> void:
	var packed: PackedScene = load(GAME_ROOT_SCENE)
	assert_not_null(packed, "game_root.tscn must load")
	var root: Node = packed.instantiate()
	autofree(root)
	assert_true(root is GameRoot, "the scene root is a GameRoot")
	assert_eq(root.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_scene_file_itself_declares_the_process_mode() -> void:
	# Read the scene text so the guard holds even if `_init` stops setting the mode in code.
	var text: String = FileAccess.get_file_as_string(GAME_ROOT_SCENE)
	assert_true(text.contains("process_mode = 3"), "the .tscn sets PROCESS_MODE_ALWAYS (3) on the root node")
