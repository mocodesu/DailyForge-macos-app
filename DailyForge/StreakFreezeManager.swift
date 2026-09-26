import Foundation
import SwiftData

// MARK: - Result

enum FreezeResult {
    case success
    case failure(String)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var message: String? {
        if case .failure(let msg) = self { return msg }
        return nil
    }
}

// MARK: - Manager

enum StreakFreezeManager {

    // MARK: Configuration

    /// Maximum number of tokens a user can hold at once.
    static let maxTokens = 2

    /// A new token is earned every N completed days.
    static let earnIntervalDays = 10

    /// Only days within this window can be frozen.
    static let freezeWindowDays = 7

    // MARK: Bank

    static var tokensInBank: Int {
        UserDefaults.standard.integer(forKey: PreferenceKeys.freezeTokensInBank)
    }

    static var lastMilestoneAwarded: Int {
        UserDefaults.standard.integer(forKey: PreferenceKeys.freezeLastMilestoneAwarded)
    }

    static var canEarnMore: Bool {
        tokensInBank < maxTokens
    }

    // MARK: Earning

    /// Called whenever the completed-day count may have changed. Awards
    /// tokens for every 10-day milestone the user has crossed that hasn't
    /// been paid out yet, up to the bank cap. Returns `true` if a token was
    /// newly earned on this call.
    ///
    /// If the bank is full, milestones are held (not consumed) so they'll
    /// be delivered as soon as the user spends a token.
    @discardableResult
    static func refreshEarnings(completedDays: Int) -> Bool {
        var bank = tokensInBank
        var watermark = lastMilestoneAwarded
        let startingBank = bank

        var nextMilestone = watermark + earnIntervalDays
        while nextMilestone <= completedDays {
            guard bank < maxTokens else { break }
            bank += 1
            watermark = nextMilestone
            nextMilestone += earnIntervalDays
        }

        if bank != startingBank {
            UserDefaults.standard.set(bank, forKey: PreferenceKeys.freezeTokensInBank)
        }
        if watermark != lastMilestoneAwarded {
            UserDefaults.standard.set(watermark, forKey: PreferenceKeys.freezeLastMilestoneAwarded)
        }

        return bank > startingBank
    }

    /// Number of completed days remaining before the next token is earned,
    /// or `nil` if the bank is already full.
    static func daysUntilNextToken(completedDays: Int) -> Int? {
        guard canEarnMore else { return nil }
        let watermark = lastMilestoneAwarded
        let next = watermark + earnIntervalDays
        if completedDays >= next { return 0 }
        return next - completedDays
    }

    // MARK: Freezing

    static func frozenDayKeys(context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<StreakFreeze>()
        let rows = (try? context.fetch(descriptor)) ?? []
        return Set(rows.map(\.dayKey))
    }

    static func isFrozen(_ date: Date, context: ModelContext) -> Bool {
        let key = DayLogic.dayKey(date)
        return frozenDayKeys(context: context).contains(key)
    }

    @discardableResult
    static func useToken(
        for date: Date,
        note: String = "",
        context: ModelContext
    ) -> FreezeResult {
        let key = DayLogic.dayKey(date)
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let dateStart = calendar.startOfDay(for: date)

        // Guards
        if DayLogic.isRestDay(date) {
            return .failure("That's a rest day — nothing to freeze.")
        }
        if dateStart >= todayStart {
            return .failure("You can only freeze past days.")
        }
        let daysBack = calendar.dateComponents([.day], from: dateStart, to: todayStart).day ?? 0
        if daysBack > freezeWindowDays {
            return .failure("You can only freeze days within the last \(freezeWindowDays) days.")
        }
        if tokensInBank <= 0 {
            return .failure("No freeze tokens available.")
        }

        // Already frozen?
        let descriptor = FetchDescriptor<StreakFreeze>(
            predicate: #Predicate { $0.dayKey == key }
        )
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return .failure("That day is already frozen.")
        }

        // Insert + spend
        let freeze = StreakFreeze(dayKey: key, note: note)
        context.insert(freeze)

        do {
            try context.save()
        } catch {
            context.rollback()
            return .failure("Could not save: \(error.localizedDescription)")
        }

        UserDefaults.standard.set(tokensInBank - 1, forKey: PreferenceKeys.freezeTokensInBank)
        return .success
    }

    /// Removes a freeze and refunds the token. Used by admin/debug flows
    /// and by the user to change their mind.
    @discardableResult
    static func removeFreeze(for date: Date, context: ModelContext) -> Bool {
        let key = DayLogic.dayKey(date)
        let descriptor = FetchDescriptor<StreakFreeze>(
            predicate: #Predicate { $0.dayKey == key }
        )
        guard let rows = try? context.fetch(descriptor), !rows.isEmpty else {
            return false
        }
        for row in rows { context.delete(row) }
        do {
            try context.save()
        } catch {
            context.rollback()
            return false
        }
        UserDefaults.standard.set(tokensInBank + 1, forKey: PreferenceKeys.freezeTokensInBank)
        return true
    }

    // MARK: Detection

    /// Returns the most recent missed workout day within the freeze window,
    /// or `nil` if nothing needs protecting. A day is "missed" if:
    ///   - it's not a rest day
    ///   - it's not already frozen
    ///   - at least one exercise existed by the end of that day
    ///   - not every existing exercise has a completion record for that day
    static func findMostRecentMissedDay(
        records: [CompletionRecord],
        exercises: [Exercise],
        frozenKeys: Set<String>,
        from date: Date = Date()
    ) -> Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        for offset in 1...freezeWindowDays {
            guard let candidate = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            if DayLogic.isRestDay(candidate) { continue }

            let key = DayLogic.dayKey(candidate)
            if frozenKeys.contains(key) { continue }

            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: candidate) else { continue }
            let existing = exercises.filter { $0.createdAt < dayEnd }
            guard !existing.isEmpty else { continue }

            let completed = Set(records.filter { $0.dayKey == key }.map(\.exerciseID))
            let allDone = existing.allSatisfy { completed.contains($0.id) }
            if !allDone {
                return candidate
            }
        }
        return nil
    }
}
