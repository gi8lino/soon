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
  lazy var calendar = SoonCalendarService(
    runtimeConfig: SoonRuntimeConfig.current,
    store: store,
    logger: logger.child("calendar_service")
  )

  /// Creates the shared service container.
  private init() {
    store = SoonCalendarStore(logger: logger.child("calendar_store"))
  }
}
