# Macro Trust and CI

Configure local and CI builds so Xcode can expand Swift AutoLog macros.

## Overview

Swift AutoLog ships Swift macros. Those macros are compiler plugins, so Xcode
requires a per-machine trust decision before the plugin executable can run.
That trust gate belongs to the consuming Xcode installation or CI host. A
package author cannot pre-trust `AutoLogMacro` from `Package.swift`, and
checking in local Xcode trust state is brittle because it is tied to machine and
fingerprint state.

AutoLog can make this smoother by keeping macro target names stable, shipping
versioned releases, and documenting the setup. Consuming apps should pin
released versions and commit `Package.resolved` so macro fingerprints change
only when the app intentionally updates dependencies.

If a headless build fails with `Macro "AutoLogMacro" from package
"Swift-AutoLog" must be enabled before it can be used`, the build host needs one
of the CI setup paths below.

## Local Xcode Builds

When Xcode first builds a target that imports AutoLog macros, approve the
`Swift-AutoLog` prompt with **Trust & Enable**. Xcode may prompt again after
package updates, package cache resets, Xcode upgrades, different machines, or
branch dependencies whose source changes without a version update.

If the prompt keeps returning unexpectedly, check that the app is not depending
on a moving branch, a retagged release, or a frequently reset package cache.

## Xcode Cloud

Xcode Cloud builds are headless, so there is no interactive **Trust & Enable**
button. Add a custom script to the consuming app repository at
`ci_scripts/ci_post_clone.sh` before the build starts:

```bash
#!/bin/zsh
set -euo pipefail

defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
```

Commit the script as executable:

```bash
chmod +x ci_scripts/ci_post_clone.sh
```

The `ci_post_clone.sh` script runs before Xcode Cloud invokes the build, so the
build host has the macro validation preference before package resolution and
macro expansion need it.

## Command-Line xcodebuild CI

For CI systems where the workflow owns the `xcodebuild` command, pass
`-skipMacroValidation` on trusted jobs:

```bash
xcodebuild \
  -project MyApp.xcodeproj \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -skipMacroValidation \
  build
```

If the same project also uses Swift package build plugins, add
`-skipPackagePluginValidation` to that command as well:

```bash
xcodebuild \
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -skipMacroValidation \
  -skipPackagePluginValidation \
  build
```

Both flags bypass Xcode's interactive validation for the build host. Use them
only on CI workflows with reviewed dependencies, pinned package versions, and a
checked-in `Package.resolved` file.

## What AutoLog Maintainers Can Control

AutoLog should keep the macro implementation target name stable, publish
versioned tags, avoid moving tags, and keep macro expansion behavior easy to
audit. Those choices reduce surprise prompts and make the trust decision less
ambiguous, but they do not remove Xcode's per-machine macro trust requirement.
