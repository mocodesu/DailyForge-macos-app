import SwiftUI
import AppKit

// MARK: - Tier

enum CelebrationTier: Equatable {
    case standard
    case bronze
    case silver
    case gold
    case legendary

    static func forDays(_ days: Int) -> CelebrationTier {
        switch days {
        case 365...:      return .legendary
        case 180..<365:   return .gold
        case 90..<180:    return .silver
        case 30..<90:     return .bronze
        default:          return .standard
        }
    }

    var badgeTint: Color {
        switch self {
        case .standard:  return Color(hex: "#FF6B35")
        case .bronze:    return Color(hex: "#CD7F32")
        case .silver:    return Color(hex: "#C0C0C0")
        case .gold:      return Color(hex: "#FFD700")
        case .legendary: return Color(hex: "#9B5DE5")
        }
    }

    var cardGradient: [Color] {
        switch self {
        case .standard:
            return [Color(hex: "#FF6B35"), Color(hex: "#C2410C")]
        case .bronze:
            return [Color(hex: "#B87333"), Color(hex: "#5C3A21")]
        case .silver:
            return [Color(hex: "#A8A8A8"), Color(hex: "#3A3A3A")]
        case .gold:
            return [Color(hex: "#FFD700"), Color(hex: "#8B6508")]
        case .legendary:
            return [Color(hex: "#9B5DE5"), Color(hex: "#3A1E6B")]
        }
    }

    var numberGradient: [Color] {
        switch self {
        case .standard:  return [.white, Color.white.opacity(0.7)]
        case .bronze:    return [Color(hex: "#FFE0B0"), Color(hex: "#A96B38")]
        case .silver:    return [.white, Color(hex: "#A0A0A0")]
        case .gold:      return [Color(hex: "#FFF4B0"), Color(hex: "#C99B00")]
        case .legendary: return [Color(hex: "#E0BBFF"), Color(hex: "#7A3FD0")]
        }
    }

    var label: String {
        switch self {
        case .standard:  return "MILESTONE"
        case .bronze:    return "BRONZE"
        case .silver:    return "SILVER"
        case .gold:      return "GOLD"
        case .legendary: return "LEGENDARY"
        }
    }

    var subtitle: String {
        switch self {
        case .standard:  return "A meaningful milestone."
        case .bronze:    return "A month of discipline. You earned this."
        case .silver:    return "Three months. A quarter of a year forged."
        case .gold:      return "Six months. This is who you are now."
        case .legendary: return "One year. You are not the person who started."
        }
    }

    /// Overall celebration intensity multiplier — used to add extra
    /// confetti, extra burst waves, and longer duration per tier.
    var intensity: Int {
        switch self {
        case .standard:  return 1
        case .bronze:    return 2
        case .silver:    return 3
        case .gold:      return 4
        case .legendary: return 5
        }
    }

    var duration: Double {
        switch self {
        case .standard:  return 5.0
        case .bronze:    return 8.0
        case .silver:    return 9.5
        case .gold:      return 11.0
        case .legendary: return 14.0
        }
    }

    var primarySound: String {
        switch self {
        case .standard:  return "Hero"
        case .bronze:    return "Hero"
        case .silver:    return "Hero"
        case .gold:      return "Hero"
        case .legendary: return "Hero"
        }
    }
}

// MARK: - Kind

enum CelebrationKind: Equatable {
    case day
    case milestone(Int)

    var isGrand: Bool {
        if case .milestone = self { return true }
        return false
    }

    var tier: CelebrationTier {
        switch self {
        case .day: return .standard
        case .milestone(let days): return CelebrationTier.forDays(days)
        }
    }
}

// MARK: - Root

struct CelebrationView: View {
    let kind: CelebrationKind
    let streak: Int
    let onFinished: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var contentScale: CGFloat = 0.5
    @State private var contentOpacity: Double = 0

    @State private var burstParticles: [ConfettiParticle] = []
    @State private var rainParticles: [ConfettiParticle] = []
    @State private var extraParticles: [ConfettiParticle] = []
    @State private var confettiReady = false

    @State private var finished = false

    private var isGrand: Bool { kind.isGrand }
    private var tier: CelebrationTier { kind.tier }
    private var duration: Double { isGrand ? tier.duration : 4.2 }

