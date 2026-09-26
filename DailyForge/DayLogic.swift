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

    // MARK: - Rest days

    /// Thursdays and Fridays are rest days. No exercises are required,
    /// the streak is not broken, and enforcement stays quiet.
    ///
    /// Gregorian weekday numbering: Sunday = 1, Monday = 2, … Thursday = 5,
    /// Friday = 6, Saturday = 7.
    static func isRestDay(_ date: Date = Date()) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 5 || weekday == 6
    }

    // MARK: - Exercise filtering

    /// Exercises that should be shown on the given day.
    /// Daily exercises always appear. Non-daily exercises appear only on
    /// the calendar day they were created. Rest days show nothing —
    /// Thursday and Friday are intentionally blank.
    static func activeExercises(from all: [Exercise], on date: Date = Date()) -> [Exercise] {
        if isRestDay(date) { return [] }
        return all.filter { exercise in
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
    /// Rest days vacuously count as "done" since nothing is required.
    static func allCompletedToday(exercises: [Exercise], records: [CompletionRecord]) -> Bool {
        if isRestDay() { return true }
        guard !exercises.isEmpty else { return false }
        let key = dayKey()
        let completedIDs = Set(records.filter { $0.dayKey == key }.map(\.exerciseID))
        return exercises.allSatisfy { completedIDs.contains($0.id) }
    }

    /// "5 of 6 done" style progress for today.
    static func progressToday(exercises: [Exercise], records: [CompletionRecord]) -> (done: Int, total: Int) {
        if isRestDay() { return (0, 0) }
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

    /// Consecutive non-rest days ending today (or yesterday if today
    /// isn't complete yet). Thursdays and Fridays are skipped entirely —
    /// they neither add to nor break the streak.
    static func currentStreak(completedKeys: Set<String>) -> Int {
        var streak = 0
        var cursor = Calendar.current.startOfDay(for: Date())

        if isRestDay(cursor) {
            // Today is a rest day — begin counting from yesterday.
            guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else {
                return 0
            }
            cursor = yesterday
        } else if !completedKeys.contains(dayKey(cursor)) {
            // Today isn't complete yet (probably mid-day) — look at yesterday.
            guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else {
                return 0
            }
            cursor = yesterday
        }

        while true {
            if isRestDay(cursor) {
                // Rest days don't break the streak and don't add to it.
                guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else {
                    break
                }
                cursor = prev
                continue
            }
            guard completedKeys.contains(dayKey(cursor)) else { break }
            streak += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = prev
        }
        return streak
    }
}
