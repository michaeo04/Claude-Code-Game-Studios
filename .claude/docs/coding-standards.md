# Coding Standards

- All game code must include doc comments on public APIs
- Every system must have a corresponding architecture decision record in `docs/architecture/`
- Gameplay values must be data-driven (external config), never hardcoded
- All public methods must be unit-testable (dependency injection over singletons)
- Commits must reference the relevant design document or task ID
- **Commit messages**: Use Conventional Commits format — `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`. Reference the story or task ID in the body (e.g., `Story: EPIC-001-S02`).
- **Verification-driven development**: Write tests first when adding gameplay systems.
  For UI changes, verify with screenshots. Compare expected output to actual output
  before marking work complete. Every implementation should have a way to prove it works.

# Design Document Standards

- All design docs use Markdown
- Each mechanic has a dedicated document in `design/gdd/`
- Documents must include these 8 required sections:
  1. **Overview** -- one-paragraph summary
  2. **Player Fantasy** -- intended feeling and experience
  3. **Detailed Rules** -- unambiguous mechanics
  4. **Formulas** -- all math defined with variables
  5. **Edge Cases** -- unusual situations handled
  6. **Dependencies** -- other systems listed
  7. **Tuning Knobs** -- configurable values identified
  8. **Acceptance Criteria** -- testable success conditions
- Balance values must link to their source formula or rationale

# Testing Standards

## Test Evidence by Story Type

All stories must have appropriate test evidence before they can be marked Done:

| Story Type | Required Evidence | Location | Gate Level |
|---|---|---|---|
| **Logic** (formulas, AI, state machines) | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| **Integration** (multi-system) | Integration test OR documented playtest | `tests/integration/[system]/` | BLOCKING |
| **Visual/Feel** (animation, VFX, feel) | Screenshot + lead sign-off | `production/qa/evidence/` | ADVISORY (see escalation exception below) |
| **UI** (menus, HUD, screens) | Manual walkthrough doc OR interaction test | `production/qa/evidence/` | ADVISORY |
| **Config/Data** (balance tuning) | Smoke check pass | `production/qa/smoke-[date].md` | ADVISORY |

**Escalation exception (designated by creative-director 2026-09-22; RATIFIED by producer 2026-09-22).** Visual/Feel evidence is ADVISORY by default. A check becomes BLOCKING only when **both** limbs hold:

1. It is the **sole falsification test in the project for a specific pillar-breaking failure mode.** "Sole" is judged per *failure mode*, not per pillar — two checks may both serve one pillar if they detect different failure modes.
2. Its failure would force **cross-system retuning** (changing a value another GDD consumes) rather than presentation polish.

A GDD does not get to declare this on its own: the creative-director designates (as part of a `/design-review`) and the producer ratifies before the GDD is marked Approved. **If the producer declines, the check reverts to ADVISORY and the GDD may proceed**; the creative-director may escalate to the user.

Each designation must state (a) the failure mode, (b) the **named build gate** it blocks — the designation expires when that gate is passed, unless re-designated — and (c) the **pre-committed failure response**: what gets changed if the check fails, decided before the result is known, so it is not chosen under deadline pressure.

Designations are recorded in `production/qa/designated-gates.md`. Check the register before designating: if another GDD already claims the same failure mode, neither is sole.

**Scope limit.** A check that is a quantitative measurement on hardware with a numeric pass/fail threshold is **Integration evidence executed on a device** — already BLOCKING under the table above — and does not need this exception. Use this exception only for checks that are genuinely subjective (screenshot + lead sign-off).

**Precedent (ratified 2026-09-22).** Ball Movement BM-1 (failure mode: input-to-ball pipeline latency makes a death the pipeline's fault, not the player's — Pillar 2 primary, Pillar 4 secondary) and BM-3 (failure mode: unasked ball motion at run start/resume — Pillar 2) are BLOCKING for the **first-playable gate only**. Pre-committed failure response for both: lower `V_MAX` toward ~22 u/s; do **not** loosen Tube Track's `T_VIS_MIN` or Ball Movement's `T_DODGE_180_MAX`. BM-2 was not designated — a miss there is a tuning finding and blocks only locking the `OMEGA_MAX`/`BALL_LAG_TAU` defaults. Note: both BM-1 and BM-3 would also qualify as Integration-on-device under the scope limit above; the designation is belt-and-braces and must not be cited to escalate a merely-numeric device check in future.

**Verification obligation.** A prior version of this paragraph stated "ratified" before any producer was invoked; the error was caught on 2026-09-22 by checking `production/session-logs/agent-audit.log`. Never record a ratification, approval or sign-off as complete without verifying it against that log. Full incident record: `design/gdd/reviews/ball-movement-review-log.md`.

## Automated Test Rules

- **Naming**: `[system]_[feature]_test.[ext]` for files; `test_[scenario]_[expected]` for functions
- **Determinism**: Tests must produce the same result every run — no random seeds, no time-dependent assertions
- **Isolation**: Each test sets up and tears down its own state; tests must not depend on execution order
- **No hardcoded data**: Test fixtures use constant files or factory functions, not inline magic numbers
  (exception: boundary value tests where the exact number IS the point)
- **Independence**: Unit tests do not call external APIs, databases, or file I/O — use dependency injection

## What NOT to Automate

- Visual fidelity (shader output, VFX appearance, animation curves)
- "Feel" qualities (input responsiveness, perceived weight, timing)
- Platform-specific rendering (test on target hardware, not headlessly)
- Full gameplay sessions (covered by playtesting, not automation)

## CI/CD Rules

- Automated test suite runs on every push to main and every PR
- No merge if tests fail — tests are a blocking gate in CI
- Never disable or skip failing tests to make CI pass — fix the underlying issue
- Engine-specific CI commands:
  - **Godot**: `godot --headless --script tests/gdunit4_runner.gd`
  - **Unity**: `game-ci/unity-test-runner@v4` (GitHub Actions)
  - **Unreal**: headless runner with `-nullrhi` flag
