import SwiftUI
import SwiftData
import AppKit

// MARK: - Sheet routing

private enum HistorySheet: Identifiable {
    case day(DayProgress)
    case week(WeekProgress)

    var id: String {
        switch self {
        case .day(let d):  return "day-\(d.id)"
        case .week(let w): return "week-\(w.id)"
        }
    }
}

// MARK: - History View

struct HistoryView: View {
    let exercises: [Exercise]
    let records: [CompletionRecord]

    @Environment(\.dismiss) private var dismiss

    @State private var sheet: HistorySheet?

    private let daysToShow = 30

    // MARK: Schedule config

    private var restDays: Set<Int> {
        let raw = UserDefaults.standard.string(forKey: PreferenceKeys.restDaysRaw)
            ?? Preferences.defaultRestDaysRaw
        let parsed = raw
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { (1...7).contains($0) }
        return Set(parsed.prefix(Preferences.maxRestDays))
    }

    private var targetDaysPerWeek: Int {
        max(1, 7 - restDays.count)
    }

    // MARK: Days

    private var days: [DayProgress] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [DayProgress] = []

        for offset in 0..<daysToShow {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            result.append(progress(for: date))
        }
        return result
    }

    private func progress(for date: Date) -> DayProgress {
        let key = DayLogic.dayKey(date)
        let due = DayLogic.activeExercises(from: exercises, on: date)
        let completedThatDay = Set(records.filter { $0.dayKey == key }.map(\.exerciseID))
        let done = due.filter { completedThatDay.contains($0.id) }.count

        return DayProgress(
            id: key,
            date: date,
            completed: done,
            total: due.count,
            isToday: Calendar.current.isDateInToday(date)
        )
    }

    // MARK: Weeks

    private var currentWeekStart: Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let anchor = calendar.date(from: comps) ?? Date()
        return calendar.startOfDay(for: anchor)
    }

    private var currentWeek: WeekProgress {
        weekProgress(startingOn: currentWeekStart)
    }

    private var lastWeek: WeekProgress? {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) else {
            return nil
        }
        return weekProgress(startingOn: start)
    }

    private func weekProgress(startingOn weekStart: Date) -> WeekProgress {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var daysCompleted = 0
        var targetDays = 0
        var workSeconds: TimeInterval = 0

        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
            let dateStart = calendar.startOfDay(for: date)

            if DayLogic.isRestDay(date) { continue }
            targetDays += 1
            guard dateStart <= today else { continue }

            let key = DayLogic.dayKey(date)
            let due = DayLogic.activeExercises(from: exercises, on: date)
            guard !due.isEmpty else { continue }

            let completedThatDay = Set(records.filter { $0.dayKey == key }.map(\.exerciseID))
            let allDone = due.allSatisfy { completedThatDay.contains($0.id) }

            if allDone {
                daysCompleted += 1
                for record in records where record.dayKey == key {
                    if let start = record.startedAt {
                        workSeconds += record.completedAt.timeIntervalSince(start)
                    }
                }
            }
        }

        let endDate = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart

        return WeekProgress(
            id: DayLogic.dayKey(weekStart),
            startDate: weekStart,
            endDate: endDate,
            daysCompleted: daysCompleted,
            targetDays: max(targetDays, 1),
            workSeconds: workSeconds
        )
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 760, height: 760)
        .background(Theme.surfaceBase)
        .sheet(item: $sheet) { which in
            switch which {
            case .day(let day):
                DayDetailView(day: day, exercises: exercises, records: records)
            case .week(let week):
                WeekDetailSheet(
                    week: week,
                    exercises: exercises,
                    records: records
                )
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text("History")
                    .font(.title.bold())
                Text("Last \(daysToShow) days")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            weeklyProgressRing

            Button("Close") { dismiss() }
        }
        .padding(20)
    }

    private var weeklyProgressRing: some View {
        let week = currentWeek
        let progress = week.progress
        let done = week.daysCompleted
        let target = week.targetDays

        return HStack(spacing: 14) {
            VStack(alignment: .trailing, spacing: 2) {
                Text("This Week")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text("\(done) of \(target) days")
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
            }

            ZStack {
                Circle()
                    .stroke(Theme.surfaceSunken, lineWidth: 6)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.accentFill, Theme.accentWarm],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7, dampingFraction: 0.75), value: progress)

                Text("\(Int(round(progress * 100)))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
            }
            .frame(width: 64, height: 64)
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if exercises.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.textSecondary)
                Text("No history yet")
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    lastWeekRecapSection
                    dailyGridSection
                }
                .padding(24)
            }
        }
    }

    // MARK: Last Week Recap

    @ViewBuilder
    private var lastWeekRecapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Weekly recap")
                    .font(.headline)
                Spacer()
                Text("Last week")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            if let week = lastWeek {
                Button {
                    sheet = .week(week)
                } label: {
                    LastWeekRecapCard(week: week)
                }
                .buttonStyle(.plain)
            } else {
                Text("No data available for last week.")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 8)
            }
        }
    }

    // MARK: Daily Grid

    private var dailyGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily breakdown")
                    .font(.headline)
                Spacer()
                Text("Tap a circle for details")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96, maximum: 120), spacing: 20)],
                spacing: 22
            ) {
                ForEach(days) { day in
                    DayCircle(day: day)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if day.total > 0 { sheet = .day(day) }
                        }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.border, lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Last Week Recap Card

private struct LastWeekRecapCard: View {
    let week: WeekProgress

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 18) {
            ring

            VStack(alignment: .leading, spacing: 5) {
                Text(week.dateRange)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 12) {
                    metric(
                        icon: "checkmark.seal.fill",
                        text: "\(week.daysCompleted) of \(week.targetDays) days",
                        tint: week.tint
                    )
                    metric(
                        icon: "clock.fill",
                        text: week.workSeconds > 0 ? week.workTimeLabel : "—",
                        tint: Theme.accent
                    )
                }
            }

            Spacer()

            VStack(spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                Text("Details")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.border, lineWidth: 0.5)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceSunken, lineWidth: 7)

            Circle()
                .trim(from: 0, to: week.progress)
                .stroke(
                    week.tint,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.75), value: week.progress)

            VStack(spacing: 0) {
                Text("\(Int(round(week.progress * 100)))")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text("%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .offset(y: -1)
            }
        }
        .frame(width: 68, height: 68)
    }

    private func metric(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

// MARK: - Week Detail Sheet

struct WeekDetailSheet: View {
    let week: WeekProgress
    let exercises: [Exercise]
    let records: [CompletionRecord]

    @Environment(\.dismiss) private var dismiss

    private var calendar: Calendar { Calendar.current }

    // MARK: Computed Data

    private var dayInfos: [WeekDayInfo] {
        var result: [WeekDayInfo] = []
        let today = calendar.startOfDay(for: Date())

        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: week.startDate) else { continue }
            let dateStart = calendar.startOfDay(for: date)
            let isRest = DayLogic.isRestDay(date)
            let isFuture = dateStart > today
            let key = DayLogic.dayKey(date)

            let due = DayLogic.activeExercises(from: exercises, on: date)
            let dayRecords = records.filter { $0.dayKey == key }
            let completedIDs = Set(dayRecords.map(\.exerciseID))
            let completedCount = due.filter { completedIDs.contains($0.id) }.count

            var workSeconds: TimeInterval = 0
            for r in dayRecords {
                if let s = r.startedAt {
                    workSeconds += r.completedAt.timeIntervalSince(s)
                }
            }

            result.append(WeekDayInfo(
                id: key,
                date: date,
                weekday: calendar.component(.weekday, from: date),
                isRestDay: isRest,
                isFuture: isFuture,
                isToday: calendar.isDateInToday(date),
                dueCount: due.count,
                completedCount: completedCount,
                workSeconds: workSeconds,
                records: dayRecords
            ))
        }
        return result
    }

    private var exerciseStats: [WeekExerciseStat] {
        let startKey = DayLogic.dayKey(week.startDate)
        let endKey = DayLogic.dayKey(week.endDate)

        let weekRecords = records.filter { $0.dayKey >= startKey && $0.dayKey <= endKey }
        let grouped = Dictionary(grouping: weekRecords, by: \.exerciseID)
        let lookup = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

        return grouped.compactMap { (id, recs) -> WeekExerciseStat? in
            guard let ex = lookup[id] else { return nil }
            var totalTime: TimeInterval = 0
            var timedCount = 0
            for r in recs {
                if let s = r.startedAt {
                    totalTime += r.completedAt.timeIntervalSince(s)
                    timedCount += 1
                }
            }
            let avg = timedCount > 0 ? totalTime / Double(timedCount) : 0
            return WeekExerciseStat(
                id: id,
                name: ex.name,
                bodyParts: ex.bodyParts,
                exerciseType: ex.exerciseType,
                timesCompleted: recs.count,
                totalWorkSeconds: totalTime,
                avgWorkSeconds: avg
            )
        }
        .sorted { lhs, rhs in
            if lhs.timesCompleted != rhs.timesCompleted {
                return lhs.timesCompleted > rhs.timesCompleted
            }
            return lhs.totalWorkSeconds > rhs.totalWorkSeconds
        }
    }

    private var totals: WeekTotals {
        let nonRestDays = dayInfos.filter { !$0.isRestDay }
        let targetDays = nonRestDays.count
        let completedDays = nonRestDays.filter { $0.isComplete }.count
        let workSeconds = dayInfos.reduce(0) { $0 + $1.workSeconds }
        let totalCompletions = dayInfos.reduce(0) { $0 + $1.records.count }
        let avgSession = completedDays > 0 ? workSeconds / Double(completedDays) : 0
        let bestDay = nonRestDays
            .filter { $0.isComplete }
            .max(by: { $0.workSeconds < $1.workSeconds })
        let missedDays = nonRestDays.filter { !$0.isComplete && !$0.isFuture && $0.dueCount > 0 }.count

        return WeekTotals(
            daysCompleted: completedDays,
            targetDays: targetDays,
            workSeconds: workSeconds,
            totalCompletions: totalCompletions,
            avgSessionSeconds: avgSession,
            restDaysInWeek: dayInfos.filter(\.isRestDay).count,
            bestDay: bestDay,
            missedDays: missedDays
        )
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    statsGrid
                    dailyBreakdownSection
                    if !exerciseStats.isEmpty {
                        exercisePerformanceSection
                    }
                    highlightsSection
                }
                .padding(24)
            }
        }
        .frame(width: 720, height: 780)
        .background(Theme.surfaceBase)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Week of \(week.dateRange)")
                    .font(.title2.bold())
                Text("A detailed look at your last workout week.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button("Close") { dismiss() }
        }
        .padding(20)
    }

    // MARK: Hero

    private var heroSection: some View {
        HStack(spacing: 22) {
            bigRing

            VStack(alignment: .leading, spacing: 6) {
                Text(totals.daysCompleted == totals.targetDays
                     ? "Perfect week!"
                     : "\(totals.missedDays) missed day\(totals.missedDays == 1 ? "" : "s")")
                    .font(.title3.bold())
                    .foregroundStyle(totals.daysCompleted == totals.targetDays ? Theme.success : Theme.textPrimary)

                Text("\(totals.daysCompleted) of \(totals.targetDays) workout days completed")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)

                Text(week.dateRange)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 2)
            }

            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    totals.daysCompleted == totals.targetDays
                        ? Theme.success.opacity(0.35)
                        : Theme.border,
                    lineWidth: totals.daysCompleted == totals.targetDays ? 1 : 0.5
                )
        )
    }

    private var bigRing: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceSunken, lineWidth: 11)

            Circle()
                .trim(from: 0, to: week.progress)
                .stroke(
                    LinearGradient(
                        colors: [week.tint, week.tint.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.7, dampingFraction: 0.75), value: week.progress)

            VStack(spacing: 1) {
                Text("\(Int(round(week.progress * 100)))%")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text("complete")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: 116, height: 116)
    }

    // MARK: Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statTile(
                icon: "clock.fill",
                title: "Work time",
                value: totals.workSeconds > 0 ? formatLongDuration(totals.workSeconds) : "—",
                tint: Theme.accent
            )
            statTile(
                icon: "flame.fill",
                title: "Exercises done",
                value: "\(totals.totalCompletions)",
                tint: Theme.accentFill
            )
            statTile(
                icon: "timer",
                title: "Avg session",
                value: totals.avgSessionSeconds > 0 ? formatLongDuration(totals.avgSessionSeconds) : "—",
                tint: Theme.success
            )
            statTile(
                icon: "moon.zzz.fill",
                title: "Rest days",
                value: "\(totals.restDaysInWeek)",
                tint: Theme.textSecondary
            )
        }
    }

    private func statTile(icon: String, title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.border, lineWidth: 0.5)
        )
    }

    // MARK: Daily Breakdown

    private var dailyBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily breakdown").font(.headline)
                Spacer()
                Text("Mon → Sun")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }

            HStack(spacing: 8) {
                ForEach(dayInfos) { day in
                    WeekDayTile(day: day)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.border, lineWidth: 0.5)
            )
        }
    }

    // MARK: Exercise Performance

    private var exercisePerformanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exercise performance").font(.headline)
                Spacer()
                Text("\(exerciseStats.count) exercise\(exerciseStats.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }

            VStack(spacing: 8) {
                ForEach(exerciseStats) { stat in
                    WeekExerciseRow(stat: stat, maxPossible: totals.targetDays)
                }
            }
        }
    }

    // MARK: Highlights

    private var highlightsSection: some View {
        let insights = buildInsights()
        return VStack(alignment: .leading, spacing: 12) {
            if !insights.isEmpty {
                Text("Highlights").font(.headline)
                VStack(spacing: 8) {
                    ForEach(insights) { insight in
                        InsightRow(insight: insight)
                    }
                }
            }
        }
    }

    private func buildInsights() -> [WeekInsight] {
        var items: [WeekInsight] = []

        if totals.daysCompleted == totals.targetDays && totals.targetDays > 0 {
            items.append(WeekInsight(
                icon: "trophy.fill",
                tint: Color(hex: "#FFD700"),
                title: "Perfect week",
                body: "You completed every scheduled workout day. Consistency is compounding."
            ))
        } else if totals.missedDays > 0 {
            items.append(WeekInsight(
                icon: "exclamationmark.triangle.fill",
                tint: Theme.warning,
                title: "\(totals.missedDays) missed day\(totals.missedDays == 1 ? "" : "s")",
                body: "One missed day is noise. Two is a pattern — aim for a clean week ahead."
            ))
        }

        if let best = totals.bestDay, best.workSeconds > 60 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            let dayName = formatter.string(from: best.date)
            items.append(WeekInsight(
                icon: "bolt.fill",
                tint: Theme.accentFill,
                title: "Strongest day: \(dayName)",
                body: "You logged \(formatLongDuration(best.workSeconds)) across \(best.records.count) exercise\(best.records.count == 1 ? "" : "s") on your best day."
            ))
        }

        if let top = exerciseStats.first, top.timesCompleted >= 2 {
            items.append(WeekInsight(
                icon: "repeat",
                tint: Theme.success,
                title: "Most performed: \(top.name)",
                body: "You did this \(top.timesCompleted)× this week, totaling \(top.totalWorkSeconds > 0 ? formatLongDuration(top.totalWorkSeconds) : "—")."
            ))
        }

        if totals.workSeconds > 0 {
            items.append(WeekInsight(
                icon: "flame.fill",
                tint: Theme.accentDeep,
                title: "\(formatLongDuration(totals.workSeconds)) of work",
                body: "Across the week you invested \(totals.totalCompletions) exercise completions — that's \(formatLongDuration(totals.avgSessionSeconds)) on a typical day."
            ))
        }

        return items
    }
}

