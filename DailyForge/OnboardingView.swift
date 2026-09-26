import SwiftUI
import SwiftData
import PhotosUI
import AppKit

// MARK: - Steps

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case howItWorks
    case nameAndAge
    case units
    case height
    case currentWeight
    case goalWeight
    case routine
    case photos
    case summary

    var progressIndex: Int { rawValue }
    static var total: Int { allCases.count }
}

// MARK: - Form Model

struct OnboardingForm {
    var displayName: String = ""
    var ageText: String = ""
    var unitSystem: UnitSystem = .metric
    var heightCm: Double = 175
    var currentWeightKg: Double = 75
    var goalWeightKg: Double = 70
    var minimumExercises: Int = Preferences.defaultMinimumExercises
    var restDays: Set<Int> = [5, 6]
    var frontPhoto: Data?
    var sidePhoto: Data?
}

// MARK: - Root

struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var step: OnboardingStep = .welcome
    @State private var form = OnboardingForm()
    @State private var errorMessage: String?

    @State private var finishParticles: [ConfettiParticle] = []
    @State private var finishStart: Date = Date()
    @State private var showFinishBurst: Bool = false

    var body: some View {
        ZStack {
            backgroundLayer
            contentColumn
            finishOverlay
        }
        .frame(minWidth: 640, minHeight: 740)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
    }

    // MARK: Background

    private var backgroundLayer: some View {
        ZStack {
            Theme.surfaceBase
            LinearGradient(
                colors: [accentTint.opacity(0.16), accentTint.opacity(0.00)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.45), value: step)
    }

    private var accentTint: Color {
        switch step {
        case .welcome:       return Color(hex: "#FF6B35")
        case .howItWorks:    return Color(hex: "#118AB2")
        case .nameAndAge:    return Color(hex: "#9B5DE5")
        case .units:         return Color(hex: "#06D6A0")
        case .height:        return Color(hex: "#FFD166")
        case .currentWeight: return Color(hex: "#EF476F")
        case .goalWeight:    return Color(hex: "#118AB2")
        case .routine:       return Color(hex: "#06D6A0")
        case .photos:        return Color(hex: "#9B5DE5")
        case .summary:       return Color(hex: "#FF6B35")
        }
    }

    // MARK: Content Column

    private var contentColumn: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                stepContent
                    .id(step)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            if let message = errorMessage {
                errorBanner(message)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var finishOverlay: some View {
        if showFinishBurst {
            ConfettiCanvas(particles: finishParticles, startDate: finishStart)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .zIndex(10)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                backButton
                Spacer()
                Text("Step \(step.progressIndex + 1) of \(OnboardingStep.total)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textTertiary)
                    .monospacedDigit()
                Spacer()
                Color.clear.frame(width: 32, height: 32)
            }
            progressBar
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var backButton: some View {
        if step != .welcome {
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(8)
                    .background(Circle().fill(Theme.surfaceElevated))
            }
            .buttonStyle(.plain)
            .transition(.opacity.combined(with: .scale))
        } else {
            Color.clear.frame(width: 32, height: 32)
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceSunken)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Theme.accentFill, accentTint],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progressFraction)
                    .animation(.spring(response: 0.55, dampingFraction: 0.85), value: step)
            }
        }
        .frame(height: 4)
    }

    private var progressFraction: CGFloat {
        CGFloat(step.progressIndex + 1) / CGFloat(OnboardingStep.total)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warning)
            Text(message).font(.callout)
            Spacer()
        }
        .padding(10)
        .background(Theme.warningSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Step Router

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            WelcomeStep(accent: accentTint, onNext: advance)
        case .howItWorks:
            HowItWorksStep(accent: accentTint, onNext: advance)
        case .nameAndAge:
            NameAgeStep(
                name: $form.displayName,
                ageText: $form.ageText,
                accent: accentTint,
                onNext: nameAgeNext
            )
        case .units:
            UnitsStep(
                unitSystem: $form.unitSystem,
                accent: accentTint,
                onNext: advance,
                onUnitChanged: handleUnitChange
            )
        case .height:
            HeightStep(
                heightCm: $form.heightCm,
                unitSystem: form.unitSystem,
                accent: accentTint,
                onNext: advance
            )
        case .currentWeight:
            WeightStep(
                title: "What do you weigh today?",
                subtitle: "We'll use this as your starting line.",
                weightKg: $form.currentWeightKg,
                unitSystem: form.unitSystem,
                accent: accentTint,
                iconName: "figure.stand",
                confirmLabel: "Next",
                onNext: advance
            )
        case .goalWeight:
            GoalWeightStep(
                currentWeightKg: form.currentWeightKg,
                goalWeightKg: $form.goalWeightKg,
                unitSystem: form.unitSystem,
                accent: accentTint,
                onNext: advance
            )
        case .routine:
            RoutineStep(
                minimumExercises: $form.minimumExercises,
                restDays: $form.restDays,
                accent: accentTint,
                onNext: advance
            )
        case .photos:
            PhotosStep(
                frontData: $form.frontPhoto,
                sideData: $form.sidePhoto,
                accent: accentTint,
                onNext: advance
            )
        case .summary:
            SummaryStep(
                form: form,
                accent: accentTint,
                onBegin: finish
            )
        }
    }

    // MARK: Navigation

    private func advance() {
        errorMessage = nil
        let all = OnboardingStep.allCases
        guard let idx = all.firstIndex(of: step) else { return }
        let next = idx + 1
        guard next < all.count else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            step = all[next]
        }
    }

    private func goBack() {
        errorMessage = nil
        let all = OnboardingStep.allCases
        guard let idx = all.firstIndex(of: step) else { return }
        let prev = idx - 1
        guard prev >= 0 else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            step = all[prev]
        }
    }

    private func nameAgeNext() {
        guard validateNameAge() else { return }
        advance()
    }

    // MARK: Validation

    private func validateNameAge() -> Bool {
        let trimmed = form.displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter your name."
            return false
        }
        let rawAge = form.ageText.trimmingCharacters(in: .whitespaces)
        guard let age = Int(rawAge), age >= 10, age <= 120 else {
            errorMessage = "Please enter an age between 10 and 120."
            return false
        }
        return true
    }

    private func handleUnitChange(from old: UnitSystem, to new: UnitSystem) {
        let heightLo = UnitConversion.heightRangeCm.lowerBound
        let heightHi = UnitConversion.heightRangeCm.upperBound
        form.heightCm = min(max(form.heightCm, heightLo), heightHi)

        let weightLo = UnitConversion.weightRangeKg.lowerBound
        let weightHi = UnitConversion.weightRangeKg.upperBound
        form.currentWeightKg = min(max(form.currentWeightKg, weightLo), weightHi)
        form.goalWeightKg = min(max(form.goalWeightKg, weightLo), weightHi)
    }

    // MARK: Finish

    private func finish() {
        guard validateFinal() else { return }

        UserDefaults.standard.unitSystem = form.unitSystem
        UserDefaults.standard.set(form.minimumExercises, forKey: PreferenceKeys.minimumExercises)
        UserDefaults.standard.set(
            DayLogic.restDaysRaw(from: form.restDays),
            forKey: PreferenceKeys.restDaysRaw
        )

        spawnFinishConfetti()
        NSSound(named: "Glass")?.play()

        persistProfile()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            showFinishBurst = false
        }
    }

    private func validateFinal() -> Bool {
        let trimmed = form.displayName.trimmingCharacters(in: .whitespaces)
        let age = Int(form.ageText.trimmingCharacters(in: .whitespaces)) ?? 0

        guard !trimmed.isEmpty, age > 0 else {
            errorMessage = "Something's missing. Please go back and check your details."
            return false
        }
        guard UnitConversion.weightRangeKg.contains(form.currentWeightKg),
              UnitConversion.weightRangeKg.contains(form.goalWeightKg) else {
            errorMessage = "Weight is out of range."
            return false
        }
        guard UnitConversion.heightRangeCm.contains(form.heightCm) else {
            errorMessage = "Height is out of range."
            return false
        }
        return true
    }

    private func spawnFinishConfetti() {
        let center: [ConfettiParticle] = ConfettiEmitter.burst(
            from: CGPoint(x: 0.5, y: 0.55),
            count: 140,
            speed: 0.45...1.2,
            lifetime: 2.6...4.0,
            palette: ConfettiPalette.celebration,
            sizeRange: 9...18
        )
        let left: [ConfettiParticle] = ConfettiEmitter.burst(
            from: CGPoint(x: 0.15, y: 0.25),
            count: 40,
            palette: ConfettiPalette.celebration,
            spread: 70,
            baseAngle: 55,
            sizeRange: 8...14
        )
        let right: [ConfettiParticle] = ConfettiEmitter.burst(
            from: CGPoint(x: 0.85, y: 0.25),
            count: 40,
            palette: ConfettiPalette.celebration,
            spread: 70,
            baseAngle: 125,
            sizeRange: 8...14
        )
        let combined: [ConfettiParticle] = center + left + right

        finishParticles = combined
        finishStart = Date()
        showFinishBurst = true
    }

    private func persistProfile() {
        let trimmed = form.displayName.trimmingCharacters(in: .whitespaces)
        let age = Int(form.ageText.trimmingCharacters(in: .whitespaces)) ?? 0

        let profile = UserProfile(
            displayName: trimmed,
            age: age,
            initialWeightKg: form.currentWeightKg,
            goalWeightKg: form.goalWeightKg,
            initialHeightCm: form.heightCm
        )
        profile.initialFrontPhoto = form.frontPhoto
        profile.initialSidePhoto = form.sidePhoto
        context.insert(profile)
        try? context.save()
    }
}

