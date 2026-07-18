import Foundation
import Testing
@testable import CodexLimitPeek

@Suite(.serialized)
struct AppearanceStoreTests {
    @Test @MainActor
    func firstRunDefaultsToLoud() {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(defaults: defaults)

        #expect(store.selectedTheme == .loud)
        #expect(store.currentProfile == .default(for: .loud))
    }

    @Test @MainActor
    func unknownSelectedThemeFallsBackToLoud() {
        let defaults = isolatedDefaults()
        defaults.set("missing-theme", forKey: AppearancePersistenceKey.selectedTheme)

        let store = AppearanceStore(defaults: defaults)

        #expect(store.selectedTheme == .loud)
    }

    @Test @MainActor
    func eachThemeKeepsIndependentCustomizations() {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(defaults: defaults)

        store.updateCurrent { $0.geometry.shadowDepth = 2 }
        store.select(.bold)
        store.updateCurrent { $0.geometry.shadowDepth = 7 }
        store.select(.frost)
        store.updateCurrent { $0.geometry.shadowDepth = 1 }
        store.flushPendingSave()

        let restored = AppearanceStore(defaults: defaults)
        #expect(restored.selectedTheme == .frost)
        #expect(restored.profile(for: .loud).geometry.shadowDepth == 2)
        #expect(restored.profile(for: .bold).geometry.shadowDepth == 7)
        #expect(restored.profile(for: .frost).geometry.shadowDepth == 1)
    }

    @Test @MainActor
    func capturedThemeColorWriteDoesNotFollowCurrentSelection() {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(defaults: defaults)
        let expected = AppearanceColor(hex: 0x4A6FA5, alpha: 0.42)

        store.select(.loud)
        let initialRevision = store.revision
        store.setColor(expected, for: .surface, in: .bold)

        #expect(store.selectedTheme == .loud)
        #expect(store.revision == initialRevision)
        #expect(store.profile(for: .bold).palette.surface == expected)
        #expect(
            store.profile(for: .loud).palette.surface
                != expected
        )

