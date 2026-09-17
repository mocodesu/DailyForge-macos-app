import SwiftUI
import SwiftData
import AppKit

struct HistoryView: View {
    let exercises: [Exercise]
    let records: [CompletionRecord]

    @Environment(\.dismiss) private var dismiss

    @State private var selectedDay: DayProgress?

    private let daysToShow = 30

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

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 720, height: 660)
        .background(Theme.surfaceBase)
        .sheet(item: $selectedDay) { day in
            DayDetailView(day: day, exercises: exercises, records: records)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("History").font(.title.bold())
                Text("Last \(daysToShow) days — tap a circle for details")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            summaryBadge
            Button("Close") { dismiss() }
        }
        .padding(20)
    }

    private var summaryBadge: some View {
        let complete = days.filter { $0.total > 0 && $0.progress >= 1.0 }.count
        let attempted = days.filter { $0.total > 0 }.count
        return VStack(spacing: 2) {
            Text("\(complete)/\(attempted)")
                .font(.title3.bold().monospacedDigit())
            Text("days complete")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
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
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 96, maximum: 120), spacing: 20)],
                    spacing: 22
                ) {
                    ForEach(days) { day in
                        DayCircle(day: day)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if day.total > 0 { selectedDay = day }
                            }
                    }
                }
                .padding(24)
            }
        }
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
