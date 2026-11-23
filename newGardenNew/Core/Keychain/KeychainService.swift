import Foundation
import Security
import os

enum KeychainError: Error, Sendable {
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case encodingFailed
}

extension KeychainError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            String(localized: "keychain.error.notFound", defaultValue: "No se encontró el valor guardado.")
        case .unexpectedStatus:
            String(localized: "keychain.error.unexpected", defaultValue: "No se pudo acceder al llavero del dispositivo.")
        case .encodingFailed:
            String(localized: "keychain.error.encoding", defaultValue: "El valor no se pudo codificar.")
        }
    }
}

nonisolated final class KeychainService: KeychainServiceProtocol, Sendable {
    private let serviceName: String

    init(serviceName: String = "com.ipo.newGardenNew") {
        self.serviceName = serviceName
    }

    func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func read(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

/// In-memory double for previews and tests.
nonisolated final class InMemoryKeychainService: KeychainServiceProtocol, Sendable {
    private let store = OSAllocatedUnfairLock(initialState: [String: String]())

    init(seed: [String: String] = [:]) {
        store.withLock { $0 = seed }
    }

    func save(key: String, value: String) throws {
        store.withLock { $0[key] = value }
    }

    func read(key: String) throws -> String? {
        store.withLock { $0[key] }
    }

    func delete(key: String) throws {
        store.withLock { _ = $0.removeValue(forKey: key) }
    }
}
