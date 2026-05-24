import AppKit
import EasyBarCalendarConfig
import EasyBarShared
import SwiftUI
import TOMLKit

/// Config load failure contexts used for Soon's shared error window copy.
enum SoonConfigLoadFailureContext {
  case initialLoad
  case reloadKeptPreviousConfig
}

/// User-facing config error shown when Soon falls back or keeps the previous config.
enum SoonConfigError: Error, LocalizedError {
  case fileReadFailure(message: String)
  case parseFailure(
    message: String,
    line: Int?,
    column: Int?,
    item: String?,
    value: String?
  )
  case invalidCalendar(CalendarConfigError)

  /// Returns the config path or source location associated with the validation failure.
  var configPath: String {
    switch self {
    case .fileReadFailure:
      return "Config file"

    case .parseFailure(_, let line, let column, _, _):
      if let line, let column {
        return "line \(line), column \(column)"
      }

      if let line {
        return "line \(line)"
      }

      return "TOML syntax"

    case .invalidCalendar(let error):
      return error.configPath
    }
  }

  /// Returns the item or key associated with the failure when available.
  var problemItem: String? {
    switch self {
    case .fileReadFailure:
      return nil

    case .parseFailure(_, _, _, let item, _):
      return item

    case .invalidCalendar(let error):
      return error.problemItem
    }
  }

  /// Returns the problematic TOML value when available.
  var problemValue: String? {
    switch self {
    case .fileReadFailure:
      return nil

    case .parseFailure(_, _, _, _, let value):
      return value

    case .invalidCalendar(let error):
      return error.problemValue
    }
  }

  /// Returns the human-readable failure detail without the config path prefix.
  var detail: String {
    switch self {
    case .fileReadFailure(let message):
      return message

    case .parseFailure(let message, let line, let column, _, _):
      let locationText: String
      if let line, let column {
        locationText = " at line \(line), column \(column)"
      } else if let line {
        locationText = " at line \(line)"
      } else {
        locationText = ""
      }

      let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedMessage.isEmpty else {
        return "Could not parse TOML\(locationText)."
      }

      return "Could not parse TOML\(locationText): \(trimmedMessage)"

    case .invalidCalendar(let error):
      return error.detail
    }
  }

  var errorDescription: String? {
    return "\(configPath): \(detail)"
  }
}

/// Presents a floating window that explains Soon config load or reload failures.
@MainActor
final class SoonConfigErrorWindowController: NSObject, NSWindowDelegate {
  /// Currently presented config error window.
  private var window: NSWindow?
  /// Hosting controller reused for the error content view.
  private var hostingController = NSHostingController(rootView: AnyView(EmptyView()))

