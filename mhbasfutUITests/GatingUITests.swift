//
//  GatingUITests.swift
//  mhbasfutUITests
//
//  Regresión del bug crítico: un ciclo de 14 días caducado (día 15+) debe
//  llevar SIEMPRE al cuestionario (nunca a una Home congelada en "Día 14"),
//  un ciclo fresco muestra la Home con el día correcto, y sin sesión se
//  muestra el login de jugador.
//
//  El estado se siembra con el dominio de argumentos (`-clave valor`) y
//  `--uitest-reset` limpia el dominio persistente al arrancar, así los
//  tests son deterministas aunque el simulador tenga datos reales.
//

import XCTest

final class GatingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp(seed: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitest-reset"] + seed
        app.launch()
        return app
    }

    private func daysAgoTimestamp(_ days: Int) -> String {
        String(Int(Date().addingTimeInterval(-Double(days) * 86_400).timeIntervalSince1970))
    }

    @MainActor
    func testSignedOutShowsSignIn() throws {
        let app = launchApp(seed: [])
        XCTAssertTrue(app.staticTexts["Bienvenido a MHBasFut"].waitForExistence(timeout: 20))
    }

    @MainActor
    func testExpiredCycleForcesQuestionnaireNotHome() throws {
        let app = launchApp(seed: [
            "-student.username", "TestUser",
            "-questionary.isCompleted", "YES",
            "-questionary.selectedSport", "Futbol",
            "-plan.startDate", daysAgoTimestamp(20),
        ])
        // Debe verse el cuestionario (pregunta 1 de 40 con respuestas vacías),
        // jamás la Home congelada en "Día 14".
        XCTAssertTrue(app.staticTexts["Pregunta 1/40"].waitForExistence(timeout: 20))
        XCTAssertFalse(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Día 14'")).firstMatch.exists,
            "El ciclo caducado no debe quedarse mostrando la Home"
        )
        XCTAssertTrue(app.buttons["CONTINUAR"].exists)
    }

    @MainActor
    func testFreshCycleShowsHomeWithCorrectDay() throws {
        let app = launchApp(seed: [
            "-student.username", "TestUser",
            "-questionary.isCompleted", "YES",
            "-questionary.selectedSport", "Futbol",
            "-plan.startDate", daysAgoTimestamp(3),
        ])
        // Ciclo empezado hace 3 días → hoy es el Día 4.
        let day4 = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Día 4'")).firstMatch
        XCTAssertTrue(day4.waitForExistence(timeout: 20))
    }

    @MainActor
    func testDayFifteenExpiredNotDayThirteen() throws {
        // Día 14 exacto (13 días atrás): todavía es un ciclo vivo.
        let app = launchApp(seed: [
            "-student.username", "TestUser",
            "-questionary.isCompleted", "YES",
            "-questionary.selectedSport", "Futbol",
            "-plan.startDate", daysAgoTimestamp(13),
        ])
        let day14 = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Día 14'")).firstMatch
        XCTAssertTrue(day14.waitForExistence(timeout: 20), "El día 14 aún se juega en la Home")
    }
}
