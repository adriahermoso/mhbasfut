//
//  IntensityLogic.swift
//  mhbasfut
//
//  Plan 1 – Intensity valuation (Borg 0–10) pure logic.
//  No persistence, no UI: intensity → recovery-exercise mapping only.
//

import Foundation

/// One selectable Borg row (value + exact Spanish label, highest to lowest).
public struct IntensityBorgOption: Identifiable, Equatable {
    public let id: Int
    public let value: Int
    public let label: String

    public init(value: Int, label: String) {
        self.id = value
        self.value = value
        self.label = label
    }
}

/// One recovery/stretch exercise shown after the intensity is rated.
public struct IntensityRecoveryExercise: Identifiable, Equatable {
    public let id: Int
    public let name: String
    public let detail: String

    public init(id: Int, name: String, detail: String) {
        self.id = id
        self.name = name
        self.detail = detail
    }
}

public enum IntensityLogic {
    /// Exact Spanish labels, highest (10) to lowest (0). Order matters.
    public static let borgOptions: [IntensityBorgOption] = [
        IntensityBorgOption(value: 10, label: "Extreme (10)"),
        IntensityBorgOption(value: 9, label: "Maximum (9)"),
        IntensityBorgOption(value: 8, label: "Very, very heavy (8)"),
        IntensityBorgOption(value: 7, label: "Very heavy (7)"),
        IntensityBorgOption(value: 6, label: "Heavier (6)"),
        IntensityBorgOption(value: 5, label: "Heavy (5)"),
        IntensityBorgOption(value: 4, label: "Somewhat heavy (4)"),
        IntensityBorgOption(value: 3, label: "Light (3)"),
        IntensityBorgOption(value: 2, label: "Very light (2)"),
        IntensityBorgOption(value: 1, label: "Very, very light (1)"),
        IntensityBorgOption(value: 0, label: "Rest (0)"),
    ]

    /// The 6 recovery exercises. Always show a contiguous prefix of this list.
    public static let recoveryExercises: [IntensityRecoveryExercise] = [
        IntensityRecoveryExercise(
            id: 0,
            name: "Estiramiento de isquiotibiales",
            detail: "Mantén 30 segundos cada pierna, sin rebotes."
        ),
        IntensityRecoveryExercise(
            id: 1,
            name: "Estiramiento de cuádriceps",
            detail: "Mantén 30 segundos cada pierna, rodilla apuntando al suelo."
        ),
        IntensityRecoveryExercise(
            id: 2,
            name: "Estiramiento de gemelos",
            detail: "Mantén 30 segundos cada pierna, talón pegado al suelo."
        ),
        IntensityRecoveryExercise(
            id: 3,
            name: "Movilidad de cadera 90/90",
            detail: "30 segundos cada lado, espalda recta."
        ),
        IntensityRecoveryExercise(
            id: 4,
            name: "Apertura de pecho y hombros",
            detail: "30 segundos, manos entrelazadas detrás de la espalda."
        ),
        IntensityRecoveryExercise(
            id: 5,
            name: "Respiración diafragmática",
            detail: "1 minuto, inhalar 4 s / exhalar 6 s, manos en el abdomen."
        ),
    ]

    /// Number of recovery exercises for an intensity, exactly per spec:
    /// 0–2 → 2, 3–4 → 3, 5–6 → 4, 7–8 → 5, 9–10 → 6.
    /// Out-of-range values are clamped, never crash.
    public static func exerciseCount(for intensity: Int) -> Int {
        let v = min(max(intensity, 0), 10)
        switch v {
        case 0...2: return 2
        case 3...4: return 3
        case 5...6: return 4
        case 7...8: return 5
        default: return 6
        }
    }

    /// Contiguous prefix of the 6-exercise list for the given intensity.
    public static func exercises(for intensity: Int) -> [IntensityRecoveryExercise] {
        Array(recoveryExercises.prefix(exerciseCount(for: intensity)))
    }

    /// True when the stage holds a training kind with at least one exercise.
    /// Mirrors PlanStep.Kind so the trigger stays in one testable place.
    public static func isTrainingWithExercises(kind: PlanStep.Kind) -> Bool {
        if case .training(let exercises) = kind {
            return !exercises.isEmpty
        }
        return false
    }
}
