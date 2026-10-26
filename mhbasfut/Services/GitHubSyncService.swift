//
//  GitHubSyncService.swift
//  mhbasfut
//
//  Plan Admin Data Sync – Paso 4.
//  Sube el JSON completo del usuario a
//  PUT /repos/adriahermoso/mhbasfut/contents/users/{username}.json
//  usando un fine-grained PAT de corta duración.
//
//  El token NO está en este fichero: lo aporta TokenVault (Keychain,
//  importado desde el recurso git-ignored `GitHubToken.plist`). Sin token,
//  la sincronización queda apagada con mensaje claro en la UI.
//
//  Estados de sesión:
//    · invitado  → `session.guest`: la app funciona entera y NO se envía
//                  nada a GitHub;
//    · jugador   → `student.username` = `admin.linkedUsername`, cuenta
//                  validada contra StudentAccounts;
//    · sin sesión→ pantalla de sign-in.
//

import Foundation
import Combine
import CryptoKit

public enum SyncReason: String {
    case questionnaire
    case dayCompleted
    case intensity
    case wellness
    case background
    case manual
}

@MainActor
public final class GitHubSyncService: ObservableObject {

    public static let shared = GitHubSyncService()

    // MARK: - Config fija

    nonisolated public static let owner = "adriahermoso"
    nonisolated public static let repo = "mhbasfut"
    nonisolated public static let usersPrefix = "users"
    nonisolated public static let debounceInterval: TimeInterval = 60

    private var tokenOverride: String? = nil

    // MARK: - Estado publicado (UI en español)

    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var lastSyncDate: Date? = nil
    @Published public private(set) var lastErrorMessage: String? = nil

    // MARK: - Credenciales de sesión (superviven reinicios hasta logout)
    //  Solo identificadores no secretos: ni contraseñas ni token viven aquí.
    //  El token está en el Keychain (TokenVault) y la contraseña no se
    //  guarda en ningún sitio: se valida contra StudentAccounts y se tira.

    private let usernameKey = "admin.linkedUsername"
    private let lastSyncKey = "admin.lastSyncDate"
    nonisolated public static let guestKey = "session.guest"
    private let session: URLSession

    /// true = sesión de invitado: app completa, cero llamadas a GitHub.
    @Published public private(set) var isGuest: Bool

    public init(session: URLSession = .shared) {
        self.session = session
        self.lastSyncDate = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
        self.isGuest = UserDefaults.standard.bool(forKey: Self.guestKey)
        // Migración: versiones anteriores guardaban la contraseña del vínculo
        // en claro en UserDefaults. Ya no se usa para nada → se purga aquí
        // (aparece una sola vez, después de actualizar).
        UserDefaults.standard.removeObject(forKey: "admin.linkedPassword")
    }

    // Solo tests: inyectar PAT sin tocar el código.
    public func setTokenOverride(_ token: String?) { tokenOverride = token }

    /// Token activo: Keychain (TokenVault). `setTokenOverride` solo lo usan
    /// los tests. Nunca se registra en logs.
    var activeToken: String? {
        if let o = tokenOverride, !o.isEmpty { return o }
        return TokenVault.token()
    }

    public var isLinked: Bool { linkedUsername != nil }

