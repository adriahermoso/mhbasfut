//
//  AuthHardeningTests.swift
//  mhbasfutTests
//
//  Aceptación de la hardening del acceso:
//  · ninguna contraseña en claro ni persistida,
//  · cuentas hasheadas (salt + SHA-256),
//  · bloqueo local tras intentos fallidos,
//  · modo invitado sin destino de subida,
//  · token en Keychain, nunca en `UserDefaults` ni en claro en el bundle.
//

import XCTest
@testable import mhbasfut

final class AuthHardeningTests: XCTestCase {

    private let keys = [
        "admin.linkedUsername", "admin.lastSyncDate", "student.username",
        "session.guest", "auth.attempts", "auth.lockedUntil", "admin.linkedPassword",
    ]

    override func setUp() {
        super.setUp()
        for k in keys { UserDefaults.standard.removeObject(forKey: k) }
        // Clave histórica: se vacía con escritura explícita (en este entorno
        // `removeObject` no siempre se refleja en las lecturas siguientes) para
        // que el test que escanea valores guardados sea determinista.
        UserDefaults.standard.set("", forKey: "admin.linkedPassword")
        AuthRateLimiter.reset()
    }

    override func tearDown() {
        for k in keys { UserDefaults.standard.removeObject(forKey: k) }
        AuthRateLimiter.reset()
        super.tearDown()
    }

    // MARK: - Ninguna contraseña persistida

