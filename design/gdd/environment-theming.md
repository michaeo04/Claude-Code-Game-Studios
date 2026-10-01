# Environment & Theming

> **Status**: Designed (2026-09-29), pending independent `/design-review`. Revised 2026-10-01 after `/review-all-gdds` (C1, S4): Tube Track now carries F = 84, and Environment applies `L_ball_adjusted` to the ball material live.
> **Author**: user + agents
> **Last Updated**: 2026-10-01
> **Implements Pillar**: Pillar 1 (Instant Readability) — primary, the fog/contrast derivation is what makes a hazard readable at all before it needs to be reacted to; Pillar 2 (Fair but Merciless Difficulty) — secondary, the hidden-side readable window this system's fog rules protect.

## Overview

Environment & Theming owns everything the player sees that isn't the ball or a hazard: the tube's material and hue, the sky, the fog that defines how far ahead is readable, and the background props — all supplied per map through `MapConfig` fields Tube Track already reads (`fog_mode`, `fog_depth_begin`, `fog_end_distance`, `fog_depth_curve`, `fog_density`, `fog_color`, `readable_distance`) but doesn't own the values of. Its single most consequential number is `F_read`: the radial distance from the camera eye at which a hazard is still readable through fog at `v_max` — Tube Track's own visibility budget (F9) currently guesses this at 46 u, giving a margin of only 0.02 s over the fairness floor `T_VIS_MIN`, and this system is the one that must actually justify that number rather than leave it a guess. It executes the art bible's own already-locked visual identity ("Quiet World, Loud Hazards": a muted, capped-chroma world so hazards stay the only saturated, full-contrast thing on screen) rather than inventing a new one — Sections 1-4 of the art bible already fix Map 1's full palette, the shape language, and the color guardrails; this GDD is where those become real `MapConfig` values and a real fog/readability derivation, not a fresh design decision. It decides nothing about hazard geometry (Obstacle System) or any near-miss/hit juice (Juice & Feedback), and it doesn't own the ball's base appearance (Ball Movement / the art bible's own ball rules) — it owns exactly the environment: the tube's look, the fog, and how far the player can actually see. **One narrow exception**: when `colorblind_safe_enabled` is on, this system computes a single adjusted luminance value (Formula F3) and applies it to the ball's material itself, immediately, because Environment & Theming owns colours and materials in the MVP and no ball skin system exists yet, a targeted contrast fix derived from data this system already reads for fog contrast (Rule 3), not a new claim over the ball's design (the ball's shape, behavior and chroma/hue stay untouched, and Ball Movement is not a consumer).

## Player Fantasy

**The fantasy.** The world around me is calm and quiet so I can trust it — and the one time something in it turns loud and warm, I already know exactly what that means.

**What the player feels.**
- **Danger is the only loud thing.** Everything else — the tube, the sky, the pickups — stays a step quieter, so the moment something demands full attention, I already know it's the thing that can kill me (art bible §1: "Danger is the loudest thing on screen").
- **I can always see far enough to react.** The fog never quietly eats my reaction time — whatever's coming is readable at `v_max` with room to spare, not by luck but because this system is built around that promise (Tube Track's own `T_VIS_MIN` fairness floor).
- **The world tells me how fast I'm going without saying a word.** Streaming seams, a fog that pulls a little nearer, a chroma that quietly drops at speed — the environment carries the thrill without competing with the thing I actually need to read (art bible mood state 3; game-concept.md's Sensation aesthetic, "sense of speed").
- **Every map feels like arriving somewhere new.** A new hue, a new sky, a new mood — while the rules that keep me alive never change underneath it (game-concept.md's Discovery aesthetic; art bible §1 "Never varies").

**Feelings to avoid.** A fog that quietly shrinks my reaction window as speed ramps; an environment loud enough to compete with a hazard for attention, even for a frame; a per-map palette that changes the rules of what's safe along with the scenery; a mood that reads as cozy or safe when tension is actually what the moment calls for (art bible §2: "tension comes from hazard density, speed and world desaturation, never from darkening the world").

**Serves the pillars.** *Pillar 1, Instant Readability* — primary: this system's entire fog/contrast job is making sure a hazard is readable before it needs to be reacted to. *Pillar 2, Fair but Merciless Difficulty* — secondary: the hidden-side readable window this system's fog and clear-contour-band rules protect is half of what makes a "fair surprise" fair at all.

## Detailed Design

### Core Rules

1. **Data model: the `MapConfig` fields this system owns.** `seam_pattern_id`, `fog_mode`, `fog_depth_begin`, `fog_end_distance` (`F`), `fog_depth_curve`, `fog_density`, `fog_color`, `readable_distance` (`F_read`) — all already read by Tube Track's own Dependencies table — plus `tube_color`, `sky_top_color`, `sky_bottom_color`, `prop_set_id`, all per-map values validated at map load.
2. **A clean boundary with Obstacle System: environment colors here, hazard colors there, both drawn from one shared art-bible palette.** This GDD owns the tube, sky, and prop palette; Obstacle System's own already-Approved Visual/Audio Requirements owns hazard silhouette and hazard color within the art bible's reserved warm family (Section 4). Neither GDD redefines the other's colors — this GDD reads Obstacle System's own fixed hazard color (Section 4's Signal Red/Ember) as a read-only reference for Rule 3's own contrast derivation, never as something it can change.
3. **`F_read` is derived from the fog opacity curve crossing the art bible's own binding contrast floor — never an independent guess.** As fog blends both the tube and a hazard toward `fog_color` with increasing distance, the effective displayed contrast between hazard and tube degrades; `F_read` is the distance at which that contrast first falls below the art bible's own 4:1 floor (Section 4, "hazard / tube contrast at least 4:1 (binding; see colorblind notes)"). The exact derivation, combining Godot's own verified fog-opacity formula with the art bible's fixed luminance values, is Formula F1 — this rule only commits to the derivation existing and being contrast-driven, resolving Tube Track's own "external contract, guess" placeholder for real.
4. **`fog_end_distance` (`F`) is a stricter, later bound than `F_read` — full opacity, not unreadability.** With `fog_density` = 1.0 (required: the default exponential fog mode never reaches full opacity at any finite distance, a verified Godot 4.7.2 fact), `F` is the distance at which fog reaches 100% opacity — where the tube's own far end disappears entirely. `F` is always farther than `F_read`: a hazard becomes unreadable before the world itself vanishes, never the other way around.
5. **Speed-driven fog and chroma shift, formalizing the art bible's own Mood State 3.** As Ball Movement's `speed` rises toward `v_max`, fog pulls nearer (a bounded function of `speed`, Formula F2) and world chroma multiplies by a fixed factor (0.88, the art bible's own already-decided value, Section 4) — hazards, the ball, and pickups are exempt from the chroma shift (the art bible's own explicit exemption). This resolves Tube Track's Open Question 10 (user decision: the environment carries speed readability; Rule 7 below).
6. **The Menu-state preview hazard stays fixed on screen while the tube's own idle scroll advances underneath it (user decision).** Mood State 1's "one lone hazard... previewing the rule" does not scroll with the tube's `s_idle` mechanism (Tube Track's own idle-tick formula) — it holds its screen position, reading as a held pose rather than motion, matching Mood State 1's own "still, airy" descriptors. Resolves Tube Track's Open Question 16.
7. **The ball needs no additional speed cue of its own (user decision).** The environment's own speed cues (Rule 5: fog pull, chroma shift, seam flow) are sufficient — resolves Ball Movement's Open Question 3. The ball's own silhouette and behavior stay exactly consistent regardless of speed, serving Pillar 2's "never a source of surprise" (a ball that visibly changed at speed would itself become something to read, competing with hazards for attention against art bible §1's own loudness budget).
8. **Per-map palette variation is bounded by the art bible's own guardrails, never invented fresh by this GDD.** A new map's palette follows the art bible's own "Deriving a new map's palette" procedure (Section 4) verbatim — hue selection outside the reserved warm/ball-adjacent ranges, the fixed contrast floors, a grayscale render check, a color-vision-deficiency simulation — this GDD supplies the `MapConfig` mechanism for storing and validating a per-map palette against those already-fixed guardrails, not a new set of rules.
9. **`colorblind_safe_enabled` boosts the one known risk spot, not a full alternate palette (user decision).** The art bible's own Colorblind Safety section already claims the base palette is safe by construction (a 4:1 luminance floor, never hue alone) — with one named exception: ball-vs-hazard luminance contrast is only 1.03:1 today, separated only by hue and shape. When `colorblind_safe_enabled` (Settings & Accessibility) is true, this system widens that specific gap (Formula F3) beyond its base value; every other contrast relationship is already above its own floor and is left unchanged. **This system applies `L_ball_adjusted` to the ball's material itself** (it owns colours and materials in the MVP; no ball skin system exists yet, and Ball Movement has no consumer for it), and it takes effect **immediately** whenever `colorblind_safe_enabled` changes (on `setting_changed`, in Menu, Paused or Running, with no wait for `run_reset`), so the Menu preview behind Settings shows the result at once (review item S4). Resolves Settings & Accessibility's own Open Question 1.
10. **The Double Gate hazard's "shared plinth" gets a real material and height.** Resolves Obstacle System's own Open Question 12 — the plinth is an environment-owned prop (Rule 2's boundary: it sits at the hazard's base but is not part of the hazard's own silhouette or color).
11. **`F_read` is re-derived and re-checked per map at load time — never a one-time calculation that could go stale on a future map's palette.** Formula F1 is parametric in whatever `MapConfig` and hazard-color data a given map actually uses, not hardcoded to Map 1's numbers; at load, this system computes that map's own `F_read` and rejects the map if it fails Tube Track's own visibility floor (`F_read >= T_VIS_MIN * v_max + d_cam`) with a new code, `MAP_VISIBILITY_UNSAFE`, naming the map and the shortfall — the same "derive, don't guess, and gate it" pattern Camera's own `CAMERA_RADIUS_TOO_CLOSE` guard uses.
12. **No side effects; deterministic given the same `MapConfig` and `speed` input.** Environment & Theming sends no requests to Tube Track, Ball Movement, Obstacle System, or Settings & Accessibility — it only reads their published state and config values. (Writing `L_ball_adjusted` to the ball's material, Rule 9, is a material write and not a request to Ball Movement.) Given the same `MapConfig` and the same `speed` sequence, its own derived values (fog distance, chroma multiplier) are always the same.
13. **Structure.** `EnvMath` is a stateless static class holding F1's `factor`/luminance-blend/`contrast`/`F_read`-search, F2's speed-driven `fog_end_distance`, and F3's `L_ball_adjusted`. `EnvCore` is a `RefCounted` with no engine calls, holding the loaded `MapConfig` reference and the last-applied `L_ball_adjusted`, driven by injected read-only test doubles for Ball Movement (`speed`) and Settings & Accessibility (`colorblind_safe_enabled`), plus an injected `log_sink` — mirroring `BallCore`'s and `CameraCore`'s own seam pattern. `EnvConfig` is a `Resource` holding every `MapConfig` field (Rule 1) plus every Tuning Knob, with a `validated(log_sink)` method enforcing Rule 11's `MAP_VISIBILITY_UNSAFE` gate and the `FOG_RANGE_INVALID` check (Edge Cases).

### States and Transitions

Environment & Theming has no phase of its own; its behavior is a function of `MapConfig` (fixed per map) and Ball Movement's `speed` (continuous). It does not own the momentary hit-presentation grey-out (art bible Mood State 5) — that belongs to Juice & Feedback, layered on top of this system's own baseline theme, the same boundary Obstacle System draws for its own hit moment.

| Situation | Event | Environment & Theming does |
|-----------|-------|----------------------------|
| Map load | none | `MapConfig` validated — `F_read`/`F` derivation checked against `T_VIS_MIN` (Rules 3-4); palette loaded |
| Menu (Mood State 1) | none | Idle theme applied; the preview hazard holds its screen position (Rule 6) |
| Running, any speed | every frame | Fog distance and world chroma derived from Ball Movement's `speed` (Rule 5) |
| Any phase (Menu, Running, Paused) | `setting_changed` for `colorblind_safe_enabled` | `L_ball_adjusted` recomputed (F3) and applied to the ball material at once (Rule 9) |
| Hit (Mood State 5) | `run_ended` (Run State, via Juice & Feedback) | This system's own baseline theme is unaffected; the momentary grey-out itself is Juice & Feedback's, not this system's |

### Interactions with Other Systems

| System | Direction | Data / events | Note |
|--------|-----------|----------------|------|
| Tube Track (Approved) | in | `R`, segment/window data to theme | Hard dependency |
| Ball Movement (Approved) | in | `speed`, once per frame | Hard dependency; read-only, feeds Rule 5 |
| Obstacle System (Approved) | in (soft, reference-only) | The art bible's own fixed hazard color (Section 4), read for Rule 3's contrast derivation | Never a runtime call; Obstacle System's own colors are not owned or changed here (Rule 2) |
| Settings & Accessibility (Designed) | in | `colorblind_safe_enabled` (getter, plus `setting_changed` to react live) | Feeds Rule 9; both are required, not optional (review item S4) |
| Tube Track (Approved) | out | `MapConfig`'s fog/color fields (Rule 1), published at map load | Resolves Tube Track's own `F_read`/`F` placeholder guesses and its Open Questions 10 and 16 |
| Obstacle System (Approved) | out | The Double Gate shared-plinth material/height | Resolves Obstacle System's own Open Question 12 |
| Ball material (no system consumes it) | out | `L_ball_adjusted` (Formula F3), applied by this system to the ball's material, only when `colorblind_safe_enabled` is on, live on `setting_changed` | Ball Movement does not consume it; this GDD never touches the ball's chroma/hue/silhouette (Overview's own narrow exception); a future ball skin system would take over the application |
| Maps & Levels (Not Started) | out (provisional) | Per-map `MapConfig` selection mechanism | Not yet authored |
| Juice & Feedback (Not Started) | none (boundary note) | — | Mood State 5's momentary grey-out is Juice & Feedback's own effect, layered on top of this system's baseline theme, never owned here |

## Formulas

All worked examples use Map 1's own values (registry defaults `v_max` = 25, `v_start` = 10, `d_cam` = 7.84) plus the art bible's own fixed color data (Section 4: Signal Red hazard face, L = 0.079; Ember hazard shade, L = 0.03; Mist Sage tube, L = 0.49; Haze Low sky, L = 0.84; Slate Cobalt ball, L = 0.083).

**F1. Fog-degraded contrast and `F_read`**

```
factor(d)   = pow(smoothstep(fog_depth_begin, fog_end_distance, d), fog_depth_curve) * fog_density   (Godot 4.7.2; fog_density = 1.0, Core Rule 4)
L(c, f)     = luminance(c) * (1 - f) + luminance(fog_color) * f          (linear-luminance blend — commutes with WCAG luminance, so this works directly on scalars, not re-linearized hex colors)
contrast(f) = (max(L_hazard(f), L_tube(f)) + 0.05) / (min(L_hazard(f), L_tube(f)) + 0.05)
F_read      = min { d : contrast(factor(d)) < 4.0 }
```

**`fog_color` for Map 1 is Haze Low (`#E6EDF5`, L = 0.84) — a finding, not a guess.** Neither the art bible nor Tube Track ever stated `fog_color`'s value; solving for the value that reproduces Tube Track's own already-recorded contrast figures (4.14 at 0% fog, 1.96 at 25%, crossing 4:1/3:1/2:1 at roughly 1%/8%/24% opacity) pins it to Haze Low — Haze Top does not reproduce these figures. This GDD sets it formally.

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `d` | float | `>= 0` u, radial from the camera eye | Godot's own fog `d` (`rendering.md`'s verified 4.7.2 fact) |
| `factor` | float | `[0, 1]` | Fog opacity at `d` |
| `fog_depth_begin`, `fog_end_distance` (`F`) | float, `MapConfig` | `F > fog_depth_begin`; Map 1: 44, 84 | Fog ramp bounds |
| `fog_depth_curve` | float, `MapConfig` | `> 0`; Map 1: 1.0 | Matches Tube Track's own AC-12 precedent |
| `fog_color` | Color, `MapConfig` | Map 1: Haze Low (L = 0.84) | Derived above |
| `L_hazard`, `L_tube` | float, fixed (art bible) | 0.079, 0.49 | Signal Red, Mist Sage |
| `F_read` | float, derived | Map 1: 46.22 u | First distance below the art bible's own binding 4:1 floor |

**Output range:** letting `t = (d - fog_depth_begin) / (F - fog_depth_begin)` at `fog_depth_curve` = 1, `factor = smoothstep(t) = 3t² - 2t³`, and contrast crosses 4:1 at `factor* ≈ 0.0089` — inverting the *smoothstep*, not `t` directly, gives `t* ≈ 0.0555` (solving `3t²-2t³ = 0.0089` for small `t`; the earlier draft of this formula conflated `factor*` with `t*` directly, an error caught and corrected in this session's own qa-lead pass). `F_read = fog_depth_begin + 0.0555 * (F - fog_depth_begin)`, independent of `fog_depth_begin`/`F`'s individual values. **`F_read` is about 17× more sensitive to `fog_depth_begin` than to `F`** (`∂F_read/∂fog_depth_begin ≈ 0.945`, `∂F_read/∂F ≈ 0.0555`) — the contrast floor collapses in the first ~5.5% of the fog ramp's own distance, not near full opacity.

**This corrects a real, physically-impossible pairing Tube Track had been carrying.** Tube Track's own shipped defaults (`F` = 48, `F_read` = 46 — a 2 u gap) cannot coexist: a 2 u ramp cannot carry fog opacity from ~0% to 100%. The real requirement, solved from this formula, is `fog_depth_begin` ≈ 44, `F` ≈ 84 (a 40 u ramp), giving `F_read` = 44 + 0.0555×40 = **46.22 u** — still almost exactly Tube Track's own existing guess, but only reachable with a fog ramp roughly 20× wider than previously assumed. A cross-file edit correcting Tube Track's own shipped `fog_end_distance` (48 → 84) and formally adding `fog_depth_begin` = 44 is proposed in Dependencies.

**Example / margin check:** against Tube Track's own floor `F_read >= T_VIS_MIN * v_max + d_cam`: at `d_cam` = 7.84 (Camera's own resolved worst case), floor = 45.34, margin = 0.88 u (0.035 s); at the legacy `d_cam` = 8 guess, floor = 45.5, margin = 0.72 u (0.029 s) — a real margin, slightly larger than this project's earlier "0.02 s" tracking for this exact budget once the smoothstep inversion is done correctly.

**Unfogged baseline, corrected:** the art bible's own stated 4.17:1 (hazard/tube, unfogged) does not reproduce exactly from its own stated luminances (0.079/0.49) — direct computation gives **4.186:1**. The discrepancy is small (rounding in the art bible's own source figures) and doesn't change any conclusion above; noted here rather than silently repeated.

**F2. Speed-driven fog pull (Core Rule 5)**

```
u(speed)                = clamp((speed - V_START) / (v_max - V_START), 0, 1)
fog_end_distance(speed) = F_end_base - FOG_PULL_MAX * u(speed)
fog_depth_begin(speed)  = fog_depth_begin_base                              (not pulled — see Output range)
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `speed` | float | `[V_START, v_max]` = `[10, 25]` | Ball Movement, read-only |
| `u(speed)` | float | `[0, 1]` | Normalized, clamped, linear |
| `FOG_PULL_MAX` | float, tuning knob | 0-8 (hard ceiling ≈13.0, derived below), default 4 | Max inward pull of `F` at `v_max` |
| `F_end_base`, `fog_depth_begin_base` | float, `MapConfig` | Map 1: 84, 44 | Resting values at `V_START` |

**Output range:** only `F` is pulled with speed, deliberately — F1's own sensitivity finding shows pulling `fog_depth_begin` instead would move `F_read` about 17× faster per unit and risk the floor, while `F` barely moves it. `F_read(speed) = 44 + 0.0555 * (fog_end_distance(speed) - 44)`, falling monotonically from 46.22 u at `V_START` to `46.22 - 0.0555 * FOG_PULL_MAX` at `v_max`. The derived hard ceiling on `FOG_PULL_MAX` is the value that would exactly zero out F1's own margin at `v_max` against the tighter (legacy `d_cam` = 8) floor — solving `46.22 - 0.0555 * FOG_PULL_MAX = 45.5` gives **≈13.0** (looser than this GDD's own earlier draft stated, not tighter — nothing previously declared safe becomes unsafe under the correction). The shipped safe range (0-8) stays well clear of it.

**Example** (`FOG_PULL_MAX` = 4, the default, at three speeds): `speed` = `V_START` (10): `u` = 0, `F_read` ≈ **46.22 u**. `speed` = 17.5 (midpoint): `u` = 0.5, `F_read` ≈ **46.11 u**. `speed` = `v_max` (25): `u` = 1, `F_read` = 46.22 − 0.222 = **46.00 u** — clears the 45.5 floor (legacy `d_cam` = 8) by 0.50 u (0.020 s) and the 45.34 floor (resolved `d_cam` = 7.84) by 0.66 u (0.026 s); `fog_end_distance(v_max)` = 80, always `>` `F_read` (Core Rule 4). `F_read` never drops below either floor at any speed in `[V_START, v_max]`, since the function is monotonic and the endpoint is already checked.

**F3. Colorblind-safe ball/hazard contrast boost (Core Rule 9)**

```
L_target        = (L_hazard + 0.05) / R_target - 0.05
L_floor         = L_ember + margin_ember
L_ball_adjusted = colorblind_safe_enabled ? max(min(L_ball_base, L_target), L_floor) : L_ball_base
delta           = L_ball_adjusted - L_ball_base
```

**Why `R_target` = 1.4, not the art bible's own 4:1 or 3:1 floors elsewhere.** Both the ball (Slate Cobalt, L = 0.083) and the hazard face (Signal Red, L = 0.079) sit at the extreme low end of the luminance range, where WCAG contrast compresses hard. *Lightening* the ball is capped almost immediately by the already-locked ball/tube `>= 4:1` floor (tube L = 0.49 requires `L_ball <= 0.085` — only 0.002 of headroom, barely any improvement). *Darkening* the ball is bounded by the art bible's own "hazard is the darkest thing" claim (Section 1), which the art bible itself admits holds only because of Ember's L = 0.03, not Signal Red's — so the ball must stay clear of Ember with a real margin, or this fix trades one known risk for a new, unflagged one. **1.4 is the actual ceiling of the achievable envelope once both locked floors are respected, not an arbitrary undershoot** — reported as a raw luminance gap, it is roughly a 10× improvement (0.004 → ~0.037), the more honest description of the real perceptual gain given how the ratio metric itself compresses near black.

**Ownership boundary (Core Rule 2).** All adjustment happens on the ball's own luminance — this formula only *reads* `L_hazard`/`L_ember` (Obstacle System's own fixed values, already read by F1) and never touches them. `L_ball_adjusted` is applied by this system to the ball's material, live whenever `colorblind_safe_enabled` changes (Core Rule 9); Ball Movement has no consumer (Dependencies). It is sampled on `setting_changed`, not once per run: the toggle takes effect immediately.

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `colorblind_safe_enabled` | bool | `{true, false}` | Settings & Accessibility toggle (Rule 9); gates the boost |
| `L_ball_base` | float | `[0, 1]`, Map 1 default 0.083 (Slate Cobalt) | The active ball skin's own luminance, pre-adjustment |
| `L_hazard` | float | fixed, 0.079 (Signal Red) | Hazard-face luminance; read-only (Rule 2) |
| `L_ember` | float | fixed, 0.03 (Ember) | Hazard-shade luminance; read-only; anchors "hazard is darkest" (art bible §1) |
| `R_target` | float, tuning knob | default 1.4 | Target ball/hazard-face contrast ratio once boosted |
| `margin_ember` | float, tuning knob | default 0.01 | Minimum luminance gap the adjusted ball keeps above `L_ember` |
| `L_target` | float, derived | `[0, 1]`, 0.0421 at defaults | Max ball luminance yielding `R_target` against `L_hazard` |
| `L_floor` | float, derived | `[0, 1]`, 0.04 at defaults | Hard floor = `L_ember + margin_ember`; never crossed |
| `L_ball_adjusted` | float | `[0, 1]`, 0.0421 at Map 1 defaults | Final ball luminance applied when the toggle is on |

**Output range:** `L_ball_adjusted` is clamped to `[L_floor, L_ball_base]` — it can only stay equal to base or move darker, never lighter, and never at or below Ember. Darkening the ball also strictly *increases* ball/tube contrast (never threatens the locked 4:1/3:1 floors elsewhere) and leaves chroma (OKLCH C = 0.098) and hue untouched, since only the lightness axis is adjusted — the 0.08-0.12 chroma guardrail is preserved by construction, not a separate clamp. Independent of Core Rule 5's own per-frame chroma multiplier — different axis (luminance vs. chroma), different trigger (a settings toggle, evaluated on each change, vs. continuous speed), and the ball is already exempt from that shift regardless.

**Example** (Map 1, Slate Cobalt base skin, toggle on): `L_target = (0.079+0.05)/1.4 - 0.05 = 0.0421`; `L_floor = 0.03+0.01 = 0.04`; `L_ball_adjusted = max(min(0.083, 0.0421), 0.04) = 0.0421`; `delta = -0.0409`. Resulting ball/hazard-face ratio ≈ 1.40:1 (up from 1.03:1); resulting ball/tube ratio ≈ 5.86:1 (still clears the 4:1 floor, with more margin than the 4.06:1 baseline); ball/Ember gap = 0.0121, clearing the 0.01 margin.

## Edge Cases

- **If `d < fog_depth_begin`**: `factor` = 0 (Godot's own `smoothstep` clamps below its lower bound) — no fog, contrast equals the unfogged baseline (4.186:1 at Map 1 defaults).
- **If `d > fog_end_distance`**: `factor` = 1 — both the hazard and the tube are fully blended to `fog_color`, contrast collapses to exactly 1:1 (nothing is distinguishable, which is expected: `F` is where the world itself disappears, `F_read` is always reached well before this).
- **If a map's `MapConfig` sets `fog_end_distance <= fog_depth_begin`**: rejected at load with `FOG_RANGE_INVALID` — F1's own precondition (`F > fog_depth_begin`) is violated and no meaningful ramp exists.
- **If `FOG_PULL_MAX` is tuned high enough that `F_read(v_max)` would fall below Tube Track's own visibility floor**: rejected at load under Core Rule 11's own `MAP_VISIBILITY_UNSAFE` check — the same gate that catches a bad base palette also catches an over-aggressive speed-pull tuning, since F2's own `F_read(speed)` is evaluated at `v_max` as part of that check.
- **If `speed` is ever outside `[V_START, v_max]`** (a retuned config, or a value fed directly in a test): F2's own `clamp(..., 0, 1)` already holds `u(speed)` in `[0, 1]`, so `fog_end_distance(speed)` never extrapolates past its own defined range — no special-casing needed beyond the formula itself.
- **If `colorblind_safe_enabled` is toggled at any time** (Menu with Settings open, Paused, or mid-run): this system recomputes `L_ball_adjusted` and applies it to the ball's material immediately, on `setting_changed` (review item S4, Open Question 4 resolved: live). Nothing waits for `run_reset`, and Ball Movement is not involved.
- **If a future map uses different hazard/hazard-shade colors than Map 1's Signal Red/Ember**: Formula F3 re-derives `L_target`/`L_floor` against that map's own actual `L_hazard`/`L_ember` (Core Rule 2's read-only reference), never against Map 1's hardcoded numbers — the worked example uses Map 1's values for concreteness, not as a fixed constant baked into the formula.

## Dependencies

**Upstream (Environment & Theming needs these)**

| System | Type | What it needs | Note |
|--------|------|----------------|------|
| Tube Track (Approved) | Hard | `R`, segment/window data to theme | Already listed as a Tube Track dependent |
| Ball Movement (Approved) | Hard | `speed`, once per frame | Read-only; feeds Formula F2 |
| Obstacle System (Approved) | Soft, reference-only | The art bible's own fixed hazard color (Section 4) | Never a runtime call; feeds Formulas F1 and F3 |
| Settings & Accessibility (Designed) | in | `colorblind_safe_enabled` getter and `setting_changed` (both required) | Feeds Formula F3, applied live |

**Downstream (these need Environment & Theming)**

| System | Type | What it needs |
|--------|------|-------|
| Tube Track (Approved) | Hard (config values, not runtime calls) | `MapConfig`'s fog/color fields (Core Rule 1), published at map load |
| Obstacle System (Approved) | Hard (config value) | The Double Gate shared-plinth material/height |
| Ball Movement (Approved) | None (documented edge: Ball Movement has no consumer) | Environment applies `L_ball_adjusted` (Formula F3) to the ball's material itself; Ball Movement's own GDD records the edge from its side |
| Maps & Levels (Not Started) | Soft, not yet active | Per-map `MapConfig` selection mechanism |

**Bidirectional consistency (checked against the existing GDDs) — 7 cross-file resolutions applied this session**
- **Tube Track:** already lists Environment & Theming as supplying every `MapConfig` fog/color field. Its own Open Question 10 (the readable criterion) is resolved here (Formulas F1/F2) — **with a real correction, not just a value fill-in**: the placeholder `F` = 48 / `F_read` = 46 pairing is physically impossible (a 2 u fog ramp cannot carry opacity from ~0% to 100%); the real requirement is `fog_depth_begin` ≈ 44, `F` ≈ 84. Tube Track's own examples, tables, Tuning Knobs and ACs now carry F = 84 (A = 9, N = 12), propagated 2026-10-01 (review item C1; Open Question 2 resolved). Open Question 16 (idle scroll) is also resolved here (Core Rule 6, user decision: fixed on screen, not scrolling).
- **Ball Movement:** its own Open Question 3 (does the ball need its own speed cue) is resolved here (Core Rule 7, user decision: no, the environment carries it alone) — a cross-file edit has been applied. The `L_ball_adjusted` edge (Formula F3) is documented in its Dependencies as an edge with no consumer: Environment applies the value to the ball's material itself (review item S4), so Ball Movement reads nothing.
- **Obstacle System:** its own Open Question 12 (the Double Gate shared plinth) is resolved here (Core Rule 10) — a cross-file edit has been applied. Its own already-fixed hazard color (Section 4 of the art bible) is read, never altered, matching this GDD's own Core Rule 2 boundary.
- **Settings & Accessibility:** its own Open Question 1 (`colorblind_safe_enabled`'s real meaning) is resolved here (Core Rule 9 / Formula F3) — a cross-file edit has been applied in five places (Core Rule 8, an Edge Case, the Downstream table, Provisional assumptions, and its own Open Questions table).
- **Systems index:** the Dependency Map already lists Environment & Theming as depending on Tube Track and Ball Movement — consistent; the new Obstacle System and Settings & Accessibility reference-only edges are soft/data dependencies of the kind this project's own convention doesn't require listing in the index (the same treatment Settings & Accessibility's own Tube Track/Tilt Input references get).

**Provisional assumptions**: the exact per-map `MapConfig` selection mechanism Maps & Levels will want (no GDD yet); whether a future map's own hazard hue (within the reserved warm family) ever needs a different `R_target`/`margin_ember` pair for Formula F3 (untested beyond Map 1's own colors).

## Tuning Knobs

| Knob | Default | Safe range | Affects | Too low | Too high |
|------|---------|------------|---------|---------|----------|
| `fog_depth_begin` | 44 (Map 1) | Practical floor ≈44 at the shipped `F`=84 (F1's own sensitivity finding — `F_read` is ~19× more sensitive to this knob than to `F`); Core Rule 11 checks the actual derived `F_read` at load, not this range alone | Where the fog ramp starts (F1) | Below ~44 at defaults, `F_read` falls under Tube Track's own visibility floor — rejected at load (`MAP_VISIBILITY_UNSAFE`, Core Rule 11), not a silent failure | Shrinks the fog ramp's own usable width, pushing more of the visible world toward "fully clear," which reads as less atmospheric |
| `fog_end_distance` (`F`) | 84 (Map 1) | 60-130 (upper bound: Tube Track's own `A_MAX`-derived ceiling for `L`=12 is ≈129.5) | Where fog reaches full opacity (Core Rule 4) | The world disappears too close, feeling claustrophobic and cutting into the fog ramp's own width | Draw-call/segment cost grows (Tube Track's own `A` requirement scales with `F`); diminishing atmospheric benefit past a point |
| `fog_depth_curve` | 1.0 | 0.5-2.0 | Shape of the fog ramp (F1) | A very shallow curve makes the transition feel abrupt near `fog_depth_begin` | A steep curve delays the visible transition, then compresses it sharply near `F` |
| `FOG_PULL_MAX` | 4 | 0-8 (hard ceiling ≈13.0, derived in F2 — the value that would exactly zero out F1's own margin at `v_max` against the tighter legacy floor) | How much `F` pulls inward at `v_max` (F2) | Little to no speed-driven atmosphere change | Approaches (never reaches, if kept under the derived ceiling) the point where `F_read(v_max)` violates Tube Track's own visibility floor |
| `R_target` | 1.4 | 1.03 (no effective boost) to 1.4 (the derived hard ceiling given `margin_ember`'s own default) | Target ball/hazard-face contrast once `colorblind_safe_enabled` is on (F3) | Barely different from the unboosted 1.03:1 baseline — doesn't actually fix the flagged risk | Above 1.4 is unreachable given `margin_ember`'s own floor above Ember — `L_target` would clamp against `L_floor` instead, silently under-delivering the requested ratio |
| `margin_ember` | 0.01 | 0.005-0.03 | Minimum luminance gap the boosted ball keeps above Ember (F3) | Risks the boosted ball reading as visually confusable with the hazard's own shade color | Shrinks `R_target`'s own true reachable ceiling further (Knob Interactions) |

**Fixed constants (not tuning knobs):** the art bible's own fixed colors this system reads but never sets (`L_hazard`, `L_ember`, `L_tube`, and every other Map 1 palette value) — those are Obstacle System's and this GDD's own art-bible-sourced content, not designer-adjustable numbers in the traditional sense.

**Knob interactions**
- `fog_depth_begin` and `fog_end_distance` (`F`) jointly determine the derived `F_read` (F1) — Core Rule 11's own dynamic check at map load is the real gate, not either knob's own stated range in isolation; a map author should treat the stated ranges as starting guidance, not a substitute for that check.
- `FOG_PULL_MAX` interacts with both fog knobs above the same way — it shifts `F` at speed, which (via F1's own sensitivity relationship) shifts `F_read` a small, bounded amount; Core Rule 11 checks the worst case (`v_max`) directly.
- `R_target` and `margin_ember` jointly determine the true reachable contrast ceiling (F3) — raising `margin_ember` lowers how high `R_target` can actually go before `L_target` clamps against `L_floor` instead; they are not independent, and this GDD's own default pairing (1.4, 0.01) is the specific corner that was checked, not an arbitrary pick from a wider space.

**Sources of truth elsewhere:** `v_max`, `V_START`, `OMEGA_MAX` (Ball Movement); `d_cam` (Camera); `T_VIS_MIN` (Tube Track); `L_hazard`, `L_ember`, the entire Map 1 palette (the art bible, Obstacle System for hazard-specific values).

## Visual/Audio Requirements

**Mood States 1-3 only (art bible §2).** States 4-6 (near-miss, hit, personal best) are Juice & Feedback's own layer on top of this system's baseline; this section owns only what the tube/sky/fog/props actually look like at rest and under Formulas F1/F2.

| State | Fog | Chroma | Tube / sky / props |
|---|---|---|---|
| 1 Menu | Resting `MapConfig` values (Map 1: `fog_depth_begin`=44, `F`=84, `F_read`=46.22u, F1) — **Formula F2 is not evaluated in Menu**; there is no `speed` input outside a run, so the environment never approximates a pull, it simply reads its own resting fields | Base (no shift) | Sky/tube static; props at rest, no scroll; the preview hazard holds its screen position (Core Rule 6) — a still frame, not a slow version of running |
| 2 Run, low speed | `speed` near `V_START`=10, `u(speed)`≈0 (F2) — fog effectively at its resting F1 baseline | Base (no visible shift) | Wide hazard spacing (Obstacle System's own budget) reads against a fully clear horizon; seam scroll (Tube Track's `s`) is slow — no additional speed FX owned here, matching art bible §2's "no speed FX" at this state |
| 3 Run, high speed | `speed`→`v_max`=25, `u(speed)`→1 — `fog_end_distance` pulls to 80, `F_read` falls to 46.00u (F2 worked example) | ×0.88 (fixed, art bible §4) applied to tube, sky, and prop materials only — hazards, ball, pickups exempt by construction | Same geometry as State 2, just faster seam scroll (Tube Track) and the two derived shifts above; sky hue itself never changes across states — mood is carried by fog/chroma/light key, never a sky recolor (art bible §2's own state table has no sky column) |

The chroma exemption (hazards/ball/pickups) must be a materially separate parameter from the environment's own chroma multiplier, not a shared uniform gated by an object flag — this is a spec constraint for whoever implements it (technical-artist), not an instruction on how to write the shader.

**The Double Gate shared plinth (resolves Obstacle System's own Open Question 12).** A shallow, rounded collar of the tube's own surface, raised under the full arc span of the gate (matching its 90-270° footprint plus a 0.5D margin on each open end), height **0.15D** — tall enough to visually bridge the two gate posts into one object rather than two floating hazards, but well under the hazard family's own 1D minimum silhouette height (art bible §3b) and under the ball's own diameter, so it can never itself be mistaken for a hazard or foul the ball's path. Material: the tube's own palette (Mist Sage-derived, environment chroma ceiling C ≤ 0.05), never Signal Red/Ember — and unlike the hazard it sits under, the plinth **is** subject to the high-speed chroma multiplier (Core Rule 5), since it is environment, not hazard. Edge profile: rounded, filleted — hazards get "no fillets, no bevels" (art bible §3), but the plinth is explicitly environment shape language, so "round is yours" (§3) applies, not the hazard rule. This is the concrete geometry behind the boundary Core Rules 2 and 10 already stated.

**Per-map footprint — is the scope realistic for a solo dev?** Map 1's footprint is one tube material, a two-stop sky gradient, and a small MultiMesh-instanced background prop set (3-6 meshes, ~5x hazard scale or soft horizontal silhouettes, art bible §3d) — well inside the 150 draw-call budget since geometry is instanced and sparse. A **new map authored as new geometry** (new prop meshes, new tube topology) is the expensive path and is not recommended as the default. A **palette-swap map** — new tube hue, new sky stops, and a retint of the *same* prop meshes (only material parameters change, not geometry) — costs one new material set and zero new draw calls, and still satisfies every art-bible guardrail in "Deriving a new map's palette" (§4) since that procedure constrains hue/luminance/chroma, not mesh count. **Recommendation:** ship Map 2+ as palette-swap maps first; treat new prop geometry as a separately-scoped, later content pass, not something this GDD should assume as free.

| | Map 1 | Map 2 (palette-swap, recommended) | Map 2 (new geometry, deferred) |
|---|---|---|---|
| Tube material | 1 | +1 (new hue only) | +1 |
| Sky | 2-stop gradient | +1 new pair | +1 new pair |
| Props | 3-6 meshes, instanced | 0 new meshes, retinted | 3-6 new meshes |
| Draw-call delta | baseline | ~0 | non-trivial, needs its own budget check |

**Audio — a real call, not a placeholder.** This system owns nothing audio. Its own Overview already scopes it as "everything the player sees" — ambient wind/hum/reverb is a distinct sensory channel with its own mixing concerns (ducking under juice stings, spatialization) that don't follow from anything this GDD derives. If a speed-driven ambient layer is wanted (e.g. wind intensity rising with `speed`, mirroring Formula F2's own shape), it should read Ball Movement's `speed` directly, the same read-only pattern this GDD already uses — it does not need this system's own derived fog/chroma values as an intermediate. Ownership belongs to Juice & Feedback or a future dedicated Audio Direction GDD, not here. **Audio/Ambient: None owned here.**

**📌 Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:environment-theming` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

No player-facing UI of its own. No requests to other systems beyond what Dependencies already states. No UX Flag: there is no screen or HUD element of its own to specify — this system is background presentation, never a UI surface.

## Acceptance Criteria

**Targets:** **[M]** `EnvMath` static pure functions (F1 `factor`/luminance-blend/`contrast`/`F_read`-search, F2 speed-driven `fog_end_distance`, F3 `L_ball_adjusted`); **[C]** `EnvCore`, a `RefCounted` with injected Ball Movement/Settings & Accessibility test doubles and a `log_sink` (Core Rule 13, mirrors `BallCore`/`CameraCore`); **[K]** `EnvConfig.validated(log_sink)`, a preflight returning a clamped copy (Core Rule 11, `MAP_VISIBILITY_UNSAFE`; Edge Cases, `FOG_RANGE_INVALID`); **[L]** CI lint, no engine coupling and no undeclared outward edges (mirrors Camera's own AC-17 / Ball Movement's AC-25); **[I]** integration, deferred until named owner+date; **[V]** device/playtest evidence in `production/qa/evidence/environment-theming/`. Tests live in `tests/unit/environment_theming/`, named `environment_theming_[feature]_test.gd`.

**Fixture:** `make_env_fixture()` returns Map 1's `MapConfig` (`fog_depth_begin` = 44, `fog_end_distance` = 84, `fog_depth_curve` = 1.0, `fog_density` = 1.0, `fog_color` = Haze Low, L = 0.84; `V_START` = 10, `v_max` = 25, `FOG_PULL_MAX` = 4, `R_target` = 1.4, `margin_ember` = 0.01) plus the art bible's fixed luminances (`L_hazard` = 0.079 Signal Red, `L_ember` = 0.03, `L_tube` = 0.49 Mist Sage, `L_ball_base` = 0.083 Slate Cobalt) and Ball Movement's `D` = 0.8. Test doubles supply Ball Movement's `speed` and Settings & Accessibility's `colorblind_safe_enabled`/`setting_changed`. `T_VIS_MIN` = 1.5 s (Tube Track, read-only); `d_cam` = 7.84 (Camera's resolved worst case, primary floor 45.34) and 8.0 (legacy, floor 45.5, used only where an AC says so). `F_read` oracles are computed by evaluating F1's actual formula (bisection over `d` to 1e-3), not a shortcut approximation; tolerance 1e-3 for bisection-derived values, 1e-6 for closed-form F3 values, stated per-AC otherwise.

**Logic, BLOCKING**
- **AC-1 [K]** (Core Rule 1) `EnvConfig.validated()` loads Map 1's own defaults with zero warning/error codes.
- **AC-2 [M]** (F1, Map 1) Bisection over `d` finds the first crossing of `contrast(factor(d)) < 4.0` at `F_read` ≈ 46.221 u. Unfogged baseline (`d < 44`) contrast = 4.186:1. Fully fogged (`d >= 84`) contrast = 1.0 exactly.
- **AC-3 [M]** (F1, generality) Same luminance values, a synthetic pair `fog_depth_begin` = 100, `fog_end_distance` = 300 → `F_read` ≈ 111.106 u via the same bisection. A mutation returning a Map-1-shaped constant regardless of input `MapConfig` must fail this AC.
- **AC-4 [K]** (F1, the physical-impossibility finding, as an actual rejection) `fog_depth_begin` = 44, `fog_end_distance` = 48 (the old Tube Track pairing) → derived `F_read` ≈ 44.22 u, below the floor (45.34 at `d_cam` = 7.84) → rejected at load with exactly one `MAP_VISIBILITY_UNSAFE`, naming the map and the ≈1.12 u shortfall. Proves the old pairing is actually caught, not just narrated as bad in prose.
- **AC-5 [M]** (Core Rule 4) `F` is always strictly greater than `F_read` across AC-2/AC-3/AC-4's three configs — the crossing fraction is always in `(0, 1)`, structurally.
- **AC-6 [M]** (F2, speed sweep, `FOG_PULL_MAX` = 4) `speed` = 10 (`u` = 0) → `F_read` ≈ 46.221 u; `speed` = 17.5 (`u` = 0.5) → `F_read` ≈ 46.110 u; `speed` = 25 (`u` = 1) → `F_read` ≈ 45.999 u. All three strictly clear both floors (45.34 / 45.5) — `F_read` never drops below the visibility floor at any speed.
- **AC-7 [K]** (F2, `FOG_PULL_MAX` ceiling) `FOG_PULL_MAX` = 8 (the safe-range max) at `v_max` → `F_read` ≈ 45.777 u, loads cleanly. `FOG_PULL_MAX` = 20 (well past the derived ≈13.0 ceiling) at `v_max` → `F_read` ≈ 45.111 u, below both floors → rejected with `MAP_VISIBILITY_UNSAFE`. Demonstrates the hard ceiling as an actual load-time rejection, not merely a stated bound.
- **AC-8 [M]** (F3, `R_target`) `L_target` = 0.042143, `L_floor` = 0.04, toggle on → `L_ball_adjusted` = 0.042143, `delta` = −0.040857 (closed-form, exact to 1e-6).
- **AC-9 [M]** (F3, toggle-off) Toggle off → `L_ball_adjusted` is bit-identical to `L_ball_base` (0.083), `delta` = 0, regardless of `L_hazard`/`L_ember`/`R_target`. A mutation that computes `L_target`/`L_floor` even when the toggle is off must fail this AC.
- **AC-10 [M]** (F3, floor clamp) A synthetic `R_target` = 2.0 → `L_target` = 0.0145, below `L_floor` (0.04) → `L_ball_adjusted` clamps to 0.04, not 0.0145 — proves the Ember margin overrides the target ratio when the two conflict.
- **AC-11 [M]** (F3, future-map re-derivation, Edge Cases) A synthetic `L_hazard'` = 0.05, `L_ember'` = 0.02 → `L_target'` = 0.021429, `L_floor'` = 0.03, `L_ball_adjusted'` = 0.03 — distinct from Map 1's own 0.042143. A mutation that hardcodes Map 1's numbers regardless of input must fail this AC.
- **AC-12 [C]** (Core Rule 6) `s_idle` = 0, then `s_idle` = 50: the Menu-state preview hazard's published screen-anchor is bit-identical across both.
- **AC-13 [L]** (Core Rule 7, architectural/negative) Static scan of `EnvMath`/`EnvCore`'s public surface: no symbol is addressed to Ball Movement (it has no consumer); the only ball-related output is the single `l_ball_adjusted` value applied to the ball material by Environment — banned tokens `ball_scale`, `ball_tint`, `ball_speed`, `set_ball_`, or any second public value alongside it. A mutation adding such a symbol must fail this AC.
- **AC-14 [K]** (Core Rule 2 / 10, plinth boundary) The Double Gate plinth's own material: never bit-equal to Signal Red's or Ember's hex value; chroma `<=` 0.05; height exactly `0.15 * D` (0.12 u at `D` = 0.8).
- **AC-15 [C]** (Core Rule 12, determinism) Two fresh `EnvCore` instances fed an identical scripted sequence (including a toggle flip, AC-19) are bit-identical in `fog_end_distance(speed)` and `L_ball_adjusted` after every step.
- **AC-16 [L]** (Core Rules 12-13) Static scan of `EnvMath`, `EnvCore`, `EnvConfig`: none contains `request_`, `Input.`, `Engine.`, `Time.`, `OS.`, `DisplayServer.`, `get_tree`, `_process`, `_physics_process`, `randi`, `randf`, `randomize`, or any write to another system beyond reading its own published getters.
- **AC-17 [K]** (Edge Case, `FOG_RANGE_INVALID`) `fog_end_distance <= fog_depth_begin` (44/40, and the 44/44 boundary) is rejected with exactly one `FOG_RANGE_INVALID`, distinct from `MAP_VISIBILITY_UNSAFE`.
- **AC-18 [C]** (Edge Case, speed out of range) `speed` = −5 and `speed` = 100 hold `u(speed)` clamped to `{0, 1}`; `fog_end_distance` never extrapolates past `[F_end_base - FOG_PULL_MAX, F_end_base]`.
- **AC-19 [C]** (Edge Case, colorblind toggle mid-run) Starting off (`L_ball_adjusted` = 0.083), a `setting_changed(true)` mid-sequence (or in Menu, or in Paused) republishes `L_ball_adjusted` = 0.042143 on the very next read and applies it to the ball material that same frame, with no wait for `run_reset`.
- **AC-20 [K, ADVISORY]** (Core Rule 8, Config/Data smoke) A second synthetic map's palette (hue outside the reserved ranges, contrast floors re-checked) passes the art bible's own guardrail checks at load with zero warnings.

**Integration [I], deferred**
- **AC-21 [I], deferred** (Core Rules 1, 5, 9, 11) A test-only driver wires a real `BallCore`, a real loaded `MapConfig`, and Settings & Accessibility's real toggle to `EnvCore` across a scripted run. Not BLOCKING today — no named owner or date for the driver (mirrors Camera's own AC-19 precedent).
- **AC-22 [I], deferred** (Open Question 5) On-device Mobile-renderer contrast sampling versus F1's own Forward+-derived formula, within a stated tolerance — a numeric device check (`coding-standards.md`'s own Scope limit), not Visual/Feel. An owner exists (godot-specialist) but no date yet — deferred, not ADVISORY-by-default.

