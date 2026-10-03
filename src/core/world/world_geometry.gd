## MINIMAL placeholder of the immutable `WorldGeometry` value (ADR-0004: R, D, N_F, L).
##
## The map-loader epic owns the real class and will replace this file; `a_segments` is the `A` of
## ADR-0013 Decision 4 (segments ahead of the ball that stay visible). Only what CR-003 needs.
class_name WorldGeometry
extends RefCounted

## Tube radius `R` (world units).
var r: float
## Ball distance `D` from the camera plane (world units).
var d: float
## Number of tube slots `N_F`.
var n_f: int
## Segment length `L` (world units).
var l: float
## `A`: segments ahead of the ball that stay visible (ADR-0013).
var a_segments: int


func _init(
	radius: float = 3.0, distance: float = 2.0, slots: int = 20, segment_length: float = 12.0, ahead: int = 9
) -> void:
	r = radius
	d = distance
	n_f = slots
	l = segment_length
	a_segments = ahead
