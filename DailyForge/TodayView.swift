import SwiftUI
import SwiftData
import Combine

struct TodayView: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.sortIndex) private var allExercises: [Exercise]
    @Query(sort: \CompletionRecord.completedAt, order: .reverse) private var records: [CompletionRecord]
    @Query private var dayLocks: [DayLock]
    @Query private var milestones: [Milestone]

    @State private var selectedExercise: Exercise?
    @State private var activeSession: Exercise?
    @State private var showCreateExercise = false
    @State private var showHistory = false
    @State private var today = Date()
    @State private var showMilestoneUnlock = false
    @State private var showDayCompletePrompt = false

    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // MARK: - Filtered exercise sets

    /// Exercises that belong to the current day. Daily exercises always show.
    /// Non-daily exercises only show on the day they were created.
    private var exercises: [Exercise] {
        DayLogic.activeExercises(from: allExercises, on: today)
    }

    /// Daily-only exercises — used for streak math so one-offs don't count.
    private var dailyExercises: [Exercise] {
        DayLogic.dailyExercises(from: allExercises)
    }

    // MARK: - Derived state

    private var allDone: Bool {
        DayLogic.allCompletedToday(exercises: exercises, records: records)
    }

    private var isLockedToday: Bool {
        let key = DayLogic.dayKey()
        return dayLocks.contains { $0.dayKey == key }
    }

    private var completedToday: Set<UUID> {
        let key = DayLogic.dayKey()
        return Set(records.filter { $0.dayKey == key }.map(\.exerciseID))
    }

    private var streak: Int {
        DayLogic.currentStreak(
            completedKeys: DayLogic.completedDayKeys(exercises: dailyExercises, records: records)
        )
    }

    private var progress: (done: Int, total: Int) {
        DayLogic.progressToday(exercises: exercises, records: records)
    }

    private var nextMilestoneDay: Int {
        let unlocked = Set(milestones.map(\.day))
        var day = 30
        while unlocked.contains(day) { day += 30 }
        return day
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            mainContent
                .disabled(activeSession != nil)
                .blur(radius: activeSession != nil ? 6 : 0)

            if let exercise = activeSession {
                WorkoutSessionView(exercise: exercise) {
                    completeExercise(exercise)
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .frame(minWidth: 560, minHeight: 600)
        .onReceive(minuteTimer) { now in
            today = now
            checkMilestoneUnlock()
        }
        .onAppear {
            checkMilestoneUnlock()
            if allDone && !isLockedToday && !showMilestoneUnlock {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if !showMilestoneUnlock && !isLockedToday {
                        showDayCompletePrompt = true
                    }
                }
            }
        }
        .onChange(of: allDone) { _, newValue in
            if newValue && !isLockedToday && !showMilestoneUnlock && activeSession == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if !showMilestoneUnlock && !isLockedToday {
                        showDayCompletePrompt = true
                    }
                }
            }
        }
        .sheet(item: $selectedExercise) { exercise in
            ExerciseDetailSheet(
                exercise: exercise,
                onStart: {
                    selectedExercise = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        activeSession = exercise
                    }
                },
                onComplete: {
                    selectedExercise = nil
                    completeExercise(exercise)
                }
            )
        }
        .sheet(isPresented: $showCreateExercise) {
            CreateExerciseView(nextSortIndex: (allExercises.map(\.sortIndex).max() ?? -1) + 1)
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(exercises: dailyExercises, records: records)
        }
        .sheet(isPresented: $showDayCompletePrompt) {
            DayCompletePrompt(
                exerciseCount: exercises.count,
                onAddMore: { showDayCompletePrompt = false },
                onLock: {
                    lockDay()
                    showDayCompletePrompt = false
                }
            )
        }
        .sheet(isPresented: $showMilestoneUnlock) {
            if let milestone = milestones.first(where: {
                $0.completedAt == nil && $0.day == nextMilestoneDay - 30
            }) {
                MilestoneView(profile: profile, milestone: milestone)
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(today.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.title.bold())
                Text("Hi \(profile.displayName) — \(progress.done) of \(progress.total) done today")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            streakBadge
        }
        .padding(20)
    }

    private var streakBadge: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(streak > 0 ? .orange : .secondary)
                Text("\(streak)")
                    .font(.title2.bold().monospacedDigit())
            }
            Text("day streak")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if exercises.isEmpty {
            emptyState
        } else if isLockedToday {
            lockedState
        } else {
            VStack(spacing: 0) {
                if allDone {
                    allDoneBanner
                }
                exerciseList
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No exercises today")
                .font(.title2.bold())
            Text(allExercises.isEmpty
                 ? "Add your first exercise. Once saved, its reps and sets are locked in."
                 : "No daily exercises are set up. Add one to start a streak.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380)
            Button("Create Exercise") { showCreateExercise = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var lockedState: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            Text("Done for today")
                .font(.largeTitle.bold())
            Text("Come back tomorrow. Rest is part of the plan.")
                .foregroundStyle(.secondary)
            Text("\(streak) day streak • Next milestone at \(nextMilestoneDay) days")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var allDoneBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("All exercises done!")
                    .font(.headline)
                Text("Lock the day when you're ready. You can still add more.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("I'm done for today") {
                lockDay()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.green.opacity(0.10))
    }

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(exercises) { exercise in
                    ExerciseCard(
                        exercise: exercise,
                        isDone: completedToday.contains(exercise.id)
                    )
                    .onTapGesture {
                        if !completedToday.contains(exercise.id) {
                            selectedExercise = exercise
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button {
                showHistory = true
            } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(.bordered)

            Spacer()

            if !isLockedToday {
                Button {
                    showCreateExercise = true
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            } else {
                Label("Locked until tomorrow", systemImage: "lock.fill")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .padding(16)
    }

    // MARK: - Actions

    private func completeExercise(_ exercise: Exercise) {
        let key = DayLogic.dayKey()
        let already = records.contains { $0.exerciseID == exercise.id && $0.dayKey == key }
        if !already {
            let record = CompletionRecord(exerciseID: exercise.id, dayKey: key)
            context.insert(record)
            try? context.save()
        }
        activeSession = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            checkMilestoneUnlock()
            if allDone && !isLockedToday && !showMilestoneUnlock {
                showDayCompletePrompt = true
            }
        }
    }

    private func lockDay() {
        let key = DayLogic.dayKey()
        guard !dayLocks.contains(where: { $0.dayKey == key }) else { return }
        let lock = DayLock(dayKey: key)
        context.insert(lock)
        try? context.save()
    }

    // MARK: - Milestone

    private func checkMilestoneUnlock() {
        let completed = DayLogic.completedDayKeys(exercises: dailyExercises, records: records)
        let streak = DayLogic.currentStreak(completedKeys: completed)
        let unlocked = Set(milestones.map(\.day))

        for target in stride(from: 30, through: max(streak, 30), by: 30)
        where streak >= target && !unlocked.contains(target) {
            let m = Milestone(day: target)
            context.insert(m)
            try? context.save()
            showMilestoneUnlock = true
        }
    }
}

// MARK: - Day Complete Prompt

struct DayCompletePrompt: View {
    let exerciseCount: Int
    let onAddMore: () -> Void
    let onLock: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Day complete!")
                .font(.title.bold())

            Text("You finished all \(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s"). Ready to call it a day?")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text("Rest is part of the plan. Come back tomorrow.")
                .font(.callout)
                .foregroundStyle(.tertiary)

            HStack(spacing: 12) {
                Button("Add more exercises") { onAddMore() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                Button("I'm done for today") { onLock() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .padding(28)
        .frame(width: 420)
    }
}
