import Foundation
import SwiftData

/// A photo taken in the app.
///
/// Only metadata lives in SwiftData; the JPEG itself is a file in the app
/// container. Storing image bytes in the store would bloat it and make every
/// query expensive, and the photo is already in the user's library besides —
/// this is the app's own record of which profile produced which frame.
@Model
final class CapturedPhoto {
    #Unique<CapturedPhoto>([\.fileName])

    var fileName: String = ""
    var capturedAt: Date = Date()
    var profileID: String = ""
    var profileName: String = ""
    var intensity: Double = 1

    init(
        fileName: String,
        capturedAt: Date = .now,
        profileID: String,
        profileName: String,
        intensity: Double
    ) {
        self.fileName = fileName
        self.capturedAt = capturedAt
        self.profileID = profileID
        self.profileName = profileName
        self.intensity = intensity
    }

    var fileURL: URL { PhotoStore.directory.appendingPathComponent(fileName) }
}

/// Where captured JPEGs live on disk.
nonisolated enum PhotoStore {

    static let directory: URL = {
        let base = URL.applicationSupportDirectory.appendingPathComponent("Captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    /// Writes `data` and returns the generated file name.
    static func write(_ data: Data) throws -> String {
        let name = "\(UUID().uuidString).jpg"
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
        return name
    }

    static func delete(_ fileName: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }
}
