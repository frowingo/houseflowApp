import Foundation
import XCTest

final class CoreBoundaryTests: XCTestCase {
    func testCoreSourcesUseOnlyFoundationOrPureSwiftImports() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcesRoot = packageRoot.appendingPathComponent("Sources/HouseFlowCore")
        let sourceFiles = try XCTUnwrap(
            FileManager.default.enumerator(
                at: sourcesRoot,
                includingPropertiesForKeys: nil
            )?.allObjects as? [URL]
        ).filter { $0.pathExtension == "swift" }

        XCTAssertFalse(sourceFiles.isEmpty)

        for sourceFile in sourceFiles {
            let contents = try String(contentsOf: sourceFile, encoding: .utf8)
            let importedModules = contents
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("import ") }
                .map { String($0.dropFirst("import ".count)) }

            XCTAssertEqual(
                importedModules.filter { $0 != "Foundation" },
                [],
                "\(sourceFile.lastPathComponent) imports a platform module"
            )

            for forbiddenSymbol in ["URLSession", "URLRequest", "UserDefaults"] {
                XCTAssertFalse(
                    contents.contains(forbiddenSymbol),
                    "\(sourceFile.lastPathComponent) uses forbidden symbol \(forbiddenSymbol)"
                )
            }
        }
    }
}
