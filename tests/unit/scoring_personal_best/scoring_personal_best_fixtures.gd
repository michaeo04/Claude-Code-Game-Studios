## Fixtures for the Scoring tests: stubs for the three seams, core factory, signal log. No GUT call here.
extends RefCounted

const PERSONAL_BEST_FIXTURE_DEFAULT: int = 500

## A Callable does not keep a RefCounted alive, so stubs handed to a core are retained here.
static var _retained: Array[RefCounted] = []


## Scripted `s` source: holds the last value once exhausted; an empty sequence reads 0.0.
class SStub:
	extends RefCounted
	var sequence: Array[float] = []
	var index: int = 0
	var calls: int = 0

	func read() -> float:
		calls += 1
		if sequence.is_empty():
			return 0.0
		var v: float = sequence[mini(index, sequence.size() - 1)]
		index += 1
		return v


## Save stand-in with call-count and argument spies.
class SaveStub:
	extends RefCounted
	var stored: Variant = 0
	var write_succeeds: bool = true
	var get_calls: int = 0
	var set_calls: int = 0
	var last_get_args: Array = []
	var last_set_args: Array = []

	func get_value(section: String, key: String, default: Variant) -> Variant:
		get_calls += 1
		last_get_args = [section, key, default]
		return stored

	func set_value(section: String, key: String, value: Variant) -> bool:
		set_calls += 1
		last_set_args = [section, key, value]
		return write_succeeds


## Records `(name, payload)` of every signal in emission order (stories 005 to 007 add the signals).
class SignalLog:
	extends RefCounted
	var entries: Array = []


static func make_s_stub(sequence: Array[float]) -> SStub:
	var stub: SStub = SStub.new()
	stub.sequence = sequence.duplicate()
	_retained.append(stub)
	return stub


static func make_save_stub(initial_best: Variant, write_succeeds: bool = true) -> SaveStub:
	var stub: SaveStub = SaveStub.new()
	stub.stored = initial_best
	stub.write_succeeds = write_succeeds
	_retained.append(stub)
	return stub


static func make_core(s_stub: SStub, save_stub: SaveStub, milestones: Array[int] = []) -> ScoreCore:
	return ScoreCore.new(s_stub.read, save_stub.get_value, save_stub.set_value, milestones)


static func make_score_fixture() -> Dictionary:
	var s_stub: SStub = make_s_stub([])
	var save_stub: SaveStub = make_save_stub(PERSONAL_BEST_FIXTURE_DEFAULT)
	return {"s": s_stub, "save": save_stub, "core": make_core(s_stub, save_stub)}


static func make_signal_log(_core: ScoreCore) -> SignalLog:
	return SignalLog.new()
