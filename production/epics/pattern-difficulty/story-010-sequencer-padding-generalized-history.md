# Story 010: Sequencer padding with the generalized read history

> **Epic**: Pattern & Difficulty
> **Status**: Blocked
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

> **BLOCKED**: `TR-pattern-difficulty-011` is Partial in `docs/architecture/architecture-traceability.md` ("generalized padding changes CR9 and F2c; Pattern design review required"). ADR-0008 Decision 6 replaces the GDD's opposing-only, non-Spike history with a history of every read (Spikes included) and a rule `req_spacing = max(S_MIN_SPACING, DODGE_RECOVERY_S if opposing)`, `req_clear = D`. The GDD's CR9, F2c, AC-12, AC-12c and AC-13 still describe the older rule (for example AC-12c says a Spike never enters the history). Unblock when the Pattern design review has revised those GDD sections and their acceptance criteria; update the AC text below to the revised GDD before `/dev-story`. The `/story-readiness` verdict must be BLOCKED until then.

## Context
**GDD**: `design/gdd/pattern-difficulty.md` (Core Rules 8, 9; Formula F2c; AC-12, AC-12c, AC-13), pending revision
**Requirement**: `TR-pattern-difficulty-011`, `TR-pattern-difficulty-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (Decision 6)
**ADR Decision Summary**: A pruned history of every read; each read of a drawn chunk is checked against every history entry; `padding_segments = ceil(max shortfall / L)` empty segments are inserted before the chunk. It never redraws, reorders or rejects a chunk.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `ceil` uses the documented constant `PADDING_EPSILON`; `opposing` uses the wrapped angular difference. `PatternConfig.validated` must assert `DODGE_RECOVERY_S - L >= D` (14.6 u vs 0.8 u at defaults).
**Control Manifest Rules (this layer)**:
- Required: history entry `(s_start, s_end, solution_angles)`; prune to `s_start >= frontier - max(DODGE_RECOVERY_S, S_MIN_SPACING)`; worst case 5 segments (`ceil(1.4 * 3.0)`); a chunk with no solution angles is never "opposing".
- Forbidden: the opposing-only history; redraw, reorder or reject at run time; raw `abs`; relying on P2 alone.
- Guardrail: `S_MIN_SPACING` 6.25 u, `DODGE_RECOVERY_S` 26.6 u, `D` 0.8 u, `L` 12 u.

## Acceptance Criteria
To be re-confirmed against the revised GDD. Current text (ADR-0008 generalization applies):
- [ ] **AC-12** (a) W1 then NR1 (opposing): 24.0 u gap, short by 2.6 u, exactly 1 padding segment (indices 1 empty, 2 empty, 3 NR1 at `s_start` 38.0); (b) W1 then W2 (non-opposing): zero padding; (c) opposing pair at exactly `DODGE_RECOVERY_S`: zero padding; (d) TWOHOP: first read 80 deg at 7.0 not opposing, second read 170 deg at 15.0 opposing the history entry, 11.6 u short, exactly 1 padding segment; first-read-only and always-pad mutations fail. Revise rows for the Spike-included history (for example `SPIKE_AFTER_WALL` and a non-opposing pair under 6.25 u get padding).
- [ ] **AC-12c** (revised) Spike handling under the generalized history: governed by the revised GDD (the older "Spike never enters the history" text is superseded by ADR-0008).
- [ ] **AC-13** At `T_DODGE_180` 1.4, `v_max` 30, `L` 10, `SEAM_HZ_MAX` 3.0: `DODGE_RECOVERY_S` 42.0, exactly 5 padding segments (empty for 5 indices, then the Near-Ring chunk), never a rejection or crash.
- [ ] Companion: AC-12b cross-chunk rows (26.5 u needs exactly 1 padding segment); AC-20 history-empty-after-reset assertion; the `DODGE_RECOVERY_S - L >= D` assertion rejects a violating config.

## Implementation Notes
Replace the body of the `_padding_segments_for(chunk)` seam added in Story 006. History is cleared in `on_run_reset` (Story 007). Padding state (`remaining_padding`) is consumed by successive `hazards_for_segment` calls returning empty. After placement append every read of the chunk at its final padded `s_start` and prune. `req_clear` ignores theta (conservative). Pacing impact (padding frequency) is measured at first playable (Pattern OQ11), not here.

## Out of Scope
- Story 008: pool clustering advisory. Obstacle epic stories 011 and 012: `ContentPreflight` P2/P3 (runs this sequencer).

## QA Test Cases
- **AC-12 / AC-12c / AC-13 / cross-chunk AC-12b**: sequencer calls
  - Given: micro-fixtures `TWOHOP`, `SPIKE_AFTER_WALL`, `LONG_OVERLAP` and the corner config. When: scripted `hazards_for_segment` calls run. Then: padding counts and indices exactly as listed; never a rejection.
  - Edge cases: `PADDING_EPSILON` stops a spurious segment at an exact multiple of `L`; history pruning loses nothing.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/pattern_difficulty/pattern_difficulty_sequencer_padding_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Pattern design review revising CR9/F2c (external gate); Stories 002, 004, 006, 007
- Unlocks: Story 013 (padding in integration), obstacle-system stories 011 and 012 (P2/P3), Story 014
