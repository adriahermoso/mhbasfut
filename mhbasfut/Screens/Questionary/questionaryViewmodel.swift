//
//  questionaryViewmodel.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import SwiftUI
import Combine

public enum QuestionaryState: Equatable {
    case selectingSport
    case answering
    case finished
}

public class QuestionaryViewModel: ObservableObject {
    @Published public var state: QuestionaryState = .selectingSport
    @Published public var questions: [Question] = []
    
    // Selections
    @Published public var selectedSport: String? = "Futbol"
    @Published public var selectedAnswer: String? = nil
    @Published public var currentSliderValue: Double = 5.0
    @Published public var currentFieldValues: [String: String] = [:]
    @Published public var currentQuestionIndex: Int = 0
    @Published public var savedAnswers: [String: String] = [:]
    @Published public var finalScore: QuestionaryScore? = nil
    @Published public var assignedPlanNumber: Int = 1
    
    public let repo: QuestionaryRepo
    
    public init(repo: QuestionaryRepo = QuestionaryRepo(), forceRetake: Bool = false) {
        self.repo = repo
        self.savedAnswers = repo.getSavedAnswers()
        
        // Restore sport preference or default to football
        let savedSport = repo.getSelectedSport() ?? "Futbol"
        self.selectedSport = savedSport
        self.questions = repo.loadQuestionnaire(for: savedSport)
        self.finalScore = repo.getSavedScore()
        self.assignedPlanNumber = repo.getAssignedPlan(forSport: savedSport)
            ?? PhysicalPlanClassifier.assignedPlan(answers: savedAnswers)
        
        if repo.isQuestionnaireCompleted() {
            // New questions may have been added since completion (e.g. physical
            // tests appended at the end). If anything is unanswered, continue
            // answering there instead of showing the finished screen.
            if let firstUnanswered = questions.firstIndex(where: { savedAnswers["\($0.id)"] == nil }) {
                self.state = .answering
                self.currentQuestionIndex = firstUnanswered
                self.syncCurrentInputWithSavedAnswer()
            } else {
                self.state = .finished
                // Recompute if answers changed externally but keep saved date when possible.
                if finalScore == nil {
                    self.finalScore = QuestionaryScorer.compute(questions: questions, answers: savedAnswers, sport: savedSport)
                }
            }
        } else {
            // Check if there are answers in progress or start answering directly
            if !savedAnswers.isEmpty {
                self.state = .answering
                // Find first unanswered question or start at 0
                let firstUnanswered = questions.firstIndex(where: { savedAnswers["\($0.id)"] == nil }) ?? 0
                self.currentQuestionIndex = firstUnanswered
                self.syncCurrentInputWithSavedAnswer()
            }
        }

        // Gate de caducidad: aunque el cuestionario figure como completado,
        // un ciclo expirado obliga a repasarlo (respuestas precargadas) para
        // asignar el siguiente plan.
        if forceRetake, state != .selectingSport, !questions.isEmpty {
            if state == .finished {
                state = .answering
                currentQuestionIndex = questions.firstIndex(where: { savedAnswers["\($0.id)"] == nil }) ?? 0
                syncCurrentInputWithSavedAnswer()
            }
        }
    }
    
    public var currentQuestion: Question? {
        guard questions.indices.contains(currentQuestionIndex) else { return nil }
        return questions[currentQuestionIndex]
    }
    
    public var progress: Double {
        if state == .selectingSport { return 0.05 }
        if state == .finished { return 1.0 }
        guard !questions.isEmpty else { return 0.0 }
        return Double(currentQuestionIndex + 1) / Double(questions.count)
    }
    
    public var isCurrentAnswerValid: Bool {
        switch state {
        case .selectingSport:
            return selectedSport != nil
            
        case .answering:
            guard let q = currentQuestion else { return false }
            switch q.questionType {
            case .options:
                return selectedAnswer != nil && !selectedAnswer!.isEmpty
                
            case .slider:
                return true
                
            case .field:
                let text = currentFieldValues["single"] ?? ""
                return QuestionaryValidation.validate(
                    value: text,
                    type: q.resolvedSingleInputType(),
                    questionId: q.id,
                    fieldKey: "single",
                    minValue: q.minValue,
                    maxValue: q.maxValue
                ) == nil
                
            case .fields:
                guard let fields = q.fields, !fields.isEmpty else { return true }
                for field in fields {
                    let val = currentFieldValues[field.key] ?? ""
                    let err = QuestionaryValidation.validate(
                        value: val,
                        type: field.resolvedInputType(questionId: q.id),
                        questionId: q.id,
                        fieldKey: field.key,
                        minValue: field.minValue ?? q.minValue,
                        maxValue: field.maxValue ?? q.maxValue
                    )
                    if err != nil { return false }
                }
                return true
            }
            
        case .finished:
            return true
        }
    }

    /// User-facing validation message for a given field key of the current question.
    public func fieldError(for key: String) -> String? {
        guard let q = currentQuestion else { return nil }
        let raw = currentFieldValues[key] ?? ""
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
        switch q.questionType {
        case .field:
            return QuestionaryValidation.validate(
                value: raw,
                type: q.resolvedSingleInputType(),
                questionId: q.id,
                fieldKey: key,
                minValue: q.minValue,
                maxValue: q.maxValue
            )
        case .fields:
            guard let field = q.fields?.first(where: { $0.key == key }) else { return nil }
            return QuestionaryValidation.validate(
                value: raw,
                type: field.resolvedInputType(questionId: q.id),
                questionId: q.id,
                fieldKey: key,
                minValue: field.minValue ?? q.minValue,
                maxValue: field.maxValue ?? q.maxValue
            )
        default:
            return nil
        }
    }
    