// MARK: - Shared Shell

private struct StepShell<Content: View>: View {
    let iconName: String
    let iconTint: Color
    let title: String
    let subtitle: String
    let primaryLabel: String
    let secondaryLabel: String?
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?
    let content: Content

    init(
        iconName: String,
        iconTint: Color,
        title: String,
        subtitle: String,
        primaryLabel: String = "Continue",
        secondaryLabel: String? = nil,
        onPrimary: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.iconName = iconName
        self.iconTint = iconTint
        self.title = title
        self.subtitle = subtitle
        self.primaryLabel = primaryLabel
        self.secondaryLabel = secondaryLabel
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
        self.content = content()
    }

    @State private var iconScale: CGFloat = 0.4
    @State private var iconRotation: Double = -14
    @State private var glowPulse: CGFloat = 1.0
    @State private var titleOffset: CGFloat = 18
    @State private var titleOpacity: Double = 0
    @State private var contentOffset: CGFloat = 26
    @State private var contentOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 22
    @State private var buttonOpacity: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                iconBlock
                titleBlock
                content
                    .offset(y: contentOffset)
                    .opacity(contentOpacity)
                actionsRow
                    .offset(y: buttonOffset)
                    .opacity(buttonOpacity)
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear(perform: animateEntrance)
    }

    private var iconBlock: some View {
        ZStack {
            Circle()
                .fill(iconTint.opacity(0.18))
                .frame(width: 130, height: 130)
                .blur(radius: 22)
                .scaleEffect(glowPulse)

            Circle()
                .fill(Theme.surfaceElevated)
                .frame(width: 108, height: 108)
                .overlay(Circle().stroke(Theme.border, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)

            Image(systemName: iconName)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [iconTint, iconTint.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(iconScale)
                .rotationEffect(.degrees(iconRotation))
        }
        .padding(.top, 4)
    }

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
            Text(subtitle)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
        .offset(y: titleOffset)
        .opacity(titleOpacity)
    }

    private var actionsRow: some View {
        HStack(spacing: 12) {
            if let label = secondaryLabel, let action = onSecondary {
                Button(label) { action() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            Button {
                onPrimary()
            } label: {
                Text(primaryLabel)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.top, 4)
    }

    private func animateEntrance() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.05)) {
            iconScale = 1.0
            iconRotation = 0
        }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            glowPulse = 1.15
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.15)) {
            titleOffset = 0
            titleOpacity = 1
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.25)) {
            contentOffset = 0
            contentOpacity = 1
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.35)) {
            buttonOffset = 0
            buttonOpacity = 1
        }
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    let accent: Color
    let onNext: () -> Void

    @State private var logoScale: CGFloat = 0.3
    @State private var logoRotation: Double = -12
    @State private var ring1Scale: CGFloat = 0.4
    @State private var ring1Opacity: Double = 0.9
    @State private var ring2Scale: CGFloat = 0.4
    @State private var ring2Opacity: Double = 0.7
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var subtitleOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 24
    @State private var buttonOpacity: Double = 0
    @State private var glowPulse: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            logoBlock
            textBlock
            Spacer()
            getStartedButton
        }
        .onAppear(perform: animate)
    }

    private var logoBlock: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(ring1Opacity), lineWidth: 3)
                .frame(width: 160, height: 160)
                .scaleEffect(ring1Scale)

            Circle()
                .stroke(accent.opacity(ring2Opacity), lineWidth: 2)
                .frame(width: 160, height: 160)
                .scaleEffect(ring2Scale)

            Circle()
                .fill(accent.opacity(0.35))
                .frame(width: 180, height: 180)
                .blur(radius: 40)
                .scaleEffect(glowPulse)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 130, height: 130)
                    .shadow(color: accent.opacity(0.55), radius: 26, y: 8)

                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(logoScale)
            .rotationEffect(.degrees(logoRotation))
        }
    }

    private var textBlock: some View {
        VStack(spacing: 12) {
            Text("DailyForge")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.65)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .opacity(titleOpacity)
                .offset(y: titleOffset)

            Text("Forge a body that can't be argued with.\nOne daily commitment, one unbreakable streak.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .opacity(subtitleOpacity)
        }
    }

    private var getStartedButton: some View {
        Button {
            onNext()
        } label: {
            HStack(spacing: 8) {
                Text("Get Started")
                    .font(.body.weight(.semibold))
                Image(systemName: "arrow.right")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
        .offset(y: buttonOffset)
        .opacity(buttonOpacity)
    }

    private func animate() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.55).delay(0.1)) {
            logoScale = 1.0
            logoRotation = 0
        }
        withAnimation(.easeOut(duration: 1.4).delay(0.1)) {
            ring1Scale = 2.4
            ring1Opacity = 0
        }
        withAnimation(.easeOut(duration: 1.8).delay(0.3)) {
            ring2Scale = 3.1
            ring2Opacity = 0
        }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            glowPulse = 1.16
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
            titleOpacity = 1
            titleOffset = 0
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.55)) {
            subtitleOpacity = 1
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.75)) {
            buttonOffset = 0
            buttonOpacity = 1
        }
    }
}