    var body: some View {
        ZStack {
            backdrop
            confetti
            content
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .onAppear { start() }
    }

    // MARK: Backdrop

    @ViewBuilder
    private var backdrop: some View {
        Group {
            if isGrand {
                RadialGradient(
                    colors: backdropColors,
                    center: .center,
                    startRadius: 20,
                    endRadius: 900
                )
            } else {
                Color.black.opacity(0.55)
            }
        }
        .opacity(backdropOpacity)
        .ignoresSafeArea()
    }

    private var backdropColors: [Color] {
        switch tier {
        case .standard:  return [Color(hex: "#2A1400").opacity(0.94), Color.black.opacity(0.90)]
        case .bronze:    return [Color(hex: "#2A1400").opacity(0.94), Color.black.opacity(0.90)]
        case .silver:    return [Color(hex: "#1A1A1A").opacity(0.94), Color.black.opacity(0.92)]
        case .gold:      return [Color(hex: "#2A2000").opacity(0.94), Color.black.opacity(0.92)]
        case .legendary: return [Color(hex: "#200A3A").opacity(0.96), Color.black.opacity(0.94)]
        }
    }

    // MARK: Confetti

    @ViewBuilder
    private var confetti: some View {
        if confettiReady {
            ZStack {
                ConfettiCanvas(particles: burstParticles, startDate: Date())
                ConfettiCanvas(particles: rainParticles, startDate: Date())
                ConfettiCanvas(particles: extraParticles, startDate: Date())
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if isGrand, case .milestone(let days) = kind {
            GrandCelebrationContent(days: days, streak: streak, tier: tier)
                .scaleEffect(contentScale)
                .opacity(contentOpacity)
        } else {
            DayCelebrationContent(streak: streak)
                .scaleEffect(contentScale)
                .opacity(contentOpacity)
        }
    }

    // MARK: Lifecycle

    private func start() {
        buildConfetti()

        withAnimation(.easeInOut(duration: 0.35)) {
            backdropOpacity = 1
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.62).delay(0.1)) {
            contentScale = 1.0
            contentOpacity = 1.0
        }

        playSound()

        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            finish()
        }
    }

    private func buildConfetti() {
        if isGrand {
            buildGrandConfetti()
        } else {
            buildDayConfetti()
        }
        confettiReady = true
    }

    private func buildDayConfetti() {
        let centerBurst: [ConfettiParticle] = ConfettiEmitter.burst(
            from: CGPoint(x: 0.5, y: 0.5),
            count: 100,
            speed: 0.35...1.0,
            lifetime: 2.2...3.4,
            palette: ConfettiPalette.celebration,
            sizeRange: 8...16
        )
        let rain: [ConfettiParticle] = ConfettiEmitter.rain(
            count: 45,
            spreadOver: 1.8,
            baseDelay: 0.2,
            palette: ConfettiPalette.celebration
        )
        burstParticles = centerBurst
        rainParticles = rain
        extraParticles = []
    }

    private func buildGrandConfetti() {
        let palette = paletteForTier()
        let intensity = tier.intensity

        let centerBurst: [ConfettiParticle] = ConfettiEmitter.burst(
            from: CGPoint(x: 0.5, y: 0.5),
            count: 100 + intensity * 20,
            speed: 0.5...1.4,
            lifetime: 3.0...5.0,
            palette: palette,
            sizeRange: 10...20
        )
        let rain: [ConfettiParticle] = ConfettiEmitter.rain(
            count: 100 + intensity * 25,
            spreadOver: 3.5 + Double(intensity) * 0.5,
            baseDelay: 0.3,
            palette: palette
        )

        let secondWave: [ConfettiParticle] = ConfettiEmitter.burst(
            from: CGPoint(x: 0.5, y: 0.5),
            count: 70,
            speed: 0.3...0.75,
            lifetime: 2.8...4.2,
            palette: palette,
            baseDelay: 1.1,
            sizeRange: 6...12
        )
        let leftCannon: [ConfettiParticle] = ConfettiEmitter.burst(
            from: CGPoint(x: 0.10, y: 0.20),
            count: 45,
            palette: palette,
            spread: 80,
            baseAngle: 55,
            sizeRange: 8...14
        )
        let rightCannon: [ConfettiParticle] = ConfettiEmitter.burst(
            from: CGPoint(x: 0.90, y: 0.20),
            count: 45,
            palette: palette,
            spread: 80,
            baseAngle: 125,
            sizeRange: 8...14
        )

        var extras: [ConfettiParticle] = secondWave + leftCannon + rightCannon

        // Higher tiers get extra waves. Legendary gets five additional bursts.
        if intensity >= 3 {
            extras.append(contentsOf: ConfettiEmitter.burst(
                from: CGPoint(x: 0.5, y: 0.35),
                count: 60,
                speed: 0.4...1.0,
                lifetime: 3.0...4.5,
                palette: palette,
                baseDelay: 1.9,
                sizeRange: 8...16
            ))
        }
        if intensity >= 4 {
            extras.append(contentsOf: ConfettiEmitter.burst(
                from: CGPoint(x: 0.25, y: 0.55),
                count: 55,
                palette: palette,
                spread: 120,
                baseAngle: -30,
                baseDelay: 2.4,
                sizeRange: 9...17
            ))
            extras.append(contentsOf: ConfettiEmitter.burst(
                from: CGPoint(x: 0.75, y: 0.55),
                count: 55,
                palette: palette,
                spread: 120,
                baseAngle: 210,
                baseDelay: 2.4,
                sizeRange: 9...17
            ))
        }
        if intensity >= 5 {
            extras.append(contentsOf: ConfettiEmitter.burst(
                from: CGPoint(x: 0.5, y: 0.6),
                count: 90,
                speed: 0.6...1.4,
                lifetime: 3.5...5.5,
                palette: palette,
                baseDelay: 3.0,
                sizeRange: 10...20
            ))
            extras.append(contentsOf: ConfettiEmitter.burst(
                from: CGPoint(x: 0.15, y: 0.75),
                count: 40,
                palette: palette,
                spread: 100,
                baseAngle: -45,
                baseDelay: 3.6,
                sizeRange: 8...14
            ))
            extras.append(contentsOf: ConfettiEmitter.burst(
                from: CGPoint(x: 0.85, y: 0.75),
                count: 40,
                palette: palette,
                spread: 100,
                baseAngle: 225,
                baseDelay: 3.6,
                sizeRange: 8...14
            ))
        }

        burstParticles = centerBurst
        rainParticles = rain
        extraParticles = extras
    }

    private func paletteForTier() -> [Color] {
        switch tier {
        case .standard:  return ConfettiPalette.celebration
        case .bronze:    return [Color(hex: "#CD7F32"), Color(hex: "#B87333"), Color(hex: "#FF6B35"), Color(hex: "#FFD166"), Color(hex: "#8B5A2B")]
        case .silver:    return [Color(hex: "#C0C0C0"), Color(hex: "#E8E8E8"), Color(hex: "#A8A8A8"), Color(hex: "#FFFFFF"), Color(hex: "#FF6B35")]
        case .gold:      return ConfettiPalette.grand
        case .legendary: return [Color(hex: "#9B5DE5"), Color(hex: "#E0BBFF"), Color(hex: "#FFD700"), Color(hex: "#06D6A0"), Color(hex: "#FF6B35"), Color(hex: "#FFFFFF")]
        }
    }

    private func playSound() {
        if isGrand {
            NSSound(named: tier.primarySound)?.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                NSSound(named: "Glass")?.play()
            }
            if tier.intensity >= 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    NSSound(named: "Glass")?.play()
                }
            }
            if tier.intensity >= 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    NSSound(named: "Hero")?.play()
                }
            }
        } else {
            NSSound(named: "Glass")?.play()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true

        withAnimation(.easeInOut(duration: 0.35)) {
            backdropOpacity = 0
            contentOpacity = 0
            contentScale = 0.88
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onFinished()
        }
    }
}

