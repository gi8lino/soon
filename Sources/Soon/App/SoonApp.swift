import SwiftUI

/// The Soon menu bar app entry point.
@main
struct SoonApp: App {
  /// Bridges SwiftUI app lifecycle with AppKit lifecycle hooks.
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  /// Provides the minimal scene hierarchy required by SwiftUI.
  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}
