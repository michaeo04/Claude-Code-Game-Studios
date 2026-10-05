## Factories of the Pattern & Difficulty tests (GDD AC preamble): `make_pattern_fixture`, `make_chunk`,
## `make_content_library`, `make_run_time_stub`, `make_run_id_stub` and the 8-chunk library W1-W4, SP1, DG1, NR1, REV2.
## `make_compiled_library`, `make_core` and `ScriptedShuffler` serve `PatternCore`/`TierBag`. Framework-free: no GUT call.
extends RefCounted

const V_MAX: float = 25.0
const T_DODGE_180: float = 1.064
const T_REACT: float = 0.25
const L: float = 12.0
const T_RAMP: float = 90.0
const TIER_INTRO_DURATION: float = 15.0
const TIER_RAMP_DURATION: float = 90.0
const ANGULAR_REVERSAL_THRESHOLD: float = PI / 2.0
const THETA_REF: float = 0.0
const VISIBLE_ARC_HALF_WIDTH_TEST: float = PI / 2.0
const WALL_THETA_MIN: float = 0.4127
const WALL_THETA_MAX: float = 5.8705
const RING_HALF: float = 2.7053

var cfg: PatternConfig = PatternConfig.new()
## `T_DODGE_180 * V_MAX` (26.6 u).
var dodge_recovery_s: float = 0.0
## `T_REACT * V_MAX` (6.25 u).
var s_min_spacing: float = 0.0


## The injected external values plus this GDD's own defaults.
static func make_pattern_fixture() -> RefCounted:
	var fx: RefCounted = (load("res://tests/support/pattern_fixture.gd") as GDScript).new() as RefCounted
	var c: PatternConfig = PatternConfig.new()
	c.tier_intro_duration = TIER_INTRO_DURATION
	c.tier_ramp_duration = TIER_RAMP_DURATION
	c.angular_reversal_threshold = ANGULAR_REVERSAL_THRESHOLD
	fx.set("cfg", c)
	fx.set("dodge_recovery_s", T_DODGE_180 * V_MAX)
	fx.set("s_min_spacing", T_REACT * V_MAX)
	return fx


static func make_piece(theta_min: float, theta_max: float, s_start: float, s_end: float) -> HazardPiece:
	var p: HazardPiece = HazardPiece.new()
	p.theta_min = theta_min
	p.theta_max = theta_max
	p.s_start = s_start
	p.s_end = s_end
	return p


static func make_placement(
	hazard_type: HazardPlacement.HazardType,
	local_segment_index: int,
	pieces: Array[HazardPiece],
	solution_angles: PackedFloat64Array
) -> HazardPlacement:
	var h: HazardPlacement = HazardPlacement.new()
	h.hazard_type = hazard_type
	h.local_segment_index = local_segment_index
	h.pieces = pieces
	h.solution_angles = solution_angles
	return h


## A Wall at `theta_solution` 0 in `segment` spanning chunk-local `s_start` to `s_end`.
static func make_wall(segment: int, s_start: float, s_end: float) -> HazardPlacement:
	var pieces: Array[HazardPiece] = [make_piece(WALL_THETA_MIN, WALL_THETA_MAX, s_start, s_end)]
	return make_placement(HazardPlacement.HazardType.WALL, segment, pieces, PackedFloat64Array([0.0]))


## `chunk_id` is stored as the decimal string name (the GDD tables use 1 to 8).
static func make_chunk(
	chunk_id: int, tier: ChunkDef.Tier, segment_count: int, placements: Array[HazardPlacement]
) -> ChunkDef:
	var c: ChunkDef = ChunkDef.new()
	c.chunk_id = StringName(str(chunk_id))
	c.tier = tier
	c.segment_count = segment_count
	c.placements = placements
	return c


static func make_content_library(chunks: Array[ChunkDef]) -> ChunkLibrary:
	var lib: ChunkLibrary = ChunkLibrary.new()
	lib.chunks = chunks
	return lib