// MARK: - Step 2: How It Works

private struct HowItWorksCard: Identifiable {
    let id: Int
    let icon: String
    let tint: Color
    let title: String
    let body: String
}

private struct HowItWorksStep: View {
    let accent: Color
    let onNext: () -> Void

    private static let cards: [HowItWorksCard] = [
        HowItWorksCard(
            id: 0,
            icon: "figure.strengthtraining.traditional",
            tint: Color(hex: "#FF6B35"),
            title: "Build your routine",
            body: "Pick the exercises you want to hit daily — from a built-in catalog or your own. You set the minimum."
        ),
        HowItWorksCard(
            id: 1,
            icon: "checkmark.seal.fill",
            tint: Color(hex: "#06D6A0"),
            title: "Complete every one",
            body: "Each exercise gets a full-screen session timer. Finish them all before the day is done."
        ),
        HowItWorksCard(
            id: 2,
            icon: "mic.fill",
            tint: Color(hex: "#9B5DE5"),
            title: "Swear by voice",
            body: "Read your oath out loud. Speech recognition locks in the day — no sneaking."
        ),
        HowItWorksCard(
            id: 3,
            icon: "moon.zzz.fill",
            tint: Color(hex: "#118AB2"),
            title: "Rest when you need",
            body: "Choose up to three rest days a week. Your streak pauses without breaking."
        )
    ]

