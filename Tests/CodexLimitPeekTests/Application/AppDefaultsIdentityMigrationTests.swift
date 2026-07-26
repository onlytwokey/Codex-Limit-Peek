import Foundation
import Testing
@testable import CodexLimitPeek

struct AppDefaultsIdentityMigrationTests {
    @Test @MainActor
    func copiesAppSettingsWithoutCopyingStatusItemHostState() throws {
        let suiteName = "AppDefaultsIdentityMigrationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("bold", forKey: "appearance.selectedTheme")

        AppDefaultsIdentityMigration.migrateIfNeeded(
            defaults: defaults,
            bundleIdentifier:
                AppDefaultsIdentityMigration.currentBundleIdentifier,
            legacyDomain: [
                "appearance.selectedTheme": "loud",
                "quota.remainingPercent": 82,
                "NSStatusItem VisibleCC Item-0": 1,
            ]
        )

        #expect(defaults.string(forKey: "appearance.selectedTheme") == "bold")
        #expect(defaults.integer(forKey: "quota.remainingPercent") == 82)
        #expect(defaults.object(forKey: "NSStatusItem VisibleCC Item-0") == nil)
        #expect(
            defaults.bool(
                forKey: AppDefaultsIdentityMigration.completionKey
            )
        )
    }

    @Test @MainActor
    func ignoresLegacyValuesAfterMigrationCompletes() throws {
        let suiteName = "AppDefaultsIdentityMigrationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AppDefaultsIdentityMigration.migrateIfNeeded(
            defaults: defaults,
            bundleIdentifier:
                AppDefaultsIdentityMigration.currentBundleIdentifier,
            legacyDomain: ["quota.remainingPercent": 82]
        )
        AppDefaultsIdentityMigration.migrateIfNeeded(
            defaults: defaults,
            bundleIdentifier:
                AppDefaultsIdentityMigration.currentBundleIdentifier,
            legacyDomain: ["quota.remainingPercent": 10]
        )

        #expect(defaults.integer(forKey: "quota.remainingPercent") == 82)
    }
}
