//
//  questionaryRepo.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import Foundation

public enum QuestionType: String, Codable {
    case options
    case slider
    case field
    case fields
}

public enum FieldInputType: String, Codable {
    case text
    case integer
    case decimal
    case time
}

public struct QuestionField: Codable, Identifiable, Equatable {
    public var id: String { key }
    public let key: String
    public let label: String
    public let placeholder: String
    public let inputType: String?
    public let minValue: Double?
    public let maxValue: Double?

    public init(key: String, label: String, placeholder: String, inputType: String? = nil, minValue: Double? = nil, maxValue: Double? = nil) {
        self.key = key
        self.label = label
        self.placeholder = placeholder
        self.inputType = inputType
        self.minValue = minValue
        self.maxValue = maxValue
    }

    enum CodingKeys: String, CodingKey {
        case key, label, placeholder, inputType, minValue, maxValue
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        label = try c.decode(String.self, forKey: .label)
        placeholder = try c.decode(String.self, forKey: .placeholder)
        inputType = try c.decodeIfPresent(String.self, forKey: .inputType)
        minValue = try c.decodeIfPresent(Double.self, forKey: .minValue)
        maxValue = try c.decodeIfPresent(Double.self, forKey: .maxValue)
    }

    /// Effective input type: explicit JSON value or inferred from key/label.
    public func resolvedInputType(questionId: Int) -> FieldInputType {
        if let raw = inputType, let t = FieldInputType(rawValue: raw) { return t }
        return QuestionaryValidation.inferredFieldType(questionId: questionId, fieldKey: key, label: label)
    }
}

public struct Question: Codable, Identifiable, Equatable {
    public let id: Int
    public let category: String?
    public let question: String
    public let type: String?
    public let answers: [String]
    public let placeholder: String?
    public let explanation: String?
    public let imageName: String?
    public let diagram: String?
    public let min: Double?
    public let max: Double?
    public let step: Double?
    public let unit: String?
    public let fields: [QuestionField]?
    public let inputType: String?
    public let minValue: Double?
    public let maxValue: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, category, question, type, answers, placeholder, explanation, imageName, diagram, min, max, step, unit, fields
        case inputType, minValue, maxValue
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        question = try container.decode(String.self, forKey: .question)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        answers = try container.decodeIfPresent([String].self, forKey: .answers) ?? []
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        diagram = try container.decodeIfPresent(String.self, forKey: .diagram)
        min = try container.decodeIfPresent(Double.self, forKey: .min)
        max = try container.decodeIfPresent(Double.self, forKey: .max)
        step = try container.decodeIfPresent(Double.self, forKey: .step)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        fields = try container.decodeIfPresent([QuestionField].self, forKey: .fields)
        inputType = try container.decodeIfPresent(String.self, forKey: .inputType)
        minValue = try container.decodeIfPresent(Double.self, forKey: .minValue)
        maxValue = try container.decodeIfPresent(Double.self, forKey: .maxValue)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encode(question, forKey: .question)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encode(answers, forKey: .answers)
        try container.encodeIfPresent(placeholder, forKey: .placeholder)
        try container.encodeIfPresent(explanation, forKey: .explanation)
        try container.encodeIfPresent(imageName, forKey: .imageName)
        try container.encodeIfPresent(diagram, forKey: .diagram)
        try container.encodeIfPresent(min, forKey: .min)
        try container.encodeIfPresent(max, forKey: .max)
        try container.encodeIfPresent(step, forKey: .step)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encodeIfPresent(fields, forKey: .fields)
        try container.encodeIfPresent(inputType, forKey: .inputType)
        try container.encodeIfPresent(minValue, forKey: .minValue)
        try container.encodeIfPresent(maxValue, forKey: .maxValue)
    }
    
    public var questionType: QuestionType {
        QuestionType(rawValue: type ?? "options") ?? .options
    }

    /// Effective input type for `.field` questions.
    public func resolvedSingleInputType() -> FieldInputType {
        if let raw = inputType, let t = FieldInputType(rawValue: raw) { return t }
        return QuestionaryValidation.inferredFieldType(questionId: id, fieldKey: "single", label: question)
    }
    
    public init(
        id: Int,
        category: String? = nil,
        question: String,
        type: String? = "options",
        answers: [String] = [],
        placeholder: String? = nil,
        explanation: String? = nil,
        imageName: String? = nil,
        diagram: String? = nil,
        min: Double? = nil,
        max: Double? = nil,
        step: Double? = nil,
        unit: String? = nil,
        fields: [QuestionField]? = nil,
        inputType: String? = nil,
        minValue: Double? = nil,
        maxValue: Double? = nil
    ) {
        self.id = id
        self.category = category
        self.question = question
        self.type = type
        self.answers = answers
        self.placeholder = placeholder
        self.explanation = explanation
        self.imageName = imageName
        self.diagram = diagram
        self.min = min
        self.max = max
        self.step = step
        self.unit = unit
        self.fields = fields
        self.inputType = inputType
        self.minValue = minValue
        self.maxValue = maxValue
    }
}

