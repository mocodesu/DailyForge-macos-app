import SwiftUI

// MARK: - Palette

enum ConfettiPalette {
    /// Warm celebratory colors — used for everyday completions.
    static let celebration: [Color] = [
        Color(hex: "#FF6B35"),
        Color(hex: "#FFD166"),
        Color(hex: "#EF476F"),
        Color(hex: "#06D6A0"),
        Color(hex: "#118AB2"),
        Color(hex: "#9B5DE5"),
    ]

    /// Gold-forward palette — used for milestone celebrations.
    static let grand: [Color] = [
        Color(hex: "#FFD700"),
        Color(hex: "#FFB800"),
        Color(hex: "#FF6B35"),
        Color(hex: "#EF476F"),
        Color(hex: "#06D6A0"),
        Color(hex: "#9B5DE5"),
        Color(hex: "#FFFFFF"),
    ]
}

// MARK: - Shape

enum ConfettiShape: CaseIterable {
    case rectangle
    case circle
    case triangle
    case ribbon
    case star
}

// MARK: - Particle

struct ConfettiParticle: Identifiable {
    let id = UUID()

    /// Normalized origin (0…1, origin is top-left of the canvas)
    let originX: Double
    let originY: Double
    /// Normalized velocity per second
    let vx: Double
    let vy: Double
    /// Initial rotation in radians
    let rotation: Double
    /// Rotation rate in radians per second
    let rotationSpeed: Double
    /// Rendered size in points
    let size: Double
    let color: Color
    let shape: ConfettiShape
    /// Phase offset for the side-to-side wobble
    let wobblePhase: Double
    /// Wobble amplitude (normalized)
    let wobbleAmplitude: Double
    /// Seconds before the particle appears
    let delay: Double
    /// Total lifetime in seconds
    let lifetime: Double
    /// Gravity multiplier (relative to a base of ~0.9)
    let gravity: Double
}

// MARK: - Emitters

enum ConfettiEmitter {

    /// A radial burst from a point.
    static func burst(
        from origin: CGPoint = CGPoint(x: 0.5, y: 0.45),
        count: Int = 80,
        speed: ClosedRange<Double> = 0.35...0.9,
        lifetime: ClosedRange<Double> = 2.2...3.6,
        palette: [Color] = ConfettiPalette.celebration,
        spread: Double = 360,
        baseAngle: Double = -90,
        baseDelay: Double = 0,
        sizeRange: ClosedRange<Double> = 8...16,
        gravity: ClosedRange<Double> = 0.7...1.4
    ) -> [ConfettiParticle] {
        (0..<count).map { _ in
            let angle = (baseAngle + Double.random(in: -spread / 2 ... spread / 2)) * .pi / 180
            let spd = Double.random(in: speed)
            return ConfettiParticle(
                originX: origin.x,
                originY: origin.y,
                vx: cos(angle) * spd,
                vy: sin(angle) * spd,
                rotation: Double.random(in: 0 ... .pi * 2),
                rotationSpeed: Double.random(in: -8 ... 8),
                size: Double.random(in: sizeRange),
                color: palette.randomElement() ?? .orange,
                shape: ConfettiShape.allCases.randomElement() ?? .rectangle,
                wobblePhase: Double.random(in: 0 ... .pi * 2),
                wobbleAmplitude: Double.random(in: 0.005 ... 0.02),
                delay: baseDelay + Double.random(in: 0 ... 0.12),
                lifetime: Double.random(in: lifetime),
                gravity: Double.random(in: gravity)
            )
        }
    }

    /// Confetti raining down from above the visible area.
    static func rain(
        count: Int = 120,
        spreadOver: Double = 3.0,
        baseDelay: Double = 0,
        palette: [Color] = ConfettiPalette.celebration
    ) -> [ConfettiParticle] {
        (0..<count).map { _ in
            ConfettiParticle(
                originX: Double.random(in: -0.05 ... 1.05),
                originY: -0.15,
                vx: Double.random(in: -0.05 ... 0.05),
                vy: Double.random(in: 0.25 ... 0.55),
                rotation: Double.random(in: 0 ... .pi * 2),
                rotationSpeed: Double.random(in: -6 ... 6),
                size: Double.random(in: 9 ... 18),
                color: palette.randomElement() ?? .orange,
                shape: ConfettiShape.allCases.randomElement() ?? .rectangle,
                wobblePhase: Double.random(in: 0 ... .pi * 2),
                wobbleAmplitude: Double.random(in: 0.01 ... 0.035),
                delay: baseDelay + Double.random(in: 0 ... spreadOver),
                lifetime: 6.0,
                gravity: Double.random(in: 0.3 ... 0.7)
            )
        }
    }
}

// MARK: - Canvas

struct ConfettiCanvas: View {
    let particles: [ConfettiParticle]
    let startDate: Date

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(startDate)
                for p in particles {
                    draw(p, at: t, in: context, size: size)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(
        _ p: ConfettiParticle,
        at t: Double,
        in context: GraphicsContext,
        size: CGSize
    ) {
        let localT = t - p.delay
        guard localT >= 0, localT < p.lifetime else { return }

        let wobble = sin(localT * 4 + p.wobblePhase) * p.wobbleAmplitude
        let x = (p.originX + p.vx * localT + wobble) * size.width
        let y = (p.originY + p.vy * localT + 0.5 * 0.9 * p.gravity * localT * localT) * size.height

        let progress = localT / p.lifetime
        let alpha: Double = progress < 0.75 ? 1.0 : max(0, 1 - (progress - 0.75) / 0.25)

        var ctx = context
        ctx.translateBy(x: x, y: y)
        ctx.rotate(by: .radians(p.rotation + p.rotationSpeed * localT))
        ctx.opacity = alpha

        let s = CGFloat(p.size)
        switch p.shape {
        case .rectangle:
            let r = CGRect(x: -s / 2, y: -s * 0.3, width: s, height: s * 0.6)
            ctx.fill(Path(r), with: .color(p.color))
        case .circle:
            let r = CGRect(x: -s / 2, y: -s / 2, width: s, height: s)
            ctx.fill(Path(ellipseIn: r), with: .color(p.color))
        case .triangle:
            var path = Path()
            path.move(to: CGPoint(x: 0, y: -s * 0.5))
            path.addLine(to: CGPoint(x: s * 0.5, y: s * 0.35))
            path.addLine(to: CGPoint(x: -s * 0.5, y: s * 0.35))
            path.closeSubpath()
            ctx.fill(path, with: .color(p.color))
        case .ribbon:
            let r = CGRect(x: -s * 0.15, y: -s * 0.5, width: s * 0.3, height: s)
            ctx.fill(Path(r), with: .color(p.color))
        case .star:
            var path = Path()
            let points = 5
            let outer = s * 0.5
            let inner = s * 0.22
            for i in 0..<(points * 2) {
                let angle = Double(i) * .pi / Double(points) - .pi / 2
                let radius = i.isMultiple(of: 2) ? outer : inner
                let pt = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath()
            ctx.fill(path, with: .color(p.color))
        }
    }
}
