//
//  PlanViewmodel.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 02/09/2026.
//

import SwiftUI
import Combine

public struct PlanMealOption: Identifiable, Equatable {
    public let id: Int
    public let name: String
    public let imageName: String
    
    public init(id: Int, name: String, imageName: String) {
        self.id = id
        self.name = name
        self.imageName = imageName
    }
}

public struct PlanExercise: Identifiable, Equatable {
    public let id: Int
    public let name: String
    public let detail: String
    public let desc: String
    public let imageName: String
    
    public init(id: Int, name: String, detail: String, desc: String, imageName: String) {
        self.id = id
        self.name = name
        self.detail = detail
        self.desc = desc
        self.imageName = imageName
    }
}

public struct PlanStep: Identifiable {
    public let id: Int
    public let title: String
    public let objective: String?
    public let kind: Kind
    
    public enum Kind {
        case meal(options: [PlanMealOption])
        case training(exercises: [PlanExercise])
    }
    
    public init(id: Int, title: String, objective: String?, kind: Kind) {
        self.id = id
        self.title = title
        self.objective = objective
        self.kind = kind
    }
}

final class PlanViewModel: ObservableObject {
    @Published var currentDay: Int = 1
    @Published var currentDayTitol: String = "Fuerza general y estabilidad"
    @Published var currentStageIndex: Int = 0
    @Published var completedStages: Set<Int> = []
    @Published var selectedMealOptions: [Int: Int] = [:]
    @Published var stages: [String] = []
    @Published var steps: [PlanStep] = []
    
    let repo: PlanRepo
    
    var fullDayLabel: String { "\(currentDaySubtitle): \(currentDayTitol)" }
    var currentDaySubtitle: String { "Día \(currentDay)" }
    var currentStageTitle: String {
        stages[safe: currentStageIndex] ?? stages.first ?? "Desayuno"
    }
    var currentStageName: String {
        stages[safe: currentStageIndex] ?? stages.first ?? "Desayuno"
    }
    var isCurrentDayFullyCompleted: Bool {
        !stages.isEmpty && completedStages.count >= stages.count
    }
    
    init(repo: PlanRepo = PlanRepo.shared) {
        self.repo = repo
        self.loadDayData()
    }
    
