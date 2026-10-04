## PlatformCore subclass that records which lifecycle method was called. No GUT call.
extends PlatformCore

## Method names in call order.
var calls: Array[String] = []


func _init() -> void:
	super(false, Callable(), Callable(), Callable(), Callable(), HapticsConfig.new())


func on_focus_out() -> void:
	calls.append("on_focus_out")


func on_focus_in() -> void:
	calls.append("on_focus_in")


func on_paused() -> void:
	calls.append("on_paused")


func on_resumed() -> void:
	calls.append("on_resumed")


func on_back_requested() -> void:
	calls.append("on_back_requested")
