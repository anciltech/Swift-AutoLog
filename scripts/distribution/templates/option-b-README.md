# Swift AutoLog

Automatic function logging for Swift apps, with a precompiled runtime.

## Install in Xcode

1. Open your project's **Package Dependencies** and press **+**.
2. Paste `https://github.com/anciltech/Swift-AutoLog-Distribution.git`.
3. Choose **Up to Next Major Version**, starting at **0.10.2**.
4. Add **AutoLog** to the app or framework target that will use the macros.
   Also add **AutoLogSwiftUI** for `Button.log`, `Binding.log`, and view helpers.
5. Build and approve Xcode's **Trust & Enable** prompt for the macro plugin.

No access to the private implementation repository is required.
Requires Xcode 27 (Swift 6.4) or newer for this binary release.
Supports iOS 17+, macOS 15+, and watchOS 11+, including simulators and Intel Macs.

## Install in a Swift package

```swift
// In dependencies:
.package(url: "https://github.com/anciltech/Swift-AutoLog-Distribution.git", from: "0.10.2")

// In your target's dependencies:
.product(name: "AutoLog", package: "Swift-AutoLog-Distribution")
// Optional:
.product(name: "AutoLogSwiftUI", package: "Swift-AutoLog-Distribution")
```

## Use it

Start the runtime once during app startup:

```swift
import AutoLog
import SwiftUI

@main
struct MyApp: App {
  init() {
    AutoLog.start()
  }

  var body: some Scene {
    WindowGroup { ContentView() }
  }
}
```

Annotate the types you want to observe:

```swift
import AutoLog

@AutoLog
struct GreetingService {
  func greeting(for name: String) -> String {
    "Hello, \(name)"
  }
}

// Calling GreetingService().greeting(for: "World") emits a console event.
```

Use `@Log` on individual functions when type-wide logging is too broad.
For SwiftUI interaction logging, add the optional product and import it:

```swift
import AutoLogSwiftUI
import SwiftUI

struct ContentView: View {
  var body: some View {
    Button.log("Greet") {
      _ = GreetingService().greeting(for: "World")
    }
  }
}
```

## CI

Private source credentials are unnecessary. The compiler plugin still needs
macro trust approval. See [Macro trust and CI](docs/MacroTrustAndCI.md) for
Xcode Cloud and command-line build setup.

## Distribution contents

- **AutoLogRuntime**: a static XCFramework downloaded from this repository's
  release assets. Runtime, formatting, configuration, and routing source are
  excluded.
- **AutoLog**: public macro declarations and runtime API re-exports.
- **AutoLogMacro**: macro implementation source, compiled on the developer's Mac.
- **AutoLogSwiftUI**: public SwiftUI convenience wrappers.

This protects runtime source. Macro and SwiftUI wrapper source remain visible.
Swift module interfaces necessarily expose the runtime's public declarations.
Do not add both this package and the private source package to the same target.
See [LICENSE](LICENSE) for the license.