// MARK: - Week Models

struct WeekProgress: Identifiable {
    let id: String
    let startDate: Date
    let endDate: Date
    let daysCompleted: Int
    let targetDays: Int
    let workSeconds: TimeInterval

    var progress: Double {
        guard targetDays > 0 else { return 0 }
        return min(1.0, Double(daysCompleted) / Double(targetDays))
    }

    var dateRange: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: startDate)) – \(f.string(from: endDate))"
    }

    var workTimeLabel: String {
        workSeconds > 0 ? formatLongDuration(workSeconds) : "—"
    }

    var tint: Color {
        guard targetDays > 0 else { return Theme.textTertiary }
        if progress >= 1.0 { return Theme.success }
        if progress >= 0.6 { return Theme.warning }
        if progress > 0 { return Theme.accentFill }
        return Theme.accentDeep.opacity(0.75)
    }
}

struct WeekDayInfo: Identifiable {
    let id: String
    let date: Date
    let weekday: Int
    let isRestDay: Bool
    let isFuture: Bool
    let isToday: Bool
    let dueCount: Int
    let completedCount: Int
    let workSeconds: TimeInterval
    let records: [CompletionRecord]

    var isComplete: Bool {
        !isRestDay && !isFuture && dueCount > 0 && completedCount == dueCount
    }