    @State private var headerOpacity: Double = 0
    @State private var headerOffset: CGFloat = 16
    @State private var cardOffsets: [CGFloat] = Array(repeating: 30, count: 4)
    @State private var cardOpacities: [Double] = Array(repeating: 0, count: 4)
    @State private var buttonOpacity: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                cardsColumn
                continueButton
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear(perform: animate)
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 100, height: 100)
                    .blur(radius: 18)
                Circle()
                    .fill(Theme.surfaceElevated)
                    .frame(width: 84, height: 84)
                    .overlay(Circle().stroke(Theme.border, lineWidth: 0.5))
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .padding(.top, 8)

            Text("How DailyForge works")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text("Four moving pieces. Together they keep you honest.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .opacity(headerOpacity)
        .offset(y: headerOffset)
    }

    private var cardsColumn: some View {
        VStack(spacing: 12) {
            ForEach(Self.cards) { card in
                cardView(card)
                    .opacity(cardOpacities[card.id])
                    .offset(y: cardOffsets[card.id])
            }
        }
    }

    private func cardView(_ card: HowItWorksCard) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(card.tint.opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: card.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(card.tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(card.body)
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.border, lineWidth: 0.5)
        )
    }

    private var continueButton: some View {
        Button {
            onNext()
        } label: {
            Text("Sounds good")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
        .padding(.top, 6)
        .opacity(buttonOpacity)
    }

    private func animate() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.05)) {
            headerOpacity = 1
            headerOffset = 0
        }
        for i in 0..<Self.cards.count {
            let delay = 0.20 + Double(i) * 0.10
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(delay)) {
                cardOffsets[i] = 0
                cardOpacities[i] = 1
            }
        }
        let buttonDelay = 0.20 + Double(Self.cards.count) * 0.10 + 0.05
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(buttonDelay)) {
            buttonOpacity = 1
        }
    }
}

// MARK: - Step 3: Name + Age

private struct NameAgeStep: View {
    @Binding var name: String
    @Binding var ageText: String
    let accent: Color
    let onNext: () -> Void

