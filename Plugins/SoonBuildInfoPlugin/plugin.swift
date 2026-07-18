import Foundation
import PackagePlugin

@main
struct SoonBuildInfoPlugin: BuildToolPlugin {
  private static let versionFileName = "soon-build-version"

  func createBuildCommands(
    context: PluginContext,
    target _: Target
  ) throws -> [Command] {
    let generator = try context.tool(named: "SoonGenerateBuildInfo")
    let versionFile = context.package.directory
      .appending(".build")
      .appending(Self.versionFileName)
    let output = context.pluginWorkDirectory.appending("BuildInfo.generated.swift")

    return [
      .buildCommand(
        displayName: "Generate Soon build info",
        executable: generator.path,
        arguments: [
          versionFile.string,
          output.string,
        ],
        inputFiles: Self.inputFiles(for: versionFile),
        outputFiles: [output]
      )
    ]
  }

  private static func inputFiles(for path: Path) -> [Path] {
    FileManager.default.fileExists(atPath: path.string) ? [path] : []
  }
}
