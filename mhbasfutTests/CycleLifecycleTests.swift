//
//  CycleLifecycleTests.swift
//  mhbasfutTests
//
//  Regresión del bug crítico de expiración de plan:
//  - el ciclo de 14 días caduca por tiempo (día 15) y fuerza el cuestionario
//  - al terminar el día 14 se archiva el ciclo y se empieza el siguiente plan
//  - la progresión nunca repite plan y avanza al menos un nivel por ciclo
//  - los datos filtrados del bug antiguo (progreso imposible) se rescatan
//
//  Cada test fotografía TODO el dominio persistente y lo restaura al final,
//  así los datos reales del simulador nunca se contaminan.
//

import XCTest
@testable import mhbasfut

final class CycleLifecycleTests: XCTestCase {

    private var savedDomain: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        if let bundleID = Bundle.main.bundleIdentifier,
           let domain = UserDefaults.standard.persistentDomain(forName: bundleID) {
            savedDomain = domain
        }
        clearAllTestKeys()
    }

    override func tearDown() {
        clearAllTestKeys()
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.setPersistentDomain(savedDomain, forName: bundleID)
        }
        super.tearDown()
    }

    private func clearAllTestKeys() {
        let d = UserDefaults.standard
        let keys = [
            "plan.startDate", "plan.cycleNumber", "plan.completedCycles",
            "plan.lastSport", "plan.archives",
            "plan.programCompleted.Futbol", "plan.programCompleted.Basquet",
            "plan.assignedNumber", "plan.assignedNumber.Futbol", "plan.assignedNumber.Basquet",
            "questionary.isCompleted", "questionary.answers", "questionary.selectedSport",
            "questionary.completedDate",
            AdminOverrideApplier.lastAppliedRevisionKey,
            "rewards.coins",
        ]
        for k in keys { d.removeObject(forKey: k) }
        for day in 1...14 {
            d.removeObject(forKey: "plan.completedStages.\(day)")
            d.removeObject(forKey: "plan.dayCompleted.\(day)")
            for s in 0...6 { d.removeObject(forKey: "plan.selectedMeal.\(day).\(s)") }
            for s in 0...10 { d.removeObject(forKey: "plan.intensity.\(day).\(s)") }
        }
        // Estado explícito en vez de solo borrar: en este entorno `removeObject`
        // no siempre se refleja en las lecturas siguientes (el dominio queda
        // limpio pero `bool(forKey:)` puede seguir devolviendo el valor
        // anterior), y estos tests dependen de leer "sin cuestionario hecho".
        // Escribirlo explícitamente hace el estado determinista sea cual sea
        // el estado previo del simulador.
        d.set(false, forKey: "questionary.isCompleted")
    }

    private func setStartDate(daysAgo: Int, now: Date = Date()) {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "plan.startDate")
    }

    private func markAllDaysDone() {
        for d in 1...14 {
            UserDefaults.standard.set(true, forKey: "plan.dayCompleted.\(d)")
            UserDefaults.standard.set([0, 1], forKey: "plan.completedStages.\(d)")
        }
    }

    // MARK: - Expiry

    func testRawDayAndExpiryBoundaries() {
        setStartDate(daysAgo: 13) // hoy es el día 14
        let repo = PlanRepo()
        XCTAssertEqual(repo.rawDayNumber(), 14)
        XCTAssertFalse(repo.hasPlanExpired(), "El día 14 todavía se puede jugar")

        setStartDate(daysAgo: 14) // hoy es el día 15
        XCTAssertEqual(repo.rawDayNumber(), 15)
        XCTAssertTrue(repo.hasPlanExpired(), "El día 15 debe forzar el cuestionario")
    }

    func testEnforceExpiryFlipsQuestionnairePending() {
        QuestionaryRepo().saveCompletion(isCompleted: true)
        setStartDate(daysAgo: 20)
        let enforced = PlanRepo().enforceExpiryIfNeeded()
        XCTAssertTrue(enforced)
        XCTAssertFalse(QuestionaryRepo().isQuestionnaireCompleted())
    }

    func testEnforceExpiryDoesNothingWhenProgramCompleted() {
        QuestionaryRepo().saveCompletion(isCompleted: true)
        QuestionaryRepo().saveSelectedSport("Futbol")
        setStartDate(daysAgo: 20)
        PlanRepo().setProgramCompleted(true)
        let enforced = PlanRepo().enforceExpiryIfNeeded()
        XCTAssertFalse(enforced)
        XCTAssertTrue(QuestionaryRepo().isQuestionnaireCompleted())
    }

    func testEnforceExpiryKeepsFreshCycle() {
        QuestionaryRepo().saveCompletion(isCompleted: true)
        setStartDate(daysAgo: 3)
        let enforced = PlanRepo().enforceExpiryIfNeeded()
        XCTAssertFalse(enforced)
        XCTAssertTrue(QuestionaryRepo().isQuestionnaireCompleted())
    }

    // MARK: - Next plan rule

    func testNextPlanRule() {
        XCTAssertEqual(PlanRepo.nextPlanNumber(computedPlan: 1, previousPlan: nil), 1)
        XCTAssertEqual(PlanRepo.nextPlanNumber(computedPlan: 4, previousPlan: nil), 4)
        XCTAssertEqual(PlanRepo.nextPlanNumber(computedPlan: 1, previousPlan: 1), 2)
        XCTAssertEqual(PlanRepo.nextPlanNumber(computedPlan: 3, previousPlan: 1), 3, "El test manda si pide más")
        XCTAssertEqual(PlanRepo.nextPlanNumber(computedPlan: 1, previousPlan: 2), 3, "Nunca repite plan")
        XCTAssertEqual(PlanRepo.nextPlanNumber(computedPlan: 4, previousPlan: 2), 4)
        XCTAssertEqual(PlanRepo.nextPlanNumber(computedPlan: 2, previousPlan: 4), 4, "El plan 4 es el techo")
    }

    // MARK: - First questionnaire starts cycle 1

    func testFirstQuestionnaireStartsCycleOne() {
        let repo = PlanRepo()
        let next = repo.completeQuestionnaireCycle(sport: "Futbol", computedPlan: 2)
        XCTAssertEqual(next, 2)
        XCTAssertEqual(repo.getCycleNumber(), 1)
        XCTAssertEqual(repo.getCompletedCycles(), 0)
        XCTAssertTrue(repo.getArchives().isEmpty)
        XCTAssertEqual(repo.getLastSport(), "Futbol")
        XCTAssertEqual(QuestionaryRepo().getAssignedPlan(forSport: "Futbol"), 2)
        XCTAssertNotNil(repo.rawDayNumber())
    }

    // MARK: - Day 14 transitions

    func testDay14BelowPlan4RequestsRetake() {
        QuestionaryRepo().saveCompletion(isCompleted: true)
        QuestionaryRepo().saveSelectedSport("Futbol")
        QuestionaryRepo().saveAssignedPlan(2, forSport: "Futbol")
        setStartDate(daysAgo: 13)

        let needsRetake = PlanRepo().handleFinalDayCompleted()
        XCTAssertTrue(needsRetake)
        XCTAssertFalse(QuestionaryRepo().isQuestionnaireCompleted())
        XCTAssertEqual(PlanRepo().getCompletedCycles(), 1)
        XCTAssertFalse(PlanRepo().isProgramCompleted())
    }

    func testDay14Plan4ClosesProgram() {
        QuestionaryRepo().saveCompletion(isCompleted: true)
        QuestionaryRepo().saveSelectedSport("Futbol")
        QuestionaryRepo().saveAssignedPlan(4, forSport: "Futbol")
        setStartDate(daysAgo: 13)

        let needsRetake = PlanRepo().handleFinalDayCompleted()
        XCTAssertFalse(needsRetake)
        XCTAssertTrue(QuestionaryRepo().isQuestionnaireCompleted(), "Sin cuestionario tras el plan 4")
        XCTAssertTrue(PlanRepo().isProgramCompleted())
        XCTAssertEqual(PlanRepo().getCompletedCycles(), 1)
    }

    // MARK: - Full cycle change: archive, progress, clean day 1

    func testFullCycleArchivesAndStartsNextPlanClean() {
        QuestionaryRepo().saveCompletion(isCompleted: true)
        QuestionaryRepo().saveSelectedSport("Futbol")
        let repo = PlanRepo()
        repo.completeQuestionnaireCycle(sport: "Futbol", computedPlan: 2)
        XCTAssertEqual(repo.getAssignedPlanNumber(), 2)

        // 14 días completos con cena elegida el día 1 (para probar el archivado)
        markAllDaysDone()
        UserDefaults.standard.set(1, forKey: "plan.selectedMeal.1.6")

        // Día 14 completado → retake
        XCTAssertTrue(repo.handleFinalDayCompleted())

        // Retake: los tests físicos empeoran (plan 1), pero la progresión exige subir
        let next = repo.completeQuestionnaireCycle(sport: "Futbol", computedPlan: 1)
        XCTAssertEqual(next, 3, "min(4, max(1, 2+1)) = 3")
        XCTAssertEqual(repo.getCycleNumber(), 2)
        XCTAssertEqual(repo.getAssignedPlanNumber(), 3)

        // Archivo del ciclo anterior intacto
        let archives = repo.getArchives()
        XCTAssertEqual(archives.count, 1)
        XCTAssertEqual(archives[0].planNumber, 2)
        XCTAssertEqual(archives[0].days.count, 14)
        XCTAssertTrue(archives[0].allDaysCompleted)
        XCTAssertFalse(archives[0].recovered)
        XCTAssertEqual(archives[0].days.first(where: { $0.day == 1 })?.selectedMeals["6"], 1)

        // Progreso vivo limpio: día 1 jugable desde cero (el bug "cannot complete meals")
        XCTAssertFalse(repo.isDayCompleted(day: 1))
        XCTAssertTrue(repo.getCompletedStages(day: 1).isEmpty)
        XCTAssertNil(repo.getSelectedMealOption(day: 1, stageIndex: 6))
        XCTAssertNil(repo.getIntensity(day: 1, stageIndex: 0))

        // Ciclo nuevo empieza hoy
        XCTAssertEqual(repo.rawDayNumber(), 1)
        XCTAssertFalse(repo.hasPlanExpired())
    }

    func testSecondCycleWithSameComputedPlanStillAvoidsLeak() {
        QuestionaryRepo().saveCompletion(isCompleted: true)
        QuestionaryRepo().saveSelectedSport("Futbol")
        let repo = PlanRepo()
        repo.completeQuestionnaireCycle(sport: "Futbol", computedPlan: 1)
        markAllDaysDone()
        XCTAssertTrue(repo.handleFinalDayCompleted())

        let next = repo.completeQuestionnaireCycle(sport: "Futbol", computedPlan: 1)
        XCTAssertEqual(next, 2, "1 → 2 aunque los tests no suban")
        XCTAssertFalse(repo.isDayCompleted(day: 1))
        XCTAssertTrue(repo.getCompletedStages(day: 1).isEmpty)

        // El día 1 del ciclo nuevo se puede completar de verdad
        repo.saveCompletedStages(day: 1, stages: Set(0...5))
        XCTAssertEqual(repo.getCompletedStages(day: 1).count, 6)
        XCTAssertFalse(repo.isDayCompleted(day: 1))
    }

    func testSportSwitchStartsFreshAtClassifierLevel() {
        QuestionaryRepo().saveCompletion(isCompleted: true)
        QuestionaryRepo().saveSelectedSport("Futbol")
        let repo = PlanRepo()
        repo.completeQuestionnaireCycle(sport: "Futbol", computedPlan: 2)
        markAllDaysDone()
        XCTAssertTrue(repo.handleFinalDayCompleted())

        // Cambio de deporte: empieza en el nivel clasificado, sin progresión
        QuestionaryRepo().saveSelectedSport("Basquet")
        let next = repo.completeQuestionnaireCycle(sport: "Basquet", computedPlan: 4)
        XCTAssertEqual(next, 4)
        XCTAssertEqual(QuestionaryRepo().getAssignedPlan(forSport: "Basquet"), 4)
        XCTAssertEqual(QuestionaryRepo().getAssignedPlan(forSport: "Futbol"), 2)
        XCTAssertEqual(repo.getArchives().count, 1)
        XCTAssertEqual(repo.getArchives()[0].sport, "Futbol")
    }

    func testProgramCompletedRetakeRestartsFromAssessment() {
        QuestionaryRepo().saveCompletion(isCompleted: true)
        QuestionaryRepo().saveSelectedSport("Futbol")
        QuestionaryRepo().saveAssignedPlan(4, forSport: "Futbol")
        setStartDate(daysAgo: 5)
        PlanRepo().setProgramCompleted(true)

        let repo = PlanRepo()
        let next = repo.completeQuestionnaireCycle(sport: "Futbol", computedPlan: 3)
        XCTAssertEqual(next, 3)
        XCTAssertFalse(repo.isProgramCompleted(forSport: "Futbol"))
    }

    // MARK: - Legacy leak sweep

    func testSweepRescuesImpossibleProgress() {
        QuestionaryRepo().saveCompletion(isCompleted: true)
        QuestionaryRepo().saveSelectedSport("Futbol")
        QuestionaryRepo().saveAssignedPlan(2, forSport: "Futbol")
        setStartDate(daysAgo: 3) // hoy es el día 4

        // Días 1..3 legítimos + progreso imposible en 5..8 (filtrado del bug)
        for d in 1...3 {
            UserDefaults.standard.set(true, forKey: "plan.dayCompleted.\(d)")
        }
        for d in 5...8 {
            UserDefaults.standard.set(true, forKey: "plan.dayCompleted.\(d)")
            UserDefaults.standard.set([0, 1, 2], forKey: "plan.completedStages.\(d)")
        }

        let repo = PlanRepo()
        let swept = repo.sweepImpossibleProgressIfNeeded()
        XCTAssertEqual(swept, 4)

        // Progreso imposible fuera; legítimo intacto
        for d in 5...8 { XCTAssertFalse(repo.isDayCompleted(day: d)) }
        for d in 1...3 { XCTAssertTrue(repo.isDayCompleted(day: d)) }

        // Los días rescatados quedan archivados (no se pierden)
        let archives = repo.getArchives()
        XCTAssertEqual(archives.count, 1)
        XCTAssertTrue(archives[0].recovered)
        XCTAssertEqual(archives[0].days.map(\.day).sorted(), [5, 6, 7, 8])
        XCTAssertEqual(archives[0].days.first(where: { $0.day == 5 })?.completedStages, [0, 1, 2])

        // Idempotente
        XCTAssertEqual(repo.sweepImpossibleProgressIfNeeded(), 0)
    }

    func testSweepIgnoresExpiredCycles() {
        QuestionaryRepo().saveCompletion(isCompleted: true)
        QuestionaryRepo().saveSelectedSport("Futbol")
        setStartDate(daysAgo: 20) // día 21: todo <= 14 es teóricamente alcanzable
        UserDefaults.standard.set(true, forKey: "plan.dayCompleted.14")
        XCTAssertEqual(PlanRepo().sweepImpossibleProgressIfNeeded(), 0)
        XCTAssertTrue(PlanRepo().isDayCompleted(day: 14))
    }

    func testSweepDoesNothingWithoutCompletedQuestionnaire() {
        setStartDate(daysAgo: 3)
        UserDefaults.standard.set(true, forKey: "plan.dayCompleted.9")
        XCTAssertEqual(PlanRepo().sweepImpossibleProgressIfNeeded(), 0)
        XCTAssertTrue(PlanRepo().isDayCompleted(day: 9))
    }
}
