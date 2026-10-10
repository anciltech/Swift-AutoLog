# Open-source release — 2026-10-10

`anciltech/Swift-AutoLog` is the canonical MIT-licensed source repository.
Release 0.11.0 includes all runtime, macro, SwiftUI and settings implementations;
there is no binary runtime or separate distribution repository.

## Migration

Use `https://github.com/anciltech/Swift-AutoLog.git` at 0.11.0. Change SwiftPM
product package identities from `swift-autolog-distribution` to `swift-autolog`.
Keep `AutoLog` / `AutoLogSwiftUI` products and imports. Replace vendored or
machine-local copies in apps with the tagged source dependency; the library demo
retains its local source checkout for development. Resolve again and review the
new macro revision before updating CI trust. Required upstream MIT notices remain.

## Validation

Run `swift test` and `scripts/source-consumer-smoke.sh`. The consumer checks
bootstrap, macro expansion, failure-only routing, SwiftUI helpers and caller
actor isolation. After tagging, run the same script with `--package-url
https://github.com/anciltech/Swift-AutoLog.git --version 0.11.0` and Git credentials
disabled. `scripts/source-platform-smoke.sh` links iOS and watchOS device and
simulator Release variants. These are compile/link checks, not physical-device tests.

The minimum-toolchain workflow now tests source consumers. The hosted workflow
installs the public source release without saved credentials. Binary build,
generation, validation and publication tools have been removed.
