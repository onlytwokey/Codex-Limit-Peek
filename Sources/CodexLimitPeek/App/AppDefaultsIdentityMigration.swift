import Foundation

@MainActor
enum AppDefaultsIdentityMigration {
    static let currentBundleIdentifier =
        "io.github.onlytwokey.CodexLimitPeek.MenuBar"
    static let legacyBundleIdentifier =
        "io.github.onlytwokey.CodexLimitPeek"
    static let completionKey = "app.bundleIdentityMigration.v1"

    static func migrateIfNeeded(
        defaults: UserDefaults = .standard,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        legacyDomain: [String: Any]? = nil
    ) {
        guard bundleIdentifier == currentBundleIdentifier else { return }
        guard !defaults.bool(forKey: completionKey) else { return }

        let values = legacyDomain
            ?? defaults.persistentDomain(
                forName: legacyBundleIdentifier
            )
        if let values {
            for (key, value) in values where shouldMigrate(key) {
                guard defaults.object(forKey: key) == nil else { continue }
                defaults.set(value, forKey: key)
            }
        }

        defaults.set(true, forKey: completionKey)
    }

    static func shouldMigrate(_ key: String) -> Bool {
        !key.hasPrefix("NSStatusItem")
    }
}
