import SwiftUI
import AppKit

// MARK: - Kind

enum CelebrationKind: Equatable {
    case day
    case milestone(Int)
}

// MARK: - Root Overlay

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

    private var isGrand: Bool {
        if case .milestone = kind { return true }
        return false
    }

    private var duration: Double {
        isGrand ? 8.0 : 4.2
    }

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
                    colors: [
                        Color(hex: "#2A1400").opacity(0.94),
                        Color.black.opacity(0.90)
                    ],
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
            GrandCelebrationContent(days: days, streak: streak)
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
            burstParticles = ConfettiEmitter.burst(
                from: CGPoint(x: 0.5, y: 0.5),
                count: 160,
                speed: 0.5...1.4,
                lifetime: 3.0...5.0,
                palette: ConfettiPalette.grand,
                sizeRange: 10...20
            )
            rainParticles = ConfettiEmitter.rain(
                count: 170,
                spreadOver: 4.5,
                baseDelay: 0.3,
                palette: ConfettiPalette.grand
            )
            extraParticles =
                ConfettiEmitter.burst(
                    from: CGPoint(x: 0.5, y: 0.5),
                    count: 90,
                    speed: 0.3...0.75,
                    lifetime: 2.8...4.2,
                    palette: ConfettiPalette.grand,
                    baseDelay: 1.1,
                    sizeRange: 6...12
                )
                + ConfettiEmitter.burst(
                    from: CGPoint(x: 0.10, y: 0.20),
                    count: 45,
                    palette: ConfettiPalette.grand,
                    spread: 80,
                    baseAngle: 55,
                    sizeRange: 8...14
                )
                + ConfettiEmitter.burst(
                    from: CGPoint(x: 0.90, y: 0.20),
                    count: 45,
                    palette: ConfettiPalette.grand,
                    spread: 80,
                    baseAngle: 125,
                    sizeRange: 8...14
                )
        } else {
            burstParticles = ConfettiEmitter.burst(
                from: CGPoint(x: 0.5, y: 0.5),
                count: 100,
                speed: 0.35...1.0,
                lifetime: 2.2...3.4,
                palette: ConfettiPalette.celebration,
                sizeRange: 8...16
            )
            rainParticles = ConfettiEmitter.rain(
                count: 45,
                spreadOver: 1.8,
                baseDelay: 0.2,
                palette: ConfettiPalette.celebration
            )
            extraParticles = []
        }
        confettiReady = true
    }

    private func playSound() {
        if isGrand {
            NSSound(named: "Hero")?.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                NSSound(named: "Glass")?.play()
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
                        colors: [Color(hex: "#FFE066"), Color(hex: "#FF6B35")],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 3
                )
                .frame(width: 180, height: 180)
                .scaleEffect(ring1Scale)
                .opacity(ring1Opacity)

            Circle()
                .stroke(Color(hex: "#FFD700").opacity(0.7), lineWidth: 2)
                .frame(width: 180, height: 180)
                .scaleEffect(ring2Scale)
                .opacity(ring2Opacity)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#FFD700").opacity(0.60),
                            Color(hex: "#FFD700").opacity(0.0)
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
                        colors: [
                            Color(hex: "#FFE066"),
                            Color(hex: "#FFD700"),
                            Color(hex: "#FFAA00")
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: Color(hex: "#FFD700").opacity(0.9), radius: 34)
                .scaleEffect(trophyScale)
                .rotationEffect(.degrees(trophyRotation))
        }
    }

    private var titleBlock: some View {
        ZStack {
            Text("\(days) DAY STREAK")
                .font(.system(size: 58, weight: .black, design: .rounded))
                .tracking(3)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "#FFE066"),
                            Color(hex: "#FFD700"),
                            Color(hex: "#FF8C00"),
                            Color(hex: "#FFD700")
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .shadow(color: Color(hex: "#FF6B35").opacity(0.65), radius: 14)
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
        Text("A month of discipline. You earned this.")
            .font(.title2.weight(.medium))
            .foregroundStyle(.white.opacity(0.92))
            .multilineTextAlignment(.center)
    }

    private var badgeRow: some View {
        HStack(spacing: 14) {
            grandBadge(icon: "flame.fill", text: "\(streak) day streak", tint: Color(hex: "#FF6B35"))
            grandBadge(icon: "trophy.fill", text: "Milestone \(days)", tint: Color(hex: "#FFD700"))
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
