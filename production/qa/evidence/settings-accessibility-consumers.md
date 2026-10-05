# Settings & Accessibility consumers: evidence (story 012)

Test: `tests/integration/settings_accessibility/settings_accessibility_consumers_test.gd` (fakes written against the published getters).

## Covered by real code
- `GameRoot._construct` order: platform, save, settings; `HapticsSettingsAdapter.push_initial` runs once right after the Settings step, before Run State.
- `GameRoot._wire` connects `SettingsCore.setting_changed` to `HapticsSettingsAdapter.on_setting_changed`; `unwire()` removes it. The connection sits outside the typed row table because `validate_rows` treats a `Variant` parameter as untyped (documented in `_connect_settings_rows`).

## Pending (fake consumer in the test, real consumer not yet built or not yet wired)
| Consumer | Contract the fake follows | Pending until |
|---|---|---|
| Tube Track | pulls `get_seam_contrast_scale()` every frame, writes material only on change | Tube Track view reads Settings (no `seam_contrast` use in `src/` yet) |
| Environment | getter at map load plus `setting_changed` | Environment epic |
| Tilt Input | `TiltSettingsAdapter.on_setting_changed` (live path already proven by CRF-003 test) | production factory wiring of `TiltSettingsAdapter` into `_connect_settings_rows` |
| Platform Services | real `PlatformServices.set_haptics_*` | production factory (GameRoot.configure) |

## Menus slider contract (not implemented here)
Settings sliders use `UiSlider` and call `set_value` on `drag_ended` only, never per `value_changed`; `SettingsCore` has no coalescing.
