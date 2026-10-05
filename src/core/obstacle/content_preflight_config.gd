## Data-driven inputs of the offline `ContentPreflight` (ADR-0008 Decision 5): the geometry and the Obstacle knobs.
## Defaults equal the shipped values (R 3.0, D 0.8, L 12) and the GDD Tuning Knobs.
class_name ContentPreflightConfig
extends Resource

@export var tube_radius: float = 3.0
@export var ball_diameter: float = 0.8
@export var segment_length: float = 12.0
@export var gap_margin: float = 2.5
@export var max_pieces_per_segment: int = 12
@export var grace_zone_length: float = 11.0
## `S_MIN_SPACING` in world units (`t_react * v_max`).
@export var min_spacing: float = 6.25
## `VISIBLE_ARC_HALF_WIDTH` (Camera shipped default is about 1.0472).
@export var visible_arc_half_width: float = 1.0472
## `HIDDEN_SPAN_MIN_S` in world units.
@export var hidden_span_min_s: float = 36.0
## `ANGULAR_REVERSAL_THRESHOLD` of Pattern & Difficulty (opposing-read test of `DODGE_RECOVERY_VIOLATION`).
@export var angular_reversal_threshold: float = PI / 2.0
## `T_DODGE_180 * V_MAX` in world units (26.6 at the shipped 1.064 s and 25 u/s).
@export var dodge_recovery_s: float = 26.6
## Near-miss margins for `NEAR_ZONE_OVERLAP` (F3-NM).
@export var near_miss: NearMissConfig = NearMissConfig.new()
