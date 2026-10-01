# Art Bible: Tube Rush *(working title)*

## Document Status
- **Version**: 0.1
- **Last Updated**: 2026-09-19
- **Owned By**: art-director
- **Status**: Draft (Sections 1-4 of 9 complete: Visual Identity Foundation)

---

## 1. Visual Identity Statement

**Visual rule**: *Danger is the loudest thing on screen. Only hazards get
full-chroma warm hue plus peak contrast; everything else, rewards included,
stays a step quieter.*

This extends the concept doc's anchor "Only danger is bright". "Bright" was
ambiguous (value or chroma) and ignored pickups and boosters, so the rule now
states the loudness budget explicitly and covers rewards.

### Supporting principles

1. **Loudness budget** *(serves Pillar 1, Instant Readability)*. Only hazards
   are full-chroma warm with peak contrast. Pickups and boosters get a cool
   accent and round shapes so they never read as danger or vanish.
   *Design test*: when two elements compete for attention, the one that can kill
   the player is the louder.
2. **Shape before color** *(serves Pillar 2, Fair but Merciless Difficulty)*.
   Obstacle types must be recognizable by silhouette alone so patterns are
   learnable and never rely on hue.
   *Design test*: when two hazards are ambiguous in grayscale, change the
   silhouette, not the hue.
3. **Juice never speaks in danger's voice** *(serves Pillar 3, Juice on Every
   Near-Miss)*. Near-miss and speed effects use the ball's cool/white channel
   and stay off the hazard.
   *Design test*: when a near-miss effect overlaps a hazard in color or screen
   area, choose the effect that uses the cool/white channel and stays off the
   hazard.

### Helix Jump reference and how it is reconciled

The user's main visual reference for obstacles and moodboard/concept art is
Helix Jump, and Map 1 should read as "classic Helix Jump". Classic Helix Jump
has a saturated tower with hazards read through hue and value contrast, which
conflicts with the loudness rule if copied literally.

**Chosen reconciliation: "Tinted, not saturated".** Each tube keeps a single
Helix-style hue, but at capped (dusty or pastel) chroma. Hazards alone get full
chroma and the darkest value.
- **Keep from Helix Jump**: flat-shaded chunky low-poly forms, hard-edged
  protrusions, one hue family per map, a glossy ball, a palette shift per map.
- **Change**: the tower's chroma is capped so hazards stay the loudest element.
- **Rejected alternative, hue-contrast** (saturated tower, hazards in a
  complementary hue): truer to the reference, but relies on hue alone, which
  fails the accessibility requirement, and it needs a per-map hazard color that
  breaks the reserved warm family.

### Map 1 base look

A single-hue, flat-shaded low-poly tube with a soft sky gradient at capped
chroma, carrying chunky, angular red and dark obstacles and a glossy, cool-toned
ball. Few materials, to stay comfortably under the 150 draw-call budget.

### Scope note

Each map will have its own theme and concept art. Only Map 1 is in scope now.
Future maps may change hue, theme and environment, but must obey this section's
rules (hazard loudness and silhouette rules never vary).

---

## 2. Mood & Atmosphere

Defined for Map 1. The hit and the next run are one continuous loop: the restart takes
under 1 s, measured from the touch-down of the player's tap (a short locked sting, then one tap).
Tension comes from hazard density, speed and world desaturation, never from
darkening the world (the dusty base palette can otherwise read as cozy).

