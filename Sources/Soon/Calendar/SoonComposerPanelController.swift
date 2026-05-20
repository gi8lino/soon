import AppKit
import Combine
import EasyBarCalendarConfig
import EasyBarCalendarUI
import EasyBarShared
import SwiftUI

/// Manages a floating panel for the shared calendar event composer.
@MainActor
final class SoonComposerPanelController: ObservableObject {
  /// Currently displayed composer panel.
  private var panel: NSPanel?

  /// Hosting controller reused for the composer view.
  private var hostingController = NSHostingController(rootView: AnyView(EmptyView()))

  /// Current composer view model.
  private var composer: CalendarEventComposer?

  /// Shared app services.
  private let services = SoonServices.shared

  /// Runtime config used for composer styling.
  private let runtimeConfig = SoonRuntimeConfig.current

  /// Presents the composer panel for one new appointment.
  func present(
    defaultDate: Date,
    onChanged: @escaping () -> Void
  ) {
    let composer = makeComposer()
    composer.prepare(defaultDate: defaultDate)
    self.composer = composer

    hostingController.rootView = AnyView(
      CalendarEventComposerView(
        composer: composer,
        config: runtimeConfig.calendar.calendarComposerUIConfig,
        appointmentsStyle: runtimeConfig.calendar.appointmentsCalendarUIStyle,
        onCancel: { [weak self] in
          self?.close()
        },
        onSaved: { [weak self] in
          onChanged()
          self?.close()
        },
        onDeleted: { [weak self] in
          onChanged()
          self?.close()
        }
      )
    )

    showIfPossible()
  }

  /// Presents the composer panel for one existing appointment.
  func present(
    event: CalendarAgentEvent,
    onChanged: @escaping () -> Void
  ) {
    let composer = makeComposer()
    composer.prepare(event: event)
    self.composer = composer

    hostingController.rootView = AnyView(
      CalendarEventComposerView(
        composer: composer,
        config: runtimeConfig.calendar.calendarComposerUIConfig,
        appointmentsStyle: runtimeConfig.calendar.appointmentsCalendarUIStyle,
        onCancel: { [weak self] in
          self?.close()
        },
        onSaved: { [weak self] in
          onChanged()
          self?.close()
        },
        onDeleted: { [weak self] in
          onChanged()
          self?.close()
        }
      )
    )

    showIfPossible()
  }

  /// Closes the composer panel when present.
  func close() {
    panel?.close()
    panel = nil
    composer = nil
    hostingController = NSHostingController(rootView: AnyView(EmptyView()))
  }

  /// Shows the panel centered relative to the active window or screen.
  private func showIfPossible() {
    let panel = panel ?? makePanel()
    self.panel = panel

    if let composer {
      panel.title = composer.panelTitle
    }

    hostingController.view.layoutSubtreeIfNeeded()
    let fittingSize = hostingController.view.fittingSize
    guard fittingSize.width > 0, fittingSize.height > 0 else { return }

    panel.setContentSize(fittingSize)

    if let parentWindow = NSApp.keyWindow ?? NSApp.mainWindow {
      let parentFrame = parentWindow.frame
      panel.setFrameOrigin(
        NSPoint(
          x: parentFrame.midX - fittingSize.width / 2,
          y: parentFrame.midY - fittingSize.height / 2
        )
      )
    } else if let screenFrame = NSScreen.main?.visibleFrame {
      panel.setFrameOrigin(
        NSPoint(
          x: screenFrame.midX - fittingSize.width / 2,
          y: screenFrame.midY - fittingSize.height / 2
        )
      )
    }

    panel.orderFrontRegardless()
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  /// Builds the shared floating composer panel.
  private func makePanel() -> NSPanel {
    let panel = NSPanel(
      contentRect: .zero,
      styleMask: [.titled, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    panel.title = "Appointment"
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isMovableByWindowBackground = true
    panel.isFloatingPanel = true
    panel.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
    panel.hasShadow = true
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.isReleasedWhenClosed = false
    panel.contentViewController = hostingController

    panel.standardWindowButton(.closeButton)?.isHidden = true
    panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
    panel.standardWindowButton(.zoomButton)?.isHidden = true

    return panel
  }

  /// Builds one reusable composer view model wired to Soon's store and calendar service.
  private func makeComposer() -> CalendarEventComposer {
    CalendarEventComposer(
      config: runtimeConfig.calendar.calendarComposerUIConfig,
      snapshotPublisher: services.store.$snapshot.eraseToAnyPublisher(),
      refreshSnapshots: {
        SoonServices.shared.calendar.refresh()
      },
      createEvent: { event, completion in
        SoonServices.shared.calendar.createEvent(event, completion: completion)
      },
      updateEvent: { event, completion in
        SoonServices.shared.calendar.updateEvent(event, completion: completion)
      },
      deleteEvent: { event, completion in
        SoonServices.shared.calendar.deleteEvent(event, completion: completion)
      },
      openCalendarApp: {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal")
        else { return }

        NSWorkspace.shared.open(appURL)
      }
    )
  }
}
