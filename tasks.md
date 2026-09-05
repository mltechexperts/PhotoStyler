# PhotoStyler — Task Tracker

**Owner legend:** 🤖 = Claude does it · 👤 = Murali does it (interactive/account/physical device) · 🤝 = both
**Status legend:** ⬜ not started · 🔄 in progress · ✅ done · ⛔ blocked · ⏭ deferred

> Living file. Updated as work proceeds. Paired with `PhotoStyler_Project_Guide.md` (decisions + context).
> **Resume here:** read the "Current position" line below, then the guide's Decision Log.

**Current position:** Phases 0, 1, 2 complete. Swift 6, zero warnings. Camera rewritten and its failure paths verified by screenshot; the live viewfinder still needs a physical iPhone (6.5). Next: Phase 3/4 — profile manifest, starter profiles, and the shop UI. Blocked on Murali for Homebrew (0.5) and `gh auth login` (0.8).
**Last updated:** 2026-09-05

---

## Phase 0 — Unblock the machine ⛔ BLOCKING EVERYTHING

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 0.1 | Audit disk space | 🤖 | ✅ | 40 GiB free / 96% full. Xcode caches only ~335 MB — not the problem. Big items are Murali's photo work (Desktop 247G, Pictures 159G, Downloads 119G). Nothing deleted. |
| 0.2 | Free additional space if needed | 👤 | ✅ | Not needed — download completed with ~32 GiB to spare. Nothing deleted. |
| 0.3 | `xcodebuild -downloadPlatform iOS` | 🤖 | ✅ | **Unblocked.** iOS 26.5 platform + simulator runtime installed (8.52 GB, exit 0). Restarted once mid-download; second attempt succeeded. |
| 0.4 | Verify destinations resolve | 🤖 | ✅ | Simulators now enumerate (iOS 26.3.1 and 26.5). Previously zero eligible destinations. |
| 0.5 | Install Homebrew | 🤖 | ⛔ | 🔴 **Needs Murali** — `sudo` requires a password, so Claude cannot install Homebrew. Run: `! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/brew/HEAD/install.sh)"` |
| 0.6 | `brew install node swiftlint swiftformat xcbeautify gh` | 🤖 | ⬜ | Node needed for XcodeBuildMCP. |
| 0.7 | Add XcodeBuildMCP server | 🤖 | ⬜ | `claude mcp add xcodebuild -- npx -y xcodebuildmcp@latest`. Gives build/test/sim-control/screenshots. |
| 0.8 | `gh auth login` | 👤 | ⬜ | Interactive — run `! gh auth login` in the session. |
| 0.9 | Baseline build of untouched project | 🤖 | ✅ | 🎉 **First successful build of this project.** Real failure was `@Published` needing an explicit `import Combine` — the project enables `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`, so SwiftUI no longer re-exports it. Installed and launched on iPhone 17 sim; home screen verified by screenshot. |

## Phase 1 — Project hygiene & repo

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 1.1 | Move repo to `~/MyApps/PhotoStyler` | 🤖 | ✅ | Was `~/Desktop/PhotoStyler`. Git history preserved (2 commits). Guide moved in alongside. |
| 1.2 | Commit pre-existing WIP | 🤖 | ✅ | `a157d37` — 4 dirty files from the guide were uncommitted. |
| 1.3 | Add `.gitignore` | 🤖 | ✅ | Added; also untracked Xcode user state that was already committed. |
| 1.4 | Create private GitHub repo + push | 🤖 | ⬜ | Depends on 0.8. |
| 1.5 | `IPHONEOS_DEPLOYMENT_TARGET` 26.2 → 18.0 | 🤖 | ✅ | **D2.** Done in both Debug and Release. |
| 1.6 | `TARGETED_DEVICE_FAMILY` `1,2` → `1` | 🤖 | ✅ | **A5.** Also removed the iPad orientation keys. |
| 1.7 | Resolve Info.plist conflict | 🤖 | ✅ | Deleted the stub and the now-dead `PBXFileSystemSynchronizedBuildFileExceptionSet` that existed only to exclude it. |
| 1.8 | Add `NSPhotoLibraryAddUsageDescription` | 🤖 | ✅ | 🔴 Fixed. Also added `ITSAppUsesNonExemptEncryption=NO`, app category `photography`, display name. |
| 1.9 | Rename `cameramanager.swift` → `CameraManager.swift` | 🤖 | ✅ | Project uses synchronized folder groups, so the rename needed no pbxproj file references. |
| 1.10 | `SWIFT_VERSION` 5.0 → 6.0 + strict concurrency | 🤖 | ✅ | Swift 6 language mode on, builds with **zero warnings**. Migration surfaced a real bug: `PhotoCaptureDelegate` was implicitly `@MainActor` (target default) while AVFoundation calls it back on its own queue. |
| 1.11 | SwiftLint + SwiftFormat config & build phase | 🤖 | ⬜ | Depends on 0.6. |

