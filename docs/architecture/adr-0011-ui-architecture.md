# ADR-0011: UI architecture

## Status

Proposed

## Date

2026-10-03

## Last Verified

2026-10-03

## Decision Makers

The user (project owner), with Claude Code agents.

## Summary

HUD and Menus & Screen Flow are approved as designs and specify their layout in **dp inside a safe area**, but no ADR says how dp becomes viewport units (HUD Open Question 9), which `CanvasLayer` index each overlay uses, how the pure cores and the Control views split, how a hidden or blocked control stops taking taps, how a slider inside a scroll list arbitrates a drag, or what the screen-reader proposals depend on. This ADR decides: **stretch mode `canvas_items` with `Window.content_scale_factor = dpi / 160`**, so layouts are written directly in dp (one viewport unit is one dp); a fixed **layer stack** (5 flash, 10 HUD, 20 Menus, 30 Ink cover, 100 debug); **`XCore` plus a scene-based `XView`** with no `_process`; **`visible` and full-screen STOP blockers** instead of `mouse_behavior_recursive`; a **thumb-only hit area** for sliders; and **AccessKit names set through one helper with no acceptance criterion depending on them** until a device test proves screen-reader support on Android.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | UI |
| **Knowledge Risk** | HIGH: dual focus (4.6), AccessKit (4.5), recursive Control behaviour (4.5) and Android edge-to-edge (4.5) are all post-cutoff; `docs/engine-reference/godot/modules/ui.md` is verified to 4.6 only and its recursive-disable snippet does not name the real property |
| **References Consulted** | `docs/engine-reference/godot/modules/ui.md`, `breaking-changes.md`, `deprecated-apis.md`, `modules/input.md`, ADR-0002, ADR-0003, ADR-0005, ADR-0006, `design/ux/hud.md`, `design/ux/menus-screen-flow.md`, `design/ux/interaction-patterns.md` |
| **Post-Cutoff APIs Used** | AccessKit accessibility properties on `Control` (4.5), only through one helper and with no dependency; **not used:** `mouse_behavior_recursive`, `FoldableContainer`, the dual-focus APIs (every button is `FOCUS_NONE`) |
| **Verification Required** | **NEEDS VERIFICATION (spike UI-1, on device):** (1) `display/window/stretch/mode = canvas_items` with `content_scale_size = (0, 0)` and `content_scale_factor = dpi / 160` gives layouts in dp (one viewport unit per dp) and crisp text on Android; (2) `DisplayServer.screen_get_dpi()` on Android returns the density the OS reports (for example 420) and not a physical xdpi, on at least two makers; (3) changing `content_scale_factor` at run time (after `app_foregrounded` or a size change) re-lays out Controls within one frame and does not disturb the 3D viewport or `scaling_3d`; (4) `Control._has_point()` override decides GUI picking for emulated touch (slider thumb only), and a drag that started on the thumb stays with the slider after it leaves the rect; (5) a `ScrollContainer` scrolls by touch drag on a Control that passes the press; (6) an invisible Control and a full-screen `mouse_filter = STOP` blocker stop taps as assumed, and the Pause and Menu buttons win over the Hit tap catcher by tree order; (7) `StyleBoxFlat` pills with rounded corners cost one draw call each and no shadows (draw-call delta in R-1). Added checks: (2b) log the raw `screen_get_dpi()` next to `displayMetrics.density * 160` and test at the smallest and largest Android Display size settings (the OS may group densities, 420 reported as 480 would make dp about 14% large); (5b) a drag that starts on a stock Button inside the scroll list scrolls it (PASS filter); (8) `emulate_touch_from_mouse` on for editor runs; (9) `ScrollContainer` clips the slider thumb rectangle at the row edge. **Spike UI-A1 (device, criteria written before the run; tiers full, partial, none):** (a) real property names and the `accessibility_support` setting; (b) whether TalkBack announces name, role and state of a `Button`, `CheckButton` and `HSlider`; (c) whether explore-by-touch and double-tap reach `FOCUS_NONE` controls, repeated with `FOCUS_CLICK`; (d) Switch Access and Voice Access; (e) live regions set at run time; (f) a gated control's reason and state; (g) what TalkBack does to touch gestures, the Hit tap catcher and tilt (record the whole game); (h) `ScrollContainer` two-finger scroll and whether `UiSlider` is adjustable with the accessible rectangle covering the full row; (i) frame cost with accessibility on; (j) accessibility node bounds with `content_scale_factor` other than 1. The 4.7 release notes and class reference are read first. `ui.md` and `input.md` are verified to 4.6 only, and `content_scale_factor` and Window stretch semantics are not in the reference. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (views have no `_process`, `tick` order, `_wire()` rows), ADR-0003 (draw-call allocation HUD 20 and Menus 25, Hit flash as a `ColorRect`), ADR-0005 (stock `Button`, `FOCUS_NONE`, tap catcher), ADR-0006 (display facts: safe area, size, re-read points) |
| **Enables** | the HUD and Menus epics, ADR-0010 (the Ink cover lives on layer 30), the accessibility requirements document |
| **Blocks** | HUD epic, Menus & Screen Flow epic (before the first UI story, HUD Open Question 9) |
| **Ordering Note** | ADR-0005 wording (`mouse_behavior_recursive`) and ADR-0006 display facts (`screen_dpi`, scale) need small edits once this is Accepted |

