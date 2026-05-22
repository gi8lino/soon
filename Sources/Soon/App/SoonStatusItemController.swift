import AppKit
import EasyBarCalendarConfig
import SwiftUI

/// Borderless floating panel used for the Soon calendar surface.
private final class SoonCalendarPanel: NSPanel {
  /// Allows SwiftUI controls inside the borderless panel to receive focus.
  override var canBecomeKey: Bool {
    return true
  }

  /// Prevents the floating calendar panel from becoming the app's main window.
  override var canBecomeMain: Bool {
    return false
  }
}

/// Native macOS status item wrapper for Soon.
@MainActor
final class SoonStatusItemController: NSObject {
  /// Shared app services.
  private let services: SoonServices
  /// Reloads the app so updated config is picked up.
  private let onReloadConfig: () -> Void
  /// Runtime config.
  private let runtimeConfig = SoonRuntimeConfig.current
  /// Runtime menu bar config.
  private let menuBarConfig = SoonRuntimeConfig.current.menuBar

  /// Native menu bar item.
  private let statusItem: NSStatusItem
  /// Borderless calendar panel shown on left click.
  private var calendarPanel: SoonCalendarPanel?
  /// Hosting controller for the SwiftUI calendar content.
  private let hostingController: NSHostingController<AnyView>

  /// Timer used to keep date-based menu bar labels fresh.
  private var labelTimer: Timer?
  /// Retained context menu while it is being displayed.
  private var contextMenu: NSMenu?
  /// Global click monitor used to close the calendar panel.
  private var globalClickMonitor: Any?
  /// Local click monitor used to close the calendar panel.
  private var localClickMonitor: Any?

  /// Size used by the selected calendar surface.
  private var calendarSize: CGSize {
    runtimeConfig.calendar.soonPopupSurfaceSize
  }

  /// Creates and installs the status item.
  init(
    services: SoonServices,
    onReloadConfig: @escaping () -> Void
  ) {
    self.services = services
    self.onReloadConfig = onReloadConfig
    self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    self.hostingController = NSHostingController(
      rootView: AnyView(
        SoonMenuBarContentView()
          .environmentObject(services)
      )
    )

    super.init()

    configureButton()
    updateMenuBarLabel()
    startLabelTimerIfNeeded()
  }

  /// Removes the status item and closes all UI.
  func stop() {
    labelTimer?.invalidate()
    labelTimer = nil

    closeCalendarPanel()

    contextMenu = nil
    NSStatusBar.system.removeStatusItem(statusItem)
  }

  /// Configures click handling on the native status item button.
  private func configureButton() {
    guard let button = statusItem.button else { return }

    button.target = self
    button.action = #selector(handleStatusItemClick(_:))
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    button.imagePosition = .imageLeft
  }

  /// Handles left and right clicks on the status item.
  @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
    guard let event = NSApp.currentEvent else {
      toggleCalendarPanel(relativeTo: sender)
      return
    }

