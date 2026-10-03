# ADR-0015: Audio policy (three cues, bus layout, OS audio policy owner)

## Status

Proposed

## Date

2026-10-03

## Last Verified

2026-10-03

## Decision Makers

Project owner (delegated the decision to the assistant, 2026-10-03); technical-director review requested the same day

## Summary

The MVP has exactly three audio moments, all owned by Juice & Feedback: the near-miss whoosh, the hit sting and the personal-best sting. This ADR decides that they are one-shot, non-positional `AudioStreamPlayer` nodes created once at construction and played on the same Juice stamp edges as the visuals, routed through one `SFX` bus under `Master` (a `Music` bus is declared and left empty), that there is no in-game volume control in the MVP, and that Platform Services is the owner of the OS audio policy (the game does not request exclusive audio focus). Latency and Android behaviour are carried as two device spikes.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Audio |
| **Knowledge Risk** | MEDIUM for the project: `AudioStreamPlayer`, `AudioServer` buses and `AudioStreamWAV` are old, stable APIs (4.0 to 4.3); Android audio focus, output latency and the sample-rate path on 4.7.2 are not covered by the engine reference |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`; `design/gdd/juice-feedback.md` (Audio, Rules 4, 8), `design/gdd/platform-services.md` (Open Question 20), `design/accessibility-requirements.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | **NEEDS VERIFICATION (device):** AU-1 audio behaviour on Android: whether Godot requests audio focus by default and what happens to the player's own music, what a headphone or Bluetooth disconnect does mid-run, what a call or `FOCUS_OUT` does to a playing sting, the device mix rate; AU-2 trigger-to-sound latency of a `play()` call on two makers (the budget is below) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (no autoloads, no view `_process`, injected callables), ADR-0006 (Platform Services owns every OS call), ADR-0010 (stamps and edges), ADR-0009 (lint harness) |
| **Enables** | The Juice audio stories; the audio asset specs (`/asset-spec`) |
| **Blocks** | Juice audio stories only; no other ADR depends on this one |
| **Ordering Note** | Written after ADR-0002 to ADR-0014 were Accepted. It resolves Platform Services Open Question 20 and `design/accessibility-requirements.md` Open Question 2 (volume controls) |

## Context

### Problem Statement

