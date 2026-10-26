//
//  questionaryIcons.swift
//  mhbasfut
//
//  Per-question SF Symbol icons for the questionnaire option buttons.
//  Replaces the generic "square.dashed" placeholder with meaningful icons.
//

import Foundation

public enum QuestionIconProvider {

    /// Icon for a given option answer. Falls back to the question-level icon
    /// when there is no answer-specific mapping.
    public static func iconName(question: Question, answer: String, sport: String? = nil) -> String {
        if let specific = answerSpecificIcon(questionId: question.id, answer: answer, sport: sport) {
            return specific
        }
        return questionIcon(questionId: question.id)
    }

    // MARK: - Question-level fallback icons

    public static func questionIcon(questionId: Int) -> String {
        switch questionId {
        case 1: return "person.fill" // age
        case 2: return "person.crop.circle.fill" // sex
        case 3: return "ruler.fill" // height / weight
        case 4: return "soccerball" // modality
        case 5: return "medal.fill" // category
        case 6: return "clock.fill" // experience
        case 7: return "calendar" // training days (slider)
        case 8: return "clock" // training hours (slider)
        case 9: return "target" // objective
        case 10: return "moon.stars.fill" // sleep hours
        case 11: return "star.fill" // sleep quality
        case 12: return "bed.double.fill" // bedtime / waketime
        case 13: return "sunrise.fill" // rest feeling
        case 14: return "fork.knife" // meals
        case 15: return "leaf.fill" // fruit & veg
        case 16: return "drop.fill" // water
        case 17: return "cup.and.saucer.fill" // pre-training meal
        case 18: return "takeoutbag.and.cup.and.straw.fill" // recovery meal
        case 19: return "bolt.heart.fill" // muscle pain
        case 20: return "timer" // stretching
        case 21: return "cross.case.fill" // recovery tools
        case 22: return "bed.double.fill" // rest days
        case 23: return "brain.head.profile" // stress
        case 24: return "flame.fill" // motivation
        case 25: return "face.smiling.fill" // mood
        case 26: return "cloud.fill" // mental fatigue
        case 27: return "tv.fill" // screen time
        case 28: return "bolt.fill" // energy drinks
        case 29: return "calendar.badge.clock" // sleep schedule
        case 30: return "flame.fill" // warmup
        case 31: return "wind" // cooldown
        case 32: return "shield.fill" // prevention
        case 33: return "cross.case.fill" // injuries
        case 34: return "figure.stand" // affected zone
        case 35: return "calendar" // days out
        default: return "questionmark.circle.fill"
        }
    }

    // MARK: - Answer-specific icons

