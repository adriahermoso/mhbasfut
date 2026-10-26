//
//  WellnessRepo.swift
//  mhbasfut
//
//  Plan 2 – Sleep Quality + Emotion Rater persistence and trigger helpers.
//  All history is kept in UserDefaults; every helper is pure/testable with
//  injectable dates so calendar-day logic (time zones, midnight) is safe.
//

import Foundation

/// One stored rating: the calendar day it was given + the chosen option index.
/// Sleep: 0 = Muy bien … 3 = Mal. Emotion: 0 = Genial … 4 = Fatal.
public struct WellnessRating: Codable, Equatable {
    public let date: Date
    public let rating: Int

    public init(date: Date, rating: Int) {
        self.date = date
        self.rating = rating
    }
}

public enum WellnessRepo {

    // MARK: - Keys (follow existing plan.* / questionary.* style)

    public static let sleepHistoryKey = "sleep.quality.history"
    public static let emotionHistoryKey = "emotion.history"

    /// Questionnaire question holding bedtime/waketime ("HH:MM" strings).
    public static let wakeUpQuestionId = 12
    public static let wakeUpFieldKey = "waketime"

    private static var didLogMalformedWakeTime = false

    // MARK: - Wake-up time (Step 1)

    /// Decode a Q12-style fields answer: JSON dict first
    /// ({"bedtime":"23:00","waketime":"07:30"}), legacy "k=v;k=v" fallback.
    /// Mirrors QuestionaryViewModel.decodeFieldsString without the ViewModel.
    public static func fieldsDictionary(from raw: String) -> [String: String] {
        if let data = raw.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            return dict
        }
        var result: [String: String] = [:]
        for pair in raw.components(separatedBy: ";") {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                result[parts[0]] = parts[1]
            }
        }
        return result
    }

    /// Raw "HH:MM" wake-up string from persisted questionnaire answers, if any.
    public static func wakeTimeString(from savedAnswers: [String: String]) -> String? {
        guard let raw = savedAnswers["\(wakeUpQuestionId)"], !raw.isEmpty else { return nil }
        let dict = fieldsDictionary(from: raw)
        guard let value = dict[wakeUpFieldKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }

    /// Today's wake-up moment (hour/minute applied to `now`'s calendar day),
    /// or nil when missing or malformed (e.g. "7", "25:00", "07-30").
    /// Accepts both "07:30" and "7:30"; minutes must be two digits 00–59,
    /// hours 0–23 — the same rule as QuestionaryValidation.isValidTime.
    public static func wakeUpToday(
        from savedAnswers: [String: String],
        now: Date = Date(),
        calendar: Calendar = Calendar.current
    ) -> Date? {
        guard let raw = wakeTimeString(from: savedAnswers) else { return nil }
        let parts = raw.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              parts[0].count <= 2, parts[1].count == 2,
              (0...23).contains(hour), (0...59).contains(minute) else {
            if !didLogMalformedWakeTime {
                didLogMalformedWakeTime = true
                #if DEBUG
                print("[WellnessRepo] Malformed waketime: \(raw). Sleep sheet disabled until fixed.")
                #endif
            }
            return nil
        }
        return calendar.date(
            bySettingHour: hour, minute: minute, second: 0, of: now
        )
    }

    // MARK: - Sleep history (Step 2)

    public static func sleepHistory() -> [WellnessRating] {
        guard let data = UserDefaults.standard.data(forKey: sleepHistoryKey),
              let history = try? JSONDecoder().decode([WellnessRating].self, from: data) else {
            return []
        }
        return history
    }

    private static func saveSleepHistory(_ history: [WellnessRating]) {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: sleepHistoryKey)
        }
    }

    /// Append a rating; full history is kept, never overwritten.
    public static func saveSleepQuality(rating: Int, date: Date = Date()) {
        var history = sleepHistory()
        history.append(WellnessRating(date: date, rating: min(max(rating, 0), 3)))
        saveSleepHistory(history)
    }

    /// True when any rating exists on the same calendar day as `date`.
    public static func hasSleepQuality(for date: Date = Date(), calendar: Calendar = Calendar.current) -> Bool {
        let day = calendar.startOfDay(for: date)
        return sleepHistory().contains { calendar.startOfDay(for: $0.date) == day }
    }

    /// Sleep sheet trigger: wake-up known, device time at/past wake-up, and
    /// no rating recorded yet today. Before wake-up time → false (a later
    /// HomeScreen appearance re-evaluates). Missing/malformed wake-up → false.
    public static func isSleepSheetDue(
        now: Date = Date(),
        savedAnswers: [String: String],
        calendar: Calendar = Calendar.current
    ) -> Bool {
        guard let wakeUp = wakeUpToday(from: savedAnswers, now: now, calendar: calendar) else {
            return false
        }
        guard now >= wakeUp else { return false }
        return !hasSleepQuality(for: now, calendar: calendar)
    }

    // MARK: - Emotion history (Step 2)

    public static func emotionHistory() -> [WellnessRating] {
        guard let data = UserDefaults.standard.data(forKey: emotionHistoryKey),
              let history = try? JSONDecoder().decode([WellnessRating].self, from: data) else {
            return []
        }
        return history
    }

    private static func saveEmotionHistory(_ history: [WellnessRating]) {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: emotionHistoryKey)
        }
    }

    /// Append a rating; full history is kept, never overwritten.
    public static func saveEmotion(rating: Int, date: Date = Date()) {
        var history = emotionHistory()
        history.append(WellnessRating(date: date, rating: min(max(rating, 0), 4)))
        saveEmotionHistory(history)
    }

    /// Most recent emotion date, or nil when never recorded.
    public static func lastEmotionDate() -> Date? {
        emotionHistory().map(\.date).max()
    }

    /// Whole calendar days between the last rating and `now`.
    /// Nil when never recorded. Start-of-day based, so time-zone shifts and
    /// midnight crossings resolve to the correct calendar-day count.
    public static func daysSinceLastEmotion(
        now: Date = Date(),
        calendar: Calendar = Calendar.current
    ) -> Int? {
        guard let last = lastEmotionDate() else { return nil }
        let from = calendar.startOfDay(for: last)
        let to = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: from, to: to).day
    }

    /// Emotion sheet trigger: never recorded → due; otherwise due when the
    /// last rating is 3+ calendar days old. Exactly 3 → due, 2 → not due.
    public static func isEmotionDue(
        now: Date = Date(),
        calendar: Calendar = Calendar.current
    ) -> Bool {
        guard let days = daysSinceLastEmotion(now: now, calendar: calendar) else {
            return true
        }
        return days >= 3
    }
}
