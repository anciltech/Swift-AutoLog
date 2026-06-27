# Changelog

## 0.9.2 - 2026-06-27

### Changed

- `CompactFormatter` now renders long structured object values as bounded
  multi-line previews instead of expanding every nested object and collection.
- Added `CompactFormatter(objectPreviewLineLimit:)` so loggers can opt into
  larger or smaller object previews.

## 0.9.1 - 2026-06-27

### Changed

- `CompactFormatter` now renders complex collection parameters and return values
  as bounded multi-line previews with per-element summaries instead of dumping
  the full object graph inline.
- Long structured object parameters and return values are now pretty-printed
  with indentation so nested fields are readable before any truncation policy is
  applied.

## 0.9.0 - 2026-05-22

### Added

- Added the `AutoLogSwiftUI` product for SwiftUI helpers such as `Button.log`, binding logging, and lifecycle modifiers.
- Added compile-time emission pruning so macros can omit start, success, or failure paths when an emit filter is known at build time.
- Added typed macro emission filters, including array-style filters such as `@Log(emit: [.failures, .warnings])`.
- Added build-derived emission defaults so `@AutoLog` can use output definitions to choose a smaller generated logging surface.
- Added explicit initializer logging support.

### Changed

- Moved SwiftUI-specific source out of the core `AutoLog` product so non-UI consumers do not link SwiftUI/Combine just to log.
- Treated handled thrown errors as warning events so warning filters can show recovered failures without enabling all success output.
- Reduced generated macro code when builds choose failures-only or timing-free logging paths.

### Documentation

- Added binary-impact measurement notes and follow-up planning for reducing executable size and clean build time.
- Documented the SwiftUI product split and build-time filtering guidance.

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