    var progress: Double {
        guard dueCount > 0 else { return 0 }
        return min(1.0, Double(completedCount) / Double(dueCount))
    }

    var weekdayLetter: String {
        WeekdayNames.letters[weekday - 1]
    }

    var weekdayShort: String {
        WeekdayNames.short[weekday - 1]
    }

    var dayNumber: String {
        let c = Calendar.current.dateComponents([.day], from: date)
        return "\(c.day ?? 0)"
    }
}

struct WeekExerciseStat: Identifiable {
    let id: UUID
    let name: String
    let bodyParts: [String]
    let exerciseType: ExerciseType
    let timesCompleted: Int
    let totalWorkSeconds: TimeInterval
    let avgWorkSeconds: TimeInterval
}

struct WeekTotals {
    let daysCompleted: Int
    let targetDays: Int
    let workSeconds: TimeInterval
    let totalCompletions: Int
    let avgSessionSeconds: TimeInterval
    let restDaysInWeek: Int
    let bestDay: WeekDayInfo?
    let missedDays: Int
}

struct WeekInsight: Identifiable {
    let id = UUID()
    let icon: String
    let tint: Color
    let title: String
    let body: String
}

// MARK: - Week Day Tile

private struct WeekDayTile: View {
    let day: WeekDayInfo