        store.flushPendingSave()
        #expect(
            AppearanceStore(defaults: defaults)
                .profile(for: .bold).palette.surface == expected
        )
    }

    @Test @MainActor
    func changesAutoPersistAfterDebounceWithoutManualFlush() async throws {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(
            defaults: defaults,
            saveDelayNanoseconds: 5_000_000
        )
        let expectedColor = AppearanceColor(hex: 0x2F6F69)

        store.select(.bold)
        store.setColor(expectedColor, for: .normal)

        #expect(!store.isSaved)
        for _ in 0..<100 {
            if store.isSaved {
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(store.isSaved)

        let restored = AppearanceStore(defaults: defaults)
        #expect(restored.selectedTheme == .bold)
        #expect(restored.profile(for: .bold).palette.normal == expectedColor)
    }

    @Test @MainActor
    func stateColorsPersistIndependentlyForEveryTheme() {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(defaults: defaults)
        let stateTokens: [AppearanceColorToken] = [
            .normal,
            .warning,
            .danger,
            .unavailableBase,
            .unavailableStripe
        ]
        let expectedByTheme: [AppearanceThemeID: [AppearanceColor]] = [
            .loud: [
                AppearanceColor(hex: 0x126E68),
                AppearanceColor(hex: 0x9A4D00),
                AppearanceColor(hex: 0xA62F35),
                AppearanceColor(hex: 0xFFFDF3),
                AppearanceColor(hex: 0xD13B43)
            ],
            .bold: [
                AppearanceColor(hex: 0x237B73),
                AppearanceColor(hex: 0xA56A00),
                AppearanceColor(hex: 0xB43C43),
                AppearanceColor(hex: 0xEEEAE0),
                AppearanceColor(hex: 0xB64B50)
            ],
            .frost: [
                AppearanceColor(hex: 0x2A8278),
                AppearanceColor(hex: 0x9B6F13),
                AppearanceColor(hex: 0xB84956),
                AppearanceColor(hex: 0xE7F2F4),
                AppearanceColor(hex: 0xAD5260)
            ]
        ]

        for theme in AppearanceThemeID.allCases {
            store.select(theme)
            let colors = expectedByTheme[theme]!
            for (token, color) in zip(stateTokens, colors) {
                store.setColor(color, for: token)
            }
        }
        store.flushPendingSave()

        let restored = AppearanceStore(defaults: defaults)
        for theme in AppearanceThemeID.allCases {
            let colors = expectedByTheme[theme]!
            for (token, expected) in zip(stateTokens, colors) {
                #expect(restored.profile(for: theme).palette[token] == expected)
            }
        }
    }

    @Test @MainActor
    func statusItemGeometryRoundTripsIndependentlyForEveryTheme() {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(defaults: defaults)
        let expected: [AppearanceThemeID: StatusItemGeometry] = [
            .loud: StatusItemGeometry(
                fontSize: 8.5,
                outlineWidth: 0.5,
                cornerRadius: 2,
                shadowDepth: 1,
                shadowBlur: 0.5,
                horizontalPadding: 3,
                tagHeight: 15
            ),
            .bold: StatusItemGeometry(
                fontSize: 11,
                outlineWidth: 2,
                cornerRadius: 6,
                shadowDepth: 3,
                shadowBlur: 2,
                horizontalPadding: 8,
                tagHeight: 18
            ),
            .frost: StatusItemGeometry(
                fontSize: 13.5,
                outlineWidth: 3.5,
                cornerRadius: 11,
                shadowDepth: 5.5,
                shadowBlur: 7.5,
                horizontalPadding: 13.5,
                tagHeight: 21.5
            )
        ]

        for theme in AppearanceThemeID.allCases {
            store.select(theme)
            store.updateCurrent {
                $0.statusItemGeometry = expected[theme]!
            }
        }
        store.flushPendingSave()

        let restored = AppearanceStore(defaults: defaults)
        for theme in AppearanceThemeID.allCases {
            #expect(
                restored.profile(for: theme).statusItemGeometry
                    == expected[theme]
            )
        }
    }

    @Test @MainActor
    func resetOnlyChangesTheSelectedTheme() {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(defaults: defaults)
        store.setEditorFontScale(1.3)
        store.updateCurrent {
            $0.geometry.fontScale = 1.2
            $0.statusItemGeometry.fontSize = 13
        }
        store.select(.bold)
        store.updateCurrent {
            $0.geometry.fontScale = 0.9
            $0.statusItemGeometry.fontSize = 8.5
        }

        store.resetCurrentTheme()

        #expect(store.profile(for: .bold) == .default(for: .bold))
        #expect(store.profile(for: .loud).geometry.fontScale == 1.2)
        #expect(
            store.profile(for: .bold).statusItemGeometry
                == .default(for: .bold)
        )
        #expect(
            store.profile(for: .loud).statusItemGeometry.fontSize == 13
        )
        #expect(store.editorFontScale == 1.3)

        store.flushPendingSave()
        let restored = AppearanceStore(defaults: defaults)
        #expect(restored.profile(for: .bold) == .default(for: .bold))
        #expect(restored.profile(for: .loud).geometry.fontScale == 1.2)
        #expect(
            restored.profile(for: .bold).statusItemGeometry
                == .default(for: .bold)
        )
        #expect(
            restored.profile(for: .loud).statusItemGeometry.fontSize == 13
        )
        #expect(restored.editorFontScale == 1.3)
    }

    @Test @MainActor
    func canResetCurrentThemeTracksTheSelectedTheme() {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(defaults: defaults)

        #expect(!store.canResetCurrentTheme)

        store.updateCurrent { $0.geometry.shadowDepth = 2 }
        #expect(store.canResetCurrentTheme)

        store.select(.bold)
        #expect(!store.canResetCurrentTheme)

        store.updateCurrent { $0.statusItemGeometry.fontSize = 8.5 }
        #expect(store.canResetCurrentTheme)

        store.select(.loud)
        #expect(store.canResetCurrentTheme)
    }

    @Test @MainActor
    func resettingAnAlreadyDefaultThemeIsANoOp() {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(defaults: defaults)
        let initialRevision = store.revision

        store.resetCurrentTheme()

        #expect(store.currentProfile == .default(for: .loud))
        #expect(store.revision == initialRevision)
        #expect(store.isSaved)
        #expect(store.saveFeedbackState == .saved)
    }

    @Test @MainActor
    func malformedProfileOnlyResetsThatTheme() throws {
        let defaults = isolatedDefaults()
        var bold = AppearanceProfile.default(for: .bold)
        bold.geometry.cornerRadius = 22
        defaults.set(
            try JSONEncoder().encode(bold),
            forKey: AppearancePersistenceKey.profile(.bold)
        )
        defaults.set(
            Data("not-json".utf8),
            forKey: AppearancePersistenceKey.profile(.loud)
        )

        let restored = AppearanceStore(defaults: defaults)

        #expect(restored.profile(for: .loud) == .default(for: .loud))
        #expect(restored.profile(for: .bold).geometry.cornerRadius == 22)
    }

    @Test @MainActor
    func unsupportedSchemaOnlyResetsThatTheme() throws {
        let defaults = isolatedDefaults()
        var loud = AppearanceProfile.default(for: .loud)
        loud.schemaVersion = 999
        defaults.set(
            try JSONEncoder().encode(loud),
            forKey: AppearancePersistenceKey.profile(.loud)
        )

        let restored = AppearanceStore(defaults: defaults)

        #expect(restored.profile(for: .loud) == .default(for: .loud))
    }

    @Test @MainActor
    func colorTokenMutationIsClampedAndPersisted() {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(defaults: defaults)
        store.setColor(
            AppearanceColor(red: 2, green: -1, blue: 0.5, alpha: 4),
            for: .normal
        )
        #expect(!store.isSaved)
        store.flushPendingSave()
        #expect(store.isSaved)

        let restored = AppearanceStore(defaults: defaults)
        #expect(
            restored.profile(for: .loud).palette.normal
                == AppearanceColor(red: 1, green: 0, blue: 0.5, alpha: 1)
        )
    }

    @Test @MainActor
    func everyEditableColorTokenRoundTripsThroughTheStore() {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(defaults: defaults)

        for (index, token) in AppearanceColorToken.allCases.enumerated() {
            let color = AppearanceColor(
                red: Double(index) / 10,
                green: 0.25,
                blue: 0.75
            )
            store.setColor(color, for: token)
            #expect(store.color(for: token) == color)
        }

        store.flushPendingSave()
        let restored = AppearanceStore(defaults: defaults)
        for (index, token) in AppearanceColorToken.allCases.enumerated() {
            let expected = AppearanceColor(
                red: Double(index) / 10,
                green: 0.25,
                blue: 0.75
            )
            #expect(restored.profile(for: .loud).palette[token] == expected)
        }
    }

    @Test @MainActor
    func versionOneProfileMigratesToVersionThreeWithoutLosingCustomColors() throws {
        let defaults = isolatedDefaults()
        var legacy = LegacyAppearanceProfileV1.default(for: .bold)
        legacy.palette.background = AppearanceColor(hex: 0xABCDEF)
        defaults.set(
            try JSONEncoder().encode(legacy),
            forKey: AppearancePersistenceKey.legacyProfileV1(.bold)
        )

        let store = AppearanceStore(defaults: defaults)
        let migrated = store.profile(for: .bold)

        #expect(migrated.schemaVersion == 3)
        #expect(migrated.palette.background == AppearanceColor(hex: 0xABCDEF))
        #expect(
            migrated.palette.actionAccent
                == AppearanceColor(hex: 0xFF8A82)
        )
    }

    @Test @MainActor
    func versionTwoProfileMigratesWithEquivalentStatusAppearance() throws {
        let defaults = isolatedDefaults()
        var legacy = LegacyAppearanceProfileV2.default(for: .bold)
        legacy.geometry.fontScale = 1.25
        legacy.geometry.outlineWidth = 4
        legacy.geometry.cornerRadius = 28
        legacy.geometry.shadowDepth = 10
        legacy.geometry.shadowBlur = 20
        defaults.set(
            try JSONEncoder().encode(legacy),
            forKey: AppearancePersistenceKey.legacyProfileV2(.bold)
        )

        let migrated = AppearanceStore(defaults: defaults).profile(for: .bold)

        #expect(migrated.schemaVersion == 3)
        #expect(migrated.geometry == legacy.geometry.clamped())
        #expect(
            migrated.statusItemGeometry == StatusItemGeometry(
                fontSize: 12.5,
                outlineWidth: 3,
                cornerRadius: 23,
                shadowDepth: 4,
                shadowBlur: 20,
                horizontalPadding: 7,
                tagHeight: 18
            )
        )
    }

    @Test @MainActor
    func malformedVersionThreeFallsBackToValidVersionTwo() throws {
        let defaults = isolatedDefaults()
        var legacy = LegacyAppearanceProfileV2.default(for: .frost)
        legacy.palette.background = AppearanceColor(hex: 0xABCDEF)
        defaults.set(
            Data("broken-v3".utf8),
            forKey: AppearancePersistenceKey.profile(.frost)
        )
        defaults.set(
            try JSONEncoder().encode(legacy),
            forKey: AppearancePersistenceKey.legacyProfileV2(.frost)
        )

        let restored = AppearanceStore(defaults: defaults)

        #expect(
            restored.profile(for: .frost).palette.background
                == AppearanceColor(hex: 0xABCDEF)
        )
        #expect(restored.profile(for: .frost).schemaVersion == 3)
    }

    @Test @MainActor
    func unsupportedVersionThreeFallsBackToVersionTwoAndCorrectsIdentity()
        throws
    {
        let defaults = isolatedDefaults()
        var unsupported = AppearanceProfile.default(for: .bold)
        unsupported.schemaVersion = 999
        unsupported.palette.background = AppearanceColor(hex: 0x111111)
        var legacy = LegacyAppearanceProfileV2.default(for: .loud)
        legacy.palette.background = AppearanceColor(hex: 0xABCDEF)
        legacy.capabilities = AppearanceProfile.default(
            for: .frost
        ).capabilities
        defaults.set(
            try JSONEncoder().encode(unsupported),
            forKey: AppearancePersistenceKey.profile(.bold)
        )
        defaults.set(
            try JSONEncoder().encode(legacy),
            forKey: AppearancePersistenceKey.legacyProfileV2(.bold)
        )

        let migrated = AppearanceStore(defaults: defaults).profile(for: .bold)

        #expect(migrated.palette.background == AppearanceColor(hex: 0xABCDEF))
        #expect(migrated.themeID == .bold)
        #expect(
            migrated.capabilities
                == AppearanceProfile.default(for: .bold).capabilities
        )
    }

    @Test @MainActor
    func invalidVersionTwoFallsBackToVersionOne() throws {
        let malformedDefaults = isolatedDefaults()
        var malformedFallback = LegacyAppearanceProfileV1.default(for: .bold)
        malformedFallback.palette.background = AppearanceColor(hex: 0x123456)
        malformedFallback.capabilities = AppearanceProfile.default(
            for: .frost
        ).capabilities
        malformedDefaults.set(
            Data("broken-v2".utf8),
            forKey: AppearancePersistenceKey.legacyProfileV2(.loud)
        )
        malformedDefaults.set(
            try JSONEncoder().encode(malformedFallback),
            forKey: AppearancePersistenceKey.legacyProfileV1(.loud)
        )

        let malformedResult = AppearanceStore(
            defaults: malformedDefaults
        ).profile(for: .loud)

        #expect(
            malformedResult.palette.background
                == AppearanceColor(hex: 0x123456)
        )
        #expect(malformedResult.themeID == .loud)
        #expect(
            malformedResult.capabilities
                == AppearanceProfile.default(for: .loud).capabilities
        )

        let unsupportedDefaults = isolatedDefaults()
        var unsupported = LegacyAppearanceProfileV2.default(for: .frost)
        unsupported.schemaVersion = 999
        var unsupportedFallback = LegacyAppearanceProfileV1.default(
            for: .loud
        )
        unsupportedFallback.palette.background = AppearanceColor(hex: 0x654321)
        unsupportedDefaults.set(
            try JSONEncoder().encode(unsupported),
            forKey: AppearancePersistenceKey.legacyProfileV2(.frost)
        )
        unsupportedDefaults.set(
            try JSONEncoder().encode(unsupportedFallback),
            forKey: AppearancePersistenceKey.legacyProfileV1(.frost)
        )

        let unsupportedResult = AppearanceStore(
            defaults: unsupportedDefaults
        ).profile(for: .frost)

        #expect(
            unsupportedResult.palette.background
                == AppearanceColor(hex: 0x654321)
        )
        #expect(unsupportedResult.themeID == .frost)
        #expect(
            unsupportedResult.capabilities
                == AppearanceProfile.default(for: .frost).capabilities
        )
    }

    @Test @MainActor
    func validVersionThreeWinsOverOlderProfiles() throws {
        let defaults = isolatedDefaults()
        var current = AppearanceProfile.default(for: .loud)
        current.palette.background = AppearanceColor(hex: 0x123456)
        var legacy = LegacyAppearanceProfileV2.default(for: .loud)
        legacy.palette.background = AppearanceColor(hex: 0xABCDEF)
        defaults.set(
            try JSONEncoder().encode(current),
            forKey: AppearancePersistenceKey.profile(.loud)
        )
        defaults.set(
            try JSONEncoder().encode(legacy),
            forKey: AppearancePersistenceKey.legacyProfileV2(.loud)
        )

        let restored = AppearanceStore(defaults: defaults)

        #expect(
            restored.profile(for: .loud).palette.background
                == AppearanceColor(hex: 0x123456)
        )
    }

    @Test @MainActor
    func untouchedLegacyGeometryMovesToCorrectedReferenceDefaults() throws {
        let defaults = isolatedDefaults()
        defaults.set(
            try JSONEncoder().encode(
                LegacyAppearanceProfileV1.default(for: .loud)
            ),
            forKey: AppearancePersistenceKey.legacyProfileV1(.loud)
        )
        defaults.set(
            try JSONEncoder().encode(
                LegacyAppearanceProfileV1.default(for: .frost)
            ),
            forKey: AppearancePersistenceKey.legacyProfileV1(.frost)
        )

        let store = AppearanceStore(defaults: defaults)

        #expect(store.profile(for: .loud).geometry.cornerRadius == 0)
        #expect(store.profile(for: .frost).geometry.shadowBlur == 0)
    }

    @Test @MainActor
    func customizedLegacyGeometryIsPreservedDuringMigration() throws {
        let defaults = isolatedDefaults()
        var legacy = LegacyAppearanceProfileV1.default(for: .loud)
        legacy.geometry.cornerRadius = 13
        legacy.geometry.shadowDepth = 4
        defaults.set(
            try JSONEncoder().encode(legacy),
            forKey: AppearancePersistenceKey.legacyProfileV1(.loud)
        )

        let migrated = AppearanceStore(defaults: defaults).profile(for: .loud)

        #expect(migrated.geometry.cornerRadius == 13)
        #expect(migrated.geometry.shadowDepth == 4)
    }

    @Test @MainActor
    func savingMigrationKeepsVersionOneAndVersionTwoData() throws {
        let defaults = isolatedDefaults()
        let versionOneData = try JSONEncoder().encode(
            LegacyAppearanceProfileV1.default(for: .loud)
        )
        let versionTwoData = try JSONEncoder().encode(
            LegacyAppearanceProfileV2.default(for: .loud)
        )
        defaults.set(
            versionOneData,
            forKey: AppearancePersistenceKey.legacyProfileV1(.loud)
        )
        defaults.set(
            versionTwoData,
            forKey: AppearancePersistenceKey.legacyProfileV2(.loud)
        )

        let store = AppearanceStore(defaults: defaults)
        store.flushPendingSave()

        #expect(
            defaults.data(
                forKey: AppearancePersistenceKey.legacyProfileV1(.loud)
            ) == versionOneData
        )
        #expect(
            defaults.data(
                forKey: AppearancePersistenceKey.legacyProfileV2(.loud)
            ) == versionTwoData
        )
        let versionThreeData = try #require(
            defaults.data(
                forKey: AppearancePersistenceKey.profile(.loud)
            )
        )
        #expect(
            try JSONDecoder().decode(
                AppearanceProfile.self,
                from: versionThreeData
            ).schemaVersion == 3
        )
    }

    @Test @MainActor
    func appearancePersistenceDoesNotModifyQuotaOrVoiceDefaults() {
        let defaults = isolatedDefaults()
        defaults.set(61, forKey: "quota.remainingPercent")
        defaults.set(10, forKey: "voiceBroadcast.intervalMinutes")
        let store = AppearanceStore(defaults: defaults)

        store.updateCurrent { $0.geometry.cornerRadius = 20 }
        store.flushPendingSave()

        #expect(defaults.integer(forKey: "quota.remainingPercent") == 61)
        #expect(defaults.integer(forKey: "voiceBroadcast.intervalMinutes") == 10)
    }

    @Test @MainActor
    func editorFontScaleIsGlobalClampedAndPersisted() {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(defaults: defaults)

        #expect(store.editorFontScale == 1.15)
        store.setEditorFontScale(4)
        #expect(store.editorFontScale == 1.5)
        store.select(.bold)
        store.resetCurrentTheme()
        #expect(store.editorFontScale == 1.5)

        store.setEditorFontScale(1.35)
        store.flushPendingSave()

        let restored = AppearanceStore(defaults: defaults)
        #expect(restored.editorFontScale == 1.35)
        #expect(restored.selectedTheme == .bold)
    }

    @Test @MainActor
    func malformedEditorFontScaleFallsBackToApprovedDefault() {
        let defaults = isolatedDefaults()
        defaults.set(
            "large",
            forKey: AppearancePersistenceKey.editorFontScale
        )

        let restored = AppearanceStore(defaults: defaults)

        #expect(restored.editorFontScale == 1.15)
    }

    @Test @MainActor
    func booleanEditorFontScaleFallsBackToApprovedDefault() {
        let defaults = isolatedDefaults()
        defaults.set(
            true,
            forKey: AppearancePersistenceKey.editorFontScale
        )

        let restored = AppearanceStore(defaults: defaults)

        #expect(restored.editorFontScale == 1.15)
    }

    @Test @MainActor
    func sliderEditingDefersDiskWriteAndFeedbackUntilMouseUp()
        async throws
    {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(
            defaults: defaults,
            saveDelayNanoseconds: 5_000_000
        )

        store.sliderEditingChanged(true)
        store.updateCurrent { $0.geometry.fontScale = 1.2 }

        #expect(!store.isSaved)
        #expect(store.saveFeedbackState == .saved)
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(
            AppearanceStore(defaults: defaults)
                .currentProfile.geometry.fontScale == 1
        )

        store.sliderEditingChanged(false)
        #expect(store.saveFeedbackState == .saving)
        try await Task.sleep(nanoseconds: 30_000_000)

        #expect(store.isSaved)
        #expect(store.saveFeedbackState == .saved)
        #expect(
            AppearanceStore(defaults: defaults)
                .currentProfile.geometry.fontScale == 1.2
        )
    }

    @Test @MainActor
    func sliderClickWithoutValueChangeDoesNotCreateFalseSaveFeedback() {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(defaults: defaults)

        store.sliderEditingChanged(true)
        store.sliderEditingChanged(false)

        #expect(store.isSaved)
        #expect(store.saveFeedbackState == .saved)
    }

    @Test @MainActor
    func flushDuringSliderEditingPersistsLatestValue() {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(defaults: defaults)

        store.sliderEditingChanged(true)
        store.setEditorFontScale(1.45)
        store.flushPendingSave()
        store.sliderEditingChanged(false)

        #expect(store.isSaved)
        #expect(store.saveFeedbackState == .saved)
        #expect(
            AppearanceStore(defaults: defaults).editorFontScale == 1.45
        )
    }

    @Test @MainActor
    func editorFontScaleDoesNotRepositionTheMainPanel() {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(defaults: defaults)
        let initialRevision = store.revision

        store.setEditorFontScale(1.3)

        #expect(store.revision == initialRevision)
    }

    @Test @MainActor
    func secondDragCancelsPendingWriteWithoutReturningToSaved()
        async throws
    {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(
            defaults: defaults,
            saveDelayNanoseconds: 5_000_000
        )

        store.sliderEditingChanged(true)
        store.updateCurrent { $0.geometry.fontScale = 1.1 }
        store.sliderEditingChanged(false)
        #expect(store.saveFeedbackState == .saving)

        store.sliderEditingChanged(true)
        store.updateCurrent { $0.geometry.fontScale = 1.2 }
        try await Task.sleep(nanoseconds: 30_000_000)

        #expect(store.saveFeedbackState == .saving)
        #expect(
            AppearanceStore(defaults: defaults)
                .currentProfile.geometry.fontScale == 1
        )

        store.sliderEditingChanged(false)
        try await Task.sleep(nanoseconds: 30_000_000)

        #expect(store.saveFeedbackState == .saved)
        #expect(
            AppearanceStore(defaults: defaults)
                .currentProfile.geometry.fontScale == 1.2
        )
    }

    @Test @MainActor
    func nonSliderChangeShowsSavingUntilPersistenceSucceeds()
        async throws
    {
        let defaults = isolatedDefaults()
        let store = AppearanceStore(
            defaults: defaults,
            saveDelayNanoseconds: 5_000_000
        )

        store.select(.bold)

        #expect(store.saveFeedbackState == .saving)
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(store.saveFeedbackState == .saved)
        #expect(AppearanceStore(defaults: defaults).selectedTheme == .bold)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "AppearanceStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
