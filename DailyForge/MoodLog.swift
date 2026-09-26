import SwiftUI
import SwiftData

// MARK: - Mood

enum WorkoutMood: String, CaseIterable, Codable, Identifiable {
    case exhausted
    case fine
    case strong
    case elite

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .exhausted: return "😮‍💨"
        case .fine:      return "🙂"
        case .strong:    return "💪"
        case .elite:     return "🔥"
        }
    }

    var label: String {
        switch self {
        case .exhausted: return "Exhausted"
        case .fine:      return "Fine"
        case .strong:    return "Strong"
        case .elite:     return "Elite"
        }
    }

    var descriptor: String {
        switch self {
        case .exhausted: return "Drained but done"
        case .fine:      return "Got through it"
        case .strong:    return "Felt powerful"
        case .elite:     return "Untouchable"
        }
    }

    var tint: Color {
        switch self {
        case .exhausted: return Color(hex: "#9B5DE5")
        case .fine:      return Color(hex: "#118AB2")
        case .strong:    return Color(hex: "#FF6B35")
        case .elite:     return Color(hex: "#06D6A0")
        }
    }

    /// 1-4 scale used for charts/averages.
    var score: Int {
        switch self {
        case .exhausted: return 1
        case .fine:      return 2
        case .strong:    return 3
        case .elite:     return 4
        }
    }
}

// NOTE: The `SessionMood` @Model class lives in `Models.swift`.
// It used to also live here, which caused an "ambiguous type" error
// at every call site. Do not re-declare it here.

// MARK: - Sheet

struct MoodLogSheet: View {
    let dayKey: String
    let dayNumber: Int
    let onSave: (WorkoutMood, String) -> Void
    let onSkip: () -> Void

    @State private var selectedMood: WorkoutMood?
    @State private var note: String = ""
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            header
            moodGrid
            noteField
            actionsRow
        }
        .padding(28)
        .frame(width: 520)
        .background(Theme.surfaceBase)
        .scaleEffect(appeared ? 1 : 0.94)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Theme.accentFill.opacity(0.16))
                    .frame(width: 120, height: 120)
                    .blur(radius: 22)

                Circle()
                    .fill(Theme.surfaceElevated)
                    .frame(width: 92, height: 92)
                    .overlay(Circle().stroke(Theme.border, lineWidth: 0.5))

                Text("🎯")
                    .font(.system(size: 44))
            }
            .padding(.top, 4)

            Text("How did it feel?")
                .font(.title2.bold())
            Text("A quick mood snapshot for Day \(dayNumber). You can skip it, but logging it makes your recaps richer.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
        }
    }

    private var moodGrid: some View {
        HStack(spacing: 10) {
            ForEach(WorkoutMood.allCases) { mood in
                moodButton(mood)
            }
        }
    }

    private func moodButton(_ mood: WorkoutMood) -> some View {
        let isSelected = selectedMood == mood
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedMood = mood
            }
        } label: {
            VStack(spacing: 8) {
                Text(mood.emoji)
                    .font(.system(size: 38))

                Text(mood.label)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Theme.textPrimary)

                Text(mood.descriptor)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? mood.tint : Theme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? Color.clear : Theme.border,
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: isSelected ? mood.tint.opacity(0.35) : .clear,
                radius: 8,
                y: 3
            )
        }
        .buttonStyle(.plain)
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Note (optional)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.4)
            TextField("Anything worth remembering?", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 10) {
            Button("Skip") { onSkip() }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

            Spacer()

            Button {
                guard let mood = selectedMood else { return }
                onSave(mood, note)
            } label: {
                Label("Save Mood", systemImage: "checkmark")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 130)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(selectedMood == nil)
        }
    }
}

// MARK: - Display helper

struct MoodChip: View {
    let mood: WorkoutMood
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Text(mood.emoji)
                .font(compact ? .caption : .callout)
            Text(mood.label)
                .font(compact ? .caption.weight(.medium) : .callout.weight(.medium))
        }
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 3 : 6)
        .background(mood.tint.opacity(0.15))
        .foregroundStyle(mood.tint)
        .clipShape(Capsule())
    }
}