| State | Emotion | Lighting | Descriptors | Energy | Mood carrier |
|---|---|---|---|---|---|
| 1 Menu / map select | Curious, poised | Cool-neutral key, top-left, lowest contrast, no warm light | Still, airy, dusty, open | 1/5 | Tube idles slowly, ball bobs; one lone hazard on the tube is the only saturated thing, previewing the rule |
| 2 Run, low speed | Focused calm (not relaxed) | Same key, soft contrast, long fog | Spacious, deliberate, legible | 2/5 | Wide gaps between hazards, distant horizon, no speed FX |
| 3 Run, high speed | Controlled tension, flow | Same direction; world chroma drops about 12% (x0.88, range 0.85-0.90), value unchanged so hazard and seam contrast are unaffected; fog pulls nearer; hazards, ball and pickups untouched | Taut, streaming, hushed, narrow | 4/5 | Cool-white streaks at screen edges only (never the approach zone); FOV widening capped at 5% |
| 4 Near-miss | Sharp thrill, tiny triumph | 60-100 ms cool-white rim on the ball | Bright, brief, crisp | Spike 5/5 | White ring pulse on the tube at the ball's position, whoosh, 1-2% FOV punch |
| 5 Hit + restart | Sting, then "again", no shame | 150-200 ms hitstop; world greys out while the killer hazard keeps full chroma; then a soft white flash (peak at most 30% opacity, at most 2 frames) | Abrupt, exact, clean | Spike, then reset | Grey-out isolates the killer hazard (shows what killed the player); ball bursts into cool-white shards; restart in under 1 s from the touch-down of the player's tap |
| 6 New personal best | Earned pride | Brief value lift and capped cool bloom, no gold | Clean, ascending, clear | 3/5 | White ring sweeps down the tube plus a non-blocking banner; never delays the restart |

### Rules resolved from conflicts
- **No screen shake.** It fights Pillar 1 and the camera-roll dizziness fix. Use
  the FOV punch instead; any shake must be tiny and carried by the ball, not the
  tube. (The concept doc still lists screen shake and should be synced.)
- **No red hit flash and no gold or multi-hue confetti.** Both break the reserved
  warm family and the loudness budget (Section 1).
- **Key light is fixed in camera space.** The camera rolls with the ball, so
  world-fixed light would make shading and hazard shadows swim.
- **Photosensitivity.** At most 3 flashes per second, at most 30% opacity, and a
  "reduced juice" setting.
- **High-speed compression must not shrink the readable window** of newly
  visible (hidden-side) hazards.

### Per-map variation
Maps may change: tube hue, sky and props, fog distance, key-light angle within
the cool-neutral range, music timbre, and the ceiling of the energy curve.

**Never varies:** hazards are the loudest element; warm is reserved for hazards;
juice stays in the cool/white channel; energy ordering (menu < low speed < high
speed < near-miss peak); the killer hazard is isolated on death; restart in
under 1 s from the touch-down of the player's tap; readability beats effect.

### Warm-themed maps (decided 2026-09-19)
Mild warm themes (such as desert) are allowed, but their environment chroma must
stay under a very low ceiling so hazards remain the loudest element. The ceiling
is set in Section 4 (Color System). A glowing lava theme is dropped (see Section 4).

---

## 3. Shape Language

**Core rule: "Round is yours, angular is danger."** Hazards alone own hard,
flat-shaded angles. The ball, pickups, tube and UI own curves. It extends the
Section 1 loudness budget (Pillar 1) and gives an instant safe/unsafe gut read.

Numbers below marked *(proposal)* are starting points; they belong to the obstacle
GDD and must be validated in the engine.

### (a) The ball
- Solid, smooth-shaded sphere with a fixed radius; hitbox equals the visible
  silhouette (Pillar 2: no "unfair" hits). It is the only solid sphere in the game.
- **Intentional exception to faceted low-poly** (confirmed 2026-09-19): the ball is
  a smooth sphere of roughly 16x12 segments or more.
- Skins **may** change: hue (never warm), gloss, low-frequency pattern, burst
  shards. Skins **may not** change: silhouette or scale, add protrusions, use
  red/black striping, or drop below a minimum value contrast against the tube.
  Every skin keeps the cool-white rim (Section 2).

### (b) Hazards
Three families, told apart by their front-on profile (the camera looks down the
tube):
1. **Spike**: tall, narrow, single apex. "Pierce."
2. **Block**: squat, wide, flat-topped slab (a notched-top variant is allowed). "Obstruct."
3. **Gate**: an arc band spanning 90-270 degrees of the circumference with a
   flat-cut gap. "Squeeze."

A new family is admitted only if it is grayscale-distinct from all existing ones
(Principle 2, Pillar 2). Cap: 5 families per map.

