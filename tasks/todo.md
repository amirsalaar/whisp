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

## Local Whisper persistence

- [x] Trace the `Installed` -> `Get` regression to the WhisperKit storage probe used by refresh and recorder readiness.
- [x] Align WhisperKit downloads and storage checks to the real Hugging Face base directory, while preserving a legacy fallback path.
- [x] Verify the download on disk before reporting the model as installed.
- [x] Add regression coverage for WhisperKit storage resolution and bundle completeness.

## Local Whisper download retry

- [x] Inspect the real Hugging Face tree created by WhisperKit during a local model install.
- [x] Fix the WhisperKit download base so new installs land under `~/Documents/huggingface/models/...` instead of `.../models/models/...`.
- [x] Keep compatibility with installs already created in the accidental double-`models` path.
- [x] Run focused Whisper storage/model-manager tests and the full suite.

Result: the `Get` action now points WhisperKit at the correct Hub base, completed installs are detected immediately, and previously downloaded models in the accidental `models/models` tree still resolve for refresh and delete.

## Fn / Globe reliability hardening

- [x] Research public Wispr Flow behavior and compare it against VoiceFlow's current Fn / Globe architecture.
- [x] Audit the dedicated Fn / Globe monitor from first principles for standalone key classification and tap recovery.
- [x] Fix the press-and-hold startup race so releasing the key during async recorder startup cancels cleanly.
- [x] Add regression coverage for standalone Fn keyDown handling and the new trigger state machine.
- [x] Re-run focused hotkey suites and the full VoiceFlow test suite.

Result: VoiceFlow now keeps the dedicated global Fn / Globe event-tap path, ignores standalone Fn keyDown echoes instead of treating them as combinations, recovers the tap after interruptions, and no longer loses a key release while audio recording startup is still in flight.

## Floating microphone dock

- [x] Add a floating, non-activating dock that stays visible across apps and Spaces.
- [x] Reuse real recorder and transcription state so the dock reflects listening, processing, success, and permission states.
- [x] Add a General preference to show or hide the dock.
- [x] Add focused regression coverage for the dock state model.
- [x] Verify with `swift build`, focused dock/hotkey tests, the full suite, and `make build`.

Result: VoiceFlow now launches an always-available floating microphone dock by default, keeps it synchronized with live recorder/transcription state, lets users disable it from General settings, and builds cleanly in both debug and packaged app flows.