    var body: some View {
        VStack(spacing: 8) {
            Text(day.weekdayLetter)
                .font(.caption.weight(.semibold))
                .foregroundStyle(day.isToday ? Theme.accentFill : Theme.textSecondary)
                .tracking(0.4)

            ZStack {
                Circle()
                    .stroke(Theme.surfaceSunken, lineWidth: 4)

                if day.isRestDay {
                    Circle()
                        .fill(Theme.surfaceSunken)
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                } else if day.isFuture {
                    Circle()
                        .stroke(
                            Theme.border,
                            style: StrokeStyle(lineWidth: 4, dash: [3, 3])
                        )
                    Text(day.dayNumber)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                } else if day.isComplete {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.success, Theme.success.opacity(0.85)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    if day.progress > 0 {
                        Circle()
                            .trim(from: 0, to: day.progress)
                            .stroke(
                                Theme.warning,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    Text(day.dayNumber)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .frame(width: 42, height: 42)

            VStack(spacing: 1) {
                if day.isRestDay {
                    Text("rest")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                } else if day.isFuture {
                    Text("—")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textTertiary)
                } else if day.workSeconds > 0 {
                    Text(formatLongDuration(day.workSeconds))
                        .font(.system(size: 9, weight: .semibold).monospacedDigit())
                        .foregroundStyle(day.isComplete ? Theme.success : Theme.warning)
                } else if day.dueCount > 0 && day.completedCount > 0 {
                    Text("\(day.completedCount)/\(day.dueCount)")
                        .font(.system(size: 9, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Theme.warning)
                } else if day.dueCount > 0 {
                    Text("missed")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                } else {
                    Text("—")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Week Exercise Row

private struct WeekExerciseRow: View {
    let stat: WeekExerciseStat
    let maxPossible: Int

    private var ratio: Double {
        guard maxPossible > 0 else { return 0 }
        return min(1.0, Double(stat.timesCompleted) / Double(maxPossible))
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.accentFill.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: WorkoutIcons.icon(forType: stat.exerciseType))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accentFill)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(stat.name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(stat.bodyParts.joined(separator: " • "))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            miniRing

            Text("\(stat.timesCompleted)/\(maxPossible)")
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, alignment: .trailing)

            Text(stat.totalWorkSeconds > 0 ? formatLongDuration(stat.totalWorkSeconds) : "—")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 72, alignment: .trailing)
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
    }

    private var miniRing: some View {
        let color: Color = ratio >= 1.0 ? Theme.success : (ratio >= 0.6 ? Theme.warning : Theme.accentFill)
        return ZStack {
            Circle()
                .stroke(Theme.surfaceSunken, lineWidth: 4)
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(round(ratio * 100)))%")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(width: 36, height: 36)
    }
}

// MARK: - Insight Row

private struct InsightRow: View {
    let insight: WeekInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(insight.tint.opacity(0.16))
                    .frame(width: 34, height: 34)
                Image(systemName: insight.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(insight.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(insight.body)
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
    }
}

// MARK: - Day Progress Model

struct DayProgress: Identifiable {
    let id: String
    let date: Date
    let completed: Int
    let total: Int
    let isToday: Bool

    var progress: Double {
        guard total > 0 else { return 0 }
        return min(1.0, Double(completed) / Double(total))
    }

    var dayNumber: String {
        let comps = Calendar.current.dateComponents([.day], from: date)
        return "\(comps.day ?? 0)"
    }

    var percentText: String {
        guard total > 0 else { return "—" }
        return "\(Int(round(progress * 100)))%"
    }

    var countText: String {
        guard total > 0 else { return "rest" }
        return "\(completed) of \(total)"
    }
}

// MARK: - Day Circle

struct DayCircle: View {
    let day: DayProgress

    var body: some View {
        VStack(spacing: 8) {
            ringView
            VStack(spacing: 1) {
                Text(day.percentText)
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                Text(day.countText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var ringView: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceSunken, lineWidth: 6)

            Circle()
                .trim(from: 0, to: day.progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: day.progress)

            Text(day.dayNumber)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(day.isToday ? Theme.accentFill : Theme.textPrimary)
        }
        .frame(width: 68, height: 68)
        .overlay(alignment: .topTrailing) {
            if day.isToday {
                Circle()
                    .fill(Theme.accentFill)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Theme.surfaceBase, lineWidth: 2)
                    )
                    .offset(x: 2, y: -2)
            }
        }
    }

    private var ringColor: Color {
        guard day.total > 0 else { return Theme.textTertiary.opacity(0.35) }
        if day.progress >= 1.0 { return Theme.success }
        if day.progress >= 0.6 { return Theme.warning }
        if day.progress > 0 { return Theme.accentFill }
        return Theme.accentDeep.opacity(0.75)
    }
}

// MARK: - Day Detail

struct DayDetailView: View {
    let day: DayProgress
    let exercises: [Exercise]
    let records: [CompletionRecord]

    @Environment(\.dismiss) private var dismiss

    private var dayRecords: [CompletionRecord] {
        records
            .filter { $0.dayKey == day.id }
            .sorted { $0.completedAt < $1.completedAt }
    }

    private var exerciseLookup: [UUID: Exercise] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    private var firstStart: Date? {
        let starts = dayRecords.compactMap(\.startedAt)
        if let earliest = starts.min() { return earliest }
        return dayRecords.first?.completedAt
    }

    private var lastCompletion: Date? {
        dayRecords.map(\.completedAt).max()
    }

    private var totalWallClock: TimeInterval? {
        guard let start = firstStart, let end = lastCompletion else { return nil }
        return end.timeIntervalSince(start)
    }

    private var totalWorkTime: TimeInterval {
        dayRecords.reduce(0) { sum, record in
            guard let start = record.startedAt else { return sum }
            return sum + record.completedAt.timeIntervalSince(start)
        }
    }

    private var totalBreakTime: TimeInterval {
        max(0, (totalWallClock ?? 0) - totalWorkTime)
    }

    private var hasStartTimes: Bool {
        dayRecords.contains { $0.startedAt != nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    summarySection
                    timelineSection
                }
                .padding(24)
            }
        }
        .frame(width: 640, height: 680)
        .background(Theme.surfaceBase)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(.title2.bold())
                Text(day.total > 0 ? "\(day.completed) of \(day.total) completed" : "No exercises scheduled")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button("Close") { dismiss() }
        }
        .padding(20)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session summary").font(.headline)

            HStack(spacing: 12) {
                summaryCard(
                    title: "Total time",
                    value: totalWallClock.map(formatLongDuration) ?? "—",
                    subtitle: hasStartTimes ? "first start → last done" : "no start times recorded",
                    tint: Theme.accent
                )
                summaryCard(
                    title: "Work time",
                    value: formatLongDuration(totalWorkTime),
                    subtitle: "sum of active sessions",
                    tint: Theme.success
                )
                summaryCard(
                    title: "Break time",
                    value: hasStartTimes ? formatLongDuration(totalBreakTime) : "—",
                    subtitle: "time between exercises",
                    tint: Theme.warning
                )
            }

            if hasStartTimes {
                HStack(spacing: 20) {
                    timePill(label: "Started", date: firstStart)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(Theme.textTertiary)
                    timePill(label: "Finished", date: lastCompletion)
                }
                .padding(.top, 4)
            }
        }
    }

    private func summaryCard(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(tint)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Theme.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func timePill(label: String, date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(Theme.textSecondary)
            Text(date.map { $0.formatted(date: .omitted, time: .shortened) } ?? "—")
                .font(.callout.weight(.medium).monospacedDigit())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Per-exercise breakdown").font(.headline)

            if dayRecords.isEmpty {
                Text("No exercises were completed on this day.")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(dayRecords.enumerated()), id: \.element.id) { index, record in
                        recordRow(index: index + 1, record: record)
                    }
                }
            }
        }
    }

