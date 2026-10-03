# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.7.2
- **Language**: GDScript
- **Rendering**: Mobile renderer (Vulkan) on Android, gated by spike R-1; Forward+ is the pre-committed fallback (ADR-0003). Stylized low-poly 3D
- **Physics**: Jolt (Godot 4.6+ default)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: Android only (decided 2026-10-01; iOS is out of scope, see docs/architecture/adr-0001-android-only.md)
- **Input Methods**: Touch (device tilt/accelerometer)
- **Primary Input**: Touch (tilt)
- **Gamepad Support**: None
- **Touch Support**: Full
- **Platform Notes**: Movement is analog — tilt angle maps directly to the ball's angular position around the tube's exterior surface, not discrete taps or lane-snapping.

## Naming Conventions

- **Classes**: PascalCase (e.g., `PlayerController`)
- **Variables**: snake_case (e.g., `move_speed`)
- **Signals/Events**: snake_case, past tense (e.g., `health_changed`)
- **Files**: snake_case matching class (e.g., `player_controller.gd`)
- **Scenes/Prefabs**: PascalCase matching root node (e.g., `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH`)

## Performance Budgets

- **Target Framerate**: 60 FPS
- **Frame Budget**: 16.6ms
- **Draw Calls**: ≤ 150 per frame (mobile 3D budget)
- **Memory Ceiling**: 512 MB (mid-tier Android target)

## Testing

- **Framework**: GUT (Godot Unit Test)
- **Minimum Coverage**: [TO BE CONFIGURED]
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- The machine-checked list is the `forbidden_patterns` section of `docs/registry/architecture.yaml`, enforced by `tools/ci/lint_rules.json` (ADR-0009). Headline rules: no autoloads for game systems, no `_process`/`_physics_process` outside `GameRoot`, no `CONNECT_DEFERRED` on control signals, no `Engine.time_scale` or `SceneTree.paused`, no raw `s` in a `Vector3` outside `WorldFrame`/`TubeMath` (ADR-0013), no `CollisionObject3D`/`Area3D`/`RayCast3D` (ADR-0008)

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- GUT (MIT), pinned by exact release and `godot.sha512` in `tools/ci/versions.json` after spike T-1 (ADR-0009); gdUnit4 is the pre-committed fallback if T-1 fails

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- ADR-0001: Android only, iOS out of scope (`docs/architecture/adr-0001-android-only.md`, 2026-10-01)
- ADR-0002 to ADR-0014 Accepted 2026-10-03 (`docs/architecture/`): game loop and Composition Root, renderer (Mobile) and tube route, Map Loader, sensor and input, Android integration, persistence, hazard content, test framework (GUT) and CI, presentation time, UI, ball material and chroma, distance precision and render origin, hazard render route. Validation spikes (R-1, T-1, PS-*, SP-*, PT-*, HV-1, UI-*, PRC-1, MS-1) gate the first dependent story

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (primary language) | godot-gdscript-specialist |
| Shader / material files | godot-shader-specialist |
| UI / screen files | godot-specialist |
| Scene / prefab / level files | godot-specialist |
| Native extension / plugin files | godot-gdextension-specialist |
| General architecture review | Primary |