    public func continueToNext() {
        switch state {
        case .selectingSport:
            guard let sport = selectedSport else { return }
            repo.saveSelectedSport(sport)
            questions = repo.loadQuestionnaire(for: sport)
            state = .answering
            currentQuestionIndex = 0
            syncCurrentInputWithSavedAnswer()
            
        case .answering:
            guard let q = currentQuestion else { return }
            guard isCurrentAnswerValid else { return }
            
            // Save current answer
            let serialized = serializeCurrentAnswer(for: q)
            savedAnswers["\(q.id)"] = serialized
            repo.saveAnswer(questionId: q.id, answer: serialized)
            
            if currentQuestionIndex < questions.count - 1 {
                currentQuestionIndex += 1
                syncCurrentInputWithSavedAnswer()
            } else {
                let sport = repo.getSelectedSport() ?? selectedSport
                let score = QuestionaryScorer.compute(questions: questions, answers: savedAnswers, sport: sport)
                repo.saveScore(score)
                finalScore = score
                updateAssignedPlanIfNeeded()
                state = .finished
            }
            
        case .finished:
            finishQuestionnaire()
        }
    }
    
    public func goToPrevious() {
        guard state == .answering else { return }
        if currentQuestionIndex > 0 {
            currentQuestionIndex -= 1
            syncCurrentInputWithSavedAnswer()
        } else {
            // First question → back to sport selection.
            state = .selectingSport
        }
    }
    
    public func finishQuestionnaire() {
        let resolvedSport = repo.getSelectedSport() ?? selectedSport ?? "Futbol"
        if finalScore == nil {
            let score = QuestionaryScorer.compute(questions: questions, answers: savedAnswers, sport: resolvedSport)
            repo.saveScore(score)
            finalScore = score
        }
        let computed = PhysicalPlanClassifier.assignedPlan(answers: savedAnswers)
        // Single funnel: archives the previous cycle (if any), advances the
        // plan progression and restarts the 14 days today.
        assignedPlanNumber = PlanRepo.shared.completeQuestionnaireCycle(sport: resolvedSport, computedPlan: computed)
        repo.saveCompletion(isCompleted: true)
        // Admin Data Sync: cuestionario completado → subir snapshot (debounce interno).
        Task { @MainActor in
            GitHubSyncService.shared.requestSync(reason: .questionnaire)
        }
    }

    // MARK: - Assigned physical plan (football pla 1–4)

    /// Preview of the plan the finished card will show (a partir de los tests
    /// 36–40 y de la progresión de ciclos). No escribe nada: la asignación
    /// real ocurre en `finishQuestionnaire()`.
    @discardableResult
    public func updateAssignedPlanIfNeeded() -> Int {
        let sport = repo.getSelectedSport() ?? selectedSport ?? "Futbol"
        let computed = PhysicalPlanClassifier.assignedPlan(answers: savedAnswers)
        let planRepo = PlanRepo.shared
        let preview: Int
        if planRepo.isProgramCompleted(forSport: sport) {
            preview = computed
        } else if planRepo.hasStoredStartDate() && planRepo.getLastSport() == sport {
            preview = PlanRepo.nextPlanNumber(computedPlan: computed, previousPlan: planRepo.getAssignedPlanNumber())
        } else {
            preview = computed
        }
        assignedPlanNumber = preview
        return preview
    }
    
    // MARK: - Input State Synchronization
    
    public func syncCurrentInputWithSavedAnswer() {
        guard let q = currentQuestion else { return }
        let existing = savedAnswers["\(q.id)"]
        
        switch q.questionType {
        case .options:
            selectedAnswer = existing
            
        case .slider:
            if let str = existing, let val = Double(str) {
                currentSliderValue = val
            } else {
                let min = q.min ?? 1.0
                let max = q.max ?? 10.0
                currentSliderValue = ((min + max) / 2.0)
            }
            
        case .field:
            if let str = existing {
                currentFieldValues = ["single": str]
            } else {
                currentFieldValues = ["single": ""]
            }
            
        case .fields:
            if let str = existing {
                currentFieldValues = decodeFieldsString(str)
            } else {
                var initial: [String: String] = [:]
                q.fields?.forEach { initial[$0.key] = "" }
                currentFieldValues = initial
            }
        }
    }
    
    // MARK: - Serialization Helpers
    
    private func serializeCurrentAnswer(for question: Question) -> String {
        switch question.questionType {
        case .options:
            return selectedAnswer ?? ""
            
        case .slider:
            if let step = question.step, step >= 1.0 {
                return String(format: "%.0f", currentSliderValue)
            } else {
                return String(format: "%.1f", currentSliderValue)
            }
            
        case .field:
            return currentFieldValues["single"] ?? ""
            
        case .fields:
            return encodeFieldsDictionary(currentFieldValues)
        }
    }
    
    private func encodeFieldsDictionary(_ dict: [String: String]) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return dict.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
    }
    
    private func decodeFieldsString(_ str: String) -> [String: String] {
        if let data = str.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            return dict
        }
        var result: [String: String] = [:]
        for pair in str.components(separatedBy: ";") {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                result[parts[0]] = parts[1]
            }
        }
        return result
    }
    
    public func getDisplayAnswer(for questionId: Int) -> String? {
        guard let raw = savedAnswers["\(questionId)"] else { return nil }
        if raw.starts(with: "{"), let dict = try? JSONSerialization.jsonObject(with: raw.data(using: .utf8)!) as? [String: String] {
            return dict.values.joined(separator: " • ")
        }
        return raw
    }
}