  /// Presents one config failure in a dedicated floating window.
  func present(
    error: SoonConfigError,
    context: SoonConfigLoadFailureContext,
    configPath: String,
    onReload: @escaping () -> Void
  ) {
    let presentation = SharedConfigErrorPresentation(
      windowTitle: "Soon Config Error",
      title: title(for: context),
      summary: summary(for: context),
      filePath: configPath,
      locationText: error.configPath,
      problemItemText: error.problemItem,
      problemValueText: error.problemValue,
      detailText: error.detail,
      openButtonTitle: "Open Config",
      retryButtonTitle: "Reload Config"
    )

    hostingController.rootView = AnyView(
      SharedConfigErrorView(
        presentation: presentation,
        onOpen: {
          NSWorkspace.shared.open(URL(fileURLWithPath: configPath))
        },
        onRetry: onReload,
        onClose: { [weak self] in
          self?.close()
        }
      )
    )

    let window = window ?? makeWindow()
    self.window = window

    window.title = presentation.windowTitle
    hostingController.view.layoutSubtreeIfNeeded()
    let fittingSize = hostingController.view.fittingSize
    guard fittingSize.width > 0, fittingSize.height > 0 else { return }

    window.setContentSize(fittingSize)
    center(window: window, size: fittingSize)
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  /// Closes the config error window when it is currently shown.
  func close() {
    window?.close()
    window = nil
    hostingController = NSHostingController(rootView: AnyView(EmptyView()))
  }

  /// Builds the floating config error window shell.
  private func makeWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: .zero,
      styleMask: [.titled, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = "Soon Config Error"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
    window.level = .floating
    window.hasShadow = true
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
    window.backgroundColor = .clear
    window.isOpaque = false
    window.representedURL = nil
    window.miniwindowImage = NSApp.applicationIconImage
    window.standardWindowButton(.closeButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
    window.standardWindowButton(.documentIconButton)?.image = NSApp.applicationIconImage
    window.contentViewController = hostingController
    window.delegate = self
    return window
  }

  /// Centers the floating error window over the active window or main screen.
  private func center(window: NSWindow, size: CGSize) {
    if let parentWindow = NSApp.keyWindow ?? NSApp.mainWindow {
      let parentFrame = parentWindow.frame
      window.setFrameOrigin(
        NSPoint(
          x: parentFrame.midX - size.width / 2,
          y: parentFrame.midY - size.height / 2
        )
      )
      return
    }

    if let screenFrame = NSScreen.main?.visibleFrame {
      window.setFrameOrigin(
        NSPoint(
          x: screenFrame.midX - size.width / 2,
          y: screenFrame.midY - size.height / 2
        )
      )
    }
  }

  /// Resets controller state when the user closes the window directly.
  func windowWillClose(_ notification: Notification) {
    window = nil
    hostingController = NSHostingController(rootView: AnyView(EmptyView()))
  }

  /// Returns the headline text for the failure context.
  private func title(for context: SoonConfigLoadFailureContext) -> String {
    switch context {
    case .initialLoad:
      return "Soon started with a config problem"
    case .reloadKeptPreviousConfig:
      return "Soon could not apply the new config"
    }
  }

  /// Returns the fallback summary for the failure context.
  private func summary(for context: SoonConfigLoadFailureContext) -> String {
    switch context {
    case .initialLoad:
      return "Soon is running with fallback defaults until the config is fixed and reloaded."
    case .reloadKeptPreviousConfig:
      return "The previous working config is still active. Fix the file and reload config to apply the changes."
    }
  }
}

/// Converts one TOML parse error into Soon's user-facing config error.
func makeSoonParseFailure(from error: TOMLParseError, text: String) -> SoonConfigError {
  let line = positive(Int(error.source.begin.line))
  let column = positive(Int(error.source.begin.column))
  let lines = text.components(separatedBy: .newlines)
  let lineText = sourceLine(in: lines, line: line)

  let tablePath = nearestTableHeaderPath(in: lines, beforeLine: line)
  let key = keyText(from: lineText)
  let item = problemItem(tablePath: tablePath, key: key)
  let value = valueText(from: lineText)

  return SoonConfigError.parseFailure(
    message: error.description,
    line: line,
    column: column,
    item: item,
    value: value
  )
}

/// Returns a positive integer or nil.
private func positive(_ value: Int) -> Int? {
  guard value > 0 else {
    return nil
  }

  return value
}

/// Returns one source line for a 1-based line number.
private func sourceLine(in lines: [String], line: Int?) -> String? {
  guard let line, line > 0, line <= lines.count else {
    return nil
  }

  return lines[line - 1]
}

/// Returns the nearest TOML table header path before the failing line.
private func nearestTableHeaderPath(in lines: [String], beforeLine line: Int?) -> String? {
  guard let line, line > 1 else {
    return nil
  }

  let startIndex = min(line - 2, lines.count - 1)
  guard startIndex >= 0 else {
    return nil
  }

  for index in stride(from: startIndex, through: 0, by: -1) {
    if let tablePath = tableHeaderPath(from: lines[index]) {
      return tablePath
    }
  }

  return nil
}

/// Returns the TOML table path from a complete table-header line.
private func tableHeaderPath(from line: String) -> String? {
  let trimmed = trimInlineComment(from: line)
    .trimmingCharacters(in: .whitespacesAndNewlines)

  if trimmed.hasPrefix("[[") {
    guard let end = trimmed.range(of: "]]") else {
      return nil
    }

    let remainder = trimmed[end.upperBound...]
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard remainder.isEmpty else {
      return nil
    }

    let start = trimmed.index(trimmed.startIndex, offsetBy: 2)
    let value = trimmed[start..<end.lowerBound]
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return value.isEmpty ? nil : value
  }

  if trimmed.hasPrefix("[") {
    guard let end = trimmed.firstIndex(of: "]") else {
      return nil
    }

    let remainder = trimmed[trimmed.index(after: end)...]
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard remainder.isEmpty else {
      return nil
    }

    let start = trimmed.index(after: trimmed.startIndex)
    let value = trimmed[start..<end]
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return value.isEmpty ? nil : value
  }

  return nil
}

/// Returns the key before the assignment operator on one TOML line.
private func keyText(from line: String?) -> String? {
  guard
    let line,
    let assignmentIndex = assignmentIndex(in: line)
  else {
    return nil
  }

  let key = line[..<assignmentIndex]
    .trimmingCharacters(in: .whitespacesAndNewlines)

  return key.isEmpty ? nil : key
}

/// Returns the value after the assignment operator on one TOML line.
private func valueText(from line: String?) -> String? {
  guard
    let line,
    let assignmentIndex = assignmentIndex(in: line)
  else {
    return nil
  }

  let valueStart = line.index(after: assignmentIndex)
  let rawValue = String(line[valueStart...])
  let value = trimInlineComment(from: rawValue)
    .trimmingCharacters(in: .whitespacesAndNewlines)

  return value.isEmpty ? nil : value
}

/// Combines a table path and key into a readable TOML item label.
private func problemItem(tablePath: String?, key: String?) -> String? {
  guard let key, !key.isEmpty else {
    return nil
  }

  guard let tablePath, !tablePath.isEmpty else {
    return key
  }

  return "[\(tablePath)].\(key)"
}

/// Finds the first assignment operator outside strings and comments.
private func assignmentIndex(in line: String) -> String.Index? {
  var inSingleQuotedString = false
  var inDoubleQuotedString = false
  var escaped = false

  for index in line.indices {
    let character = line[index]

    if escaped {
      escaped = false
      continue
    }

    if character == "\\" && inDoubleQuotedString {
      escaped = true
      continue
    }

    if character == "\"" && !inSingleQuotedString {
      inDoubleQuotedString.toggle()
      continue
    }

    if character == "'" && !inDoubleQuotedString {
      inSingleQuotedString.toggle()
      continue
    }

    if character == "#" && !inSingleQuotedString && !inDoubleQuotedString {
      return nil
    }

    if character == "=" && !inSingleQuotedString && !inDoubleQuotedString {
      return index
    }
  }

  return nil
}

/// Removes an inline comment while preserving hashes inside strings.
private func trimInlineComment(from value: String) -> String {
  var result = ""
  var inSingleQuotedString = false
  var inDoubleQuotedString = false
  var escaped = false

  for character in value {
    if escaped {
      result.append(character)
      escaped = false
      continue
    }

    if character == "\\" && inDoubleQuotedString {
      result.append(character)
      escaped = true
      continue
    }

    if character == "\"" && !inSingleQuotedString {
      inDoubleQuotedString.toggle()
      result.append(character)
      continue
    }

    if character == "'" && !inDoubleQuotedString {
      inSingleQuotedString.toggle()
      result.append(character)
      continue
    }

    if character == "#" && !inSingleQuotedString && !inDoubleQuotedString {
      break
    }

    result.append(character)
  }

  return result
}
