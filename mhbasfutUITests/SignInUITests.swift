//
//  SignInUITests.swift
//  mhbasfutUITests
//
//  Flujo de acceso: botón de invitado (entra sin cuenta, sin tocar GitHub)
//  y validación de credenciales con mensaje de error.
//

import XCTest

final class SignInUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitest-reset"]
        app.launch()
        return app
    }

    /// El botón de invitado entra en la app completa sin cuenta.
    @MainActor
    func testGuestButtonEntersWithoutAccount() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Bienvenido a MHBasFut"].waitForExistence(timeout: 20))

        let guestButton = app.buttons["Entrar sin cuenta"]
        XCTAssertTrue(guestButton.waitForExistence(timeout: 10),
                      "La pantalla de acceso debe ofrecer entrar sin cuenta")

        guestButton.tap()

        // Una vez dentro: cuestionario (estado por defecto) u Home si ya estaba completado.
        let questionnaire = app.staticTexts["Pregunta 1/40"]
        let homeDay = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Día '")).firstMatch
        XCTAssertTrue(
            questionnaire.waitForExistence(timeout: 20) || homeDay.waitForExistence(timeout: 20),
            "El modo invitado debe llegar al contenido de la app sin iniciar sesión"
        )
        // Y ya no se vuelve a pedir cuenta.
        XCTAssertFalse(app.staticTexts["Bienvenido a MHBasFut"].exists)
    }

    /// Contraseña incorrecta → mensaje de error, sigue en la pantalla de acceso.
    @MainActor
    func testWrongPasswordShowsError() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Bienvenido a MHBasFut"].waitForExistence(timeout: 20))

        let userField = app.textFields["Usuario"]
        XCTAssertTrue(userField.waitForExistence(timeout: 10))
        userField.tap()
        userField.typeText("HugoMartinez")

        let passField = app.secureTextFields["Contraseña"]
        XCTAssertTrue(passField.waitForExistence(timeout: 10))
        passField.tap()
        passField.typeText("no-es-mi-password")

        app.buttons["ENTRAR"].tap()

        XCTAssertTrue(
            app.staticTexts["Usuario o contraseña incorrectos. Revisa los datos de WhatsApp."]
                .waitForExistence(timeout: 10),
            "Debe mostrarse el error de credenciales"
        )
        XCTAssertTrue(app.staticTexts["Bienvenido a MHBasFut"].exists, "Debe seguir sin entrar")
    }
}