    func loadDayData() {
        self.currentDay = repo.calculateCurrentDay()
        let dayData = repo.getDay(number: currentDay)
        self.currentDayTitol = dayData?.titol ?? "Entrenamiento"
        
        var newStages: [String] = []
        var newSteps: [PlanStep] = []
        var stageCounter = 0
        
        if let day = dayData {
            // 1. Esmorzar
            newStages.append("Desayuno")
            newSteps.append(PlanStep(
                id: stageCounter,
                title: "Desayuno",
                objective: nil,
                kind: .meal(options: day.esmorzar.opcions.enumerated().map { idx, opt in
                    PlanMealOption(id: idx, name: opt.nom, imageName: opt.imatge)
                })
            ))
            stageCounter += 1
            
            // 2. Mig matí
            newStages.append("Media mañana")
            newSteps.append(PlanStep(
                id: stageCounter,
                title: "Media mañana",
                objective: nil,
                kind: .meal(options: day.mig_mati.opcions.enumerated().map { idx, opt in
                    PlanMealOption(id: idx, name: opt.nom, imageName: opt.imatge)
                })
            ))
            stageCounter += 1
            
            // 3. Middle stage(s): timed sessions when the day defines them
            // (basket pla 2–4 schema), otherwise the classic tipus layout.
            if let sessions = day.sessions, !sessions.isEmpty {
                for session in sessions {
                    let sessionExercises: [PlanExerciseData] = (session.contingut ?? [])
                        + (session.escalfament ?? [])
                        + (session.part_principal ?? [])
                    let hora = (session.hora ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let nom = (session.nom ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let sessionTitle: String
                    if !hora.isEmpty && !nom.isEmpty {
                        sessionTitle = "\(hora) · \(nom)"
                    } else if !nom.isEmpty {
                        sessionTitle = nom
                    } else if !hora.isEmpty {
                        sessionTitle = hora
                    } else {
                        sessionTitle = "Sesión"
                    }
                    newStages.append(sessionTitle)
                    newSteps.append(PlanStep(
                        id: stageCounter,
                        title: sessionTitle,
                        objective: nil,
                        kind: .training(exercises: sessionExercises.enumerated().map { idx, ex in
                            PlanExercise(id: idx, name: ex.exercici, detail: ex.series_repeticions ?? "", desc: ex.descripcio ?? "", imageName: ex.imatge ?? "")
                        })
                    ))
                    stageCounter += 1
                }
            } else {
            switch day.tipus {
            case "entrenament":
                // Some days use "escalfament" + "part_principal",
                // others use "forca" + "pliometria" (e.g. Day 5).
                // Merge all available training exercises into at most two stages.
                let warmupExercises: [PlanExerciseData] = day.entrenament?.escalfament ?? []
                let mainExercises: [PlanExerciseData] = (day.entrenament?.part_principal ?? [])
                    + (day.entrenament?.forca ?? [])
                    + (day.entrenament?.pliometria ?? [])

                // Only show Escalfament stage if there are exercises for it
                if !warmupExercises.isEmpty {
                    newStages.append("Calentamiento")
                    newSteps.append(PlanStep(
                        id: stageCounter,
                        title: "Calentamiento",
                        objective: day.entrenament?.objectiu,
                        kind: .training(exercises: warmupExercises.enumerated().map { idx, ex in
                            PlanExercise(id: idx, name: ex.exercici, detail: ex.series_repeticions ?? "", desc: ex.descripcio ?? "", imageName: ex.imatge ?? "")
                        })
                    ))
                    stageCounter += 1
                }

                // Always show Part principal stage (even if empty — shows a clear card)
                newStages.append("Parte principal")
                newSteps.append(PlanStep(
                    id: stageCounter,
                    title: "Parte principal",
                    objective: warmupExercises.isEmpty ? day.entrenament?.objectiu : nil,
                    kind: .training(exercises: mainExercises.enumerated().map { idx, ex in
                        PlanExercise(id: idx, name: ex.exercici, detail: ex.series_repeticions ?? "", desc: ex.descripcio ?? "", imageName: ex.imatge ?? "")
                    })
                ))
                stageCounter += 1
                
            case "club":
                let clubName = day.entrenament?.nom ?? "Entrenamiento con el club"
                newStages.append(clubName)
                newSteps.append(PlanStep(
                    id: stageCounter,
                    title: clubName,
                    objective: nil,
                    kind: .training(exercises: [
                        PlanExercise(
                            id: 0,
                            name: clubName,
                            detail: "Club",
                            desc: day.entrenament?.nota ?? "Haz únicamente el entrenamiento habitual de tu club.",
                            imageName: day.entrenament?.imatge ?? "entrenament-amb-el-club"
                        )
                    ])
                ))
                stageCounter += 1
                
            case "recuperacio":
                let recName = day.entrenament?.nom ?? "Recuperación y movilidad"
                newStages.append(recName)
                newSteps.append(PlanStep(
                    id: stageCounter,
                    title: recName,
                    objective: day.entrenament?.objectiu,
                    kind: .training(exercises: (day.entrenament?.activitats ?? []).enumerated().map { idx, ex in
                        PlanExercise(id: idx, name: ex.exercici, detail: ex.series_repeticions ?? "", desc: ex.descripcio ?? "", imageName: ex.imatge ?? "")
                    })
                ))
                stageCounter += 1
                
            case "descans":
                let descansName = day.entrenament?.nom ?? "Descanso completo"
                newStages.append(descansName)
                newSteps.append(PlanStep(
                    id: stageCounter,
                    title: descansName,
                    objective: nil,
                    kind: .training(exercises: [
                        PlanExercise(
                            id: 0,
                            name: descansName,
                            detail: "Descanso",
                            desc: day.entrenament?.nota ?? "Descanso total. Prioriza el sueño y la recuperación.",
                            imageName: day.entrenament?.imatge ?? "descans-complet"
                        )
                    ])
                ))
                stageCounter += 1
                
            default:
                break
            }
            }
            
            // 4. Dinar
            newStages.append("Comida")
            newSteps.append(PlanStep(
                id: stageCounter,
                title: "Comida",
                objective: nil,
                kind: .meal(options: day.dinar.opcions.enumerated().map { idx, opt in
                    PlanMealOption(id: idx, name: opt.nom, imageName: opt.imatge)
                })
            ))
            stageCounter += 1
            
            // 5. Berenar
            newStages.append("Merienda")
            newSteps.append(PlanStep(
                id: stageCounter,
                title: "Merienda",
                objective: nil,
                kind: .meal(options: day.berenar.opcions.enumerated().map { idx, opt in
                    PlanMealOption(id: idx, name: opt.nom, imageName: opt.imatge)
                })
            ))
            stageCounter += 1
            
            // 6. Sopar
            newStages.append("Cena")
            newSteps.append(PlanStep(
                id: stageCounter,
                title: "Cena",
                objective: nil,
                kind: .meal(options: day.sopar.opcions.enumerated().map { idx, opt in
                    PlanMealOption(id: idx, name: opt.nom, imageName: opt.imatge)
                })
            ))
            stageCounter += 1
        }
        
        self.stages = newStages
        self.steps = newSteps
        
        self.completedStages = repo.getCompletedStages(day: currentDay)
        self.selectedMealOptions = repo.getAllSelectedMealOptions(day: currentDay)
        
        if let firstUncompleted = (0..<stages.count).first(where: { !completedStages.contains($0) }) {
            self.currentStageIndex = firstUncompleted
        } else {
            self.currentStageIndex = max(stages.count - 1, 0)
        }
    }
    
    func saveMealSelection(stageIndex: Int, optionIndex: Int) {
        selectedMealOptions[stageIndex] = optionIndex
        repo.saveSelectedMealOption(day: currentDay, stageIndex: stageIndex, optionIndex: optionIndex)
    }

    // MARK: - Intensity valuation (Borg 0–10, Plan 1)

    func intensityRating(for stageIndex: Int) -> Int? {
        repo.getIntensity(day: currentDay, stageIndex: stageIndex)
    }

    func hasIntensityRating(for stageIndex: Int) -> Bool {
        repo.hasIntensityRating(day: currentDay, stageIndex: stageIndex)
    }

    func saveIntensityRating(stageIndex: Int, value: Int) {
        repo.saveIntensity(day: currentDay, stageIndex: stageIndex, value: value)
        // Admin Data Sync: valoración de intensidad → subir snapshot (debounce interno).
        Task { @MainActor in
            GitHubSyncService.shared.requestSync(reason: .intensity)
        }
    }

    /// True when the step at index is a training stage holding exercises.
    func isTrainingStageWithExercises(at index: Int) -> Bool {
        guard steps.indices.contains(index) else { return false }
        return IntensityLogic.isTrainingWithExercises(kind: steps[index].kind)
    }
    
    func completeStage(index: Int) {
        completedStages.insert(index)
        repo.saveCompletedStages(day: currentDay, stages: completedStages)
        
        if isCurrentDayFullyCompleted {
            let wasAlreadyCompleted = repo.isDayCompleted(day: currentDay)
            repo.setDayCompleted(day: currentDay, isCompleted: true)
            // Synchronous write: guarantees the timestamp is persisted before
            // PlanSheet's onComplete -> StreakViewModel.refresh() reads it.
            UserDefaultsStreakRepo.shared.recordDayCompletedSync(date: Date())
            
            // Día 14 completado: o se cierra el programa (plan 4) o el usuario
            // vuelve al cuestionario para empezar el siguiente ciclo de 14 días.
            // El guard evita doble conteo si se vuelve a tocar un paso ya completo.
            if currentDay >= 14 && !wasAlreadyCompleted {
                let needsRetake = repo.handleFinalDayCompleted()
                if needsRetake {
                    print("[PlanViewModel] Ciclo de 14 días completado. Cuestionario pendiente.")
                } else {
                    print("[PlanViewModel] Programa completo (plan 4). Día final conservado.")
                }
            }

            // Admin Data Sync: día completo → subir snapshot (debounce interno).
            Task { @MainActor in
                GitHubSyncService.shared.requestSync(reason: .dayCompleted)
            }
        }
    }
    
    func advanceToNextStage() {
        if let nextUncompleted = (0..<stages.count).first(where: { !completedStages.contains($0) }) {
            currentStageIndex = nextUncompleted
        } else if currentStageIndex < stages.count - 1 {
            currentStageIndex += 1
        }
    }
    
    func completeCurrentStage() {
        completeStage(index: currentStageIndex)
    }
    
    func sync(stageIndex: Int) {
        currentStageIndex = stageIndex
    }
    
    func sync(completed: Set<Int>) {
        completedStages = completed
    }
    
    func refresh() {
        loadDayData()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
