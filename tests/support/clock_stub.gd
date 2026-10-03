## A controllable microsecond clock for tests (ADR-0002 Decision 4: every system takes an injected `clock_us: Callable`).
##
## Framework-free by design (ADR-0009 Decision 1): no GUT base class and no GUT call, so a switch of
## test framework never touches this file. Test files load it with
## `const ClockStub = preload("res://tests/support/clock_stub.gd")`.
##
## Usage:
##   var clock := ClockStub.new(1_000_000)
##   var system := SomeCore.new(clock.as_callable())
##   clock.advance_s(0.016)
extends RefCounted

var now_us: int


func _init(start_us: int = 0) -> void:
	now_us = start_us


## The injected callable: returns the current stub time in microseconds.
func as_callable() -> Callable:
	return get_now_us


func get_now_us() -> int:
	return now_us


## Move the clock forward by a number of microseconds.
func advance_us(delta_us: int) -> void:
	now_us += delta_us


## Move the clock forward by seconds, rounded to the nearest microsecond.
func advance_s(delta_s: float) -> void:
	now_us += roundi(delta_s * 1_000_000.0)
