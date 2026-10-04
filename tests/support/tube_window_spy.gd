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
## Segment signals in order: `["left", index]` or `["entered", index]`.
var segs: Array[Array] = []
## Per-signal re-entrancy probe: signal name ("primed", "state", "entered", "left") -> action name
## ("advance", "begin_run", "pause"); the action is attempted once from the handler.
var probe: Dictionary = {}

var _window: TubeWindow = null


## The injected `slot_binder` callable target.
func binder(slot_index: int, segment_index: int) -> void:
	binds.append([slot_index, segment_index])


## Connects to the window signals (bound methods, no lambda).
func attach(window: TubeWindow) -> void:
	_window = window
	window.window_primed.connect(_on_primed)
	window.state_changed.connect(_on_state)
	window.segment_entered_window.connect(_on_entered)
	window.segment_left_window.connect(_on_left)


## Forgets everything recorded so far.
func clear() -> void:
	binds.clear()
	events.clear()
	segs.clear()


func _on_primed(first_index: int, last_index: int) -> void:
	events.append(["primed", first_index, last_index, _window.get_state(), _window.get_first_index(), _window.get_last_index()])
	_run_probe("primed")


func _on_state(new_state: int, old_state: int) -> void:
	events.append(["state", new_state, old_state, _window.get_state(), _window.get_first_index(), _window.get_last_index()])
	_run_probe("state")


func _on_entered(index: int) -> void:
	segs.append(["entered", index])
	_run_probe("entered")


func _on_left(index: int) -> void:
	segs.append(["left", index])
	_run_probe("left")


func _run_probe(signal_name: String) -> void:
	if not probe.has(signal_name):
		return
	var action: String = probe[signal_name]
	probe.erase(signal_name)
	match action:
		"advance":
			_window.advance(1000.0)
		"begin_run":
			_window.begin_run()
		"pause":
			_window.pause()