## Context

### Problem Statement

HUD and Menus layouts are in dp (touch targets of at least 48 dp, minimum safe area 360x560 dp), phones range from about 360 to 430 dp wide at densities from 280 to 560 dpi, and the project has no `project.godot` yet. The GDDs leave the conversion, the layer order, the Control and core split, the inert-control rule, the slider and scroll arbitration and the AccessKit scope to an ADR; ADR-0005 already forward-references one of them.

### Constraints

- Portrait only, phones only (ADR-0006); foldables keep the portrait layout centred.
- At most 20 draw calls and 1.0 ms per tick for the HUD in the worst Hit state, 25 and 1.0 ms for Menus (ADR-0003).
- Stock `Button` with `emulate_mouse_from_touch` on; the Hit tap catcher reads `InputEventScreenTouch` (ADR-0005); every `press_us` stamped from `clock_us`.
- No `_process` in views; `GameRoot` calls `tick` (ADR-0002); presentation never gates gameplay.
- Colours are Ink, Rim White and Lagoon only; every element is a pill; OS text scaling is not honoured (HUD, Menus, deliberate).
- Gated controls are dimmed with a reason label and use an own state flag, never `Button.disabled` (Menus).
- A drag starting on a slider thumb moves the slider and any other drag scrolls (Menus Settings).

### Requirements

- One decision for dp conversion, layer order, view and core split, inert controls, slider arbitration and AccessKit scope.
- Testable headless wherever possible (GUT with real Controls).
- No dependence on an unverified engine behaviour for gameplay-critical input.

## Decision

### 1. dp: `canvas_items` stretch with `content_scale_factor`