    private func recordRow(index: Int, record: CompletionRecord) -> some View {
        let exercise = exerciseLookup[record.exerciseID]
        let duration = record.startedAt.map { record.completedAt.timeIntervalSince($0) }

        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.successSoft)
                    .frame(width: 28, height: 28)
                Text("\(index)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(Theme.success)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(exercise?.name ?? "Deleted exercise")
                        .font(.body.weight(.medium))
                    if let exercise = exercise, !exercise.isDaily {
                        Text("ONE-OFF")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Theme.warningSoft)
                            .foregroundStyle(Theme.warning)
                            .clipShape(Capsule())
                    }
                }

                if let start = record.startedAt {
                    Text("Started \(start.formatted(date: .omitted, time: .shortened)) → Done \(record.completedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text("Completed \(record.completedAt.formatted(date: .omitted, time: .shortened)) (no start time)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            Spacer()

            if let duration = duration {
                Text(formatLongDuration(duration))
                    .font(.callout.bold().monospacedDigit())
                    .foregroundStyle(Theme.accent)
            } else {
                Text("—")
                    .font(.callout.bold().monospacedDigit())
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(12)
        .background(Theme.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Theme.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Duration formatting

func formatLongDuration(_ interval: TimeInterval) -> String {
    let total = Int(interval.rounded())
    if total < 60 { return "\(total)s" }
    if total < 3600 {
        let m = total / 60
        let s = total % 60
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }
    let h = total / 3600
    let m = (total % 3600) / 60
    return m == 0 ? "\(h)h" : "\(h)h \(m)m"
}
