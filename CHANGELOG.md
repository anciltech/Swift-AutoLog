# Changelog

## 0.8.1 - 2026-05-20

### Added

- Added `AutoLogOutput.consoleDefault` as the explicit console-only default output.
- Added `AutoLog.start(configuration:sinks:configurationStore:refreshInterval:)` so apps can attach external sinks without changing logger identity.
- Added `AutoLogParameterPrivacy` with `.include`, `.omit`, and `.allowList` options for per-output parameter privacy.
- Added optional `metadataKeyAllowList` on `AutoLogOutput` for backend-specific custom-key policy.

### Changed

- `AutoLogOutput` now controls sink delivery: untagged events can flow to any matching configured output, while explicit route tags still narrow routing for specific call sites.
- Function start events are selected by `.start` in each output's `eventTypes` instead of the global `emitStartEvents` switch.
- The default no-configuration runtime remains console-only and preserves legacy timing and format settings through the implicit console output.
- SwiftUI helper events such as `Button.log` and lifecycle helpers now participate in the same output matching as macro-generated events.

### Documentation

- Documented Crashlytics as a normal `.firebase` `AutoLogEventSink` that receives events through output routing.
- Updated output-routing examples for Crashlytics, Splunk, Datadog, Sentry, and other backend sinks.
