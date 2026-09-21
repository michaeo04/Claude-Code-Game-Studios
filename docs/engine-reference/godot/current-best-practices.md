# Godot — Current Best Practices

Last verified: 2026-02-12 | Engine: Godot 4.6

Practices that are **new or changed** since the model's training data (~4.3).
This supplements (not replaces) the agent's built-in knowledge.

## GDScript (4.5+)

- **Variadic arguments**: Functions can accept arbitrary parameter counts
  ```gdscript
  func log_values(prefix: String, values: Variant...) -> void:
      for v in values:
          print(prefix, ": ", v)
  ```

- **Abstract classes and methods**: Use `@abstract` to enforce inheritance
  ```gdscript
  @abstract
  class_name BaseEnemy extends CharacterBody3D

  @abstract
  func get_attack_pattern() -> Array[Attack]:
      pass  # Subclasses MUST override
  ```

- **Script backtracing**: Detailed call stacks available even in Release builds

## GDScript gotchas verified on the 4.7.2 binary (2026-09-20)

Each item was run headless on `Godot_v4.7.2-stable_win64` (Tube Track and Run State design
reviews, re-checked 2026-09-20). Anything not run is listed under "Still unverified" in
`modules/rendering.md` or marked as such.

- **No `nextafter`**: calling it gives `Parse Error: Function "nextafter()" not found`. To test a
  value one ulp below a boundary, use the literal double (for example `11.999999999999998` for 12).
  `Expression.parse` does not report the missing function, so do not use it to check.
- **Do not name a function `wrap`**: an unqualified call resolves to the global
  `wrap(value, min, max)` (`Too few arguments for "wrap()" call`). Use a distinct name
  (`wrap_angle`).
- **A static and an instance function cannot share a name**: `Function "x" has the same name as a
  previously declared function`.
- **`fposmod` edge cases**: `fposmod(a + PI, TAU) - PI` returns `+PI` (not `-PI`) for `a` the double
  just below `-PI`, so an angle wrap needs a `>= PI` guard; `fposmod(-1e-20, 5.0)` returns exactly
  `5.0`, so a "result in [0, y)" assumption fails for tiny negatives.
- **`Vector3` is 32-bit**: `Vector3(0, 0, 16384.001).z` reads `16384.001953125`. GDScript `float`
  is 64-bit; keep long-running distances in `float` and cast only when building the vector.
- **Signal argument coercion depends on the handler**: `signal s(v: int)` emitted with `2.7`
  delivers `2` to a handler declared `func h(v: int)` and `2.7` (a float) to an untyped handler or
  lambda. The signal's declared types are not enforced at `emit`. An enum-typed argument reports
  `TYPE_INT`.
- **Lambda captures**: a primitive local is captured by value (the outer variable stays unchanged),
  a container (`Array`, `Dictionary`) by reference. Count events through an `Array`.
- **`Callable().call()` on an unset Callable is a script error** (`Attempt to call function on a
  null instance`); default to `Callable()` and guard with `is_valid()`.
- **`CONNECT_DEFERRED` handlers run after `emit()` returns** (next idle step), so any guarantee that
  holds "inside the emission" (a re-entrancy guard, for example) does not cover them.
- **`class_name` needs a class cache**: a script's `class_name` did not resolve without a project
  and an import pass. Run `godot --headless --import` before a headless test run (GUT included), or
  `preload` the script.

## Physics (4.6)

- **Jolt Physics is the default 3D engine** for new projects
  - Better determinism and stability than GodotPhysics3D
  - Some HingeJoint3D properties (`damp`) only work with GodotPhysics
  - Switch: Project Settings → Physics → 3D → Physics Engine
  - 2D physics unchanged (still Godot Physics 2D)

## Rendering (4.6)

- **D3D12 is the default backend on Windows** (was Vulkan) — for better driver compatibility
- **Glow now processes before tonemapping** with screen blending mode — existing glow setups may look different
- **SSR overhauled** — significant improvement in realism, stability, and performance
- **AgX tonemapper** — new white point and contrast controls

## Rendering (4.5)

- **Shader Baker**: Pre-compile shaders to eliminate startup hitching
- **SMAA 1x**: New AA option — sharper than FXAA, cheaper than TAA
- **Stencil buffer**: Available for advanced masking/portal effects
- **Bent normal maps**: Directional occlusion in normal map textures
- **Specular occlusion**: Ambient occlusion now affects reflections

## Accessibility (4.5+)

- **Screen reader support**: Control nodes integrate with accessibility tools via AccessKit
- **Live translation preview**: Test GUI layouts in different languages directly in-editor
- **FoldableContainer**: New accordion-style UI node for collapsible sections
- **Recursive Control disable**: Disable mouse/focus interactions for entire node hierarchies with a single property

## Animation (4.5+)

- **BoneConstraint3D**: Bind bones to other bones with modifiers
  - AimModifier3D, CopyTransformModifier3D, ConvertTransformModifier3D

## Animation (4.6)

- **IK system fully restored**: Complete inverse kinematics reintroduced for 3D
  - Available modifiers: CCDIK, FABRIK, Jacobian IK, Spline IK, TwoBoneIK
  - Applied via `SkeletonModifier3D` nodes

## Resources (4.5+)

- **`duplicate_deep()`**: Explicit deep duplication for nested resource trees
  - Old `duplicate()` behavior retained for backward compatibility
  - Use `duplicate_deep()` when you need per-instance copies of nested resources

## Navigation (4.5+)

- **Dedicated 2D navigation server**: No longer proxied through 3D NavigationServer
  - Reduces export binary size for 2D-only games

## UI (4.6)

- **Dual-focus system**: Mouse/touch focus is now separate from keyboard/gamepad focus
  - Visual feedback differs depending on input method
  - Consider this when designing custom focus behavior

## Editor Workflow (4.6)

- Flexible dock drag-and-drop with blue outline preview (including bottom panel)
- Most panels support floating windows (except Debugger)
- New keyboard shortcuts: Alt+O (Output), Alt+S (Shader)
- Export variable auto-generation: drag resource from FileSystem into script editor
- Live preview in Quick Open dialog when "Live Preview" enabled
- New "Select Mode" (v key) prevents accidental transforms; old mode renamed "Transform Mode" (q key)

## Tooling

- **ripgrep has no `gdscript` type**: `*.gd` is registered under `gap` (GAP programming language).
  `rg --type gdscript` is a hard error — the search never executes.
  Always use `rg --glob "*.gd"` (shell) or `glob: "*.gd"` (Grep tool) to filter GDScript files.

## Platform (4.5+)

- **visionOS export**: First new platform since open-sourcing (windowed app mode)
- **SDL3 gamepad driver**: Better cross-platform gamepad support
- **Android**: Edge-to-edge display, camera feed access, 16KB page support (Android 15+)
- **Linux**: Wayland subwindow support for multi-window capability
