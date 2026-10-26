//
//  SmokeUITests.swift
//  mhbasfutUITests
//
//  Prueba mínima de arranque: valida que el target de UI tests está bien
//  conectado con la app y que el simulador puede lanzarla.
//

import XCTest

final class SmokeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