public struct Questionnaire: Codable {
    public let questions: [Question]
    
    public init(questions: [Question]) {
        self.questions = questions
    }
}

public class QuestionaryRepo {
    private let answersKey = "questionary.answers"
    private let completedKey = "questionary.isCompleted"
    private let sportKey = "questionary.selectedSport"
    private let completionDateKey = "questionary.completedDate"
    
    public init() {}
    
    public func loadQuestionnaire(for sport: String) -> [Question] {
        let filename = sport == "Basquet" ? "questionary_basquet" : "questionary_football"
        let folder = sport == "Basquet" ? "Basquet" : "Football"
        
        var url = Bundle.main.url(forResource: filename, withExtension: "json") ??
                  Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "Data/\(folder)")
        
        if url == nil {
            let possiblePaths = [
                "mhbasfut/Data/\(folder)/\(filename).json",
                "Data/\(folder)/\(filename).json"
            ]
            for p in possiblePaths {
                let fileURL = URL(fileURLWithPath: p)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    url = fileURL
                    break
                }
            }
        }
        
        guard let finalUrl = url,
              let data = try? Data(contentsOf: finalUrl),
              let questionnaire = try? JSONDecoder().decode(Questionnaire.self, from: data) else {
            #if DEBUG
            print("Error: Could not find or decode \(filename).json")
            #endif
            return []
        }
        
        return questionnaire.questions
    }
    
    // MARK: - Persistence
    
    public func saveAnswer(questionId: Int, answer: String) {
        var current = getSavedAnswers()
        current["\(questionId)"] = answer
        UserDefaults.standard.set(current, forKey: answersKey)
    }
    
    public func getSavedAnswers() -> [String: String] {
        return UserDefaults.standard.dictionary(forKey: answersKey) as? [String: String] ?? [:]
    }
    
    public func getAnswer(for questionId: Int) -> String? {
        return getSavedAnswers()["\(questionId)"]
    }
    
    public func saveCompletion(isCompleted: Bool) {
        UserDefaults.standard.set(isCompleted, forKey: completedKey)
        if isCompleted {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: completionDateKey)
        }
    }
    
    public func isQuestionnaireCompleted() -> Bool {
        return UserDefaults.standard.bool(forKey: completedKey)
    }
    
    public func saveSelectedSport(_ sport: String) {
        UserDefaults.standard.set(sport, forKey: sportKey)
    }
    
    public func getSelectedSport() -> String? {
        return UserDefaults.standard.string(forKey: sportKey)
    }
    
    public func resetQuestionnaire() {
        UserDefaults.standard.removeObject(forKey: answersKey)
        UserDefaults.standard.removeObject(forKey: completedKey)
        UserDefaults.standard.removeObject(forKey: sportKey)
        UserDefaults.standard.removeObject(forKey: completionDateKey)
        // NOTE: score keys are intentionally preserved here so "Rehacer test"
        // keeps the progress card. Use clearScore() only for "Eliminar datos".
    }

    // MARK: - Score persistence (kept across "Rehacer test", removed on "Eliminar datos")
    public func saveScore(_ score: QuestionaryScore) {
        if let data = try? JSONEncoder().encode(score) {
            UserDefaults.standard.set(data, forKey: QuestionaryScore.storageKey)
        }
    }

    public func getSavedScore() -> QuestionaryScore? {
        guard let data = UserDefaults.standard.data(forKey: QuestionaryScore.storageKey),
              let score = try? JSONDecoder().decode(QuestionaryScore.self, from: data) else {
            return nil
        }
        return score
    }

    public func clearScore() {
        UserDefaults.standard.removeObject(forKey: QuestionaryScore.storageKey)
    }

    // MARK: - Assigned physical plan (football pla / basket pla 1–4, from tests 36–40)

    public static let assignedPlanKey = "plan.assignedNumber"

    private static func assignedPlanKey(forSport sport: String?) -> String {
        guard let sport = sport, !sport.isEmpty else { return assignedPlanKey }
        return "\(assignedPlanKey).\(sport)"
    }

    public func saveAssignedPlan(_ number: Int, forSport sport: String?) {
        UserDefaults.standard.set(min(max(number, 1), 4), forKey: Self.assignedPlanKey(forSport: sport))
    }

    public func getAssignedPlan(forSport sport: String?) -> Int? {
        let key = Self.assignedPlanKey(forSport: sport)
        if UserDefaults.standard.object(forKey: key) != nil {
            return min(max(UserDefaults.standard.integer(forKey: key), 1), 4)
        }
        // Legacy fallback: plan saved before per-sport keys existed belongs to football.
        if sport == "Futbol", UserDefaults.standard.object(forKey: Self.assignedPlanKey) != nil {
            return min(max(UserDefaults.standard.integer(forKey: Self.assignedPlanKey), 1), 4)
        }
        return nil
    }
}

