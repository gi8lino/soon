import EasyBarCalendarPresentation
import SwiftUI

/// Compact menu bar label for Soon.
struct SoonMenuBarLabelView: View {
  /// Runtime menu bar config.
  private let menuBar = SoonRuntimeConfig.current.menuBar

  /// Renders the configured top-bar label.
  var body: some View {
    HStack(spacing: CGFloat(menuBar.spacing)) {
      if showsConfiguredIcon {
        configuredIcon
      }

      if showsConfiguredDate {
        Text(dateText)
          .monospacedDigit()
      }

      if !hasVisibleContent {
        Image(systemName: "calendar")
      }
    }
  }

  /// Returns the configured icon view.
  @ViewBuilder
  private var configuredIcon: some View {
    switch menuBar.icon.kind {
    case "text":
      Text(iconValue)

    default:
      Image(systemName: iconValue)
    }
  }

  /// Returns whether the configured icon should be shown.
  private var showsConfiguredIcon: Bool {
    return menuBar.icon.enabled && !iconValue.isEmpty
  }

  /// Returns whether the configured date text should be shown.
  private var showsConfiguredDate: Bool {
    return menuBar.date.enabled && !dateFormat.isEmpty
  }

  /// Returns whether at least one configured label part is visible.
  private var hasVisibleContent: Bool {
    return showsConfiguredIcon || showsConfiguredDate
  }

  /// Returns the trimmed configured icon value.
  private var iconValue: String {
    return menuBar.icon.value.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Returns the trimmed configured date format.
  private var dateFormat: String {
    return menuBar.date.format.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Returns the formatted date label.
  private var dateText: String {
    CalendarDateFormatter.string(
      from: Date(),
      calendar: .autoupdatingCurrent,
      dateFormat: dateFormat
    )
  }
}
