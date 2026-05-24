import EasyBarShared
import Foundation

/// Shared app services used by the menu bar UI and app controller.
@MainActor
final class SoonServices: ObservableObject {
  /// Shared service container.
  static let shared = SoonServices()

  /// Root logger shared by Soon services.
  let logger = ProcessLogger(label: "soon")

  /// Shared calendar snapshot store.
  let store: SoonCalendarStore

  /// Shared in-process calendar service.
  private(set) var calendar: SoonCalendarService

  /// Creates the shared service container.
  private init() {
    store = SoonCalendarStore(logger: logger.child("calendar_store"))
    calendar = SoonCalendarService(
      runtimeConfig: SoonRuntimeConfig.current,
      store: store,
      logger: logger.child("calendar_service")
    )
  }

  /// Recreates services that depend on the runtime config.
  func reload(runtimeConfig: SoonRuntimeConfig) {
    calendar.stop()
    calendar = SoonCalendarService(
      runtimeConfig: runtimeConfig,
      store: store,
      logger: logger.child("calendar_service")
    )
  }
}
