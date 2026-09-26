import SwiftUI
import AppKit

@MainActor
enum MilestoneCardRenderer {

    // MARK: Render

    /// Renders a 1080×1080 shareable card for a completed milestone.
    /// Returns nil if the platform can't produce the image.
    static func render(
        profile: UserProfile,
        milestone: Milestone,
        unitSystem: UnitSystem
    ) -> NSImage? {
        let view = MilestoneShareCard(
            profile: profile,
            milestone: milestone,
            unitSystem: unitSystem
        )
        .frame(width: 1080, height: 1080)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1080)

        guard let cgImage = renderer.cgImage else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: 1080, height: 1080))
    }

    // MARK: Save

    enum SaveResult {
        case saved(URL)
        case cancelled
        case failed(String)
    }

    /// Presents a save panel and writes the rendered PNG. Returns the
    /// outcome. Callers can display a message or open the file.
    @MainActor
    static func save(
        profile: UserProfile,
        milestone: Milestone,
        unitSystem: UnitSystem
    ) -> SaveResult {
        guard let image = render(profile: profile, milestone: milestone, unitSystem: unitSystem) else {
            return .failed("Could not render the card.")
        }
        guard let pngData = image.pngData else {
            return .failed("Could not encode the card as PNG.")
        }

        let panel = NSSavePanel()
        panel.title = "Save milestone card"
        panel.nameFieldStringValue = "DailyForge-\(milestone.day)-day-milestone.png"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return .cancelled
        }

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            try pngData.write(to: url, options: .atomic)
            return .saved(url)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: Copy

    /// Copies the rendered card to the system pasteboard as PNG.
    @MainActor
    static func copyToClipboard(
        profile: UserProfile,
        milestone: Milestone,
        unitSystem: UnitSystem
    ) -> Bool {
        guard let image = render(profile: profile, milestone: milestone, unitSystem: unitSystem) else {
            return false
        }
        guard let pngData = image.pngData else { return false }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(pngData, forType: .png)
        return true
    }
}

// MARK: - NSImage helper

private extension NSImage {
    var pngData: Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

// MARK: - Card View

struct MilestoneShareCard: View {
    let profile: UserProfile
    let milestone: Milestone
    let unitSystem: UnitSystem

    private var weightDeltaKg: Double? {
        guard let current = milestone.currentWeightKg else { return nil }
        return current - profile.initialWeightKg
    }

    private var weightDeltaLabel: String? {
        guard let delta = weightDeltaKg else { return nil }
        let absKg = abs(delta)
        let display = UnitConversion.kgToDisplay(absKg, unit: unitSystem)
        let unit = unitSystem.weightUnitLabel
        if absKg < 0.05 { return "Maintained weight" }
        return String(format: "%.1f %@ %@", display, unit, delta < 0 ? "lost" : "gained")
    }

    private var dateRangeLabel: String {
        let start = profile.startDate
        let end = milestone.completedAt ?? Date()
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: start)) → \(f.string(from: end))"
    }

    private var tier: CelebrationTier {
        CelebrationTier.forDays(milestone.day)
    }

    private var tierLabel: String {
        switch tier {
        case .legendary: return "LEGENDARY"
        case .gold:      return "GOLD"
        case .silver:    return "SILVER"
        case .bronze:    return "BRONZE"
        case .standard:  return "MILESTONE"
        }
    }

    var body: some View {
        ZStack {
            backgroundGradient

            // Decorative flourishes
            GeometryReader { geo in
                decorativeRings(size: geo.size)
            }
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                badgeRow
                    .padding(.bottom, 48)

                dayCount
                    .padding(.bottom, 8)

                Text("DAY STREAK")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .tracking(8)
                    .foregroundStyle(.white.opacity(0.95))

                Text(dateRangeLabel)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 14)

                Spacer(minLength: 0)

                weightBlock
                    .padding(.bottom, 40)

                footerBlock
                    .padding(.bottom, 60)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 80)
        }
        .clipShape(RoundedRectangle(cornerRadius: 60))
        .overlay(
            RoundedRectangle(cornerRadius: 60)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 3)
        )
    }

    // MARK: Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: tier.cardGradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func decorativeRings(size: CGSize) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 2)
                .frame(width: size.width * 0.85, height: size.width * 0.85)
                .offset(x: size.width * 0.30, y: -size.height * 0.30)

            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 2)
                .frame(width: size.width * 1.05, height: size.width * 1.05)
                .offset(x: -size.width * 0.35, y: size.height * 0.35)

            Circle()
                .fill(Color.white.opacity(0.03))
                .frame(width: size.width * 0.55, height: size.width * 0.55)
                .offset(x: -size.width * 0.42, y: -size.height * 0.40)
        }
    }

    // MARK: Badge

    private var badgeRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(tier.badgeTint)

            Text(tierLabel)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .tracking(6)
                .foregroundStyle(tier.badgeTint)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
                .overlay(Capsule().strokeBorder(tier.badgeTint.opacity(0.5), lineWidth: 2))
        )
    }

    // MARK: Day Count

    private var dayCount: some View {
        Text("\(milestone.day)")
            .font(.system(size: 300, weight: .black, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(
                LinearGradient(
                    colors: tier.numberGradient,
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: tier.badgeTint.opacity(0.5), radius: 30, y: 8)
    }

    // MARK: Weight

    @ViewBuilder
    private var weightBlock: some View {
        if let label = weightDeltaLabel {
            HStack(spacing: 14) {
                Image(systemName: weightIconName)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(tier.badgeTint)

                Text(label)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 2))
            )
        }
    }

    private var weightIconName: String {
        guard let delta = weightDeltaKg else { return "equal.circle.fill" }
        if abs(delta) < 0.05 { return "equal.circle.fill" }
        return delta < 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
    }

    // MARK: Footer

    private var footerBlock: some View {
        VStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.20))
                .frame(width: 120, height: 2)

            Text(profile.displayName)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 16, weight: .semibold))
                Text("FORGED WITH DAILYFORGE")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(3)
            }
            .foregroundStyle(.white.opacity(0.65))
            .padding(.top, 4)
        }
    }
}
