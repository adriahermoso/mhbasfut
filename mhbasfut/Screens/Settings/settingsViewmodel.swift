//
//  settingsViewmodel.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var remindersEnabled: Bool = true
    @Published var soundEnabled: Bool = true
    @Published var appVersion: String = "Versión 1.0.0"

    private let repo: SettingsRepository

    init(repo: SettingsRepository? = nil) {
        self.repo = repo ?? UserDefaultsSettingsRepo()
        Task { await load() }
    }

    func load() async {
        async let reminders = repo.getRemindersEnabled()
        async let sound = repo.getSoundEnabled()
        let version = repo.getAppVersion()
        remindersEnabled = await reminders
        soundEnabled = await sound
        appVersion = version
    }

    // MARK: - Toggle bindings (wired to repo, UI side effect only via repo state)

    func setRemindersEnabled(_ enabled: Bool) {
        remindersEnabled = enabled
        Task { await repo.setRemindersEnabled(enabled) }
    }

    func setSoundEnabled(_ enabled: Bool) {
        soundEnabled = enabled
        Task { await repo.setSoundEnabled(enabled) }
    }

    // MARK: - Row actions (no-op for now, but wired for future navigation)

    func didTapPerfil() { /* navigate to profile – wiring placeholder */ }
    
    func didTapRehacerTest() {
        Task {
            await repo.rehacerTest()
            UserDefaults.standard.set(false, forKey: "questionary.isCompleted")
        }
    }
    
    func didTapPreferenciasEntrenamiento() { }
    func didTapApariencia() { }
    func didTapIdioma() { }
    
    func didTapEliminarDatos() {
        Task {
            await repo.eliminarDatos()
            UserDefaults.standard.set(false, forKey: "questionary.isCompleted")
        }
    }
    
    func didTapAcerca() { }
    func didTapPoliticaPrivacidad() { }
}
