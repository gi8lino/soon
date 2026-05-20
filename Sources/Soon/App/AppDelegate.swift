import AppKit

/// AppKit delegate that forwards lifecycle events into `AppController`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  /// Main app controller.
  private let appController = AppController()

  /// Starts Soon after launch.
  func applicationDidFinishLaunching(_ notification: Notification) {
    appController.start()
  }

  /// Stops Soon before termination.
  func applicationWillTerminate(_ notification: Notification) {
    appController.stop()
  }
}
