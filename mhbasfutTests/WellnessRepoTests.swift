//
//  WellnessRepoTests.swift
//  mhbasfutTests
//
//  Plan 2 – unit tests for wake-up parsing, Sleep "already rated today" /
//  "time has passed", Emotion 0/1/2/3/4+ days, and history round-trips.
//  Requires the mhbasfutTests unit-test target (host: mhbasfut app).
//
//  Each test stashes + restores both history keys, so production data is
//  never polluted and every test starts from a clean slate.
//

import XCTest
@testable import mhbasfut

final class WellnessRepoTests: XCTestCase {

    private var savedSleep: Data?
    private var savedEmotion: Data?

    override func setUp() {
        super.setUp()
        savedSleep = UserDefaults.standard.data(forKey: WellnessRepo.sleepHistoryKey)
        savedEmotion = UserDefaults.standard.data(forKey: WellnessRepo.emotionHistoryKey)
        UserDefaults.standard.removeObject(forKey: WellnessRepo.sleepHistoryKey)
        UserDefaults.standard.removeObject(forKey: WellnessRepo.emotionHistoryKey)
    }

    override func tearDown() {
        if let savedSleep {
            UserDefaults.standard.set(savedSleep, forKey: WellnessRepo.sleepHistoryKey)
        } else {
            UserDefaults.standard.removeObject(forKey: WellnessRepo.sleepHistoryKey)
        }
        if let savedEmotion {
            UserDefaults.standard.set(savedEmotion, forKey: WellnessRepo.emotionHistoryKey)
        } else {
            UserDefaults.standard.removeObject(forKey: WellnessRepo.emotionHistoryKey)
        }
        super.tearDown()
    }

    // MARK: - Helpers

    private func answers(waketime: String?) -> [String: String] {
        guard let waketime else { return [:] }
        return ["12": "{\"bedtime\":\"23:00\",\"waketime\":\"\(waketime)\"}"]
    }

