import SwiftUI
import SwiftData
import Combine

struct TodayView: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.sortIndex) private var allExercises: [Exercise]
    @Query(sort: \CompletionRecord.completedAt, order: .reverse) private var records: [CompletionRecord]
    @Query private var dayLocks: [DayLock]
    @Query private var swears: [DailySwear]
    @Query private var milestones: [Milestone]

    @State private var selectedExercise: Exercise?
    @State private var activeSession: Exercise?
    @State private var showCreateExercise = false
    @State private var showHistory = false
    @State private var showMinimumAlert = false
    @State private var today = Date()
    @State private var showMilestoneUnlock = false
    @State private var showDayCompletePrompt = false
    @State private var showSwearSheet = false

    #if DEBUG
    @State private var showManageExercises = false
    #endif

    private let minimumExercises = 5
    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var exercises: [Exercise] {
        DayLogic.activeExercises(from: allExercises, on: today)
    }
    private var dailyExercises: [Exercise] {
        DayLogic.dailyExercises(from: allExercises)
    }
    private var meetsMinimum: Bool { exercises.count >= minimumExercises }
    private var remainingToMinimum: Int { max(0, minimumExercises - exercises.count) }
    private var allExercisesDone: Bool {
        DayLogic.allCompletedToday(exercises: exercises, records: records)
    }
    private var allDone: Bool { meetsMinimum && allExercisesDone }
    private var isLockedToday: Bool {
        let key = DayLogic.dayKey()
        return dayLocks.contains { $0.dayKey == key }
    }
    private var sworeToday: Bool {
        let key = DayLogic.dayKey()
        return swears.contains { $0.dayKey == key }
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
    private var pendingMilestone: Milestone? {
        let target = nextMilestoneDay - 30
        return milestones.first { $0.completedAt == nil && $0.day == target }
    }

    var body: some View {
        sheetsLayer
    }

    private var sheetsLayer: some View {
        alertsLayer
            .sheet(item: $selectedExercise, content: exerciseDetailSheet)
            .sheet(isPresented: $showCreateExercise, content: createExerciseSheet)
            .sheet(isPresented: $showHistory, content: historySheet)
            .sheet(isPresented: $showDayCompletePrompt, content: dayCompleteSheet)
            .sheet(isPresented: $showMilestoneUnlock, content: milestoneSheet)
            .sheet(isPresented: $showSwearSheet) {
                SwearView(dayKey: DayLogic.dayKey()) {
                    DispatchQueue.main.async { publishDayState() }
                }
            }
            #if DEBUG
            .sheet(isPresented: $showManageExercises) {
                ManageExercisesView()
            }
            #endif
    }

    private var alertsLayer: some View {
        lifecycleLayer
            .alert("Minimum exercises not met", isPresented: $showMinimumAlert) {
                Button("Add Exercise") { showCreateExercise = true }
                Button("Later", role: .cancel) { }
            } message: {
                Text("You have \(exercises.count) of \(minimumExercises) required daily exercises. Add \(remainingToMinimum) more to start the day.")
            }
    }

    private var lifecycleLayer: some View {
        baseLayer
            .onReceive(minuteTimer, perform: handleMinuteTick)
            .onAppear(perform: handleAppear)
            .onChange(of: allDone, handleAllDoneChange)
            .onChange(of: exercises.count, handleExerciseCountChange)
            .onChange(of: isLockedToday) { _, _ in publishDayState() }
    }

    private var baseLayer: some View {
        ZStack {
            mainContent
                .disabled(activeSession != nil)
                .blur(radius: activeSession != nil ? 6 : 0)

            if let exercise = activeSession {
                WorkoutSessionView(exercise: exercise) { startedAt in
                    completeExercise(exercise, startedAt: startedAt)
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .frame(minWidth: 560, minHeight: 600)
    }

    @ViewBuilder
    private func exerciseDetailSheet(_ exercise: Exercise) -> some View {
        ExerciseDetailSheet(
            exercise: exercise,
            isCompletedToday: completedToday.contains(exercise.id),
            onStart: {
                selectedExercise = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    activeSession = exercise
                }
            },
            onComplete: {
                selectedExercise = nil
                completeExercise(exercise, startedAt: nil)
            },
            onDisableDaily: {
                selectedExercise = nil
                publishDayState()
            },
            onDelete: {
                selectedExercise = nil
                publishDayState()
            }
        )
    }

    @ViewBuilder
    private func createExerciseSheet() -> some View {
        CreateExerciseView(nextSortIndex: (allExercises.map(\.sortIndex).max() ?? -1) + 1)
    }

    @ViewBuilder
    private func historySheet() -> some View {
        HistoryView(exercises: dailyExercises, records: records)
    }

    @ViewBuilder
    private func dayCompleteSheet() -> some View {
        DayCompletePrompt(
            exerciseCount: exercises.count,
            onAddMore: { showDayCompletePrompt = false },
            onSwear: {
                showDayCompletePrompt = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showSwearSheet = true
                }
            }
        )
    }

    @ViewBuilder
    private func milestoneSheet() -> some View {
        if let milestone = pendingMilestone {
            MilestoneView(profile: profile, milestone: milestone)
        }
    }

    private func handleMinuteTick(_ now: Date) {
        today = now
        checkMilestoneUnlock()
    }

    private func handleAppear() {
        publishDayState()
        checkMilestoneUnlock()

        if !isLockedToday && !meetsMinimum && !allExercises.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if !isLockedToday && !meetsMinimum { showMinimumAlert = true }
            }
            return
        }

        if allDone && !isLockedToday && !showMilestoneUnlock && !sworeToday {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if !showMilestoneUnlock && !isLockedToday { showDayCompletePrompt = true }
            }
        }
    }

    private func handleAllDoneChange(_ oldValue: Bool, _ newValue: Bool) {
        publishDayState()
        if newValue && !isLockedToday && !showMilestoneUnlock && activeSession == nil && !sworeToday {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if !showMilestoneUnlock && !isLockedToday { showDayCompletePrompt = true }
            }
        }
    }

    private func handleExerciseCountChange(_ oldValue: Int, _ newValue: Int) {
        publishDayState()
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .background(Theme.surfaceBase)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(today.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.title.bold())
                Text("Hi \(profile.displayName) — \(progress.done) of \(progress.total) done today")
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            streakBadge

            Button(action: PreferencesOpener.open) {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Preferences")
            .padding(.leading, 4)
        }
        .padding(20)
    }

    private var streakBadge: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(streak > 0 ? Theme.accentFill : Theme.textSecondary)
                Text("\(streak)")
                    .font(.title2.bold().monospacedDigit())
            }
            Text("day streak")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Theme.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var content: some View {
        if exercises.isEmpty {
            emptyState
        } else if isLockedToday {
            lockedState
        } else {
            activeState
        }
    }

    private var activeState: some View {
        VStack(spacing: 0) {
            if !meetsMinimum {
                minimumNotMetBanner
            } else if allDone && !sworeToday {
                swearBanner
            } else if allDone && sworeToday {
                allDoneBanner
            }
            exerciseList
        }
    }

    private var minimumNotMetBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warning)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Add \(remainingToMinimum) more exercise\(remainingToMinimum == 1 ? "" : "s")")
                    .font(.headline)
                Text("You need at least \(minimumExercises) exercises per day.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button("Add Exercise") { showCreateExercise = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.warningSoft)
    }

    private var swearBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Theme.success)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("All exercises done!").font(.headline)
                Text("Swear by voice to seal the day.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button {
                showSwearSheet = true
            } label: {
                Label("Swear by God", systemImage: "mic.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.successSoft)
    }

    private var allDoneBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Theme.success)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Day sealed.").font(.headline)
                Text("You swore by voice. Well done.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.successSoft)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 56))
                .foregroundStyle(Theme.textSecondary)
            Text("No exercises today")
                .font(.title2.bold())
            Text("Set up at least \(minimumExercises) exercises to begin your daily routine.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
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
                .foregroundStyle(Theme.success)
            Text("Done for today").font(.largeTitle.bold())
            if sworeToday {
                Text("You swore by voice. The day is sealed.")
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text("Come back tomorrow. Rest is part of the plan.")
                    .foregroundStyle(Theme.textSecondary)
            }
            Text("\(streak) day streak • Next milestone at \(nextMilestoneDay) days")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 4)

            #if DEBUG
            Button {
                showManageExercises = true
            } label: {
                Label("Manage Exercises", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .padding(.top, 16)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(exercises) { exercise in
                    exerciseRow(exercise)
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func exerciseRow(_ exercise: Exercise) -> some View {
        let isDone = completedToday.contains(exercise.id)
        ExerciseCard(exercise: exercise, isDone: isDone)
            .onTapGesture { selectedExercise = exercise }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button { showHistory = true } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(.bordered)

            Spacer()

            if !isLockedToday {
                Button { showCreateExercise = true } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            } else {
                Label("Locked until tomorrow", systemImage: "lock.fill")
                    .foregroundStyle(Theme.textSecondary)
                    .font(.callout)
            }
        }
        .padding(16)
    }

    private func publishDayState() {
        DayState.shared.allDone = allDone
        DayState.shared.isLocked = isLockedToday
        DayState.shared.exerciseCount = exercises.count
        DayState.shared.dayKey = DayLogic.dayKey()
    }

    private func completeExercise(_ exercise: Exercise, startedAt: Date?) {
        let key = DayLogic.dayKey()
        let already = records.contains { $0.exerciseID == exercise.id && $0.dayKey == key }
        if !already {
            let record = CompletionRecord(
                exerciseID: exercise.id,
                dayKey: key,
                startedAt: startedAt
            )
            context.insert(record)
            try? context.save()
        }
        activeSession = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            publishDayState()
            checkMilestoneUnlock()
            if allDone && !isLockedToday && !showMilestoneUnlock && !sworeToday {
                showDayCompletePrompt = true
            }
        }
    }

    private func lockDay() {
        guard meetsMinimum else {
            showMinimumAlert = true
            return
        }
        guard sworeToday else {
            showSwearSheet = true
            return
        }
        let key = DayLogic.dayKey()
        guard !dayLocks.contains(where: { $0.dayKey == key }) else { return }
        context.insert(DayLock(dayKey: key))
        try? context.save()
        publishDayState()
    }

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
    let onSwear: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.success)
            Text("Day complete!").font(.title.bold())
            Text("You finished all \(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s"). Ready to seal it?")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
            Text("You'll swear by voice that you did the work.")
                .font(.callout)
                .foregroundStyle(Theme.textTertiary)
            HStack(spacing: 12) {
                Button("Add more exercises") { onAddMore() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button {
                    onSwear()
                } label: {
                    Label("Swear by God", systemImage: "mic.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .padding(28)
        .frame(width: 440)
        .background(Theme.surfaceBase)
    }
}
