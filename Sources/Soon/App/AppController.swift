import AppKit
import EasyBarShared
import Foundation

/// App-level controller for the Soon menu bar process.
@MainActor
final class AppController {
  /// Shared Soon services.
  private let services = SoonServices.shared
  /// Single-instance guard for the app process.
  private let instanceGuard = SingleInstanceGuard()
  /// Native status item controller.
  private var statusItemController: SoonStatusItemController?

  /// Starts Soon.
  func start() {
    let runtimeConfig = SoonRuntimeConfig.current

    configureLogging(runtimeConfig: runtimeConfig)

    guard acquireInstanceLock(runtimeConfig: runtimeConfig) else {
      terminateApplication()
    }

    NSApp.setActivationPolicy(.accessory)

    services.calendar.start()
    statusItemController = SoonStatusItemController(
      services: services,
      onReloadConfig: { [weak self] in
        self?.reloadConfig()
      }
    )
  }

  /// Stops Soon.
  func stop() {
    statusItemController?.stop()
    statusItemController = nil

    services.calendar.stop()
  }

  /// Configures process logging from the Soon runtime config.
  private func configureLogging(runtimeConfig: SoonRuntimeConfig) {
    services.logger.configureRuntimeLogging(
      minimumLevel: runtimeConfig.loggingDebugEnabled ? .debug : .info,
      fileLoggingEnabled: runtimeConfig.loggingEnabled,
      fileLoggingPath: URL(fileURLWithPath: runtimeConfig.loggingDirectory)
        .appendingPathComponent("soon.out")
        .path
    )
  }

  /// Relaunches Soon so the latest config is loaded everywhere.
  private func reloadConfig() {
    let config = NSWorkspace.OpenConfiguration()
    let appURL = Bundle.main.bundleURL

    NSWorkspace.shared.openApplication(at: appURL, configuration: config) { [weak self] _, error in
      Task { @MainActor in
        guard let self else { return }

        if let error {
          self.services.logger.error(
            "soon failed to relaunch for config reload",
            .field("error", error.localizedDescription)
          )
          return
        }

        NSApp.terminate(nil)
      }
    }
  }

  /// Acquires the single-instance lock for Soon.
  private func acquireInstanceLock(runtimeConfig: SoonRuntimeConfig) -> Bool {
    switch instanceGuard.acquireLock(
      processName: "soon",
      directory: runtimeConfig.lockDirectory
    ) {
    case .acquired:
      return true

    case .alreadyRunning(let lockPath):
      services.logger.warn(
        "soon already running",
        .field("lock_path", lockPath)
      )
      return false

    case .failed(let lockPath, let reason):
      services.logger.error(
        "soon failed to acquire instance lock",
        .field("lock_path", lockPath),
        .field("reason", reason)
      )
      return false
    }
  }

  /// Terminates the application immediately.
  private func terminateApplication() -> Never {
    NSApp.terminate(nil)
    fatalError("Application should have terminated")
  }
}