    private func today(at hour: Int, minute: Int = 0) -> Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: Date())
        return calendar.date(from: DateComponents(
            year: comps.year, month: comps.month, day: comps.day,
            hour: hour, minute: minute, second: 0
        ))!
    }

    // MARK: - Step 1: wake-up parsing

    func testFieldsDictionaryParsesJSONAndLegacyFormats() {
        XCTAssertEqual(
            WellnessRepo.fieldsDictionary(from: "{\"bedtime\":\"23:00\",\"waketime\":\"07:30\"}"),
            ["bedtime": "23:00", "waketime": "07:30"]
        )
        XCTAssertEqual(
            WellnessRepo.fieldsDictionary(from: "bedtime=23:00;waketime=07:30"),
            ["bedtime": "23:00", "waketime": "07:30"]
        )
    }

    func testWakeTimeStringExtraction() {
        XCTAssertEqual(WellnessRepo.wakeTimeString(from: answers(waketime: "07:30")), "07:30")
        XCTAssertNil(WellnessRepo.wakeTimeString(from: [:]))
        XCTAssertNil(WellnessRepo.wakeTimeString(from: answers(waketime: nil)))
    }

    func testWakeUpTodayValidAndMalformed() {
        let calendar = Calendar.current
        let wake = WellnessRepo.wakeUpToday(from: answers(waketime: "07:30"), now: today(at: 12), calendar: calendar)
        XCTAssertNotNil(wake)
        XCTAssertEqual(calendar.component(.hour, from: wake!), 7)
        XCTAssertEqual(calendar.component(.minute, from: wake!), 30)
        // Same calendar day as `now`.
        XCTAssertTrue(calendar.isDate(wake!, inSameDayAs: today(at: 12)))

        XCTAssertNil(WellnessRepo.wakeUpToday(from: answers(waketime: "25:00")))
        XCTAssertNil(WellnessRepo.wakeUpToday(from: answers(waketime: "07-30")))
        XCTAssertNil(WellnessRepo.wakeUpToday(from: answers(waketime: "7")))
        XCTAssertNil(WellnessRepo.wakeUpToday(from: [:]))
    }

    // MARK: - Sleep trigger rules

    func testSleepDueOnlyAfterWakeUpTime() {
        let a = answers(waketime: "07:30")
        XCTAssertFalse(WellnessRepo.isSleepSheetDue(now: today(at: 7, minute: 0), savedAnswers: a))
        XCTAssertTrue(WellnessRepo.isSleepSheetDue(now: today(at: 7, minute: 30), savedAnswers: a))
        XCTAssertTrue(WellnessRepo.isSleepSheetDue(now: today(at: 12), savedAnswers: a))
    }

    func testSleepNeverTwiceSameDay() {
        let a = answers(waketime: "07:30")
        let now = today(at: 9)
        XCTAssertTrue(WellnessRepo.isSleepSheetDue(now: now, savedAnswers: a))
        WellnessRepo.saveSleepQuality(rating: 0, date: now)
        XCTAssertTrue(WellnessRepo.hasSleepQuality(for: now))
        XCTAssertFalse(WellnessRepo.isSleepSheetDue(now: now, savedAnswers: a))
    }

    func testSleepDueAgainNextCalendarDay() {
        let a = answers(waketime: "07:30")
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today(at: 9))!
        WellnessRepo.saveSleepQuality(rating: 2, date: yesterday)
        XCTAssertTrue(WellnessRepo.isSleepSheetDue(now: today(at: 9), savedAnswers: a))
    }

    func testSleepNeverWithoutWakeUpTime() {
        XCTAssertFalse(WellnessRepo.isSleepSheetDue(now: today(at: 12), savedAnswers: [:]))
        XCTAssertFalse(WellnessRepo.isSleepSheetDue(now: today(at: 12), savedAnswers: answers(waketime: "99:99")))
    }

    func testSleepHistoryRoundTripAndClamping() {
        XCTAssertEqual(WellnessRepo.sleepHistory().count, 0)
        WellnessRepo.saveSleepQuality(rating: 1, date: today(at: 9))
        WellnessRepo.saveSleepQuality(rating: 9, date: today(at: 10)) // clamps to 3
        let history = WellnessRepo.sleepHistory()
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].rating, 1)
        XCTAssertEqual(history[1].rating, 3)
    }

    // MARK: - Emotion trigger rules (0, 1, 2, 3, 4+ days)

    func testEmotionDueWhenNeverRecorded() {
        XCTAssertNil(WellnessRepo.lastEmotionDate())
        XCTAssertNil(WellnessRepo.daysSinceLastEmotion(now: today(at: 12)))
        XCTAssertTrue(WellnessRepo.isEmotionDue(now: today(at: 12)))
    }

    func testEmotionNotDueAtZeroOneTwoDays() {
        let calendar = Calendar.current
        for daysAgo in 0...2 {
            UserDefaults.standard.removeObject(forKey: WellnessRepo.emotionHistoryKey)
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today(at: 12))!
            WellnessRepo.saveEmotion(rating: 1, date: date)
            XCTAssertEqual(WellnessRepo.daysSinceLastEmotion(now: today(at: 12)), daysAgo)
            XCTAssertFalse(WellnessRepo.isEmotionDue(now: today(at: 12)), "\(daysAgo) days ago")
        }
    }

    func testEmotionDueAtThreeAndFourPlusDays() {
        let calendar = Calendar.current
        for daysAgo in [3, 4, 10] {
            UserDefaults.standard.removeObject(forKey: WellnessRepo.emotionHistoryKey)
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today(at: 12))!
            WellnessRepo.saveEmotion(rating: 2, date: date)
            XCTAssertEqual(WellnessRepo.daysSinceLastEmotion(now: today(at: 12)), daysAgo)
            XCTAssertTrue(WellnessRepo.isEmotionDue(now: today(at: 12)), "\(daysAgo) days ago")
        }
    }

    func testEmotionHistoryAppendAndClamping() {
        WellnessRepo.saveEmotion(rating: 0, date: today(at: 9))
        WellnessRepo.saveEmotion(rating: 9, date: today(at: 10)) // clamps to 4
        let history = WellnessRepo.emotionHistory()
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].rating, 0)
        XCTAssertEqual(history[1].rating, 4)
        XCTAssertNotNil(WellnessRepo.lastEmotionDate())
    }
}
