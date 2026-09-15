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
    let isCompletedToday: Bool
    var onStart: () -> Void
    var onComplete: () -> Void
    var onDisableDaily: () -> Void
    var onDelete: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showDisableConfirmation = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            statsRow
            sessionPanel
            dailyToggle
            if !exercise.notes.isEmpty { notesPanel }
            Spacer(minLength: 0)
            actions
        }
        .padding(28)
        .frame(width: 520, height: sheetHeight)
        .confirmationDialog(
            "Stop repeating this exercise every day?",
            isPresented: $showDisableConfirmation,
            titleVisibility: .visible
        ) {
            Button("Stop Repeating", role: .destructive) { disableDaily() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("\"\(exercise.name)\" will disappear from your daily list immediately. You can turn it back on at any time from this same sheet.")
        }
        .confirmationDialog(
            "Delete this exercise?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Forever", role: .destructive) { deleteExercise() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("\"\(exercise.name)\" and its entire completion history will be removed. This cannot be undone.")
        }
    }

    private var sheetHeight: CGFloat {
        #if DEBUG
        return isCompletedToday ? 600 : 660
        #else
        return isCompletedToday ? 500 : 560
        #endif
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

    private var dailyToggle: some View {
        GroupBox {
            HStack(spacing: 12) {
                Image(systemName: exercise.isDaily ? "repeat" : "1.circle")
                    .font(.title2)
                    .foregroundStyle(exercise.isDaily ? .blue : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Repeat every day")
                        .font(.callout.weight(.medium))
                    Text(exercise.isDaily
                         ? "Turn off to remove this exercise from your daily list."
                         : "This exercise is no longer part of your daily routine.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { exercise.isDaily },
                    set: { newValue in
                        if newValue {
                            enableDaily()
                        } else {
                            showDisableConfirmation = true
                        }
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
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
            if isCompletedToday {
                HStack {
                    Label("Completed today", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            } else {
                Button {
                    onStart()
                } label: {
                    Label("Start Workout", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

                Button("Not yet") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            #if DEBUG
            Divider()
                .padding(.vertical, 4)

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Exercise", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            #endif
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title.bold().monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Mutations

    private func disableDaily() {
        exercise.isDaily = false
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) {
            exercise.createdAt = yesterday
        }
        try? context.save()
        onDisableDaily()
        dismiss()
    }

    private func enableDaily() {
        exercise.isDaily = true
        try? context.save()
    }

    private func deleteExercise() {
        let id = exercise.id
        let descriptor = FetchDescriptor<CompletionRecord>(
            predicate: #Predicate { $0.exerciseID == id }
        )
        if let records = try? context.fetch(descriptor) {
            for record in records {
                context.delete(record)
            }
        }
        context.delete(exercise)
        try? context.save()
        onDelete()
        dismiss()
    }
}

// MARK: - Manage Exercises (DEBUG ONLY)

#if DEBUG
struct ManageExercisesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Exercise.sortIndex) private var exercises: [Exercise]

    @State private var pendingDeletion: Exercise?
    @State private var showCreateExercise = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            listContent
        }
        .frame(width: 540, height: 620)
        .sheet(isPresented: $showCreateExercise) {
            CreateExerciseView(nextSortIndex: nextSortIndex)
        }
        .confirmationDialog(
            "Delete this exercise?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { exercise in
            Button("Delete Forever", role: .destructive) {
                deleteExercise(exercise)
                pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: { exercise in
            Text("\"\(exercise.name)\" and its entire completion history will be removed. This cannot be undone.")
        }
    }

    private var nextSortIndex: Int {
        (exercises.map(\.sortIndex).max() ?? -1) + 1
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Manage Exercises").font(.title2.bold())
                Text("\(exercises.count) exercise\(exercises.count == 1 ? "" : "s") • Delete or add more.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showCreateExercise = true
            } label: {
                Label("Add Exercise", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Button("Close") { dismiss() }
        }
        .padding(20)
    }

    @ViewBuilder
    private var listContent: some View {
        if exercises.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("No exercises yet")
                    .foregroundStyle(.secondary)
                Button {
                    showCreateExercise = true
                } label: {
                    Label("Create Exercise", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(exercises) { exercise in
                    ManageRow(exercise: exercise) {
                        pendingDeletion = exercise
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private func deleteExercise(_ exercise: Exercise) {
        let id = exercise.id
        let descriptor = FetchDescriptor<CompletionRecord>(
            predicate: #Predicate { $0.exerciseID == id }
        )
        if let records = try? context.fetch(descriptor) {
            for record in records {
                context.delete(record)
            }
        }
        context.delete(exercise)
        try? context.save()
    }
}

private struct ManageRow: View {
    let exercise: Exercise
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: exercise.exerciseType.icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(exercise.name).font(.body.weight(.medium))
                    if !exercise.isDaily {
                        Text("ONE-OFF")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.18))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete \(exercise.name)")
        }
        .padding(.vertical, 4)
    }

    private var summary: String {
        switch exercise.exerciseType {
        case .reps:
            return "\(exercise.sets) sets × \(exercise.reps) reps • \(exercise.bodyParts.joined(separator: ", "))"
        case .timer:
            return "\(exercise.sets) sets × \(formatDuration(exercise.durationSeconds)) • \(exercise.bodyParts.joined(separator: ", "))"
        }
    }
}
#endif

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

    @State private var offset = 0
    @State private var justSavedCount = 0

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

                if justSavedCount > 0 {
                    savedBanner
                }

                formBox

                Toggle(isOn: $confirmLock) {
                    Text("I understand this exercise is permanent and cannot be changed.")
                        .font(.callout)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.callout)
                }

                actionButtons
            }
            .padding(24)
        }
        .frame(width: 560, height: 860)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("New Exercise").font(.largeTitle.bold())
            Text("Once saved, this exercise is locked in. You can still change the daily-repeat flag later.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var savedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("\(justSavedCount) exercise\(justSavedCount == 1 ? "" : "s") saved. Keep going or close when done.")
                .font(.callout)
            Spacer()
        }
        .padding(10)
        .background(Color.green.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var formBox: some View {
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
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)

            Spacer()

            #if DEBUG
            Button("Save & Add Another") {
                save(stayOpen: true)
            }
            .buttonStyle(.bordered)
            .disabled(!confirmLock)
            #endif

            Button("Save Exercise") {
                save(stayOpen: false)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!confirmLock)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func toggleBodyPart(_ part: String) {
        if selectedBodyParts.contains(part) {
            selectedBodyParts.remove(part)
        } else {
            selectedBodyParts.insert(part)
        }
    }

    private func save(stayOpen: Bool) {
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
            sortIndex: nextSortIndex + offset
        )
        context.insert(exercise)
        try? context.save()

        errorMessage = nil

        if stayOpen {
            offset += 1
            justSavedCount += 1
            resetForNext()
        } else {
            dismiss()
        }
    }

    private func resetForNext() {
        name = ""
        notes = ""
        repsText = "10"
        setsText = "3"
        durationText = "30"
        sessionDurationText = "60"
        confirmLock = false
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