    @FocusState private var focusedField: Field?
    enum Field { case name, age }

    var body: some View {
        StepShell(
            iconName: "person.fill",
            iconTint: accent,
            title: "Who are we forging?",
            subtitle: "Your name and age help us personalize milestones.",
            primaryLabel: "Continue",
            onPrimary: onNext
        ) {
            VStack(spacing: 14) {
                fieldShell(label: "Your name", icon: "person.text.rectangle") {
                    TextField("e.g. Alex", text: $name)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .focused($focusedField, equals: .name)
                        .onSubmit { focusedField = .age }
                }
                fieldShell(label: "Your age", icon: "calendar") {
                    TextField("e.g. 28", text: $ageText)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .focused($focusedField, equals: .age)
                        .onSubmit(onNext)
                }
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.caption2)
                    Text("Stays on your Mac. Never leaves.").font(.caption)
                }
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
            .padding(.top, 4)
        }
        .onAppear {
            guard name.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .name
            }
        }
    }

    private func fieldShell<Content: View>(
        label: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Theme.border, lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Step 4: Units

private struct UnitsStep: View {
    @Binding var unitSystem: UnitSystem
    let accent: Color
    let onNext: () -> Void
    let onUnitChanged: (UnitSystem, UnitSystem) -> Void

    var body: some View {
        StepShell(
            iconName: "ruler",
            iconTint: accent,
            title: "Pick your units",
            subtitle: "Choose how heights and weights are displayed. You can switch any time.",
            primaryLabel: "Continue",
            onPrimary: onNext
        ) {
            HStack(spacing: 14) {
                optionCard(system: .metric, title: "Metric", example: "kg · cm", icon: "globe.europe.africa.fill")
                optionCard(system: .imperial, title: "Imperial", example: "lb · ft/in", icon: "flag.fill")
            }
            .padding(.top, 4)
        }
    }

    private func optionCard(system: UnitSystem, title: String, example: String, icon: String) -> some View {
        let selected: Bool = unitSystem == system
        return Button {
            select(system)
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(selected ? accent : Theme.surfaceSunken)
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(selected ? Color.white : Theme.textSecondary)
                }
                VStack(spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(Theme.textPrimary)
                    Text(example).font(.caption.monospaced()).foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(selected ? accent : Theme.border, lineWidth: selected ? 2 : 0.5)
            )
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(accent)
                        .padding(10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(selected ? 1.0 : 0.94)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: unitSystem)
    }

    private func select(_ system: UnitSystem) {
        let old = unitSystem
        guard old != system else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            unitSystem = system
        }
        onUnitChanged(old, system)
    }
}

// MARK: - Step 5: Height

private struct HeightStep: View {
    @Binding var heightCm: Double
    let unitSystem: UnitSystem
    let accent: Color
    let onNext: () -> Void

    private var range: ClosedRange<Double> { UnitConversion.heightRangeCm }

    private var displayValue: Double {
        unitSystem == .metric ? heightCm : heightCm / UnitConversion.cmPerInch
    }
    private var displayLower: Double {
        unitSystem == .metric ? range.lowerBound : range.lowerBound / UnitConversion.cmPerInch
    }
    private var displayUpper: Double {
        unitSystem == .metric ? range.upperBound : range.upperBound / UnitConversion.cmPerInch
    }
    private var sliderStep: Double { unitSystem == .metric ? 1.0 : 0.5 }

    private var sliderBinding: Binding<Double> {
        Binding(get: { displayValue }, set: { setFromDisplay($0) })
    }

    private var bigLabel: String {
        switch unitSystem {
        case .metric: return "\(Int(heightCm.rounded()))"
        case .imperial:
            let (ft, inches) = UnitConversion.cmToFeetInches(heightCm)
            return "\(ft)'\(Int(inches.rounded()))\""
        }
    }

    private var smallLabel: String {
        unitSystem == .metric ? "cm" : "ft · in"
    }

    private var quickHeightsCm: [Double] {
        unitSystem == .metric
            ? [150.0, 160.0, 170.0, 180.0, 190.0]
            : [152.4, 165.1, 172.7, 180.3, 190.5]
    }

