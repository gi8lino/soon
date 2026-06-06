import CoreGraphics
import EasyBarCalendarConfig
import EasyBarCalendarPresentation
import EasyBarShared
import EventKit
import Foundation

/// In-process calendar client for Soon.
///
/// This class intentionally does not use a socket. It owns EventKit directly,
/// observes calendar changes, builds snapshots, and applies them to the shared store.
@MainActor
final class SoonCalendarService {
  /// Bridges EventKit travel-time storage that is not exposed as public Swift API.
  private enum EventTravelTimeBridge {
    /// Key-value coding key used by EventKit for travel time.
    static let key = "travelTime"

    /// Reads positive travel time from one EventKit event.
    static func getSeconds(from event: EKEvent) -> TimeInterval? {
      let selector = NSSelectorFromString(key)
      guard event.responds(to: selector) else { return nil }

      if let value = event.value(forKey: key) as? NSNumber {
        let seconds = value.doubleValue
        return seconds > 0 ? seconds : nil
      }

      return nil
    }

    /// Writes travel time onto one EventKit event.
    static func setSeconds(_ seconds: TimeInterval?, on event: EKEvent) {
      guard let seconds, seconds > 0 else {
        event.setValue(NSNumber(value: 0), forKey: key)
        return
      }

      event.setValue(NSNumber(value: seconds), forKey: key)
    }
  }

  /// Errors raised while mutating calendar events.
  private enum CalendarMutationError: LocalizedError {
    case accessDenied
    case invalidDateRange
    case noWritableCalendar
    case eventNotFound

    /// User-facing error description.
    var errorDescription: String? {
      switch self {
      case .accessDenied:
        return "Calendar access is not available."
      case .invalidDateRange:
        return "The end time must be after the start time."
      case .noWritableCalendar:
        return "No writable calendar is available."
      case .eventNotFound:
        return "The selected appointment could not be found."
      }
    }
  }