    if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
      showContextMenu(relativeTo: sender)
      return
    }

    toggleCalendarPanel(relativeTo: sender)
  }

  /// Opens or closes the calendar panel.
  private func toggleCalendarPanel(relativeTo button: NSStatusBarButton) {
    if calendarPanel?.isVisible == true {
      closeCalendarPanel()
      return
    }

    showCalendarPanel(relativeTo: button)
  }

  /// Shows the calendar panel below the status item.
  private func showCalendarPanel(relativeTo button: NSStatusBarButton) {
    services.calendar.refresh()

    stopClickMonitors()

    let size = calendarSize
    let panel = calendarPanel ?? makeCalendarPanel(size: size)

    calendarPanel = panel
    hostingController.view.frame = NSRect(origin: .zero, size: size)
    panel.setContentSize(size)
    panel.setFrameOrigin(panelOrigin(size: size, relativeTo: button))

    panel.orderFrontRegardless()
    panel.makeKey()

    statusItem.button?.state = .on

    DispatchQueue.main.async { [weak self] in
      self?.startClickMonitors()
    }
  }

  /// Creates the borderless calendar panel.
  private func makeCalendarPanel(size: CGSize) -> SoonCalendarPanel {
    let panel = SoonCalendarPanel(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    panel.contentViewController = hostingController
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true
    panel.level = .popUpMenu
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    panel.isMovable = false
    panel.isReleasedWhenClosed = false
    panel.ignoresMouseEvents = false

    return panel
  }

  /// Calculates the panel origin below the status item.
  private func panelOrigin(size: CGSize, relativeTo button: NSStatusBarButton) -> CGPoint {
    guard let buttonWindow = button.window else {
      return .zero
    }

    let statusFrame = buttonWindow.frame
    let visibleFrame =
      buttonWindow.screen?.visibleFrame
      ?? NSScreen.main?.visibleFrame
      ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

    let x = min(
      max(statusFrame.midX - size.width / 2, visibleFrame.minX + 8),
      visibleFrame.maxX - size.width - 8
    )

    let y = min(
      max(statusFrame.minY - size.height - 8, visibleFrame.minY + 8),
      visibleFrame.maxY - size.height - 8
    )

    return CGPoint(x: x, y: y)
  }

  /// Closes the calendar panel.
  private func closeCalendarPanel() {
    calendarPanel?.orderOut(nil)
    statusItem.button?.state = .off
    stopClickMonitors()
  }

  /// Starts outside-click monitors.
  private func startClickMonitors() {
    stopClickMonitors()

    globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] _ in
      Task { @MainActor in
        self?.closeCalendarPanel()
      }
    }

    localClickMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] event in
      Task { @MainActor in
        self?.closeIfClickIsOutsideCalendarPanel(event)
      }

      return event
    }
  }

  /// Closes the calendar panel only when a local click happens outside the panel.
  private func closeIfClickIsOutsideCalendarPanel(_ event: NSEvent) {
    guard let panel = calendarPanel, panel.isVisible else { return }

    guard event.window !== panel else {
      return
    }

    closeCalendarPanel()
  }

  /// Stops outside-click monitors.
  private func stopClickMonitors() {
    if let globalClickMonitor {
      NSEvent.removeMonitor(globalClickMonitor)
      self.globalClickMonitor = nil
    }

    if let localClickMonitor {
      NSEvent.removeMonitor(localClickMonitor)
      self.localClickMonitor = nil
    }
  }

  /// Shows the right-click app menu.
  private func showContextMenu(relativeTo button: NSStatusBarButton) {
    closeCalendarPanel()

    let menu = makeContextMenu()
    contextMenu = menu
    statusItem.menu = menu

    button.performClick(nil)

    statusItem.menu = nil
    contextMenu = nil
  }

  /// Builds the status item context menu.
  private func makeContextMenu() -> NSMenu {
    let menu = NSMenu()

    let titleItem = NSMenuItem(
      title: "Soon \(BuildInfo.appVersion)",
      action: nil,
      keyEquivalent: ""
    )
    titleItem.isEnabled = false
    menu.addItem(titleItem)

    menu.addItem(.separator())

    menu.addItem(actionItem(title: "Reload Config", action: #selector(reloadConfig(_:))))
    menu.addItem(actionItem(title: "Refresh", action: #selector(refresh(_:))))
    menu.addItem(actionItem(title: "Open Calendar Settings", action: #selector(openCalendarSettings(_:))))
    menu.addItem(actionItem(title: "Open Calendar App", action: #selector(openCalendarApp(_:))))

    menu.addItem(.separator())

    menu.addItem(actionItem(title: "Quit Soon", action: #selector(quit(_:))))

    return menu
  }

  /// Creates one enabled menu action item.
  private func actionItem(title: String, action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    return item
  }

  /// Relaunches Soon so updated config is applied everywhere.
  @objc private func reloadConfig(_ sender: Any?) {
    onReloadConfig()
  }

  /// Refreshes the current calendar snapshot.
  @objc private func refresh(_ sender: Any?) {
    services.calendar.refresh()
  }

  /// Opens Calendar privacy settings.
  @objc private func openCalendarSettings(_ sender: Any?) {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
      )
    else {
      return
    }

    NSWorkspace.shared.open(url)
  }

  /// Opens Apple's Calendar app.
  @objc private func openCalendarApp(_ sender: Any?) {
    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal")
    else {
      return
    }

    NSWorkspace.shared.open(appURL)
  }

  /// Terminates Soon.
  @objc private func quit(_ sender: Any?) {
    NSApp.terminate(nil)
  }

  /// Starts a timer when the configured label contains date text.
  private func startLabelTimerIfNeeded() {
    guard menuBarConfig.date.enabled else { return }

    labelTimer = Timer.scheduledTimer(
      withTimeInterval: 60,
      repeats: true
    ) { [weak self] _ in
      Task { @MainActor in
        self?.updateMenuBarLabel()
      }
    }
  }

  /// Updates the native menu bar button from config.
  private func updateMenuBarLabel() {
    guard let button = statusItem.button else { return }

    button.image = nil
    button.title = ""
    button.imagePosition = .imageLeft

    let iconText = configuredTextIcon
    let dateText = configuredDateText

    if let symbolName = configuredSystemSymbolName {
      button.image = NSImage(
        systemSymbolName: symbolName,
        accessibilityDescription: "Soon"
      )
      button.title = dateText ?? ""
      return
    }

    let parts = [iconText, dateText]
      .compactMap { $0 }
      .filter { !$0.isEmpty }

    if parts.isEmpty {
      button.image = NSImage(
        systemSymbolName: "calendar",
        accessibilityDescription: "Soon"
      )
      return
    }

    button.title = parts.joined(separator: textSpacing)
  }

  /// Returns the configured SF Symbol name when enabled.
  private var configuredSystemSymbolName: String? {
    guard menuBarConfig.icon.enabled else { return nil }
    guard menuBarConfig.icon.kind == "sf_symbol" else { return nil }

    let value = menuBarConfig.icon.value.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? "calendar" : value
  }

  /// Returns the configured text icon when enabled.
  private var configuredTextIcon: String? {
    guard menuBarConfig.icon.enabled else { return nil }
    guard menuBarConfig.icon.kind == "text" else { return nil }

    let value = menuBarConfig.icon.value.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }

  /// Returns the configured formatted date text when enabled.
  private var configuredDateText: String? {
    guard menuBarConfig.date.enabled else { return nil }

    let format = menuBarConfig.date.format.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !format.isEmpty else { return nil }

    let formatter = DateFormatter()
    formatter.dateFormat = format
    return formatter.string(from: Date())
  }

  /// Returns spacing used between text-based label parts.
  private var textSpacing: String {
    let count = max(1, Int(menuBarConfig.spacing.rounded()))
    return String(repeating: " ", count: count)
  }
}