    public var linkedUsername: String? {
        let raw = UserDefaults.standard.string(forKey: usernameKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let r = raw, !r.isEmpty else { return nil }
        return r
    }

    // MARK: - Sesión de invitado (acceso sin cuenta, cero tráfico a GitHub)

    /// Abre la sesión de invitado: la app se usa completa (cuestionario,
    /// plan, racha, recompensas…), pero no sale NADA del dispositivo.
    public func startGuestSession() {
        setGuest(true)
        UserDefaults.standard.removeObject(forKey: studentUsernameKey)
        UserDefaults.standard.removeObject(forKey: usernameKey)
        AuthRateLimiter.reset()
        lastErrorMessage = nil
        objectWillChange.send()
    }

    /// Sale del modo invitado. El borrado del progreso del invitado lo
    /// decide la UI (con confirmación) antes de llamar aquí.
    public func leaveGuestSession() {
        setGuest(false)
        objectWillChange.send()
    }

    private func setGuest(_ value: Bool) {
        if value {
            UserDefaults.standard.set(true, forKey: Self.guestKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.guestKey)
        }
        isGuest = value
    }

    // MARK: - Vinculación de cuenta (solo cuentas de la lista)

    /// Vincula una cuenta VALIDADA contra `StudentAccounts` (misma lista que
    /// el sign-in): ya no se puede escribir en el repo con un usuario
    /// inventado, y la identidad de subida coincide siempre con la sesión.
    /// La contraseña no se guarda. Devuelve nil si ok, o mensaje en español.
    @discardableResult
    public func link(username: String, password: String) -> String? {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty else { return "Escribe tu usuario." }
        if let locked = Self.lockMessageIfLocked() { return locked }
        guard let canonical = StudentAccounts.verify(username: u, password: password) else {
            _ = AuthRateLimiter.recordFailure()
            return Self.lockMessageIfLocked() ?? "Usuario o contraseña incorrectos. Revisa los datos de WhatsApp."
        }
        AuthRateLimiter.reset()
        linkUsername(canonical)
        return nil
    }

    /// Fija la identidad de subida (cuenta ya validada) y cierra el modo invitado.
    private func linkUsername(_ canonical: String) {
        UserDefaults.standard.set(canonical, forKey: usernameKey)
        setGuest(false)
        lastErrorMessage = nil
        objectWillChange.send()
    }

    public func logout() {
        UserDefaults.standard.removeObject(forKey: usernameKey)
        lastErrorMessage = nil
        objectWillChange.send()
    }

    /// Mensaje de bloqueo si hay intentos fallidos recientes (nil = sin bloqueo).
    nonisolated public static func lockMessageIfLocked(
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> String? {
        let remaining = AuthRateLimiter.remainingLock(now: now, defaults: defaults)
        guard remaining > 0 else { return nil }
        let seconds = Int(remaining.rounded(.up))
        return "Demasiados intentos. Vuelve a intentarlo en \(seconds) segundos."
    }

    // MARK: - Sesión de alumno (sign-in previo al cuestionario)

    private let studentUsernameKey = "student.username"

    public var studentUsername: String? {
        let raw = UserDefaults.standard.string(forKey: studentUsernameKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let r = raw, !r.isEmpty else { return nil }
        return r
    }

    public var isStudentSignedIn: Bool { studentUsername != nil }

    /// Modo prueba del profesor: entra como cualquier alumno pero
    /// ninguna subida sale a GitHub (ver `uploadTarget`).
    public var isAdminMode: Bool { StudentAccounts.isAdmin(username: studentUsername) }

    /// Valida contra las cuentas hasheadas y abre la sesión del alumno.
    /// El usuario canónico (GitHub distingue mayúsculas) es la identidad del
    /// sync: vincula la subida a `users/{usuario}.json`. Devuelve nil si ok,
    /// o mensaje en español.
    @discardableResult
    public func studentSignIn(username: String, password: String) -> String? {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty else { return "Escribe tu usuario." }
        if let locked = Self.lockMessageIfLocked() { return locked }
        guard let canonical = StudentAccounts.verify(username: u, password: password) else {
            _ = AuthRateLimiter.recordFailure()
            return Self.lockMessageIfLocked() ?? "Usuario o contraseña incorrectos. Revisa los datos de WhatsApp."
        }
        AuthRateLimiter.reset()
        UserDefaults.standard.set(canonical, forKey: studentUsernameKey)
        linkUsername(canonical)
        return nil
    }

    /// Cierra la sesión del alumno y detiene futuras subidas.
    public func studentSignOut() {
        UserDefaults.standard.removeObject(forKey: studentUsernameKey)
        setGuest(false)
        logout()
    }

    // MARK: - Borrado de datos y de cuenta

    /// Borra TODO el progreso local (incluidas las claves de sesión).
    /// Al terminar no hay sesión: la UI decide qué pantalla muestra.
    public func wipeLocalData() async {
        await UserDefaultsSettingsRepo().eliminarDatos()
        lastSyncDate = nil
        lastErrorMessage = nil
        setGuest(false)
        objectWillChange.send()
    }

    /// Borra `users/{username}.json` en GitHub (guideline 5.1.1(v)).
    /// Devuelve nil si ok, o un mensaje en español sin tocar nada local.
    public func deleteRemoteAccountFile() async -> String? {
        guard let target = Self.uploadTarget(username: linkedUsername) else {
            return "No hay ninguna cuenta vinculada en este dispositivo."
        }
        guard let token = activeToken else {
            return "Falta el token de sincronización. Pide al profesor que lo configure."
        }
        guard let url = Self.contentsURL(username: target) else {
            return "No se pudo construir la petición de borrado."
        }
        do {
            var get = URLRequest(url: url)
            get.httpMethod = "GET"
            get.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            get.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            get.setValue("MHBasfut-iOS", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: get)
            guard let http = response as? HTTPURLResponse else {
                return "Respuesta inválida del servidor."
            }
            if http.statusCode == 404 { return nil } // ya no existe: nada que borrar
            guard (200...299).contains(http.statusCode) else {
                return "No se pudo leer la cuenta en GitHub (código \(http.statusCode))."
            }
            guard let sha = Self.parseSHA(from: data) else {
                return "No se pudo leer la cuenta en GitHub."
            }
            var del = URLRequest(url: url)
            del.httpMethod = "DELETE"
            del.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            del.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            del.setValue("MHBasfut-iOS", forHTTPHeaderField: "User-Agent")
            let body: [String: String] = [
                "message": "account: delete \(target).json",
                "sha": sha,
            ]
            del.httpBody = try? JSONSerialization.data(withJSONObject: body)
            let (_, delResponse) = try await session.data(for: del)
            guard let dh = delResponse as? HTTPURLResponse, (200...299).contains(dh.statusCode) else {
                let code = (delResponse as? HTTPURLResponse)?.statusCode ?? 0
                return "No se pudo eliminar la cuenta en GitHub (código \(code))."
            }
            return nil
        } catch is URLError {
            return "Sin conexión. No se ha eliminado nada, inténtalo de nuevo."
        } catch {
            return "No se pudo eliminar la cuenta. Inténtalo de nuevo."
        }
    }

    /// Borra la cuenta en GitHub y después todo el dato local.
    /// Si la parte remota falla, NO se borra nada local (así se puede reintentar).
    @discardableResult
    public func deleteAccountAndData() async -> String? {
        if let error = await deleteRemoteAccountFile() { return error }
        await wipeLocalData()
        return nil
    }

    // MARK: - URLs y construcción pura (testeable sin red)

    /// Nombre de fichero de sync. Trim + preserva mayúsculas: GitHub es
    /// case-sensitive y la web debe pedir EXACTAMENTE este mismo string
    /// en `CONFIG.alumnes` (p. ej. `EloiRomero`, no `eloi`).
    nonisolated public static func syncFileName(for username: String) -> String? {
        let t = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return t
    }

    /// true cuando la sesión actual es de invitado (sin cuenta).
    nonisolated public static var isGuestSession: Bool {
        UserDefaults.standard.bool(forKey: guestKey)
    }

    /// Único punto de decisión sobre qué se sube. Devuelve el nombre de
    /// fichero, o `nil` si no se sube nada. Invitado y rol de profesor
    /// (Admin y `professor1`…`professor5`) devuelven siempre `nil`, así que
    /// no hay NINGUNA llamada a GitHub desde esas sesiones y ni
    /// `users/Admin.json` ni `users/professorN.json` se crean ni se listan
    /// en la web.
    nonisolated public static func uploadTarget(username: String?) -> String? {
        guard !isGuestSession else { return nil }
        guard let raw = username, !StudentAccounts.isAdmin(username: raw) else { return nil }
        return syncFileName(for: raw)
    }

    nonisolated public static func contentsURL(username: String) -> URL? {
        guard let file = syncFileName(for: username) else { return nil }
        var c = URLComponents()
        c.scheme = "https"
        c.host = "api.github.com"
        c.path = "/repos/\(owner)/\(repo)/contents/\(usersPrefix)/\(file).json"
        return c.url
    }

    /// Cuerpo del PUT: mensaje + contenido en Base64 (+ SHA si es update).
    nonisolated public static func putBody(message: String, jsonData: Data, sha: String?) -> [String: String] {
        var body: [String: String] = [
            "message": message,
            "content": jsonData.base64EncodedString()
        ]
        if let sha, !sha.isEmpty { body["sha"] = sha }
        return body
    }

    nonisolated public static func buildPutRequest(username: String, jsonData: Data, sha: String?, token: String) -> URLRequest? {
        guard let url = contentsURL(username: username) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("MHBasfut-iOS", forHTTPHeaderField: "User-Agent")
        let body = putBody(message: "sync: update \(username).json", jsonData: jsonData, sha: sha)
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return req
    }

    /// Extrae el SHA del GET previo (necesario para actualizar el fichero).
    nonisolated public static func parseSHA(from getResponseData: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: getResponseData) as? [String: Any],
              let sha = obj["sha"] as? String, !sha.isEmpty else { return nil }
        return sha
    }

    /// Decodifica el cuerpo de la Contents API de GitHub: si llega el JSON
    /// con `content` en Base64 lo decodifica; si ya llega el fichero en crudo
    /// (Accept raw) lo devuelve tal cual.
    nonisolated public static func decodeContentsAPIData(_ data: Data) -> Data? {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let content = obj["content"] as? String, (obj["encoding"] as? String) == "base64" {
                let cleaned = content.replacingOccurrences(of: "\n", with: "")
                return Data(base64Encoded: cleaned)
            }
            // Fichero JSON legítimo (ya venía en crudo).
            return data
        }
        return nil
    }

    /// Revisión admin + ediciones pendientes del fichero remoto.
    nonisolated public static func parseAdminEdits(fromUserJSON data: Data) -> (revision: String?, overrides: [String: Any]?) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, nil)
        }
        let revision = obj["adminRevision"] as? String
        let overrides = obj["adminOverrides"] as? [String: Any]
        return (revision, overrides)
    }

    /// Aplica las ediciones del panel admin si la revisión remota es más
    /// nueva que la última aplicada. Se usa tanto al volver a primer plano
    /// como antes de cada subida (así una subida nunca pisa una edición del
    /// panel: primero se aplica, luego el snapshot la refleja).
    @discardableResult
    nonisolated public static func applyPendingAdminEdits(fromRemoteUserJSON data: Data, defaults: UserDefaults = .standard) -> Bool {
        let (revision, overrides) = parseAdminEdits(fromUserJSON: data)
        guard AdminOverrideApplier.shouldApply(
            remoteRevision: revision,
            appliedRevision: AdminOverrideApplier.appliedRevision(defaults: defaults)
        ) else { return false }
        guard let overrides, let revision else { return false }
        _ = AdminOverrideApplier.apply(overrides: overrides, defaults: defaults)
        AdminOverrideApplier.storeAppliedRevision(revision, defaults: defaults)
        return true
    }

    /// Debounce puro: evita commits excesivos ante cambios rápidos.
    nonisolated public static func shouldSync(last: Date?, now: Date, interval: TimeInterval = debounceInterval) -> Bool {
        guard let last else { return true }
        return now.timeIntervalSince(last) >= interval
    }

    // MARK: - Entrada con debounce (no bloquea, nunca crashea)

    /// Razones críticas que nunca deben perderse por el debounce:
    /// cuestionario, día completado y sync manual siempre suben.
    /// Intensidad / wellness / background sí respetan el debounce de 60s.
    nonisolated public static func isCritical(reason: SyncReason) -> Bool {
        switch reason {
        case .questionnaire, .dayCompleted, .manual: return true
        case .intensity, .wellness, .background: return false
        }
    }

    /// Llamar desde: fin de cuestionario, día completado, intensidad /
    /// emoción / sueño, y al entrar en background. Sin vínculo → no hace nada.
    public func requestSync(reason: SyncReason, force: Bool = false) {
        guard let target = Self.uploadTarget(username: linkedUsername) else { return }
        let mustForce = force || Self.isCritical(reason: reason)
        if !mustForce {
            let now = Date()
            if !Self.shouldSync(last: lastSyncDate, now: now) { return }
        }
        Task { await self.syncNow(username: target) }
    }

    public func syncNow(username: String? = nil) async {
        guard let target = Self.uploadTarget(username: username ?? linkedUsername) else { return }
        guard !isSyncing else { return }
        guard let token = activeToken else {
            lastErrorMessage = "Falta el token de sincronización. Pide al profesor que lo configure."
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        do {
            // Primero traer el estado remoto: su SHA para el PUT y posibles
            // ediciones del panel admin que deban aplicarse ANTES de construir
            // el snapshot (el snapshot luego las refleja y las "consolida").
            let remote = try await fetchRemoteState(username: target, token: token)
            if let raw = remote.raw {
                Self.applyPendingAdminEdits(fromRemoteUserJSON: raw)
            }
            let snapshot = UserDataExporter.build(username: target)
            let json = try UserDataExporter.jsonData(for: snapshot)
            guard let request = Self.buildPutRequest(username: target, jsonData: json, sha: remote.sha, token: token) else {
                lastErrorMessage = "No se pudo construir la petición de subida."
                return
            }
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                lastErrorMessage = "Respuesta inválida del servidor."
                return
            }
            switch http.statusCode {
            case 200, 201:
                let now = Date()
                lastSyncDate = now
                UserDefaults.standard.set(now, forKey: lastSyncKey)
                lastErrorMessage = nil
            case 401, 403:
                lastErrorMessage = "El token ha caducado o no tiene permiso. Pide uno nuevo al profesor."
            case 404:
                lastErrorMessage = "Repositorio no encontrado. Revisa el nombre del repo."
            case 422:
                lastErrorMessage = "Conflicto de versión (SHA). Se reintentará en la próxima sincronización."
            default:
                lastErrorMessage = "No se pudo sincronizar (código \(http.statusCode)). Se reintentará más tarde."
            }
        } catch is URLError {
            // Sin internet → silencio: se reintenta en el próximo trigger.
            lastErrorMessage = "Sin conexión. Se sincronizará cuando vuelva internet."
        } catch {
            lastErrorMessage = "No se pudo sincronizar. Se reintentará más tarde."
        }
    }

    /// Trae el fichero remoto: SHA (para el PUT) y contenido en crudo
    /// (para aplicar ediciones del panel admin). Fichero nuevo → (nil, nil).
    private func fetchRemoteState(username: String, token: String) async throws -> (sha: String?, raw: Data?) {
        guard let url = Self.contentsURL(username: username) else { return (nil, nil) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("MHBasfut-iOS", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { return (nil, nil) }
            if http.statusCode == 404 { return (nil, nil) } // fichero nuevo
            guard (200...299).contains(http.statusCode) else { return (nil, nil) }
            return (Self.parseSHA(from: data), Self.decodeContentsAPIData(data))
        } catch is URLError {
            throw URLError(.notConnectedToInternet)
        }
    }

    /// Aplica las ediciones pendientes del panel admin (si las hay y son más
    /// nuevas) sin subir nada. Devuelve true cuando se aplicó algo — el
    /// llamante decide si además quiere subir el snapshot consolidado.
    @discardableResult
    public func applyRemoteOverridesIfNeeded() async -> Bool {
        guard let target = Self.uploadTarget(username: linkedUsername) else { return false }
        guard let token = activeToken else { return false }
        guard let url = Self.contentsURL(username: target) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("MHBasfut-iOS", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
            guard let raw = Self.decodeContentsAPIData(data) else { return false }
            return Self.applyPendingAdminEdits(fromRemoteUserJSON: raw)
        } catch {
            // Sin conexión o error temporal: se reintentará en el próximo arranque.
            return false
        }
    }
}

