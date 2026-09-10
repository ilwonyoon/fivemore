import Foundation
import Security

@MainActor
final class TrialUsageStore: ObservableObject {
    /// Generous on purpose: a parent should have weeks of real use before the
    /// unlock is ever mentioned, so the purchase reads as a tip rather than a
    /// gate.
    static let freeLimit = 30

    @Published private(set) var usedCount: Int

    var remainingCount: Int {
        max(0, Self.freeLimit - usedCount)
    }

    private let service = "com.fivemore.app.trial"
    private let account = "successful-moments"

    init() {
        usedCount = 0
        usedCount = readCount()
    }

    func consumeUse() {
        guard usedCount < Self.freeLimit else { return }
        usedCount += 1
        persistCount(usedCount)
    }

    func reconcile(minimumUsedCount: Int) {
        let reconciled = min(Self.freeLimit, max(usedCount, minimumUsedCount))
        guard reconciled != usedCount else { return }
        usedCount = reconciled
        persistCount(reconciled)
    }

#if DEBUG
    func resetForDevelopment() {
        usedCount = 0
        SecItemDelete(baseQuery() as CFDictionary)
    }
#endif

    private func readCount() -> Int {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              let count = Int(value) else {
            return 0
        }

        return min(Self.freeLimit, max(0, count))
    }

    private func persistCount(_ count: Int) {
        let data = Data(String(count).utf8)
        let query = baseQuery()
        let attributes = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

