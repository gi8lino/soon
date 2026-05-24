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

  /// Captured result of the initial process-wide load.
  private static let initialLoadResult = performLoad()

  /// Process-wide loaded runtime config.
  static private(set) var current = initialLoadResult.config
  /// Most recent config load failure, cleared after a successful reload.
  static private(set) var lastLoadFailure = initialLoadResult.failure

  /// Loads the Soon runtime config from env, config file, and defaults.
  static func load() -> SoonRuntimeConfig {
    return current
  }

  /// Reloads the process-wide runtime config from disk.
  @discardableResult
  static func reloadCurrent() -> LoadResult {
    let result = performLoad(fallbackConfig: current)
    current = result.config
    lastLoadFailure = result.failure
    return result
  }

  /// One runtime-config load result.
  struct LoadResult {
    let config: SoonRuntimeConfig
    let failure: SoonConfigError?
  }

  /// Performs one runtime-config load, keeping the provided fallback config on failure.
  private static func performLoad(
    fallbackConfig: SoonRuntimeConfig? = nil
  ) -> LoadResult {
    let configPath = resolvedSoonConfigPath()

    do {
      let toml = try parsedConfig(at: configPath)
      let calendar = try parsedCalendarConfig(from: toml)

      return LoadResult(
        config: resolvedConfig(
          from: toml,
          configPath: configPath,
          calendar: calendar
        ),
        failure: nil
      )
    } catch let error as SoonConfigError {
      return LoadResult(
        config: fallbackConfig ?? defaultConfig(configPath: configPath),
        failure: error
      )
    } catch {
      return LoadResult(
        config: fallbackConfig ?? defaultConfig(configPath: configPath),
        failure: .fileReadFailure(message: error.localizedDescription)
      )
    }
  }

  /// Resolves one runtime config from a parsed TOML table.
  private static func resolvedConfig(
    from toml: TOMLTable,
    configPath: String,
    calendar: CalendarBuiltinConfig
  ) -> SoonRuntimeConfig {

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
      calendar: calendar,
      menuBar: menuBar
    )
  }

  /// Resolves one default runtime config without reading config.toml.
  private static func defaultConfig(configPath: String) -> SoonRuntimeConfig {
    return resolvedConfig(
      from: TOMLTable(),
      configPath: configPath,
      calendar: .default
    )
  }
}

/// Returns one parsed TOML table or throws a user-facing config error.
private func parsedConfig(at path: String) throws -> TOMLTable {
  if !FileManager.default.fileExists(atPath: path) {
    return TOMLTable()
  }

  let text: String

  do {
    text = try String(contentsOfFile: path, encoding: .utf8)
  } catch {
    throw SoonConfigError.fileReadFailure(message: error.localizedDescription)
  }

  do {
    return try TOMLTable(string: text)
  } catch let error as TOMLParseError {
    throw makeSoonParseFailure(from: error, text: text)
  } catch {
    throw SoonConfigError.fileReadFailure(message: error.localizedDescription)
  }
}

/// Parses the shared calendar config block.
private func parsedCalendarConfig(from toml: TOMLTable) throws -> CalendarBuiltinConfig {
  let topLevelCalendarTable = toml["calendar"]?.table ?? TOMLTable()

  do {
    return try CalendarBuiltinConfig.parse(
      from: topLevelCalendarTable,
      fallback: CalendarBuiltinConfig.default,
      path: "calendar"
    )
  } catch let error as CalendarConfigError {
    throw SoonConfigError.invalidCalendar(error)
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