// MARK: - Day Celebration Content

struct DayCelebrationContent: View {
    let streak: Int

    @State private var sealScale: CGFloat = 0.3
    @State private var sealRotation: Double = -14
    @State private var ringScale: CGFloat = 0.4
    @State private var ringOpacity: Double = 0.9
    @State private var glowPulse: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 26) {
            ZStack {
                Circle()
                    .stroke(Theme.success.opacity(ringOpacity), lineWidth: 3)
                    .frame(width: 140, height: 140)
                    .scaleEffect(ringScale)

                Circle()
                    .fill(Theme.success.opacity(0.30))
                    .frame(width: 170, height: 170)
                    .blur(radius: 34)
                    .scaleEffect(glowPulse)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 110))
                    .foregroundStyle(Theme.success)
                    .shadow(color: Theme.success.opacity(0.75), radius: 26)
                    .scaleEffect(sealScale)
                    .rotationEffect(.degrees(sealRotation))
            }

            VStack(spacing: 10) {
                Text("Day Complete!")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 3)

                if streak > 0 {
                    Text("\(streak) day streak — keep going.")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
        }
        .padding(40)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.1)) {
                sealScale = 1.0
                sealRotation = 0
            }
            withAnimation(.easeOut(duration: 1.2).delay(0.1)) {
                ringScale = 2.9
                ringOpacity = 0
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                glowPulse = 1.18
            }
        }
    }
}

