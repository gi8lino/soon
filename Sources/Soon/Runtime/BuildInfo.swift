import Foundation

/// Build-time version information shared by the Soon app.
public enum BuildInfo {
  /// The application version embedded at build time.
  public static let appVersion = "dev"

  /// The best available version string for the running build.
  public static var displayVersion: String {
    if let bundledVersion = bundledVersion(named: "CFBundleShortVersionString") {
      return bundledVersion
    }

    if appVersion != "dev" {
      return appVersion
    }

    if let bundledBuild = bundledVersion(named: "CFBundleVersion") {
      return bundledBuild
    }

    return appVersion
  }

  /// Reads one non-empty version string from the main app bundle.
  private static func bundledVersion(named key: String) -> String? {
    guard
      let value = Bundle.main.object(forInfoDictionaryKey: key) as? String
    else {
      return nil
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
