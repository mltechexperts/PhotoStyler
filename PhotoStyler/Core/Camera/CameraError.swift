import Foundation

nonisolated enum CameraError: Error, LocalizedError, Equatable {
    case unauthorized
    case noCameraAvailable
    case cannotAddInput
    case cannotAddOutput
    case captureFailed(String)
    case saveFailed(String)
    case interrupted

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "PhotoStyler needs camera access."
        case .noCameraAvailable:
            "No camera is available on this device."
        case .cannotAddInput, .cannotAddOutput:
            "The camera could not be set up."
        case .captureFailed(let reason):
            "The photo could not be taken. \(reason)"
        case .saveFailed(let reason):
            "The photo could not be saved. \(reason)"
        case .interrupted:
            "The camera was interrupted by another app."
        }
    }

    /// Whether the user can fix this themselves in Settings.
    var isRecoverableInSettings: Bool { self == .unauthorized }
}
