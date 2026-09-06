# PhotoStyler — Task Tracker

**Owner legend:** 🤖 = Claude does it · 👤 = Murali does it (interactive/account/physical device) · 🤝 = both
**Status legend:** ⬜ not started · 🔄 in progress · ✅ done · ⛔ blocked · ⏭ deferred

> Living file. Updated as work proceeds. Paired with `PhotoStyler_Project_Guide.md` (decisions + context).
> **Resume here:** read the "Current position" line below, then the guide's Decision Log.

**Current position:** Phases 0, 1, 2 complete. Swift 6, zero warnings. Camera rewritten and its failure paths verified by screenshot; the live viewfinder still needs a physical iPhone (6.5). Phases 0–6 complete except assets that need Murali (4.7 LUTs, 5.6 final icon) and the device pass (6.5). 38 tests green. Next: Phase 7 — App Store submission prep (privacy manifest, policy, Connect record). App builds with zero warnings under Swift 6 and runs end to end in the Simulator. Repo is backed up to GitHub. Only remaining Murali blocker is Homebrew (0.5), which is convenience, not capability.
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
| 0.8 | `gh auth login` | 👤 | ✅ | Logged in as `mltechexperts` via browser flow (after the device-code flow failed twice). `gh auth setup-git` writes a **per-host** helper, not global `credential.helper`. |
| 0.9 | Baseline build of untouched project | 🤖 | ✅ | 🎉 **First successful build of this project.** Real failure was `@Published` needing an explicit `import Combine` — the project enables `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`, so SwiftUI no longer re-exports it. Installed and launched on iPhone 17 sim; home screen verified by screenshot. |

## Phase 1 — Project hygiene & repo

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 1.1 | Move repo to `~/MyApps/PhotoStyler` | 🤖 | ✅ | Was `~/Desktop/PhotoStyler`. Git history preserved (2 commits). Guide moved in alongside. |
| 1.2 | Commit pre-existing WIP | 🤖 | ✅ | `a157d37` — 4 dirty files from the guide were uncommitted. |
| 1.3 | Add `.gitignore` | 🤖 | ✅ | Added; also untracked Xcode user state that was already committed. |
| 1.4 | Create private GitHub repo + push | 🤖 | ✅ | **https://github.com/mltechexperts/PhotoStyler** — private, `main`, 6 commits pushed. Local and remote in sync. |
| 1.5 | `IPHONEOS_DEPLOYMENT_TARGET` 26.2 → 18.0 | 🤖 | ✅ | **D2.** Done in both Debug and Release. |
| 1.6 | `TARGETED_DEVICE_FAMILY` `1,2` → `1` | 🤖 | ✅ | **A5.** Also removed the iPad orientation keys. |
| 1.7 | Resolve Info.plist conflict | 🤖 | ✅ | Deleted the stub and the now-dead `PBXFileSystemSynchronizedBuildFileExceptionSet` that existed only to exclude it. |
| 1.8 | Add `NSPhotoLibraryAddUsageDescription` | 🤖 | ✅ | 🔴 Fixed. Also added `ITSAppUsesNonExemptEncryption=NO`, app category `photography`, display name. |
| 1.9 | Rename `cameramanager.swift` → `CameraManager.swift` | 🤖 | ✅ | Project uses synchronized folder groups, so the rename needed no pbxproj file references. |
| 1.10 | `SWIFT_VERSION` 5.0 → 6.0 + strict concurrency | 🤖 | ✅ | Swift 6 language mode on, builds with **zero warnings**. Migration surfaced a real bug: `PhotoCaptureDelegate` was implicitly `@MainActor` (target default) while AVFoundation calls it back on its own queue. |
| 1.11 | SwiftLint + SwiftFormat config & build phase | 🤖 | ✅ | `.swiftlint.yml` added and wired into CI. Local install still needs Homebrew (0.5); CI installs it on the runner. |

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
| 3.1 | `ImageProcessor` w/ shared Metal `CIContext` | 🤖 | ✅ | Exercised end-to-end: 8 profiles render correctly through the shared Metal `CIContext`. |
| 3.2 | `LUTLoader` — `.cube` → `CIColorCubeWithColorSpace` | 🤖 | ✅ | `CubeLUT.swift` — Adobe Cube parser (TITLE/LUT_3D_SIZE/DOMAIN_MIN/MAX, comments, blank lines), typed errors, 128 dimension cap, `LUTStore` parse cache behind an `NSLock`. |
| 3.3 | `AdjustmentStack` | 🤖 | ✅ | `Adjustments.swift` — 10 parameters, neutral-by-default, per-key decoding so manifests only name what they change, `clamped()` treats profile data as untrusted. |
| 3.4 | Intensity blend (original ↔ styled) | 🤖 | ⬜ | |
| 3.5 | Split preview (downscaled, 30fps) vs export (full-res, EXIF) paths | 🤖 | ✅ | `previewImage(_:maxDimension:)` splits the downscaled path from full-res export. |
| 3.6 | Thumbnail cache for profile grid | 🤖 | ✅ | `ThumbnailRenderer` with `NSCache` (80 entries), keyed by profile id + size, rendered on a detached task. |

