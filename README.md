# 5 More

5 More turns “five more minutes” into a small family memory. A parent takes one photo to begin a five-minute timer; the photo remains at the center of the countdown and is saved to the family’s normal Photos library.

The product requirements, scope decisions, roadmap, and acceptance checklist live in [`PRD.md`](PRD.md).

## Core interaction

```text
crayon hero → live camera in the same frame → captured photo + five-minute timer
```

## Technology

- iOS 17+
- SwiftUI
- AVFoundation camera
- PhotoKit storage and lookup
- SwiftData metadata
- StoreKit 2 non-consumable lifetime unlock with Family Sharing
- Keychain-backed thirty-use allowance
- Vision hand pose detection for timer length
- Local notifications for background timer completion

Photos stay in Apple Photos. The app stores only local metadata and a temporary cache copy while a timer is active. There is no account, backend, photo upload, advertising SDK, or subscription.

## Run locally

1. Generate the Xcode project:

   ```sh
   xcodegen generate
   ```

2. Open `FiveMore.xcodeproj` in Xcode.
3. Select the `FiveMore` scheme and an iPhone simulator or physical iPhone.
4. Build and run.

The simulator uses a clearly labeled camera demo image so the complete capture-to-timer flow can be exercised. A physical iPhone uses the real rear camera.

The included `Products.storekit` file supplies a local `$4.99` non-consumable product for StoreKit testing. The product must be recreated in App Store Connect before TestFlight or release.

StoreKit configuration only loads when the app is launched from its Xcode scheme. Running a build installed directly on a device queries the real App Store instead, so the price stays unavailable until the product exists in App Store Connect.

## Project structure

```text
FiveMore/
├── App
├── Core
├── DesignSystem
├── Features
│   ├── Capture
│   ├── Memories
│   ├── Paywall
│   └── Settings
├── Models
├── Resources
└── Services
```

## Current MVP boundaries

- Timer length set by how many fingers the camera sees; five minutes when no hand is shown
- Thirty successful moments free
- One-time lifetime unlock after the free allowance, shared through Family Sharing
- Repeating a moment reuses the same photo and never consumes a free use
- No login, cloud sync, profiles, social features, or configurable sounds
- Existing Memories remain available after the free allowance is exhausted

