# Protected runtime release tools

These are the canonical distribution tools. The demo repository's `scripts/`
commands delegate here. By default scratch files are under this package's
`.build`; set `AUTOLOG_DISTRIBUTION_WORKSPACE` to use another workspace build
root. All scripts still accept their existing command-line arguments.

`build-option-b-runtime-xcframework.sh` needs Xcode and XcodeGen.
`prepare-option-b-distribution.sh` generates the public shim, macros, SwiftUI
wrappers, and binary target. `validate-option-b-distribution.sh` rejects runtime
source in a release package. `option-b-distribution-smoke.sh` checks macro
expansion and runtime events while disabling saved HTTP credentials.
`option-b-platform-smoke.sh` checks iOS/watchOS device and simulator Release
links. `publish-option-b-distribution.sh` publishes only after binary checks and
then verifies anonymous consumption; run it only when publication is authorized.

The verified minimum is Swift 6.2 / Xcode 26, tested from Xcode 26.0.1.
Release 0.10.3 uses the baseline-built runtime; 0.10.2 retains its Swift 6.4 requirement.

The binary module is `AutoLogCore`, re-exported by `AutoLog`. It deliberately
avoids the public `AutoLogRuntime` type name: Swift 6.2/6.3 text-interface import
otherwise resolves module-qualified types against the struct and fails. The
consumer check also returns a non-Sendable reference from caller-isolated async
closures, exercising the API that requires Swift 6.2.

The publisher rejects runtimes whose text-interface headers were emitted by a
compiler outside the Swift 6.2 series. This prevents rebuilding on a newer local
Xcode from silently raising the advertised minimum. Other compilers may build
comparison artifacts in CI, but those artifacts cannot be published by this tool.

The current customer release is 0.10.3 with tools 6.2. Use `--version VERSION`
when preparing a different release; the generated README uses that version.
The complete older binary matrix passed before publication.

Xcode 26.0.1 runs on macOS 15. GitHub removed its watchOS 26.0 platform
components from the image, so the workflow installs that platform explicitly
and selects Xcode on the disposable runner before building. The local scripts
continue to use per-process Xcode selection without changing the user's default.

The platform download omits `-buildVersion`: Xcode 26.0.1 rejects the numeric
26.0 selector despite offering a compatible default. Simulator enumeration is
performed first, following the runner maintainers' initialization workaround.

The publisher extracts and validates the exact ZIP it will upload. Its compiler
check and customer smoke use that extracted framework, so a mismatched adjacent
framework cannot hide a newer binary inside the hosted archive.

`Published Customer Baseline` verifies actual release 0.10.3 installation on
Swift 6.2 and 6.3.2 with Git configuration, SwiftPM Keychain, and netrc disabled.
The release publisher separately performs the anonymous Xcode 27 check.
