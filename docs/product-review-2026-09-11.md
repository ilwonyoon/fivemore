# Five More — Product / UX Review

**Reviewed:** 2026-09-11
**Scope:** current iPhone build, product structure, visual system, image assets, monetization and sharing strategy

## What is now in better shape

- The large centered `5 More` title is replaced in the capture flow with a compact five-finger hand and **Five More Minutes** in the upper-left corner. It reads like a friendly app identity without competing with the photo.
- The Home and Memories artwork inside the Liquid Glass tab bar has been optically reduced by adding transparent breathing room to the PNGs. The tap target remains system-sized; only the drawn artwork is smaller.
- Every runtime image asset now has one canonical record in [`asset-manifest.json`](asset-manifest.json), plus a human-editable inventory workbook. The manifest has source path, target size, template behavior, current status, and an ImageGen prompt.

## Structural review

### P0 — keep the roadmap honest

The PRD previously described variable one-to-ten-finger timer lengths. The runtime intentionally supports only a stable open five-finger palm and always starts five minutes. The PRD has been corrected to make that product decision explicit.

The PRD also needs one more cleanup pass before release: it contains an older statement that V1 has no sound selection, but Settings now supports gentle built-in sounds, reusable Cheers, and Moment Voice. The current implementation is coherent; the roadmap wording should simply represent it as a deliberate V1 feature.

### P1 — protect the active flow from the tab bar

`RootView` keeps the two-tab bar visible during Camera, Timer, and Completion. It does preserve state, but the tab bar competes with the timer's “End early”, “Make our 5-second cheer”, and “Done” actions and permits a parent to leave a live moment by accident.

**Recommendation:** expose the capture phase through a small `CaptureFlowStore` or binding, then hide/disable the tab bar outside Home. Memories remains available before and after a moment, not in the middle of one. This is the highest-value next UI behavior change.

### P1 — split the capture feature by responsibility

`CaptureFlowView` currently owns UI layout, routing, camera orchestration, photo persistence, timer recovery, notification scheduling, and Moment Voice attachment. It is working, but future changes will be risky.

**Recommended boundary:**

| Unit | Owns |
| --- | --- |
| `CaptureFlowStore` | phase, active Moment, timer lifecycle, persistence coordination |
| `CaptureScreen` | live camera, hand guidance, shutter |
| `TimerScreen` | remaining time, end early, Moment Voice entry point |
| `CompletionScreen` | repeat / done and completion audio |
| existing services | camera, Photos, notification, audio file storage |

Do this after the active-tab-bar change; it should be a refactor with behavioral tests, not a redesign.

### P2 — make voice storage visible and robust

Moment Voice correctly targets compact local AAC (5 seconds, 16 kHz / 24 kbps, 200 clips or 10 MB). The current clip scan is synchronous and the audio library shares one folder with reusable Cheers. Prefixes prevent collisions today, but a `VoiceStorageService` actor and a Settings row such as “Moment voices: 18 of 200 · 0.5 MB” would make storage understandable and keep file work off the main UI path.

Before release, test a real device for: microphone denial/recovery, 200-clip and 10-MB limits, deletion of a Moment, and background local-notification playback. The existing automated tests do not prove those device behaviors.

## UI and UX review

| Area | Assessment | Next action |
| --- | --- | --- |
| Header | Compact hand + `Five More Minutes` is clearer than the former large wordmark. | Keep it. Do not create a second header-logo asset yet; reuse `SymbolFiveHand`. |
| Liquid Glass navigation | Artwork is now optically right-sized; system tap targets remain accessible. | Recheck on a real iPhone in Light and Dark appearance. |
| Main photo frame | The frame stays the central object across Home, Camera, and Timer. | Keep its position fixed; do not add timer effects above it. |
| Finger capture | Guidance makes the automatic shutter discoverable and a tap remains a fallback. | Test with children/parents in normal room light; tune stability only from observations. |
| Timer / completion | The timer is calm, but tab navigation competes with the task. | Hide or disable tabs during an active flow (P1 above). |
| Moment Voice | It is emotionally differentiated and optional, so it does not slow the start. | Test whether “Make our 5-second cheer” is discovered; consider a one-time post-capture hint, not a blocking tutorial. |
| Language | Product UI is currently English while the initial user context is Korean. | Pick launch locale(s) and localize all user-facing strings before App Store submission. |
| Accessibility | Text labels and system-sized targets are a good base. | Complete VoiceOver, Dynamic Type, contrast, and reduced-motion passes on physical hardware. |

