import EasyBarShared
import Foundation

/// Returns the resolved Soon config path.
func resolvedSoonConfigPath() -> String {
  expandedEnvironmentPath(named: SoonEnvironmentKeys.configPath)
    ?? defaultSoonConfigPath()
}

/// Returns the default config path used by Soon.
func defaultSoonConfigPath() -> String {
  FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/soon/config.toml")
    .path
}

/// Returns the default directory used for Soon single-instance locks.
func defaultSoonLockDirectory() -> String {
  "/tmp/soon"
}

/// Returns the default directory used for Soon logs.
func defaultSoonLoggingDirectory() -> String {
  FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".local/state/soon")
    .path
}