Rules for all hazards:
- Extrude radially from the tube.
- Height at least 1 ball diameter (D) *(proposal)*.
- The joint with the tube is abrupt: no fillets, no bevels.
- The silhouette has no curves or circles.
- About 60 triangles each, one MultiMesh per family *(proposal; technical-artist to confirm)*.
- Gate gap at least 2D *(proposal; tuning knob)*.
- **Tip-first identity**: the defining feature sits in the top third, so a
  hidden-side hazard is identifiable the moment it crests the tube's horizon (Pillar 1).

### (c) Pickups and boosters
- Pickups hover 0.5-1D above the surface with a visible air gap; hazards are rooted,
  pickups float.
- Coins are hollow rings or discs, at most 0.5D. Boosters are a larger ring
  (about 0.8D) with an inner glyph.
- Smooth-shaded, spinning slowly; never a solid sphere or any angular shape.

### (d) Tube and environment
- The tube is the largest and simplest form: a flat-shaded cylinder (about 32
  sides; confirm against the draw-call budget).
- Circumferential seams sit flush with relief of at most 0.1D; they give speed and
  distance cues because the tube is static on screen.
- Props stay in the background: either at least 5x hazard scale (landscape) or soft
  horizontal forms. No wedge or slab silhouettes at hazard scale.
- Keep a clear sky band around the tube's contour so emerging hazards read against
  a clean gradient.

### (e) UI shape grammar
UI echoes the round family (pills, circles, rounded rectangles). It never uses
triangles, warning icons or hazard-like wedges. It is neutral or cool-white, sits
off the approach zone, and never covers the isolated killer hazard on death.

### (f) Visual hierarchy
1. Hazards: angular, darkest, saturated.
2. Ball: fixed screen anchor with a glossy rim.
3. Pickups: small and spinning.
4. Tube seam flow.
5. Environment.
UI stays peripheral.

### (g) Per-map variation
- **May change**: hazard theming within the silhouette (proportions within 15%,
  surface bumps under 10% of width), seam pattern, props, sky.
- **Never changes**: the round/angular split, the 1D minimum height, tip-first
  identity, a circular tube section, grayscale distinctness, the spherical ball,
  the clear contour band.

### Known risks
- Ball and pickups share the cool channel. They are separated by scale,
  hollowness, hover gap and gloss, which is the weakest distinction: playtest it.
- Props and fog near the tube contour would shrink the hidden-side readable
  window, hence the clear-band rule.

---

## 4. Color System

All numbers are **proposals to validate on a real phone screen** (chroma is OKLCH
C, contrast is the WCAG luminance ratio). The contrast ratios and chroma values
below were recomputed from the hex codes on 2026-09-19 and match the art
director's figures.

### Map 1 palette
| Name | Hex | Role | Notes (computed) |
|---|---|---|---|
| Mist Sage | #A9BFB0 | Tube | luminance 0.49, C 0.032, hue 156 |
| Haze Top | #C4D2E6 | Sky top | luminance 0.64 |
| Haze Low | #E6EDF5 | Sky bottom | luminance 0.84 |
| Signal Red | #A0101A | Hazard face | luminance 0.08, C 0.174, hue 26 |
| Ember | #5C0A12 | Hazard shade | luminance 0.03 |
| Slate Cobalt | #3A4F88 | Ball | luminance 0.08, C 0.098 |
| Lagoon | #0E6A82 | Pickup/booster, UI accent | luminance 0.12, C 0.086 |
| Rim White | #F4F8FF | Juice, ball rim | luminance 0.94 |

The ball is cool (cobalt), not the orange used in the prototype, because warm
is reserved for hazards. Contrast: hazard/tube 4.17:1, ball/tube 4.06:1,
pickup/tube 3.16:1.

### Semantic vocabulary
| Signal | Means |
|---|---|
| Warm full chroma | Lethal; hazards only |
| Cool accent | Safe or collectible (pickups, ball) |
| White | Player feedback (rim, juice, UI) |
| Grey-out | Run over; look at the killer hazard |
| Dark | Threat and weight; only hazards and the ball go below luminance 0.10 |