    func testNoPasswordIsPersistedAnywhere() async {
        await MainActor.run {
            let svc = GitHubSyncService.shared
            XCTAssertNil(svc.studentSignIn(username: "HugoMartinez", password: "H4pT8wR5"))
            XCTAssertTrue(svc.isStudentSignedIn)
        }
        // La clave histórica ya no recibe la contraseña…
        let legacy = UserDefaults.standard.string(forKey: "admin.linkedPassword") ?? ""
        XCTAssertTrue(legacy.isEmpty, "No debe quedar ninguna contraseña en admin.linkedPassword")
        // …y ninguna contraseña conocida aparece en NINGún valor guardado.
        let plaintextPasswords = ["H4pT8wR5", "M7kR4tQ2", "A7dN2xF9"]
        for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
            let dump = String(describing: value)
            for password in plaintextPasswords {
                XCTAssertFalse(dump.contains(password), "Contraseña en claro en UserDefaults[\(key)]")
            }
        }
    }

    // MARK: - Tabla de credenciales: solo hashes

    func testCredentialTableStoresHashesNotPasswords() {
        // 7 alumnos + Admin + 5 profesores.
        XCTAssertEqual(StudentAccounts.credentials.count, 13)
        for (username, credential) in StudentAccounts.credentials {
            XCTAssertEqual(credential.hash.count, 64, "El hash de \(username) debe ser SHA-256 en hexadecimal")
            XCTAssertTrue(credential.hash.allSatisfy { "0123456789abcdef".contains($0) })
            XCTAssertEqual(credential.salt.count, 32, "Cada cuenta lleva sal propia")
            // Ni la tabla ni el hash contienen el usuario en claro.
            XCTAssertFalse(credential.hash.contains(username.lowercased()))
        }
    }

    func testDigestIsDeterministicAndSalted() {
        let a = StudentAccounts.digest(salt: "sal1", username: "usuario", password: "contrasena")
        let b = StudentAccounts.digest(salt: "sal1", username: "usuario", password: "contrasena")
        let otherSalt = StudentAccounts.digest(salt: "sal2", username: "usuario", password: "contrasena")
        let otherUser = StudentAccounts.digest(salt: "sal1", username: "otro", password: "contrasena")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, otherSalt)
        XCTAssertNotEqual(a, otherUser)
        // La contraseña cambia el digest.
        XCTAssertNotEqual(a, StudentAccounts.digest(salt: "sal1", username: "usuario", password: "otra"))
    }

    func testVerifyReturnsCanonicalUsername() {
        XCTAssertEqual(StudentAccounts.verify(username: "  eloiromero ", password: "M7kR4tQ2"), "EloiRomero")
        XCTAssertEqual(StudentAccounts.canonicalUsername("GONZALOSCHIAVO"), "GonzaloSchiavo")
        XCTAssertNil(StudentAccounts.canonicalUsername("desconocido"))
        XCTAssertNil(StudentAccounts.verify(username: "EloiRomero", password: "mala"))
    }

    // MARK: - Cuentas de profesor (sin datos en GitHub)

    /// `professor1`…`professor5`: contraseña simple (la misma que el
    /// usuario), validación normal y CERO subidas — no se crea ningún
    /// `users/professorN.json`, así que la web no muestra nada suyo.
    func testProfessorAccountsSignInButNeverUpload() {
        for i in 1...5 {
            let username = "professor\(i)"
            XCTAssertEqual(StudentAccounts.verify(username: username, password: username), username)
            // Mayúsculas y espacios no estorban al entrar.
            XCTAssertEqual(StudentAccounts.verify(username: " PROFESSOR\(i) ", password: username), username)
            // Cualquier otra contraseña → rechazo.
            XCTAssertNil(StudentAccounts.verify(username: username, password: "otra"))
            // Rol de profesor y, sobre todo, ningún destino de subida.
            XCTAssertTrue(StudentAccounts.isAdmin(username: username))
            XCTAssertNil(GitHubSyncService.uploadTarget(username: username))
            XCTAssertNil(GitHubSyncService.uploadTarget(username: "  \(username)  "))
        }
        // Los alumnos reales siguen subiendo con normalidad.
        XCTAssertEqual(GitHubSyncService.uploadTarget(username: "MarcelRosell"), "MarcelRosell")
        // Una cuenta inventada no existe.
        XCTAssertNil(StudentAccounts.verify(username: "professor9", password: "professor9"))
    }

    // MARK: - Bloqueo local

    func testLockoutAfterFiveFailures() {
        let suite = "AuthRateLimiterTests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let now = Date()
        XCTAssertEqual(AuthRateLimiter.remainingLock(now: now, defaults: defaults), 0)
        for attempt in 1..<AuthRateLimiter.maxAttempts {
            let remaining = AuthRateLimiter.recordFailure(now: now, defaults: defaults)
            XCTAssertEqual(remaining, 0, "Fallo \(attempt) todavía sin bloqueo")
        }
        let locked = AuthRateLimiter.recordFailure(now: now, defaults: defaults)
        XCTAssertEqual(locked, AuthRateLimiter.lockInterval, accuracy: 0.5)
        XCTAssertGreaterThan(AuthRateLimiter.remainingLock(now: now.addingTimeInterval(10), defaults: defaults), 0)
        // El bloqueo expira solo.
        XCTAssertEqual(AuthRateLimiter.remainingLock(now: now.addingTimeInterval(31), defaults: defaults), 0)
        // Y se puede reiniciar.
        AuthRateLimiter.reset(defaults: defaults)
        XCTAssertEqual(AuthRateLimiter.remainingLock(now: now, defaults: defaults), 0)
    }

    @MainActor
    func testServiceBlocksFurtherAttemptsWhileLocked() {
        let svc = GitHubSyncService.shared
        svc.studentSignOut()
        AuthRateLimiter.reset()

        // 5 fallos → bloqueo con mensaje en español.
        for _ in 0..<AuthRateLimiter.maxAttempts {
            XCTAssertNotNil(svc.link(username: "nadie", password: "mala"))
        }
        let message = GitHubSyncService.lockMessageIfLocked()
        XCTAssertNotNil(message)
        XCTAssertNotNil(svc.link(username: "HugoMartinez", password: "H4pT8wR5"),
                        "Mientras dure el bloqueo no se puede entrar")
        XCTAssertNotNil(svc.studentSignIn(username: "HugoMartinez", password: "H4pT8wR5"))

        // Un inicio válido tras reiniciar el contador vuelve a dejar entrar.
        AuthRateLimiter.reset()
        XCTAssertNil(svc.studentSignIn(username: "HugoMartinez", password: "H4pT8wR5"))
        XCTAssertTrue(svc.isStudentSignedIn)
    }

    // MARK: - Modo invitado

    @MainActor
    func testGuestFlagGuardsEveryUploadPath() {
        let svc = GitHubSyncService.shared
        svc.studentSignOut()
        XCTAssertFalse(GitHubSyncService.isGuestSession)
        XCTAssertEqual(GitHubSyncService.uploadTarget(username: "HugoMartinez"), "HugoMartinez")

        svc.startGuestSession()
        XCTAssertTrue(GitHubSyncService.isGuestSession)
        XCTAssertNil(GitHubSyncService.uploadTarget(username: "HugoMartinez"))
        XCTAssertNil(GitHubSyncService.uploadTarget(username: svc.linkedUsername))

        svc.leaveGuestSession()
        XCTAssertFalse(GitHubSyncService.isGuestSession)
        XCTAssertEqual(GitHubSyncService.uploadTarget(username: "HugoMartinez"), "HugoMartinez")
    }

    // MARK: - Token

    func testTokenIsNeverInUserDefaults() {
        XCTAssertNil(UserDefaults.standard.string(forKey: "github.pat"))
        XCTAssertNil(UserDefaults.standard.string(forKey: "token"))
        for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
            XCTAssertFalse(String(describing: value).contains("github_pat_"),
                           "Token en claro en UserDefaults[\(key)]")
        }
    }

    func testBundlePayloadIsObfuscatedAndDecodable() throws {
        guard let url = Bundle.main.url(forResource: "GitHubToken", withExtension: "plist") else {
            // Clone sin credencial: la sync queda apagada por diseño.
            throw XCTSkip("GitHubToken.plist no está en este bundle (se esperaba en un build local con credencial).")
        }
        let data = try Data(contentsOf: url)
        let raw = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(raw.contains("github_pat_"), "El recurso del bundle no debe contener el token en claro")

        let plist = try XCTUnwrap(
            (try PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
        )
        let payload = try XCTUnwrap(plist["payload"] as? String)
        let decoded = try XCTUnwrap(TokenVault.decode(payload))
        XCTAssertTrue(decoded.hasPrefix("github_pat_"), "El payload debe decodificarse al PAT real")
    }

    func testKeychainRoundTrip() {
        TokenVault.setToken("token-de-prueba-unidad")
        XCTAssertEqual(TokenVault.readKeychain(), "token-de-prueba-unidad")
        XCTAssertEqual(TokenVault.token(), "token-de-prueba-unidad")
        TokenVault.clear()
        XCTAssertNil(TokenVault.readKeychain())
        // Restaura la credencial real importándola otra vez del bundle.
        _ = TokenVault.token()
    }
}
