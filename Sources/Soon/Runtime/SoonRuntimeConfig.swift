import EasyBarCalendarConfig
import EasyBarShared
import Foundation
import TOMLKit

/// Resolved runtime config used by Soon.
struct SoonRuntimeConfig {
  /// Menu bar icon config.
  struct MenuBarIconConfig {
    let enabled: Bool
    let kind: String
    let value: String
  }

  /// Menu bar date config.
  struct MenuBarDateConfig {
    let enabled: Bool
    let format: String
  }

  /// Menu bar label config.
  struct MenuBarConfig {
    let spacing: Double
    let icon: MenuBarIconConfig
    let date: MenuBarDateConfig
  }

  /// Active config path.
  let configPath: String
  /// Whether file logging is enabled.
  let loggingEnabled: Bool
  /// Whether debug logging is enabled.
  let loggingDebugEnabled: Bool
  /// Directory for file logs.
  let loggingDirectory: String
  /// Directory for the single-instance lock.
  let lockDirectory: String
  /// Shared calendar config.
  let calendar: CalendarBuiltinConfig
  /// Menu bar config.
  let menuBar: MenuBarConfig

  /// Process-wide loaded runtime config.
  static let current = load()

  /// Loads the Soon runtime config from env, config file, and defaults.
  static func load() -> SoonRuntimeConfig {
    let configPath = resolvedSoonConfigPath()
    let toml = parsedConfig(at: configPath)

    let loggingTable = toml["logging"]?.table
    let appTable = toml["app"]?.table
    let menuBarTable = toml["menu_bar"]?.table
    let menuBarIconTable = menuBarTable?["icon"]?.table
    let menuBarDateTable = menuBarTable?["date"]?.table

    let loggingEnabled =
      boolEnvironmentValue(named: SoonEnvironmentKeys.loggingEnabled)
      ?? loggingTable?["enabled"]?.bool
      ?? false

    let loggingDebugEnabled =
      boolEnvironmentValue(named: SoonEnvironmentKeys.loggingDebugEnabled)
      ?? loggingTable?["debug"]?.bool
      ?? false

    let loggingDirectory =
      expandedEnvironmentPath(named: SoonEnvironmentKeys.loggingDirectory)
      ?? expandedPath(loggingTable?["directory"]?.string)
      ?? defaultSoonLoggingDirectory()

    let lockDirectory =
      expandedEnvironmentPath(named: SoonEnvironmentKeys.lockDirectory)
      ?? expandedPath(appTable?["lock_dir"]?.string)
      ?? defaultSoonLockDirectory()

    let menuBar = MenuBarConfig(
      spacing: max(0, menuBarTable?["spacing"]?.double ?? 4),
      icon: MenuBarIconConfig(
        enabled: menuBarIconTable?["enabled"]?.bool ?? true,
        kind: normalizedIconKind(menuBarIconTable?["kind"]?.string),
        value: menuBarIconTable?["value"]?.string ?? "calendar"
      ),
      date: MenuBarDateConfig(
        enabled: menuBarDateTable?["enabled"]?.bool ?? false,
        format: menuBarDateTable?["format"]?.string ?? "EEE d"
      )
    )

    return SoonRuntimeConfig(
      configPath: configPath,
      loggingEnabled: loggingEnabled,
      loggingDebugEnabled: loggingDebugEnabled,
      loggingDirectory: loggingDirectory,
      lockDirectory: lockDirectory,
      calendar: parsedCalendarConfig(from: toml),
      menuBar: menuBar
    )
  }
}

/// Returns one parsed TOML table or an empty table when loading fails.
private func parsedConfig(at path: String) -> TOMLTable {
  guard
    let text = try? String(contentsOfFile: path, encoding: .utf8),
    let table = try? TOMLTable(string: text)
  else {
    return TOMLTable()
  }

  return table
}

/// Parses the shared calendar config block.
private func parsedCalendarConfig(from toml: TOMLTable) -> CalendarBuiltinConfig {
  let builtinsTable = toml["builtins"]?.table ?? TOMLTable()
  let calendarTable = builtinsTable["calendar"]?.table ?? TOMLTable()

  do {
    return try CalendarBuiltinConfig.parse(
      from: calendarTable,
      fallback: CalendarBuiltinConfig.default,
      path: "builtins.calendar"
    )
  } catch {
    fputs("soon: invalid builtins.calendar config: \(error)\n", stderr)
    return .default
  }
}

/// Normalizes the configured menu bar icon kind.
private func normalizedIconKind(_ value: String?) -> String {
  switch value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
  case "text":
    return "text"
  default:
    return "sf_symbol"
  }
}