// MARK: - Input validation

public enum QuestionaryValidation {

    /// Infer the expected input type when the JSON does not declare one.
    public static func inferredFieldType(questionId: Int, fieldKey: String, label: String) -> FieldInputType {
        let key = fieldKey.lowercased()
        let lbl = label.lowercased()
        if key == "bedtime" || key == "waketime" || lbl.contains("hora") {
            return .time
        }
        if key == "height" || key == "weight" || lbl.contains("alçada") || lbl.contains("altura") || lbl.contains("pes") || lbl.contains("cm") || lbl.contains("kg") {
            return .decimal
        }
        if questionId == 1 || lbl.contains("edat") || lbl.contains("edad") || lbl.contains("age") {
            return .integer
        }
        return .text
    }

    public static func allowedCharacters(for type: FieldInputType) -> CharacterSet {
        switch type {
        case .integer:
            return CharacterSet(charactersIn: "0123456789")
        case .decimal:
            return CharacterSet(charactersIn: "0123456789.,")
        case .time:
            return CharacterSet(charactersIn: "0123456789:")
        case .text:
            return CharacterSet(charactersIn: "").inverted
        }
    }

    /// Validate a single raw string. Returns nil when valid, otherwise a user-facing message.
    public static func validate(value: String, type: FieldInputType, questionId: Int, fieldKey: String, minValue: Double? = nil, maxValue: Double? = nil) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Este campo es obligatorio."
        }
        switch type {
        case .text:
            return nil
        case .integer:
            let digits = trimmed.filter { $0.isNumber }
            // Reject anything that is not a plain integer (e.g. letters, symbols).
            if digits.count != trimmed.count {
                return "Introduce solo números (ej. 16)."
            }
            guard let num = Int(trimmed) else {
                return "Introduce un número válido."
            }
            let (lo, hi) = integerBounds(questionId: questionId, fieldKey: fieldKey, minValue: minValue, maxValue: maxValue)
            if num < lo || num > hi {
                return "Debe estar entre \(lo) y \(hi)."
            }
            return nil
        case .decimal:
            let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
            guard let num = Double(normalized) else {
                return "Introduce solo números."
            }
            let (lo, hi) = decimalBounds(questionId: questionId, fieldKey: fieldKey, minValue: minValue, maxValue: maxValue)
            if num < lo || num > hi {
                if hi.truncatingRemainder(dividingBy: 1) == 0 && lo.truncatingRemainder(dividingBy: 1) == 0 {
                    return "Debe estar entre \(Int(lo)) y \(Int(hi))."
                }
                return "Debe estar entre \(lo) y \(hi)."
            }
            return nil
        case .time:
            if !isValidTime(trimmed) {
                return "Formato de hora no válido (ej. 23:00)."
            }
            return nil
        }
    }

    public static func filter(_ string: String, for type: FieldInputType) -> String {
        switch type {
        case .text:
            return string
        case .integer:
            return string.filter { $0.isNumber }
        case .decimal:
            var result = ""
            var hasSeparator = false
            for ch in string {
                if ch.isNumber {
                    result.append(ch)
                } else if (ch == "." || ch == ",") && !hasSeparator {
                    hasSeparator = true
                    result.append(ch)
                }
            }
            return result
        case .time:
            var filtered = string.filter { $0.isNumber || $0 == ":" }
            // Keep at most one colon and max 5 chars (HH:MM)
            var seenColon = false
            var out = ""
            for ch in filtered {
                if ch == ":" {
                    if seenColon { continue }
                    seenColon = true
                }
                out.append(ch)
                if out.count >= 5 { break }
            }
            return out
        }
    }

    public static func isValidTime(_ s: String) -> Bool {
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              parts[0].count <= 2, parts[1].count == 2,
              (0...23).contains(h), (0...59).contains(m) else {
            return false
        }
        return true
    }

    private static func integerBounds(questionId: Int, fieldKey: String, minValue: Double?, maxValue: Double?) -> (Int, Int) {
        if let lo = minValue, let hi = maxValue { return (Int(lo), Int(hi)) }
        if questionId == 1 { return (5, 100) } // age
        return (0, 999)
    }

    private static func decimalBounds(questionId: Int, fieldKey: String, minValue: Double?, maxValue: Double?) -> (Double, Double) {
        if let lo = minValue, let hi = maxValue { return (lo, hi) }
        let key = fieldKey.lowercased()
        if key == "height" { return (100, 250) }
        if key == "weight" { return (25, 250) }
        return (0, 1000)
    }
}

