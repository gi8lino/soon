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

  /// Simple theme palette used to resolve `theme.*` config color references.
  struct Theme {
    let colors: [String: String]

    /// Returns the built-in Soon color palette.
    static let `default` = Theme(
      colors: [
        "background": "#111111",
        "surface": "#1a1a1a",
        "surface_elevated": "#2b2b2b",
        "surface_hover": "#202020",
        "text": "#ffffff",
        "text_secondary": "#d0d0d0",
        "text_tertiary": "#c0c0c0",
        "muted": "#6c7086",
        "muted_secondary": "#8a8a8a",
        "outside_month": "#6e738d",
        "border": "#333333",
        "border_strong": "#444444",
        "border_subtle": "#00000000",
        "accent": "#91d7e3",
        "accent_secondary": "#89B4FA",
        "accent_soft": "#8bd5ca",
        "success": "#a6e3a1",
        "success_secondary": "#a6da95",
        "warning": "#f9e2af",
        "orange": "#fab387",
        "error": "#f38ba8",
        "danger": "#FF0000",
        "selection_text": "#0B1020",
        "selection_background": "#89B4FA",
        "transparent": "#00000000",
        "overlay_outline": "#000000F0",
        "overlay_text": "#FFFFFFFF",
        "today_button_border": "#3F2F6B",
      ]
    )

    /// Parses theme color overrides from `[theme.colors]`.
    static func parse(from table: TOMLTable?) -> Theme {
      guard let colorsTable = table?["colors"]?.table else {
        return .default
      }

      var colors = Theme.default.colors

      for key in colorsTable.keys {
        guard let value = colorsTable[key]?.string else {
          continue
        }

        colors[key] = value
      }

      return Theme(colors: colors)
    }

    /// Resolves one `theme.name` color reference to a concrete color string.
    func resolveColorReference(_ value: String) -> String {
      let prefix = "theme."
      guard value.hasPrefix(prefix) else {
        return value
      }

      let key = String(value.dropFirst(prefix.count))
      return colors[key] ?? value
    }
  }

  /// Active config path.
  let configPath: String
  /// Whether file logging is enabled.
  let loggingEnabled: Bool
  /// Minimum runtime log level.
  let loggingLevel: ProcessLogLevel
  /// Directory for file logs.
  let loggingDirectory: String
  /// Directory for the single-instance lock.
  let lockDirectory: String
  /// Theme used to resolve calendar color references.
  let theme: Theme
  /// Shared calendar config.
  let calendar: CalendarBuiltinConfig
  /// Menu bar config.
  let menuBar: MenuBarConfig

  /// Captured result of the initial process-wide load.
  @MainActor
  private static let initialLoadResult = performLoad()

  /// Process-wide loaded runtime config.
  @MainActor
  static private(set) var current = initialLoadResult.config
  /// Most recent config load failure, cleared after a successful reload.
  @MainActor
  static private(set) var lastLoadFailure = initialLoadResult.failure

  /// Loads the Soon runtime config from env, config file, and defaults.
  @MainActor
  static func load() -> SoonRuntimeConfig {
    return current
  }

  /// Reloads the process-wide runtime config from disk.
  @discardableResult
  @MainActor
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
      let theme = Theme.parse(from: toml["theme"]?.table)
      let calendar = try parsedCalendarConfig(from: toml, theme: theme)

      return LoadResult(
        config: resolvedConfig(
          from: toml,
          configPath: configPath,
          theme: theme,
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
    theme: Theme,
    calendar: CalendarBuiltinConfig
  ) -> SoonRuntimeConfig {

    let loggingTable = toml["logging"]?.table
    let appTable = toml["app"]?.table
    let menuBarTable = toml["menu_bar"]?.table
    let menuBarIconTable = menuBarTable?["icon"]?.table
    let menuBarDateTable = menuBarTable?["date"]?.table

    let loggingEnabled =
      loggingTable?["enabled"]?.bool
      ?? false

    let loggingLevel = resolvedLogLevel(from: loggingTable)

    let loggingDirectory =
      expandedPath(loggingTable?["directory"]?.string)
      ?? defaultSoonLoggingDirectory()

    let lockDirectory =
      expandedPath(appTable?["lock_dir"]?.string)
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
      loggingLevel: loggingLevel,
      loggingDirectory: loggingDirectory,
      lockDirectory: lockDirectory,
      theme: theme,
      calendar: calendar,
      menuBar: menuBar
    )
  }

  /// Resolves the configured log level, allowing the environment to override only verbosity.
  private static func resolvedLogLevel(from loggingTable: TOMLTable?) -> ProcessLogLevel {
    let configuredLevel = ProcessLogLevel.normalized(loggingTable?["level"]?.string) ?? .info

    return ProcessLogLevel.normalized(
      stringEnvironmentValue(named: SoonEnvironmentKeys.loggingLevel)
    ) ?? configuredLevel
  }

  /// Resolves one default runtime config without reading config.toml.
  private static func defaultConfig(configPath: String) -> SoonRuntimeConfig {
    let theme = Theme.default

    return resolvedConfig(
      from: TOMLTable(),
      configPath: configPath,
      theme: theme,
      calendar: CalendarBuiltinConfig.default.resolvingSoonThemeColorReferences(
        using: theme.resolveColorReference
      )
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

/// Parses the shared calendar config block and resolves theme color references.
private func parsedCalendarConfig(
  from toml: TOMLTable,
  theme: SoonRuntimeConfig.Theme
) throws -> CalendarBuiltinConfig {
  let topLevelCalendarTable = toml["calendar"]?.table ?? TOMLTable()

  do {
    return try CalendarBuiltinConfig.parse(
      from: topLevelCalendarTable,
      fallback: CalendarBuiltinConfig.default,
      path: "calendar"
    ).resolvingSoonThemeColorReferences(using: theme.resolveColorReference)
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

extension CalendarBuiltinConfig {
  /// Returns a copy with Soon theme references resolved to concrete color strings.
  fileprivate func resolvingSoonThemeColorReferences(
    using resolve: (String) -> String
  ) -> CalendarBuiltinConfig {
    var config = self

    config.style.textColorHex = config.style.textColorHex.map(resolve)
    config.style.backgroundColorHex = config.style.backgroundColorHex.map(resolve)
    config.style.borderColorHex = config.style.borderColorHex.map(resolve)

    config.anchor.topTextColorHex = config.anchor.topTextColorHex.map(resolve)
    config.anchor.bottomTextColorHex = config.anchor.bottomTextColorHex.map(resolve)

    config.appointments.eventTextColorHex = resolve(config.appointments.eventTextColorHex)
    config.appointments.emptyTextColorHex = resolve(config.appointments.emptyTextColorHex)
    config.appointments.secondaryTextColorHex = resolve(config.appointments.secondaryTextColorHex)
    config.appointments.travelTextColorHex = resolve(config.appointments.travelTextColorHex)
    config.appointments.travelIconColorHex = config.appointments.travelIconColorHex.map(resolve)
    config.appointments.alertIconColorHex = config.appointments.alertIconColorHex.map(resolve)

    config.birthdays.birthdayIconColorHex = config.birthdays.birthdayIconColorHex.map(resolve)

    config.composer.style.backgroundColorHex = resolve(config.composer.style.backgroundColorHex)
    config.composer.style.borderColorHex = resolve(config.composer.style.borderColorHex)
    config.composer.style.headerTextColorHex = resolve(config.composer.style.headerTextColorHex)

    config.upcoming.popup.backgroundColorHex = resolve(config.upcoming.popup.backgroundColorHex)
    config.upcoming.popup.borderColorHex = resolve(config.upcoming.popup.borderColorHex)

    config.month.popup.style.backgroundColorHex = resolve(config.month.popup.style.backgroundColorHex)
    config.month.popup.style.borderColorHex = resolve(config.month.popup.style.borderColorHex)

    config.month.popup.calendar.headerTextColorHex = resolve(
      config.month.popup.calendar.headerTextColorHex
    )
    config.month.popup.calendar.weekdayTextColorHex = resolve(
      config.month.popup.calendar.weekdayTextColorHex
    )
    config.month.popup.calendar.dayTextColorHex = resolve(
      config.month.popup.calendar.dayTextColorHex
    )
    config.month.popup.calendar.outsideMonthTextColorHex = resolve(
      config.month.popup.calendar.outsideMonthTextColorHex
    )
    config.month.popup.calendar.todayCellBackgroundColorHex = resolve(
      config.month.popup.calendar.todayCellBackgroundColorHex
    )
    config.month.popup.calendar.todayCellBorderColorHex = resolve(
      config.month.popup.calendar.todayCellBorderColorHex
    )
    config.month.popup.calendar.indicatorColorHex = resolve(
      config.month.popup.calendar.indicatorColorHex
    )

    config.month.popup.selection.selectedTextColorHex = resolve(
      config.month.popup.selection.selectedTextColorHex
    )
    config.month.popup.selection.selectedBackgroundColorHex = resolve(
      config.month.popup.selection.selectedBackgroundColorHex
    )

    config.month.popup.anchor.textColorHex = config.month.popup.anchor.textColorHex.map(resolve)
    config.month.popup.todayButton.borderColorHex = resolve(
      config.month.popup.todayButton.borderColorHex
    )

    return config
  }
}