Three GDDs name audio but none decides how it is played. Juice specifies three cues at the level of character and timing ("not a full asset list"). Platform Services leaves the owner of the OS audio policy open (Open Question 20: the player's own music, headphone or Bluetooth disconnect, Android audio focus). The accessibility requirements record "volume controls: not specified (no audio ADR yet)". Without a decision, each Juice story would invent its own node type, bus names and interruption behaviour.

### Constraints

- Presentation never gates gameplay (architecture principle 5): a missing, slow or failing sound must not delay or alter any game state.
- No autoloads, no view `_process`, no `Engine.time_scale`, no `SceneTree.paused` (ADR-0002); presentation time follows ADR-0010 (stamp from `clock_us`, derive elapsed seconds).
- Positioned nodes need a `rebase()` hook after ADR-0013 (a node whose position depends on `s`); a non-positional sound has none.
- The Hit presentation tolerates an early restart tap (Juice Rule 8): the hit sting decays within about 300 to 400 ms and must not leave a tail into the restart window.
- Memory ceiling 512 MB; nothing is allocated during a run (ADR-0003 spirit).
- No gameplay-critical information may be audio-only (`design/accessibility-requirements.md`): each cue has a visual and a haptic equivalent.

### Requirements

- Exactly three cues, fixed presentation every time (Juice Rule 2: no pitch or volume scaling by closeness).
- Cue onsets: near-miss at rim-glow onset; hit sting at the Hit tick (hit-stop start), together with the flash; personal-best sting layered on the hit sting, never replacing it.
- One owner for the bus layout and one owner for the OS audio policy.
- Testable without a device: the mapping from edges to cue requests is pure.

## Decision

### 1. Scope: three one-shot cues, no music and no ambience in the MVP

Juice & Feedback owns the three cues. The game concept lists "simple background music" as a moderate audio need; it is **out of scope for the MVP** and is added by its own ADR amendment when wanted. The `Music` bus is declared now (Decision 3) so adding it later changes no layout. Environment & Theming, HUD, Menus and Run State own no audio (their GDDs say so); a UI tap sound, if ever wanted, is a Juice cue added by amendment, because HUD and Menus have no interface to request one.

### 2. Playback: three pre-created, non-positional `AudioStreamPlayer` nodes

- `JuiceAudioView` (a thin `Node`, no `_process`, part of the Juice view; ADR-0002) creates **three `AudioStreamPlayer` nodes at construction**, one per cue, each with its stream assigned once. Nothing is created, freed or loaded during a run. `AudioStreamPlayer3D` is **forbidden**: a positioned node would need a `rebase()` hook (ADR-0013), would add a Doppler path that a 1008 u rebase jump could spike, and a 2D mix is all the design asks for.
- Each cue plays by calling `play()` on its node from a Juice edge consumed in the Juice tick step (ADR-0010 Decision 3 pattern). A second `play()` of the same cue restarts it. Overlap of the hit sting and the personal-best sting is two different nodes, so they layer.
- On `run_reset` (and `run_abandoned`) the hit and personal-best nodes call `stop()`: a restart after the lock never lets a sting tail into the new run (Juice Rule 8).
- Duration is the stream's own length; no timer, Tween or `await` times a sound (ADR-0010 time rule).

### 3. Bus layout

`default_bus_layout.tres` (committed) holds `Master` and two children: `SFX` (the three cues) and `Music` (declared, empty, reserved). Bus names are constants in `AudioBuses` (a constants class, like `UiLayers`); no string literal bus name appears elsewhere. There is **no ducking** (no music in the MVP). The relative loudness of the personal-best sting over the hit sting is the static gain `PB_STING_GAIN_DB` in `JuiceConfig` (data-driven, validated range), not bus automation.

### 4. Edges to cues: a pure core

`JuiceAudioCore` (RefCounted, no engine call) maps Juice's edges to cue requests: `near_miss_started`, `hit_started` (same tick as the Hit flash, `run_ended` rank 1 path) and `personal_best_started`, each to `{cue_id: StringName, gain_db: float}`. `JuiceView` injects an `audio_sink: Callable(cue_id, gain_db)`; the production sink is `JuiceAudioView.play_cue`. Reduced motion, colourblind-safe and every other setting leave audio unchanged. A cue request outside a phase that shows gameplay (for example a stale near-miss edge after a reset) is dropped by the core, like every other Juice edge (`run_id` check, Juice Rule 7).

### 5. Assets and validation

- Format: **16-bit PCM WAV** (`AudioStreamWAV`, no loop) for all three: short transients, no decode cost at play time. Compressed formats are for a future music stream. Total budget for the three cues: 500 KB.
- `JuiceConfig` validates at load (`validated(log_sink)`): each stream non-null; `near_miss` length at most 0.25 s; `hit` at most `HIT_STING_MAX_S` = 0.40 s; `personal_best` at most 1.0 s. A violation logs `AUDIO_CUE_INVALID` with the cue id and **disables that cue** (silent); it never aborts a run or the boot (presentation never gates gameplay).
- Durations come from Juice: near-miss `NEAR_MISS_WINDOW` = 0.08 s character, hit "dry, abrupt, no jingle", personal best one or two rising notes. Sound design is owned by the audio-director and sound-designer; this ADR fixes mechanism, not content.

### 6. OS audio policy owner: Platform Services

Platform Services owns the OS audio policy (resolves Platform Services Open Question 20). MVP policy:

- The game plays its cues on the system media stream at the device volume and **does not request exclusive audio focus**: the player's own music, podcasts and calls are not interrupted by the game, and the cues mix over them. (Whether Godot requests focus by default on Android is unverified; AU-1 decides, and if it does, the export setting or a Platform Services call that opts out is the fix.)
- A headphone or Bluetooth disconnect mid-run is the OS's business: the cues continue on the speaker and the run is not paused for it. A pause on audio route change is **not** added (the run only pauses for `app_interrupted`, `sensor_lost` and the Pause button).
- Backgrounding (`FOCUS_OUT`, ADR-0006) pauses the run; the engine pauses its audio driver with the app (unverified, AU-1). On return no cue replays: a stale edge is dropped by the `run_id` and phase check.
- The only audio value Platform Services passes on is none today; if AU-1 finds a required hook, it becomes a getter on Platform Services, never an `AudioServer` call from Juice.

### 7. Volume controls: none in the MVP

There is no in-game volume or mute setting: Settings & Accessibility owns five settings and none is audio, adding one needs a Settings GDD revision, and the device media volume is the control on a phone. Every cue has a visual and a haptic equivalent, so a muted device loses no information. This is revisited after the first playtest (accessibility requirements Open Question 2 is closed by this decision, and reopens only if a playtester needs it).

### 8. Latency budget

The trigger-to-sound latency of `play()` on Android is unmeasured. Budget: at most **50 ms** from the Juice tick that requests a cue to audible sound on a mid-tier phone (a hit sting later than that desyncs from the white flash). AU-2 measures it on two makers. If it fails, the first response is the engine's `audio/driver/output_latency` project setting; advancing the cue request ahead of the visual is **not** allowed (it would make a sound precede an event the player has not yet seen).

### Architecture Diagram

```text
Juice edges (near_miss_detected, run_ended rank 1, personal_best_updated)
   -> JuiceCore (stamps, run_id and phase checks, ADR-0010)
   -> JuiceAudioCore.request(edge) -> {cue_id, gain_db}        (pure)
   -> audio_sink: Callable -> JuiceAudioView.play_cue()        (thin Node, no _process)
        AudioStreamPlayer x3 (non-positional, pre-created)  ->  bus SFX  ->  Master -> device
        run_reset / run_abandoned -> stop() on hit and PB nodes
   Platform Services: owns OS audio policy (no exclusive focus), lifecycle (ADR-0006)
```

### Key Interfaces

```gdscript
class_name AudioBuses extends RefCounted          # constants only
const MASTER: StringName = &"Master"; const SFX: StringName = &"SFX"; const MUSIC: StringName = &"Music"

class_name JuiceAudioCore extends RefCounted       # pure, unit-testable
func _init(config: JuiceConfig, audio_sink: Callable) -> void
func on_near_miss_started(run_id: int) -> void
func on_hit_started(run_id: int) -> void
func on_personal_best_started(run_id: int) -> void
func on_run_reset(run_id: int) -> void             # drops pending requests

class_name JuiceAudioView extends Node             # no _process
func build(streams: Dictionary, bus: StringName) -> void   # creates the three players once; logs AUDIO_CUE_INVALID
func play_cue(cue_id: StringName, gain_db: float) -> void
func stop_stings() -> void                         # hit and personal-best nodes
```

### Implementation Guidelines

- `JuiceAudioView` is built in the Juice step of the construction order (ADR-0002 Decision 5); `audio_sink` is a typed method reference, not a string-built `Callable`.
- No `AudioServer` write outside `audio_buses.gd` and `JuiceAudioView.build`; no `AudioStreamPlayer.new()` after construction; no `AudioStreamPlayer3D`, no Tween or `await` on a sound.
- The cue streams are loaded by the loader/composition step like every other resource (`ResourceLoader` only in `map_loader.gd` is for maps; cue streams are preloaded constants in the Juice view scene), never by game logic.

## Alternatives Considered

### Alternative 1: `AudioStreamPlayer3D` at the ball or the hazard
- **Pros**: spatial feel.
- **Cons**: needs a `rebase()` hook (ADR-0013), a Doppler path, and positional falloff the design does not ask for.
- **Rejection Reason**: cost and risk with no design requirement; the cues are fixed presentations.

### Alternative 2: One `AudioStreamPlayer` with `AudioStreamPolyphonic`
- **Pros**: one node, built-in polyphony.
- **Cons**: less simple to stop one layer on reset; a newer API with less evidence on 4.7.2 and Android.
- **Rejection Reason**: three plain players are simpler to test and stop individually.

### Alternative 3: An audio manager autoload with a pool
- **Rejection Reason**: ADR-0002 forbids autoloads; three cues need no pool.

### Alternative 4: An in-game volume slider in the MVP
- **Rejection Reason**: needs a Settings GDD revision for a phone game whose device volume is the control and whose cues are all redundant with visuals and haptics; revisit after playtest.

## Consequences

### Positive
- One mechanism, three nodes, no per-cue invention; the edge mapping is pure and unit-testable.
- No interaction with the render origin or the per-frame order.
- A missing or invalid asset degrades to silence, never to a crash or a delayed run.

### Negative
- No music or ambience until an amendment; the concept's "simple background music" waits.
- No player-facing volume control; a player who wants the game quieter uses the device volume.

### Neutral
- The `Music` bus exists and is empty, so adding music later changes no layout.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| `play()` latency on Android exceeds 50 ms and the hit sting desyncs from the flash | Medium | Medium | AU-2 on two makers; `output_latency`; never advance the cue ahead of the visual |
| Godot requests exclusive audio focus and silences the player's own music | Medium | Low | AU-1; opt out through Platform Services if it does |
| Backgrounding leaves a sting playing or replays it on return | Low | Low | `stop_stings()` on reset; the `run_id` and phase check drops stale edges; AU-1 |
| A mixed hit and personal-best layer masks the hit sting | Low | Low | `PB_STING_GAIN_DB` is data; sound-designer tunes against the hit (Juice Audio) |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | 0 | negligible (three `play()` calls per run at most) | 16.6 ms |
| Memory | 0 | at most 500 KB of PCM | 512 MB |
| Draw calls | 0 | 0 | 150 |

## Migration Plan

Greenfield. Create `AudioBuses`, `JuiceAudioCore`, `JuiceAudioView` and `default_bus_layout.tres` with the Juice stories; add `JuiceConfig` audio fields and `AUDIO_CUE_INVALID`; register the lint rules (no `AudioStreamPlayer3D`; `AudioServer` writes and `AudioStreamPlayer.new()` only in the allowed files) in `tools/ci/lint_rules.json` with the first Juice audio story; update `design/accessibility-requirements.md` Open Question 2 and Platform Services Open Question 20 as resolved.

## Validation Criteria

- [ ] Unit (pure): `JuiceAudioCore` maps each edge to its cue and gain; drops a request for a stale `run_id` or outside the gameplay phases; `on_run_reset` clears pending requests; the config validator disables an over-length stream with `AUDIO_CUE_INVALID` and never throws.
- [ ] Integration (headless, fake sink): a Hit sequence requests `hit` at the Hit tick and `personal_best` after it when a personal best is set; a restart calls `stop_stings()`.
- [ ] Lint: no `AudioStreamPlayer3D`; no `AudioStreamPlayer.new()` outside `JuiceAudioView.build`; no `AudioServer` write outside the two allowed files; no string-literal bus name outside `audio_buses.gd`.
- [ ] AU-1 (device, two makers): focus behaviour with the player's own music, headphone and Bluetooth disconnect, call and `FOCUS_OUT`, mix rate; recorded in `production/qa/evidence/`.
- [ ] AU-2 (device, two makers): trigger-to-sound latency at most 50 ms, recorded.

## GDD Requirements Addressed

| GDD | System | Requirement | How this ADR satisfies it |
|-----|--------|-------------|---------------------------|
| `design/gdd/juice-feedback.md` | Juice & Feedback | Audio: near-miss whoosh, hit sting, personal-best sting (TR-juice-feedback-016); Rules 2, 4, 8 | Decisions 1 to 5 |
| `design/gdd/platform-services.md` | Platform Services | Open Question 20: owner of the OS audio policy | Decision 6 |
| `design/accessibility-requirements.md` | Accessibility | Open Question 2: volume controls; no audio-only information | Decision 7; each cue has a visual and haptic equivalent |
| `design/gdd/environment-theming.md`, `hud.md` | Environment, HUD | own no audio | Decision 1 |

## Related

- ADR-0002, ADR-0006, ADR-0009, ADR-0010, ADR-0013
- `docs/architecture/architecture.md` (Required ADRs: "Can defer to implementation")
