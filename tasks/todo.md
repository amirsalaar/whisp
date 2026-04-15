- [x] Confirm the current Apple toolchain and reproduce the macro-plugin failure mode.
- [x] Add a preflight check for missing Apple macro plugins in the shared build helper.
- [x] Verify `make install` fails early with an actionable Xcode requirement message.
- [x] Record the lesson if the new failure mode check proves useful.

## Hotkey investigation

- [x] Normalize unsupported Globe/Fn press-and-hold selections to a working key.
- [x] Update the recording settings UI so Globe/Fn is not offered as a supported global trigger.
- [x] Add regression coverage for press-and-hold settings normalization.
- [x] Run focused hotkey tests.

## Fn / Globe support

- [x] Restore Fn / Globe as a selectable press-and-hold trigger.
- [x] Add a dedicated Fn / Globe monitor backed by a lower-level event tap.
- [x] Add explicit Fn setup guidance and Input Monitoring actions in settings.
- [x] Preserve legacy Globe/Fn selections instead of normalizing them away.
- [x] Add regression coverage for Fn activation, combination cancellation, and migration.
- [x] Run the full VoiceFlow test suite.

## Fn / Globe simplification

- [x] Review the new standalone Fn / Globe path for duplicated state and branching.
- [x] Simplify the target manager, app, helper, and dashboard files without changing behavior.
- [x] Keep scope off unrelated model-cache changes already present in the worktree.
- [x] Run focused Fn / Globe tests and record the simplification result.

Result: centralized Fn / Globe readiness/config helpers, reduced duplicate monitor setup paths, and kept model-cache changes untouched while focused hotkey tests stayed green.
