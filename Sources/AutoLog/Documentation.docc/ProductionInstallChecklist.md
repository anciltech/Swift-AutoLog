# Production Install Checklist

Use this checklist before enabling Swift AutoLog in a production target.

## Checklist

1. Add the `AutoLog` product to the app, framework, extension, or package target
   that owns the behavior you want to observe.
2. Approve the package macro trust prompt in Xcode or in the CI environment.
3. Call `AutoLog.start()` once during startup. In app extensions, call it from
   that extension's entry point instead of assuming the host app bootstrap ran.
4. Mark app-owned view models, services, use cases, repositories, and data
   sources with ``AutoLog(using:)``.
5. Keep framework adapters, delegate callbacks, and very hot loops targeted with
   ``Log(using:)`` instead of broad type-level logging.
6. For external telemetry, define an ``AutoLogOutput`` with
   ``AutoLogParameterPrivacy/omit`` or a reviewed allow-list.
7. Add one route sink per backend only after the no-sink quick start is working.
   See <doc:BackendSinkExamples>.
8. For production failure diagnostics, prefer explicit source annotations such
   as `@AutoLog(emit: .failures, measure: false)` until the customer build
   system proves `AUTOLOG_MACRO_EMIT` and `AUTOLOG_MACRO_MEASURE` reach macro
   expansion.
9. Keep `AutoLogSwiftUI`, `AutoLogSettingsUI`, and `AutoLogSettings` out of
   production targets unless the app intentionally ships those surfaces.
10. Run the release checks:

   ```bash
   swift package --package-path AutoLogSourceCode/swift-autolog describe
   scripts/customer-adoption-smoke.sh
   ```

   For package source changes, also run:

   ```bash
   swift test --package-path AutoLogSourceCode/swift-autolog
   ```

## Quick Start Gate

The first production gate is intentionally plain:

```swift
import AutoLog

AutoLog.start()

@AutoLog
struct PaymentService {
  func submit(orderID: String) async throws {
    try await api.submit(orderID: orderID)
  }
}
```

Once that path compiles and emits console events, add route sinks or explicit
production `emit:` profiles.
