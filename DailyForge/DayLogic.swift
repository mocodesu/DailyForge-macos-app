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

    // MARK: - User-configurable schedule

    /// Number of exercises the user must set up before the day "counts".
    static func minimumExercises() -> Int {
        let raw = UserDefaults.standard.integer(forKey: PreferenceKeys.minimumExercises)
        guard raw > 0 else { return Preferences.defaultMinimumExercises }
        let range = Preferences.minimumExercisesRange
        return min(max(raw, range.lowerBound), range.upperBound)
    }

    /// Set of Gregorian weekday numbers (Sun = 1 … Sat = 7) the user has
    /// marked as rest days. Capped at 3.
    static func restDays() -> Set<Int> {
        let raw = UserDefaults.standard.string(forKey: PreferenceKeys.restDaysRaw)
            ?? Preferences.defaultRestDaysRaw
        let parsed = raw
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { (1...7).contains($0) }
        return Set(parsed.prefix(Preferences.maxRestDays))
    }

    /// True if `date` falls on one of the user's configured rest days.
    static func isRestDay(_ date: Date = Date()) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return restDays().contains(weekday)
    }

    /// Serializes a set of Gregorian weekdays to the stored string form.
    static func restDaysRaw(from weekdays: Set<Int>) -> String {
        let valid = weekdays.filter { (1...7).contains($0) }
        let capped = valid.sorted().prefix(Preferences.maxRestDays)
        return capped.map(String.init).joined(separator: ",")
    }

    // MARK: - Exercise filtering

    /// Exercises that should be shown on the given day.
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

    /// Consecutive non-rest, non-frozen days ending today (or yesterday if
    /// today isn't complete yet). Rest days and frozen days are skipped —
    /// they neither add to nor break the streak.
    static func currentStreak(
        completedKeys: Set<String>,
        frozenKeys: Set<String> = []
    ) -> Int {
        var streak = 0
        var cursor = Calendar.current.startOfDay(for: Date())

        if isRestDay(cursor) || frozenKeys.contains(dayKey(cursor)) {
            guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else {
                return 0
            }
            cursor = yesterday
        } else if !completedKeys.contains(dayKey(cursor)) {
            guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else {
                return 0
            }
            cursor = yesterday
        }

        while true {
            if isRestDay(cursor) || frozenKeys.contains(dayKey(cursor)) {
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
