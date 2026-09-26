import SwiftUI

// MARK: - Suggestion

struct RecoverySuggestion: Identifiable, Hashable {
    let id: String
    let icon: String
    let title: String
    let body: String
    let duration: String
    let tint: Color
}

// MARK: - Catalog

enum RecoveryCatalog {

    /// The full pool of real, actionable recovery ideas. A subset is
    /// chosen deterministically for each day so the user sees variety
    /// without us having to track state.
    static let all: [RecoverySuggestion] = [
        RecoverySuggestion(
            id: "stretch",
            icon: "figure.flexibility",
            title: "5-minute stretch",
            body: "Hips, hamstrings, and shoulders. Hold each pose for 30 seconds — don't bounce.",
            duration: "5 min",
            tint: Color(hex: "#9B5DE5")
        ),
        RecoverySuggestion(
            id: "walk",
            icon: "figure.walk",
            title: "Easy walk",
            body: "Aim for 20 minutes outdoors. Sunlight and low-intensity movement speed recovery.",
            duration: "20 min",
            tint: Color(hex: "#06D6A0")
        ),
        RecoverySuggestion(
            id: "hydrate",
            icon: "drop.fill",
            title: "Hydrate",
            body: "Drink 2–3 extra glasses of water today. Dehydration slows muscle repair.",
            duration: "All day",
            tint: Color(hex: "#118AB2")
        ),
        RecoverySuggestion(
            id: "foamroll",
            icon: "figure.rolling",
            title: "Foam roll",
            body: "Quads, calves, and upper back. Spend 60 seconds per area, slow and deliberate.",
            duration: "6 min",
            tint: Color(hex: "#FF6B35")
        ),
        RecoverySuggestion(
            id: "sleep",
            icon: "bed.double.fill",
            title: "Prioritize sleep",
            body: "Aim for 8 hours tonight. Most muscle repair happens during deep sleep.",
            duration: "Tonight",
            tint: Color(hex: "#9B5DE5")
        ),
        RecoverySuggestion(
            id: "mobility",
            icon: "figure.cooldown",
            title: "Mobility flow",
            body: "Cat-cow → world's greatest stretch → 90/90 hip switch. Two rounds, no rush.",
            duration: "8 min",
            tint: Color(hex: "#06D6A0")
        ),
        RecoverySuggestion(
            id: "yoga",
            icon: "figure.yoga",
            title: "Light yoga",
            body: "Down dog → warrior I & II → child's pose. Breathe through every transition.",
            duration: "15 min",
            tint: Color(hex: "#118AB2")
        ),
        RecoverySuggestion(
            id: "breathe",
            icon: "wind",
            title: "4-7-8 breathing",
            body: "Inhale 4s, hold 7s, exhale 8s. Repeat 8 cycles. Lowers cortisol, aids recovery.",
            duration: "5 min",
            tint: Color(hex: "#FF6B35")
        ),
        RecoverySuggestion(
            id: "protein",
            icon: "fork.knife",
            title: "Protein with every meal",
            body: "Aim for 0.8g per pound of bodyweight today to support muscle synthesis.",
            duration: "All day",
            tint: Color(hex: "#FF6B35")
        ),
        RecoverySuggestion(
            id: "cold",
            icon: "snowflake",
            title: "Cold exposure",
            body: "60–90 seconds of cold shower at the end. Reduces inflammation and soreness.",
            duration: "2 min",
            tint: Color(hex: "#118AB2")
        ),
        RecoverySuggestion(
            id: "sunlight",
            icon: "sun.max.fill",
            title: "Get sunlight",
            body: "10 minutes of morning sun regulates circadian rhythm and improves sleep quality.",
            duration: "10 min",
            tint: Color(hex: "#FFD166")
        ),
        RecoverySuggestion(
            id: "legs-up",
            icon: "figure.seated.side",
            title: "Legs up the wall",
            body: "Lie on your back, legs vertical against a wall. Great for circulation after leg days.",
            duration: "5 min",
            tint: Color(hex: "#9B5DE5")
        )
    ]

    /// Deterministic per-day selection. The same day always returns the
    /// same three suggestions, but they rotate daily.
    static func suggestions(for date: Date = Date(), count: Int = 3) -> [RecoverySuggestion] {
        let key = DayLogic.dayKey(date)
        // Simple stable hash from the day key.
        let seed = key.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        let pool = all
        guard !pool.isEmpty else { return [] }

        var picked: [RecoverySuggestion] = []
        var used = Set<Int>()
        var cursor = abs(seed) % pool.count

        while picked.count < min(count, pool.count) {
            if !used.contains(cursor) {
                used.insert(cursor)
                picked.append(pool[cursor])
            }
            cursor = (cursor + 1) % pool.count
        }
        return picked
    }
}

// MARK: - View

struct RestDayRecoverySection: View {
    let date: Date

    private var suggestions: [RecoverySuggestion] {
        RecoveryCatalog.suggestions(for: date, count: 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Active recovery")
                    .font(.headline)
                Spacer()
                Text("Refreshes daily")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }

            VStack(spacing: 10) {
                ForEach(suggestions) { item in
                    RecoveryRow(suggestion: item)
                }
            }
        }
        .frame(maxWidth: 520)
    }
}

private struct RecoveryRow: View {
    let suggestion: RecoverySuggestion
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(suggestion.tint.opacity(0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: suggestion.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(suggestion.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(suggestion.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(suggestion.duration)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(suggestion.tint.opacity(0.14))
                        .foregroundStyle(suggestion.tint)
                        .clipShape(Capsule())
                }
                Text(suggestion.body)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.border, lineWidth: 0.5)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.05)) {
                appeared = true
            }
        }
    }
}