// MARK: - Cuentas de alumno (hashes, no contraseñas en claro)

// ────────────────────────────────────────────────────────────
// Las contraseñas NO están en el binario: solo `salt + SHA-256`. Una
// extracción del binario no da contraseñas usables directamente (habría que
// fuerza bruta offline por cuenta). Cuentas y contraseñas se siguen
// repartiendo por WhatsApp.
// ────────────────────────────────────────────────────────────

public struct Credential: Equatable {
    public let salt: String
    public let hash: String
    public init(salt: String, hash: String) {
        self.salt = salt
        self.hash = hash
    }
}

public enum StudentAccounts {

    /// Cuenta especial de modo prueba (profesor). Case-insensitive.
    public static let adminUsername = "Admin"

    /// usuario canónico → credencial. Si en el futuro se añade una cuenta
    /// (p. ej. la del profesor) se genera con `digest(salt:username:password:)`.
    public static let credentials: [String: Credential] = [
        "EloiRomero": Credential(salt: "mHb7Qp2Lx9Rt4Vn8Zc1Df6Yw3Sj5Ka0B", hash: "90a28015d8c65e4b5c56d53e557e86de681041e122027bc2f47408e7eb668b3a"),
        "GonzaloSchiavo": Credential(salt: "pL3xTq8Nv2Ws6Rd9Fg4Hj7Km1Zb5Xc0Q", hash: "79bd658ef3b4dd4e6a6dd0cedc4fae4eee69e32ac1e00b8a8d323ed7d09df882"),
        "HugoMartinez": Credential(salt: "aZ8kM3nR7pT1vY6wQ2sE5dF9gH4jL0Bx", hash: "7d060daa6dedd15e08be911e8886132f32f303679ce1cff0efb54c03be5ffec0"),
        "MarcVilanova": Credential(salt: "dF6gJ2kL8mN4pQ9rS1tU3vW5xY7zA0Bc", hash: "27bfd9ab940dd821e6f2bbecdd238d78ce1305d9acff0dd231956413ce2ba5fa"),
        "DavidHernandez": Credential(salt: "rS2tU9vW1xY4zA7bC0dE3fG6hJ8kL5mN", hash: "9e35b2448a2bd7e7bd362ba07b42361aab7f7f00e5dc63246ddf51096828ac20"),
        "MarcelRosell": Credential(salt: "hK5jL2mN8pQ1rS4tU7vW0xY3zA6bC9dE", hash: "8f395ded9069be9d4a4970306394a97b286d5e3ecbd1157fc66dd430fd662789"),
        "HectorVelasco": Credential(salt: "vW8xY1zA4bC7dE0fG3hJ6kL9mN2pQ5rS", hash: "1d2cb7acb080a1db0c62dce5580980123681d08de60f0522a0beb3e603c6333e"),
        // Modo prueba del profesor: no es un alumno real. Se valida como
        // cualquier otro (para poder entrar) pero `uploadTarget` bloquea
        // todas sus subidas, así que nunca genera `users/Admin.json`.
        StudentAccounts.adminUsername: Credential(salt: "bC4dE7fG0hJ3kL6mN9pQ2rS5tU8vW1xY", hash: "b313646e566ec22206a476da98cae760cc905622b2e8bf78438a6964331a58a2"),
        // Profesores reales: entran igual que la cuenta Admin y también
        // bloquean toda subida, así que la web no muestra ningún dato suyo.
        "professor1": Credential(salt: "kLyISCeCUow5PZ35pPoZN5j052LkG6uV", hash: "4a2fadf696337083a08cea00da27d90ba2316cf58ae8b3c47b363bea4a5e139a"),
        "professor2": Credential(salt: "g5bri3OKi8Xwk0yzBBkdcaTcNM92lvpd", hash: "33eee279ff6918ae5377a4a2f9d37c2d1306f36f47c758b16952b5019a580f5f"),
        "professor3": Credential(salt: "PWnciLJGjoi7pTtTdQQfql1zPQbIUhPG", hash: "bcf4981aff2fcf456e462d4b378610591ac8ed66fde284bcb6b0a82ffe3c64be"),
        "professor4": Credential(salt: "URQ42UBjnQ7sqJy8oOmvJFyd8vtHi2dX", hash: "3fb431661234733518c330d9770a26b283046b698150397ec42c366212f4a6a3"),
        "professor5": Credential(salt: "hytJxVKkexolzK72yLaX3JZIJ0ttbVj7", hash: "4e10b24c28ed00faacd272a195f2b5712abe3c2297cee619d65278ca768f03bc"),
    ]

