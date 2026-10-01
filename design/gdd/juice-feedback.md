# Juice & Feedback

> **Status**: Designed (2026-09-29), pending independent `/design-review`. Cross-file edit applied 2026-09-30 (from `scoring-personal-best.md`'s own `/design-review`): Core Rule 5, States and Transitions, Edge Cases, Dependencies, AC-12, and AC-13 updated — `personal_best_updated` can legally co-occur with `run_abandoned`, not only `run_ended`; the abandon path is now a defined silent suppression (no bloom/sweep, no log), not a `JUICE_PB_CONTRACT_VIOLATION`, which is now correctly scoped to the one case that actually violates Scoring's contract (arrival during `NearMiss`). **Second cross-file edit applied 2026-09-30** (same source GDD's re-review): Core Rules 4-5, States and Transitions, Edge Cases, Interactions, Dependencies, Visual/Audio Requirements, UI Requirements, and AC-12 updated again — this system no longer signals HUD for the personal-best banner at all (only its own bloom/sweep celebration stays Hit-only); HUD now reads `personal_best_updated` directly from Scoring & Personal Best for the banner, on both the hit and abandon paths.
> **Author**: user + agents
> **Last Updated**: 2026-09-30
> **Implements Pillar**: Pillar 3 (Juice on Every Near-Miss) — primary, this system IS the pillar's entire mechanism; Pillar 1 (Instant Readability) — secondary, the explicit tension juice must never win against.

## Overview

Juice & Feedback owns the moment-to-moment feel of three events every run has: a near-miss, a hit, and (sometimes) a new personal best — the white ring pulse, the whoosh, the FOV punch, the hitstop and grey-out, the shard burst, the haptic pulse. It listens to events three other Approved systems already publish (Near-Miss Detection's `near_miss_detected`, Run State's `run_ended`/`run_reset`/`restart_unlocked`, Scoring's `personal_best_updated`) and drives mechanisms four more Approved systems already built for it (Camera's `apply_fov_punch`, Platform Services' `haptic(kind)`, Tube Track's surface-anchored effect frame, Obstacle System's own published hazard data for hit VFX) — it is the layer that finally answers what every one of those systems' own "Juice & Feedback owns the actual values" notes has been deferring. Almost everything this system needs to decide is already decided by the art bible's own Mood States 4-6 (near-miss, hit, personal best) — this GDD's job is turning that already-locked design intent into real numbers, real event wiring, and real constraints (a 0.20 s hitstop that's already load-bearing in Run State's own restart-lock formula; a photosensitivity cap; no screen shake, ever), not inventing a new feel from scratch. It decides nothing about when a near-miss happened (Near-Miss Detection), what a hit's own killer hazard looks like (Obstacle System), or the camera's own base transform (Camera, which only exposes the punch mechanism) — it owns exactly the moment three specific events become something the player feels.

## Player Fantasy

**The fantasy.** Every close call rewards me instantly, every death stings once and lets go, and the one time I beat my own record, the game knows it too.

**What the player feels.**
- **A near-miss is a tiny triumph, every single time.** The same white ring pulse, the same whoosh, the same brief FOV punch — a threading-the-needle thrill I can chase on purpose (game-concept.md: "players will start taking riskier near-miss lines once they trust their own reflexes, chasing bonus feedback"; Pillar 3: "every close dodge must feel immediately rewarding").
- **A death is a sharp, exact sting — never a punishment.** The world grey-out isolates exactly what killed me, the hitstop is a moment, not a wait, and then I'm bursting into shards and already looking at the restart prompt (art bible mood state 5: "sting, then 'again', no shame").
- **My reactions never fight the reward.** The juice never covers the hazard I'm still dodging, never delays my restart, and never asks me to notice it — it just confirms what I already felt (Pillar 1: readability beats effect).
- **Beating my own record actually feels like something.** A brief lift, a cool sweep down the tube, a quiet banner — noticed, never disruptive, never gold (art bible mood state 6; Pillar 5's own "skill mastery" framing).

**Feelings to avoid.** Screen shake (explicitly cut, Camera's own GDD already encodes this); a flash rate or intensity that could ever read as photosensitivity-unsafe; juice that competes with or delays reading a hazard; a hit that reads as mockery or shame rather than a clean, respected sting; a restart the player has to wait through because juice hasn't finished.

**Serves the pillars.** *Pillar 3, Juice on Every Near-Miss* — this system IS the pillar's entire mechanism, not a supporting piece of it. *Pillar 1, Instant Readability* — the tension the art bible itself names explicitly: juice must never obscure what's actually dangerous, even for a frame.

## Detailed Design

### Core Rules

1. **Three triggers, three presentations.** This system listens to `near_miss_detected` (Near-Miss Detection), `run_ended` (Run State & Restart — a hit), and `personal_best_updated` (Scoring & Personal Best) — each drives exactly one presentation (art bible Mood States 4/5/6 respectively). No other event drives a presentation.

2. **Near-miss presentation (Mood State 4).** On `near_miss_detected(hazard_id, run_id)`: a cool-white rim on the ball (60-100ms), a white ring pulse on the tube surface at the ball's own position (using Tube Track's surface-anchored effect frame), a whoosh (audio), a `NEAR_MISS` haptic (Platform Services), and `apply_fov_punch` (Camera) at a fixed 1-2% magnitude. No intensity scaling by closeness — Near-Miss Detection's own Core Rule 7 supplies no closeness value, so every near-miss gets the identical presentation, at whatever fixed value within that 1-2% band this GDD's own Tuning Knobs lock.

3. **Hit presentation (Mood State 5).** On `run_ended(run_id, hazard_id, run_time_ms)`: hitstop for `hitstop_actual` = 0.20 s, fixed (this GDD's own value — the art bible's Mood State 5 gives a 150-200 ms range, and this GDD locks the top of it, exactly matching Run State's own `HITSTOP_MAX` derivation constant so `RESTART_LOCK - hitstop_actual >= T_READ` never has less margin than Run State's F4 already assumed); a world grey-out while the killer hazard (looked up via `hazard_id` from Obstacle System) keeps full chroma; a soft white flash (≤30% opacity, ≤2 frames, photosensitivity-safe); the ball bursts into cool-white shards; a `HIT` haptic. `hitstop_actual` is injected back into Run State's config by the composition root (Run State never calls this system directly — its own Dependencies text already anticipates this). The full sequence is sized to fit inside Run State's own restart lock under normal timing — Rule 8 is the actual safety net if it doesn't.

4. **Personal-best presentation (Mood State 6).** On `personal_best_updated(final_score)`, while the hazard-reaction track is `Hit`: a brief value lift, a capped cool bloom (never gold — an explicit art-bible exclusion), and a white ring sweep down the tube. **Revised 2026-09-30 (`scoring-personal-best.md` re-review, user decision):** this system no longer signals HUD to show the banner — HUD's own banner now reads `personal_best_updated` directly from Scoring & Personal Best (`hud.md` Core Rule 3), independent of this system's own presentation state, so a voluntary-quit new best still gets HUD's basic acknowledgment even though this system's own bloom/sweep stay Hit-only (Rule 5). Never delays the restart, and layers on top of whatever else is already presenting rather than gating it. No dedicated haptic kind — the co-occurring hit's `HIT` haptic (Rule 3) is the only haptic cue for a personal best; Rule 5 guarantees one is always already playing, and a separate kind would either get dropped by Platform Services' own priority gate (if not above `HIT`) or break the "death cue is never dropped" invariant (if above it).

5. **A personal-best presentation co-occurs with a hit; an abandoned-run personal best is suppressed, not presented.** `personal_best_updated` fires from Scoring & Personal Best's own Core Rule 6 on **either** `run_ended` (a hit) **or** `run_abandoned` (Scoring & Personal Best Core Rule 5 treats the two identically) — resolved 2026-09-30, correcting this GDD's earlier assumption that only `run_ended` could fire it. When it arrives while the hazard-reaction track is `Hit` (the `run_ended` path), the personal-best presentation (Rule 4) layers on top of the hit presentation as before, matching the art bible's own "sting, then triumph" sequencing (Mood State 5 then 6). When it arrives while the hazard-reaction track is `Idle` (the `run_abandoned` path — no hit to layer on), this system deliberately does **not** present it: no bloom, no sweep, no log — the milestone track stays `Off`. **The banner is no longer this system's concern at all (Rule 4, revised 2026-09-30): HUD shows it directly off Scoring's own event regardless of this system's own track state**, so a voluntary quit still gets that basic acknowledgment even though this system stays silent. The art bible's own Mood State 6 language ("triumph" layered on a "sting") has no natural home when the player chose to leave rather than being stopped by a hazard, which is why *this system's own* celebration stays Hit-only. Scoring's own new best is still written and takes effect immediately regardless (Save & Persistence; HUD's `personal_best` display updates on the next read) — only this system's *bloom/sweep celebration* is suppressed, never the record itself and never HUD's own banner.

6. **A hit always cuts an in-progress near-miss presentation immediately.** Mirrors Platform Services' own established haptic priority (`HIT` > `NEAR_MISS` > `UI_TAP`) — the death sting must never be diluted or delayed by a still-finishing near-miss effect. This is distinct from Near-Miss Detection's own Core Rule 4 (which already prevents a near-miss firing at all for the *same* hazard that then hits) — this rule covers a *different* hazard's still-playing near-miss.

7. **`run_reset` clears every in-progress presentation, unconditionally.** Matches Run State & Restart's own Interactions table ("`run_reset` clears effects"): hitstop ends, grey-out lifts, any pending ring/bloom/shard/banner-signal is cancelled outright, not faded. This is the actual safety net behind Rule 8.

8. **A restart tap can cut the hit presentation short, and this system must tolerate that, not merely avoid it.** Run State & Restart's own Edge Cases already state this plainly: the presentation "must be sized within the lock or be safe to interrupt." Rule 3's timing keeps it sized to fit under normal conditions; Rule 7's unconditional clear is what makes an early cut safe regardless.

9. **The FOV punch is the one camera effect this system is allowed — never a position or rotation change.** Camera's own Core Rule 7 exposes exactly one mechanism, `apply_fov_punch`, and this system never asks Camera for anything else. Camera's own "no screen shake" constraint is a hard rule this GDD does not relax.

10. **`reduced_motion_enabled` scales down this system's own flash, shard, and bloom intensity — never the hitstop duration.** When true (Settings & Accessibility), hit-presentation flash opacity, shard-burst intensity, and the personal-best bloom/sweep's own intensity are all reduced by `REDUCED_MOTION_INTENSITY_SCALE` (Tuning Knobs) — the bloom is included because it shares the hit flash's photosensitivity rationale and always co-occurs with it (Rule 5) — reusing the existing accessibility toggle rather than adding a dedicated "reduced juice" field, since both concerns (Tube Track's seam flash, this system's hit flash) are the same underlying photosensitivity risk. `hitstop_actual` stays fixed at 0.20s in every mode (user decision) — a brief world-pause is a weaker photosensitivity risk than a flash, and keeping it fixed means Run State's own `LOCK_MIN` never needs recomputing for this system's own setting.

11. **Photosensitivity cap: no more than 3 flashes per second, ever, system-wide.** A hard ceiling shared with Tube Track's own seam-flash budget (art bible: "the flash budget is global"). This system's own flash-rate accounting must account for Tube Track's concurrent seam flashes when checking the cap, not just its own effects in isolation. The actual runtime enforcement of this cap is a shared rolling ledger of the last 1.0 s of flash timestamps across all three sources (seam, hit, near-miss ring). Formulas F1/F2's rate-budget derivation (`f_headroom`, `NEAR_MISS_FLASH_MIN_INTERVAL`) is the *design-time* validator that confirms a map+lock combination leaves any headroom at all — it bounds a rate averaged over a full death-to-death cycle, which does not by itself prevent a local burst within one second; the ledger is the *runtime* safety net that holds a would-be near-miss flash below the luminance threshold (same non-skip semantics as F2 — the reward is never dropped, only its flash contribution) whenever the trailing 1-second window already holds 3 flashes, even if `NEAR_MISS_FLASH_MIN_INTERVAL` alone would have allowed it. Juice derives seam-flash timestamps itself from Tube Track's already-public `s`, `L`, `n_seams` — no new Tube Track interface is needed, since Juice already queries `s` at presentation time for the surface-anchored effect frame (Interactions table) — and registers its own hit-flash and near-miss-flash timestamps directly, since it fires both itself.

12. **Haptics: this system finalizes values on top of Platform Services' own safety rails.** Platform Services defines the schema (`duration_ms`, `amplitude`, `priority`) and the gate (`HAPTIC_MIN_INTERVAL`, `HAPTIC_MAX_MS`); this GDD finalizes `NEAR_MISS` (30ms/0.5/priority 1) and `HIT` (80ms/1.0/priority 2) unchanged from Platform Services' own provisional defaults — `NEAR_MISS` sits inside the 60-100ms rim window without weight; `HIT` fits inside the fixed 200ms hitstop (Rule 3) and keeps priority strictly above `NEAR_MISS`, preserving Platform Services' own "death cue never dropped" structural invariant. `UI_TAP` is **not** adopted here — Core Rule 1 admits exactly three triggers, none of them a menu tap, so `UI_TAP`'s ownership transferred to Menus & Screen Flow — HUD's own GDD (2026-09-29) did not adopt it either (its own Core Rule 11 caps HUD's outbound calls at exactly three, none of them `UI_TAP`-shaped) — and Menus & Screen Flow's own Core Rule 7 finalized it (2026-09-29, values unchanged from Platform Services' own provisional defaults). `reduced_motion_enabled` (Rule 10) does **not** scale haptic amplitude — that reuse is justified specifically by shared photosensitivity risk between flash and shard visuals, which haptic amplitude does not carry, and this system has no interface to scale amplitude through even if it wanted to (Rule 13 bars a second call into Platform Services beyond `haptic(kind)`). Platform Services' own separate `haptics_intensity` field (Settings & Accessibility-supplied, multiplying amplitude inside its own Formula F3) is the correct owner of a future reduced-haptics feature, resolving the other half of Platform Services' own Open Question 16 — not this GDD's interface.

13. **No side effects beyond the calls this system is explicitly given.** Juice & Feedback never sends requests back to Near-Miss Detection, Run State, Scoring, or Obstacle System — it only reads their events. It calls exactly `Camera.apply_fov_punch`, `PlatformServices.haptic`, and whatever rendering/audio calls its own implementation needs — never a second, undocumented interface into any dependency.

### States and Transitions

This system does not run a single state machine — it runs two independent, layerable **presentation tracks**, matching Rule 5 (a personal best layers on a hit rather than replacing it).

**Hazard-reaction track** (near-miss and hit are mutually exclusive within this track):
- `Idle` — no near-miss or hit presentation playing. The default, and the state reached whenever a presentation completes or is cleared.
- `NearMiss` — playing the near-miss presentation (Rule 2). Entered from `Idle` on `near_miss_detected`. Returns to `Idle` when the presentation's own fixed duration elapses; nothing else ends it early except a hit (below).
- `Hit` — playing the hit presentation (Rule 3). Entered from `Idle`, or from `NearMiss` (cutting it immediately per Rule 6), on `run_ended`. Returns to `Idle` when the presentation completes.

**Milestone track** (independent of the hazard-reaction track's own timing):
- `Off` — the default.
- `PersonalBestOverlay` — entered from `Off` on `personal_best_updated` **only when the hazard-reaction track is already in `Hit`** (Rule 5 — the `run_ended` path). A `personal_best_updated` arriving while the hazard-reaction track is `Idle` (the `run_abandoned` path, Rule 5) is acknowledged but does not transition the milestone track at all — it stays `Off`. `personal_best_updated` arriving while the hazard-reaction track is `NearMiss` is a contract violation (Edge Cases, `JUICE_PB_CONTRACT_VIOLATION`), not a defined entry to this state. Returns to `Off` when its own bloom/sweep completes (no longer "banner-signal/bloom/sweep" — the banner is HUD's own independent read of Scoring's event as of 2026-09-30, Rule 4); it does not need to finish before the hazard-reaction track returns to `Idle`.

**Global override:** `run_reset`, at any time, forces both tracks to `Idle`/`Off` immediately and unconditionally (Rule 7). This transition takes priority over every transition above and is never conditional on which state either track is currently in.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| Near-Miss Detection | Inbound | `near_miss_detected(hazard_id, run_id)` — triggers Rule 2 |
| Run State & Restart | Inbound | `run_ended(run_id, hazard_id, run_time_ms)` triggers Rule 3; `run_reset` triggers Rule 7 (unconditional clear); `restart_unlocked` is informational only — this system does not gate on it, since Run State's own lock math already accounts for this system's worst-case duration (Rule 3) |
| Scoring & Personal Best | Inbound | `personal_best_updated(final_score)` triggers Rule 4, always co-occurring with a hit presentation (Rule 5) |
| Obstacle System | Inbound (queried, not pushed) | the killer hazard's `hazard_id`, footprint, and type, read at `run_ended` time to isolate it in the grey-out (Rule 3) |
| Camera | Outbound | `apply_fov_punch(amount, duration)` — Rule 9, the only camera call this system ever makes |
| Platform Services | Outbound | `haptic(kind)` for `NEAR_MISS` / `HIT` — Rule 12, respects Platform Services' own `HAPTIC_MIN_INTERVAL` / `HAPTIC_MAX_MS` gate |
| Tube Track | Outbound (uses) | the surface-anchored effect frame (`P(theta,s,h)`) to place the near-miss ring pulse and hit shard burst at the correct world position |
| Settings & Accessibility | Inbound (queried) | `reduced_motion_enabled`, read at presentation time to scale flash/shard intensity (Rule 10) |
| HUD | none (provisional, queried) | HUD may query this system's own presentation-track state to avoid overlapping its own animations — still provisional (`hud.md` Open Question 6); this system pushes nothing to HUD (Rule 13) — revised 2026-09-30: the personal-best banner is no longer signaled here, HUD reads `personal_best_updated` directly from Scoring & Personal Best instead (`hud.md` Core Rule 3) |

## Formulas

All examples use Tube Track's defaults (`L` = 12, `n_seams` = 1, `v_max` = 25 → `f_seam` = 2.0833 Hz), Run State's defaults (`RESTART_LOCK` = 0.5 s, `T_restart` @ 60 fps = 0.216 s, F2), and Pattern & Difficulty's resolved first-hazard floor (`s_first` ≥ 11, Ball Movement Rule 5, Run State Open Question 11). `F_GLOBAL_MAX` = 3 Hz is the art bible's and Tube Track's own WCAG 2.3.1 cap (Core Rule 11) — this system does not introduce a second cap, it accounts against the same one.

**F1. Global flash-rate budget (Core Rule 11)**

Photosensitivity is checked as a *cross-system* rate, not per-effect, because seam, hit, and near-miss flashes share one global cap. The naive check — summing each source's own isolated worst-case rate — is provably too strict: it fails even at today's shipped defaults, because it silently assumes the seam can flash at its full rate *while* the hit flash is also firing at its full rate, which the state machine forbids (Tube Track's `advance(s)` — and so every seam crossing — is only valid in Running; Hit/Ended freeze it, Tube Track Rule 4). The real bound accounts for how much of a death-restart cycle is actually spent running.

```
T_dead      = RESTART_LOCK + T_restart                  (frozen: Hit + Ended + restart transition, no seam flashes possible)
T_run_min   = s_first / v_max                            (shortest legal travel before the next hazard can be hit)
T_cycle_min = T_dead + T_run_min                          (shortest possible death-to-death cycle)
n_seam_max  = ceil(f_seam * T_run_min)                    (max seam crossings that can land inside that short running window, worst-case phase)
f_combined  = (1 + n_seam_max) / T_cycle_min              (worst-case seam+hit rate, temporally correct)
f_headroom  = F_GLOBAL_MAX - f_combined                   (what's left for Juice's own near-miss ring flash)
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `f_seam` | float | Tube Track's own F5 output for the loaded map, ≤ `SEAM_HZ_MAX` (3 Hz) | the map's actual seam frequency at `v_max` — a per-map value, never assumed to be the 2.08 Hz default |
| `RESTART_LOCK` | float | 0.45-0.60 s (Run State F4) | the restart lock |
| `T_restart` | float | 0.216 s at 60 fps (Run State F2, worst case for *maximizing* hit rate is the fastest device) | touch-to-first-frame restart transition; treated as seam-flash-free |
| `s_first` | float | ≥ 11 (Ball Movement Rule 5, Run State Open Question 11) | shortest legal distance to the first hazard after any restart (a restart always re-enters the INTRO tier) |
| `v_max` | float | 25 u/s (Ball Movement, provisional) | Ball Movement's max speed |
| `T_dead`, `T_run_min`, `T_cycle_min` | float, s | derived | see above |
| `n_seam_max` | int | ≥ 0 | worst-case seam crossings inside one cycle's running window |
| `f_combined` | float, Hz | derived | worst-case seam+hit rate alone |
| `f_headroom` | float, Hz | derived, can be negative | remaining budget for the near-miss ring's own flash component |

**Output range:** `f_combined` is always ≤ `F_GLOBAL_MAX` given Tube Track's own `f_seam` ≤ `SEAM_HZ_MAX` (3 Hz) and Run State's own `RESTART_LOCK` ≥ 0.45 s — `FLASH_BUDGET_EXCEEDED` for seam+hit *alone* should structurally never fire under those two systems' own already-Approved constraints; it stays in the validator as a defensive check in case either constraint is loosened later without re-deriving this.

**Worked examples:**

| `f_seam` (map) | `RESTART_LOCK` | `T_cycle_min` | `n_seam_max` | `f_combined` | `f_headroom` |
|---|---|---|---|---|---|
| 2.0833 Hz (default, L=12) | 0.5 s (default) | 1.156 s | 1 | 1.730 Hz | **1.270 Hz** |
| 2.0833 Hz | 0.45 s (LOCK_MIN) | 1.106 s | 1 | 1.808 Hz | 1.192 Hz |
| 2.0833 Hz | 0.60 s (LOCK_MAX) | 1.256 s | 1 | 1.592 Hz | 1.408 Hz |
| 2.778 Hz (L=9, tightest legal seam under `SEAM_HZ_MAX`) | 0.5 s | 1.156 s | 2 | 2.595 Hz | 0.405 Hz |
| 3.0 Hz (theoretical cap) | 0.45 s (worst legal combo) | 1.106 s | 2 | 2.712 Hz | 0.288 Hz |

At default tuning, `f_headroom` ≈ 1.27 Hz — a bit more generous than Tube Track's own rough estimate in its Open Question 18 ("~0.9 per second"), which used a naive per-second framing rather than this cycle-based one. The last two rows show the real risk: a denser (but still individually legal) seam pattern combined with the fastest legal restart lock leaves as little as ~0.29-0.41 Hz for near-miss flashes — never negative at any legal combination, but map-dependent, which is why this is computed at load time from Tube Track's actual `f_seam`, not hardcoded to the default.

**Validator rule** (composition-root preflight, after Tube Track's own `validate()` and Run State's own config validation both succeed): `JuiceConfig.validate_flash_budget(f_seam, restart_lock, log_sink)` computes `f_combined` above. If `f_combined > F_GLOBAL_MAX`, reject with `FLASH_BUDGET_EXCEEDED`, naming `f_seam`, `restart_lock`, and the computed `f_combined` — the pre-committed failure response is to lower `SEAM_HZ_MAX` for that map (never to raise `F_GLOBAL_MAX`, a WCAG constant, not a tuning knob). Otherwise it publishes `f_headroom` for F2.

**Hitstop validator** (composition-root preflight, alongside the one above): `JuiceConfig.validate_hitstop(hitstop_actual, hitstop_max, log_sink)` rejects with `HITSTOP_EXCEEDS_MAX`, naming both values, if `hitstop_actual > hitstop_max` (Run State's own `HITSTOP_MAX` = 0.20 s, F4) — formalizing the invariant Core Rule 3 and the Tuning Knobs table already state in prose, matching this Formula's own validator pattern rather than leaving it unchecked. Equality (`hitstop_actual == hitstop_max`) is legal — the shipped default of 0.20 s sits exactly at the boundary by design (Core Rule 3: "exactly matching Run State's own `HITSTOP_MAX` derivation constant").

**F2. Near-miss ring flash throttle**

Near-Miss Detection's own Core Rules 5/6 (one report per hazard, on exit) plus Obstacle System's enforced density floor `S_MIN_SPACING = T_REACT * v_max` (Obstacle System, `TOO_DENSE`) bound the worst-case near-miss rate at `1 / T_REACT` — `v_max` cancels, since `S_MIN_SPACING` scales with it:

```
f_nearmiss_theoretical_max = 1 / T_REACT = 1 / 0.25 = 4.0 Hz
```

4 Hz alone exceeds the entire 3 Hz global cap, independent of anything seam or hit contribute (F1) — so the near-miss ring pulse's own flash is treated as a WCAG-countable flash (matching how Tube Track already treats its own seam band, rather than assuming an unverified on-screen-area exemption) and is not allowed to fire unconditionally on every `near_miss_detected` at worst-case density. It needs the same kind of runtime rate-limiter Platform Services already uses for haptics (`HAPTIC_MIN_INTERVAL`):

```
NEAR_MISS_FLASH_MIN_INTERVAL = 1 / f_headroom          (f_headroom from F1, computed once at map load)
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `f_nearmiss_theoretical_max` | float, Hz | 4.0 (fixed; `T_REACT` = 0.25 s, Run State's own registry constant) | worst-case near-miss encounter rate, independent of `v_max` |
| `NEAR_MISS_FLASH_MIN_INTERVAL` | float, s | derived from F1's `f_headroom`; ≈0.787 s at defaults, ≈2.47 s at the tightest legal seam+lock combo | minimum time between two near-miss **flash** pops; does not gate the rest of the presentation |

**Output range:** `NEAR_MISS_FLASH_MIN_INTERVAL` is always positive given F1's guarantee that `f_headroom` ≥ 0 under any legal `MapConfig`/`RESTART_LOCK` combination. If a `near_miss_detected` arrives while the ring's own flash is still inside its cooldown, **only the flash pop is affected**: the rim glow (a static cool-white highlight, not itself an on/off luminance step), whoosh, haptic, and FOV punch (F3) still fire on every event, unthrottled — matching Core Rule 2's "the same presentation, every single time" and Player Fantasy's "a tiny triumph, every single time." Only the ring's own brightest instant is held below the WCAG 0.10 luminance-step threshold during the cooldown, rather than skipped outright — the reward is never silently dropped, only its flash contribution is capped.

**Example** (`NEAR_MISS_FLASH_MIN_INTERVAL` ≈ 0.787 s at defaults): two near-misses 0.3 s apart (well inside `DODGE_RECOVERY_S`/`S_MIN_SPACING` packing) both play the full non-flash presentation; only the second one's flash pop is held under the luminance threshold. Two near-misses 1.5 s apart both flash at full intensity.

**F3. Near-miss FOV-punch magnitude (Core Rule 2, Camera F5)**

Camera's `apply_fov_punch(amount, duration)` (Camera F5) takes `amount` as a peak additive FOV offset in degrees, against `CAMERA_FOV` (Camera Tuning Knobs, 75° default). The art bible's "1-2% FOV punch" converts as:

```
amount = FOV_PUNCH_PCT * CAMERA_FOV,   FOV_PUNCH_PCT = 0.015 (fixed, Core Rule 2 bars closeness-scaling)
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `CAMERA_FOV` | float, degrees | 75.0 (Camera Tuning Knobs) | the camera's un-punched field of view |
| `FOV_PUNCH_PCT` | float | 0.015 (fixed) | the midpoint of the art bible's 1-2% band — leans toward readability per Pillar 1 rather than the top of the range |
| `amount` | float, degrees | 1.125 (fixed at defaults) | Camera F5's own `amount` parameter |
| `duration` | float, s | 0.08 (fixed) | reuses the same 60-100 ms window as the rim glow and whoosh (Core Rule 2), rather than inventing a second timing constant |

**Output range:** `amount` = 1.125° at `CAMERA_FOV` = 75°. **Example** (via Camera F5): `fov_offset(0)` = 1.125°; `fov_offset(0.04)` = 0.5625°; `fov_offset(0.08)` = 0°; `fov_offset(0.1)` = 0°.

## Edge Cases

- **Two near-misses arrive in the same tick (different hazards)**: both play their full presentation independently (rim/whoosh/haptic/FOV punch each once per hazard). Formula F2's flash throttle is evaluated once per event in arrival order, so at most one of the two ring flashes may be held under cooldown — never both silently dropped.
- **A second `near_miss_detected` arrives while a near-miss presentation is still playing** (before its 60-100 ms window ends): retriggers a fresh one-shot — rim, whoosh, haptic, and FOV punch all restart — rather than layering or queueing. Mirrors Camera's own "latest call replaces" `apply_fov_punch` precedent (Camera Core Rule 7).
- **A `near_miss_detected` arrives while the hazard-reaction track is in `Hit`** (a hit is already playing — not one just cutting this near-miss, Rule 6): dropped entirely, not queued. States and Transitions defines no `Hit` → `NearMiss` edge, matching Rule 6's own priority in the harder direction.
- **`personal_best_updated` arrives while the hazard-reaction track is `Hit`** (the `run_ended` path, Rule 5): the personal-best presentation plays as designed, layered on the hit.
- **`personal_best_updated` arrives while the hazard-reaction track is `Idle`** (the `run_abandoned` path, Rule 5 — resolved 2026-09-30: this is now a defined, legal path, not a contract violation): no bloom, no sweep, no log for this system — the milestone track stays `Off`. HUD's own banner still shows independently (Rule 4, revised 2026-09-30) — only this system's own celebration is silent.
- **`personal_best_updated` arrives while the hazard-reaction track is `NearMiss`** (a genuine contract violation — Scoring & Personal Best's own Core Rule 6 only ever fires it from a run-ending event, and a run ending that didn't already cut an in-progress near-miss to `Hit` per Rule 6 breaks that contract): logged as one `JUICE_PB_CONTRACT_VIOLATION` error; the personal-best presentation still plays, layered on the `NearMiss` presentation currently showing — the reward is never silently withheld for an upstream bug.
- **`run_reset` arrives mid-presentation** (near-miss or hit): both tracks force to `Idle`/`Off` immediately (Rule 7). Formula F2's flash-rate cooldown timer does **not** reset — it is a continuous wall-clock safety mechanism, not gameplay state, and resetting it on every death would let repeated fast deaths exceed the photosensitivity budget F1/F2 exist to prevent.
- **A new map loads mid-session, changing `f_seam`** (and so F1's `f_headroom` and F2's `NEAR_MISS_FLASH_MIN_INTERVAL`): the new interval applies from that point forward; a cooldown already in progress keeps its original end time, never extended or shortened retroactively.
- **`reduced_motion_enabled` is toggled mid-run**: takes effect on the next presentation only — a hit or near-miss already playing keeps the intensity it started with, never changes mid-flight.
- **`haptics_enabled` is `false`**: this system still calls `haptic(kind)` unconditionally on every trigger — Platform Services silently drops it (`DISABLED` cause, its own Core Rule 6); this system needs no `haptics_enabled` check of its own.
- **A near-miss flash is due to fire (outside its own `NEAR_MISS_FLASH_MIN_INTERVAL` cooldown) while the shared 1-second ledger already holds 3 entries from seam+hit clustering inside a short running window**: the flash pop is held under the luminance threshold anyway — the ledger (Rule 11) is checked in addition to, never instead of, the interval cooldown. Matches `run_reset`'s own edge case above: the ledger is a continuous wall-clock safety mechanism, not gameplay state, and does **not** get cleared by `run_reset` any more than the F2 cooldown timer does.

## Dependencies

**Upstream (Juice & Feedback needs these)**

| System | Type | What it needs | Note |
|--------|------|----------------|------|
| Near-Miss Detection (Designed) | Hard | `near_miss_detected(hazard_id, run_id)` | Triggers Rule 2; no intensity value (Near-Miss Detection Core Rule 7) |
| Run State & Restart (Approved) | Hard | `run_ended(run_id, hazard_id, run_time_ms)`, `run_reset` | Triggers Rules 3 and 7; `HITSTOP_MAX`/`T_READ`/`RESTART_LOCK` bound Rule 3's own timing (Run State F4) |
| Scoring & Personal Best (Designed) | Hard | `personal_best_updated(final_score)` | Triggers Rule 4 when it co-occurs with `run_ended`; suppressed (no presentation) when it co-occurs with `run_abandoned` instead — resolved 2026-09-30, Rule 5 |
| Obstacle System (Approved) | Hard, queried | `hazard_id`, footprint, hazard type of the killer hazard | Read at `run_ended` time to isolate it in the grey-out (Rule 3) |
| Camera (Designed) | Hard, called | `apply_fov_punch(amount, duration)`, `CAMERA_FOV` | Rule 9, Formula F3 — the only camera call this system ever makes |
| Platform Services (Approved) | Hard, called | `haptic(kind)`, `HapticsConfig` schema, `HAPTIC_MIN_INTERVAL`/`HAPTIC_MAX_MS` | Rule 12 — this GDD finalizes the `NEAR_MISS`/`HIT` values on top of Platform Services' own safety rails |
| Settings & Accessibility (Approved) | Hard, queried | `reduced_motion_enabled` | Rule 10 — scales flash/shard intensity only, never hitstop duration or haptic amplitude |
| Tube Track (Approved) | Hard, queried | the surface-anchored effect frame (`P(theta, s, h)`), `f_seam` (Formula F5) | Positions the ring pulse and shard burst (Interactions); `f_seam` feeds Formula F1's own flash-budget derivation |

**Downstream (these need Juice & Feedback)**

| System | Type | What it needs |
|--------|------|-------|
| HUD (Designed) | Soft | May read Juice's own presentation state to avoid overlapping its own animations — still provisional (`hud.md`'s own Open Question 6 defers exact layout/transition timing to `/ux-design`). Revised 2026-09-30: this is now the only HUD relationship this system has — the personal-best banner is no longer signaled from here (`hud.md` Core Rule 3 reads it directly from Scoring & Personal Best instead). |

**Bidirectional consistency (checked against the existing GDDs)**
- **Near-Miss Detection:** already lists Juice & Feedback as a Hard dependent for `near_miss_detected` — consistent. Its own Dependencies/Provisional-assumptions/AC-26/Open-Question-1 no-longer-provisional edits have been applied (this session).
- **Run State & Restart:** already lists Juice & Feedback as a Hard dependent for `run_ended`/`run_reset`/`restart_unlocked` — consistent. Its own F4 Interactions note ("reduced juice shortens the hitstop") and Open Question 15's bundled item have been resolved to "no" and applied.
- **Scoring & Personal Best:** already lists Juice & Feedback as a Soft dependent for `personal_best_updated` — consistent. Its own Dependencies/Provisional-assumptions/Open-Question-5 edits marking this no-longer-provisional have been applied.
- **Obstacle System:** already lists Juice & Feedback (paired with Environment & Theming) as a Soft dependent for `hazard_id`/footprint/type — consistent. The "provisional" wording has been resolved and applied.
- **Camera:** already exposes `apply_fov_punch` specifically for Juice & Feedback (Camera Core Rule 7) — consistent. The `CAMERA_FOV` knob gap this GDD's own Formula F3 exposed has been closed and applied.
- **Platform Services:** already lists Juice & Feedback as the owner of the final haptic values (Core Rule 6) — consistent. `NEAR_MISS`/`HIT` finalization, `UI_TAP`'s scope transfer, and the new `haptics_intensity` field (Open Question 16 resolved) have all been applied.
- **Settings & Accessibility:** upstream of Juice & Feedback (it supplies `reduced_motion_enabled`, queried not pushed); no edit needed there for that relationship. It did gain a new `haptics_intensity` 5th field this session (applied), a consequence of the Platform Services edit above, not of this GDD reading it directly.
- **Tube Track:** already lists Juice & Feedback as a Soft dependent for the surface-anchored effect frame — consistent. Its own Open Question 18 flash-budget deferred item has been resolved and applied.
- **Systems index:** row 11 (Juice & Feedback) lists all 8 dependencies above under the Dependency Map — consistent with this GDD's own upstream table; status update pending (Phase 5).

**Provisional assumptions**: HUD's own consumption is mostly resolved (`hud.md`, 2026-09-29): it does not consume `near_miss_detected` in the MVP (HUD Core Rule 10) and renders the personal-best banner exactly as this GDD specs it (HUD Visual/Audio Requirements). Still open: whether HUD wants to read Juice's own presentation *timing* to avoid overlapping its own score-popup animation — this GDD does not itself send HUD anything either way, so that remains HUD's own eventual `/ux-design` question, not a data contract between the two GDDs.

## Tuning Knobs

| Knob | Default | Safe range | Affects | Too low | Too high |
|------|---------|------------|---------|---------|----------|
| `FOV_PUNCH_PCT` | 0.015 | 0.01-0.02 (art bible's 1-2% band) | Near-miss FOV punch magnitude (Formula F3) | Punch is imperceptible, weakening the "immediately rewarding" feel | Competes with hazard readability (Pillar 1) |
| `NEAR_MISS_WINDOW` | 0.08 s | 0.06-0.10 s (art bible's 60-100 ms band) | Shared duration for the rim glow, whoosh, and FOV-punch ease (Rules 2, Formula F3) | Reads as a flicker rather than a glow | Starts to compete with the next hazard's own read time |
| `HITSTOP_ACTUAL` | 0.20 s | 0.15-0.20 s (art bible's mood state 5 band) | Hit presentation's own world-freeze duration (Rule 3); must stay ≤ Run State's own `HITSTOP_MAX` | Death doesn't register as a distinct beat | Reads as a delayed restart; risks `RESTART_LOCK - hitstop_actual >= T_READ` (Run State F4) if raised above `HITSTOP_MAX` |
| `HIT_FLASH_OPACITY` | 0.30 | 0.10-0.30 (art bible's own hard ceiling — never raised) | Peak opacity of the hit's soft white flash (Rule 3); also the personal-best bloom's own peak opacity, reused rather than a second knob (Visual/Audio Requirements) | Barely visible, weakens "abrupt, exact, clean" | Exceeds the art bible's own photosensitivity ceiling — never legal above 0.30 |
| `REDUCED_MOTION_INTENSITY_SCALE` | 0.5 | 0.1-0.7 | Multiplier on flash opacity, shard-burst intensity, and the personal-best bloom's own intensity when `reduced_motion_enabled` is true (Rule 10) | Reduced motion becomes indistinguishable from off (defeats the setting) | Barely reduces anything, defeating the accessibility intent |
| `SHARD_COUNT` | 12 (guess) | 6-20 | Ball-burst shard count on hit (Rule 3) | Reads as a weak pop | Performance cost (draw calls, Technical Preferences ≤150/frame budget) on a mobile GPU |
| `SHARD_BURST_SPEED` | 8.0 u/s (guess) | 4.0-14.0 | How far shards travel before fading | Shards barely move, weak burst | Shards fly off-screen before the player can register them |

**Fixed constants (not tuning knobs):** `NEAR_MISS_FLASH_MIN_INTERVAL` (Formula F2) — fully derived from `f_headroom` (Formula F1) and Tube Track's own live `f_seam`, never set directly; a designer changes it only indirectly, by changing `SEAM_HZ_MAX`, `RESTART_LOCK`, or the map's own `L`/`n_seams`. `F_GLOBAL_MAX` = 3 Hz (WCAG 2.3.1 / art bible) is a correctness constant, not a tuning knob — never raised.

**Knob interactions**
- `HITSTOP_ACTUAL` must stay ≤ Run State's own `HITSTOP_MAX` (0.20 s) — raising it above that value invalidates Run State's own `LOCK_MIN` derivation (F4) and requires a cross-file re-check, not just a local change.
- `FOV_PUNCH_PCT` and `NEAR_MISS_WINDOW` together determine Formula F3's `amount`/`duration`; changing `CAMERA_FOV` (Camera's own knob) changes `amount` even if neither of this GDD's own knobs move.
- `HIT_FLASH_OPACITY` interacts with Formula F1/F2's own flash-budget accounting only through *rate*, not opacity — this knob's own ceiling (0.30) is independent of `NEAR_MISS_FLASH_MIN_INTERVAL`'s own rate limiting; the two guard different axes of the same photosensitivity risk (how bright vs. how often).
- `SHARD_COUNT`/`SHARD_BURST_SPEED` interact with the mobile performance budget (Technical Preferences: ≤150 draw calls/frame) — both are implementation-level guesses pending a device profiling pass, not derived from any Formula here.

**Sources of truth elsewhere:** `CAMERA_FOV` (Camera); `HITSTOP_MAX`, `T_READ`, `RESTART_LOCK` (Run State & Restart F4); `SEAM_HZ_MAX`, `f_seam` (Tube Track F5); `NEAR_MISS`/`HIT` haptic `duration_ms`/`amplitude`/`priority`, `HAPTIC_MIN_INTERVAL`, `HAPTIC_MAX_MS` (Platform Services — finalized by this GDD, Core Rule 12, but the knobs themselves live in `HapticsConfig`); `reduced_motion_enabled` (Settings & Accessibility).

## Visual/Audio Requirements

**Mood States 4-6 only (art bible §2).** States 1-3 (menu, low speed, high speed) belong to Environment & Theming's own baseline (its Visual/Audio Requirements section); this section owns exactly the three presentations this GDD's Core Rules already lock — near-miss, hit, and personal best — layered on top of that baseline, never replacing it.

### Near-miss presentation (Mood State 4, Core Rule 2)

| Element | Treatment | Color | Timing |
|---|---|---|---|
| Ball rim glow | A thin, bright highlight that follows the ball's own silhouette edge (a rim/fresnel treatment — brightest at grazing angle, fading toward the center of the visible sphere), sitting on top of the ball's own glossy base material, never changing the ball's silhouette or scale (art bible §3a) | Rim White (`#F4F8FF`) core, thinning to a **Lagoon-tinted (`#0E6A82`) outer edge** — *art-director extension, see Lagoon-edge note below* | `NEAR_MISS_WINDOW` = 0.08 s (Tuning Knobs), matching F3's `duration` |
| Tube ring pulse | A ring centered on the ball's own position on the tube surface (via Tube Track's `P(theta,s,h)` frame, Interactions table), expanding radially and fading in brightness/width across the full 0.08 s window, additive-blended over the tube's own capped-chroma material (Mist Sage) so it never darkens or occludes anything under it | Rim White (`#F4F8FF`) core, **Lagoon-tinted (`#0E6A82`) outer edge** — *explicit art bible instruction, §4 "Juice contrast"* | Same 0.08 s window; the ring's own brightest onset frame is the "flash" component throttled by Formula F2 (`NEAR_MISS_FLASH_MIN_INTERVAL`) — the expand/fade motion itself is not a flash and is never throttled |
| FOV punch | Camera-only, no color | — | `amount` = 1.125°, `duration` = 0.08 s (Formula F3, fixed) |
| Haptic | `NEAR_MISS` kind, unchanged from Platform Services' provisional default | — | 30 ms / amplitude 0.5 / priority 1 (Core Rule 12) |

**Hard constraint on the ring pulse:** it must never geometrically extend onto a hazard's own silhouette or footprint. If the ball's near-miss position places the expanding ring within a hazard's screen area, the ring is clipped/culled from that hazard's own footprint before render — this is Section 1's own Principle 3 test ("when a near-miss effect overlaps a hazard in color or screen area, choose the effect that uses the cool/white channel and stays off the hazard") applied concretely.

**No intensity scaling by closeness** (Core Rule 2) — every element above plays at the identical values on every `near_miss_detected`, regardless of how close the dodge was.

### Hit presentation (Mood State 5, Core Rule 3)

| Element | Treatment | Color | Timing |
|---|---|---|---|
| Hitstop | World freeze, ball included | — | `HITSTOP_ACTUAL` = 0.20 s (fixed, Tuning Knobs) |
| Grey-out | Chroma multiplied toward 0 (full desaturation) on every world element — tube (Mist Sage), sky (Haze Top/Haze Low), ball (Slate Cobalt), pickups/boosters (Lagoon), props — **luminance preserved**, so silhouettes and shapes stay exactly as readable as before the hit; reuses the same axis-separated treatment (chroma multiplied, luminance untouched) Environment & Theming already established for its own high-speed chroma shift, rather than introducing a second desaturation algorithm | The killer hazard (looked up via `hazard_id` from Obstacle System, Core Rule 3) is **exempt from the multiply** — Signal Red face (`#A0101A`) and Ember shade (`#5C0A12`) stay at full chroma and full contrast, the one thing left legible | Applies as the hitstop begins; a quick crossfade (~1-2 frames), not an instant cut, so the transition itself doesn't register as an additional WCAG luminance step |
| Soft white flash | Full-screen overlay — has no "edge" to spec since it covers the whole frame, not a shape read against a variable background (see Lagoon-edge note) | Rim White (`#F4F8FF`), peak opacity `HIT_FLASH_OPACITY` = 0.30 (the art bible's own hard ceiling) | ≤ 2 frames, timed at hitstop onset — the frozen, brightest instant of the "impact" beat |
| Ball burst | The ball's silhouette explodes into `SHARD_COUNT` = 12 (guess) irregular, faceted polygon fragments, each a fraction of the ball's own diameter `D`. **Silhouette: rounded-off corners, not spike-sharp** — hazards alone own hard, unfilleted angles (art bible §3, "Round is yours, angular is danger"); a shard silhouette that reads as spike-like would visually rhyme with a hazard at exactly the moment juice must read as feedback, not danger. Material retains a fraction of the ball's own glossy specular response (shards read as "pieces of the ball"), but the burst shifts hue *into* the juice register rather than staying Slate Cobalt, matching Core Rule 3's own text ("bursts into cool-white shards") | Rim White (`#F4F8FF`) core, **Lagoon-tinted (`#0E6A82`) outer edge** — *art-director extension, see Lagoon-edge note* | Travels outward at `SHARD_BURST_SPEED` = 8.0 u/s (guess), beginning as hitstop ends and releasing into the restart-lock window |
| Haptic | `HIT` kind | — | 80 ms / amplitude 1.0 / priority 2 (Core Rule 12) |

**Sequencing within the 0.20 s hitstop** (an art-director recommendation for beat order, not a frame-exact spec): grey-out crossfades in as the freeze begins; the white flash pops within that same frozen beat, reading as the moment of impact; the ball's shard burst begins releasing as hitstop ends, carrying the "sting, then let go" read (Player Fantasy) into the restart-lock window rather than inside the freeze itself — a freeze-then-release cadence matching Mood State 5's own descriptors "Abrupt, exact, clean" and "Spike, then reset."

**Reduced motion (`reduced_motion_enabled`, Core Rule 10):** scales the hit flash's peak opacity, the shard burst's intensity, **and the personal-best bloom/sweep's intensity** (extended, see Personal-best presentation below) by `REDUCED_MOTION_INTENSITY_SCALE` = 0.5 — the grey-out and hitstop duration are untouched.

### Personal-best presentation (Mood State 6, Core Rule 4)

| Element | Treatment | Color | Timing |
|---|---|---|---|
| Value lift | Signaled to HUD only; this system does not render it (Rule 4, Interactions table) | — | — |
| Cool bloom | A capped, soft glow layered over the existing hit presentation — **never gold**, confirmed against both the art bible's Mood State 6 row ("no gold") and its "Rules resolved from conflicts" ("No red hit flash and no gold or multi-hue confetti... break the reserved warm family and the loudness budget"). Peak opacity reuses `HIT_FLASH_OPACITY` = 0.30 (Tuning Knobs) rather than a second photosensitivity ceiling — the bloom always co-occurs with the hit flash (Rule 5), so sharing a ceiling is consistent, not coincidental. Scaled by `REDUCED_MOTION_INTENSITY_SCALE` under reduced motion (Core Rule 10, extended above) | Lagoon (`#0E6A82`) / Rim White (`#F4F8FF`) family only | Eases in/out (no hard on/off step) so it is not itself a second WCAG-countable flash stacked on the hit's own flash |
| Tube ring sweep | A ring that travels down the tube's own length (along Tube Track's `s`-axis), rather than radiating outward from a point like the near-miss ring — a deliberately different motion signature so the two "ring" cues are never confusable, since color alone doesn't distinguish them (both are Rim White/Lagoon) | Rim White (`#F4F8FF`) core, **Lagoon-tinted (`#0E6A82`) outer edge** — *explicit art bible instruction* | Non-blocking; must complete without delaying or gating the restart (Rule 4) |
| Haptic | None dedicated — the co-occurring `HIT` haptic is the only cue (Rule 4) | — | — |

**The banner itself is no longer specified here** (revised 2026-09-30): it is HUD's own independently-triggered element, reading `personal_best_updated` directly from Scoring & Personal Best rather than a signal from this system (Rule 4). Its visual treatment lives in `hud.md`'s own Visual/Audio Requirements, not here.

### The Lagoon-outer-edge finding, and where it does and doesn't apply

Art bible §4, "Juice contrast" (decided 2026-09-19): "White juice against the tube is only about 1.83:1 and against the sky 1.1-1.4:1, so it can vanish in glare. Rings get a Lagoon-tinted outer edge around the white core to separate them from tube and sky, without touching hazard contrast. Still requires a real-device test."

The bible's literal scope is "Rings" — the near-miss tube ring pulse and the PB ring sweep are directly covered. Two further treatments extend the same principle by analogy, flagged explicitly rather than folded in silently:

- **Ball rim glow (near-miss):** extended — the same "white juice against a variable backdrop" failure mode, even though it sits on the ball's own silhouette rather than floating independently. Lower risk than the ring, but the same fix is cheap and keeps the whole near-miss presentation visually consistent.
- **Shard burst:** extended — shards are discrete Rim White fragments traveling through the same tube/sky backdrop.
- **Hit flash: does not need it.** It is a full-screen overlay, not a shape read against a background — there is no "edge" to tint, and the vanishing-into-glare failure mode doesn't apply to a wash covering the entire frame.

All three extended treatments need the same real-device test the bible itself already flags as outstanding for the literal Rings — this GDD carries that testing gap forward, it does not resolve it.

### Audio

This system owns three audio moments — near-miss, hit, personal best — at the level of a timing/character spec, not a full asset list.

- **Near-miss whoosh.** A light, airy swoosh — pitched/filtered rather than broadband noise, so it reads as a "quiet world" texture and doesn't compete with the hit sting's own character. Duration matches `NEAR_MISS_WINDOW` = 0.08 s, starting exactly at rim-glow onset. Same fixed presentation every time (Core Rule 2) — no pitch/volume scaling by closeness.
- **Hit sting.** A single sharp, dry transient — abrupt, exact, clean (Mood State 5's own descriptors) — not layered or reverberant, and never a comedic "fail" jingle or pitch-shifted mockery cue (Player Fantasy: "never a punishment... sting, then let go"). Onset lands at hitstop start, synced with the white flash's own pop. Total decay kept short enough (recommend ≤300-400 ms) that it resolves before or just after the hitstop ends, so it never bleeds audibly into the restart-lock window as a lingering "you failed" tail.
- **Personal-best sting.** A short, clean, ascending cue — "clean, ascending, clear" (Mood State 6's own descriptors) — layered on top of the hit sting (never replacing it, since Rule 5 guarantees they always co-occur) and mixed to sit above it without masking it. Kept to a single short rising gesture (one or two notes, not a multi-note arpeggio or fanfare): Rule 8 already requires the *visual* hit presentation to tolerate an early restart-tap cut cleanly, and the same tolerance applies to this cue. Never delays the restart (Rule 4).

### Performance note — shard burst and ring pulse against the mobile draw-call budget

Both effects fit comfortably inside the ≤150 draw calls/frame and 512 MB budget (Technical Preferences), **provided each is implemented as a single batched draw call, not per-fragment/per-instance nodes**:

- **Shard burst (`SHARD_COUNT` = 12):** realistic as-is. Recommend a single particle system (e.g. `GPUParticles3D` with one mesh + one material) rather than 12 individual `MeshInstance3D` nodes — a particle system's per-particle count doesn't add draw calls. Only one hit presentation ever plays at a time (Rule 6, States and Transitions — the hazard-reaction track is mutually exclusive), so there's no concurrency multiplier to budget for. Recommend visual-only particles with no per-shard physics/collision simulation.
- **Ring pulse (near-miss and PB sweep):** recommend implementing as a shader term on the tube's own existing material (a decal-like effect) rather than a separate mesh, adding zero additional draw calls. If a separate mesh is used instead, a single quad or torus is still one draw call.

Net verdict: `SHARD_COUNT` = 12 and the batching approach above are realistic for the stated mobile budget; the "guess" tag on `SHARD_COUNT`/`SHARD_BURST_SPEED` is about the *feel* needing a device profiling/playtest pass, not a performance risk.

## UI Requirements

No player-facing UI of its own. **Revised 2026-09-30**: Juice & Feedback no longer signals HUD for the personal-best banner moment — HUD reads `personal_best_updated` directly from Scoring & Personal Best instead (Core Rule 4; `hud.md` Core Rule 3) and owns the actual banner widget entirely. No UX Flag: unlike Settings & Accessibility, this system's own values aren't the content of a future screen; they're presentation effects with no menu/HUD surface of their own.

## Acceptance Criteria

**Targets:** **[M]** `JuiceMath` static pure functions (F1's flash-budget derivation — `flash_budget(f_seam, restart_lock, t_restart, s_first, v_max, f_global_max)` → `t_cycle_min, n_seam_max, f_combined, f_headroom`; F2's `near_miss_flash_min_interval(f_headroom)` and the shared-ledger check `ledger_allows_flash(timestamps, now, window=1.0, max_count=3)`; F3's `fov_punch_amount(fov_punch_pct, camera_fov)`). **[C]** `JuiceCore`, a `RefCounted` with injected read-only test doubles for all 8 upstream dependencies (Near-Miss Detection, Run State & Restart, Scoring & Personal Best, Obstacle System, Camera, Platform Services, Settings & Accessibility, Tube Track) and a `log_sink` (mirrors `BallCore`/`CameraCore`), holding the hazard-reaction track, the milestone track, the F2 cooldown timer, and the shared flash ledger. **[K]** `JuiceConfig.validated(log_sink)` (clamps Tuning Knobs) plus two preflight validators: `validate_flash_budget(f_seam, restart_lock, log_sink)` (F1, `FLASH_BUDGET_EXCEEDED`) and `validate_hitstop(hitstop_actual, hitstop_max, log_sink)` (`HITSTOP_EXCEEDS_MAX`). **[L]** CI lint, no engine coupling plus a Rule 9/13 side-effect allowlist check. **[I]** integration, deferred until named owner+date, one row per upstream dependency. **[V]** device/playtest evidence in `production/qa/evidence/juice-feedback/`. Tests live in `tests/unit/juice_feedback/`, named `juice_[feature]_test.gd`.

**Fixture:** `make_juice_fixture()` returns Tuning Knobs defaults (`FOV_PUNCH_PCT` 0.015, `NEAR_MISS_WINDOW` 0.08, `HITSTOP_ACTUAL` 0.20, `HIT_FLASH_OPACITY` 0.30, `REDUCED_MOTION_INTENSITY_SCALE` 0.5, `SHARD_COUNT` 12, `SHARD_BURST_SPEED` 8.0). Test doubles supply `CAMERA_FOV` 75.0 (Camera), `f_seam` 2.083333 Hz (Tube Track F5 default, `L`=12, `n_seams`=1, `v_max`=25), `RESTART_LOCK` 0.5 s / `T_restart` 0.216 s (Run State F2/F4), `s_first` 11, `v_max` 25 (Ball Movement/Pattern & Difficulty), `HITSTOP_MAX` 0.20 s (Run State F4), `F_GLOBAL_MAX` 3.0 Hz, and the finalized haptic schema (`NEAR_MISS` 30 ms/0.5/priority 1, `HIT` 80 ms/1.0/priority 2, Core Rule 12). `make_core(cfg)` and `make_sink()` are companions. Exact `==` for log codes, event/call counts, and haptic parameters; 1e-6 tolerance on floats otherwise, stated per-AC where looser.

**Logic, BLOCKING**
- **AC-1 [M]** (F1) Table reproduction at the fixture's defaults: `T_dead` 0.716, `T_run_min` 0.44, `T_cycle_min` 1.156, `n_seam_max` 1, `f_combined` 1.730104, `f_headroom` 1.269896. Second row, tightest legal map (`f_seam` 2.777778, `L`=9, `RESTART_LOCK` 0.5): `n_seam_max` 2, `f_combined` 2.595156, `f_headroom` 0.404844. Third row (`f_seam` 3.0, `RESTART_LOCK` 0.45): `T_cycle_min` 1.106, `n_seam_max` 2, `f_combined` 2.712477, `f_headroom` 0.287523.
- **AC-2 [M]** (F1, output range) Swept table over `f_seam` in [1.0, 3.0] Hz and `RESTART_LOCK` in [0.45, 0.60] s: `f_combined <= F_GLOBAL_MAX` always holds given `f_seam <= SEAM_HZ_MAX` (3 Hz) and `RESTART_LOCK >= 0.45` s — the validator (AC-3) never actually rejects at any point in this legal grid, confirming the GDD's own "should structurally never fire" claim; it remains a defensive check, not dead code, since AC-3 also exercises an illegal input.
- **AC-3 [K]** (F1, validator) `validate_flash_budget`: fixture defaults load clean, zero `FLASH_BUDGET_EXCEEDED`, publishing `f_headroom` = 1.269896. An injected illegal pair (`f_seam` 3.0, `RESTART_LOCK` 0.40 — below `LOCK_MIN`, constructed only to force `f_combined > 3.0`) is rejected with exactly one `FLASH_BUDGET_EXCEEDED`, naming `f_seam`, `restart_lock`, and the computed `f_combined`.
- **AC-4 [M]** (F2, corrected) `near_miss_flash_min_interval(f_headroom)`: 1.269896 → 0.787466 s (defaults); 0.404844 → 2.470085 s (tightest legal map); 0.287523 → 3.478002 s (row 3). A mutation reproducing an earlier draft's incorrect "≈1.08 s" figure at defaults must fail this AC.
- **AC-5 [C]** (F2, runtime throttle) At the corrected default interval (0.787466 s): two `near_miss_detected` events 0.3 s apart — both fire rim/whoosh/haptic/FOV-punch at full value; only the second's ring-flash pop is held under the luminance threshold. Two events 1.5 s apart — both ring-flashes fire at full intensity. Non-flash elements are asserted unthrottled in both cases (mutation: an implementation that also throttles the rim glow, whoosh, or FOV punch must fail this AC).
- **AC-6 [M/C]** (Rule 11, shared ledger) Ledger seeded with 3 timestamps at t=0.0, t=0.05, t=0.10 (reproducing the tightest-legal-map cluster: 2 seam + 1 hit inside a 0.44 s running window). A `near_miss_detected` arrives at t=0.5 — past its own `NEAR_MISS_FLASH_MIN_INTERVAL` cooldown — but the trailing-1.0s window `[-0.5, 0.5]` still contains all 3 prior timestamps: the flash pop is held under threshold; rim/whoosh/haptic/FOV-punch still fire. At t=1.11 (window `[0.11, 1.11]` now empty of the seeded timestamps) with the interval cooldown also elapsed, the next near-miss flash fires at full intensity. **Mutation:** an implementation that checks only `NEAR_MISS_FLASH_MIN_INTERVAL` and ignores the ledger must fail this AC (it would fire the t=0.5 flash at full intensity, producing a 4th flash inside 1 second).
- **AC-7 [M]** (F3) `fov_punch_amount(0.015, 75.0)` = 1.125°, `duration` = `NEAR_MISS_WINDOW` = 0.08 s exactly. Companion ease check via Camera's own F5 (test double): `fov_offset(0)` = 1.125°, `fov_offset(0.04)` = 0.5625°, `fov_offset(0.08)` = 0°.
- **AC-8 [K]** (Core Rule 3, hitstop validator) `validate_hitstop(hitstop_actual, hitstop_max, log_sink)`: (0.20, 0.20) loads clean, no log (boundary equality is legal, Core Rule 3's own "exactly matching" language); (0.15, 0.20) loads clean; (0.200001, 0.20) rejected with exactly one `HITSTOP_EXCEEDS_MAX`, naming both values.
- **AC-9 [C]** (Core Rule 10, scope) With `reduced_motion_enabled` = true: hit-flash peak opacity, shard-burst intensity, and PB-bloom intensity are each multiplied by `REDUCED_MOTION_INTENSITY_SCALE` (0.5). In the same scenario, `hitstop_actual` stays exactly 0.20 s (bit-identical to the `reduced_motion_enabled` = false case) and both haptic calls (`NEAR_MISS` amplitude 0.5, `HIT` amplitude 1.0) are bit-identical to the false case. **Mutation:** any implementation that scales hitstop duration or either haptic amplitude under `reduced_motion_enabled` must fail this AC.
- **AC-10 [C]** (States and Transitions, hazard-reaction track) `Idle` –[`near_miss_detected`]→ `NearMiss` –[0.08 s elapses]→ `Idle`; `Idle` –[`run_ended`]→ `Hit` –[presentation completes]→ `Idle`. Table-driven over both entry paths.
- **AC-11 [C]** (Core Rule 6) `NearMiss` entered at t=0, `run_ended` (different `hazard_id`) arrives at t=0.03 (mid-window): immediate transition to `Hit` — rim, whoosh, near-miss haptic, and FOV-punch ease all stop; the hit presentation's own timeline starts fresh at t=0. A companion case with the **same** `hazard_id` on the cutting hit is asserted out of scope for this AC (Near-Miss Detection's own Core Rule 4 already prevents that combination upstream).
- **AC-12 [C]** (States and Transitions, milestone track + Rule 5) `personal_best_updated` arriving while the hazard-reaction track is `Hit` (the `run_ended` path): milestone track goes `Off` → `PersonalBestOverlay`, and returns to `Off` on its own completion independent of whether the hazard-reaction track has already returned to `Idle` (both orderings tested). A companion case with the hazard-reaction track already `Idle` (the `run_abandoned` path): the milestone track stays `Off` — no transition, no bloom/sweep call, no log line — confirming the suppression (Rule 5) is silent, not merely unpresented. (Revised 2026-09-30: HUD's own banner independently fires in this same scenario — that is `hud.md`'s own AC to assert, since this system no longer signals it, Rule 4.)
- **AC-13 [C]** (Edge Cases, `JUICE_PB_CONTRACT_VIOLATION`) `personal_best_updated` arrives while the hazard-reaction track is `NearMiss`: exactly one `JUICE_PB_CONTRACT_VIOLATION` logged; the PB presentation still plays, layered on the `NearMiss` presentation currently showing. A mutation that logs this violation for the now-legal `Idle` case (AC-12's companion), or that fails to log it for the actual `NearMiss` violation case, must fail this AC.
- **AC-14 [C]** (Core Rule 7, global override) From every combination of hazard-reaction ∈ {`Idle`, `NearMiss`, `Hit`} × milestone ∈ {`Off`, `PersonalBestOverlay`}, `run_reset` forces exactly (`Idle`, `Off`) with no intermediate state observable. The F2 cooldown timer and the shared ledger (AC-6) both retain their pre-reset contents — asserted explicitly, since both are wall-clock safety state, not presentation state.
- **AC-15 [C]** (Core Rule 8) `Hit` active at t=0.05 of its 0.20 s hitstop; a restart tap (modeled as `run_reset` arriving mid-presentation, since a real restart ultimately fires it) cuts the presentation: no error logged, hazard-reaction track reaches `Idle` immediately via Rule 7's own unconditional clear (reuses AC-14's mechanism), no dangling grey-out/shard/hitstop state, and the `HIT` haptic already dispatched at trigger time is not retracted (one-shot, nothing to cancel).
- **AC-16 [C]** (Core Rule 12) `near_miss_detected` → exactly one `haptic(NEAR_MISS)` call, `duration_ms` 30, `amplitude` 0.5, `priority` 1. `run_ended` → exactly one `haptic(HIT)` call, `duration_ms` 80, `amplitude` 1.0, `priority` 2. Both dispatched even when the injected Platform Services test double reports `haptics_enabled` = false. **Mutation:** an implementation that gates either call on `haptics_enabled` must fail this AC.
- **AC-17 [C]** (Core Rules 4-5, no dedicated PB haptic) `personal_best_updated` co-occurring with `run_ended`: total `haptic()` call count for that event stays exactly 1 (`HIT` only) — no second call fires for the PB moment.
- **AC-18 [L]** (Core Rules 9, 13) Static scan of `JuiceCore`: the only permitted outbound calls are `Camera.apply_fov_punch`, `PlatformServices.haptic`, and an allowlisted set of rendering/audio stub calls; no call into any method on the Near-Miss Detection, Run State, Scoring, or Obstacle System test doubles beyond the documented inbound reads (`near_miss_detected`, `run_ended`, `run_reset`, `personal_best_updated`, hazard lookup); no call on the Camera test double other than `apply_fov_punch` (no position/rotation/transform setter).
- **AC-19 [C]** (Determinism) Two fresh `JuiceCore` instances fed an identical scripted sequence of events and `dt_eff` steps — including near-misses, hits, a PB, resets, and `reduced_motion_enabled` toggles — are bit-identical after every step (track states, both timers, ledger contents, log codes).
- **AC-20 [L]** (CI architecture lint) Static scan over `JuiceMath`, `JuiceCore`, `JuiceConfig`: none contains `CollisionObject3D`, `Area3D`, `PhysicsServer`, `RayCast3D`, `Input.`, `Engine.`, `Time.`, `OS.`, `DisplayServer.`, `get_tree`, `_process`, `_physics_process`, `randi`, `randf`, `randomize`.
- **AC-21 [K, ADVISORY]** (Config/Data smoke) The shipped `JuiceConfig.tres` equals the Tuning Knobs table defaults and validates with zero `KNOB_CLAMPED`, `FLASH_BUDGET_EXCEEDED`, or `HITSTOP_EXCEEDS_MAX` against the shipped Tube Track/Run State map defaults.

**Integration [I], deferred** — each row not BLOCKING today per this project's own precedent (Camera AC-19; Ball Movement AC-29/AC-31): no AC may be BLOCKING for a milestone while its driver has no named owner or no date.
- **AC-22 [I], deferred** — Near-Miss Detection: real `near_miss_detected` events from `NearMissCore` drive `JuiceCore`'s `NearMiss` presentation with correct timing and the corrected F2 throttle (AC-4/AC-5).
- **AC-23 [I], deferred** — Run State & Restart: real `run_ended`/`run_reset` wired; `hitstop_actual` injected back into Run State's config by the composition root (Rule 3) with no double-injection or stale value across map reloads.
- **AC-24 [I], deferred** — Scoring & Personal Best: real `personal_best_updated` co-occurrence with `run_ended` verified against `ScoringCore`, including the `JUICE_PB_CONTRACT_VIOLATION` path (AC-13) if the contract is ever actually violated upstream.
- **AC-25 [I], deferred** — Obstacle System: real `hazard_id`/footprint/type lookup at `run_ended` time, confirming the grey-out isolates the correct hazard.
- **AC-26 [I], deferred** — Camera: `apply_fov_punch(amount, duration)` reaches a real `CameraCore` and produces the F5 ease Camera's own GDD defines.
- **AC-27 [I], deferred** — Platform Services: `haptic(kind)` calls pass through Platform Services' own `HAPTIC_MIN_INTERVAL`/`HAPTIC_MAX_MS` gate and priority queue correctly — `HIT` never dropped in favor of a concurrent `NEAR_MISS`.
- **AC-28 [I], deferred** — Settings & Accessibility: `reduced_motion_enabled` read from a real settings store scales flash/shard/bloom intensity on the *next* presentation only, never mid-flight.
- **AC-29 [I], deferred** — Tube Track: the surface-anchored effect frame `P(theta,s,h)` and live `f_seam` correctly position ring/shard effects and feed F1's validator (AC-3) at real map load, including the shared ledger's own seam-timestamp derivation from Tube Track's real `s`/`L`/`n_seams` (AC-6) — no new Tube Track interface required.

**Device and playtest**
- **JUI-1 [V, ADVISORY]** (Core Rule 11) The ≤3-flashes/sec cap validated on a real device across a representative session including the AC-6 adversarial clustering scenario under real frame-timing jitter, not just idealized fixed-dt math. Screenshot/video + lead sign-off in `production/qa/evidence/juice-feedback/`. **Classified ADVISORY, not BLOCKING**: subjective/device-dependent (Testing Standards' Visual/Feel row); `production/qa/designated-gates.md` carries no entry for Juice & Feedback, and the two-limb escalation exception (`coding-standards.md`) requires a creative-director designation plus producer ratification, neither of which exists here.
- **JUI-2 [V, ADVISORY]** (Visual/Audio Requirements, Lagoon-outer-edge finding) The Lagoon-tinted (`#0E6A82`) outer edge on the ring pulse, ball rim glow, shard burst, and PB ring sweep validated for contrast against the tube (Mist Sage) and sky (Haze Top/Haze Low) backdrops on a real device — the art bible's own "still requires a real-device test" note. Screenshot + lead sign-off in `production/qa/evidence/juice-feedback/`.
- **JUI-3 [V, ADVISORY]** (Formula F1, real-device validation the art bible flagged as outstanding) `f_headroom` and the shared ledger (AC-6) hold to ≤3 flashes/sec under real device frame-pacing variance, not just the fixed-`dt` idealized math AC-1/AC-2/AC-6 exercise. Screenshot/video + lead sign-off in `production/qa/evidence/juice-feedback/`.

**Gate policy.** AC-1 through AC-20 are Logic, BLOCKING (Formulas F1-F3, Core Rules 1-13, States and Transitions). AC-21 is Config/Data, ADVISORY. AC-22 through AC-29 are Integration — BLOCKING once each dependency's own driver/ADR has a named owner *and* a date (currently neither for any of the 8), tracked as open gaps, not present blockers. JUI-1 through JUI-3 are Visual/Feel, ADVISORY by default; none may become BLOCKING without a fresh `/design-review` pass carrying an explicit creative-director designation and producer ratification recorded in `production/qa/designated-gates.md` (coding-standards.md's escalation exception) — not assumed here.

## Open Questions

| # | Question | Owner | Resolve when |
|---|----------|-------|--------------|
| 1 | Whether the near-miss ring pulse truly needs full WCAG-flash treatment (Formula F2's own throttle) or is exempt by on-screen area — currently resolved conservatively as "treat it as a flash" (Visual/Audio Requirements), matching how Tube Track already treats its own seam band, pending a real on-screen-area measurement that could relax it | art-director, accessibility-specialist | Vertical slice, on a real device |
| 2 | `SHARD_COUNT` and `SHARD_BURST_SPEED` are guesses (Tuning Knobs) pending a device profiling and playtest pass — the batching approach itself is confirmed realistic for the mobile draw-call budget (Visual/Audio Requirements), but the exact feel is not | user, technical-artist | Vertical slice |
| 3 | **Partially RESOLVED 2026-09-29**: HUD's own GDD now exists and specs the banner's own visual treatment (`hud.md` Visual/Audio Requirements). Still open: whether HUD wants to read Juice's own presentation *timing* to avoid a score-popup overlapping a near-miss ring or hit flash — deferred to `/ux-design` (`hud.md` Open Question 6) | ux-designer | `/ux-design`, Pre-Production |
| 4 | JUI-1/JUI-2/JUI-3's own real-device validation (the ≤3-flashes/sec cap under real frame-pacing jitter, the Lagoon-edge contrast against the tube/sky, F1's own real-device confirmation) — all currently only exercised against idealized fixed-`dt` math | user, qa-lead | Vertical slice, on a real device |
| 5 | RESOLVED 2026-09-29 (`menus-screen-flow.md` Core Rule 7): `UI_TAP`'s final home is Menus & Screen Flow, values unchanged from Platform Services' own provisional defaults; `HIT` > `NEAR_MISS` > `UI_TAP` (priority 0, the lowest) holds, unaffected | — | Resolved |
