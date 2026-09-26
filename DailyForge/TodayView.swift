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
    @Query private var freezes: [StreakFreeze]
    @Query private var moods: [SessionMood]

    @AppStorage(PreferenceKeys.minimumExercises) private var minimumExercises: Int = Preferences.defaultMinimumExercises
    @AppStorage(PreferenceKeys.restDaysRaw) private var restDaysRaw: String = Preferences.defaultRestDaysRaw
    @AppStorage(PreferenceKeys.freezeTokensInBank) private var freezeTokensInBank: Int = 0

    @State private var selectedExercise: Exercise?
    @State private var exerciseToEdit: Exercise?
    @State private var activeSession: Exercise?
    @State private var showCreateExercise = false
    @State private var showHistory = false
    @State private var showMinimumAlert = false
    @State private var today = Date()
    @State private var showMilestoneUnlock = false
    @State private var showDayCompletePrompt = false
    @State private var showSwearSheet = false
    @State private var showMoodSheet = false

    @State private var celebration: CelebrationKind?
    @State private var celebrationQueue: [CelebrationKind] = []
    @State private var pendingMilestoneCelebration: Int?
    @State private var moodPromptPending = false

    @State private var showFreezeSheet = false
    @State private var showTokenEarnedOverlay = false
    @State private var bannerDismissed = false

    #if DEBUG
    @State private var showManageExercises = false
    @State private var showDebugUndoConfirmation = false
    #endif

    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // MARK: Schedule helpers

    private var restDays: Set<Int> {
        let parsed = restDaysRaw
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { (1...7).contains($0) }
        return Set(parsed.prefix(Preferences.maxRestDays))
    }

    private var isRestDay: Bool {
        let weekday = Calendar.current.component(.weekday, from: today)
        return restDays.contains(weekday)
    }

    private var restDayDescription: String {
        if restDays.isEmpty {
            return "No rest days configured. Every day counts."
        }
        let names = WeekdayNames.full
        let sorted = restDays.sorted()
        if sorted.count == 1 { return "\(names[sorted[0] - 1]) is a rest day." }
        let head = sorted.dropLast().map { names[$0 - 1] }.joined(separator: ", ")
        let tail = names[sorted.last! - 1]
        return "\(head) and \(tail) are rest days."
    }

    private var nextWorkoutDayLabel: String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        let names = WeekdayNames.full
        for offset in 1...7 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: start) else { break }
            let weekday = calendar.component(.weekday, from: candidate)
            if !restDays.contains(weekday) { return names[weekday - 1] }
        }
        return "—"
    }

    // MARK: Derived state

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
    private var moodToday: SessionMood? {
        let key = DayLogic.dayKey()
        return moods.first { $0.dayKey == key }
    }
    private var hasMoodToday: Bool { moodToday != nil }
    private var completedToday: Set<UUID> {
        let key = DayLogic.dayKey()
        return Set(records.filter { $0.dayKey == key }.map(\.exerciseID))
    }
    private var frozenKeys: Set<String> {
        Set(freezes.map(\.dayKey))
    }
    private var streak: Int {
        DayLogic.currentStreak(
            completedKeys: DayLogic.completedDayKeys(exercises: dailyExercises, records: records),
            frozenKeys: frozenKeys
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

    // MARK: Freeze detection

    private var missedDayCandidate: Date? {
        StreakFreezeManager.findMostRecentMissedDay(
            records: records,
            exercises: dailyExercises,
            frozenKeys: frozenKeys
        )
    }

    private var streakIfFreezeCandidate: Int {
        guard let date = missedDayCandidate else { return 0 }
        var withFreeze = frozenKeys
        withFreeze.insert(DayLogic.dayKey(date))
        return DayLogic.currentStreak(
            completedKeys: DayLogic.completedDayKeys(exercises: dailyExercises, records: records),
            frozenKeys: withFreeze
        )
    }

    private var canOfferFreeze: Bool {
        !bannerDismissed
        && missedDayCandidate != nil
        && streakIfFreezeCandidate > 0
        && freezeTokensInBank > 0
        && !isLockedToday
    }

    // MARK: Body

    var body: some View {
        ZStack {
            sheetsLayer

            if let kind = celebration {
                CelebrationView(kind: kind, streak: streak) {
                    celebrationFinished()
                }
                .transition(.opacity)
                .zIndex(1000)
            }

            tokenEarnedOverlay
        }
        .animation(.easeInOut(duration: 0.25), value: celebration)
    }

    @ViewBuilder
    private var tokenEarnedOverlay: some View {
        if showTokenEarnedOverlay {
            VStack {
                HStack(spacing: 10) {
                    Image(systemName: "snowflake")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(showTokenEarnedOverlay ? 360 : 0))
                        .animation(
                            .easeInOut(duration: 1.4).repeatForever(autoreverses: false),
                            value: showTokenEarnedOverlay
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Freeze token earned")
                            .font(.callout.weight(.semibold))
                        Text("You can now protect a missed day")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#118AB2"), Color(hex: "#06D6A0")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color(hex: "#118AB2").opacity(0.45), radius: 14, y: 4)
                )
                .padding(.top, 60)

                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .allowsHitTesting(false)
            .zIndex(999)
        }
    }

    private var sheetsLayer: some View {
        alertsLayer
            .sheet(item: $selectedExercise, content: exerciseDetailSheet)
            .sheet(isPresented: $showCreateExercise, content: createExerciseSheet)
            .sheet(item: $exerciseToEdit, onDismiss: { publishDayState() }, content: editExerciseSheet)
            .sheet(isPresented: $showHistory, content: historySheet)
            .sheet(isPresented: $showDayCompletePrompt, content: dayCompleteSheet)
            .sheet(isPresented: $showMilestoneUnlock, content: milestoneSheet)
            .sheet(isPresented: $showFreezeSheet, content: freezeSheet)
            .sheet(isPresented: $showMoodSheet, content: moodSheet)
            .sheet(isPresented: $showSwearSheet) {
                SwearView(dayKey: DayLogic.dayKey()) {
                    DispatchQueue.main.async {
                        publishDayState()
                        refreshFreezeEarnings(announce: true)
                        moodPromptPending = !hasMoodToday
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                            enqueueCelebration(.day)
                        }
                    }
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
            #if DEBUG
            .confirmationDialog(
                "Undo everything for today?",
                isPresented: $showDebugUndoConfirmation,
                titleVisibility: .visible
            ) {
                Button("Undo All", role: .destructive) { debugUndoAll() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Removes every completion record, the day lock, the voice swear, and today's mood for \(DayLogic.dayKey()). Exercises themselves are untouched.")
            }
            #endif
    }

    private var lifecycleLayer: some View {
        baseLayer
            .onReceive(minuteTimer, perform: handleMinuteTick)
            .onAppear(perform: handleAppear)
            .onChange(of: allDone, handleAllDoneChange)
            .onChange(of: exercises.count, handleExerciseCountChange)
            .onChange(of: isLockedToday) { _, _ in publishDayState() }
            .onChange(of: minimumExercises) { _, _ in publishDayState() }
            .onChange(of: restDaysRaw) { _, _ in publishDayState() }
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
            onEdit: {
                selectedExercise = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    exerciseToEdit = exercise
                }
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
    private func editExerciseSheet(_ exercise: Exercise) -> some View {
        CreateExerciseView(
            nextSortIndex: (allExercises.map(\.sortIndex).max() ?? -1) + 1,
            exerciseToEdit: exercise
        )
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

    @ViewBuilder
    private func freezeSheet() -> some View {
        if let date = missedDayCandidate {
            FreezeTokenSheet(
                targetDate: date,
                streakBefore: streak,
                streakAfter: streakIfFreezeCandidate,
                tokensInBank: freezeTokensInBank,
                onConfirm: { note in
                    let result = StreakFreezeManager.useToken(
                        for: date,
                        note: note,
                        context: context
                    )
                    showFreezeSheet = false
                    if result.isSuccess {
                        bannerDismissed = false
                        publishDayState()
                        NSSound(named: "Pop")?.play()
                    }
                },
                onCancel: { showFreezeSheet = false }
            )
        }
    }

    @ViewBuilder
    private func moodSheet() -> some View {
        MoodLogSheet(
            dayKey: DayLogic.dayKey(),
            dayNumber: dailyExercises.count,
            onSave: { mood, note in
                saveMood(mood, note: note)
                showMoodSheet = false
            },
            onSkip: {
                showMoodSheet = false
            }
        )
    }

    private func handleMinuteTick(_ now: Date) {
        today = now
        checkMilestoneUnlock()
    }

    private func handleAppear() {
        publishDayState()
        checkMilestoneUnlock()
        refreshFreezeEarnings(announce: false)

        if isRestDay { return }

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

        // If the day is sealed and mood isn't logged, offer it once.
        if isLockedToday && sworeToday && !hasMoodToday && !showMoodSheet {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if !hasMoodToday { showMoodSheet = true }
            }
        }
    }

    private func handleAllDoneChange(_ oldValue: Bool, _ newValue: Bool) {
        publishDayState()
        if isRestDay { return }
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
            #if DEBUG
            debugBar
            #endif
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

            if let mood = moodToday {
                MoodChip(mood: mood.mood, compact: true)
            }

            freezeTokenBadge
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

    private var freezeTokenBadge: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "snowflake")
                    .foregroundStyle(freezeTokensInBank > 0 ? Color(hex: "#118AB2") : Theme.textSecondary)
                Text("\(freezeTokensInBank)")
                    .font(.title2.bold().monospacedDigit())
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: freezeTokensInBank)
            }
            Text("freeze\(freezeTokensInBank == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    freezeTokensInBank > 0
                        ? Color(hex: "#118AB2").opacity(0.35)
                        : Theme.border,
                    lineWidth: 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .help("Freeze tokens protect your streak")
    }

    private var streakBadge: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(streak > 0 ? Theme.accentFill : Theme.textSecondary)
                Text("\(streak)")
                    .font(.title2.bold().monospacedDigit())
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: streak)
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

    #if DEBUG
    private var debugBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "ladybug.fill")
                .font(.caption)
                .foregroundStyle(Theme.warning)
            Text("DEBUG")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.warning)

            Divider().frame(height: 16)

            Button {
                debugCompleteAll()
            } label: {
                Label("Complete All", systemImage: "checkmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(exercises.isEmpty || (completedToday.count == exercises.count && sworeToday && isLockedToday))

            Button(role: .destructive) {
                showDebugUndoConfirmation = true
            } label: {
                Label("Undo All", systemImage: "arrow.uturn.backward.circle")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(completedToday.isEmpty && !sworeToday && !isLockedToday)

            Divider().frame(height: 16)

            Button {
                celebration = nil
                celebrationQueue.removeAll()
                enqueueCelebration(.day)
            } label: {
                Label("Test Day", systemImage: "sparkles")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Menu {
                Button("Test 30d (bronze)") {
                    fireTestMilestone(days: 30)
                }
                Button("Test 90d (silver)") {
                    fireTestMilestone(days: 90)
                }
                Button("Test 180d (gold)") {
                    fireTestMilestone(days: 180)
                }
                Button("Test 365d (legendary)") {
                    fireTestMilestone(days: 365)
                }
            } label: {
                Label("Test Milestone", systemImage: "trophy.fill")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 145)

            Button {
                showMoodSheet = true
            } label: {
                Label("Test Mood", systemImage: "face.smiling")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                FocusModeManager.shared.engage()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    FocusModeManager.shared.release()
                }
            } label: {
                Label("Test Focus", systemImage: "moon.stars.fill")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                let bank = StreakFreezeManager.tokensInBank
                UserDefaults.standard.set(min(bank + 1, StreakFreezeManager.maxTokens),
                                          forKey: PreferenceKeys.freezeTokensInBank)
            } label: {
                Label("+ Token", systemImage: "snowflake")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            Text(debugStatusText)
                .font(.caption2.monospaced())
                .foregroundStyle(Theme.textTertiary)

            Button {
                showManageExercises = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Manage exercises")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(Theme.warningSoft)
    }

    private var debugStatusText: String {
        let records = completedToday.count
        let total = exercises.count
        var bits: [String] = ["\(records)/\(total) done", "min \(minimumExercises)"]
        if sworeToday { bits.append("sworn") }
        if hasMoodToday { bits.append("mood") }
        if isLockedToday { bits.append("locked") }
        if isRestDay { bits.append("rest") }
        bits.append("❄\(StreakFreezeManager.tokensInBank)")
        return bits.joined(separator: " • ")
    }

    private func fireTestMilestone(days: Int) {
        // Insert a real Milestone so the sheet path works end-to-end.
        if !milestones.contains(where: { $0.day == days }) {
            context.insert(Milestone(day: days))
            try? context.save()
        }
        celebration = nil
        celebrationQueue.removeAll()
        pendingMilestoneCelebration = days
        enqueueCelebration(.day)
    }

    private func debugCompleteAll() {
        let key = DayLogic.dayKey()
        let existingIDs = Set(records.filter { $0.dayKey == key }.map(\.exerciseID))
        let now = Date()

        for exercise in exercises where !existingIDs.contains(exercise.id) {
            let start = now.addingTimeInterval(-Double(exercise.sessionDurationSeconds))
            let record = CompletionRecord(
                exerciseID: exercise.id,
                dayKey: key,
                startedAt: start,
                completedAt: now
            )
            context.insert(record)
        }

        do {
            try context.save()
        } catch {
            print("⚠️ debugCompleteAll save failed: \(error)")
        }

        publishDayState()
        checkMilestoneUnlock()
        refreshFreezeEarnings(announce: true)
    }

    private func debugUndoAll() {
        let key = DayLogic.dayKey()

        for record in records where record.dayKey == key {
            context.delete(record)
        }
        for swear in swears where swear.dayKey == key {
            context.delete(swear)
        }
        for lock in dayLocks where lock.dayKey == key {
            context.delete(lock)
        }
        for mood in moods where mood.dayKey == key {
            context.delete(mood)
        }

        do {
            try context.save()
        } catch {
            print("⚠️ debugUndoAll save failed: \(error)")
        }

        showDayCompletePrompt = false
        showSwearSheet = false
        showMoodSheet = false
        celebration = nil
        celebrationQueue.removeAll()
        pendingMilestoneCelebration = nil
        bannerDismissed = false
        moodPromptPending = false

        publishDayState()
    }
    #endif

    @ViewBuilder
    private var content: some View {
        if isRestDay {
            restDayState
        } else if exercises.isEmpty {
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
            if canOfferFreeze {
                freezeDangerBanner
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
                Text(hasMoodToday ? "Mood logged for today." : "Log how it felt to make recaps richer.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if !hasMoodToday {
                Button {
                    showMoodSheet = true
                } label: {
                    Label("Log Mood", systemImage: "face.smiling")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.successSoft)
    }

    private var freezeDangerBanner: some View {
        let missedDate = missedDayCandidate
        let restored = streakIfFreezeCandidate
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMM d"
        let missedLabel = missedDate.map { dateFormatter.string(from: $0) } ?? ""

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#118AB2").opacity(0.20))
                    .frame(width: 38, height: 38)
                Image(systemName: "snowflake")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(hex: "#118AB2"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Protect your \(restored)-day streak")
                    .font(.headline)
                Text("You missed \(missedLabel). Spend a freeze token?")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Button {
                showFreezeSheet = true
            } label: {
                Label("Use Token", systemImage: "snowflake")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(Color(hex: "#118AB2"))

            Button {
                bannerDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#118AB2").opacity(0.14),
                    Color(hex: "#06D6A0").opacity(0.10)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var restDayState: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.accentFill)
                    .padding(.top, 24)

                Text("Rest day").font(.largeTitle.bold())

                Text("\(restDayDescription) Recover, recharge — your streak is safe.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: 520)

                if streak > 0 {
                    Text("\(streak) day streak")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Theme.accentSoft)
                        .clipShape(Capsule())
                }

                Text("Next workout day: \(nextWorkoutDayLabel)")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)

                Divider()
                    .padding(.vertical, 8)
                    .frame(maxWidth: 520)

                RestDayRecoverySection(date: today)

                Button("Edit schedule") { PreferencesOpener.open() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
        }
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

            if let mood = moodToday {
                HStack(spacing: 8) {
                    Text("Today you felt:")
                        .font(.callout)
                        .foregroundStyle(Theme.textSecondary)
                    MoodChip(mood: mood.mood, compact: false)
                }
                .padding(.top, 4)
            } else {
                Button {
                    showMoodSheet = true
                } label: {
                    Label("Log today's mood", systemImage: "face.smiling")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 4)
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

            if isRestDay {
                Label("Rest day", systemImage: "moon.zzz.fill")
                    .foregroundStyle(Theme.textSecondary)
                    .font(.callout)
            } else if isLockedToday {
                Label("Locked until tomorrow", systemImage: "lock.fill")
                    .foregroundStyle(Theme.textSecondary)
                    .font(.callout)
            } else {
                Button { showCreateExercise = true } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
    }

    // MARK: - Mood

    private func saveMood(_ mood: WorkoutMood, note: String) {
        let key = DayLogic.dayKey()

        // Replace any existing mood for today.
        if let existing = moods.first(where: { $0.dayKey == key }) {
            context.delete(existing)
        }

        let entry = SessionMood(dayKey: key, mood: mood, note: note)
        context.insert(entry)
        do {
            try context.save()
            NSSound(named: "Pop")?.play()
        } catch {
            print("⚠️ saveMood failed: \(error)")
        }
    }

    // MARK: - Freeze helpers

    private func refreshFreezeEarnings(announce: Bool) {
        let completedDays = DayLogic.completedDayKeys(
            exercises: dailyExercises,
            records: records
        ).count

        let earned = StreakFreezeManager.refreshEarnings(completedDays: completedDays)
        if earned && announce {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                showTokenEarnedOverlay = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    showTokenEarnedOverlay = false
                }
            }
        }
    }

    // MARK: - Celebration orchestration

    private func enqueueCelebration(_ kind: CelebrationKind) {
        if celebration == nil {
            celebration = kind
        } else {
            celebrationQueue.append(kind)
        }
    }

    private func celebrationFinished() {
        let justFinished = celebration
        celebration = nil

        // Day → milestone chain.
        if case .day = justFinished, let target = pendingMilestoneCelebration {
            pendingMilestoneCelebration = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                celebration = .milestone(target)
            }
            return
        }

        // Milestone → reflection sheet, then mood prompt if still pending.
        if case .milestone = justFinished {
            if pendingMilestone != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showMilestoneUnlock = true
                }
            } else {
                playQueuedCelebration()
                maybeShowMood()
            }
            return
        }

        playQueuedCelebration()
        if celebration == nil {
            maybeShowMood()
        }
    }

    private func playQueuedCelebration() {
        guard !celebrationQueue.isEmpty else { return }
        let next = celebrationQueue.removeFirst()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            celebration = next
        }
    }

    private func maybeShowMood() {
        guard moodPromptPending, !hasMoodToday, !showMilestoneUnlock else { return }
        moodPromptPending = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !hasMoodToday { showMoodSheet = true }
        }
    }

    // MARK: - State

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
            refreshFreezeEarnings(announce: true)
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
        let streak = DayLogic.currentStreak(
            completedKeys: completed,
            frozenKeys: frozenKeys
        )
        let unlocked = Set(milestones.map(\.day))

        for target in stride(from: 30, through: max(streak, 30), by: 30)
        where streak >= target && !unlocked.contains(target) {
            let m = Milestone(day: target)
            context.insert(m)
            try? context.save()
            pendingMilestoneCelebration = target
            break
        }
    }
}

// MARK: - Freeze Token Sheet

struct FreezeTokenSheet: View {
    let targetDate: Date
    let streakBefore: Int
    let streakAfter: Int
    let tokensInBank: Int
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var note: String = ""
    @State private var appeared = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    var body: some View {
        VStack(spacing: 22) {
            iconHeader
            titleBlock
            impactCard
            if tokensInBank > 1 {
                inventoryNote
            }
            noteField
            actionsRow
        }
        .padding(28)
        .frame(width: 480)
        .background(Theme.surfaceBase)
        .scaleEffect(appeared ? 1 : 0.94)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    private var iconHeader: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#118AB2").opacity(0.18))
                .frame(width: 130, height: 130)
                .blur(radius: 22)

            Circle()
                .fill(Theme.surfaceElevated)
                .frame(width: 96, height: 96)
                .overlay(Circle().stroke(Theme.border, lineWidth: 0.5))

            Image(systemName: "snowflake")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#118AB2"), Color(hex: "#06D6A0")],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .rotationEffect(.degrees(appeared ? 0 : -90))
                .animation(.spring(response: 0.7, dampingFraction: 0.6), value: appeared)
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text("Protect your streak")
                .font(.title2.bold())
            Text("Spend a freeze token to make **\(Self.dateFormatter.string(from: targetDate))** not count against you.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var impactCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("BEFORE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.textTertiary)
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Theme.textSecondary)
                        .font(.caption)
                    Text("\(streakBefore)")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)

            VStack(alignment: .leading, spacing: 3) {
                Text("AFTER")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.textTertiary)
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Theme.accentFill)
                        .font(.caption)
                    Text("\(streakAfter)")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(Theme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(hex: "#118AB2").opacity(0.30), lineWidth: 0.5)
        )
    }

    private var inventoryNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "snowflake")
                .font(.caption)
                .foregroundStyle(Color(hex: "#118AB2"))
            Text("You have \(tokensInBank) tokens. One will remain after this.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(hex: "#118AB2").opacity(0.10))
        )
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Note (optional)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.4)
            TextField("Why did you miss this day?", text: $note)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 10) {
            Button("Cancel") { onCancel() }
                .keyboardShortcut(.cancelAction)

            Spacer()

            Button {
                onConfirm(note)
            } label: {
                Label("Use Token", systemImage: "snowflake")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(tokensInBank <= 0)
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