### Guardrails *(proposals)*
| Item | Rule |
|---|---|
| Environment chroma ceiling | C at most 0.05 |
| Hazard chroma floor | C at least 0.15, hue 15-35 degrees |
| Ball and pickup chroma | 0.08-0.12 |
| Hazard / tube contrast | at least 4:1 (binding; see colorblind notes) |
| Ball / tube contrast | at least 4:1 (skins at least 3:1) |
| Pickup / tube contrast | at least 3:1 |
| Warm-themed map environment chroma | C at most 0.03, hue 55-100 degrees only |
| High-speed world chroma | multiply by 0.88 (range 0.85-0.90), value unchanged; hazards, ball and pickups exempt |

**Warm themes**: mild warm themes such as desert are allowed under the ceiling
above. **A glowing lava theme is dropped** (2026-09-19): it cannot fit under the
0.03 ceiling without breaking the loudness rule.

### Deriving a new map's palette
- **Pick**: one tube hue outside 340-50 degrees and at least 30 degrees from the
  ball hue; tube luminance 0.40-0.55; a light sky.
- **Check**: every number above; a grayscale render (hazards must be the
  darkest); a color-vision-deficiency simulation; a phone at 50% brightness in sunlight.
- **Reject**: environment over the chroma ceiling; hazard/tube under 4:1; a
  moved hazard hue; emissive or bloom exceeding the ceiling; a tube hue within 30
  degrees of the ball or pickup; tube and sky at equal value with no shading.

### UI palette
Ink #1E2433, pill #F4F8FF at 85% opacity, accent Lagoon. Text at least 4.5:1;
score at least 7:1. It diverges from the world palette in four ways: it is fixed
across maps; it ignores fog, speed desaturation and grey-out; it uses no warm hue
(no red errors or badges); it uses no gold.

### Juice contrast (decided 2026-09-19)
White juice against the tube is only about 1.83:1 and against the sky 1.1-1.4:1,
so it can vanish in glare. Rings get a **Lagoon-tinted outer edge** around the
white core to separate them from tube and sky, without touching hazard contrast.
Still requires a real-device test.

### Colorblind safety
| Pair | Fails under | Backup cue |
|---|---|---|
| Red hazard / sage tube | Deutan, protan | 4:1 luminance (protan darkens red, which helps); angular silhouette |
| Lagoon pickup / sage tube | Deutan, protan | Ring shape, hover gap, 3.2:1, chime |
| Cobalt ball / Lagoon pickup, cobalt / sage tube | Tritan | Sphere vs hollow ring, white rim, 4:1, size |
| Tube / sky | Tritan | Underside shading, clear contour band |
| White juice / light backdrop | All | Ring motion, whoosh, haptic |

A warm hazard against a green or cool tube survives red-green deficiency only
through luminance, never hue, so the 4:1 floor is binding.

### Known risks
- **Ball vs hazard** have almost the same luminance (0.083 vs 0.079, contrast
  1.03:1), so only hue and shape separate them. Section 1's "darkest" rule holds
  only because the hazard shade (Ember) is about 0.03. Playtest it.
- **Glare**: light dusty palettes wash out and chroma cues die first, so value
  contrast must carry safety.

---

## 5. Character Design Direction
[To be designed]

---

## 6. Environment Design Language
[To be designed]

---

## 7. UI/HUD Visual Direction

**Every UI/HUD element sits on its own opaque(-ish) pill, never bare against the world.** The UI palette (§4) is deliberately fixed and ignores fog, speed desaturation and grey-out — that promise only holds if UI elements are backed by their own Rim White pill rather than read directly against a tube/sky backdrop that legitimately shifts. This also means UI/HUD elements never face the "white juice vanishing into glare" failure mode the Juice contrast note (§4) fixes with a Lagoon-tinted outer edge on world-space rings — that fix belongs to Juice & Feedback's own effects; UI/HUD elements solve the same underlying problem structurally, by never being bare white shapes over a variable backdrop in the first place.

**Live values never carry their own motion — only the world does.** A live, always-honest value (a running score, an exact count) gets zero pulse, color shift or scale change of its own on a significant moment (a near-miss, a hit, a new best). The moment is carried by the game world's own presentation (rim glow, ring sweep, banner) exactly once; a second, redundant motion source on the UI number splits the player's attention rather than reinforcing the moment. If a UI value must mark a moment at all, a single accompanying element (a banner, a badge) carries the motion — the value itself stays exact and still.