## The GDD 8-chunk fixture: INTRO {W1..W4}, RAMP adds SP1 and DG1, FULL adds NR1 and REV2.
static func make_chunks() -> Array[ChunkDef]:
	var i: ChunkDef.Tier = ChunkDef.Tier.INTRO
	var r: ChunkDef.Tier = ChunkDef.Tier.RAMP
	var f: ChunkDef.Tier = ChunkDef.Tier.FULL
	var sp_pieces: Array[HazardPiece] = [
		make_piece(-0.05, 0.05, 0.0, 0.3), make_piece(0.30, 0.40, 0.05, 0.35), make_piece(0.65, 0.75, 0.0, 0.3)
	]
	var dg_pieces: Array[HazardPiece] = [make_piece(-1.2, -0.4, 14.0, 15.2), make_piece(0.4, 1.2, 14.0, 15.2)]
	var nr_pieces: Array[HazardPiece] = [make_piece(-RING_HALF, RING_HALF, 14.0, 15.2)]
	var nr2_pieces: Array[HazardPiece] = [make_piece(-RING_HALF, RING_HALF, 27.1, 28.3)]
	var out: Array[ChunkDef] = []
	out.append(make_chunk(1, i, 1, [make_wall(0, 2.0, 3.0)]))
	out.append(make_chunk(2, i, 1, [make_wall(0, 5.0, 6.0)]))
	out.append(make_chunk(3, i, 2, [make_wall(1, 14.0, 15.0)]))
	out.append(make_chunk(4, i, 1, [make_wall(0, 11.0, 11.9)]))
	out.append(
		make_chunk(5, r, 1, [make_placement(HazardPlacement.HazardType.SPIKE, 0, sp_pieces, PackedFloat64Array())])
	)
	out.append(
		make_chunk(
			6, r, 2, [make_placement(HazardPlacement.HazardType.DOUBLE_GATE, 1, dg_pieces, PackedFloat64Array([-0.8, 0.8]))]
		)
	)
	out.append(
		make_chunk(
			7, f, 2, [make_placement(HazardPlacement.HazardType.NEAR_RING, 1, nr_pieces, PackedFloat64Array([PI]))]
		)
	)
	out.append(
		make_chunk(
			8,
			f,
			3,
			[
				make_wall(0, 0.5, 1.5),
				make_placement(HazardPlacement.HazardType.NEAR_RING, 2, nr2_pieces, PackedFloat64Array([PI]))
			]
		)
	)
	return out


## Scripted `run_time` source: `value` read through `get_value()`.
class ValueStub:
	extends RefCounted
	var value: float = 0.0

	func get_value() -> float:
		return value


static func make_run_time_stub(value: float) -> ValueStub:
	var s: ValueStub = ValueStub.new()
	s.value = value
	return s


## Scripted `run_id` source: `value` read through `get_value()`.
class IdStub:
	extends RefCounted
	var value: int = 0

	func get_value() -> int:
		return value


static func make_run_id_stub(value: int) -> IdStub:
	var s: IdStub = IdStub.new()
	s.value = value
	return s


## The compiled 8-chunk fixture library (all structural checks pass).
static func make_compiled_library() -> CompiledLibrary:
	return ChunkLibraryCompiler.compile(make_content_library(make_chunks()), PatternConfig.new(), L, Callable())


## Permutation source that moves the chunks named in `order` (chunk ids) to the front, in that order, and keeps the
## rest in their incoming order. Hand its `shuffle` Callable to `PatternCore`/`TierBag` to script a bag.
class ScriptedShuffler:
	extends RefCounted
	var order: Array[int] = []

	func shuffle(items: Array) -> void:
		var front: Array = []
		for id: int in order:
			for item: Variant in items:
				if (item as CompiledChunk).chunk_id == StringName(str(id)):
					front.append(item)
		var rest: Array = []
		for item: Variant in items:
			if not front.has(item):
				rest.append(item)
		items.assign(front + rest)


static func make_scripted_shuffler(order: Array[int]) -> ScriptedShuffler:
	var s: ScriptedShuffler = ScriptedShuffler.new()
	s.order = order
	return s


## A `PatternCore` over the compiled fixture library, reset with `run_id`; `run_time` is read from `run_time_stub`.
## A non-empty `shuffle_order` scripts every bag (those chunk ids first). The stub and shuffler are kept alive on the
## core (a `Callable` does not hold a RefCounted target).
static func make_core(
	run_time_stub: ValueStub, run_id: int, shuffle_order: Array[int] = [], grace_zone_length: float = 11.0
) -> PatternCore:
	var shuffler: ScriptedShuffler = null
	var shuffle_callable: Callable = Callable()
	if not shuffle_order.is_empty():
		shuffler = make_scripted_shuffler(shuffle_order)
		shuffle_callable = Callable(shuffler, "shuffle")
	var core: PatternCore = PatternCore.new(
		PatternConfig.new(), L, Callable(run_time_stub, "get_value"), Callable(), grace_zone_length, shuffle_callable
	)
	core.set_meta(&"run_time_stub", run_time_stub)
	core.set_meta(&"shuffler", shuffler)
	core.set_library(make_compiled_library())
	core.on_run_reset(run_id)
	return core
