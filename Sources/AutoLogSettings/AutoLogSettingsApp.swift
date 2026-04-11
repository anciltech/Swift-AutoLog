import SwiftUI
import AutoLogSettingsUI

// NSApp (NSApplication!) is nil during App.init() — NSApplication.shared is
// only created after SwiftUI's @main entry point constructs the App struct.
// NSApplicationDelegateAdaptor defers our activation call to
// applicationDidFinishLaunching, where NSApp is guaranteed non-nil.
private final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    // SPM executables have no Info.plist, so the process never becomes the
    // active application automatically. The window appears and shows a
    // blinking cursor internally, but keystrokes still go to whatever app
    // was frontmost before. activate() hands us the system keyboard focus.
    NSApp.activate()
  }
}

@main
struct AutoLogSettingsApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Window("AutoLog Format Settings", id: "main") {
      AutoLogOutputSettingsView()
    }
    .windowResizability(.contentSize)
    .defaultSize(width: 760, height: 540)
  }
}