## Image asset operating system

Use [`asset-manifest.json`](asset-manifest.json) as the machine-readable source of truth when regenerating artwork:

1. Find the named asset and its `source`, `canvas`, `targetDisplay`, `template`, and `prompt` fields.
2. Generate only the individual PNG; keep it transparent whenever `transparent: true`.
3. Preserve the canvas size and safe transparent padding for template icons. Do not bake a color into a template asset.
4. Replace the matching 1x/2x/3x image-set outputs, rebuild, and inspect Light/Dark plus the smallest target size.
5. Update the manifest status and source filename in the same change.

The current priority is **not** more decorative art. It is testing the existing compact hand mark and correctly scaled navigation assets on a physical phone. The only planned replacement is the old large `BrandWordmark`, which is now unnecessary in the capture flow.

## Sharing and virality — recommended sequence

### 1. Build a shareable Memory Card first (V1.1)

After a moment completes, offer a quiet optional `Share memory` action. It produces a local image card with:

- the parent-selected photo;
- a simple date or “Five more minutes” line;
- an optional, removable small “Made with Five More” mark;
- no child name, location, audio, or metadata by default.

Use the system share sheet (`ShareLink`). It works with Messages, AirDrop, and social apps while keeping Five More out of the business of hosting family photos. This is the most natural content loop because the object being shared is a memory, not an advert.

### 2. Measure genuine sharing before incentives

For the first parent test cohort, ask only: “Would you save or send this?” and “Did the shared card feel private enough?” A Memory Card that parents genuinely want to share is more valuable than an early referral counter. Do not put a share request in the timer or make it the default completion action.

### 3. Do not implement rewarded referral yet

The present local-only, account-free architecture cannot reliably determine that a friend installed via an invite, finished a first moment, and is a distinct person. Rewarding a generic external share is both easy to game and feels transactional in a family-memory product.

If testing shows a strong organic share loop, add a separate referral project with all of the following:

| Requirement | Reason |
| --- | --- |
| Backend-issued opaque invite token | prevents a user from minting their own rewards |
| Universal Link + deferred-install attribution | carries the invite through install into the app |
| One reward after invitee completes first saved Moment | rewards a meaningful in-app outcome, not a tap |
| conservative cap, e.g. +3 moments per verified invite, max +15 | limits abuse and avoids silently resetting the entire trial |
| rate limits, fraud review, and privacy policy update | protects the offer and explains new data handling |
| no child photo or voice sent in the referral payload | preserves the local-first promise |

The reward should be **extra free moments**, not a full trial reset. It is legible, bounded, and does not devalue the one-time purchase.

Apple’s review rules also prohibit forcing ratings, reviews, downloads, or other store-related actions to access functionality, and prohibit manipulative referrals. A voluntary Memory Card and a later, verifiable referral program are the safer shape. [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## Proposed order of work

1. **Now:** physical-iPhone regression pass for camera, open-palm capture, Dark Mode, Light Mode, audio, and tab artwork.
2. **Next build:** hide/disable the tab bar during Camera/Timer/Completion and refactor the phase into `CaptureFlowStore`.
3. **Before launch:** PRD sound-language cleanup, localization decision, storage-limit/device tests, and accessibility pass.
4. **After 10 parent tests:** prototype the local-only Memory Card; assess consent and organic sharing.
5. **Only if sharing proves real:** scope referral backend, attribution, fraud limits, and policy updates. Do not couple it to the initial paywall implementation.
