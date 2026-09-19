# Game Concept: Tube Rush *(working title)*

*Created: 2026-09-14*
*Status: Draft*

---

## Elevator Pitch

> It's an arcade endless-runner where you ride the outside of a never-ending
> tube, auto-running forward while tilting your phone (or moving your mouse)
> to rotate around the tube's surface and dodge obstacles that jut out of it
> in a full 360° circle.
>
> Test: Can someone who has never heard of this game understand what they'd be
> doing in 10 seconds? Yes — "Helix Jump, but sideways and running forward"
> reads instantly.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Arcade Endless-Runner / Obstacle-Dodge (tube-based) |
| **Platform** | Mobile (iOS/Android) — MVP mobile-only; Web (mouse control) considered post-MVP |
| **Target Audience** | Casual-to-midcore mobile players who enjoy skill-based reflex arcade games |
| **Player Count** | Single-player |
| **Session Length** | 1–5 min per run, several runs per sitting (~10–20 min total) |
| **Monetization** | Not decided yet — open question (see Risks) |
| **Estimated Scope** | Small (4–8 weeks MVP, solo) |
| **Comparable Titles** | Subway Surfers, Temple Run, Tunnel Rush |

---

## Core Fantasy

You are a ball with flawless reflexes, spinning around the surface of an
ever-extending tube at breakneck speed. The fantasy is pure mastery: dodging
obstacles that burst from the tube's surface a split-second before they'd
flatten you, and feeling your reactions get sharper with every run.

---

## Unique Hook

It's like Helix Jump, **AND ALSO** instead of falling down a vertical spiral
tower, you're auto-running forward along a horizontal tube — rotating around
its outer surface to dodge obstacles that jut out of it, in a full 360° circle
around you rather than three flat lanes.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 2 | Near-miss juice (screen shake, whoosh SFX, particle trail), sense of speed |
| **Fantasy** (make-believe, role-playing) | N/A | Not a role-driven game |
| **Narrative** (drama, story arc) | N/A | No narrative layer |
| **Challenge** (obstacle course, mastery) | 1 (primary) | Fair, learnable difficulty ramp; precision dodging |
| **Fellowship** (social connection) | N/A for MVP | Deferred — possible leaderboard/ghost-race tier later |
| **Discovery** (exploration, secrets) | 3 | New environment moodboards per level/map |
| **Expression** (self-expression, creativity) | 4 | Ball skins (post-MVP tier) |
| **Submission** (relaxation, comfort zone) | N/A | Game is tension-driven, not relaxing |

### Key Dynamics (Emergent player behaviors)
- Players will start taking riskier near-miss lines once they trust their own reflexes, chasing bonus feedback rather than playing maximally safe.
- Players will mentally "chunk" obstacle patterns after repeated deaths, recognizing recurring shapes rather than reacting cold each time.

### Core Mechanics (Systems we build)
1. Continuous auto-forward movement along a spline-based tube path (ball rides the OUTER surface of the tube), with speed increasing over distance/time.
2. Continuous (analog) angular control: tilt (mobile) or mouse movement maps directly to the ball's position around the tube's outer circumference. No gravity/wall-adherence framing — the ball simply stays locked to the tube's surface.
3. Follow camera: third-person, positioned behind the ball. Its orbit angle around the tube lags behind the ball's angle (validated starting value `CAMERA_FOLLOW_SPEED` 3.0) and it rolls with that orbit while looking at the tube axis, so the tube stays static and centered on screen while the ball and obstacles travel around it. (Validated by `prototypes/ball-in-tube-movement-concept/REPORT.md`; replaces the earlier "orbit but do not roll" idea, which caused dizziness.)
4. Obstacles protrude outward from the tube's surface at fixed world-space positions (angle + distance along the tube); collision → instant death → instant restart.
5. Near-miss detection and juice feedback (visual + audio reward for close dodges).

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | Player chooses when to risk a tight near-miss (for feedback/score) vs. play it safe | Supporting |
| **Competence** | Direct, immediate feedback on reflex skill; visible improvement run over run | Core |
| **Relatedness** | Not addressed in MVP; deferred to a possible future leaderboard/ghost-race mode | Minimal |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** (goal completion, collection, progression) — How: beating personal best distance/score, unlocking cosmetics in later tiers
- [x] **Explorers** (discovery, understanding systems, finding secrets) — How: curiosity about each level's distinct moodboard/environment
- [ ] **Socializers** (relationships, cooperation, community) — Not targeted
- [x] **Killers/Competitors** (domination, PvP, leaderboards) — How: only once a leaderboard/ghost-race tier is added post-MVP