## Phase 2 — Camera layer rebuild

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 2.1 | Move session config + `startRunning` off main thread | 🤖 | ✅ | `CameraController` funnels every mutation through a private serial `sessionQueue`; `@unchecked Sendable` with the invariant documented at the type. |
| 2.2 | Add session lifecycle (`stopRunning` on disappear) | 🤖 | ✅ | `stop()` on disappear; `CameraView` calls it from `.onDisappear`. |
| 2.3 | Guard flash against unsupported devices | 🤖 | ✅ | `capturePhoto` consults `photoOutput.supportedFlashModes`; UI hides the toggle entirely on the front camera and clears `isFlashOn` when flipping. |
| 2.4 | Replace `CameraPreview` with `layerClass` UIView | 🤖 | ✅ | `PreviewUIView` overrides `layerClass`, so UIKit sizes the layer. Deprecated `UIScreen.main` and the `sublayers?.first` lookup are both gone. |
| 2.5 | Rotation via `AVCaptureDevice.RotationCoordinator` | 🤖 | ✅ | `AVCaptureDevice.RotationCoordinator` + KVO on `videoRotationAngleForHorizonLevelCapture`, applied to the photo connection at capture time. |
| 2.6 | Real permission-denied state + Settings deep link | 🤖 | ✅ | Real `.denied` phase with a lock screen and an Open Settings deep link — **verified by screenshot**. Was `default: break`. |
| 2.7 | Tap-to-focus/expose, zoom, dual-wide camera | 🤖 | ✅ | Tap-to-focus/expose (converted through the preview layer), pinch zoom capped at 8x, `.builtInDualWideCamera` preferred over plain wide. |
| 2.8 | Thermal + interruption handling | 🤖 | ✅ | `AsyncStream<CameraEvent>` from session interruption/runtime-error notifications; model shows a banner and auto-resumes when the interruption ends. |

## Phase 3 — Imaging pipeline

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 3.1 | `ImageProcessor` w/ shared Metal `CIContext` | 🤖 | 🔄 | `ImageProcessor.swift` written: shared Metal `CIContext`, ordered chain (tone → colour → LUT → fade → grain → vignette), `CIMix` intensity blend, JPEG export. Not yet exercised against real images. |
| 3.2 | `LUTLoader` — `.cube` → `CIColorCubeWithColorSpace` | 🤖 | ✅ | `CubeLUT.swift` — Adobe Cube parser (TITLE/LUT_3D_SIZE/DOMAIN_MIN/MAX, comments, blank lines), typed errors, 128 dimension cap, `LUTStore` parse cache behind an `NSLock`. |
| 3.3 | `AdjustmentStack` | 🤖 | ✅ | `Adjustments.swift` — 10 parameters, neutral-by-default, per-key decoding so manifests only name what they change, `clamped()` treats profile data as untrusted. |
| 3.4 | Intensity blend (original ↔ styled) | 🤖 | ⬜ | |
| 3.5 | Split preview (downscaled, 30fps) vs export (full-res, EXIF) paths | 🤖 | ⬜ | |
| 3.6 | Thumbnail cache for profile grid | 🤖 | ⬜ | |

