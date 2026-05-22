# AutoLog Binary Impact Reduction Plan

Date: 2026-05-20

## Goal

Reduce the fixed binary-size and clean-build impact of adopting `AutoLog`
without removing the SwiftUI convenience APIs that make the demo ergonomic.

## Todos

- [x] Split SwiftUI helpers into a dedicated `AutoLogSwiftUI` product so
  non-UI consumers can depend on core `AutoLog` without linking SwiftUI,
  Combine, and the button/lifecycle helper extensions.
- [x] Keep the public SwiftUI call shapes intact for opt-in consumers:
  `Button.log`, `Binding.log`, `.onAppearLog`, `.taskLog`, `.onChangeLog`,
  `.onReceiveLog`, `.refreshableLog`, and `.onSubmitLog`.
- [x] Update the demo app to import `AutoLogSwiftUI` in SwiftUI files that use
  those helpers while keeping macro/runtime imports on `AutoLog`.
- [x] Update package docs to explain when to import `AutoLog` versus
  `AutoLogSwiftUI`.
- [x] Extend the impact probe so it measures core `AutoLog` separately from the
  opt-in SwiftUI helper product.
- [x] Rerun package metadata, tests, and the impact probe to capture the new
  size/build numbers.
- [ ] Consider a follow-up split for formatter/failure-context/settings code if
  the core product still has too much fixed footprint.
- [x] Add a follow-up error-only macro compile-time option that avoids
  generating success/start event machinery for projects that only want thrown
  error instrumentation.
- [x] Add typed-array compile-time emission syntax, for example
  `@AutoLog(emit: [.failures, .warnings])`, so warning and failure paths can be
  selected without string parsing at call sites.
- [x] Extend the impact probe with stripped executable bytes and compile-time
  `emit:` variants so runtime filtering and generated-code pruning can be
  compared directly.
- [ ] Add a build-time profile input that plain `@AutoLog` can read during
  macro expansion, allowing production targets to inherit a default emission
  policy without changing every annotation.
- [x] Add `AutoLogConfiguration.derivedBuildConfiguration` so enabled output
  `eventTypes` produce the default build-time emission ceiling from the same
  output definition.
- [ ] Consider a follow-up split for the macro declarations and source helpers
  so non-macro consumers can use interaction propagation without building the
  `swift-syntax` macro plugin.
- [ ] Add warm incremental-build timing after touching a logged source file so
  clean-build cost and day-to-day edit/build cost are tracked separately.

## Current First Step

Start with the `AutoLogSwiftUI` split. It has the clearest binary-size upside
and should be source-compatible at call sites once SwiftUI consumers import the
new product.
