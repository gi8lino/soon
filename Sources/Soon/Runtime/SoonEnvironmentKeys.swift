import Foundation

/// Central registry of environment variable names used by Soon.
enum SoonEnvironmentKeys {
  /// Overrides the Soon config path.
  static let configPath = "SOON_CONFIG_PATH"

  /// Overrides the single-instance lock directory.
  static let lockDirectory = "SOON_LOCK_DIR"

  /// Enables file logging.
  static let loggingEnabled = "SOON_LOGGING_ENABLED"
  /// Enables debug logging.
  static let loggingDebugEnabled = "SOON_DEBUG"
  /// Overrides the log directory.
  static let loggingDirectory = "SOON_LOG_DIR"
}
