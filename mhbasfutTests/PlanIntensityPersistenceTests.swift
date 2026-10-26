//
//  PlanIntensityPersistenceTests.swift
//  mhbasfutTests
//
//  Plan 1 – unit tests for plan.intensity.<day>.<stageIndex> persistence.
//  Requires the mhbasfutTests unit-test target (host: mhbasfut app).
//
//  Uses day 14 + stageIndex 10: resetPlanData() covers stages 0...10, while
//  real days never exceed ~7 stages, so these keys cannot collide with
//  production data. Every test removes its keys in tearDown.
//

import XCTest
@testable import mhbasfut

final class PlanIntensityPersistenceTests: XCTestCase {

    private let repo = PlanRepo.shared
    private let day = 14
    private let stage = 10

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: repo.intensityKey(day: day, stageIndex: stage))
        super.tearDown()
    }

    func testMissingKeyReturnsNil() {
        UserDefaults.standard.removeObject(forKey: repo.intensityKey(day: day, stageIndex: stage))
        XCTAssertNil(repo.getIntensity(day: day, stageIndex: stage))
        XCTAssertFalse(repo.hasIntensityRating(day: day, stageIndex: stage))
    }

    func testSaveLoadRoundTrip() {
        repo.saveIntensity(day: day, stageIndex: stage, value: 7)
        XCTAssertEqual(repo.getIntensity(day: day, stageIndex: stage), 7)
        XCTAssertTrue(repo.hasIntensityRating(day: day, stageIndex: stage))
    }

    func testKeyPattern() {
        XCTAssertEqual(repo.intensityKey(day: 3, stageIndex: 2), "plan.intensity.3.2")
    }

    func testSaveClampsOutOfRange() {
        repo.saveIntensity(day: day, stageIndex: stage, value: -3)
        XCTAssertEqual(repo.getIntensity(day: day, stageIndex: stage), 0)
        repo.saveIntensity(day: day, stageIndex: stage, value: 15)
        XCTAssertEqual(repo.getIntensity(day: day, stageIndex: stage), 10)
    }

    func testOverwriteKeepsLatestValue() {
        repo.saveIntensity(day: day, stageIndex: stage, value: 4)
        repo.saveIntensity(day: day, stageIndex: stage, value: 9)
        XCTAssertEqual(repo.getIntensity(day: day, stageIndex: stage), 9)
    }

    func testStagesAreIndependent() {
        let otherStage = 9
        UserDefaults.standard.removeObject(forKey: repo.intensityKey(day: day, stageIndex: otherStage))
        repo.saveIntensity(day: day, stageIndex: stage, value: 8)
        XCTAssertNil(repo.getIntensity(day: day, stageIndex: otherStage))
        XCTAssertEqual(repo.getIntensity(day: day, stageIndex: stage), 8)
        UserDefaults.standard.removeObject(forKey: repo.intensityKey(day: day, stageIndex: otherStage))
    }

    func testBoundaryValuesZeroAndTen() {
        repo.saveIntensity(day: day, stageIndex: stage, value: 0)
        XCTAssertEqual(repo.getIntensity(day: day, stageIndex: stage), 0)
        repo.saveIntensity(day: day, stageIndex: stage, value: 10)
        XCTAssertEqual(repo.getIntensity(day: day, stageIndex: stage), 10)
    }
}