    var body: some View {
        StepShell(
            iconName: "ruler.fill",
            iconTint: accent,
            title: "How tall are you?",
            subtitle: "We'll use this to track how your body composition changes over time.",
            primaryLabel: "Continue",
            onPrimary: onNext
        ) {
            VStack(spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(bigLabel)
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: heightCm)
                    Text(smallLabel)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 4)

                Slider(value: sliderBinding, in: displayLower...displayUpper, step: sliderStep)
                    .tint(accent)

                HStack(spacing: 6) {
                    ForEach(quickHeightsCm, id: \.self) { cm in
                        quickChip(cm)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private func quickChip(_ cm: Double) -> some View {
        let selected = abs(heightCm - cm) < 0.6
        let label: String
        switch unitSystem {
        case .metric: label = "\(Int(cm))"
        case .imperial:
            let (ft, inches) = UnitConversion.cmToFeetInches(cm)
            label = "\(ft)'\(Int(inches.rounded()))\""
        }
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                heightCm = cm
            }
        } label: {
            Text(label)
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? accent : Theme.surfaceSunken)
                .foregroundStyle(selected ? Color.white : Theme.textPrimary)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(selected ? Color.clear : Theme.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func setFromDisplay(_ newValue: Double) {
        let cm: Double = unitSystem == .metric
            ? newValue
            : newValue * UnitConversion.cmPerInch
        heightCm = min(max(cm, range.lowerBound), range.upperBound)
    }
}

// MARK: - Steps 6: Weight

private struct WeightStep: View {
    let title: String
    let subtitle: String
    @Binding var weightKg: Double
    let unitSystem: UnitSystem
    let accent: Color
    let iconName: String
    let confirmLabel: String
    let onNext: () -> Void

    private var range: ClosedRange<Double> { UnitConversion.weightRangeKg }

    private var displayValue: Double {
        UnitConversion.kgToDisplay(weightKg, unit: unitSystem)
    }
    private var displayLower: Double {
        UnitConversion.kgToDisplay(range.lowerBound, unit: unitSystem)
    }
    private var displayUpper: Double {
        UnitConversion.kgToDisplay(range.upperBound, unit: unitSystem)
    }
    private var sliderStep: Double { unitSystem == .metric ? 0.5 : 1.0 }

    private var sliderBinding: Binding<Double> {
        Binding(get: { displayValue }, set: { setFromDisplay($0) })
    }

    private var bigLabel: String { String(format: "%.1f", displayValue) }
    private var smallLabel: String { unitSystem == .metric ? "kg" : "lb" }

    private var quickWeightsKg: [Double] {
        if unitSystem == .metric {
            return [55.0, 65.0, 75.0, 85.0, 95.0]
        } else {
            let pounds: [Double] = [121.0, 143.0, 165.0, 187.0, 209.0]
            return pounds.map { $0 / UnitConversion.lbPerKg }
        }
    }

    var body: some View {
        StepShell(
            iconName: iconName,
            iconTint: accent,
            title: title,
            subtitle: subtitle,
            primaryLabel: confirmLabel,
            onPrimary: onNext
        ) {
            VStack(spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(bigLabel)
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: weightKg)
                    Text(smallLabel)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 4)

                Slider(value: sliderBinding, in: displayLower...displayUpper, step: sliderStep)
                    .tint(accent)

                HStack(spacing: 6) {
                    ForEach(quickWeightsKg, id: \.self) { kg in
                        quickChip(kg)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private func quickChip(_ kg: Double) -> some View {
        let selected = abs(weightKg - kg) < 0.6
        let display = UnitConversion.kgToDisplay(kg, unit: unitSystem)
        let label = String(format: "%.0f", display)
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                weightKg = kg
            }
        } label: {
            Text(label)
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? accent : Theme.surfaceSunken)
                .foregroundStyle(selected ? Color.white : Theme.textPrimary)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(selected ? Color.clear : Theme.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func setFromDisplay(_ newValue: Double) {
        let kg = UnitConversion.displayToKg(newValue, unit: unitSystem)
        weightKg = min(max(kg, range.lowerBound), range.upperBound)
    }
}

// MARK: - Step 7: Goal Weight

private struct GoalWeightStep: View {
    let currentWeightKg: Double
    @Binding var goalWeightKg: Double
    let unitSystem: UnitSystem
    let accent: Color
    let onNext: () -> Void

    private var range: ClosedRange<Double> { UnitConversion.weightRangeKg }

    private var displayValue: Double {
        UnitConversion.kgToDisplay(goalWeightKg, unit: unitSystem)
    }
    private var displayLower: Double {
        UnitConversion.kgToDisplay(range.lowerBound, unit: unitSystem)
    }
    private var displayUpper: Double {
        UnitConversion.kgToDisplay(range.upperBound, unit: unitSystem)
    }
    private var sliderStep: Double { unitSystem == .metric ? 0.5 : 1.0 }

    private var sliderBinding: Binding<Double> {
        Binding(get: { displayValue }, set: { setFromDisplay($0) })
    }

    private var bigLabel: String { String(format: "%.1f", displayValue) }
    private var smallLabel: String { unitSystem == .metric ? "kg" : "lb" }

    private var deltaKg: Double { goalWeightKg - currentWeightKg }

    private var deltaLabel: String {
        let absKg = abs(deltaKg)
        if absKg < 0.25 { return "Maintain" }
        let display = UnitConversion.kgToDisplay(absKg, unit: unitSystem)
        let unit = unitSystem == .metric ? "kg" : "lb"
        let direction = deltaKg < 0 ? "to lose" : "to gain"
        return String(format: "%.1f %@ %@", display, unit, direction)
    }

    private var deltaTint: Color {
        if abs(deltaKg) < 0.25 { return Theme.textSecondary }
        return deltaKg < 0 ? Theme.success : Theme.warning
    }

    private var deltaIcon: String {
        if abs(deltaKg) < 0.25 { return "equal.circle.fill" }
        return deltaKg < 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
    }

    var body: some View {
        StepShell(
            iconName: "target",
            iconTint: accent,
            title: "Where are you headed?",
            subtitle: "Set a goal weight. It powers your milestone reflections.",
            primaryLabel: "Continue",
            onPrimary: onNext
        ) {
            VStack(spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(bigLabel)
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: goalWeightKg)
                    Text(smallLabel)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 4)

                Slider(value: sliderBinding, in: displayLower...displayUpper, step: sliderStep)
                    .tint(accent)

                HStack(spacing: 8) {
                    Image(systemName: deltaIcon)
                        .foregroundStyle(deltaTint)
                    Text(deltaLabel)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(deltaTint)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: deltaKg)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(deltaTint.opacity(0.14)))
                .padding(.top, 4)
            }
            .padding(.top, 4)
        }
    }

    private func setFromDisplay(_ newValue: Double) {
        let kg = UnitConversion.displayToKg(newValue, unit: unitSystem)
        goalWeightKg = min(max(kg, range.lowerBound), range.upperBound)
    }
}

// MARK: - Step 8: Routine (NEW)

private struct RoutineStep: View {
    @Binding var minimumExercises: Int
    @Binding var restDays: Set<Int>
    let accent: Color
    let onNext: () -> Void

    private var atMaxRestDays: Bool { restDays.count >= Preferences.maxRestDays }

    var body: some View {
        StepShell(
            iconName: "calendar.badge.clock",
            iconTint: accent,
            title: "Your weekly routine",
            subtitle: "Decide how many exercises make a day, and when you'll rest.",
            primaryLabel: "Continue",
            onPrimary: onNext
        ) {
            VStack(spacing: 16) {
                minimumCard
                restDaysCard
            }
            .padding(.top, 4)
        }
    }

    private var minimumCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.number")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                Text("Minimum per day")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
            }

            HStack {
                Text("\(minimumExercises)")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: minimumExercises)
                    .frame(minWidth: 60, alignment: .leading)

                Spacer()

                Stepper("", value: $minimumExercises, in: Preferences.minimumExercisesRange)
                    .labelsHidden()
            }

            Text("You'll need at least \(minimumExercises) exercise\(minimumExercises == 1 ? "" : "s") set up before the day can be completed.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.border, lineWidth: 0.5)
        )
    }

