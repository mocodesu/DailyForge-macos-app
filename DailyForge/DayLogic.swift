import Foundation

enum DayLogic {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar.current
        f.timeZone = Calendar.current.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Stable calendar-day key for a given date.
    static func dayKey(_ date: Date = Date()) -> String {
        formatter.string(from: Calendar.current.startOfDay(for: date))
    }

    // MARK: - Exercise filtering

    /// Exercises that should be shown on the given day.
    /// Daily exercises always appear. Non-daily exercises appear only on
    /// the calendar day they were created.
    static func activeExercises(from all: [Exercise], on date: Date = Date()) -> [Exercise] {
        all.filter { exercise in
            if exercise.isDaily { return true }
            return Calendar.current.isDate(exercise.createdAt, inSameDayAs: date)
        }
    }

    /// Only the daily-repeating exercises — used for streak math so that
    /// one-off exercises don't inflate the streak.
    static func dailyExercises(from all: [Exercise]) -> [Exercise] {
        all.filter { $0.isDaily }
    }

    // MARK: - Today's progress

    /// Every exercise shown today has a completion record for today.
    static func allCompletedToday(exercises: [Exercise], records: [CompletionRecord]) -> Bool {
        guard !exercises.isEmpty else { return false }
        let key = dayKey()
        let completedIDs = Set(records.filter { $0.dayKey == key }.map(\.exerciseID))
        return exercises.allSatisfy { completedIDs.contains($0.id) }
    }

    /// "5 of 6 done" style progress for today.
    static func progressToday(exercises: [Exercise], records: [CompletionRecord]) -> (done: Int, total: Int) {
        guard !exercises.isEmpty else { return (0, 0) }
        let key = dayKey()
        let completedIDs = Set(records.filter { $0.dayKey == key }.map(\.exerciseID))
        let done = exercises.filter { completedIDs.contains($0.id) }.count
        return (done, exercises.count)
    }

    // MARK: - History and streak

    /// Set of day keys where EVERY given exercise was completed.
    /// Pass only daily exercises to get a streak-consistent view.
    static func completedDayKeys(exercises: [Exercise], records: [CompletionRecord]) -> Set<String> {
        guard !exercises.isEmpty else { return [] }
        let exerciseIDs = Set(exercises.map(\.id))
        let filtered = records.filter { exerciseIDs.contains($0.exerciseID) }
        let grouped = Dictionary(grouping: filtered, by: \.dayKey)
        var complete: Set<String> = []
        for (key, recs) in grouped {
            let ids = Set(recs.map(\.exerciseID))
            if exerciseIDs.isSubset(of: ids) {
                complete.insert(key)
            }
        }
        return complete
    }

    /// Consecutive days ending today (or yesterday if today isn't complete yet).
    static func currentStreak(completedKeys: Set<String>) -> Int {
        var streak = 0
        var cursor = Calendar.current.startOfDay(for: Date())
        if !completedKeys.contains(dayKey(cursor)) {
            guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        while completedKeys.contains(dayKey(cursor)) {
            streak += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}
