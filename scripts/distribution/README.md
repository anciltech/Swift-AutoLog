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

The older-toolchain baseline is being verified on complete Xcode installations.
The candidate manifest floor is Swift 6.2; 0.10.2 remains the Swift 6.4 release.
