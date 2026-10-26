//
//  AdminSyncTests.swift
//  mhbasfutTests
//
//  Plan Admin Data Sync – Paso 7.
//  Tests reales: exportador JSON completo, construcción del PUT
//  (URL/Base64/SHA), debounce y persistencia de la sesión.
//  El acceso a GitHubSyncService (MainActor) va siempre dentro de
//  `await MainActor.run`, así compila en Swift 5 y Swift 6.
//

import XCTest
@testable import mhbasfut

final class AdminSyncTests: XCTestCase {

    private let adminKeys = [
        "admin.linkedUsername", "admin.linkedPassword", "admin.lastSyncDate", "student.username",
        "session.guest", "auth.attempts", "auth.lockedUntil",
    ]
    private var savedAdmin: [String: Any] = [:]
    private var savedScore: Data?

    override func setUp() {
        super.setUp()
        savedAdmin = [:]
        for k in adminKeys {
            savedAdmin[k] = UserDefaults.standard.object(forKey: k)
            UserDefaults.standard.removeObject(forKey: k)
        }
        savedScore = UserDefaults.standard.data(forKey: QuestionaryScore.storageKey)
    }

    override func tearDown() {
        for k in adminKeys {
            if let v = savedAdmin[k] {
                UserDefaults.standard.set(v, forKey: k)
            } else {
                UserDefaults.standard.removeObject(forKey: k)
            }
        }
        if let savedScore {
            UserDefaults.standard.set(savedScore, forKey: QuestionaryScore.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: QuestionaryScore.storageKey)
        }
        super.tearDown()
    }

    // MARK: - Exportador: JSON contiene todos los campos requeridos

    func testExporterContainsEveryRequiredField() throws {
        let repo = QuestionaryRepo()
        repo.saveSelectedSport("Futbol")
        repo.saveAnswer(questionId: 1, answer: "16")
        repo.saveScore(QuestionaryScore(total: 82, perCategory: ["Son i descans": 20], sport: "Futbol"))
        UserDefaults.standard.set(true, forKey: "questionary.isCompleted")
        UserDefaults.standard.set(500, forKey: "rewards.coins")
        UserDefaults.standard.set("Alex", forKey: "rewards.characterName")

        let snapshot = UserDataExporter.build(username: "alex_04")
        let data = try UserDataExporter.jsonData(for: snapshot)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        for key in [
            "schemaVersion", "exportedAt", "username", "sport",
            "questionnaireCompleted", "questionnaireAnswers", "questionnaireScore",
            "assignedPlan", "assignedPlanPerSport",
            "planStartDate", "currentDay", "days",
            "sleepHistory", "emotionHistory",
            "streakCompletedDates", "streakCount",
            "coins", "level", "characterName", "ownedItems", "equippedItems"
        ] {
            XCTAssertNotNil(obj[key], "Falta el campo requerido: \(key)")
        }
        XCTAssertEqual(obj["username"] as? String, "alex_04")
        XCTAssertEqual((obj["questionnaireAnswers"] as? [String: String])?["1"], "16")
        XCTAssertEqual((obj["questionnaireScore"] as? [String: Any])?["total"] as? Int, 82)
        XCTAssertEqual(obj["coins"] as? Int, 500)
        XCTAssertEqual(obj["characterName"] as? String, "Alex")
        XCTAssertEqual((obj["days"] as? [[String: Any]])?.count, 14)
    }

    func testExporterDayHistoryMealsAndIntensity() throws {
        UserDefaults.standard.set([2, 0], forKey: "plan.completedStages.3")
        UserDefaults.standard.set(true, forKey: "plan.dayCompleted.3")
        UserDefaults.standard.set(1, forKey: "plan.selectedMeal.3.0")
        UserDefaults.standard.set(7, forKey: "plan.intensity.3.2")

        let snapshot = UserDataExporter.build(username: "test_user")
        let day3 = try XCTUnwrap(snapshot.days.first(where: { $0.day == 3 }))
        XCTAssertTrue(day3.completed)
        XCTAssertEqual(day3.completedStages, [0, 2])
        XCTAssertEqual(day3.selectedMeals["0"], 1)
        XCTAssertEqual(day3.intensities["2"], 7)

        let data = try UserDataExporter.jsonData(for: snapshot)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let days = try XCTUnwrap(obj["days"] as? [[String: Any]])
        let jsonDay3 = try XCTUnwrap(days.first(where: { ($0["day"] as? Int) == 3 }))
        XCTAssertEqual(jsonDay3["completed"] as? Bool, true)

        UserDefaults.standard.removeObject(forKey: "plan.completedStages.3")
        UserDefaults.standard.removeObject(forKey: "plan.dayCompleted.3")
        UserDefaults.standard.removeObject(forKey: "plan.selectedMeal.3.0")
        UserDefaults.standard.removeObject(forKey: "plan.intensity.3.2")
    }

