# AGENTS

## Goal
- Stabilize Android service shutdown to avoid device instability during VPN teardown.
- Prevent desktop system proxy settings from leaking after app shutdown or crash.
- Clean up the app background so the default UI no longer looks muddy or dirty.

## Working Rules
- Prefer small, reviewable patches over broad refactors.
- Treat network-state cleanup as higher priority than new features.
- Preserve existing user settings and platform behavior unless the current behavior is unsafe.

## Investigation Focus
1. Audit Android `RemoteService`, `VpnService`, and related modules for unsafe start/stop, duplicate starts, and missing teardown.
2. Audit desktop proxy enable/disable flow and add process-lifecycle cleanup for abnormal exits.
3. Audit theme and scaffold surfaces that introduce unintended gray overlays or tinted backgrounds.

## Done Criteria
- Android stop path is idempotent and explicitly closes VPN resources before process/service teardown.
- Desktop proxy state is cleared when proxy mode is disabled and when the app detaches from the process lifecycle.
- Main app surfaces use a cleaner background palette without the dirty gray cast.
- Format, analyze, and targeted tests pass where the local environment allows.
- Changes are committed to git with a focused commit message.
