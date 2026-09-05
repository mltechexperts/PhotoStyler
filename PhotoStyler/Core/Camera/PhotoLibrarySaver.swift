import Photos

/// Writes captured photos to the user's library.
///
/// Uses the add-only authorization level, which pairs with
/// `NSPhotoLibraryAddUsageDescription` and never asks for read access the app
/// does not need. The original code requested full access via the deprecated
/// `requestAuthorization()`, and would have crashed because the matching
/// usage-description key was missing from the Info.plist.
nonisolated enum PhotoLibrarySaver {

    static func save(_ data: Data) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw CameraError.saveFailed("PhotoStyler is not allowed to add photos.")
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset()
                    .addResource(with: .photo, data: data, options: nil)
            }
        } catch {
            throw CameraError.saveFailed(error.localizedDescription)
        }
    }
}