**A cosmetic "not yet" state is not the same as a disabled state, and must look different.** Where a UI element is genuinely non-interactive right now — because of something outside the player's control (no sensor, reconnecting) or because of a choice the player already made elsewhere (a dependent control switched off by its own parent toggle) — use reduced opacity on its existing pill, plus a small Lagoon animated cue only when it's actively resolving itself on its own (with no cue when it will not resolve without leaving the run, and no cue at all for a player's-own-choice case, since nothing is "resolving"). Where an element is functional but cosmetically "still arming" (a short, harmless grace window before it does something), use a calm continuous fill/charge treatment instead — never the same dimmed/inert look used for genuine unavailability, and never an urgent pulsing "act now" cue that would encourage a rushed, mistimed input. These two situations must read differently, or the player learns the wrong lesson from one of them.

**Never color-code an error state.** Every "temporarily can't" state (a lost sensor, an unsupported device, a reconnect in progress) stays inside Ink/Rim White/Lagoon exactly like every other UI element — no warm hue, no red, regardless of how error-like the underlying state is. The distinction between different unavailable states is carried by opacity, motion presence, and iconography/text, never by introducing a new hue outside the UI palette.

**UI elements separate by shape, position, opacity and label — never by hue alone.** This extends §1's "shape before color" principle from obstacles to the UI layer: any two UI states that must be told apart (available vs. reconnecting vs. unavailable; locked vs. unlocked) get a distinct shape, animation state, or text treatment, not just a different tint of the same accent color.

**Live figures are typographically dominant over reference figures.** Where a screen shows both a live, changing value and a static reference value side by side (a running total and a best-to-date), the live value gets the larger, heavier typographic treatment; the reference value is visibly subordinate (smaller/lighter, with a short label) so their difference in status — live and honest vs. fixed and comparative — reads before either number is even parsed.

**Milestone/celebration UI (a banner, a badge) stays strictly within Ink/Rim White/Lagoon — never gold, never a warm hue** — even when marking an unambiguously positive moment. This is a hard extension of §1's loudness budget and §4's "no gold" rule to the UI layer: a celebratory UI element must never borrow the visual weight the palette otherwise reserves for hazards or warmth.

**On a screen with more than one call-to-action, exactly one gets primary-action treatment.** The single most important, most positive tap on its own screen (a Play button, a Resume button, a Retry after a failure) gets the largest pill in its group, a Lagoon accent stroke or underline, and bold Ink text — every other action on that screen (a secondary entry point, an abandon/quit path, a cancel) gets the same Rim White pill and Ink text but no accent and a visibly smaller size. A screen never has two primary-treated actions competing for the same attention.

**A genuinely irreversible confirm may invert the pill's own fill and text values, reserved for actions with no undo.** Where the house pattern is a Rim White pill with Ink text, a destructive confirmation's own accept button (never its cancel option) may invert to a solid Ink fill with Rim White text — the single heaviest-reading button available in the UI palette — without using a hue outside Ink/Rim White/Lagoon and without color-coding it as an error. This is reserved for actions that cannot be undone; an ordinary or reversible action never uses it, or the inversion stops meaning anything.

**A UI moment never borrows a Mood State's own signature treatment for an unrelated purpose.** The Mood States table (§2) already reserves specific color/motion signatures for specific world moments (the hit's own soft white flash, the near-miss ring's own pulse) — a UI-layer transition or cue that is not that moment (a routine screen change, a loading boundary) must not reuse the same signature, even briefly, even in a muted form. Borrowing it would teach the player to associate an unrelated, more mundane moment with the one it actually belongs to.

*(First drafted 2026-09-29 from `hud.md`'s own Visual/Audio Requirements section — the first GDD to give this section real content, mirroring how Environment & Theming's own pass first drafted Section 6. Extended 2026-09-29 from `menus-screen-flow.md`'s own pass with the primary/secondary action grammar, the irreversible-confirm inversion, the Mood-State-exclusivity clause, and a widened "disabled-not-hidden" wording covering a player's own preceding choice, not just external conditions.)*

---

## 8. Asset Standards
[To be designed]

---

## 9. Reference Direction
[To be designed]