  /// Calendar used for user-facing calendar output.
  private static var formatterCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .autoupdatingCurrent
    return calendar
  }

  /// Runtime config used by the service.
  private let runtimeConfig: SoonRuntimeConfig
  /// Store updated by calendar snapshots.
  private let store: SoonCalendarStore
  /// Logger used for service diagnostics.
  private let logger: ProcessLogger
  /// EventKit store owned by the Soon app process.
  private let eventStore = EKEventStore()

  /// Whether the calendar lifecycle is active.
  private var started = false
  /// EventKit change observer token.
  private var observer: NSObjectProtocol?
  /// Last visible month requested by the month popup.
  private var visibleMonth = Calendar.current.startOfDay(for: Date())

  /// Creates one in-process calendar service.
  init(
    runtimeConfig: SoonRuntimeConfig,
    store: SoonCalendarStore,
    logger: ProcessLogger
  ) {
    self.runtimeConfig = runtimeConfig
    self.store = store
    self.logger = logger
  }

  /// Returns whether the in-process calendar service is active.
  var isConnected: Bool {
    return started
  }

  /// Starts calendar observation and loads the first snapshot.
  func start() {
    guard !started else { return }
    guard runtimeConfig.calendar.popupMode != .none else { return }

    started = true
    installCalendarObserver()
    refresh()
  }

  /// Stops calendar observation and clears the store.
  func stop() {
    guard started else { return }

    started = false
    removeCalendarObserver()
    store.clear()
  }

  /// Updates the visible month and refreshes the active snapshot range.
  func focusVisibleMonth(_ visibleMonth: Date) {
    self.visibleMonth = visibleMonth

    guard runtimeConfig.calendar.popupMode == .month else { return }

    refresh()
  }

  /// Rebuilds the current calendar snapshot.
  func refresh() {
    guard started else { return }
    guard runtimeConfig.calendar.popupMode != .none else { return }

    Task { @MainActor [weak self] in
      guard let self else { return }

      await self.requestCalendarAccessIfNeeded()

      guard self.started else { return }
      guard let query = self.makeCurrentQuery() else {
        self.store.clear()
        return
      }

      let snapshot = self.makeSnapshot(for: query)
      self.store.apply(snapshot: snapshot)
    }
  }

  /// Creates one appointment through EventKit.
  func createEvent(
    _ event: CalendarAgentCreateEvent,
    completion: @escaping (_ success: Bool, _ message: String?) -> Void
  ) {
    performMutation(
      label: "create event",
      operation: {
        _ = try createEvent(event)
      },
      completion: completion
    )
  }

  /// Updates one appointment through EventKit.
  func updateEvent(
    _ event: CalendarAgentUpdateEvent,
    completion: @escaping (_ success: Bool, _ message: String?) -> Void
  ) {
    performMutation(
      label: "update event",
      operation: {
        try updateEvent(event)
      },
      completion: completion
    )
  }

  /// Deletes one appointment through EventKit.
  func deleteEvent(
    _ event: CalendarAgentDeleteEvent,
    completion: @escaping (_ success: Bool, _ message: String?) -> Void
  ) {
    performMutation(
      label: "delete event",
      operation: {
        try deleteEvent(event)
      },
      completion: completion
    )
  }

  /// Installs the EventKit change observer.
  private func installCalendarObserver() {
    guard observer == nil else { return }

    observer = NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged,
      object: eventStore,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.logger.info("calendar store changed")
        self?.refresh()
      }
    }
  }

  /// Removes the EventKit change observer.
  private func removeCalendarObserver() {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
      self.observer = nil
    }
  }

  /// Requests Calendar access when permission is still undetermined.
  private func requestCalendarAccessIfNeeded() async {
    guard EKEventStore.authorizationStatus(for: .event) == .notDetermined else {
      return
    }

    await withCheckedContinuation { continuation in
      eventStore.requestFullAccessToEvents { _, _ in
        continuation.resume()
      }
    }
  }

  /// Performs one calendar mutation and refreshes the snapshot on success.
  private func performMutation(
    label: String,
    operation: () throws -> Void,
    completion: (_ success: Bool, _ message: String?) -> Void
  ) {
    do {
      try operation()
      refresh()
      completion(true, nil)
    } catch {
      logger.error(
        "soon calendar \(label) failed",
        .field("error", error.localizedDescription)
      )
      completion(false, error.localizedDescription)
    }
  }

  /// Builds the current query from the configured popup mode.
  private func makeCurrentQuery() -> CalendarAgentQuery? {
    switch runtimeConfig.calendar.popupMode {
    case .month:
      return CalendarRequestFactory.makeMonthSubscribeRequest(
        range: requestedMonthRange(),
        options: runtimeConfig.calendar.presentationMonthRequestOptions
      ).query

    case .upcoming:
      return CalendarRequestFactory.makeUpcomingSubscribeRequest(
        now: Date(),
        options: runtimeConfig.calendar.presentationUpcomingRequestOptions,
        calendar: resolvedCalendar()
      ).query

    case .none:
      return nil
    }
  }

  /// Builds one snapshot for the requested query.
  private func makeSnapshot(for query: CalendarAgentQuery) -> CalendarAgentSnapshot {
    let permissionState = currentPermissionState()
    let generatedAt = Date()

    guard hasCalendarReadAccess else {
      logger.debug(
        "soon calendar snapshot",
        .field("access_granted", false),
        .field("permission_state", permissionState)
      )

      return CalendarAgentSnapshot(
        accessGranted: false,
        permissionState: permissionState,
        generatedAt: generatedAt,
        writableCalendars: [],
        events: [],
        sections: []
      )
    }

    guard query.startDate < query.endDate else {
      logger.warn("soon calendar snapshot skipped invalid range")

      return CalendarAgentSnapshot(
        accessGranted: true,
        permissionState: permissionState,
        generatedAt: generatedAt,
        writableCalendars: writableCalendars(),
        events: [],
        sections: []
      )
    }

    let events = normalizedEvents(for: query)
    let sections = makeSections(query: query, events: events)

    logger.debug(
      "soon calendar snapshot",
      .field("access_granted", true),
      .field("permission_state", permissionState),
      .field("events", events.count),
      .field("sections", sections.count)
    )

    return CalendarAgentSnapshot(
      accessGranted: true,
      permissionState: permissionState,
      generatedAt: generatedAt,
      writableCalendars: writableCalendars(),
      events: events,
      sections: sections
    )
  }

  /// Returns normalized events matching the query.
  private func normalizedEvents(for query: CalendarAgentQuery) -> [CalendarAgentEvent] {
    guard let calendars = calendarsForQuery(query) else {
      return []
    }

    let predicate = eventStore.predicateForEvents(
      withStart: query.startDate,
      end: query.endDate,
      calendars: calendars
    )

    return eventStore.events(matching: predicate)
      .compactMap { event in
        normalizedEvent(from: event, query: query)
      }
      .sorted(by: sortEvents)
  }

  /// Returns calendars matching the include/exclude filters.
  private func calendarsForQuery(_ query: CalendarAgentQuery) -> [EKCalendar]? {
    let allCalendars = eventStore.calendars(for: .event)

    let filtered = allCalendars.filter { calendar in
      CalendarFilterMatcher.matches(
        filterTarget(for: calendar),
        includedTitleTokens: query.includedCalendarNames,
        excludedTitleTokens: query.excludedCalendarNames,
        includedCalendarIDTokens: query.includedCalendarIDs,
        excludedCalendarIDTokens: query.excludedCalendarIDs,
        includedSourceIDTokens: query.includedCalendarSourceIDs,
        excludedSourceIDTokens: query.excludedCalendarSourceIDs
      )
    }

    return filtered
  }

  /// Converts one EventKit event into a shared calendar event model.
  private func normalizedEvent(
    from event: EKEvent,
    query: CalendarAgentQuery
  ) -> CalendarAgentEvent? {
    let sourceCalendar = event.calendar
    let isBirthday = sourceCalendar?.type == .birthday

    if isBirthday && !query.showBirthdays {
      return nil
    }

    let eventIdentifier = isBirthday ? nil : event.eventIdentifier
    let id = stableID(for: event, isBirthday: isBirthday)

    return CalendarAgentEvent(
      id: id,
      eventIdentifier: eventIdentifier,
      title: isBirthday
        ? birthdayTitle(for: event, showAge: query.birthdaysShowAge)
        : normalizedTitle(event.title),
      startDate: event.startDate,
      endDate: event.endDate,
      isAllDay: event.isAllDay,
      calendarID: sourceCalendar?.calendarIdentifier,
      calendarName: sourceCalendar?.title,
      calendarColorHex: colorHex(for: sourceCalendar?.cgColor),
      location: normalizedOptionalText(event.location),
      url: normalizedEventURLText(for: event),
      alertOffsetsSeconds: alertOffsets(for: event),
      isHoliday: isHoliday(event),
      hasAlert: !alertOffsets(for: event).isEmpty,
      travelTimeSeconds: EventTravelTimeBridge.getSeconds(from: event)
    )
  }

  /// Creates one new EventKit event.
  @discardableResult
  private func createEvent(_ draft: CalendarAgentCreateEvent) throws -> String {
    guard hasCalendarReadAccess else {
      throw CalendarMutationError.accessDenied
    }

    guard draft.startDate < draft.endDate else {
      throw CalendarMutationError.invalidDateRange
    }

    let event = EKEvent(eventStore: eventStore)
    event.calendar = try resolvedWritableCalendar(id: draft.calendarID)
    event.title = normalizedTitle(draft.title)
    event.startDate = draft.startDate
    event.endDate = draft.endDate
    event.isAllDay = draft.isAllDay
    event.location = normalizedOptionalText(draft.location)
    EventTravelTimeBridge.setSeconds(draft.travelTimeSeconds, on: event)
    event.alarms = alarms(from: draft.alertOffsetsSeconds)

    try eventStore.save(event, span: .thisEvent, commit: true)

    logger.info(
      "soon calendar event created",
      .field("title", event.title ?? "Untitled"),
      .field("start", draft.startDate),
      .field("end", draft.endDate)
    )

    return event.eventIdentifier ?? ""
  }

  /// Updates one existing EventKit event.
  private func updateEvent(_ draft: CalendarAgentUpdateEvent) throws {
    guard hasCalendarReadAccess else {
      throw CalendarMutationError.accessDenied
    }

    guard draft.startDate < draft.endDate else {
      throw CalendarMutationError.invalidDateRange
    }

    guard let event = eventStore.event(withIdentifier: draft.eventIdentifier) else {
      throw CalendarMutationError.eventNotFound
    }

    event.calendar = try resolvedWritableCalendar(id: draft.calendarID)
    event.title = normalizedTitle(draft.title)
    event.startDate = draft.startDate
    event.endDate = draft.endDate
    event.isAllDay = draft.isAllDay
    event.location = normalizedOptionalText(draft.location)
    EventTravelTimeBridge.setSeconds(draft.travelTimeSeconds, on: event)
    event.alarms = alarms(from: draft.alertOffsetsSeconds)

    try eventStore.save(event, span: .thisEvent, commit: true)

    logger.info(
      "soon calendar event updated",
      .field("event_id", draft.eventIdentifier),
      .field("title", event.title ?? "Untitled")
    )
  }

  /// Deletes one existing EventKit event.
  private func deleteEvent(_ draft: CalendarAgentDeleteEvent) throws {
    guard hasCalendarReadAccess else {
      throw CalendarMutationError.accessDenied
    }

    guard let event = eventStore.event(withIdentifier: draft.eventIdentifier) else {
      throw CalendarMutationError.eventNotFound
    }

    try eventStore.remove(event, span: .thisEvent, commit: true)

    logger.info(
      "soon calendar event deleted",
      .field("event_id", draft.eventIdentifier)
    )
  }

  /// Returns the writable calendar for one optional identifier.
  private func resolvedWritableCalendar(id: String?) throws -> EKCalendar {
    if let id,
      let calendar = eventStore.calendar(withIdentifier: id),
      calendar.allowsContentModifications
    {
      return calendar
    }

    if let calendar = eventStore.defaultCalendarForNewEvents,
      calendar.allowsContentModifications
    {
      return calendar
    }

    if let calendar = eventStore.calendars(for: .event).first(where: \.allowsContentModifications) {
      return calendar
    }

    throw CalendarMutationError.noWritableCalendar
  }

  /// Returns writable calendars available to the composer.
  private func writableCalendars() -> [CalendarAgentWritableCalendar] {
    eventStore.calendars(for: .event)
      .filter { calendar in
        calendar.allowsContentModifications && calendar.type != .birthday
      }
      .sorted { lhs, rhs in
        lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
      }
      .map { calendar in
        CalendarAgentWritableCalendar(
          id: calendar.calendarIdentifier,
          title: calendar.title
        )
      }
  }

  /// Builds rendered sections when a query asks for them.
  private func makeSections(
    query: CalendarAgentQuery,
    events: [CalendarAgentEvent]
  ) -> [CalendarAgentSection] {
    guard
      let sectionStartDate = query.sectionStartDate,
      let sectionDayCount = query.sectionDayCount,
      sectionDayCount > 0
    else {
      return []
    }

    let calendar = resolvedCalendar()
    let startOfSections = calendar.startOfDay(for: sectionStartDate)

    let birthdayEvents = events.filter { event in
      event.id.hasPrefix("birthday-")
    }

    var sections: [CalendarAgentSection] = []

    if query.showBirthdays {
      sections.append(
        CalendarAgentSection(
          id: "birthdays",
          title: query.birthdaysTitle,
          kind: .birthdays,
          items: birthdayEvents.map { event in
            CalendarAgentItem(
              id: event.id,
              time: formatBirthdayDate(event.startDate, format: query.birthdaysDateFormat),
              startDate: event.startDate,
              endDate: event.endDate,
              isAllDay: event.isAllDay,
              title: event.title,
              calendarName: event.calendarName,
              calendarColorHex: event.calendarColorHex,
              location: event.location,
              url: event.url,
              travelTimeSeconds: event.travelTimeSeconds
            )
          }
        )
      )
    }

    let regularEvents = events.filter { !$0.id.hasPrefix("birthday-") }

    for offset in 0..<sectionDayCount {
      guard
        let day = calendar.date(byAdding: .day, value: offset, to: startOfSections),
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)
      else {
        continue
      }

      let effectiveStart = max(day, sectionStartDate)
      let dayEvents = regularEvents.filter { event in
        event.startDate < nextDay && event.endDate > effectiveStart
      }

      let title: String
      let kind: CalendarAgentSectionKind

      if calendar.isDateInToday(day) {
        title = "Today"
        kind = .today
      } else if calendar.isDateInTomorrow(day) {
        title = "Tomorrow"
        kind = .tomorrow
      } else {
        title = formatDayTitle(day)
        kind = .future
      }

      let items: [CalendarAgentItem]
      if dayEvents.isEmpty {
        items = [
          CalendarAgentItem(
            id: "empty-\(offset)",
            time: "",
            title: query.emptyText
          )
        ]
      } else {
        items = dayEvents.map { event in
          CalendarAgentItem(
            id: event.id,
            time: event.isAllDay ? "All day" : formatEventTime(event.startDate),
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            endTime: formattedEndTime(for: event),
            title: event.title,
            calendarName: event.calendarName,
            calendarColorHex: event.calendarColorHex,
            location: event.location,
            url: event.url,
            travelTimeSeconds: event.travelTimeSeconds
          )
        }
      }

      sections.append(
        CalendarAgentSection(
          id: "events-\(offset)",
          title: title,
          kind: kind,
          items: items
        )
      )
    }

    return sections
  }

  /// Returns the month grid date range around the current visible month.
  private func requestedMonthRange() -> DateInterval {
    let calendar = resolvedCalendar()
    let monthStart = CalendarMonthRangeBuilder.startOfMonth(visibleMonth, calendar: calendar)

    return CalendarMonthRangeBuilder.visibleGridRange(for: monthStart, calendar: calendar)
      ?? DateInterval(
        start: monthStart,
        end:
          calendar.date(byAdding: .month, value: 1, to: monthStart)
          ?? monthStart.addingTimeInterval(31 * 86_400)
      )
  }

  /// Returns the calendar used for request ranges.
  private func resolvedCalendar() -> Calendar {
    var calendar = Calendar.current

    if let firstWeekday = runtimeConfig.calendar.month.popup.firstWeekday {
      calendar.firstWeekday = firstWeekday
    }

    return calendar
  }

  /// Returns whether Calendar read access is available.
  private var hasCalendarReadAccess: Bool {
    switch EKEventStore.authorizationStatus(for: .event) {
    case .authorized, .fullAccess:
      return true
    default:
      return false
    }
  }

  /// Returns the current Calendar permission state.
  private func currentPermissionState() -> String {
    switch EKEventStore.authorizationStatus(for: .event) {
    case .notDetermined:
      return "not_determined"
    case .restricted:
      return "restricted"
    case .denied:
      return "denied"
    case .authorized:
      return "authorized"
    case .fullAccess:
      return "full_access"
    case .writeOnly:
      return "write_only"
    @unknown default:
      return "unknown"
    }
  }

  /// Returns one stable ID for an EventKit event row.
  private func stableID(for event: EKEvent, isBirthday: Bool) -> String {
    let base = event.eventIdentifier ?? event.calendarItemIdentifier

    let prefix = isBirthday ? "birthday" : "event"
    return "\(prefix)-\(base)-\(Int(event.startDate.timeIntervalSince1970))"
  }

  /// Returns alert lead times in seconds before the event.
  private func alertOffsets(for event: EKEvent) -> [TimeInterval] {
    event.alarms?.compactMap { alarm in
      guard alarm.absoluteDate == nil else { return nil }

      let offset = alarm.relativeOffset
      guard offset <= 0 else { return nil }

      return abs(offset)
    } ?? []
  }

  /// Builds EventKit alarms from configured lead times.
  private func alarms(from offsets: [TimeInterval]) -> [EKAlarm]? {
    guard !offsets.isEmpty else { return nil }

    return offsets.map { offset in
      EKAlarm(relativeOffset: -abs(offset))
    }
  }

  /// Returns whether an event likely belongs to a holiday calendar.
  private func isHoliday(_ event: EKEvent) -> Bool {
    let calendarName = event.calendar?.title.lowercased() ?? ""
    return calendarName.contains("holiday")
      || calendarName.contains("holidays")
      || calendarName.contains("feiertag")
      || calendarName.contains("feiertage")
  }

  /// Returns one birthday title, optionally with age appended.
  private func birthdayTitle(for event: EKEvent, showAge: Bool) -> String {
    let rawTitle = normalizedTitle(event.title)
    let normalized = normalizedBirthdayTitle(rawTitle)

    guard showAge, let age = extractedAge(from: rawTitle) else {
      return normalized
    }

    return "\(normalized) (\(age))"
  }

  /// Removes one trailing age suffix from a birthday title when present.
  private func normalizedBirthdayTitle(_ title: String) -> String {
    guard
      let open = title.lastIndex(of: "("),
      let close = title.lastIndex(of: ")"),
      open < close
    else {
      return title
    }

    let suffix = title[title.index(after: open)..<close]
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard Int(suffix) != nil else {
      return title
    }

    return title[..<open].trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Extracts an age suffix from one birthday event title.
  private func extractedAge(from title: String) -> Int? {
    guard
      let open = title.lastIndex(of: "("),
      let close = title.lastIndex(of: ")"),
      open < close
    else {
      return nil
    }

    let value = title[title.index(after: open)..<close]
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return Int(value)
  }

  /// Normalizes one optional title into display text.
  private func normalizedTitle(_ value: String?) -> String {
    guard let value else { return "Untitled" }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "Untitled" : trimmed
  }

  /// Normalizes optional text and drops empty strings.
  private func normalizedOptionalText(_ value: String?) -> String? {
    guard let value else { return nil }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  /// Normalizes an optional URL into transport-safe text.
  private func normalizedOptionalURLText(_ value: URL?) -> String? {
    normalizedOptionalText(value?.absoluteString)
  }

  /// Returns the best URL attached to one event.
  private func normalizedEventURLText(for event: EKEvent) -> String? {
    if let directURL = normalizedOptionalURLText(event.url) {
      return directURL
    }

    return firstURLText(in: [event.location, event.notes])
  }

  /// Extracts the first URL from one of the provided text fields.
  private func firstURLText(in values: [String?]) -> String? {
    guard
      let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
      )
    else {
      return nil
    }

    for value in values {
      guard let text = normalizedOptionalText(value) else { continue }
      let range = NSRange(text.startIndex..<text.endIndex, in: text)
      let matches = detector.matches(in: text, options: [], range: range)

      if let url = matches.first?.url?.absoluteString {
        return url
      }
    }

    return nil
  }

  /// Maps one EventKit calendar into the shared filter target model.
  private func filterTarget(for calendar: EKCalendar) -> CalendarFilterTarget {
    CalendarFilterTarget(
      title: calendar.title,
      identifier: calendar.calendarIdentifier,
      sourceTitle: calendar.source.title,
      sourceIdentifier: calendar.source.sourceIdentifier
    )
  }

  /// Sorts events consistently.
  private func sortEvents(lhs: CalendarAgentEvent, rhs: CalendarAgentEvent) -> Bool {
    if lhs.startDate != rhs.startDate {
      return lhs.startDate < rhs.startDate
    }

    if lhs.endDate != rhs.endDate {
      return lhs.endDate < rhs.endDate
    }

    return lhs.id < rhs.id
  }

  /// Formats one event time for popup display.
  private func formatEventTime(_ date: Date) -> String {
    CalendarDateFormatter.string(
      from: date,
      calendar: Self.formatterCalendar,
      dateFormat: "HH:mm"
    )
  }

  /// Returns one rendered end time for timed events when it differs from the start.
  private func formattedEndTime(for event: CalendarAgentEvent) -> String? {
    guard !event.isAllDay, event.endDate > event.startDate else { return nil }

    let startTime = formatEventTime(event.startDate)
    let endTime = formatEventTime(event.endDate)
    guard startTime != endTime else { return nil }

    return endTime
  }

  /// Formats one day header for popup display.
  private func formatDayTitle(_ date: Date) -> String {
    CalendarDateFormatter.string(
      from: date,
      calendar: Self.formatterCalendar,
      dateFormat: "dd.MM.yyyy"
    )
  }

  /// Formats one birthday date using the configured format.
  private func formatBirthdayDate(_ date: Date, format: String) -> String {
    CalendarDateFormatter.string(
      from: date,
      calendar: Self.formatterCalendar,
      dateFormat: format
    )
  }

  /// Converts one calendar color into a hex string.
  private func colorHex(for cgColor: CGColor?) -> String? {
    guard let cgColor else { return nil }

    guard
      let color = cgColor.converted(
        to: CGColorSpace(name: CGColorSpace.sRGB)!,
        intent: .defaultIntent,
        options: nil
      )
    else {
      return nil
    }

    guard let components = color.components else { return nil }

    let values: [CGFloat]
    if components.count >= 3 {
      values = components
    } else if components.count == 2 {
      values = [components[0], components[0], components[0], components[1]]
    } else {
      return nil
    }

    let red = Int(max(0, min(255, round(values[0] * 255))))
    let green = Int(max(0, min(255, round(values[1] * 255))))
    let blue = Int(max(0, min(255, round(values[2] * 255))))

    return String(format: "#%02X%02X%02X", red, green, blue)
  }
}