### Flow State Design

- **Onboarding curve**: First level opens with a single obstacle type at low speed, teaching the "you're locked to the tube's surface and can slide freely around it" feel implicitly through movement within the first 10–15 seconds.
- **Difficulty scaling**: Speed and obstacle density/variety increase with distance survived.
- **Feedback clarity**: Near-miss juice + simple, high-contrast low-poly silhouettes make it unambiguous what killed the player.
- **Recovery from failure**: Instant restart (under 1–2 seconds), no friction (loading, forced ads) during MVP validation.

---

## Core Loop

### Moment-to-Moment (30 seconds)
The ball rolls forward automatically along the outside of the tube; the
player continuously adjusts its angular position around the tube's surface
(tilt or mouse) to slide past obstacles jutting out of it. This must feel
satisfying on its own — near-misses are rewarded with immediate visual/audio
juice, and the ball has slight inertia so control feels physical rather than
snappy/mechanical.

### Short-Term (5-15 minutes)
Segments of escalating obstacle density and speed, punctuated by distance
milestones (e.g., 100m, 250m). Occasional collectibles reward a clean,
efficient dodge line. "One more run" psychology comes from immediate,
legible cause-of-death feedback ("I know exactly what I did wrong") paired
with instant restart.

### Session-Level (30-120 minutes)
Several consecutive runs in one sitting: die → see distance/score →
immediately retry, chasing a personal best. A session ends naturally after
a new best is hit or the player's reflexes fatigue.

### Long-Term Progression
Skill mastery is the primary long-term hook for MVP. Post-MVP tiers add:
new environment/moodboard levels with new obstacle sets, cosmetic ball
skins unlocked via score/achievements, and short-lived in-run boosters
(shield, magnet, slow-time). Further out: additional game modes (heavier
ball, more slippery ball, gold-rush collection mode) and possibly a
leaderboard/ghost-race layer.

### Retention Hooks
- **Curiosity**: What does the next level's environment/moodboard look like?
- **Investment**: Personal best score/distance the player doesn't want to lose.
- **Social**: None in MVP — potential future leaderboard/ghost-race tier.
- **Mastery**: Tighter near-misses, longer survival streaks, eventually competitive rankings.

---

## Game Pillars

### Pillar 1: Instant Readability
The player must always be able to see obstacles clearly and know exactly why
they just died.

*Design test*: If debating between adding a flashy visual effect and keeping
obstacles easy to read, this pillar says we choose **readability**.

### Pillar 2: Fair but Merciless Difficulty
Difficulty escalates steadily and predictably; every death is caused by the
player's own reaction time, never by randomness or bad luck.

*Design test*: If debating between adding unpredictable random obstacle
spawns and keeping learnable patterns, this pillar says we choose
**learnable patterns**.

### Pillar 3: Juice on Every Near-Miss
Every close dodge must feel immediately rewarding through visual and audio
feedback.

*Design test*: If debating between polishing core-feel juice and adding new
content, this pillar says we **polish core feel first**.

### Pillar 4: One-Thumb Simplicity
Controls use a single input axis (left-right around the tube); the game is
playable one-handed, anywhere.

*Design test*: If a feature would require multi-touch or complex gestures,
this pillar says we **simplify or cut it**.