`project.godot`: `display/window/stretch/mode = "canvas_items"`, `display/window/stretch/scale_mode = "fractional"` (integer snapping would break factors such as 2.625 and 3.5), `content_scale_size` left at `(0, 0)` (with a zero base size the aspect setting has no effect), and `display/window/stretch/scale` set to a typical first-frame value (2.625) so the boot frame is not drawn at 1.0. `UiScaler` (a thin `Node`, no `_process`) sets `get_window().content_scale_factor = f` at construction and on every display-facts re-read (`app_foregrounded`, `app_returned`, window size change; ADR-0006), **only when the value differs** from the current one (no write on a burst of `size_changed`) and **never while the phase is Running**, where `f = UiMetrics.dp_scale(screen_dpi)` and `dp_scale(dpi) = clamp(dpi / 160.0, 0.75, 4.0)`; a missing or non-positive dpi returns 1.0 and logs once (HUD Open Question 9 fallback). After the write, views relayout on their next `tick` (the setter updates the viewport at once but Controls re-resolve at the end of the frame, so a `size` read in the same call can be stale). A Settings screen that is open when the factor changes finishes any slider drag first. The 2D factor also changes `get_viewport().get_visible_rect()` to dp: any code that reads the viewport size as pixels (ADR-0003, ADR-0006 display facts) is audited and uses `DisplayServer` pixel sizes instead. Fonts are imported as dynamic (TTF or OTF) so they are oversampled by the factor; each new fractional factor re-rasterizes glyphs once, which is why changes are confined to the re-read points. With this, **one viewport unit is one dp**, so the GDD formula `viewport_units_per_dp = (viewport_size.x / screen_size.x) * (screen_dpi / 160)` evaluates to 1 and every layout number in the HUD and Menus specs is used as written. `sp` equals `dp` (OS text scaling is not honoured). `UiScaler` emits `ui_scale_changed(scale: float)` after applying the factor; views re-run their layout in their next `tick` (not in the signal handler's call stack). 3D is not affected (`scaling_3d` remains the 3D resolution lever, ADR-0003).

`screen_dpi` joins the display facts that Platform Services already reads (ADR-0006 follow-up: `DisplayFacts` gains `screen_dpi: int`). The safe area arrives in pixels and is converted once by `UiMetrics.safe_area_dp(safe_px: Rect2, window_px: Rect2, f: float, max_width_dp: float) -> Rect2`: intersect the safe area with the window rectangle (subtracting the window position, so split-screen or a multi-window offset cannot leave the frame outside the window; split-screen itself stays unsupported, ADR-0006), divide by `f`, round to whole units (no half-pixel seams), then cap the width at `UI_MAX_CONTENT_WIDTH_DP` and centre it, which is the foldable letterbox of ADR-0006. A very large Android "Display size" (a high density) can shrink the layout below the 360x560 dp minimum safe area: Menus screens scroll vertically (they already do for Settings) and the HUD pills keep their size and are checked by the integration test at the largest supported scale.

### 2. Layer stack (`UiLayers`)

| Layer | Owner | Content |
|---|---|---|
| 3D viewport | World | tube, hazards, ball, props, particles |
| 5 | Juice | Hit flash `ColorRect` (`visible = false` when idle), below the HUD so pills are never washed |
| 10 | HUD | Z1 to Z5 pills, the Hit tap catcher (first child, so buttons sit above it) |
| 20 | Menus | active screen, modal cards and scrim, Paused screen (content below the top 92 dp, clear of HUD Z1) |
| 30 | Menus (behaviour: ADR-0010) | Ink cover, above both |
| 100 | tools | editor-only debug overlays (`OS.has_feature("editor")`), never in an export |

`UiLayers` is a constants class; no `CanvasLayer.layer` is assigned from a literal (lint). New layers take the gaps (spacing 5 to 10).

### 3. View and core split

Each presentation system is `XCore` (RefCounted, no engine calls, already decided) plus a **scene-based view**: `HudView.tscn` (root `CanvasLayer`, layer 10), `MenusView.tscn` (layer 20), `InkCover.tscn` (layer 30), `HitFlash.tscn` (layer 5). The view script has no `_process`; `GameRoot` calls `view.tick(real_dt)` at step 11, the view pulls a display snapshot from its core and writes a property **only when the value changed** (dirty compare, so an idle HUD redraws nothing). Views create no nodes while a run is going (all elements exist in the scene and toggle `visible`). One `Theme` resource (`assets/ui/ui_theme.tres`) holds the pill `StyleBoxFlat` (Rim White at 85%, Ink text, rounded), the Lagoon outline and the dimmed state; it is assigned at each view root, and a test asserts the theme uses only the three palette colours. Layouts are written in dp.

### 4. Safe area frame

Each view root has a `SafeAreaFrame` (`Control`) whose rectangle is `UiMetrics.safe_area_dp(...)`, recomputed on `ui_scale_changed` and on the display-facts re-read. Every positioned element (pills, rows, cards) is a child of it. Only **full-bleed** elements anchor to the whole root: the Hit tap catcher, scrims, the Ink cover, the Hit flash and backgrounds. The bottom 96 dp stays clear and no interactive element is within 40 dp of the side edges (HUD and Menus rules), checked by a test.

### 5. Input, focus and inert controls

- Every `Button` has `focus_mode = FOCUS_NONE` (ADR-0005); no code calls `grab_focus()`; the 4.6 dual-focus system therefore never draws a focus ring and needs no handling.
- **Hidden means `visible = false`** (an invisible `Control`, or one under a hidden ancestor or hidden `CanvasLayer`, receives no GUI input; hiding a whole overlay with `CanvasLayer.visible` is the cheap way). **Blocked means a full-screen `Control` with `mouse_filter = STOP`** (modal scrim, the Paused and modal backdrops, Ink cover, the Hit tap catcher), so a tap never reaches the HUD catcher underneath. **`mouse_behavior_recursive` is not used in the MVP** (this corrects ADR-0005's sentence).
- **`mouse_filter` defaults rule.** `Control`, `Panel`, `PanelContainer` and `ColorRect` default to STOP and `Label` to IGNORE. Every **non-interactive** Control (pill backgrounds, rows, containers, the Hit flash `ColorRect`) is set to **IGNORE**; only buttons, sliders, scrims, the catcher and the cover are STOP. An integration test walks each view tree and asserts it.
- **Handlers.** `button_down`, `pressed` and `_gui_input` fire during input dispatch, outside `GameRoot._tick`: they only stamp `press_us` and enqueue a request to the core (ADR-0002, ADR-0005), never change simulation state.
- **Editor runs:** `input_devices/pointing/emulate_touch_from_mouse` stays on (ADR-0005) so a mouse click produces the `InputEventScreenTouch` the catcher needs.
- A gated control is not `Button.disabled`: an own `is_gated` flag, `modulate.a` about 0.45 and a reason `Label`; its `pressed` handler asks the core and ignores the tap while gated.
- Priority between the Hit tap catcher and the Pause and Menu buttons is **tree order** (catcher first, buttons after, `mouse_filter = STOP` on the buttons), so a Menu press never also sends a restart (ADR-0005).
- Press feedback (scale 0.94 while held) is applied to a **child** (the pill visual) with a centred `pivot_offset`, not to the Button itself (a scaled Control also scales its picking rectangle and could flip release-inside); no per-frame code.

### 6. Slider inside a scroll list

`ScrollContainer` scrolls on `InputEventScreenDrag` and `InputEventScreenTouch`, not on a mouse drag, and a STOP control consumes the event before it can bubble. Rules:

- Every row, container and label inside the scroll list is IGNORE or PASS. **A stock `Button` inside the list uses `mouse_filter = PASS`** so a drag that starts on it can still scroll (a tap still presses it); `scroll_deadzone` is tuned above finger jitter (default 0 is too small) so a tap does not scroll.
- `UiSlider extends HSlider` overrides `_has_point(point)` to accept only a hit rectangle of at least 48 x 48 dp centred on the thumb (computed from `(value - min) / (max - min)`, the grabber icon width and `size.x`; a pure unit-tested function), so a press anywhere else on the row falls through to the `ScrollContainer`. The slider is **at least 48 dp tall and keeps a horizontal margin**, because the `ScrollContainer` clips and a thumb rectangle outside the slider's own rect (or clipped at the container edge) cannot be hit. The slider is STOP, so a thumb drag never also scrolls the list; a drag that started on the thumb stays with the slider (the GUI keeps the pressed control as the drag target). `follow_focus = false`, horizontal scroll off. The slider commits once on `drag_ended` (ADR-0007: no `set_value` on `value_changed`).
- Fallback if verification fails: a PASS `Control` wrapper per row with the slider set to IGNORE and manual thumb dragging in the wrapper's `_gui_input`.

### 7. Accessibility scope (AccessKit)

One helper, `UiAccess` (static, the only file that touches the 4.5 accessibility properties), sets names, descriptions and live-region flags from the HUD and Menus proposals (Play, Resume, Restart, Menu, Settings; the dialog and failure message as live alerts; the score is not announced per tick). The helper API is fixed now so call sites do not change after the spike: `name_control(c, name)`, `set_gated(c, reason)` (folds the reason into the description and exposes the gated state, because a gated Button stays enabled and would otherwise be announced as enabled), `announce(text)` (a live-region update, also used for the reason on a gated tap) and `set_live(c, mode)`. **Roles are not settable on `Control`:** they come from the node type, so toggles are stock `CheckButton` and sliders stock `HSlider` (the "switch" and "percentage" wording of the UX specs is a request to the spike, not a promise); a custom role would need the low-level `DisplayServer.accessibility_*` element API and is out of scope. The property names (believed `accessibility_name`, `accessibility_description`, `accessibility_live`) and the project setting `accessibility/general/accessibility_support` are confirmed on 4.7.2 in the spike.

**No acceptance criterion depends on it** until spike UI-A1 shows what a screen reader on Android announces; AccessKit support may be desktop-only (4.5 documented Windows, macOS and Linux). The 4.7 release notes and the `Control` class reference are read **before** spending device time.

**Interim baseline (recorded in `design/accessibility-requirements.md`, which must exist before the pre-production gate, not only here):** contrast (Ink on pills at 7:1, HUD AC-22 and Menus MN-11); touch targets of at least 48 dp with at least 8 dp between adjacent targets (checked by the integration test); no colour-only cue; no gameplay-critical information that is haptic-only or audio-only; no input has a time limit except gameplay itself; flash safety per **WCAG 2.3.1** (no more than 3 flashes per second, below the general and red flash thresholds), naming the Hit flash (a single flash per Hit at most 30% opacity, at most 2 frames, intensity capped) and the Ink cut explicitly; instant phase changes; a hardware Back press is an alternative exit path. **Known exclusions, each with an owner and a post-MVP target:** no non-tilt steering input (tilt is the only input; a touch-drag steering alternative is post-MVP), OS text scaling not honoured (acknowledged exception to WCAG 1.4.4; **not "never"**: a post-MVP in-game "Text size" setting multiplies font sizes only, so fonts come from the single `Theme` and Menus rows may grow with `custom_minimum_size` and scroll), no left-handed layout (HUD Open Question 5). The `reduced_motion_enabled` and `colorblind_safe_enabled` toggles must not be shown while they do nothing: each is wired to its consumers (the three UI motions and the Ink cut for reduced motion; Environment F3 for colourblind) before it is displayed, or hidden until it is.

**Focus:** every Button stays `FOCUS_NONE` (ADR-0005), which also hides the controls from keyboard, switch and D-pad navigation; whether Menus controls become `FOCUS_CLICK` with a themed focus style is Open Question 1 and is decided before the Menus views are built. If UI-A1 fails, screen-reader support is an explicit scope decision for the accessibility requirements document (a native plugin is out of the current scope), with the tier recorded (full, partial or none), the device and TalkBack version, and a re-run trigger on every Godot upgrade.

### 8. Draw calls and fill rate

The allocations stay as ADR-0003 fixed them (HUD 20, Menus 25, never concurrent except the Paused screen over the frozen HUD Z1). Budget about **2 draws per pill with text** (the panel, then a texture switch to the glyph atlas), not 1; a `ScrollContainer` always clips and adds a scissor and a batch break, so the Settings list is the Menus screen most at risk. Rules: pills are `StyleBoxFlat` panels with no shadow and no border (a border adds a mesh) and the theme is assigned once at each view root and as the project default theme (`gui/theme/custom`) so popups never fall back to the engine theme; no per-control `add_theme_*_override`; no `clip_contents` on pills; no blur, `BackBufferCopy` or `SubViewport` UI; no stacked full-screen translucent layers other than the one Hit flash or the one modal scrim (never together with the Ink cover); text uses the engine font atlas (one font, no per-label font file). The UI delta is measured in R-1 with the ADR-0003 method.

### Architecture Diagram

```text
Platform Services (display facts: safe_area px, size, screen_dpi) --> UiScaler: content_scale_factor = dpi/160 --> ui_scale_changed
UiMetrics (pure): dp_scale, safe_area_dp, px_to_dp
CanvasLayer 5  HitFlash          (Juice)
CanvasLayer 10 HudView           SafeAreaFrame { pills } + full-bleed tap catcher (first child)
CanvasLayer 20 MenusView         SafeAreaFrame { screens, ScrollContainer { UiSlider } } + modal scrim
CanvasLayer 30 InkCover          (behaviour: ADR-0010)
GameRoot._tick step 11: Juice.tick, HUD.tick, Menus.tick -> view.tick(real_dt) pulls core snapshot, writes changed properties
UiAccess: sets accessibility_* once at build (no AC depends on it)
```

### Key Interfaces

```gdscript
class_name UiMetrics extends RefCounted                      # pure, unit-testable
static func dp_scale(dpi: int, log_sink: Callable = Callable()) -> float          # clamp(dpi/160, 0.75, 4.0); dpi <= 0 -> 1.0, log once
static func safe_area_dp(safe_px: Rect2, window_px: Rect2, scale: float, max_width_dp: float) -> Rect2
static func slider_thumb_rect(value: float, min_v: float, max_v: float, grabber_w: float, size: Vector2) -> Rect2   # >= 48 x 48 dp
class_name UiLayers extends RefCounted
const FLASH := 5; const HUD := 10; const MENUS := 20; const INK_COVER := 30; const DEBUG := 100

class_name UiScaler extends Node                              # no _process
signal ui_scale_changed(scale: float)
func apply(facts: DisplayFacts) -> void                        # sets content_scale_factor, then emits

class_name UiSlider extends HSlider
func _has_point(point: Vector2) -> bool                        # thumb hit rectangle only (>= 48 x 48 dp)

class_name UiAccess extends RefCounted
static func name_control(c: Control, accessible_name: String) -> void   # the only caller of accessibility_*
static func set_gated(c: Control, reason: String) -> void               # reason folded into the description, gated state exposed
static func announce(text: String) -> void                              # live-region update
static func set_live(c: Control, mode: int) -> void
```

## Alternatives Considered

### Alternative 1: Stretch disabled with a manual `dp()` on every number
- **Pros**: no dependence on `content_scale_factor` behaviour; exact pixels.
- **Cons**: every Control and theme font needs a conversion; easy to forget one; fonts rebuilt per scale.
- **Rejection Reason**: more code and more silent errors; held as the fallback if UI-1 shows `content_scale_factor` misbehaves.

### Alternative 2: Fixed base size (for example 360 x 780) with `viewport` or `canvas_items` stretch and `keep_width`
- **Pros**: a familiar mobile setup.
- **Cons**: viewport mode blurs and letterboxes; a fixed base makes dp depend on the screen width instead of the density, so 48 dp touch targets drift across devices.
- **Rejection Reason**: the GDDs are specified in true dp.

### Alternative 3: Commit to screen-reader support in the MVP
- **Pros**: strongest accessibility story.
- **Cons**: the AccessKit platform scope on Android is unverified; may need a native plugin.
- **Rejection Reason**: out of scope until UI-A1.

### Alternative 4: `mouse_behavior_recursive` for hidden or inert subtrees
- **Pros**: one property per subtree.
- **Cons**: an unverified 4.5 API for something `visible` and STOP blockers already do.
- **Rejection Reason**: avoid a HIGH-risk API with no benefit.

## Consequences

### Positive
- HUD and Menus numbers are used as written (1 unit = 1 dp); one place owns scale and safe area.
- Input rules rely on long-stable behaviour (`visible`, `mouse_filter`, tree order).
- Cores stay headless-testable; views are scenes a designer can edit.

### Negative
- Depends on `content_scale_factor` and the Android DPI value (verified in UI-1; fallback exists).
- `UiSlider` carries a custom picking rule that needs a device test.
- Screen-reader support is not promised.

### Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Android reports a physical xdpi, not the density, so dp is off | Medium | Medium | UI-1 on two makers; clamp 0.75 to 4.0; fallback to the manual `dp()` route or a density from the window size |
| `content_scale_factor` change causes a hitch or a one-frame wrong layout | Low | Low | change only at the re-read points, never during a run; views relayout on the next tick |
| `_has_point` override ignored for emulated touch | Medium | Medium | UI-1 check 4; fallback custom `Range` |
| AccessKit does nothing on Android | High | Low (no AC depends) | UI-A1; scope decision in the accessibility document |
| Layer constants drift from the ADR | Low | Low | `UiLayers` lint |
| A foldable shows a stretched layout | Low | Low | letterbox cap `UI_MAX_CONTENT_WIDTH_DP` |

## Performance Implications

| Metric | Expected | Budget |
|---|---|---|
| Draw calls | HUD 20, Menus 25 (ADR-0003), measured in R-1 | 150 total |
| CPU per tick | dirty-compare writes only; HUD and Menus 1.0 ms each worst case | 3 ms simulation tick |
| Memory | one theme, one font, scenes loaded at boot | 512 MB |
| Load time | scenes instantiated once at composition | inside the boot budget |

## Migration Plan

Greenfield. Create the `project.godot` stretch settings, `UiMetrics`, `UiLayers`, `UiScaler`, the theme and the four scenes. Apply the small edits to ADR-0005 (drop `mouse_behavior_recursive`), ADR-0006 (`DisplayFacts.screen_dpi`) and the HUD and Menus GDDs (Open Question 9 resolved) after Accepted. Add to the ADR-0009 lint list: stretch settings, `CanvasLayer.layer` only from `UiLayers`, `accessibility_*` only in `ui_access.gd`, no `mouse_behavior_recursive`, no `Button.disabled` assignment in view code.

## Validation Criteria

- [ ] Unit (pure): `dp_scale` at 160, 420, 560, 0, negative, 10000; `safe_area_dp` including the width cap and an empty rectangle.
- [ ] Integration (real Controls, headless): at 360x560 dp and at scales 1.0, 2.625, 3.5 every interactive Control is at least 48 x 48 dp, none lies within 40 dp of a side edge or in the bottom 96 dp; the Pause and Menu buttons win over the tap catcher; a gated control ignores a tap; a hidden control and a blocker stop taps; views allocate no node after build; the theme uses only the three palette colours.
- [ ] Screenshots of HUD and Menus states at two densities in `production/qa/evidence/ui/` (coding standards).
- [ ] Spike UI-1 and UI-A1 results recorded; R-1 UI draw-call delta within 20 and 25.
- [ ] Lint rules above pass.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/gdd/hud.md` | HUD | TR-hud-015: dp to viewport units, dpi source and stretch mode need an ADR | decision 1 (canvas_items, `content_scale_factor`, fallback 1 with one log) |
| `design/gdd/hud.md` | HUD | TR-hud-016: HUD above the world and below Menus; Ink cut above the HUD | decision 2 (layers 10, 20, 30) |
| `design/gdd/hud.md` | HUD | TR-hud-014: layout in dp inside the safe area | decision 4 |
| `design/gdd/hud.md` | HUD | TR-hud-021: AccessKit names are proposals; no per-tick announcement | decision 7 |
| `design/gdd/menus-screen-flow.md` | Menus | TR-menus-screen-flow-014, -015: gated state flag, dp layout and targets | decisions 1, 4, 5 |
| `design/gdd/menus-screen-flow.md` | Menus | TR-menus-screen-flow-016: slider thumb versus scroll drag | decision 6 |
| `design/gdd/menus-screen-flow.md` | Menus | TR-menus-screen-flow-019: Ink cover and Menus above the HUD; Paused clear of Z1 | decision 2 |
| `design/gdd/menus-screen-flow.md` | Menus | TR-menus-screen-flow-021: AccessKit proposals non-binding | decision 7 |
| ADR-0005 | Input | hidden HUD subtrees use `mouse_behavior_recursive` (forward reference) | decision 5 replaces it |

## Open Questions

1. **Focus on Menus controls.** ADR-0005 sets `FOCUS_NONE` on every Button. That removes keyboard, switch and D-pad navigation and is the hardest accessibility decision to retrofit (every Menus scene, the theme focus style, the dialog's "focus on Cancel", the tests). Options: keep `FOCUS_NONE` everywhere (current), or `FOCUS_CLICK` on Menus and Settings controls only with a pill-styled focus StyleBox, the HUD staying `FOCUS_NONE`. Needs a decision before the Menus views are built, and an ADR-0005 amendment if changed.
1b. `UI_MAX_CONTENT_WIDTH_DP` default (proposal 480): the foldable letterbox width; ux-designer confirms.
2. ~~Whether the Ink cover's owner is Menus or a small shared presentation node~~ **Resolved by ADR-0010 (2026-10-03)**: `InkCoverCore` lives in the Menus module and is ticked unconditionally by `Menus.tick`; layer 30 is fixed here. One extra assertion for the ADR-0011 integration test: `CanvasLayer.visible = false` blocks GUI input.
3. Screen-reader support on Android (UI-A1) and the resulting accessibility requirements scope.

## Related Decisions

- ADR-0002, ADR-0003, ADR-0005, ADR-0006, ADR-0007 (slider commit); future ADR-0010 (Ink cover behaviour), ADR-0012 (Hit grey-out).
- `design/ux/hud.md`, `design/ux/menus-screen-flow.md`, `design/ux/interaction-patterns.md`
