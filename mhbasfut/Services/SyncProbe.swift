//
//  SyncProbe.swift
//  mhbasfut
//
//  Sonda manual de extremo a extremo. Solo compila en Debug y solo se
//  ejecuta con el argumento de lanzamiento `--sync-probe`:
//
//      xcrun simctl launch booted AbsurdStudio.mhbasfut --sync-probe
//
//  Crea `users/AppSmokeTest.json` en GitHub, lo vuelve a leer y lo borra,
//  registrando cada código HTTP. Comprueba de verdad el token y la ruta de
//  escritura sin tocar los ficheros reales de los alumnos.
//

#if DEBUG

import Foundation

enum SyncProbe {

    /// Nombre de fichero desechable: `users/AppSmokeTest.json`.
    static let username = "AppSmokeTest"

    @MainActor
    static func run() async {
        let sync = GitHubSyncService.shared
        guard let token = sync.activeToken else {
            print("[SyncProbe] SIN TOKEN: no hay GitHubToken.plist en el bundle ni valor en el Keychain. Sync apagada.")
            return
        }
        let session = URLSession.shared
        let formatter = ISO8601DateFormatter()

        // 1. Estado inicial: ¿existe ya un fichero con ese nombre?
        let initial = await get(session: session, token: token)
        print("[SyncProbe] 1/5 GET inicial → HTTP \(initial.status), sha = \(initial.sha ?? "nil")")

        // 2. PUT de creación (con SHA si ya existía).
        let payload: [String: Any] = [
            "schemaVersion": 0,
            "username": username,
            "probe": "MHBasfut",
            "exportedAt": formatter.string(from: Date()),
        ]
        let jsonData = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data("{}".utf8)
        let put = await put(session: session, token: token, jsonData: jsonData, sha: initial.sha)
        print("[SyncProbe] 2/5 PUT creación → HTTP \(put)")

        // 3. GET para el SHA del fichero recién escrito.
        let written = await get(session: session, token: token)
        print("[SyncProbe] 3/5 GET posterior → HTTP \(written.status), sha = \(written.sha ?? "nil")")

        // 4. DELETE (mismo mecanismo que "Eliminar mi cuenta").
        let deleted = await delete(session: session, token: token, sha: written.sha)
        print("[SyncProbe] 4/5 DELETE → HTTP \(deleted)")

        // 5. Comprobación final: ya no debe existir.
        let final = await get(session: session, token: token)
        let ok = (200...299).contains(put) && final.status == 404 && (200...299).contains(deleted)
        print("[SyncProbe] 5/5 GET final → HTTP \(final.status) (se esperaba 404)")
        print(ok ? "[SyncProbe] RESULTADO: OK — escritura y borrado reales funcionan."
                 : "[SyncProbe] RESULTADO: FAIL — revisa los códigos HTTP de arriba.")
    }

    // MARK: - Peticiones

    private static func get(session: URLSession, token: String) async -> (status: Int, sha: String?) {
        guard var req = request("GET", token: token) else { return (-1, nil) }
        req.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { return (-1, nil) }
            let sha = http.statusCode == 200 ? GitHubSyncService.parseSHA(from: data) : nil
            return (http.statusCode, sha)
        } catch {
            return (-1, nil)
        }
    }

    private static func put(
        session: URLSession,
        token: String,
        jsonData: Data,
        sha: String?
    ) async -> Int {
        guard let req = GitHubSyncService.buildPutRequest(
            username: username,
            jsonData: jsonData,
            sha: sha,
            token: token
        ) else { return -1 }
        do {
            let (_, response) = try await session.data(for: req)
            return (response as? HTTPURLResponse)?.statusCode ?? -1
        } catch {
            return -1
        }
    }

    private static func delete(session: URLSession, token: String, sha: String?) async -> Int {
        guard let sha,
              let req = request("DELETE", token: token, body: [
                  "message": "sync probe: delete \(username).json",
                  "sha": sha,
              ]) else { return -1 }
        do {
            let (_, response) = try await session.data(for: req)
            return (response as? HTTPURLResponse)?.statusCode ?? -1
        } catch {
            return -1
        }
    }

    private static func request(_ method: String, token: String, body: [String: Any]? = nil) -> URLRequest? {
        guard let url = GitHubSyncService.contentsURL(username: username) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("MHBasfut-iOS", forHTTPHeaderField: "User-Agent")
        if let body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return req
    }
}

#endif
