# PhotoStyler — Project Guide & Decision Log

**Author:** Murali (ML Creative Studios)
**Platform:** iOS 18.0+ (iPhone), SwiftUI, Swift 6
**Bundle ID:** `com.mlcreativestudios.PhotoStyler`
**Repo:** `~/MyApps/PhotoStyler`
**Goal:** App Store release
**Last updated:** 2026-09-06

> **This file is the context doc.** It records *why* things are the way they are.
> `tasks.md` records *what's left*. Read both when resuming after a pause.

---

## 🔄 Resume Here

**Where we are:** Phases 0–6 complete. The app builds under Swift 6 with zero
warnings, has 38 passing tests and CI, and runs end to end in the Simulator:
styled camera, profile shop, before/after compare, and gallery.

**What Claude can still do unaided:** nothing substantial. Every remaining task
needs Murali's accounts or assets — see *Waiting on Murali* below.

**Fastest way to move the project:** enrol in the Apple Developer Program (it has
the longest clock) and send one sample photograph (it improves every screen and
all five App Store screenshots at once).

---

## 🎯 App Vision

A photography app pairing a **custom camera** with a **catalog of style profiles** — modeled on the browse-and-apply experience of [Imagen AI's Profile Shop](https://account.imagen-ai.com/profile-shop/) — eventually including AI style transfer trained on Murali's own wedding editing style.

A **Style Profile** is a named look (Cinematic, Editorial, Warm, Film, Moody, Vintage…) with tags, a cover preview, a 3D LUT, tunable adjustments, and an intensity slider.

⚠️ **IP boundary:** we take structural and UX inspiration from Imagen's shop only. No Imagen profile data, imagery, creator names, or copy ships in this app. All profiles are authored by Murali.

---

## 📌 Decision Log

Every decision, with its reasoning. Add a row whenever a call is made.

| # | Decision | Value | Why | Date |
|---|----------|-------|-----|------|
| D1 | Distribution | **App Store release** | Confirmed by Murali. Sets the bar: privacy manifest, signing, review assets, $99/yr program. | 2026-09-05 |
| D2 | Minimum iOS | **18.0** (was 26.2) | 26.2 made the app installable on virtually no device. 18.0 covers ~6 years of iPhones while keeping `@Observable`, SwiftData, `RotationCoordinator`. | 2026-09-05 |
| D3 | Filter concept | **Style Profile catalog** | Replaces the guide's original flat "filter presets". Driven by the Imagen reference Murali supplied. | 2026-09-05 |
| D4 | Shop scope | **Free bundled catalog now, IAP later** | No backend or payments in v1. Profiles are data (JSON + `.cube`) behind a `ProfileRepository` protocol, so StoreKit 2 becomes a swap rather than a rewrite. | 2026-09-05 |
| D5 | Tooling | **Full setup** | Homebrew, Node, XcodeBuildMCP, SwiftLint, SwiftFormat, xcbeautify, gh. XcodeBuildMCP lets Claude build/run/screenshot and self-verify. | 2026-09-05 |
| D6 | Swift 6 migration timing | **Phase 2, not Phase 1** | Flipping `SWIFT_VERSION` to 6.0 before the camera rewrite would break the baseline build, since the camera code is the source of both `Sendable` errors. Fix the cause, then flip. | 2026-09-05 |
| D7 | Info.plist strategy | **Generated only** | Project had both `GENERATE_INFOPLIST_FILE=YES` and an `INFOPLIST_FILE` pointing at an empty `<dict/>`. Kept the generated route; deleted the stub and its dead exception set. | 2026-09-05 |
| D8 | Live preview renderer | **Metal (`MTKView`)** | `AVCaptureVideoPreviewLayer` cannot show a filtered preview. Frames go video output → `CIImage` → profile chain → drawable. | 2026-09-05 |
| D9 | Frame handoff | **Newest-frame box, drop stale** | Frames arrive on the capture queue; `MTKView` is main-actor bound. Apple's samples draw from the capture queue and Swift 6 flags every access. A lock-guarded box keeps only the newest frame, so falling behind drops frames instead of accruing latency. | 2026-09-05 |
| D10 | Simulator camera | **Synthetic feed** | The Simulator has no capture hardware, so the styled camera UI would be unreachable and untestable off-device. Fallback lives in the runtime-error handler, not around `configure()`: the Simulator configures and starts cleanly, then fails at first frame. | 2026-09-05 |
| D11 | Debug launch arguments | **Kept in the shipping code, `#if DEBUG`** | `-openCamera`, `-openStyles`, `-openProfile`, `-openGallery`, `-forceCameraDenied`. System permission alerts cannot be driven reliably from XCUITest, and the Simulator has no camera; these are the only way to reach those states in tests and screenshots. | 2026-09-05 |
| D12 | Photo storage | **Metadata in SwiftData, JPEG on disk** | Image bytes in the store would bloat it and slow every query. The photo is in the user's library anyway; this is the app's own record of which profile produced which frame. | 2026-09-05 |
| D13 | Render test style | **Measured pixel values, not golden images** | Assertions on mean colour stay readable in review and need no binary fixtures that rot. | 2026-09-06 |
| D14 | CI simulator choice | **Discovered at runtime** | Runner images change their simulator lineup without notice, so a hard-coded device name is a slow-motion breakage. | 2026-09-06 |

### Open assumptions — revisit if wrong

| # | Assumption | Why | Status |
|---|------------|-----|--------|
| A1 | Camera in v1, photo import in v1.1 | Camera is what the project is built around and is the harder half. Engine sits behind a protocol so import is additive. | ⚠️ Unconfirmed |
| A2 | Profile = 3D LUT + adjustments + intensity | Only approach that reproduces Murali's *actual* Lightroom edits while staying GPU-fast for live preview. | ⚠️ Unconfirmed |
| A3 | Not yet enrolled in Apple Developer Program | Sequenced early (24–48h approval); nothing blocks until archiving. | ⚠️ Unconfirmed |
| A4 | Repo at `~/MyApps/PhotoStyler`, private GitHub | Desktop is a fragile home for a real project. | ✅ Done |
| A5 | iPhone only | Avoids iPad layouts and a second screenshot set for no v1 benefit. | ✅ Done |

---

## 🖥 Current State (verified 2026-09-06)

**Environment:** macOS 27.0 · Xcode 26.6 · Swift 6.3.3 · arm64 · git 2.50.1
**Repo:** https://github.com/mltechexperts/PhotoStyler (private)

| Component | State |
|-----------|-------|
| iOS platform | ✅ iOS 26.5 installed. Was the original hard blocker. |
| Project builds | ✅ Swift 6 language mode, **zero warnings**. |
| Tests | ✅ **38 green** — 32 Swift Testing units in 4 suites, 6 XCUITest. |
| CI | ✅ `.github/workflows/ci.yml`, build+test and SwiftLint. ⚠️ Private repo: macOS minutes bill at **10×**, so ~200 usable minutes/month on the free tier. |
| Homebrew / Node / XcodeBuildMCP | ❌ Still not installed (needs sudo). Convenience only — `xcodebuild`/`simctl` cover everything. |
| `gh` | ✅ Authenticated as `mltechexperts`. |

### Phases

| Phase | State |
|-------|-------|
| 0 Toolchain · 1 Hygiene · 2 Camera · 3 Imaging · 4 Shop · 5 Capture/Gallery · 6 Tests/CI | ✅ Complete |
| 7 App Store | 🔄 Privacy manifest done; policy drafted; screenshots automated. Rest needs Murali's accounts. |

### Waiting on Murali

| # | Item | Why it matters |
|---|------|----------------|
| 7.1 | Apple Developer Program enrolment | Longest clock (24–48h; 1–2 weeks as a company). Gates submission entirely. |
| — | **A sample photo** | Biggest single visual win. `SampleImage.image` feeds the shop grid, compare view, camera strip *and* all five App Store screenshots. Everything currently renders a colour chart. |
| 7.3 | Host the privacy policy | App Review needs a reachable URL. Draft at `docs/privacy-policy.md`. |
| 6.5 | Physical iPhone pass | No camera code has touched real hardware. The one gate Claude cannot clear. |
| 4.7 | Lightroom `.cube` exports | Makes the profiles genuinely Murali's rather than generated starters. |
| 7.4 | Check the name is free | Cheap now, expensive after icon and screenshots. |

### Corrections to earlier versions of this guide
- The guide claimed Phase 1 setup was ✅ done. In reality the project was on the Desktop, not in `Phoneappphoto/`, and **could not build at all**.
- The guide's cost table said "$0 total to build & test". True for testing on your own device, but **App Store release costs $99/yr** (D1).
- The guide's roadmap ("filters", "presets") predates D3 — the profile catalog is a materially larger surface.

---

## 🏗 Target Architecture

```
PhotoStyler/
├── App/                  PhotoStylerApp.swift, routing
├── Core/
│   ├── Camera/           session (off-main), preview view, rotation coordinator
│   ├── Imaging/          ImageProcessor, LUTLoader, AdjustmentStack, thumbnail cache
│   └── Profiles/         StyleProfile, StyleTag, ProfileRepository (protocol)
├── Features/
│   ├── Home/  Capture/  ProfileShop/  Gallery/
├── Resources/            LUTs/*.cube, profiles.json, Assets.xcassets
└── Support/              PrivacyInfo.xcprivacy
```

```swift
struct StyleProfile: Identifiable, Codable, Sendable {
    let id, name, author: String
    let tags: [StyleTag]
    let lutName: String?          // .cube in bundle; later downloadable
    let adjustments: Adjustments
    let coverAsset: String
}
```

### ⚠️ The single most important technical finding

**`AVCaptureVideoPreviewLayer` cannot display a filtered preview.** It renders raw sensor output straight to the screen — no Core Image filter can be inserted into it. The original `CameraManager.swift` in this guide was built on it.

A live *styled* viewfinder therefore requires:

```
AVCaptureVideoDataOutput → CMSampleBuffer → CIImage
    → profile filter chain (LUT + adjustments) → MTKView
```

This is why the imaging pipeline (Phase 3) must land before the styled camera UI (Phase 5), and it is the biggest deviation from the code this guide originally contained.

---

## 🐛 Known defects in the original camera code

Recorded so they aren't reintroduced. All addressed in Phase 2 (`tasks.md`).

| Defect | Consequence |
|--------|-------------|
| Session config + `startRunning` on the main thread | Visible hang when opening the camera |
| No `stopRunning` | Camera stays hot: battery drain, hardware held |
| `settings.flashMode = .on` unconditionally | Front camera has no flash — must check `supportedFlashModes` |
| `UIScreen.main.bounds` in `CameraPreview` | Deprecated in iOS 26; wrong on multi-scene |
| Preview layer fetched via `sublayers?.first` | Fragile; use a `UIView` subclass with `layerClass` |
| No rotation handling | Landscape photos save wrong-way-up |
| `checkPermissions` → `default: break` | Denied permission = silent black screen, no recovery |
| `showGallery` state wired to a button that does nothing | Dead UI in `ContentView.swift` |
| Missing `NSPhotoLibraryAddUsageDescription` | **Crash on first capture** on device — fixed in Phase 1 |

## 🐛 Defects found later, and how

| Defect | Found by | Notes |
|--------|----------|-------|
| `@Published` unresolvable | First build | Target enables `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`, so Combine is no longer re-exported by SwiftUI. Removed entirely by moving to `@Observable`. |
| `PhotoCaptureDelegate` implicitly `@MainActor` | Swift 6 migration | Target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; AVFoundation calls the delegate on its own queue. Imaging types needed `nonisolated` for the same reason, or the render pipeline would have been pinned to the main thread. |
| **`CITemperatureAndTint` inverted on both axes** | Render tests | The filter adapts *from* `neutral` *to* `targetNeutral`, so a **lower** target temperature warms and a **negative** target tint pushes magenta. Golden Hour rendered cool and Moody Blue warm — it compiled, ran, and simply looked wrong. Verified empirically with a probe before fixing. |
| Orphaned `CameraPreviewView.swift` | CI SwiftLint | Phase 5 replaced it with `MetalCameraPreview` and left the file behind. Its `as!` was the only force cast in the codebase. Deleted rather than suppressed. |

---

## 🧠 SwiftUI Concepts Reference

| Concept | What it does | Example |
|---------|-------------|---------|
| `VStack` / `HStack` / `ZStack` | Vertical / horizontal / layered stacking | Controls over camera |
| `@State` | A value the view owns and reacts to | `showCamera = true` |
| `@Observable` | Modern replacement for `ObservableObject` + `@Published` (iOS 17+) | Camera state |
| `@StateObject` | Creates and owns a reference-type model | Legacy `CameraManager` |
| `NavigationStack` | Screen-to-screen navigation | Home → Camera |
| `.fullScreenCover` | Presents a view over the whole screen | Camera over home |
| `Image(systemName:)` | Apple's SF Symbols | `camera.fill` |
| `UIViewRepresentable` | Bridges UIKit views into SwiftUI | Camera preview, `MTKView` |

**Core Image terms:** `CIImage` (a recipe, not pixels — lazy) · `CIFilter` (an operation) · `CIContext` (renders the recipe; expensive, create once) · `CIColorCube` (applies a 3D LUT) · `.cube` (Adobe LUT text format).

---

## 🔧 Troubleshooting

**`xcodebuild: error: iOS 26.5 is not installed`** — the platform is missing. `xcodebuild -downloadPlatform iOS` (8.5 GB). This was the original blocker.

**Camera is a black screen in the Simulator** — expected; the Simulator has no camera. Test on a physical iPhone.

**Run on your iPhone** — connect via USB, pick the device in Xcode's device selector, Cmd+R. First run: iPhone → Settings → General → VPN & Device Management → trust the certificate.

**"Cannot find CameraView/CameraManager"** — no longer applies. This project uses Xcode's synchronized folder groups, so files in `PhotoStyler/` join the target automatically; there is no Target Membership checkbox to set.

---

## 📝 Costs

| Item | Cost |
|------|------|
| Xcode, Simulator, Create ML, Homebrew tooling | Free |
| Testing on your own iPhone (free Apple ID signing) | Free |
| **Apple Developer Program — required for App Store (D1)** | **$99/year** |

---

*Originally created with help from Claude (Anthropic); maintained as a living decision log.*