// MARK: - Grand Celebration Content

struct GrandCelebrationContent: View {
    let days: Int
    let streak: Int
    let tier: CelebrationTier

    @State private var trophyScale: CGFloat = 0.2
    @State private var trophyRotation: Double = -22
    @State private var titleScale: CGFloat = 0.82
    @State private var ring1Scale: CGFloat = 0.3
    @State private var ring1Opacity: Double = 0.9
    @State private var ring2Scale: CGFloat = 0.3
    @State private var ring2Opacity: Double = 0.9
    @State private var shineOffset: CGFloat = -1.4
    @State private var glowPulse: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 28) {
            trophyBlock
            tierPill
            titleBlock
            subtitleBlock
            badgeRow
        }
        .padding(60)
        .onAppear { animate() }
    }

    private var trophyBlock: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: tier.cardGradient,
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 3
                )
                .frame(width: 180, height: 180)
                .scaleEffect(ring1Scale)
                .opacity(ring1Opacity)

            Circle()
                .stroke(tier.badgeTint.opacity(0.7), lineWidth: 2)
                .frame(width: 180, height: 180)
                .scaleEffect(ring2Scale)
                .opacity(ring2Opacity)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            tier.badgeTint.opacity(0.60),
                            tier.badgeTint.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .scaleEffect(glowPulse)

            Image(systemName: "trophy.fill")
                .font(.system(size: 130))
                .foregroundStyle(
                    LinearGradient(
                        colors: tier.numberGradient,
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: tier.badgeTint.opacity(0.9), radius: 34)
                .scaleEffect(trophyScale)
                .rotationEffect(.degrees(trophyRotation))
        }
    }

    private var tierPill: some View {
        Text(tier.label)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .tracking(4)
            .foregroundStyle(tier.badgeTint)
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(Capsule().strokeBorder(tier.badgeTint.opacity(0.6), lineWidth: 1.5))
            )
    }

    private var titleBlock: some View {
        ZStack {
            Text("\(days) DAY STREAK")
                .font(.system(size: 58, weight: .black, design: .rounded))
                .tracking(3)
                .foregroundStyle(
                    LinearGradient(
                        colors: tier.numberGradient,
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .shadow(color: tier.badgeTint.opacity(0.65), radius: 14)
                .scaleEffect(titleScale)

            Text("\(days) DAY STREAK")
                .font(.system(size: 58, weight: .black, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white)
                .mask(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.9), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: 220)
                    .offset(x: shineOffset * 420)
                )
                .scaleEffect(titleScale)
        }
    }

    private var subtitleBlock: some View {
        Text(tier.subtitle)
            .font(.title2.weight(.medium))
            .foregroundStyle(.white.opacity(0.92))
            .multilineTextAlignment(.center)
    }

    private var badgeRow: some View {
        HStack(spacing: 14) {
            grandBadge(icon: "flame.fill", text: "\(streak) day streak", tint: tier.badgeTint)
            grandBadge(icon: "trophy.fill", text: "Milestone \(days)", tint: tier.badgeTint)
        }
        .padding(.top, 4)
    }

    private func grandBadge(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text).font(.callout.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .foregroundStyle(.white)
        .background(
            Capsule()
                .fill(tint.opacity(0.28))
                .overlay(Capsule().stroke(tint.opacity(0.85), lineWidth: 1))
        )
    }

    private func animate() {
        withAnimation(.spring(response: 0.65, dampingFraction: 0.55).delay(0.15)) {
            trophyScale = 1.0
            trophyRotation = 0
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.30)) {
            titleScale = 1.0
        }
        withAnimation(.easeOut(duration: 1.2).delay(0.10)) {
            ring1Scale = 3.0
            ring1Opacity = 0
        }
        withAnimation(.easeOut(duration: 1.5).delay(0.30)) {
            ring2Scale = 3.8
            ring2Opacity = 0
        }
        withAnimation(.easeInOut(duration: 2.2).delay(0.55).repeatForever(autoreverses: true)) {
            glowPulse = 1.14
        }
        withAnimation(.easeInOut(duration: 2.4).delay(0.70).repeatForever(autoreverses: false)) {
            shineOffset = 1.4
        }
    }
}
