# Computed Property Marker Support

## Goal

Remove the current compiler error for no-argument `@Omit` on computed
properties while keeping public docs aligned with the actual toolchain
capabilities available on April 4, 2026.

## Status

- [x] Align package dependencies with `swift-syntax` 603 so the macro layer can
  be evaluated against newer property-body macro support.
- [x] Allow no-argument `@Omit` to attach to computed properties as a peer
  marker without generating code.
- [x] Confirm `@AutoLog` still does not auto-instrument computed properties on
  the current toolchain.
- [x] Update public docs and runtime tests with computed-property marker
  examples.

## Notes

- True property or accessor body instrumentation remains blocked by the current
  compiler behavior in this workspace:
  - `@Log var value: Int { ... }` still fails with `'body' macro cannot be
    attached to property`
  - `@Log get { ... }` still fails because accessors are not expanded as
    supported body targets in the shipped toolchain
- The shipped behavior is intentionally conservative:
  - `@Omit` without traits is valid on methods and computed properties
  - `@Omit(.result)` and other trait-based forms remain function-only
  - computed properties remain outside `@AutoLog` member-attribute rewriting
