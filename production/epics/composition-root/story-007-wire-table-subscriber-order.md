# Story 007: `_wire()` row table and pinned subscriber order

> **Epic**: Composition Root & Game Loop
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0002 (ranks owned by `design/gdd/run-state-restart.md`)
**Requirement**: `TR-run-state-restart-018`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order; secondary ADR-0013 (WorldFrame row at rank 1)
**ADR Decision Summary**: `_wire()` builds rows `[signal, handler, rank]` from typed handlers, sorts by rank with the row index as tie-break (the sort is not stable), and calls `signal.connect(handler)` in that order, immediate connections only.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: NEEDS VERIFICATION on 4.7.2 (not in the engine reference): handlers run in connection order, including a handler that is disconnected and reconnected (Run State AC-30 spy test). `CONNECT_DEFERRED` handlers run after `emit()` returns; argument coercion depends on the handler's declared types.
**Control Manifest Rules (this layer)**:
- Required: ranks `run_reset` (Pattern and `WorldFrame`, tie by row order; Tube Track adapter and Obstacle, tie by row order; Ball; Camera; the rest), `run_ended` (Juice; Scoring; HUD; the rest), `run_abandoned` (Juice; Scoring; the rest); signals declared on the owning core; add the `map_load_failed` row (ADR-0004); a new system adds one row.
- Forbidden: `CONNECT_DEFERRED` on control signals; `CONNECT_ONE_SHOT` inside the table; `await` in a `run_reset` handler; handlers that send requests; string-based `connect`.
- Guardrail: a mis-ordered build must fail loudly (Juice before Scoring).

## Acceptance Criteria
- [ ] Run State AC-30 passes against the real `GameRoot._wire()` table (ADR-0002 VC-1)
- [ ] After `_wire()` every row Callable is valid and the observed connect order equals the sorted table order, including after a disconnect and reconnect (VC-6)
- [ ] A shuffled copy of the rows (tie-break by row index) produces the same connect order; the sort does not depend on stability (Decision 7)
- [ ] `run_reset` order observed by spies: Pattern, `WorldFrame`, Tube Track adapter, Obstacle, Ball, Camera, then the rest; `run_ended`: Juice, Scoring, HUD; `run_abandoned`: Juice, Scoring (TR-run-state-restart-018)
- [ ] Every handler is statically typed: a row whose handler has an untyped parameter fails a validation pass (Decision 7)
- [ ] A row ordering Scoring before Juice on `run_ended` makes `_wire()` fail loudly (Juice requirement)
- [ ] `_wire()` runs after construction and before `map_ready` can be sent, so no signal is lost before `connect()` (Decision 5)

## Implementation Notes
Rows live in `_rows: Array` built inside `_wire()`; sort with a comparator on `(rank, index)`; connect in a loop. Keep strong references (Story 006). The table in ADR-0002 Key Interfaces is a partial sketch: the complete table is whatever the system stories have appended; this story creates the machinery, the `run_reset`/`run_ended`/`run_abandoned` ranks, the `WorldFrame.on_run_reset` rank-1 row and an ordering assertion helper that later rows reuse. Signal-order check uses real `RunStateCore` once available, otherwise a fake emitter declaring the same signals.

## Out of Scope
- Story 006: construction
- Story 010: `map_load_failed` row and map load (the row may be added there)
- Each system epic: its own handler body

## QA Test Cases
- **AC-1/2**: order and validity
  - Given: spy handlers on the real table
  - When: `emit()` each signal, then disconnect/reconnect one row and emit again
  - Then: call logs match expected; no invalid Callable
  - Edge cases: tie within rank 1 and rank 2 follows row index
- **AC-3**: stability independence
  - Given: rows in shuffled order
  - When: sorted and connected
  - Then: same order as the reference
- **AC-4**: pinned lists per signal
- **AC-5**: untyped handler
  - Given: a row with an untyped parameter
  - When: validated
  - Then: rejected with a code
- **AC-6**: mis-order fails loudly
- **AC-7**: emit before `_wire()` is lost (negative control) and none occur in the production order

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/composition_root/composition_root_wire_order_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 006; run-state-restart epic (signals; fake until then)
- Unlocks: Story 010; every system story that adds a `_wire()` row
