import SwiftUI
import SwiftData
import AppKit
import Combine

// MARK: - Card

struct ExerciseCard: View {
    let exercise: Exercise
    let isDone: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.green : Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: isDone ? "checkmark" : iconName)
                    .foregroundStyle(isDone ? .white : Color.accentColor)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.headline)
                        .strikethrough(isDone)
                        .foregroundStyle(isDone ? .secondary : .primary)

                    if !exercise.isDaily {
                        Text("ONE-OFF")
                            .font(.caption2.weight(.bold))
                            .tracking(0.5)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.18))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 6) {
                    Text(metricSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(exercise.bodyParts, id: \.self) { part in
                        Text(part)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDone ? Color.secondary.opacity(0.06) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isDone ? Color.clear : Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .opacity(isDone ? 0.6 : 1.0)
    }

    private var iconName: String {
        exercise.exerciseType == .timer ? "timer" : "figure.strengthtraining.traditional"
    }

    private var metricSummary: String {
        switch exercise.exerciseType {
        case .reps:
            return "\(exercise.sets) × \(exercise.reps) reps"
        case .timer:
            return "\(exercise.sets) × \(formatDuration(exercise.durationSeconds))"
        }
    }
}

// MARK: - Detail Sheet

struct ExerciseDetailSheet: View {
    let exercise: Exercise
    var onStart: () -> Void
    var onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            statsRow
            sessionPanel
            if !exercise.notes.isEmpty { notesPanel }
            Spacer(minLength: 0)
            actions
        }
        .padding(28)
        .frame(width: 500, height: 540)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: exercise.exerciseType.icon)
                    .foregroundStyle(Color.accentColor)
                Text(exercise.exerciseType.displayName.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .tracking(0.5)

                if exercise.isDaily {
                    HStack(spacing: 3) {
                        Image(systemName: "repeat")
                        Text("DAILY")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .tracking(0.5)
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "1.circle")
                        Text("ONE-OFF")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .tracking(0.5)
                }
            }
            Text(exercise.name).font(.largeTitle.bold())

            FlowLayout(spacing: 6) {
                ForEach(exercise.bodyParts, id: \.self) { part in
                    Text(part)
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 30) {
            statTile(value: "\(exercise.sets)", label: "Sets")

            switch exercise.exerciseType {
            case .reps:
                statTile(value: "\(exercise.reps)", label: "Reps per set")
                statTile(value: "\(exercise.sets * exercise.reps)", label: "Total reps")
            case .timer:
                statTile(value: formatDuration(exercise.durationSeconds), label: "Per set")
                statTile(value: formatDuration(exercise.durationSeconds * exercise.sets), label: "Work time")
            }
        }
    }

    private var sessionPanel: some View {
        GroupBox {
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDuration(exercise.sessionDurationSeconds))
                        .font(.title3.bold().monospacedDigit())
                }
                Spacer()
                Text("Cannot be stopped once started")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(8)
        }
    }

    private var notesPanel: some View {
        GroupBox("Notes") {
            Text(exercise.notes)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                onStart()
            } label: {
                Label("Start Workout", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            HStack {
                Button("Not yet") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Mark Done (skip timer)") { onComplete() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title.bold().monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Workout Session

struct WorkoutSessionView: View {
    let exercise: Exercise
    var onComplete: () -> Void

    @State private var endDate: Date
    @State private var now = Date()
    @State private var finished = false

    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    init(exercise: Exercise, onComplete: @escaping () -> Void) {
        self.exercise = exercise
        self.onComplete = onComplete
        let total = TimeInterval(max(exercise.sessionDurationSeconds, 1))
        _endDate = State(initialValue: Date().addingTimeInterval(total))
    }

    private var totalSeconds: Double { Double(max(exercise.sessionDurationSeconds, 1)) }
    private var remaining: Double { max(0, endDate.timeIntervalSince(now)) }
    private var progress: Double {
        guard totalSeconds > 0 else { return 1 }
        return 1 - (remaining / totalSeconds)
    }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            VStack(spacing: 36) {
                titleBlock
                ringBlock
                setsInfo
                footer
            }
            .padding(60)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onReceive(ticker) { date in
            now = date
            if !finished && remaining <= 0 {
                finished = true
                NSSound(named: "Glass")?.play()
            }
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Text(exercise.exerciseType == .timer ? "HOLD" : "WORKOUT")
                .font(.caption.weight(.semibold))
                .tracking(3)
                .foregroundStyle(.secondary)
            Text(exercise.name)
                .font(.system(size: 38, weight: .bold))
                .multilineTextAlignment(.center)
        }
    }

    private var ringBlock: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 20)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    finished ? Color.green : Color.accentColor,
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)

            VStack(spacing: 4) {
                Text(formatMMSS(Int(ceil(remaining))))
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.default, value: Int(ceil(remaining)))
                Text(finished ? "Complete!" : "remaining")
                    .font(.callout)
                    .foregroundStyle(finished ? .green : .secondary)
            }
        }
        .frame(width: 300, height: 300)
    }

    @ViewBuilder
    private var setsInfo: some View {
        switch exercise.exerciseType {
        case .reps:
            Text("\(exercise.sets) sets × \(exercise.reps) reps")
                .font(.title3)
                .foregroundStyle(.secondary)
        case .timer:
            Text("\(exercise.sets) sets × \(formatDuration(exercise.durationSeconds)) hold")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if finished {
            Button {
                onComplete()
            } label: {
                Label("Mark Done", systemImage: "checkmark.circle.fill")
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.tertiary)
                Text("This timer cannot be stopped.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Create Sheet

struct CreateExerciseView: View {
    let nextSortIndex: Int

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedBodyParts: Set<String> = []
    @State private var exerciseType: ExerciseType = .reps
    @State private var isDaily = true
    @State private var repsText = "10"
    @State private var setsText = "3"
    @State private var durationText = "30"
    @State private var sessionDurationText = "60"
    @State private var notes = ""
    @State private var confirmLock = false
    @State private var errorMessage: String?

    private let allBodyParts = [
        "Chest", "Back", "Shoulders", "Arms", "Core",
        "Legs", "Glutes", "Full Body", "Cardio"
    ]

    private let quickPerSetDurations = [15, 30, 45, 60, 90, 120]
    private let quickSessionDurations: [(String, Int)] = [
        ("30s", 30), ("1m", 60), ("2m", 120), ("3m", 180), ("5m", 300), ("10m", 600)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Exercise name", text: $name)
                            .textFieldStyle(.roundedBorder)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Type").font(.caption).foregroundStyle(.secondary)
                            Picker("", selection: $exerciseType) {
                                ForEach(ExerciseType.allCases) { type in
                                    Label(type.displayName, systemImage: type.icon).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }

                        // Repeat schedule — the key new control
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: $isDaily) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Repeat every day")
                                        .font(.callout.weight(.medium))
                                    Text(isDaily
                                         ? "This exercise will appear fresh every day."
                                         : "This exercise will only appear today, then retire.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                        }
                        .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Body parts").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                if !selectedBodyParts.isEmpty {
                                    Button("Clear") { selectedBodyParts.removeAll() }
                                        .buttonStyle(.link)
                                        .font(.caption)
                                }
                            }
                            FlowLayout(spacing: 6) {
                                ForEach(allBodyParts, id: \.self) { part in
                                    BodyPartChip(
                                        label: part,
                                        isSelected: selectedBodyParts.contains(part)
                                    ) {
                                        toggleBodyPart(part)
                                    }
                                }
                            }
                        }

                        HStack {
                            Text("Sets")
                            Spacer()
                            TextField("", text: $setsText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                        }

                        switch exerciseType {
                        case .reps:
                            HStack {
                                Text("Reps per set")
                                Spacer()
                                TextField("", text: $repsText)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .multilineTextAlignment(.trailing)
                            }

                        case .timer:
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Seconds per set")
                                    Spacer()
                                    TextField("", text: $durationText)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                        .multilineTextAlignment(.trailing)
                                }
                                HStack(spacing: 6) {
                                    ForEach(quickPerSetDurations, id: \.self) { seconds in
                                        Button(formatDuration(seconds)) {
                                            durationText = "\(seconds)"
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Session timer")
                                        .font(.callout.weight(.medium))
                                    Text("Total workout window. Once started, it cannot be stopped.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                TextField("", text: $sessionDurationText)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .multilineTextAlignment(.trailing)
                            }
                            HStack(spacing: 6) {
                                ForEach(quickSessionDurations, id: \.1) { label, seconds in
                                    Button(label) {
                                        sessionDurationText = "\(seconds)"
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }

                        TextField("Notes (optional)", text: $notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }
                    .padding(10)
                }

                Toggle(isOn: $confirmLock) {
                    Text("I understand this exercise is permanent and cannot be changed.")
                        .font(.callout)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.callout)
                }

                HStack {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Save Exercise") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!confirmLock)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
        }
        .frame(width: 560, height: 820)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("New Exercise").font(.largeTitle.bold())
            Text("Once saved, this exercise is locked in. No editing later.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func toggleBodyPart(_ part: String) {
        if selectedBodyParts.contains(part) {
            selectedBodyParts.remove(part)
        } else {
            selectedBodyParts.insert(part)
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { errorMessage = "Please enter a name."; return }
        guard !selectedBodyParts.isEmpty else { errorMessage = "Pick at least one body part."; return }
        guard let sets = Int(setsText), sets > 0 else { errorMessage = "Sets must be a positive number."; return }
        guard let sessionDuration = Int(sessionDurationText), sessionDuration > 0 else {
            errorMessage = "Session duration must be a positive number of seconds."
            return
        }

        var reps = 0
        var perSetDuration = 0

        switch exerciseType {
        case .reps:
            guard let r = Int(repsText), r > 0 else {
                errorMessage = "Reps must be a positive number."
                return
            }
            reps = r
        case .timer:
            guard let d = Int(durationText), d > 0 else {
                errorMessage = "Per-set duration must be a positive number."
                return
            }
            perSetDuration = d
        }

        let orderedParts = allBodyParts.filter { selectedBodyParts.contains($0) }

        let exercise = Exercise(
            name: trimmed,
            bodyParts: orderedParts,
            exerciseType: exerciseType,
            reps: reps,
            sets: sets,
            durationSeconds: perSetDuration,
            sessionDurationSeconds: sessionDuration,
            isDaily: isDaily,
            notes: notes,
            sortIndex: nextSortIndex
        )
        context.insert(exercise)
        try? context.save()
        dismiss()
    }
}

// MARK: - Reusable Chip

struct BodyPartChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                }
                Text(label).font(.callout)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > maxWidth, currentRowWidth > 0 {
                totalHeight += currentRowHeight + spacing
                currentRowWidth = size.width + spacing
                currentRowHeight = size.height
            } else {
                currentRowWidth += size.width + spacing
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }
        totalHeight += currentRowHeight
        return CGSize(width: maxWidth == .infinity ? currentRowWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Formatting

func formatDuration(_ seconds: Int) -> String {
    if seconds < 60 { return "\(seconds)s" }
    let m = seconds / 60
    let s = seconds % 60
    return s == 0 ? "\(m)m" : String(format: "%d:%02d", m, s)
}

func formatMMSS(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%02d:%02d", m, s)
}
