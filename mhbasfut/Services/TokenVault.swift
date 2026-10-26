//
//  TokenVault.swift
//  mhbasfut
//
//  Almacenamiento del PAT de GitHub.
//
//  El token NO vive en el código fuente: se entrega en un recurso del bundle
//  (`GitHubToken.plist`, ignorado por git y con el payload ofuscado), se
//  importa al Keychain en el primer arranque y a partir de ahí solo se lee
//  de ahí. Así el valor no aparece en `git grep`, en `strings` del binario
//  ni en `UserDefaults`, y ninguna contraseña o clave se persiste en claro.
//
//  Si el recurso no existe (clone limpio / CI) no hay token: la app funciona
//  igual y la sincronización queda apagada con el mensaje que ya existe en
//  GitHubSyncService.
//

import Foundation
import Security

public enum TokenVault {

    // MARK: - Config

    public static let service = "absurdstudio.mhbasfut.secrets"
    public static let account = "github.pat"

    private static let payloadResource = "GitHubToken"
    private static let payloadKey = "payload"
    /// Clave de ofuscación XOR. Es ofuscación, no cripto: sirve para que el
    /// valor no sea legible con `strings`, no para protegerlo de un atacante
    /// con el binario en la mano (eso exigiría un backend).
    private static let xorKey: [UInt8] = Array("MHB4sFutTok3nXOR!".utf8)

    // MARK: - API pública

    /// Token activo: Keychain → importación desde el bundle → nil.
    public static func token() -> String? {
        if let stored = readKeychain(), !stored.isEmpty {
            return stored
        }
        guard let imported = importFromBundle(), !imported.isEmpty else { return nil }
        writeKeychain(imported)
        // Ya está en el Keychain: el payload del bundle deja de leerse.
        return imported
    }

    /// Sobrescribir (o borrar, con nil) el token guardado. Rotación manual.
    public static func setToken(_ value: String?) {
        guard let value, !value.isEmpty else {
            deleteKeychain()
            return
        }
        writeKeychain(value)
    }

    public static func clear() { deleteKeychain() }

    // MARK: - Bundle (recurso git-ignored)

    /// Lee e importa el recurso `GitHubToken.plist`. Devuelve nil si no existe.
    public static func importFromBundle() -> String? {
        guard let url = Bundle.main.url(forResource: payloadResource, withExtension: "plist") else {
            return nil
        }
        guard let data = try? Data(contentsOf: url),
              let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
              let payload = plist[payloadKey] as? String else {
            return nil
        }
        return decode(payload)
    }

    /// base64 → XOR. Inverso exacto de como se genera el recurso.
    public static func decode(_ payload: String) -> String? {
        guard let raw = Data(base64Encoded: payload), !raw.isEmpty else { return nil }
        let out = raw.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> [UInt8] in
            let bytes = buf.bindMemory(to: UInt8.self)
            return bytes.enumerated().map { $0.element ^ xorKey[$0.offset % xorKey.count] }
        }
        return String(decoding: out, as: UTF8.self)
    }

    // MARK: - Keychain

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public static func readKeychain() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              !data.isEmpty,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private static func writeKeychain(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    private static func deleteKeychain() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}
