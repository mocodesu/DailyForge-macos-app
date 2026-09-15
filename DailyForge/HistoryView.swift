import SwiftUI
import SwiftData

struct HistoryView: View {
    let exercises: [Exercise]
    let records: [CompletionRecord]

    @Environment(\.dismiss) private var dismiss

    private var completedDays: [(key: String, date: Date, done: Int, total: Int)] {
        let exerciseIDs = Set(exercises.map(\.id))
        let filtered = records.filter { exerciseIDs.contains($0.exerciseID) }
        let grouped = Dictionary(grouping: filtered, by: \.dayKey)
        return grouped.compactMap { key, recs in
            guard let date = DayLogic.formatter.date(from: key) else { return nil }
            return (key, date, recs.count, exercises.count)
        }
        .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("History").font(.title.bold())
                Spacer()
                Button("Close") { dismiss() }
            }
            .padding(20)

            Divider()

            if completedDays.isEmpty {
                VStack {
                    Text("No history yet.").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(completedDays, id: \.key) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.date.formatted(date: .complete, time: .omitted))
                                .font(.body.weight(.medium))
                            Text("\(entry.done) of \(entry.total) exercises")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if entry.done == entry.total {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("\(Int(Double(entry.done) / Double(max(entry.total, 1)) * 100))%")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 520, height: 560)
    }
}
