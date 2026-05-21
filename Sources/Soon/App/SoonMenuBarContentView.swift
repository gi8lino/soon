import AppKit
import EasyBarCalendarConfig
import EasyBarCalendarUI
import SwiftUI

/// Main calendar panel content for Soon.
struct SoonMenuBarContentView: View {
  /// Shared app services.
  @EnvironmentObject private var services: SoonServices

  /// Floating event composer controller.
  @StateObject private var composerPanel = SoonComposerPanelController()

  /// Runtime config used to choose the calendar surface.
  private let runtimeConfig = SoonRuntimeConfig.current

  /// Width used by the selected calendar surface.
  private var panelWidth: CGFloat {
    runtimeConfig.calendar.popupSurfaceSize.width
  }

  /// Height used by the selected calendar surface.
  private var panelHeight: CGFloat {
    runtimeConfig.calendar.popupSurfaceSize.height
  }

  /// Renders the configured calendar surface.
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if services.store.snapshot?.accessGranted == false {
        permissionWarningView
      }

      calendarContent
    }
    .frame(width: panelWidth, height: panelHeight, alignment: .topLeading)
    .background(Color.clear)
    .clipped()
    .onAppear {
      services.calendar.refresh()
    }
  }

  /// Renders the selected calendar mode.
  @ViewBuilder
  private var calendarContent: some View {
    switch runtimeConfig.calendar.popupMode {
    case .month:
      CalendarMonthPopupView(
        store: services.store,
        logger: services.store.logger,
        config: runtimeConfig.calendar.calendarMonthPopupUIConfig,
        appointmentsStyle: runtimeConfig.calendar.appointmentsCalendarUIStyle,
        birthdays: runtimeConfig.calendar.birthdayCalendarUIStyle,
        emptyText: runtimeConfig.calendar.appointments.emptyText,
        onVisibleMonthChanged: { visibleMonth in
          services.calendar.focusVisibleMonth(visibleMonth)
        },
        onCreateEvent: { defaultDate, onChanged in
          composerPanel.present(defaultDate: defaultDate, onChanged: onChanged)
        },
        onEditEvent: { event, onChanged in
          composerPanel.present(event: event, onChanged: onChanged)
        },
        onRefreshRequested: {
          services.calendar.refresh()
        }
      )
      .frame(width: panelWidth, alignment: .topLeading)

    case .upcoming:
      CalendarUpcomingPopupView(
        store: services.store,
        config: runtimeConfig.calendar.calendarUpcomingPopupUIConfig,
        appointmentsStyle: runtimeConfig.calendar.appointmentsCalendarUIStyle,
        birthdays: runtimeConfig.calendar.birthdayCalendarUIStyle,
        emptyText: runtimeConfig.calendar.appointments.emptyText,
        onEventTap: { event in
          composerPanel.present(event: event) {
            services.calendar.refresh()
          }
        }
      )
      .frame(width: panelWidth, alignment: .topLeading)

    case .none:
      VStack(alignment: .leading, spacing: 8) {
        Text("Calendar popup disabled")
          .font(.system(size: 13, weight: .semibold))

        Text("Set builtins.calendar.popup_mode to month or upcoming.")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }
      .padding(14)
      .frame(width: panelWidth, alignment: .leading)
      .background(Color(nsColor: .controlBackgroundColor))
    }
  }

  /// Renders a compact warning above the calendar when access is missing.
  private var permissionWarningView: some View {
    HStack(alignment: .center, spacing: 10) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 15, weight: .semibold))

      Text("Calendar access is not available.")
        .font(.system(size: 12, weight: .semibold))
        .lineLimit(1)

      Spacer(minLength: 8)

      Button("Settings") {
        openCalendarSettings()
      }
      .buttonStyle(.plain)
      .font(.system(size: 12, weight: .semibold))
    }
    .foregroundStyle(.white.opacity(0.92))
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(width: panelWidth, alignment: .leading)
    .background(Color.red.opacity(0.18))
  }

  /// Opens Calendar privacy settings.
  private func openCalendarSettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
      )
    else {
      return
    }

    NSWorkspace.shared.open(url)
  }
}
