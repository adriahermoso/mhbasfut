//
//  AdminOverrideTests.swift
//  mhbasfutTests
//
//  Edición manual desde el panel web: revisión ISO-8601, aplicación de
//  overrides sobre UserDefaults, no-repetición (idempotencia) y
//  compatibilidad del exporter v2 con ficheros v1.
//

import XCTest
@testable import mhbasfut

final class AdminOverrideTests: XCTestCase {

    private var savedDomain: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        if let bundleID = Bundle.main.bundleIdentifier,
           let domain = UserDefaults.standard.persistentDomain(forName: bundleID) {
            savedDomain = domain
        }
        clearKeys()
    }

    override func tearDown() {
        clearKeys()
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.setPersistentDomain(savedDomain, forName: bundleID)
        }
        super.tearDown()
    }

    private func clearKeys() {
        let d = UserDefaults.standard
        let keys = [
            "questionary.isCompleted", "questionary.selectedSport",
            "plan.assignedNumber.Futbol", "plan.assignedNumber.Basquet",
            "plan.startDate", "plan.cycleNumber", "plan.completedCycles",
            "plan.programCompleted.Futbol", "plan.programCompleted.Basquet",
            "plan.lastSport", "plan.archives", "rewards.coins",
            "streak.completedDates", "questionary.answers",
            AdminOverrideApplier.lastAppliedRevisionKey,
        ]
        for k in keys { d.removeObject(forKey: k) }
        for day in 1...14 {
            d.removeObject(forKey: "plan.dayCompleted.\(day)")
            d.removeObject(forKey: "plan.completedStages.\(day)")
            for s in 0...6 { d.removeObject(forKey: "plan.selectedMeal.\(day).\(s)") }
            for s in 0...10 { d.removeObject(forKey: "plan.intensity.\(day).\(s)") }
        }
    }

    // MARK: - Revisión & comparación

    func testParseISO8601WithoutMilliseconds() {
        let date = AdminOverrideApplier.parseISO8601("2026-10-17T12:34:56Z")
        XCTAssertNotNil(date)
        XCTAssertNil(AdminOverrideApplier.parseISO8601("garbage"))
    }

    func testShouldApplyRules() {
        XCTAssertTrue(AdminOverrideApplier.shouldApply(
            remoteRevision: "2026-10-17T12:00:00Z", appliedRevision: nil))
        XCTAssertTrue(AdminOverrideApplier.shouldApply(
            remoteRevision: "2026-10-17T12:00:01Z", appliedRevision: "2026-10-17T12:00:00Z"))
        XCTAssertFalse(AdminOverrideApplier.shouldApply(
            remoteRevision: "2026-10-17T12:00:00Z", appliedRevision: "2026-10-17T12:00:00Z"))
        XCTAssertFalse(AdminOverrideApplier.shouldApply(
            remoteRevision: "2026-10-16T12:00:00Z", appliedRevision: "2026-10-17T12:00:00Z"))
        XCTAssertFalse(AdminOverrideApplier.shouldApply(remoteRevision: nil, appliedRevision: nil))
        XCTAssertFalse(AdminOverrideApplier.shouldApply(remoteRevision: "nope", appliedRevision: nil))
    }

    // MARK: - Aplicación de overrides

    func testApplyWritesAllSupportedKeys() {
        let overrides: [String: Any] = [
            "questionnaireCompleted": true,
            "sport": "Basquet",
            "planNumber": 3,
            "planStartDate": "2026-10-10T08:00:00Z",
            "cycleNumber": 2,
            "completedCycles": 1,
            "programCompleted": false,
            "coins": 777,
            "streakCompletedDates": ["2026-10-01T22:00:00Z", "2026-10-02T22:00:00Z"],
            "answers": ["1": "16", "36": "55"],
            "days": [
                "2": [
                    "completed": true,
                    "completedStages": [0, 1, 2],
                    "selectedMeals": ["0": 1, "6": 0],
                    "intensities": ["1": 7, "99": 5],
                ]
            ],
        ]
        let applied = AdminOverrideApplier.apply(overrides: overrides)
        let d = UserDefaults.standard

        XCTAssertTrue(applied.contains("questionnaireCompleted"))
        XCTAssertTrue(d.bool(forKey: "questionary.isCompleted"))
        XCTAssertEqual(d.string(forKey: "questionary.selectedSport"), "Basquet")
        XCTAssertEqual(d.integer(forKey: "plan.assignedNumber.Basquet"), 3)
        XCTAssertEqual(d.double(forKey: "plan.startDate"), 1_791_619_200, accuracy: 1)
        XCTAssertEqual(d.integer(forKey: "plan.cycleNumber"), 2)
        XCTAssertEqual(d.integer(forKey: "plan.completedCycles"), 1)
        XCTAssertEqual(d.integer(forKey: "rewards.coins"), 777)

        let streak = d.array(forKey: "streak.completedDates") as? [Double]
        XCTAssertEqual(streak?.count, 2)

        let answers = d.dictionary(forKey: "questionary.answers") as? [String: String]
        XCTAssertEqual(answers?["36"], "55")

        XCTAssertTrue(d.bool(forKey: "plan.dayCompleted.2"))
        XCTAssertEqual(d.array(forKey: "plan.completedStages.2") as? [Int], [0, 1, 2])
        XCTAssertEqual(d.integer(forKey: "plan.selectedMeal.2.0"), 1)
        XCTAssertEqual(d.integer(forKey: "plan.intensity.2.1"), 7)
        XCTAssertNil(d.object(forKey: "plan.intensity.2.99"), "Stage fuera de rango se ignora")
        XCTAssertNil(d.object(forKey: "plan.dayCompleted.99"), "Día fuera de rango se ignora")
    }

    func testApplyIgnoresInvalidValues() {
        let overrides: [String: Any] = [
            "sport": "Tenis",
            "planNumber": "no-number",
            "planStartDate": "ayer",
            "coins": "muchas",
        ]
        let applied = AdminOverrideApplier.apply(overrides: overrides)
        XCTAssertTrue(applied.isEmpty)
        XCTAssertNil(UserDefaults.standard.string(forKey: "questionary.selectedSport"))
        XCTAssertNil(UserDefaults.standard.object(forKey: "rewards.coins"))
        XCTAssertNil(UserDefaults.standard.object(forKey: "plan.assignedNumber.Futbol"))
    }

    // MARK: - Servicio de sync: aplicar ediciones pendientes

    func testApplyPendingAdminEditsFromUserJSON() {
        let json = """
        {
          "schemaVersion": 2,
          "username": "TestUser",
          "adminRevision": "2026-10-17T09:00:00Z",
          "adminOverrides": {
            "coins": 123,
            "streakCompletedDates": ["2026-10-10T22:00:00Z"]
          }
        }
        """.data(using: .utf8)!

        let applied = GitHubSyncService.applyPendingAdminEdits(fromRemoteUserJSON: json)
        XCTAssertTrue(applied)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "rewards.coins"), 123)
        XCTAssertEqual(AdminOverrideApplier.appliedRevision(), "2026-10-17T09:00:00Z")

        // Misma revisión → no se vuelve a aplicar
        XCTAssertFalse(GitHubSyncService.applyPendingAdminEdits(fromRemoteUserJSON: json))

        // Revisión más nueva con otro cambio → se aplica encima
        let newer = """
        {
          "adminRevision": "2026-10-17T10:00:00Z",
          "adminOverrides": { "coins": 500 }
        }
        """.data(using: .utf8)!
        XCTAssertTrue(GitHubSyncService.applyPendingAdminEdits(fromRemoteUserJSON: newer))
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "rewards.coins"), 500)
    }

    func testApplyPendingIgnoresJSONWithoutAdminEdits() {
        let plain = #"{"schemaVersion": 2, "username": "TestUser"}"#.data(using: .utf8)!
        XCTAssertFalse(GitHubSyncService.applyPendingAdminEdits(fromRemoteUserJSON: plain))
    }

    func testDecodeContentsAPIRawAndBase64() {
        let raw = #"{"a": 1}"#.data(using: .utf8)!
        XCTAssertEqual(GitHubSyncService.decodeContentsAPIData(raw), raw)

        let payload = #"{"a": 1}"#
        let b64 = payload.data(using: .utf8)!.base64EncodedString()
        let wrapped = "{\"encoding\":\"base64\",\"content\":\"\(b64)\"}".data(using: .utf8)!
        XCTAssertEqual(GitHubSyncService.decodeContentsAPIData(wrapped), payload.data(using: .utf8)!)
    }

    // MARK: - Exporter v2

    func testSnapshotV2RoundTripWithCycleFields() {
        let archive = PlanRepo.PlanCycleArchive(
            sport: "Futbol",
            planNumber: 1,
            cycleNumber: 1,
            startDate: Date(timeIntervalSince1970: 1_750_000_000),
            endDate: Date(timeIntervalSince1970: 1_751_209_600),
            allDaysCompleted: true,
            recovered: false,
            days: [DaySnapshot(day: 1, completed: true, completedStages: [0, 1], selectedMeals: ["0": 2], intensities: ["1": 6])]
        )
        let snapshot = UserDataSnapshot(
            exportedAt: Date(timeIntervalSince1970: 1_751_200_000),
            username: "TestUser",
            cycleNumber: 2,
            completedCycles: 1,
            programCompleted: false,
            lastSport: "Futbol",
            planArchives: [archive],
            adminRevision: "2026-10-17T09:00:00Z"
        )
        let json = try! UserDataExporter.jsonData(for: snapshot)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try! decoder.decode(UserDataSnapshot.self, from: json)
        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.schemaVersion, 2)
        XCTAssertEqual(decoded.planArchives.first?.days.first?.selectedMeals["0"], 2)
    }

    func testSnapshotDecodesLegacyV1File() {
        // Fichero v1 real (sin campos de ciclo): debe decodificar con defaults.
        let v1 = """
        {
          "schemaVersion": 1,
          "exportedAt": "2026-10-01T10:00:00Z",
          "username": "HugoMartinez",
          "sport": "Futbol",
          "questionnaireCompleted": true,
          "questionnaireCompletedDate": "2026-09-29T18:00:00Z",
          "questionnaireAnswers": {"1": "16"},
          "questionnaireScore": null,
          "assignedPlan": 1,
          "assignedPlanPerSport": {"Futbol": 1},
          "planStartDate": "2026-09-29T18:00:00Z",
          "currentDay": 5,
          "days": [],
          "sleepHistory": [],
          "emotionHistory": [],
          "streakCompletedDates": [],
          "streakCount": 0,
          "coins": 500,
          "level": 0,
          "characterName": "CharacterName",
          "ownedItems": [],
          "equippedItems": {},
          "remindersEnabled": null,
          "soundEnabled": null,
          "appVersion": "1.2"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try! decoder.decode(UserDataSnapshot.self, from: v1)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.cycleNumber, 1)
        XCTAssertEqual(decoded.completedCycles, 0)
        XCTAssertFalse(decoded.programCompleted)
        XCTAssertEqual(decoded.planArchives.count, 0)
        XCTAssertNil(decoded.adminRevision)
    }
}
