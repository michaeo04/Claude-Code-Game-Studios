## Steer tables of the Ball Movement tests, in one constants file (GDD AC preamble).
##
## Pseudo-random tables use a fixed LCG (no engine randomness), so every call returns the same values.
## Framework-free: no GUT call.
extends RefCounted

## Fixed LCG constants (Numerical Recipes) and its default seed.
const LCG_MULTIPLIER: int = 1664525
const LCG_INCREMENT: int = 1013904223
const LCG_MODULUS: int = 4294967296
const LCG_DEFAULT_SEED: int = 12345

## A short ramp of steer values covering both full locks and the neutral.
const RAMP: PackedFloat64Array = [-1.0, -0.5, 0.0, 0.5, 1.0]


## `count` pseudo-random steer values in `[-1, 1]` from the fixed LCG; identical on every call for a given seed.
static func lcg_steer(count: int, seed_value: int = LCG_DEFAULT_SEED) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var state: int = seed_value
	for _i: int in count:
		state = (state * LCG_MULTIPLIER + LCG_INCREMENT) % LCG_MODULUS
		out.append(2.0 * float(state) / float(LCG_MODULUS) - 1.0)
	return out
