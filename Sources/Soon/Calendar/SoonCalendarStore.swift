import Combine
import EasyBarCalendarUI
import EasyBarShared
import Foundation

/// Shared calendar snapshot store used by Soon's reusable calendar popups.
@MainActor
final class SoonCalendarStore: CalendarMonthPopupStore, CalendarUpcomingPopupStore {
  /// Logger used for store diagnostics.
  let logger: ProcessLogger

  /// Latest snapshot returned by the embedded calendar runtime.
  @Published private(set) var snapshot: CalendarAgentSnapshot?

  /// Flat event list used by the month and upcoming popups.
  @Published private(set) var events: [CalendarAgentEvent] = []

  /// Calendar used for range calculations.
  private let calendar = Calendar.current

  /// Creates the store.
  init(logger: ProcessLogger) {
    self.logger = logger
  }

  /// Applies one calendar snapshot to the shared store.
  func apply(snapshot: CalendarAgentSnapshot) {
    logger.debug(
      "soon calendar applied snapshot",
      .field("access_granted", snapshot.accessGranted),
      .field("permission_state", snapshot.permissionState),
      .field("events", snapshot.events.count)
    )

    self.snapshot = snapshot
    events = snapshot.events.sorted(by: sortedEvents)
  }

  /// Clears the current calendar snapshot.
  func clear() {
    logger.debug("soon calendar cleared")
    snapshot = nil
    events = []
  }

  /// Returns all events overlapping the inclusive day range.
  func eventsInRange(from startDate: Date, to endDate: Date) -> [CalendarAgentEvent] {
    let startOfDay = calendar.startOfDay(for: startDate)
    let endDayStart = calendar.startOfDay(for: endDate)
    let endExclusive =
      calendar.date(byAdding: .day, value: 1, to: endDayStart)
      ?? endDayStart.addingTimeInterval(86_400)

    return events.filter { event in
      event.startDate < endExclusive && event.endDate > startOfDay
    }
  }

  /// Returns whether one day has at least one event.
  func hasEvents(on date: Date) -> Bool {
    let startOfDay = calendar.startOfDay(for: date)
    let endExclusive =
      calendar.date(byAdding: .day, value: 1, to: startOfDay)
      ?? startOfDay.addingTimeInterval(86_400)

    return events.contains { event in
      event.startDate < endExclusive && event.endDate > startOfDay
    }
  }

  /// Sorts calendar events consistently for display.
  private func sortedEvents(lhs: CalendarAgentEvent, rhs: CalendarAgentEvent) -> Bool {
    if lhs.startDate != rhs.startDate {
      return lhs.startDate < rhs.startDate
    }

    if lhs.endDate != rhs.endDate {
      return lhs.endDate < rhs.endDate
    }

    return lhs.id < rhs.id
  }
}
