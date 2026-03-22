import SwiftUI

@main
struct AutoLogSettingsApp: App {
  init() {
    // SPM executables lack an Info.plist, so the process never becomes the
    // active application automatically. Without this call the window draws
    // and shows a blinking cursor, but keyboard events still go to the app
    // that was frontmost before — calling activate() fixes that.
    NSApp.activate()
  }

  var body: some Scene {
    Window("AutoLog Format Settings", id: "main") {
      ContentView()
    }
    .windowResizability(.contentSize)
    .defaultSize(width: 760, height: 540)
  }
}