// MARK: - Score / punctuation

public struct QuestionaryScore: Codable, Equatable {
    public static let storageKey = "questionary.score"
    public static let maxTotal: Double = 100

    public var total: Int
    public var perCategory: [String: Double]
    public var date: Date
    public var sport: String?

    public init(total: Int, perCategory: [String: Double], date: Date = Date(), sport: String? = nil) {
        self.total = total
        self.perCategory = perCategory
        self.date = date
        self.sport = sport
    }

    public static let categoryMax: [String: Double] = [
        "Son i descans": 25,
        "Nutrició i hidratació": 20,
        "Recuperació muscular": 20,
        "Prevenció de lesions": 15,
        "Salut mental i benestar": 10,
        "Hàbits saludables": 10
    ]

    public func points(for category: String) -> Double {
        perCategory[category] ?? 0
    }

    public func maxPoints(for category: String) -> Double {
        Self.categoryMax[category] ?? 0
    }

    public var levelText: String {
        switch total {
        case 90...100: return "Entrenamiento invisible excelente"
        case 80..<90: return "Entrenamiento invisible muy bueno"
        case 70..<80: return "Entrenamiento invisible bueno"
        case 60..<70: return "Entrenamiento invisible mejorable"
        default: return "Entrenamiento invisible deficiente"
        }
    }
}

public enum QuestionaryScorer {

    /// Compute a 0–100 score from saved answers. Personal data (ids 1–9) and
    /// free time fields (id 12) are excluded; every other question contributes
    /// its category share weighted by how healthy the answer is (0…1).
    public static func compute(questions: [Question], answers: [String: String], sport: String? = nil) -> QuestionaryScore {
        // Group scored questions by category to split max points evenly.
        var byCategory: [String: [Question]] = [:]
        for q in questions {
            guard isScored(question: q) else { continue }
            let cat = q.category ?? "General"
            byCategory[cat, default: []].append(q)
        }
        var perCategory: [String: Double] = [:]
        var total: Double = 0
        for (cat, qs) in byCategory {
            let maxForCat = QuestionaryScore.categoryMax[cat] ?? 0
            guard !qs.isEmpty, maxForCat > 0 else { continue }
            let weight = maxForCat / Double(qs.count)
            var earned: Double = 0
            for q in qs {
                let raw = answers["\(q.id)"]
                earned += factor(question: q, rawAnswer: raw) * weight
            }
            perCategory[cat] = (earned * 10).rounded() / 10
            total += earned
        }
        let roundedTotal = Int(max(0, min(100, (total).rounded())))
        return QuestionaryScore(total: roundedTotal, perCategory: perCategory, date: Date(), sport: sport)
    }

    public static func isScored(question: Question) -> Bool {
        // Personal / sport context questions don't affect the health score,
        // and bedtime/waketime free text is informative only.
        if (1...9).contains(question.id) { return false }
        if question.id == 12 { return false }
        // Physical performance tests (ids 36+) are informative only.
        if question.id >= 36 { return false }
        return true
    }

    // MARK: - Per-question 0…1 factor

    static func factor(question: Question, rawAnswer: String?) -> Double {
        guard let raw = rawAnswer, !raw.isEmpty else { return 0 }
        switch question.questionType {
        case .slider:
            guard let v = Double(raw) else { return 0 }
            return sliderFactor(id: question.id, value: v)
        case .options:
            return optionsFactor(question: question, answer: raw)
        case .field, .fields:
            // Informative fields that are still scored default to full marks when filled.
            return raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1.0
        }
    }