    private var restDaysCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "moon.zzz.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                Text("Rest days")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
                Text("\(restDays.count) of \(Preferences.maxRestDays)")
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(atMaxRestDays ? accent : Theme.textSecondary)
            }

            WeekdayChipRow(
                selection: restDays,
                max: Preferences.maxRestDays,
                accent: accent
            ) { next in
                restDays = next
            }

            Text("Choose up to \(Preferences.maxRestDays) rest days a week. Rest days don't break your streak — they pause it.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Step 9: Photos (was missing)

private struct PhotosStep: View {
    @Binding var frontData: Data?
    @Binding var sideData: Data?
    let accent: Color
    let onNext: () -> Void

    @State private var frontItem: PhotosPickerItem?
    @State private var sideItem: PhotosPickerItem?

    var body: some View {
        StepShell(
            iconName: "camera.fill",
            iconTint: accent,
            title: "Baseline photos",
            subtitle: "Optional, but powerful. These show up at your 30-day milestone so you can see the change.",
            primaryLabel: "Continue",
            secondaryLabel: "Skip for now",
            onPrimary: onNext,
            onSecondary: onNext
        ) {
            HStack(spacing: 20) {
                photoPicker(label: "Front", item: $frontItem, data: $frontData)
                photoPicker(label: "Side", item: $sideItem, data: $sideData)
            }
            .padding(.top, 4)
        }
    }

    private func photoPicker(
        label: String,
        item: Binding<PhotosPickerItem?>,
        data: Binding<Data?>
    ) -> some View {
        VStack(spacing: 8) {
            PhotosPicker(selection: item, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.surfaceElevated)
                        .frame(width: 150, height: 200)
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Theme.border, lineWidth: 0.5)
                        .frame(width: 150, height: 200)

                    if let bytes = data.wrappedValue, let img = NSImage(data: bytes) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .transition(.opacity.combined(with: .scale))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 30))
                                .foregroundStyle(accent.opacity(0.7))
                            Text("Choose \(label.lowercased())")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                if data.wrappedValue != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.success)
                        .font(.caption)
                }
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .onChange(of: item.wrappedValue) { _, newValue in
            guard let newValue else { return }
            Task {
                let loaded = try? await newValue.loadTransferable(type: Data.self)
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        data.wrappedValue = loaded
                    }
                }
            }
        }
    }
}