## Phase 4 — Style Profile catalog

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 4.1 | `StyleProfile` model + `StyleTag` | 🤖 | ✅ | `StyleProfile.swift` — `StyleTag` is raw-string backed so new tags need no app update; synthesised `.original` pass-through. |
| 4.2 | `ProfileRepository` protocol + bundled impl | 🤖 | ✅ | `ProfileRepository` protocol + `BundledProfileRepository`. This is the seam that makes D4 (IAP later) a swap. |
| 4.3 | JSON manifest + `.cube` files in Resources | 🤖 | ⬜ | Profiles are data, not code. |
| 4.4 | Shop UI: grid, search, tag chips, sort | 🤖 | ⬜ | Structural inspiration from Imagen only — no Imagen data/imagery/names/copy. |
| 4.5 | Detail sheet + before/after drag compare | 🤖 | ⬜ | |
| 4.6 | Ship 6–8 starter profiles | 🤖 | ⬜ | |
| 4.7 | Export Lightroom looks as `.cube` LUTs | 👤 | ⬜ | **A2.** This is what makes the profiles genuinely *yours*. Drop-in, no code change. |

## Phase 5 — Capture, gallery, polish

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 5.1 | Live filtered viewfinder (VideoDataOutput → CIImage → MTKView) | 🤖 | ⬜ | ⚠️ Guide's `AVCaptureVideoPreviewLayer` **cannot** show filtered preview. Biggest deviation from the guide. |
| 5.2 | Profile strip over viewfinder | 🤖 | ⬜ | |
| 5.3 | Full-res capture through same chain | 🤖 | ⬜ | |
| 5.4 | Gallery view (SwiftData) | 🤖 | ⬜ | `ContentView.swift:5` `showGallery` is wired to a button that does nothing today. |
| 5.5 | Replace deprecated `.navigationBarHidden` | 🤖 | ✅ | `.navigationBarHidden` → `.toolbar(.hidden, for: .navigationBar)`. |
| 5.6 | App icon, accent color, launch screen | 🤝 | ⬜ | 1024pt single-size asset. |
| 5.7 | Haptics, empty/error states, VoiceOver, Dynamic Type | 🤖 | ⬜ | |

## Phase 6 — Tests & CI

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 6.1 | Swift Testing unit tests | 🤖 | ⬜ | `.cube` parsing incl. malformed, profile decoding, adjustment math, blending. |
| 6.2 | Golden-image render tests | 🤖 | ⬜ | Catches silent color regressions. |
| 6.3 | UI tests: home → camera → profile → capture | 🤖 | ⬜ | |
| 6.4 | GitHub Actions build + test | 🤖 | ⬜ | |
| 6.5 | Physical iPhone test pass | 👤 | ⬜ | 🔴 Only gate Claude cannot clear — simulator has no camera. |

## Phase 7 — App Store submission

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 7.1 | Enroll in Apple Developer Program ($99/yr) | 👤 | ⬜ | **A3.** Start early — 24–48h approval. Nothing blocks until 7.7. |
| 7.2 | `PrivacyInfo.xcprivacy` | 🤖 | ⬜ | Mandatory. No tracking, no collection — photos stay on device. |
| 7.3 | Write + host privacy policy | 🤝 | ⬜ | Required for camera apps. `~/MyApps/Photowebsite/` (currently empty) is the natural host. |
| 7.4 | Check "PhotoStyler" name availability | 👤 | ⬜ | Before committing to the name. |
| 7.5 | App Store Connect record | 👤 | ⬜ | Photo & Video, age rating, nutrition labels, `ITSAppUsesNonExemptEncryption=false`. |
| 7.6 | 6.9" screenshots + description + keywords | 🤝 | ⬜ | |
| 7.7 | Archive → upload → TestFlight → submit | 🤝 | ⬜ | |
| 7.8 | `/security-review` + `/code-review` before upload | 🤖 | ⬜ | |

## Deferred (post-1.0)

| # | Task | Notes |
|---|------|-------|
| D.1 | Photo library import & edit | **A1** — v1.1. Engine built behind a protocol so this is additive. |
| D.2 | StoreKit 2 IAP for profile packs | **D4** — repository protocol already accommodates it. |
| D.3 | AI style transfer (Create ML → Core ML) | Guide's Phase 2 / Month 3+. |