    static func optionsFactor(question: Question, answer: String) -> Double {
        let idx = question.answers.firstIndex(of: answer) ?? -1
        guard idx >= 0, question.answers.count > 1 else { return idx >= 0 ? 1.0 : 0 }
        let n = question.answers.count
        // Q14 is ordered worst→best, everything else best→worst.
        if question.id == 14 {
            return Double(idx) / Double(n - 1)
        }
        if question.id == 34 {
            // "Cap molèstia" = full, any specific zone = partial.
            return idx == 0 ? 1.0 : 0.4
        }
        return 1.0 - (Double(idx) / Double(n - 1))
    }

    static func sliderFactor(id: Int, value v: Double) -> Double {
        switch id {
        case 10: // sleep hours, optimal 7–9
            if v >= 7 && v <= 9 { return 1.0 }
            if (v >= 6 && v < 7) || (v > 9 && v <= 10) { return 0.7 }
            if (v >= 5 && v < 6) || (v > 10 && v <= 11) { return 0.4 }
            return 0.15
        case 11: // sleep quality 1–5, higher better
            return clamp((v - 1) / 4)
        case 16: // water litres, optimal ~1.5–3
            if v >= 1.5 && v <= 3 { return 1.0 }
            if (v >= 1 && v < 1.5) || (v > 3 && v <= 3.5) { return 0.7 }
            return 0.35
        case 19: // pain 1–10, lower better
            return clamp((10 - v) / 9)
        case 22: // rest days, 1–2 optimal
            if v == 1 || v == 2 { return 1.0 }
            if v == 0 || v == 3 { return 0.6 }
            return 0.3
        case 23: // stress 1–10, lower better
            return clamp((10 - v) / 9)
        case 24, 25: // motivation / mood 1–10, higher better
            return clamp((v - 1) / 9)
        case 27: // screen hours 0–4, lower better
            return clamp((4 - v) / 4)
        default:
            return 1.0
        }
    }

    static func clamp(_ v: Double) -> Double {
        max(0, min(1, v))
    }
}

// MARK: - Physical plan assignment (football)

// Maps the 5 physical tests (ids 36–40) to a plan level 1–4 following the
// reference table, then picks the winning plan by majority vote
// (ties go to the lower / easier plan).
public enum PhysicalPlanClassifier {

    public static let testIds = [36, 37, 38, 39, 40]

    /// Level 1–4 for a single test, or nil when the answer is missing/invalid.
    public static func levelFor(questionId: Int, rawAnswer: String?) -> Int? {
        guard let raw = rawAnswer?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        // Accept both "5.5" and "5,5" (decimalPad offers "," in Catalan locale).
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        guard let v = Double(normalized) else { return nil }
        switch questionId {
        case 36: // Sargent vertical jump, cm — higher is better
            if v < 30 { return 1 }
            if v < 40 { return 2 }
            if v < 50 { return 3 }
            return 4
        case 37: // Single-leg horizontal jump, cm — higher is better
            if v < 130 { return 1 }
            if v < 150 { return 2 }
            if v < 170 { return 3 }
            return 4
        case 38: // 30 m sprint, seconds — lower is better
            // Table: >5.5 / 5.1–5.5 / 4.7–5.0 / ≤4.6 (gap values fall through down)
            if v > 5.5 { return 1 }
            if v > 5.0 { return 2 }
            if v > 4.6 { return 3 }
            return 4
        case 39: // Squats in 60 s, reps — higher is better
            if v < 25 { return 1 }
            if v < 35 { return 2 }
            if v < 45 { return 3 }
            return 4
        case 40: // T-test agility, seconds — lower is better
            // Table: >12.0 / 11.0–12.0 / 10.0–10.9 / <10.0
            if v > 12.0 { return 1 }
            if v >= 11.0 { return 2 }
            if v >= 10.0 { return 3 }
            return 4
        default:
            return nil
        }
    }

    /// Winning plan 1–4 from saved answers (`["36": "35", ...]`).
    /// Majority vote; ties resolve to the lower plan. Defaults to 1.
    public static func assignedPlan(answers: [String: String]) -> Int {
        var votes = [0, 0, 0, 0, 0] // index 1–4 used
        for id in testIds {
            if let level = levelFor(questionId: id, rawAnswer: answers["\(id)"]) {
                votes[level] += 1
            }
        }
        let best = (1...4).max(by: { votes[$0] < votes[$1] }) ?? 1
        // max(by:) keeps the first (lowest) on ties — the safer plan wins.
        let topVotes = votes[best]
        if topVotes == 0 { return 1 }
        return (1...4).first(where: { votes[$0] == topVotes }) ?? best
    }
}
