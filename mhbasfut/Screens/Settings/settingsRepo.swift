//
//  settingsRepo.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import Foundation

protocol SettingsRepository {
    func getRemindersEnabled() async -> Bool
    func setRemindersEnabled(_ enabled: Bool) async
    func getSoundEnabled() async -> Bool
    func setSoundEnabled(_ enabled: Bool) async
    nonisolated func getAppVersion() -> String
    func rehacerTest() async
    func eliminarDatos() async
}

// UserDefaults-backed implementation: toggles persist across launches.
actor UserDefaultsSettingsRepo: SettingsRepository {
    private let remindersKey = "settings.remindersEnabled"
    private let soundKey = "settings.soundEnabled"

    func getRemindersEnabled() async -> Bool {
        if UserDefaults.standard.object(forKey: remindersKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: remindersKey)
    }

    func setRemindersEnabled(_ enabled: Bool) async {
        UserDefaults.standard.set(enabled, forKey: remindersKey)
    }

    func getSoundEnabled() async -> Bool {
        if UserDefaults.standard.object(forKey: soundKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: soundKey)
    }

    func setSoundEnabled(_ enabled: Bool) async {
        UserDefaults.standard.set(enabled, forKey: soundKey)
    }

    nonisolated func getAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return "Versión \(version)"
        }
        return "Versión 1.0.0"
    }
    
    func rehacerTest() async {
        // Keep the score card: resetQuestionnaire() preserves questionary.score.
        await MainActor.run {
            QuestionaryRepo().resetQuestionnaire()
            PlanRepo().resetPlanData()
        }
        await UserDefaultsStreakRepo.shared.resetStreakData()
    }
    
    func eliminarDatos() async {
        await MainActor.run {
            QuestionaryRepo().resetQuestionnaire()
            QuestionaryRepo().clearScore()
            PlanRepo().resetPlanData()
        }
        await UserDefaultsStreakRepo.shared.resetStreakData()
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        // removePersistentDomain already wipes the score, ensure it explicitly.
        await MainActor.run { QuestionaryRepo().clearScore() }
        UserDefaults.standard.synchronize()
    }
}