## Phase 4 — Style Profile catalog

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 4.1 | `StyleProfile` model + `StyleTag` | 🤖 | ✅ | `StyleProfile.swift` — `StyleTag` is raw-string backed so new tags need no app update; synthesised `.original` pass-through. |
| 4.2 | `ProfileRepository` protocol + bundled impl | 🤖 | ✅ | `ProfileRepository` protocol + `BundledProfileRepository`. This is the seam that makes D4 (IAP later) a swap. |
| 4.3 | JSON manifest + `.cube` files in Resources | 🤖 | ✅ | `Resources/profiles.json` (8 profiles) + 4 generated 33³ `.cube` LUTs. Xcode flattens them to the bundle root, which `LUTStore`'s lookup already handles. |
| 4.4 | Shop UI: grid, search, tag chips, sort | 🤖 | ✅ | `ProfileShopView`: adaptive grid, `.searchable`, scrolling tag chips (AND-combining), curated/name sort, empty state with Clear Filters. |
| 4.5 | Detail sheet + before/after drag compare | 🤖 | ✅ | `ProfileDetailView` with drag-to-compare divider and intensity slider. Re-renders are quantised to 20 steps so dragging doesn't queue a render per pixel. |
| 4.6 | Ship 6–8 starter profiles | 🤖 | ✅ | 8 starters: Cinematic, Warm Film, Airy, Monochrome (LUT-backed) + Editorial, Golden Hour, Moody Blue, Natural (adjustments only). Generator at `tools/generate_luts.py`. |
| 4.7 | Export Lightroom looks as `.cube` LUTs | 👤 | ⬜ | **A2.** This is what makes the profiles genuinely *yours*. Drop-in, no code change. |

## Phase 5 — Capture, gallery, polish

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 5.1 | Live filtered viewfinder (VideoDataOutput → CIImage → MTKView) | 🤖 | ✅ | `MetalPreviewView` + video data output. Frames hand over to the main actor through a lock-guarded box keeping only the newest frame. **Verified in the Simulator via `SimulatedCameraFeed`** — without it this UI is unreachable off-device. |
| 5.2 | Profile strip over viewfinder | 🤖 | ✅ | `ProfileStrip` over the viewfinder; each swatch is the profile rendered on the sample image, with haptics on selection. |
| 5.3 | Full-res capture through same chain | 🤖 | ✅ | Capture runs the full-resolution frame through the same chain and carries source EXIF into the JPEG. |
| 5.4 | Gallery view (SwiftData) | 🤖 | ✅ | SwiftData `CapturedPhoto` (metadata only; JPEGs live in the app container), grid + detail + delete, empty state. Thumbnails downsampled via `CGImageSource` off the main actor. |
| 5.5 | Replace deprecated `.navigationBarHidden` | 🤖 | ✅ | `.navigationBarHidden` → `.toolbar(.hidden, for: .navigationBar)`. |
| 5.6 | App icon, accent color, launch screen | 🤝 | ✅ | Iris mark generated by `tools/generate_icon.swift` for all three iOS 26 slots (light/dark/tinted), 1024², **no alpha**. Accent colour set to the icon's amber. 🔴 Placeholder — replace with a designed mark. |
| 5.7 | Haptics, empty/error states, VoiceOver, Dynamic Type | 🤖 | ✅ | Haptics on shutter and profile select; VoiceOver labels and selected traits on strip/cards/controls; empty + error states throughout; semantic fonts for Dynamic Type. |