### Pillar 5: Skill First, Cosmetics Only
In-game power comes from player skill, never from spending money or time to
buy an advantage.

*Design test*: If a new system would let players survive longer without
getting objectively better at dodging, this pillar says we **don't build it**.

*(Note: Pillar 3 "Juice" and Pillar 1 "Readability" intentionally create
tension — an effect that looks great but obscures an obstacle is a violation
of Pillar 1 even if it serves Pillar 3.)*

### Anti-Pillars (What This Game Is NOT)

- **NOT pay-to-win power-ups**: any purchasable advantage that reduces the skill needed to survive would compromise Pillar 5 (Skill First, Cosmetics Only).
- **NOT multi-touch/gesture controls**: complex input schemes would compromise Pillar 4 (One-Thumb Simplicity).
- **NOT unavoidable random obstacles**: obstacles a skilled player cannot react to in time would compromise Pillar 2 (Fair but Merciless Difficulty).
- **NOT real-time multiplayer/netcode for MVP**: out of scope for a first solo project on a weeks-to-months timeline.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Helix Jump | Rotating around a cylindrical surface to dodge obstacles that jut out of it | Horizontal auto-forward movement instead of vertical falling; player rotates instead of the tower auto-rotating | Directly validates the "rotate around a cylinder to dodge protrusions" core mechanic has mass appeal |
| Temple Run | Auto-forward runner structure, instant restart loop | Full 360° rotation around a tube instead of 3 flat lanes | Validates the core "auto-run + dodge" loop has mass appeal |
| Subway Surfers | Juicy near-miss feedback, simple one-axis control | Tube-exterior framing instead of street lanes; slight ball inertia instead of lane-snap | Validates one-thumb controls work at scale on mobile |

**Non-game inspirations**: Skateboarding/half-pipe physicality (the feel of
being pulled to a curved surface), marble-run toys.

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 13–35 |
| **Gaming experience** | Casual to mid-core |
| **Time availability** | Short bursts — 5-15 minutes, commute/waiting-in-line play |
| **Platform preference** | Mobile (iOS/Android) |
| **Current games they play** | Subway Surfers, Temple Run, Tunnel Rush-style browser games |
| **What they're looking for** | Quick, skill-based arcade sessions with a satisfying "one more run" pull |
| **What would turn them away** | Unfair/random deaths, disorienting camera, controls that require two hands |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Not yet decided — run `/setup-engine` to evaluate against this concept and mobile target |
| **Key Technical Challenges** | Ball-on-tube-exterior movement math (angular position around a spline-based tube), follow camera that orbits without rolling, obstacle placement pipeline along the tube's surface, mobile performance for real-time 3D |
| **Art Style** | 3D stylized low-poly |
| **Art Pipeline Complexity** | Medium (custom 3D, but simple geometric shapes keep solo production manageable) |
| **Audio Needs** | Moderate — arcade SFX, near-miss juice stingers, simple lobackground music |
| **Networking** | None for MVP |
| **Content Volume** | MVP: 1 environment, 3-5 obstacle types. Full vision: multiple levels/moodboards + modes (count TBD in `/map-systems`) |
| **Procedural Systems** | Open question — hand-placed vs. procedurally generated obstacle patterns (resolve during `/design-system`) |

---

## Risks and Open Questions

### Design Risks
- The pure-dodge MVP loop may feel shallow without the later meta-layer (boosters/skins/modes) — mitigated by planned Tier 2+ additions.
- The developer's own taste (TFT/LoL/Balatro — strategy/competition-driven) may find the MVP's pure-reflex loop under-satisfying mid-development, risking motivation loss before Tier 2 features land.

### Technical Risks
- Ball-on-tube movement and camera-follow math is non-trivial 3D work for a first solo project — must be prototyped before any GDD/architecture work.
- Real-time 3D rendering + physics performance on lower/mid-tier Android devices.

