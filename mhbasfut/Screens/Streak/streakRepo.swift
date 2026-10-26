//
//  streakRepo.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import Foundation

protocol StreakRepository {
    func getStreakDays(for month: Date) async -> [Date]
    func getCurrentStreakCount() async -> Int
    func recordDayCompleted(date: Date) async
    func isDayCompleted(date: Date) async -> Bool
    func resetStreakData() async
}

public class UserDefaultsStreakRepo: StreakRepository {
    public static let shared = UserDefaultsStreakRepo()
    private let completedDatesKey = "streak.completedDates"
    
    public init() {}
    
    private func getCompletedTimestamps() -> Set<Double> {
        let array = UserDefaults.standard.array(forKey: completedDatesKey) as? [Double] ?? []
        return Set(array)
    }
    
    private func saveCompletedTimestamps(_ timestamps: Set<Double>) {
        UserDefaults.standard.set(Array(timestamps), forKey: completedDatesKey)
    }
    
    public func recordDayCompleted(date: Date = Date()) async {
        recordDayCompletedSync(date: date)
    }

    /// Synchronous variant so callers can persist *before* triggering UI
    /// refreshes. The previous fire-and-forget `Task { await ... }` raced with
    /// `StreakViewModel.refresh()`, so the header count could briefly show
    /// the stale number right after completing a day.
    public func recordDayCompletedSync(date: Date = Date()) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date).timeIntervalSince1970
        var set = getCompletedTimestamps()
        set.insert(startOfDay)
        saveCompletedTimestamps(set)
    }
    
    public func isDayCompleted(date: Date) async -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date).timeIntervalSince1970
        return getCompletedTimestamps().contains(startOfDay)
    }
    
    public func getStreakDays(for month: Date) async -> [Date] {
        let calendar = Calendar.current
        let timestamps = getCompletedTimestamps()
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else {
            return timestamps.map { Date(timeIntervalSince1970: $0) }
        }
        
        return timestamps
            .map { Date(timeIntervalSince1970: $0) }
            .filter { monthInterval.contains($0) }
    }
    
    public func getCurrentStreakCount() async -> Int {
        let calendar = Calendar.current
        let timestamps = getCompletedTimestamps()
        guard !timestamps.isEmpty else { return 0 }
        
        let completedDates = Set(timestamps.map { calendar.startOfDay(for: Date(timeIntervalSince1970: $0)) })
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        
        var count = 0
        var checkDate: Date
        
        if completedDates.contains(today) {
            checkDate = today
        } else if completedDates.contains(yesterday) {
            checkDate = yesterday
        } else {
            return 0
        }
        
        while completedDates.contains(checkDate) {
            count += 1
            guard let previousDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDate
        }
        
        return count
    }
    
    public func resetStreakData() async {
        UserDefaults.standard.removeObject(forKey: completedDatesKey)
    }
}

class MockStreakRepo: StreakRepository {
    func getStreakDays(for month: Date) async -> [Date] {
        let calendar = Calendar.current
        var mockDates: [Date] = []
        for day in 14...18 {
            if let date = calendar.date(bySetting: .day, value: day, of: month) {
                mockDates.append(date)
            }
        }
        return mockDates
    }
    
    func getCurrentStreakCount() async -> Int {
        return 5
    }
    
    func recordDayCompleted(date: Date) async {}
    func isDayCompleted(date: Date) async -> Bool { false }
    func resetStreakData() async {}
}