## Phase 6 — Tests & CI

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 6.1 | Swift Testing unit tests | 🤖 | ✅ | **32 tests, 4 suites** (Swift Testing). `.cube` parsing incl. 7 malformed cases, adjustment decode/clamp, profile decode, catalogue integrity. |
| 6.2 | Golden-image render tests | 🤖 | ✅ | Render tests assert on measured pixel values rather than stored fixtures. **Caught a real bug**: `CITemperatureAndTint` was inverted on both axes, so Golden Hour rendered cool and Moody Blue warm. |
| 6.3 | UI tests: home → camera → profile → capture | 🤖 | ✅ | **6 UI tests** driving the real app via the DEBUG launch hooks. Class is `@MainActor` — `XCUIApplication` is main-actor bound. |
| 6.4 | GitHub Actions build + test | 🤖 | ✅ | `.github/workflows/ci.yml` — build+test and SwiftLint. Simulator UDID is discovered at runtime because runner images change their lineup. Needed a **shared scheme**, since the autogenerated one lives in gitignored `xcuserdata`. |
| 6.5 | Physical iPhone test pass | 👤 | ⬜ | 🔴 Only gate Claude cannot clear — simulator has no camera. |

## Phase 7 — App Store submission

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 7.1 | Enroll in Apple Developer Program ($99/yr) | 👤 | ⬜ | **A3.** Start early — 24–48h approval. Nothing blocks until 7.7. |
| 7.2 | `PrivacyInfo.xcprivacy` | 🤖 | ✅ | `PrivacyInfo.xcprivacy` — no tracking, nothing collected, and **no required-reason APIs** (verified by search, not assumed). Confirmed bundled into the .app. |
| 7.3 | Write + host privacy policy | 🤝 | 🔄 | Draft at `docs/privacy-policy.md`. 🔴 **Needs Murali to host it** and give me the URL — App Review requires a reachable link. `~/MyApps/Photowebsite/` is the natural home. |
| 7.4 | Check "PhotoStyler" name availability | 👤 | ⬜ | Before committing to the name. |
| 7.5 | App Store Connect record | 👤 | ⬜ | Photo & Video, age rating, nutrition labels, `ITSAppUsesNonExemptEncryption=false`. |
| 7.6 | 6.9" screenshots + description + keywords | 🤝 | 🔄 | Automation done: `tools/screenshots.sh` captures the 5-screen set at the required 1320×2868 (6.9") with a fixed 9:41 status bar, driven by the DEBUG launch args. 🔴 **Blocked on a real sample photo** — screenshots of a colour chart will not sell the app. |
| 7.7 | Archive → upload → TestFlight → submit | 🤝 | ⬜ | |
| 7.8 | `/security-review` + `/code-review` before upload | 🤖 | ⬜ | |

## Deferred (post-1.0)

| # | Task | Notes |
|---|------|-------|
| D.1 | Photo library import & edit | **A1** — v1.1. Engine built behind a protocol so this is additive. |
| D.2 | StoreKit 2 IAP for profile packs | **D4** — repository protocol already accommodates it. |
| D.3 | AI style transfer (Create ML → Core ML) | Guide's Phase 2 / Month 3+. |