// MARK: - Step 10: Summary (was missing)

private struct SummaryStep: View {
    let form: OnboardingForm
    let accent: Color
    let onBegin: () -> Void

    @State private var cardOffsets: [CGFloat] = Array(repeating: 24, count: 6)
    @State private var cardOpacities: [Double] = Array(repeating: 0, count: 6)
    @State private var buttonOpacity: Double = 0

    private var unit: UnitSystem { form.unitSystem }

    private var heightLabel: String {
        switch unit {
        case .metric: return "\(Int(form.heightCm.rounded())) cm"
        case .imperial:
            let (ft, inches) = UnitConversion.cmToFeetInches(form.heightCm)
            return "\(ft)'\(Int(inches.rounded()))\""
        }
    }

    private var currentLabel: String {
        let value = UnitConversion.kgToDisplay(form.currentWeightKg, unit: unit)
        return String(format: "%.1f %@", value, unit.weightUnitLabel)
    }

    private var goalLabel: String {
        let value = UnitConversion.kgToDisplay(form.goalWeightKg, unit: unit)
        return String(format: "%.1f %@", value, unit.weightUnitLabel)
    }

    private var ageLabel: String {
        let age = Int(form.ageText.trimmingCharacters(in: .whitespaces)) ?? 0
        return age > 0 ? "\(age)" : "—"
    }

    private var restDaysLabel: String {
        WeekdayNames.joined(weekdays: form.restDays)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                summaryList
                nextHint
                beginButton
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear(perform: animate)
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.20))
                    .frame(width: 110, height: 110)
                    .blur(radius: 20)
                Circle()
                    .fill(Theme.surfaceElevated)
                    .frame(width: 90, height: 90)
                    .overlay(Circle().stroke(Theme.border, lineWidth: 0.5))
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .padding(.top, 8)

            Text("You're all set")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Here's what we've got. Tap Begin and start forging.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var summaryList: some View {
        VStack(spacing: 10) {
            summaryRow(index: 0, icon: "person.fill", label: "Name", value: form.displayName)
            summaryRow(index: 1, icon: "calendar", label: "Age", value: ageLabel)
            summaryRow(index: 2, icon: "ruler", label: "Height", value: heightLabel)
            summaryRow(index: 3, icon: "scalemass", label: "Current", value: currentLabel)
            summaryRow(index: 4, icon: "target", label: "Goal", value: goalLabel)
            summaryRow(index: 5, icon: "moon.zzz.fill", label: "Rest days", value: restDaysLabel)
        }
    }

    private var nextHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .foregroundStyle(Theme.accentFill)
            Text("Next up: pick your \(form.minimumExercises)+ exercises. The app will guide you.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.accentSoft)
        )
    }

    private var beginButton: some View {
        Button {
            onBegin()
        } label: {
            HStack(spacing: 8) {
                Text("Begin")
                    .font(.body.weight(.semibold))
                Image(systemName: "arrow.right")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
        .padding(.top, 4)
        .opacity(buttonOpacity)
    }

    private func summaryRow(index: Int, icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.16))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
            }
            Text(label)
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.border, lineWidth: 0.5)
        )
        .offset(y: cardOffsets[index])
        .opacity(cardOpacities[index])
    }

    private func animate() {
        for i in 0..<cardOffsets.count {
            let delay = 0.05 + Double(i) * 0.07
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) {
                cardOffsets[i] = 0
                cardOpacities[i] = 1
            }
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.55)) {
            buttonOpacity = 1
        }
    }
}
