## Spy for `TubeWindow`: counts binder calls and records signals in arrival order, with the window state seen by
## each handler.
##
## Framework-free: no GUT call. Use `spy.attach(window)` after building the window with `spy.binder` as its
## `slot_binder`.
extends RefCounted

## Binder calls as `[slot_index, segment_index]`.
var binds: Array[Array] = []
## Signals in order: `["primed", first, last, seen_state, seen_first, seen_last]` or
## `["state", new, old, seen_state, seen_first, seen_last]`.
var events: Array[Array] = []

var _window: TubeWindow = null


## The injected `slot_binder` callable target.
func binder(slot_index: int, segment_index: int) -> void:
	binds.append([slot_index, segment_index])


## Connects to the window signals (bound methods, no lambda).
func attach(window: TubeWindow) -> void:
	_window = window
	window.window_primed.connect(_on_primed)
	window.state_changed.connect(_on_state)


## Forgets everything recorded so far.
func clear() -> void:
	binds.clear()
	events.clear()


func _on_primed(first_index: int, last_index: int) -> void:
	events.append(["primed", first_index, last_index, _window.get_state(), _window.get_first_index(), _window.get_last_index()])


func _on_state(new_state: int, old_state: int) -> void:
	events.append(["state", new_state, old_state, _window.get_state(), _window.get_first_index(), _window.get_last_index()])
