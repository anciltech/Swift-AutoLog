import AutoLogSwiftUI
import SwiftUI

@main
struct WatchTaskLogReleaseFixtureApp: App {
  @State private var reloadID = "initial"

  var body: some Scene {
    WindowGroup {
      VStack {
        Text("AutoLog Watch")
        Button("Reload") {
          reloadID = UUID().uuidString
        }
      }
      .taskLog("Initial Load") {
        await Task.yield()
      }
      .taskLog(.api("Reload"), id: reloadID) {
        await Task.yield()
      }
    }
  }
}