**Device and playtest**
- **ENV-1 [V, ADVISORY]** "Quiet World, Loud Hazards" mood read (Mood States 1-3): screenshot + lead sign-off, recorded in `production/qa/evidence/environment-theming/`. ADVISORY — `production/qa/designated-gates.md` carries no entry for Environment & Theming, so no creative-director designation or producer ratification exists to escalate it (verified this session, not assumed).

**Gate policy.** AC-1 through AC-19 are Logic, BLOCKING — formulas F1-F3 and Core Rules 1-13, the same bar Camera's and Ball Movement's own `[M]`/`[C]`/`[K]`/`[L]` rows set. AC-20 is Config/Data, ADVISORY. AC-21 and AC-22 are Integration — BLOCKING once each acquires a named owner *and* a date (neither exists today), tracked as open gaps, not present blockers. ENV-1 is Visual/Feel, ADVISORY by default; escalation requires a fresh `/design-review` pass with an explicit creative-director designation and producer ratification recorded in `production/qa/designated-gates.md` — not assumed here.

## Open Questions

| # | Question | Owner | Resolve when |
|---|----------|-------|--------------|
| 1 | Art bible Section 6 ("Environment Design Language") is still empty — this GDD's own Visual/Audio Requirements section is effectively its first draft; filling in Section 6 formally (tube material/geometry language, fog as a mood tool, the sky convention, prop guardrails, the palette-swap-vs-new-geometry cost distinction, the shared-plinth pattern) is a real follow-up, not done here | art-director | Before Map 2 content authoring begins |
| 2 | RESOLVED 2026-10-01 (review item C1): Tube Track's examples, F3 table, Tuning Knobs and ACs now use `F` = 84 (A = 9, N = 12, `F_read` = 46.00 at `v_max`); the corrected-away `F` = 48 appears only as the rejected pairing in this GDD's AC-4 | — | Resolved |
| 3 | Whether a future map's own hazard hue (within the reserved warm family) ever needs a different `R_target`/`margin_ember` pairing for Formula F3 — untested beyond Map 1's own colors | whoever authors a second map's palette | When a second map's palette is authored |
| 4 | RESOLVED 2026-10-01 (review item S4): the boost (Formula F3) applies **live**, on `setting_changed`, in any phase; Environment & Theming applies `L_ball_adjusted` to the ball's material itself (no ball skin system exists yet) and Ball Movement is not a consumer | — | Resolved |
| 5 | Mobile-renderer fog behavior is explicitly unverified (`docs/engine-reference/godot/modules/rendering.md`'s own "Still unverified" list) — this GDD's entire Formula F1 derivation assumes Forward+'s own verified fog formula; whether the Mobile renderer (this project's likely actual target renderer, per `technical-preferences.md`) behaves identically is unconfirmed | godot-specialist | Before implementation, on-device |
| 6 | Map 2's actual content-authoring path (palette-swap, recommended in Visual/Audio Requirements, versus new geometry) needs a real scheduling decision once Maps & Levels exists — this GDD only recommends the cheaper path, it doesn't commit production to it | producer, whoever authors Maps & Levels | When Maps & Levels is authored or scoped |