    func testStreakCountPureLogic() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        XCTAssertEqual(UserDataExporter.currentStreakCount(dates: []), 0)
        XCTAssertEqual(UserDataExporter.currentStreakCount(dates: [today]), 1)
        XCTAssertEqual(UserDataExporter.currentStreakCount(dates: [today, yesterday]), 2)
        let old = calendar.date(byAdding: .day, value: -5, to: today)!
        XCTAssertEqual(UserDataExporter.currentStreakCount(dates: [old]), 0)
    }

    // MARK: - GitHub PUT: URL, headers, Base64 y SHA

    func testContentsURLPattern() {
        let url = GitHubSyncService.contentsURL(username: "alex_04")
        XCTAssertEqual(url?.absoluteString, "https://api.github.com/repos/adriahermoso/mhbasfut/contents/users/alex_04.json")
    }

    func testPutRequestConstructionAndBase64RoundTrip() throws {
        let snapshot = UserDataExporter.build(username: "alex_04")
        let json = try UserDataExporter.jsonData(for: snapshot)

        let withoutSHA = GitHubSyncService.buildPutRequest(username: "alex_04", jsonData: json, sha: nil, token: "TOKEN123")
        let req = try XCTUnwrap(withoutSHA)
        XCTAssertEqual(req.httpMethod, "PUT")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer TOKEN123")
        let body = try XCTUnwrap(req.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] })
        XCTAssertNil(body["sha"])
        let decoded = try XCTUnwrap(Data(base64Encoded: body["content"] ?? ""))
        XCTAssertEqual(decoded, json)

        let withSHA = try XCTUnwrap(GitHubSyncService.buildPutRequest(username: "alex_04", jsonData: json, sha: "abc123", token: "TOKEN123"))
        let body2 = try XCTUnwrap(withSHA.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] })
        XCTAssertEqual(body2["sha"], "abc123")
    }

    func testParseSHA() throws {
        let data = try JSONSerialization.data(withJSONObject: ["sha": "deadbeef", "content": [:]])
        XCTAssertEqual(GitHubSyncService.parseSHA(from: data), "deadbeef")
        XCTAssertNil(GitHubSyncService.parseSHA(from: Data("{}".utf8)))
    }

    // MARK: - Debounce

    func testDebouncePreventsExcessiveCommits() {
        let now = Date()
        XCTAssertTrue(GitHubSyncService.shouldSync(last: nil, now: now))
        XCTAssertFalse(GitHubSyncService.shouldSync(last: now, now: now))
        XCTAssertFalse(GitHubSyncService.shouldSync(last: now.addingTimeInterval(-30), now: now))
        XCTAssertTrue(GitHubSyncService.shouldSync(last: now.addingTimeInterval(-61), now: now))
    }

    // MARK: - Sesión: solo cuentas validadas, sin contraseña persistida

    func testAuthValidationAndPersistence() async {
        await MainActor.run {
            let svc = GitHubSyncService.shared
            svc.setTokenOverride(nil)
            svc.studentSignOut()
            AuthRateLimiter.reset()
            XCTAssertFalse(svc.isLinked)
            let legacyPasswordBefore = UserDefaults.standard.string(forKey: "admin.linkedPassword")

            // Usuario inventado → rechazado: ya no se puede escribir en el
            // repo eligiendo un nombre cualquiera.
            XCTAssertNotNil(svc.link(username: "alex_04", password: "secreta123"))
            XCTAssertFalse(svc.isLinked)
            XCTAssertNil(UserDefaults.standard.string(forKey: "admin.linkedUsername"))

            // Cuenta real: se vincula con su usuario canónico (GitHub
            // distingue mayúsculas, la validación no).
            XCTAssertNil(svc.link(username: "hugomartinez", password: "H4pT8wR5"))
            XCTAssertTrue(svc.isLinked)
            XCTAssertEqual(svc.linkedUsername, "HugoMartinez")
            // Sobrevive a "reinicios": está en UserDefaults.
            XCTAssertEqual(UserDefaults.standard.string(forKey: "admin.linkedUsername"), "HugoMartinez")
            // link() no escribe ninguna contraseña: la clave histórica
            // `admin.linkedPassword` no cambia con la operación.
            XCTAssertEqual(
                UserDefaults.standard.string(forKey: "admin.linkedPassword"),
                legacyPasswordBefore,
                "link() no debe persistir ninguna contraseña"
            )

            svc.logout()
            XCTAssertFalse(svc.isLinked)
            XCTAssertNil(svc.linkedUsername)
            XCTAssertNil(UserDefaults.standard.string(forKey: "admin.linkedUsername"))
        }
    }

    // MARK: - Modo Admin: nunca sube nada

    /// Guard central: decide qué se sube. Admin / vacío / invitado → nada.
    func testUploadTargetBlocksAdminAndEmpty() {
        XCTAssertNil(GitHubSyncService.uploadTarget(username: "Admin"))
        XCTAssertNil(GitHubSyncService.uploadTarget(username: "admin"))
        XCTAssertNil(GitHubSyncService.uploadTarget(username: "  Admin  "))
        XCTAssertNil(GitHubSyncService.uploadTarget(username: ""))
        XCTAssertNil(GitHubSyncService.uploadTarget(username: nil))
        // Alumnos reales: pasan tal cual, respetando mayúsculas para GitHub.
        XCTAssertEqual(GitHubSyncService.uploadTarget(username: "MarcelRosell"), "MarcelRosell")
        XCTAssertEqual(GitHubSyncService.uploadTarget(username: "HectorVelasco"), "HectorVelasco")
        XCTAssertEqual(GitHubSyncService.uploadTarget(username: "  HugoMartinez  "), "HugoMartinez")
    }

    /// Sesión de invitado: la app funciona pero NO se sube nada (n ni una
    /// llamada a GitHub, ni siquiera forzando la sincronización).
    func testGuestSessionNeverSyncs() async {
        await MainActor.run {
            let svc = GitHubSyncService.shared
            svc.studentSignOut()
            XCTAssertFalse(svc.isGuest)

            svc.startGuestSession()
            XCTAssertTrue(svc.isGuest)
            XCTAssertFalse(svc.isStudentSignedIn)
            XCTAssertFalse(svc.isLinked)
            // Guard central: el modo invitado no genera destino de subida.
            XCTAssertTrue(GitHubSyncService.isGuestSession)
            XCTAssertNil(GitHubSyncService.uploadTarget(username: svc.linkedUsername))
            XCTAssertNil(GitHubSyncService.uploadTarget(username: "HugoMartinez"))

            for reason in [SyncReason.questionnaire, .dayCompleted, .intensity, .wellness, .background, .manual] {
                svc.requestSync(reason: reason, force: true)
            }
            XCTAssertNil(svc.lastErrorMessage)
            XCTAssertFalse(svc.isSyncing)

            // Salir del modo invitado vuelve a permitir subidas.
            svc.studentSignOut()
            XCTAssertFalse(svc.isGuest)
            XCTAssertFalse(GitHubSyncService.isGuestSession)
            XCTAssertEqual(GitHubSyncService.uploadTarget(username: "HugoMartinez"), "HugoMartinez")
        }
    }

    func testIsAdminDetection() {
        XCTAssertTrue(StudentAccounts.isAdmin(username: "Admin"))
        XCTAssertTrue(StudentAccounts.isAdmin(username: "admin"))
        XCTAssertTrue(StudentAccounts.isAdmin(username: " Admin "))
        XCTAssertFalse(StudentAccounts.isAdmin(username: "MarcelRosell"))
        XCTAssertFalse(StudentAccounts.isAdmin(username: nil))
        XCTAssertFalse(StudentAccounts.isAdmin(username: ""))
    }

    /// Sesión Admin abierta pero ninguna ruta toca la red ni marca error.
    func testAdminSessionNeverSyncs() async {
        await MainActor.run {
            let svc = GitHubSyncService.shared
            svc.studentSignOut()
            XCTAssertFalse(svc.isAdminMode)

            XCTAssertNil(svc.studentSignIn(username: "Admin", password: "A7dN2xF9"))
            XCTAssertTrue(svc.isStudentSignedIn)
            XCTAssertTrue(svc.isAdminMode)
            XCTAssertEqual(svc.studentUsername, "Admin")

            // Ningún motivo, ni siquiera forzado, dispara una subida.
            for reason in [SyncReason.questionnaire, .dayCompleted, .intensity, .wellness, .background, .manual] {
                svc.requestSync(reason: reason, force: true)
            }
            // syncNow explícito con "Admin" también es no-op.
            let target = GitHubSyncService.uploadTarget(username: svc.linkedUsername)
            XCTAssertNil(target)
            XCTAssertNil(svc.lastErrorMessage)
            XCTAssertFalse(svc.isSyncing)

            svc.studentSignOut()
            XCTAssertFalse(svc.isAdminMode)
        }
    }

    // MARK: - Sign-in de alumno (previo al cuestionario)

    func testStudentAccountsValidateAllUsers() {
        XCTAssertTrue(StudentAccounts.validate(username: "EloiRomero", password: "M7kR4tQ2"))
        XCTAssertTrue(StudentAccounts.validate(username: "GonzaloSchiavo", password: "G9xN3mK6"))
        XCTAssertTrue(StudentAccounts.validate(username: "HugoMartinez", password: "H4pT8wR5"))
        XCTAssertTrue(StudentAccounts.validate(username: "MarcVilanova", password: "V6nM2kT8"))
        XCTAssertTrue(StudentAccounts.validate(username: "DavidHernandez", password: "D3qW7nP4"))
        XCTAssertTrue(StudentAccounts.validate(username: "MarcelRosell", password: "R8nC4wT6"))
        XCTAssertTrue(StudentAccounts.validate(username: "HectorVelasco", password: "K5vP9mR3"))
        // Modo prueba del profesor.
        XCTAssertTrue(StudentAccounts.validate(username: "Admin", password: "A7dN2xF9"))
        // Tolerante a espacios y a mayúsculas en el usuario; contraseña exacta.
        XCTAssertTrue(StudentAccounts.validate(username: "  HugoMartinez  ", password: "H4pT8wR5"))
        XCTAssertTrue(StudentAccounts.validate(username: "hugomartinez", password: "H4pT8wR5"))
        // El sign-in devuelve SIEMPRE el usuario canónico (GitHub es case-sensitive).
        XCTAssertEqual(StudentAccounts.verify(username: "hugomartinez", password: "H4pT8wR5"), "HugoMartinez")
        XCTAssertNil(StudentAccounts.verify(username: "HugoMartinez", password: "otra"))
        XCTAssertFalse(StudentAccounts.validate(username: "HugoMartinez", password: "otra"))
        XCTAssertFalse(StudentAccounts.validate(username: "Desconocido", password: "H4pT8wR5"))
        XCTAssertFalse(StudentAccounts.validate(username: "", password: "H4pT8wR5"))
        XCTAssertFalse(StudentAccounts.validate(username: "HugoMartinez", password: ""))
    }

    func testStudentSignInOpensSessionAndLinksSync() async {
        await MainActor.run {
            let svc = GitHubSyncService.shared
            svc.studentSignOut()
            XCTAssertFalse(svc.isStudentSignedIn)

            XCTAssertNotNil(svc.studentSignIn(username: "HugoMartinez", password: "mal"))
            XCTAssertFalse(svc.isStudentSignedIn)

            XCTAssertNil(svc.studentSignIn(username: "HugoMartinez", password: "H4pT8wR5"))
            XCTAssertTrue(svc.isStudentSignedIn)
            XCTAssertEqual(svc.studentUsername, "HugoMartinez")
            // La sesión sobrevive "reinicios" y auto-vincula el sync al mismo usuario.
            XCTAssertEqual(UserDefaults.standard.string(forKey: "student.username"), "HugoMartinez")
            XCTAssertTrue(svc.isLinked)
            XCTAssertEqual(svc.linkedUsername, "HugoMartinez")

            svc.studentSignOut()
            XCTAssertFalse(svc.isStudentSignedIn)
            XCTAssertFalse(svc.isLinked)
            svc.requestSync(reason: .dayCompleted, force: true)
            XCTAssertNil(svc.lastErrorMessage)
        }
    }

    func testLogoutStopsFutureUploads() async {
        await MainActor.run {
            let svc = GitHubSyncService.shared
            svc.setTokenOverride(nil)
            AuthRateLimiter.reset()
            XCTAssertNil(svc.link(username: "HugoMartinez", password: "H4pT8wR5"))
            XCTAssertTrue(svc.isLinked)
            svc.logout()
            XCTAssertFalse(svc.isLinked)
            // Sin vínculo requestSync() es no-op y no marca error.
            svc.requestSync(reason: .dayCompleted, force: true)
            XCTAssertNil(svc.lastErrorMessage)
            svc.logout()
        }
    }
}