    private static func answerSpecificIcon(questionId: Int, answer: String, sport: String?) -> String? {
        let a = answer
        switch questionId {
        case 2:
            if a.contains("Mascul") { return "figure.stand" }
            if a.contains("Fem") { return "figure.stand.dress" }
            return "person.crop.circle.badge.questionmark"
        case 4:
            if a.contains("11") || a.contains("5x5") { return "person.3.fill" }
            if a.contains("7") || a.contains("3x3") { return "person.2.fill" }
            if a.contains("Sala") || a.contains("Mini") { return "house.fill" }
            return sport == "Basquet" ? "basketball.fill" : "soccerball"
        case 5:
            if a.contains("Infantil") { return "person.fill" }
            if a.contains("Cadet") { return "person.2.fill" }
            if a.contains("Juvenil") { return "figure.run" }
            return "trophy.fill"
        case 6:
            if a.contains("Menys") { return "clock" }
            if a.contains("1 a 3") { return "star" }
            if a.contains("4 a 6") { return "star.fill" }
            return "trophy.fill"
        case 9:
            if a.contains("rendiment") || a.contains("velocitat") { return "bolt.fill" }
            if a.contains("lesions") || a.contains("musculatura") { return "shield.fill" }
            if a.contains("xim") || a.contains("competitiu") { return "trophy.fill" }
            return "heart.fill"
        case 13:
            if a.contains("Molt descansat") { return "sun.max.fill" }
            if a.contains("Prou descansat") { return "sunrise.fill" }
            if a.contains("cansat / fatiga") || a.contains("Una mica") { return "cloud.sun.fill" }
            return "cloud.fill"
        case 14:
            if a.hasPrefix("2 ") { return "2.circle" }
            if a.hasPrefix("3 ") { return "3.circle" }
            if a.hasPrefix("4 ") { return "4.circle" }
            return "fork.knife"
        case 15:
            if a.contains("3 o m") { return "leaf.fill" }
            if a.contains("1 o 2") { return "leaf" }
            if a.contains("Alguns") { return "calendar" }
            return "xmark.circle"
        case 17:
            if a.contains("Sempre") { return "checkmark.circle.fill" }
            if a.contains("majoria") { return "checkmark.circle" }
            if a.contains("vegades") || a.contains("quelcom") { return "clock" }
            return "xmark.circle"
        case 18:
            if a.contains("Sempre") { return "checkmark.circle.fill" }
            if a.contains("Sovint") { return "checkmark.circle" }
            if a.contains("vegades") { return "clock" }
            return "xmark.circle"
        case 20:
            if a.contains("Més de 15") { return "timer" }
            if a.contains("5 i 15") { return "stopwatch" }
            if a.contains("Menys") { return "hourglass" }
            return "xmark.circle"
        case 21:
            if a.contains("habitualment") { return "checkmark.circle.fill" }
            if a.contains("Ocasionalment") { return "clock" }
            if a.contains("Rarament") { return "calendar" }
            return "xmark.circle"
        case 26:
            if a.contains("Gens") { return "sun.max.fill" }
            if a.contains("Lleu") { return "cloud.sun.fill" }
            if a.contains("Moderat") { return "cloud.fill" }
            return "cloud.bolt.rain.fill"
        case 28:
            if a.contains("Cap") { return "checkmark.shield.fill" }
            if a.contains("1 o 2") { return "2.circle" }
            if a.contains("3 a 5") { return "5.circle" }
            return "exclamationmark.triangle.fill"
        case 29:
            if a.contains("Sempre") { return "checkmark.circle.fill" }
            if a.contains("Gaireb") { return "calendar" }
            if a.contains("Variable") { return "shuffle" }
            return "questionmark.circle"
        case 30:
            if a.contains("complet") || a.contains("mobilitat") { return "flame.fill" }
            if a.contains("breu") || a.contains("5 minuts") { return "timer" }
            if a.contains("pilota") { return sport == "Basquet" ? "basketball.fill" : "soccerball" }
            return "xmark.circle"
        case 31:
            if a.contains("sempre") || a.contains("trot") { return "wind" }
            if a.contains("partits") || a.contains("intensos") { return "trophy" }
            if a.contains("vegades") { return "clock" }
            return "xmark.circle"
        case 32:
            if a.contains("2 o m") { return "shield.fill" }
            if a.contains("Un cop") { return "shield" }
            if a.contains("mol") { return "bandage" }
            return "xmark.shield"
        case 33:
            if a.contains("cap lesi") || a.contains("No, cap") { return "checkmark.shield.fill" }
            if a.contains("lleus") { return "bandage" }
            if a.contains("aturar") { return "cross.case.fill" }
            return "exclamationmark.triangle.fill"
        case 34:
            if a.contains("Cap mol") { return "checkmark.circle.fill" }
            return "bandage"
        case 35:
            if a.contains("0 dies") { return "checkmark.circle.fill" }
            if a.contains("1 a 7") { return "bandage" }
            if a.contains("1 a 3") { return "cross.case" }
            if a.contains("1 a 2") { return "calendar" }
            return "exclamationmark.triangle.fill"
        default:
            return nil
        }
    }
}
