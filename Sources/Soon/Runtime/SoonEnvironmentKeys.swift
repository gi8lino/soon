import Foundation

/// Central registry of environment variable names used by Soon.
enum SoonEnvironmentKeys {
  /// Overrides the Soon config path.
  static let configPath = "SOON_CONFIG_PATH"

  /// Overrides only the configured runtime log level for diagnostics.
  static let loggingLevel = "SOON_LOG_LEVEL"
}