    /// Usuarios con rol de profesor: la cuenta especial `Admin` más los
    /// profesores reales (`professor1`…`professor5`). Validan como cualquier
    /// otra cuenta, pero `uploadTarget` los bloquea: no existe
    /// `users/professorN.json` ni aparecen en la web.
    public static let professorUsernames: [String] = [
        adminUsername, "professor1", "professor2", "professor3", "professor4", "professor5",
    ]

    /// SHA-256 en hexadecimal de `salt|usuario|contraseña`. Pública para
    /// generar nuevas cuentas y para que los tests fijen los valores.
    public static func digest(salt: String, username: String, password: String) -> String {
        let material = "\(salt)|\(username)|\(password)"
        return SHA256.hash(data: Data(material.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// Resuelve el usuario canónico (con sus mayúsculas) ignorando
    /// mayúsculas/minúsculas. GitHub distingue mayúsculas, la gente no.
    public static func canonicalUsername(_ raw: String) -> String? {
        let u = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty else { return nil }
        if credentials[u] != nil { return u }
        return credentials.keys.first {
            $0.caseInsensitiveCompare(u) == .orderedSame
        }
    }

    /// Valida contra los hashes y devuelve el usuario canónico (nil si falla).
    public static func verify(username: String, password: String) -> String? {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty, !password.isEmpty,
              let canonical = canonicalUsername(u),
              let credential = credentials[canonical] else {
            return nil
        }
        let expected = digest(salt: credential.salt, username: canonical.lowercased(), password: password)
        return constantTimeEquals(expected, credential.hash) ? canonical : nil
    }

    /// Validación pura y testeable.
    public static func validate(username: String, password: String) -> Bool {
        verify(username: username, password: password) != nil
    }

    /// `true` si el usuario tiene rol de profesor (cualquiera de
    /// `professorUsernames`: la especial Admin y los profesores reales).
    /// Tolera espacios y mayúsculas/minúsculas.
    public static func isAdmin(username: String?) -> Bool {
        guard let raw = username else { return false }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return professorUsernames.contains {
            $0.caseInsensitiveCompare(trimmed) == .orderedSame
        }
    }

    /// Comparación de digests sin cortes tempranos por longitud.
    private static func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let lhs = Array(a.utf8)
        let rhs = Array(b.utf8)
        guard lhs.count == rhs.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<lhs.count { diff |= lhs[i] ^ rhs[i] }
        return diff == 0
    }
}

// MARK: - Bloqueo local ante intentos fallidos

/// Evita probar contraseñas en el dispositivo: tras `maxAttempts` fallos
/// seguidos hay que esperar `lockInterval` segundos.
public enum AuthRateLimiter {

    public static let maxAttempts = 5
    public static let lockInterval: TimeInterval = 30
    public static let attemptsKey = "auth.attempts"
    public static let lockedUntilKey = "auth.lockedUntil"

    /// Segundos de bloqueo restantes (0 = sin bloqueo).
    public static func remainingLock(
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> TimeInterval {
        let until = defaults.double(forKey: lockedUntilKey)
        guard until > 0 else { return 0 }
        let left = until - now.timeIntervalSince1970
        return left > 0 ? left : 0
    }

    /// Registra un fallo. Devuelve los segundos de bloqueo activos tras él.
    @discardableResult
    public static func recordFailure(
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> TimeInterval {
        let attempts = defaults.integer(forKey: attemptsKey) + 1
        if attempts >= maxAttempts {
            defaults.set(0, forKey: attemptsKey)
            defaults.set(now.timeIntervalSince1970 + lockInterval, forKey: lockedUntilKey)
        } else {
            defaults.set(attempts, forKey: attemptsKey)
        }
        return remainingLock(now: now, defaults: defaults)
    }

    public static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: attemptsKey)
        defaults.removeObject(forKey: lockedUntilKey)
    }
}
