//
//  streakViewmodel.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import Foundation
import SwiftUI
import Combine // <- Add this line

@MainActor
class StreakViewModel: ObservableObject {
    @Published var monthOffset: Int = 0 {
        didSet {
            Task { await fetchMonthData() }
        }
    }
    
    @Published var streakDays: Set<Date> = []
    @Published var currentStreakCount: Int = 0
    
    private let repo: StreakRepository
    
    init(repo: StreakRepository = UserDefaultsStreakRepo.shared) {
        self.repo = repo
        Task {
            await fetchInitialData()
        }
    }
    
    public func refresh() {
        Task {
            await fetchInitialData()
        }
    }
    
    func fetchInitialData() async {
        currentStreakCount = await repo.getCurrentStreakCount()
        await fetchMonthData()
    }
    
    func fetchMonthData() async {
        let targetDate = Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
        let days = await repo.getStreakDays(for: targetDate)
        
        // Strip time components to ensure accurate matching (Set makes lookups O(1))
        let calendar = Calendar.current
        self.streakDays = Set(days.map { calendar.startOfDay(for: $0) })
    }
    
    // MARK: - Calendar UI Logic
    
    func isStreakDay(date: Date) -> Bool {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return streakDays.contains(startOfDay)
    }
    
    func goBack() {
        if monthOffset > -3 { monthOffset -= 1 }
    }
    
    func goForward() {
        if monthOffset < 0 { monthOffset += 1 }
    }
    
    func currentMonthYearString() -> String {
        let date = Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date).capitalized
    }
    
    func getDaysForMonth() -> [Date?] {
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
        
        let components = calendar.dateComponents([.year, .month], from: targetDate)
        guard let firstDay = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else { return [] }
        
        // Offset for Monday start
        var firstWeekday = calendar.component(.weekday, from: firstDay)
        firstWeekday = (firstWeekday + 5) % 7
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        for i in 1...range.count {
            if let dayDate = calendar.date(byAdding: .day, value: i - 1, to: firstDay) {
                days.append(dayDate)
            }
        }
        return days
    }
    
    // weekdays adapt to the device's language
        var localizedWeekdays: [String] {
            let calendar = Calendar.current
            // Gets standard localized short names (e.g., ["Sun", "Mon", "Tue..."] or ["dom", "lun", "mar..."])
            let symbols = calendar.shortWeekdaySymbols
            
            // Shift the array so Monday is the first day (index 1 becomes index 0)
            let mondayFirst = Array(symbols[1...] + [symbols[0]])
            
            // Take only the first 2 letters and capitalize them to match your design
            return mondayFirst.map { String($0.prefix(2)).capitalized }
        }
}
