import AppKit
import EasyBarShared
import Foundation

/// App-level controller for the Soon menu bar process.
@MainActor
final class AppController {
  /// Shared Soon services.
  private let services = SoonServices.shared
  /// Floating shared config error window.
  private let configErrorWindowController = SoonConfigErrorWindowController()
  /// Single-instance guard for the app process.
  private var instanceGuard: SingleInstanceGuard? = SingleInstanceGuard()
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

    presentLoadFailureIfNeeded(
      SoonRuntimeConfig.lastLoadFailure,
      context: .initialLoad,
      configPath: runtimeConfig.configPath
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
      minimumLevel: runtimeConfig.loggingLevel,
      fileLoggingEnabled: runtimeConfig.loggingEnabled,
      fileLoggingPath: URL(fileURLWithPath: runtimeConfig.loggingDirectory)
        .appendingPathComponent("soon.out")
        .path
    )
  }

  /// Reloads the runtime config and rebuilds the app UI in place.
  private func reloadConfig() {
    let loadResult = SoonRuntimeConfig.reloadCurrent()
    let runtimeConfig = loadResult.config

    configureLogging(runtimeConfig: runtimeConfig)

    statusItemController?.stop()
    statusItemController = nil

    services.reload(runtimeConfig: runtimeConfig)
    services.calendar.start()
    statusItemController = SoonStatusItemController(
      services: services,
      onReloadConfig: { [weak self] in
        self?.reloadConfig()
      }
    )

    presentLoadFailureIfNeeded(
      loadResult.failure,
      context: .reloadKeptPreviousConfig,
      configPath: runtimeConfig.configPath
    )
  }

  /// Shows or closes the shared config error window based on the current load failure.
  private func presentLoadFailureIfNeeded(
    _ failure: SoonConfigError?,
    context: SoonConfigLoadFailureContext,
    configPath: String
  ) {
    guard let failure else {
      configErrorWindowController.close()
      return
    }

    configErrorWindowController.present(
      error: failure,
      context: context,
      configPath: configPath,
      onReload: { [weak self] in
        self?.reloadConfig()
      }
    )
  }

  /// Acquires the single-instance lock for Soon.
  private func acquireInstanceLock(runtimeConfig: SoonRuntimeConfig) -> Bool {
    let guardInstance =
      instanceGuard
      ?? {
        let guardInstance = SingleInstanceGuard()
        instanceGuard = guardInstance
        return guardInstance
      }()

    switch guardInstance.acquireLock(
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
