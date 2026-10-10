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

## Verified publication

Release 0.11.0 is public. Anonymous source consumers passed on Swift 6.2 and
6.3.2 in [the hosted workflow](https://github.com/anciltech/Swift-AutoLog/actions/runs/38050880347),
and locally on Xcode 27 / Swift 6.4. Both minimum-toolchain lanes passed source
tests and all four iOS/watchOS Release links in
[the source baseline](https://github.com/anciltech/Swift-AutoLog/actions/runs/38050880397).
The regular CI source build/tests passed but its separate watch fixture initially
failed because the runner omitted watchOS 26.0. CI now installs the compatible
baseline watch platform before using that fixture, matching the passing matrix.

## Retirement and local verification

The former `anciltech/Swift-AutoLog-Distribution` repository was deleted after
local consumers migrated and its complete Git mirror/release archives were saved
by the demo workspace. GitHub confirmed deletion; authenticated and anonymous API
lookups return HTTP 404. Historical local checkouts are not active publishers.

Xcode 27 / Swift 6.4 functional verification passed: 209 runtime tests and 109
macro tests. The full local suite compiled but was interrupted in performance
measurements on an overloaded host; the minimum-toolchain CI lanes ran the full
source suite successfully. No local performance claim is made.