### Market Risks
- The endless-runner/obstacle-dodge genre is heavily saturated on mobile app stores; discovery will be hard regardless of quality.
- The tube/tunnel-dodge sub-niche already has entries (Tunnel Rush-likes) — differentiation must come from art style, the fairness pillar, and moodboard variety.

### Scope Risks
- The original "a few weeks" timeline is optimistic for a first-time solo dev building a novel movement mechanic; realistic MVP estimate is 4–8 weeks.

### Open Questions
- Which engine (Godot/Unity/Unreal) best fits this concept and mobile target? → resolved via `/setup-engine` (see Technical Considerations).
- Exact tilt-to-angle input sensitivity/curve → resolve via prototyping.
- Occlusion: the tube hides obstacles on its far side, which the prototype tester found engaging ("surprise" obstacles) but which conflicts with the pillars *Instant Readability* and *Fair but Merciless Difficulty*. Keep as a feature, mitigate, or revisit the pillars? → resolve in `/design-system` or a pillar review.
- Camera tuning (follow speed, distances) was only accepted, not individually tuned, and tilt input was never tested on a real phone. → resolve in the next build.
- Hand-placed vs. procedural obstacle generation → resolve during `/design-system`.
- Monetization model (none / ads / cosmetic IAP) → resolve later, not required for MVP validation.

---

## MVP Definition

**Core hypothesis**: Rolling and dodging inside a curving tube, with a
world-locked camera and continuous analog control, feels fun and fair on its
own — before any meta-progression, skins, or additional levels are added.

**Required for MVP**:
1. One tube environment/level with a fixed art style (stylized low-poly).
2. Auto-forward movement with speed increasing over distance/time, ball riding the outer surface of the tube.
3. Continuous analog control (tilt on mobile) mapping to the ball's angular position around the tube's exterior.
4. Follow camera behind the ball with a lagged orbit that rolls with its angle, so the tube stays static on screen.
5. 3–5 distinct obstacle types protruding from the tube's surface, requiring rotation to dodge.
6. Collision → instant death → instant restart loop.
7. Distance/score tracking with a visible personal best.
8. Near-miss visual/audio juice feedback.

**Explicitly NOT in MVP** (defer to later):
- Multiple levels/moodboards.
- Ball skins/cosmetic unlocks.
- In-run temporary boosters.
- Meta-progression/permanent upgrades.
- Ball-locked "tunnel spin" camera mode (alternate game mode, later).
- Web/mouse-control version (mobile-only for MVP).
- Leaderboards/ghost-race/social features.

### Scope Tiers (if budget/time shrinks)

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 environment | Pure dodge loop only, as listed above | 4–8 weeks |
| **Vertical Slice** | 3–4 environments/moodboards | + cosmetic ball skins, in-run boosters, cross-level difficulty curve | +3–5 weeks |
| **Alpha** | All planned environments, placeholder polish | + extra modes (heavier ball, slippery ball, gold-rush mode), meta-progression | +4–6 weeks |
| **Full Vision** | Complete content, polished | + leaderboard/ghost-race layer, "Roll & Build" branch/booster depth, ball-locked spin mode as alt mode, web version | TBD |

---

## Next Steps

- [ ] Get concept approval from creative-director *(skipped this run — Lean review mode; revisit at a future phase gate if desired)*
- [ ] Fill in CLAUDE.md technology stack based on engine choice (`/setup-engine`)
- [x] **Prototype core idea** (`/prototype ball-in-tube-movement`) — done 2026-09-19, verdict PROCEED (see `prototypes/ball-in-tube-movement-concept/REPORT.md`)
- [ ] If prototype PROCEEDS: run `/art-bible`, then decompose concept into systems (`/map-systems`)
- [ ] Design each system (`/design-system [system-name]`) — use prototype learnings in Tuning Knobs and Formulas sections
- [ ] Build vertical slice in Pre-Production (`/vertical-slice`) — validate full game loop before committing to Production
- [ ] Validate core loop with playtest (`/playtest-report`)
- [ ] Plan first milestone (`/sprint-plan new`)
