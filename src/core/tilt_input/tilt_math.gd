## Pure Tilt Input math (design/gdd/tilt-input.md F1, F3, F4 and the neutral-window median of F2).
##
## Static and engine-free. No validation: config clamping lives in `TiltConfig`. Angles are in degrees.
class_name TiltMath
extends RefCounted

## Largest supported posture angle in degrees (above it a posture is unsupported).
const PHI_MAX: float = 70.0
## Cap of the effective full-scale angle in degrees (lowest sensitivity).
const FS_EFF_MAX: float = 50.0
## Smallest filter time constant used by `alpha`, in seconds.
const TAU_FLOOR: float = 0.005


## Clamps a ratio to `[-1, 1]` so that `asin` never sees a value rounded just outside its domain.
## Example: `clamp_ratio(1.0000001)` is `1.0`.
static func clamp_ratio(r: float) -> float:
	return clampf(r, -1.0, 1.0)


## F1 roll angle in degrees from a gravity vector: `sensor_sign * deg(asin(clamp(g.x / |g|)))`.
## Uses only `g.x` and the magnitude, so pitch does not change it. A zero vector gives 0.
## Example: `roll_deg(Vector3(6, -8, 0), 1)` is about `36.870`.
static func roll_deg(g: Vector3, sensor_sign: int) -> float:
	var mag: float = g.length()
	if mag <= 0.0:
		return 0.0
	return float(sensor_sign) * rad_to_deg(asin(clamp_ratio(g.x / mag)))


## F3 smoothing factor `1 - exp(-dt / max(tau, TAU_FLOOR))`. A `dt` of 0 gives 0.
## Example: `alpha(1.0 / 60.0, 0.05)` is about `0.283469`.
static func alpha(dt: float, tau: float) -> float:
	return 1.0 - exp(-dt / maxf(tau, TAU_FLOOR))


## F3 one filter step: `phi_f + alpha * (phi_r - phi_f)`.
static func filter_step(phi_f: float, phi_r: float, dt: float, tau: float) -> float:
	return phi_f + alpha(dt, tau) * (phi_r - phi_f)


## F4 steer from the filtered angle: `FS_eff = min(fs / sensitivity, FS_EFF_MAX)`, `dz_eff = min(dz, 0.2 * FS_eff)`,
## `u = clamp(sign(phi_f) * max(0, |phi_f| - dz_eff) / (FS_eff - dz_eff), -1, 1)`, result `sign(u) * |u|^k`.
## Example: `steer(14.0, 25.0, 1.5, 1.0, 1.0)` is about `0.531915`.
static func steer(phi_f: float, fs: float, dz: float, k: float, sensitivity: float) -> float:
	var fs_eff: float = minf(fs / sensitivity, FS_EFF_MAX)
	var dz_eff: float = minf(dz, 0.2 * fs_eff)
	var u: float = signf(phi_f) * maxf(0.0, absf(phi_f) - dz_eff) / (fs_eff - dz_eff)
	u = clampf(u, -1.0, 1.0)
	return signf(u) * pow(absf(u), k)


## Median of the samples (F2): the middle value, or the mean of the two middle values for an even count.
## An empty array gives NAN; the caller guards the count. The input is not modified.
## Example: `median(PackedFloat64Array([7, 1, 3, 80, 5]))` is `5.0`.
static func median(samples: PackedFloat64Array) -> float:
	var n: int = samples.size()
	if n == 0:
		return NAN
	var sorted: PackedFloat64Array = samples.duplicate()
	sorted.sort()
	if n % 2 == 1:
		return sorted[n / 2]
	return (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
