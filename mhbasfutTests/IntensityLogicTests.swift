//
//  IntensityLogicTests.swift
//  mhbasfutTests
//
//  Plan 1 – unit tests for the Borg 0–10 → recovery-exercise mapping.
//  Requires the mhbasfutTests unit-test target (host: mhbasfut app).
//

import XCTest
@testable import mhbasfut

final class IntensityLogicTests: XCTestCase {

    // MARK: - Borg options

    func testBorgOptionsCountAndDescendingOrder() {
        XCTAssertEqual(IntensityLogic.borgOptions.count, 11)
        XCTAssertEqual(IntensityLogic.borgOptions.map(\.value), [10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0])
    }

    func testBorgOptionsExactSpanishLabels() {
        let labels = Dictionary(uniqueKeysWithValues: IntensityLogic.borgOptions.map { ($0.value, $0.label) })
        XCTAssertEqual(labels[10], "Extreme (10)")
        XCTAssertEqual(labels[9], "Maximum (9)")
        XCTAssertEqual(labels[8], "Very, very heavy (8)")
        XCTAssertEqual(labels[7], "Very heavy (7)")
        XCTAssertEqual(labels[6], "Heavier (6)")
        XCTAssertEqual(labels[5], "Heavy (5)")
        XCTAssertEqual(labels[4], "Somewhat heavy (4)")
        XCTAssertEqual(labels[3], "Light (3)")
        XCTAssertEqual(labels[2], "Very light (2)")
        XCTAssertEqual(labels[1], "Very, very light (1)")
        XCTAssertEqual(labels[0], "Rest (0)")
    }

    // MARK: - Intensity → count mapping (every band + edges)

    func testExerciseCountAllBands() {
        XCTAssertEqual(IntensityLogic.exerciseCount(for: 0), 2)
        XCTAssertEqual(IntensityLogic.exerciseCount(for: 1), 2)
        XCTAssertEqual(IntensityLogic.exerciseCount(for: 2), 2)
        XCTAssertEqual(IntensityLogic.exerciseCount(for: 3), 3)
        XCTAssertEqual(IntensityLogic.exerciseCount(for: 4), 3)
        XCTAssertEqual(IntensityLogic.exerciseCount(for: 5), 4)
        XCTAssertEqual(IntensityLogic.exerciseCount(for: 6), 4)
        XCTAssertEqual(IntensityLogic.exerciseCount(for: 7), 5)
        XCTAssertEqual(IntensityLogic.exerciseCount(for: 8), 5)
        XCTAssertEqual(IntensityLogic.exerciseCount(for: 9), 6)
        XCTAssertEqual(IntensityLogic.exerciseCount(for: 10), 6)
    }

    func testExerciseCountClampsOutOfRange() {
        XCTAssertEqual(IntensityLogic.exerciseCount(for: -1), 2)
        XCTAssertEqual(IntensityLogic.exerciseCount(for: 11), 6)
        XCTAssertEqual(IntensityLogic.exerciseCount(for: -100), 2)
        XCTAssertEqual(IntensityLogic.exerciseCount(for: 100), 6)
    }

    // MARK: - Prefix slices

    func testExercisesAreContiguousPrefix() {
        for intensity in 0...10 {
            let got = IntensityLogic.exercises(for: intensity)
            let expected = Array(IntensityLogic.recoveryExercises.prefix(IntensityLogic.exerciseCount(for: intensity)))
            XCTAssertEqual(got, expected, "intensity \(intensity)")
            // Contiguity: ids always start at 0 with no gaps.
            XCTAssertEqual(got.map(\.id), Array(0..<got.count), "intensity \(intensity)")
        }
    }

    func testRecoveryCatalogHasSixExercises() {
        XCTAssertEqual(IntensityLogic.recoveryExercises.count, 6)
        XCTAssertEqual(IntensityLogic.recoveryExercises.first?.name, "Estiramiento de isquiotibiales")
        XCTAssertEqual(IntensityLogic.recoveryExercises.last?.name, "Respiración diafragmática")
    }

    // MARK: - Training-stage trigger

    func testIsTrainingWithExercises() {
        XCTAssertTrue(IntensityLogic.isTrainingWithExercises(
            kind: .training(exercises: [PlanExercise(id: 0, name: "X", detail: "", desc: "", imageName: "")])
        ))
        XCTAssertFalse(IntensityLogic.isTrainingWithExercises(kind: .training(exercises: [])))
        XCTAssertFalse(IntensityLogic.isTrainingWithExercises(
            kind: .meal(options: [PlanMealOption(id: 0, name: "X", imageName: "y")])
        ))
    }
}
