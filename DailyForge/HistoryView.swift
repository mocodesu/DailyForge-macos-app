import SwiftUI
import SwiftData
import AppKit

struct HistoryView: View {
    let exercises: [Exercise]
    let records: [CompletionRecord]

    @Environment(\.dismiss) private var dismiss

    /// How many days back to display, starting from today.
    private let daysToShow = 30

    // MARK: - Days

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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 720, height: 660)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("History").font(.title.bold())
                Text("Last \(daysToShow) days — today at the top")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var content: some View {
        if exercises.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("No history yet")
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.primary)
                Text(day.countText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var ringView: some View {
        ZStack {
            // Faint background ring
            Circle()
                .stroke(Color.secondary.opacity(0.12), lineWidth: 6)

            // Filled progress arc
            Circle()
                .trim(from: 0, to: day.progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: day.progress)

            // Date number centered inside the ring
            Text(day.dayNumber)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(day.isToday ? Color.accentColor : .primary)
        }
        .frame(width: 68, height: 68)
        .overlay(alignment: .topTrailing) {
            if day.isToday {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color(nsColor: .controlBackgroundColor), lineWidth: 2)
                    )
                    .offset(x: 2, y: -2)
            }
        }
    }

    private var ringColor: Color {
        guard day.total > 0 else { return .secondary.opacity(0.35) }
        if day.progress >= 1.0 { return .green }
        if day.progress >= 0.6 { return .yellow }
        if day.progress > 0 { return .orange }
        return .red.opacity(0.75)
    }
}
