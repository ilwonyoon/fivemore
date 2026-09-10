import SwiftData
import SwiftUI
import UIKit

struct CaptureFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var purchaseService: PurchaseService
    @Query(sort: \Moment.capturedAt, order: .reverse) private var moments: [Moment]

    @StateObject private var cameraService = CameraService()
    @StateObject private var trialStore = TrialUsageStore()

    @State private var phase: CapturePhase = .home
    @State private var capturedImage: UIImage?
    @State private var activeMomentID: UUID?
    @State private var endsAt: Date?
    @State private var now = Date.now
    @State private var isCapturing = false
    @State private var flashOpacity: Double = 0
    @State private var shutterTick = 0
    @State private var fingerTick = 0
    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var errorMessage: String?

    private var launchRequest: LaunchRequest { .shared }

    /// Minutes for the moment currently being started or running.
    @State private var activeMinutes = 5

    private var timerDuration: TimeInterval {
        TimeInterval(activeMinutes * 60)
    }

    private var remainingSeconds: Int {
        guard let endsAt else { return 0 }
        return Countdown.remainingSeconds(until: endsAt, now: now)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                GeometryReader { proxy in
                    // Measured from the reference images: 16pt side margin and a
                    // portrait frame at a 0.915 ratio, identical in every phase.
                    let fullWidth = max(1, min(proxy.size.width - Spacing.margin * 2, 390))
                    let frameHeight = min(fullWidth / 0.915, proxy.size.height * 0.52)
                    let frameWidth = frameHeight * 0.915

                    VStack(spacing: 0) {
                        header
                            .frame(width: fullWidth)

                        CrayonFrame {
                            frameContent
                                .frame(width: frameWidth, height: frameHeight)
                        }
                        .frame(width: frameWidth, height: frameHeight)

                        Spacer(minLength: Spacing.zone)

                        // The frame is the dominant object on every screen, so
                        // the controls line up with its edges rather than the
                        // screen's.
                        controls
                            .frame(width: max(frameWidth, fullWidth * 0.86))

                        Spacer(minLength: Spacing.zone)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.tight)
                }
            }
            .overlay {
                Color.white
                    .opacity(flashOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .sensoryFeedback(.impact(weight: .heavy), trigger: shutterTick)
        .sensoryFeedback(.selection, trigger: fingerTick)
        .onChange(of: cameraService.latestFingerCount) { _, newValue in
            // A tick each time the count the camera reads actually changes, so
            // holding up fingers feels like turning a dial.
            guard phase == .camera, !isCapturing, let fingers = newValue, fingers > 0 else {
                return
            }
            fingerTick = fingers
        }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView {
                showPaywall = false
                Task { await beginCamera() }
            }
            .environmentObject(purchaseService)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(trialStore: trialStore)
                .environmentObject(purchaseService)
        }
        .alert("Couldn’t continue", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
        .task {
            trialStore.reconcile(minimumUsedCount: min(TrialUsageStore.freeLimit, moments.count))
            await restoreActiveTimerIfNeeded()
            await handleLaunchRequestIfNeeded()
        }
        .onChange(of: launchRequest.token) { _, _ in
            Task { await handleLaunchRequestIfNeeded() }
        }
        .task(id: phase) {
            guard phase == .timer else { return }

            while !Task.isCancelled {
                let current = Date.now
                if now != current {
                    now = current
                }

                guard let endsAt else { return }
                if Countdown.remainingSeconds(until: endsAt, now: current) == 0 {
                    completeTimer(reason: .completed)
                    return
                }

                let nextBoundary = endsAt.timeIntervalSince(current).truncatingRemainder(dividingBy: 1)
                let delay = nextBoundary > 0.02 ? nextBoundary : 1
                try? await Task.sleep(for: .seconds(delay))
            }
        }
        .onChange(of: cameraService.stableFingerCount) { _, newValue in
            guard phase == .camera, !isCapturing, let fingers = newValue, fingers > 0 else {
                return
            }

#if targetEnvironment(simulator)
            if LaunchFlags.holdsCamera {
                activeMinutes = fingers
                return
            }
#endif

            activeMinutes = fingers
            Task { await captureAndStartTimer() }
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue != .active {
                CompletionAlertService.shared.stop()
            }

            if newValue == .active, phase == .timer {
                now = .now
                if remainingSeconds == 0 {
                    completeTimer(reason: .completed)
                }
            }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented { errorMessage = nil }
            }
        )
    }

    private var header: some View {
        ZStack {
            BrandWordmark()

            HStack {
                if phase == .camera {
                    Button {
                        cancelCamera()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close camera")
                }

                Spacer()

                if phase == .home {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .foregroundStyle(SRColor.charcoal)
        }
        .frame(height: 78)
    }

    @ViewBuilder
    private var frameContent: some View {
        switch phase {
        case .home:
            CrayonHeroView()
                .transition(.opacity)

        case .camera:
            CameraPreview(session: cameraService.session)
                .transition(.opacity)

        case .timer, .completion:
            if let capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel("The photo captured for this 5 More moment")
                    .transition(.opacity)
            } else {
                ZStack {
                    SRColor.paper
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 46))
                        Text("Your moment is saved in Photos")
                            .font(.callout)
                    }
                    .foregroundStyle(SRColor.muted)
                }
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .home:
            VStack(spacing: 9) {
                PrimaryCameraButton(isBusy: false) {
                    Task { await beginCamera() }
                }

                Text("Take a photo to start")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(SRColor.charcoal)

                if !purchaseService.isUnlocked {
                    Text(freeUsesText)
                        .font(.caption)
                        .foregroundStyle(SRColor.muted)
                        .accessibilityLabel("\(trialStore.remainingCount) free moments remaining")
                }
            }

        case .camera:
            VStack(spacing: 9) {
                PrimaryCameraButton(isBusy: isCapturing) {
                    activeMinutes = CaptureRules.minutes(
                        liveFingerCount: cameraService.latestFingerCount,
                        stableFingerCount: cameraService.stableFingerCount
                    )
                    Task { await captureAndStartTimer() }
                }

                Text(cameraGuidanceText)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(SRColor.charcoal)
            }

        case .timer:
            VStack(spacing: Spacing.margin) {
                HStack(spacing: Spacing.margin) {
                    TimerProgressRing(
                        remainingSeconds: remainingSeconds,
                        totalSeconds: Int(timerDuration),
                        diameter: 46,
                        lineWidth: 7
                    )

                    Text(Countdown.displayText(for: remainingSeconds))
                        .font(.system(size: 58, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(SRColor.charcoal)
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(remainingSeconds / 60) minutes and \(remainingSeconds % 60) seconds remaining")

                Button("End early") {
                    completeTimer(reason: .endedEarly)
                }
                .buttonStyle(.bordered)
                .tint(SRColor.muted)
            }

        case .completion:
            VStack(spacing: Spacing.tight) {
                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(SRColor.yellow)

                Text("Time’s up!")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(SRColor.charcoal)

                Text(completionSubtitle)
                    .font(.callout)
                    .foregroundStyle(SRColor.muted)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, Spacing.tight)

                // One row: repeat leads, Done sits beside it. Both buttons take
                // the same height so their labels share a baseline, and the
                // repeat button gets the wider share because it is the choice
                // the parent is most likely making.
                HStack(spacing: Spacing.tight) {
                    Button {
                        repeatMoment()
                    } label: {
                        Text("\(activeMinutes) more minutes")
                            .frame(maxWidth: .infinity, minHeight: completionButtonHeight)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SRColor.yellow)
                    .foregroundStyle(SRColor.charcoal)

                    Button {
                        returnHome()
                    } label: {
                        Text("Done")
                            .frame(minHeight: completionButtonHeight)
                            .padding(.horizontal, Spacing.margin)
                    }
                    .buttonStyle(.bordered)
                    .tint(SRColor.muted)
                }
                .font(.system(.body, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
    }

    /// Both completion buttons share this height so their labels line up.
    private var completionButtonHeight: CGFloat { 52 }

    private var completionSubtitle: String {
        guard let activeMomentID,
              let moment = moments.first(where: { $0.id == activeMomentID }),
              moment.rounds > 1 else {
            return "That’s five. Your moment is saved."
        }

        return "That’s \(moment.rounds) rounds. Your moment is saved."
    }

    /// Tells the parent what the camera is seeing, so the automatic shutter
    /// never feels like it fired on its own.
    private var cameraGuidanceText: String {
        if isCapturing {
            return "Saving your moment…"
        }

        if let pending = cameraService.latestFingerCount ?? cameraService.stableFingerCount {
            return "\(pending) more minutes…"
        }

        return "Hold up fingers, or tap for 5"
    }

    private var freeUsesText: String {
        if trialStore.remainingCount == 1 {
            "1 free moment left"
        } else {
            "\(trialStore.remainingCount) free moments left"
        }
    }

    private func beginCamera() async {
        if trialStore.remainingCount == 0, purchaseService.entitlement == .loading {
            await purchaseService.refreshEntitlement()
        }

        guard CaptureRules.canOpenCamera(
            freeUsesRemaining: trialStore.remainingCount,
            isUnlocked: purchaseService.isUnlocked
        ) else {
            showPaywall = true
            return
        }

        activeMinutes = CaptureRules.defaultMinutes

        withAnimation(.easeInOut(duration: 0.25)) {
            phase = .camera
        }

        let started = await cameraService.requestAccessAndStart()

#if targetEnvironment(simulator)
        if started, let fingers = LaunchFlags.simulatedFingerCount {
            cameraService.simulateFingerCount(fingers)
        }
#endif

        if !started {
            withAnimation { phase = .home }
            errorMessage = cameraErrorMessage
        }
    }

    private var cameraErrorMessage: String {
        switch cameraService.state {
        case .denied:
            CameraServiceError.permissionDenied.localizedDescription
        case .unavailable:
            CameraServiceError.unavailable.localizedDescription
        default:
            CameraServiceError.configurationFailed.localizedDescription
        }
    }

    /// Acts on a request from Siri, the Action Button or a Control Center
    /// control. Ignored while a timer is already running so an accidental
    /// second trigger cannot discard the moment in progress.
    private func handleLaunchRequestIfNeeded() async {
        guard let minutes = launchRequest.pendingMinutes else { return }
        launchRequest.clear()

        guard phase == .home else { return }

        await beginCamera()

        // A preset length only sticks if the camera actually opened.
        if phase == .camera, minutes > 0 {
            activeMinutes = minutes
        }
    }

    /// A brief white flash plus a heavy tap, so a capture that fires on its own
    /// still reads as "the photo was taken".
    private func showCaptureFlash() {
        shutterTick += 1

        guard !reduceMotion else { return }

        flashOpacity = 0.85
        withAnimation(.easeOut(duration: 0.32)) {
            flashOpacity = 0
        }
    }

    private func cancelCamera() {
        fingerTick = 0
        cameraService.stop()
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .home
        }
    }

    private func captureAndStartTimer() async {
        guard !isCapturing else { return }
        isCapturing = true

        do {
            // The only step the parent has to wait for. Everything after this
            // works from data already in memory, so the timer can start while
            // the photo is still being written to the library.
            let photoData = try await cameraService.capturePhoto()

            let startedAt = Date.now
            let timerEnd = startedAt.addingTimeInterval(timerDuration)

            capturedImage = UIImage(data: photoData)
            endsAt = timerEnd
            now = startedAt
            isCapturing = false
            cameraService.stop()
            showCaptureFlash()

            withAnimation(.easeInOut(duration: 0.3)) {
                phase = .timer
            }

            await finishSaving(photoData: photoData, startedAt: startedAt, endsAt: timerEnd)
        } catch {
            isCapturing = false
            errorMessage = error.localizedDescription
        }
    }

    /// Saves to Photos and records the moment after the timer is already
    /// running. A failure here rolls the flow back rather than leaving a timer
    /// with no saved photo.
    private func finishSaving(photoData: Data, startedAt: Date, endsAt timerEnd: Date) async {
        do {
            let localIdentifier = try await PhotoLibraryService.shared.savePhoto(data: photoData)

            let moment = Moment(
                photoLocalIdentifier: localIdentifier,
                capturedAt: startedAt,
                plannedDurationSeconds: Int(timerDuration)
            )

            modelContext.insert(moment)
            try modelContext.save()

            if CaptureRules.shouldConsumeFreeUse(isUnlocked: purchaseService.isUnlocked) {
                trialStore.consumeUse()
            }

            let record = ActiveTimerRecord(
                momentID: moment.id,
                photoLocalIdentifier: localIdentifier,
                startedAt: startedAt,
                endsAt: timerEnd
            )

            try? ActiveTimerMediaStore.shared.save(photoData)
            ActiveTimerStore.shared.save(record)
            activeMomentID = moment.id

            await LiveActivityService.start(startedAt: startedAt, endsAt: timerEnd, rounds: 1)
            await NotificationService.shared.requestPermissionAndSchedule(
                momentID: moment.id,
                endsAt: timerEnd
            )
        } catch {
            // PRD §6.2: a failed save must not consume a use or leave a timer
            // running for a moment that was never recorded.
            endsAt = nil
            capturedImage = nil
            withAnimation { phase = .home }
            errorMessage = error.localizedDescription
        }
    }

    private func restoreActiveTimerIfNeeded() async {
        guard phase == .home, let record = ActiveTimerStore.shared.load() else { return }

        capturedImage = ActiveTimerMediaStore.shared.loadImage()
        if capturedImage == nil {
            capturedImage = await PhotoLibraryService.shared.image(
                localIdentifier: record.photoLocalIdentifier,
                targetSize: CGSize(width: 1_200, height: 1_200)
            )
        }

        activeMomentID = record.momentID
        endsAt = record.endsAt
        now = .now

        activeMinutes = CaptureRules.restoredMinutes(from: record)

        if CaptureRules.restoredPhase(for: record, now: .now) == .timer {
            let restoredRounds = moments.first { $0.id == record.momentID }?.rounds ?? 1
            await LiveActivityService.start(
                startedAt: record.startedAt,
                endsAt: record.endsAt,
                rounds: restoredRounds
            )
        }

        if CaptureRules.restoredPhase(for: record, now: now) == .completion {
            completeTimer(reason: .completed)
        } else {
            phase = .timer
        }
    }

    private func completeTimer(reason: MomentEndReason) {
        guard phase == .timer || phase == .home else { return }

        if let activeMomentID,
           let moment = moments.first(where: { $0.id == activeMomentID }) {
            moment.endedAt = .now
            moment.endReason = reason
            try? modelContext.save()
        }

        if let activeMomentID {
            NotificationService.shared.cancel(momentID: activeMomentID)
        }
        ActiveTimerStore.shared.clear()
        Task { await LiveActivityService.stop() }
        // The cached photo is kept until the user leaves the completion screen,
        // so a repeat can restore it after a force quit.
        endsAt = nil
        now = .now

        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .completion
        }

        CompletionAlertService.shared.start()
    }

    /// Runs another round on the same moment: same photo, no new capture, and
    /// no free use consumed. The existing Moment is extended rather than a new
    /// one created, so Memories shows one entry for the whole afternoon.
    private func repeatMoment() {
        guard phase == .completion, let activeMomentID else { return }

        CompletionAlertService.shared.stop()

        let startedAt = Date.now
        let timerEnd = startedAt.addingTimeInterval(timerDuration)

        guard let moment = moments.first(where: { $0.id == activeMomentID }) else {
            returnHome()
            return
        }

        // PRD §5.4.2: a repeat extends the paid-for moment, so it must never
        // touch the trial counter.
        assert(!CaptureRules.shouldConsumeFreeUseOnRepeat())

        moment.rounds += 1
        moment.plannedDurationSeconds += Int(timerDuration)
        moment.endedAt = nil
        moment.endReason = nil
        try? modelContext.save()

        ActiveTimerStore.shared.save(
            ActiveTimerRecord(
                momentID: moment.id,
                photoLocalIdentifier: moment.photoLocalIdentifier,
                startedAt: startedAt,
                endsAt: timerEnd
            )
        )

        endsAt = timerEnd
        now = startedAt
        let repeatRounds = moment.rounds
        Task {
            await LiveActivityService.start(
                startedAt: startedAt,
                endsAt: timerEnd,
                rounds: repeatRounds
            )
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .timer
        }

        Task {
            await NotificationService.shared.requestPermissionAndSchedule(
                momentID: moment.id,
                endsAt: timerEnd
            )
        }
    }

    private func returnHome() {
        CompletionAlertService.shared.stop()
        ActiveTimerMediaStore.shared.clear()
        activeMomentID = nil
        capturedImage = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            phase = .home
        }
    }
}

#Preview {
    CaptureFlowView()
        .environmentObject(PurchaseService())
        .modelContainer(for: Moment.self, inMemory: true)
}
