# PhotoStyler — Task Tracker

**Owner legend:** 🤖 = Claude does it · 👤 = Murali does it (interactive/account/physical device) · 🤝 = both
**Status legend:** ⬜ not started · 🔄 in progress · ✅ done · ⛔ blocked · ⏭ deferred

> Living file. Updated as work proceeds. Paired with `PhotoStyler_Project_Guide.md` (decisions + context).
> **Resume here:** read the "Current position" line below, then the guide's Decision Log.

**Current position:** Phase 0 — iOS platform downloading. Phase 1 project hygiene done and committed (`936885a`). Blocked on Murali for Homebrew (0.5) and `gh auth login` (0.8).
**Last updated:** 2026-09-05

---

## Phase 0 — Unblock the machine ⛔ BLOCKING EVERYTHING

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 0.1 | Audit disk space | 🤖 | ✅ | 40 GiB free / 96% full. Xcode caches only ~335 MB — not the problem. Big items are Murali's photo work (Desktop 247G, Pictures 159G, Downloads 119G). Nothing deleted. |
| 0.2 | Free additional space if needed | 👤 | ⬜ | Only if 0.3 fails. Candidates Murali may choose: `~/Desktop/Screen Recording 2026-09-03…mov` (26G), `~/Downloads/Installers` (1.6G), `VSCode-darwin-arm64.dmg` (288M). **Never touch client galleries.** |
| 0.3 | `xcodebuild -downloadPlatform iOS` | 🤖 | 🔄 | THE blocker. Xcode 26.6 needs iOS 26.5 platform; only 26.3 sim runtime present. Running in background. |
| 0.4 | Verify destinations resolve | 🤖 | ⬜ | `xcodebuild -showdestinations` must list real simulators (currently lists zero). |
| 0.5 | Install Homebrew | 🤖 | ⛔ | 🔴 **Needs Murali** — `sudo` requires a password, so Claude cannot install Homebrew. Run: `! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/brew/HEAD/install.sh)"` |
| 0.6 | `brew install node swiftlint swiftformat xcbeautify gh` | 🤖 | ⬜ | Node needed for XcodeBuildMCP. |
| 0.7 | Add XcodeBuildMCP server | 🤖 | ⬜ | `claude mcp add xcodebuild -- npx -y xcodebuildmcp@latest`. Gives build/test/sim-control/screenshots. |
| 0.8 | `gh auth login` | 👤 | ⬜ | Interactive — run `! gh auth login` in the session. |
| 0.9 | Baseline build of untouched project | 🤖 | ⬜ | Must be green before any code changes. |

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
| 1.10 | `SWIFT_VERSION` 5.0 → 6.0 + strict concurrency | 🤖 | ⏭ | **Moved to Phase 2.** Flipping to Swift 6 now would break the baseline build before the camera rewrite lands (task 2.1) that actually fixes the `Sendable` errors. |
| 1.11 | SwiftLint + SwiftFormat config & build phase | 🤖 | ⬜ | Depends on 0.6. |

## Phase 2 — Camera layer rebuild

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 2.1 | Move session config + `startRunning` off main thread | 🤖 | ⬜ | Currently blocks main thread → launch hang. Also the real fix for `Sendable` errors at `cameramanager.swift:34,71`. |
| 2.2 | Add session lifecycle (`stopRunning` on disappear) | 🤖 | ⬜ | Never stopped today → battery drain, holds hardware. |
| 2.3 | Guard flash against unsupported devices | 🤖 | ⬜ | Front camera has no flash; must check `output.supportedFlashModes`. |
| 2.4 | Replace `CameraPreview` with `layerClass` UIView | 🤖 | ⬜ | Kills deprecated `UIScreen.main.bounds` and the fragile `sublayers?.first` lookup. |
| 2.5 | Rotation via `AVCaptureDevice.RotationCoordinator` | 🤖 | ⬜ | Without it, landscape photos save wrong-way-up. |
| 2.6 | Real permission-denied state + Settings deep link | 🤖 | ⬜ | Currently `default: break` → silent dead screen. |
| 2.7 | Tap-to-focus/expose, zoom, dual-wide camera | 🤖 | ⬜ | |
| 2.8 | Thermal + interruption handling | 🤖 | ⬜ | |

## Phase 3 — Imaging pipeline

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 3.1 | `ImageProcessor` w/ shared Metal `CIContext` | 🤖 | ⬜ | `cacheIntermediates: false`, renders off main thread. |
| 3.2 | `LUTLoader` — `.cube` → `CIColorCubeWithColorSpace` | 🤖 | ⬜ | Parse once, cache. Never per-frame. |
| 3.3 | `AdjustmentStack` | 🤖 | ⬜ | Exposure, contrast, saturation, temp/tint, highlights/shadows, grain, vignette, fade, skin-tone protection. |
| 3.4 | Intensity blend (original ↔ styled) | 🤖 | ⬜ | |
| 3.5 | Split preview (downscaled, 30fps) vs export (full-res, EXIF) paths | 🤖 | ⬜ | |
| 3.6 | Thumbnail cache for profile grid | 🤖 | ⬜ | |

## Phase 4 — Style Profile catalog

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 4.1 | `StyleProfile` model + `StyleTag` | 🤖 | ⬜ | Codable/Sendable. |
| 4.2 | `ProfileRepository` protocol + bundled impl | 🤖 | ⬜ | **D4** — protocol is what makes StoreKit IAP a later swap, not a rewrite. |
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
| 5.5 | Replace deprecated `.navigationBarHidden` | 🤖 | ⬜ | `ContentView.swift:71` → `.toolbar(.hidden, for: .navigationBar)`. |
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
