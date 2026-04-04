# Computed Property And Accessor Macro Support

## Goal

Add first-class `Swift-AutoLog` support for computed properties and explicit
accessors so logging can be attached to:

- get-only computed properties via property-level `@Log` / `@Omit`
- explicit `get` / `set` accessors via accessor-level `@Log` / `@Omit`
- `@AutoLog` shorthand auto-instrumentation for get-only computed properties

## Status

- [x] Align package dependencies with `swift-syntax` 603 so the macro layer can
  target computed-property and accessor body expansions.
- [ ] Generalize `Log` / `Omit` expansion from functions to accessors.
- [ ] Add `@AutoLog` support for shorthand get-only computed properties.
- [ ] Update public docs and runtime tests with computed-property examples.

## Notes

- Explicit accessor blocks will be treated as opt-in in the first release:
  users annotate `get` / `set` directly rather than relying on `@AutoLog` to
  rewrite nested accessors.
- The implementation should reject stored-property observers such as
  `willSet` / `didSet` for now with a focused diagnostic instead of silently
  generating misleading logs.
