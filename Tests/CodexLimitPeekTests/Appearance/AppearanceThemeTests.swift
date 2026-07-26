import Testing
@testable import CodexLimitPeek

struct AppearanceThemeTests {
    @Test
    func themeNamesAndDefaultCapabilitiesMatchTheApprovedDesign() {
        #expect(AppearanceThemeID.allCases.map(\.displayName) == ["LOUD", "BOLD", "FROST"])

        let loud = AppearanceProfile.default(for: .loud)
        let bold = AppearanceProfile.default(for: .bold)
        let frost = AppearanceProfile.default(for: .frost)

        #expect(loud.palette.background == AppearanceColor(hex: 0xFFE36E))
        #expect(loud.geometry.outlineWidth == 3)
        #expect(loud.geometry.cornerRadius == 0)
        #expect(loud.geometry.shadowDepth == 8)
        #expect(loud.capabilities.uppercaseMetadata)
        #expect(!loud.capabilities.usesMaterial)

        #expect(bold.palette.background == AppearanceColor(hex: 0xF7F3E8))
        #expect(bold.geometry.outlineWidth == 2)
        #expect(!bold.capabilities.uppercaseMetadata)

        #expect(
            frost.palette.background
                == AppearanceColor(hex: 0xDDF3F8, alpha: 0.72)
        )
        #expect(frost.geometry.cornerRadius == 16)
        #expect(frost.geometry.shadowBlur == 0)
        #expect(frost.capabilities.usesMaterial)
        #expect(frost.capabilities.roundedPrimaryTypography)
    }

    @Test
    func backgroundPresetOpacityMatchesThemeMaterialSemantics() {
        let opaqueBlue = AppearanceColor(hex: 0xDDF3F8)
        let translucentBlue = AppearanceColor(hex: 0xDDF3F8, alpha: 0.72)

        for theme in [AppearanceThemeID.loud, .bold] {
            let preset = AppearanceEditorPalette.swatches(
                for: .background,
                theme: theme
            )[2]
            #expect(preset == opaqueBlue)

            var profile = AppearanceProfile.default(for: theme)
            profile.palette.background = preset
            let resolved = AppearanceResolver.panel(
                profile: profile,
                primaryRemainingPercent: 81,
                weeklyRemainingPercent: 49,
                isUnavailable: false
            )
            #expect(resolved.visuals.panelFill == .solid)
            #expect(resolved.backgroundColor.alpha == 1)
        }

        #expect(
            AppearanceEditorPalette.swatches(
                for: .background,
                theme: .frost
            )[2] == translucentBlue
        )
    }

    @Test
    func stateColorPresetsMatchTheApprovedThemeSpecificMaterialArchive() {
        let cases: [(
            theme: AppearanceThemeID,
            token: AppearanceColorToken,
            expected: [AppearanceColor]
        )] = [
            (
                .loud,
                .normal,
                colors(0x4FC9C1, 0x3B82F6, 0x5DBB63, 0x8A6BFF, 0x006B72)
            ),
            (
                .loud,
                .warning,
                colors(0xFF9F1C, 0xFFD60A, 0xB99A00, 0xFFB48A, 0x8A4B00)
            ),
            (
                .loud,
                .danger,
                colors(0xFF676B, 0xD90429, 0xD8327D, 0xB743E6, 0x6D1F2A)
            ),
            (
                .loud,
                .unavailableBase,
                colors(0xFFFFFF, 0xC6E6FF, 0xC9DBB7, 0xD9C8FF, 0x23252B)
            ),
            (
                .loud,
                .unavailableStripe,
                colors(0xFF676B, 0x1F5FBF, 0x657300, 0x7A4CC2, 0xE8EFF2)
            ),
            (
                .bold,
                .normal,
                colors(0x45C7BB, 0x004C9E, 0x146B32, 0x737900, 0x12323A)
            ),
            (
                .bold,
                .warning,
                colors(0xE8BE3F, 0xFFF6C2, 0x806000, 0xC24A12, 0x442800)
            ),
            (
                .bold,
                .danger,
                colors(0xE76B68, 0x9A0030, 0xB50078, 0x4F1A78, 0x3A0C16)
            ),
            (
                .bold,
                .unavailableBase,
                colors(0xE9E6DE, 0x9BBFD1, 0xA9C28F, 0xC9947E, 0x292A2B)
            ),
            (
                .bold,
                .unavailableStripe,
                colors(0xC55B59, 0x49647A, 0x4F5D2A, 0x6D3A2A, 0xB6BEC1)
            ),
            (
                .frost,
                .normal,
                colors(0x4FC9C1, 0x77A9DF, 0x61A884, 0x8B7DD6, 0x3B7180)
            ),
            (
                .frost,
                .warning,
                colors(0xE3BB55, 0xF5E6A1, 0xB28B45, 0xE7A17E, 0x7A5935)
            ),
            (
                .frost,
                .danger,
                colors(0xE46D78, 0xB83B58, 0xC94F91, 0x8354A7, 0x663844)
            ),
            (
                .frost,
                .unavailableBase,
                colors(0xEFF4F5, 0xAACBE6, 0x9DC9B0, 0xC3A8D8, 0x2A3842)
            ),
            (
                .frost,
                .unavailableStripe,
                colors(0xCE6670, 0x3E739B, 0x356653, 0x5C4088, 0xD4E4EB)
            )
        ]

        for item in cases {
            let actual = AppearanceEditorPalette.swatches(
                for: item.token,
                theme: item.theme
            )
            #expect(actual == item.expected)
            #expect(actual.first == AppearanceProfile.default(
                for: item.theme
            ).palette[item.token])
            #expect(Set(actual).count == 5)
        }
    }

    @Test
    func everyThemeHasAnIndependentApprovedActionAccent() {
        #expect(
            AppearanceProfile.default(for: .loud).palette.actionAccent
                == AppearanceColor(hex: 0xFF676B)
        )
        #expect(
            AppearanceProfile.default(for: .bold).palette.actionAccent
                == AppearanceColor(hex: 0xFF8A82)
        )
        #expect(
            AppearanceProfile.default(for: .frost).palette.actionAccent
                == AppearanceColor(hex: 0xFF676B)
        )
        #expect(
            AppearanceProfile.default(for: .bold).palette.actionAccent
                != AppearanceProfile.default(for: .bold).palette.danger
        )
    }

    @Test(arguments: [
        (0, QuotaAppearanceState.danger),
        (20, QuotaAppearanceState.danger),
        (21, QuotaAppearanceState.warning),
        (45, QuotaAppearanceState.warning),
        (46, QuotaAppearanceState.normal),
        (100, QuotaAppearanceState.normal)
    ])
    func quotaThresholdsRemainUnchanged(
        percent: Int,
        expected: QuotaAppearanceState
    ) {
        #expect(
            AppearanceResolver.state(
                remainingPercent: percent,
                isUnavailable: false
            ) == expected
        )
    }

    @Test
    func unavailableOverridesRemainingPercentage() {
        #expect(
            AppearanceResolver.state(
                remainingPercent: 100,
                isUnavailable: true
            ) == .unavailable
        )
    }

    @Test
    func validationClampsEveryEditableNumericValue() {
        var profile = AppearanceProfile.default(for: .loud)
        profile.geometry = ThemeGeometry(
            fontScale: 5,
            outlineWidth: -1,
            cornerRadius: 80,
            shadowDepth: 50,
            shadowBlur: -3,
            surfaceOpacity: 0.1
        )

        let result = profile.validated(for: .loud)

        #expect(result.geometry.fontScale == 1.25)
        #expect(result.geometry.outlineWidth == 0)
        #expect(result.geometry.cornerRadius == 28)
        #expect(result.geometry.shadowDepth == 10)
        #expect(result.geometry.shadowBlur == 0)
        #expect(result.geometry.surfaceOpacity == 0.55)
    }

    @Test
    func statusItemDefaultsReproduceExistingReferenceRecipes() {
        #expect(
            AppearanceProfile.default(for: .loud).statusItemGeometry
                == StatusItemGeometry(
                    fontSize: 10,
                    outlineWidth: 2,
                    cornerRadius: 0,
                    shadowHorizontalOffset: 3,
                    shadowVerticalOffset: 3,
                    shadowBlur: 0,
                    horizontalPadding: 7,
                    tagHeight: 18
                )
        )
        #expect(
            AppearanceProfile.default(for: .bold).statusItemGeometry
                == StatusItemGeometry(
                    fontSize: 10,
                    outlineWidth: 1.5,
                    cornerRadius: 5,
                    shadowHorizontalOffset: 2,
                    shadowVerticalOffset: 2,
                    shadowBlur: 0,
                    horizontalPadding: 7,
                    tagHeight: 18
                )
        )
        #expect(
            AppearanceProfile.default(for: .frost).statusItemGeometry
                == StatusItemGeometry(
                    fontSize: 10,
                    outlineWidth: 1.5,
                    cornerRadius: 7,
                    shadowHorizontalOffset: 2,
                    shadowVerticalOffset: 2,
                    shadowBlur: 0,
                    horizontalPadding: 7,
                    tagHeight: 18
                )
        )
    }

    @Test
    func statusItemStyleDefaultsInheritThemeColorsAndPreserveOpacity() {
        #expect(AppearanceProfile.currentSchemaVersion == 4)

        for theme in AppearanceThemeID.allCases {
            let style = AppearanceProfile.default(for: theme).statusItemStyle

            #expect(style.primaryTextColor == nil)
            #expect(style.weeklyTextColor == nil)
            #expect(style.shadowColor == nil)
            #expect(
                style.shadowOpacity
                    == ThemeVisualRecipe.default(for: theme)
                        .statusChip.shadow.opacity
            )
        }
    }

    @Test
    func statusItemStyleValidationMakesOverridesOpaqueAndClampsOpacity() {
        var profile = AppearanceProfile.default(for: .frost)
        profile.statusItemStyle = StatusItemStyle(
            primaryTextColor: AppearanceColor(
                red: 2,
                green: -1,
                blue: 0.4,
                alpha: 0.2
            ),
            weeklyTextColor: AppearanceColor(
                red: 0.1,
                green: 0.2,
                blue: 0.3,
                alpha: 0.5
            ),
            shadowColor: AppearanceColor(
                red: 0.8,
                green: 0.7,
                blue: 0.6,
                alpha: 0
            ),
            shadowOpacity: 4
        )

        let style = profile.validated(for: .frost).statusItemStyle

        #expect(
            style.primaryTextColor
                == AppearanceColor(red: 1, green: 0, blue: 0.4)
        )
        #expect(
            style.weeklyTextColor
                == AppearanceColor(red: 0.1, green: 0.2, blue: 0.3)
        )
        #expect(
            style.shadowColor
                == AppearanceColor(red: 0.8, green: 0.7, blue: 0.6)
        )
        #expect(style.shadowOpacity == 1)

        profile.statusItemStyle.shadowOpacity = .nan
        #expect(
            profile.validated(for: .frost).statusItemStyle.shadowOpacity
                == StatusItemStyle.default(for: .frost).shadowOpacity
        )
    }

    @Test
    func explicitStatusColorsResolveExactlyAndIndependently() {
        var profile = AppearanceProfile.default(for: .bold)
        let primary = AppearanceColor(hex: 0xB9EFE5)
        let weekly = AppearanceColor(hex: 0xF7F3E8)
        let shadow = AppearanceColor(hex: 0x8A3FFC)
        profile.statusItemStyle.primaryTextColor = primary
        profile.statusItemStyle.weeklyTextColor = weekly
        profile.statusItemStyle.shadowColor = shadow
        profile.statusItemStyle.shadowOpacity = 0.35
        profile.statusItemGeometry.shadowHorizontalOffset = -7
        profile.statusItemGeometry.shadowVerticalOffset = 5

        let resolved = AppearanceResolver.status(
            profile: profile,
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false,
            showsFailurePattern: false
        )

        #expect(resolved.primaryTextColor == primary)
        #expect(resolved.weeklyTextColor == weekly)
        #expect(resolved.shadowColor == shadow)
        #expect(resolved.shadowOpacity == 0.35)
        #expect(resolved.shadowHorizontalOffset == -7)
        #expect(resolved.shadowVerticalOffset == 5)
    }

    @Test
    func inheritedStatusColorsRetainReadableThemeBehavior() {
        var profile = AppearanceProfile.default(for: .bold)
        profile.palette.textAndOutline = profile.palette.normal

        let resolved = AppearanceResolver.status(
            profile: profile,
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false,
            showsFailurePattern: false
        )
        let expected = profile.palette.textAndOutline.readable(
            on: resolved.fillColor.composited(over: .white)
        )

        #expect(resolved.primaryTextColor == expected)
        #expect(resolved.weeklyTextColor == expected)
        #expect(resolved.outlineColor == expected)
        #expect(resolved.shadowColor == expected)
    }

    @Test
    func editorRangesRemainNarrowerThanLegacyCompatibilityBounds() {
        #expect(
            StatusItemGeometry.EditorRange.fontSize == 8...14
        )
        #expect(
            StatusItemGeometry.EditorRange.outlineWidth == 0...4
        )
        #expect(
            StatusItemGeometry.EditorRange.cornerRadius == 0...12
        )
        #expect(
            StatusItemGeometry.EditorRange.shadowOffset == -10...10
        )
        #expect(
            StatusItemGeometry.EditorRange.shadowBlur == 0...8
        )
        #expect(
            StatusItemGeometry.EditorRange.horizontalPadding == 2...14
        )
        #expect(
            StatusItemGeometry.EditorRange.tagHeight == 14...22
        )
        #expect(
            StatusItemGeometry.CompatibilityRange.cornerRadius == 0...28
        )
        #expect(
            StatusItemGeometry.CompatibilityRange.shadowOffset == -20...20
        )
        #expect(
            StatusItemGeometry.CompatibilityRange.shadowBlur == 0...20
        )
    }

    @Test
    func validationClampsStatusGeometryToCompatibilityBounds() {
        var profile = AppearanceProfile.default(for: .loud)
        profile.statusItemGeometry = StatusItemGeometry(
            fontSize: 50,
            outlineWidth: -1,
            cornerRadius: 80,
            shadowHorizontalOffset: 50,
            shadowVerticalOffset: -50,
            shadowBlur: 80,
            horizontalPadding: 100,
            tagHeight: 1
        )

        let result = profile.validated(for: .loud).statusItemGeometry

        #expect(result.fontSize == 14)
        #expect(result.outlineWidth == 0)
        #expect(result.cornerRadius == 28)
        #expect(result.shadowHorizontalOffset == 20)
        #expect(result.shadowVerticalOffset == -20)
        #expect(result.shadowBlur == 20)
        #expect(result.horizontalPadding == 14)
        #expect(result.tagHeight == 14)
    }

    @Test
    func validationUsesThemeDefaultsForNonFiniteStatusGeometry() {
        var profile = AppearanceProfile.default(for: .bold)
        profile.statusItemGeometry = StatusItemGeometry(
            fontSize: .nan,
            outlineWidth: .infinity,
            cornerRadius: -Double.infinity,
            shadowHorizontalOffset: .nan,
            shadowVerticalOffset: .infinity,
            shadowBlur: .infinity,
            horizontalPadding: -Double.infinity,
            tagHeight: .nan
        )

        let result = profile.validated(for: .bold).statusItemGeometry

        #expect(result == StatusItemGeometry.default(for: .bold))
    }

    @Test
    func panelGeometryDoesNotAffectResolvedStatusItemAppearance() {
        var profile = AppearanceProfile.default(for: .frost)
        let reference = AppearanceResolver.status(
            profile: profile,
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false,
            showsFailurePattern: false
        )

        profile.geometry = ThemeGeometry(
            fontScale: 1.25,
            outlineWidth: 4,
            cornerRadius: 28,
            shadowDepth: 10,
            shadowBlur: 20,
            surfaceOpacity: 1
        )

        #expect(
            AppearanceResolver.status(
                profile: profile,
                primaryRemainingPercent: 81,
                weeklyRemainingPercent: 49,
                isUnavailable: false,
                showsFailurePattern: false
            ) == reference
        )
    }

    @Test
    func statusItemGeometryDoesNotAffectResolvedPanelAppearance() {
        var profile = AppearanceProfile.default(for: .loud)
        let reference = AppearanceResolver.panel(
            profile: profile,
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false
        )
        profile.statusItemGeometry = StatusItemGeometry(
            fontSize: 14,
            outlineWidth: 4,
            cornerRadius: 12,
            shadowHorizontalOffset: -6,
            shadowVerticalOffset: 6,
            shadowBlur: 8,
            horizontalPadding: 14,
            tagHeight: 22
        )

        #expect(
            AppearanceResolver.panel(
                profile: profile,
                primaryRemainingPercent: 81,
                weeklyRemainingPercent: 49,
                isUnavailable: false
            ) == reference
        )
    }

    @Test
    func unreadableTextFallsBackWithoutMutatingTheProfile() {
        var profile = AppearanceProfile.default(for: .bold)
        profile.palette.textAndOutline = profile.palette.surface

        let resolved = AppearanceResolver.panel(
            profile: profile,
            primaryRemainingPercent: 80,
            weeklyRemainingPercent: 40,
            isUnavailable: false
        )

        #expect(resolved.textColor == .black)
        #expect(profile.palette.textAndOutline == profile.palette.surface)
    }

    @Test
    func statusResolutionFitsTheWholeRecipeToMenuBarHeight() {
        var profile = AppearanceProfile.default(for: .loud)
        profile.statusItemGeometry = StatusItemGeometry(
            fontSize: 14,
            outlineWidth: 4,
            cornerRadius: 12,
            shadowHorizontalOffset: 6,
            shadowVerticalOffset: 6,
            shadowBlur: 8,
            horizontalPadding: 14,
            tagHeight: 22
        )

        let resolved = AppearanceResolver.status(
            profile: profile,
            primaryRemainingPercent: 80,
            weeklyRemainingPercent: 20,
            isUnavailable: false,
            showsFailurePattern: false
        )
        let fitted = resolved.fitted(to: 24)

        #expect(resolved.outlineWidth > 2)
        #expect(resolved.shadowVerticalOffset > 3)
        #expect(resolved.cornerRadius == 12)
        let fittedShadowMetrics = StatusItemShadowMetrics(
            appearance: fitted
        )
        #expect(
            fitted.tagHeight
                + fitted.outlineWidth
                + fittedShadowMetrics.verticalBleed
                <= 23.000_001
        )
        #expect(fitted.tagHeight >= fitted.fontSize + 3.5)
        #expect(fitted.fontSize >= 8)
        #expect(fitted.shadowBlur < resolved.shadowBlur)
        #expect(resolved.fillColor == profile.palette.normal)
        #expect(
            fitted.weeklyTextColor.contrastRatio(with: fitted.fillColor)
                >= 4.5
        )
    }

    @Test
    func everyThemeResolvesItsOwnSemanticAndUnavailableColors() {
        for theme in AppearanceThemeID.allCases {
            let profile = AppearanceProfile.default(for: theme)
            let normal = AppearanceResolver.panel(
                profile: profile,
                primaryRemainingPercent: 80,
                weeklyRemainingPercent: 40,
                isUnavailable: false
            )
            let unavailable = AppearanceResolver.status(
                profile: profile,
                primaryRemainingPercent: 80,
                weeklyRemainingPercent: 80,
                isUnavailable: true,
                showsFailurePattern: true
            )

            #expect(normal.primaryStateColor == profile.palette.normal)
            #expect(normal.weeklyStateColor == profile.palette.warning)
            #expect(unavailable.fillColor == profile.palette.unavailableBase)
            #expect(
                unavailable.unavailableStripeColor
                    == profile.palette.unavailableStripe
            )
        }
    }

    @Test
    func panelResolvesPrimaryAndWeeklyStateColorsIndependently() {
        let profile = AppearanceProfile.default(for: .loud)
        let resolved = AppearanceResolver.panel(
            profile: profile,
            primaryRemainingPercent: 80,
            weeklyRemainingPercent: 20,
            isUnavailable: false
        )

        #expect(resolved.primaryStateColor == profile.palette.normal)
        #expect(resolved.weeklyStateColor == profile.palette.danger)
    }

    @Test
    func defaultPanelsResolveExactReferenceComponentColors() {
        let loud = resolvedPanel(for: .loud)
        let bold = resolvedPanel(for: .bold)
        let frost = resolvedPanel(for: .frost)

        #expect(loud.progressTrackColor == AppearanceColor(hex: 0xD8F5F1))
        #expect(bold.progressTrackColor == AppearanceColor(hex: 0xDCE9E7))
        #expect(
            frost.progressTrackColor
                == AppearanceColor(hex: 0xFFFFFF, alpha: 0.55)
        )
        #expect(loud.actionAccentColor == AppearanceColor(hex: 0xFF676B))
        #expect(bold.actionAccentColor == AppearanceColor(hex: 0xFF8A82))
        #expect(
            frost.actionAccentColor
                == AppearanceColor(hex: 0xFF676B, alpha: 0.72)
        )
        #expect(
            frost.backgroundColor
                == AppearanceColor(hex: 0xFFFFFF, alpha: 0.78)
        )
        #expect(
            frost.panelGradientEndColor
                == AppearanceColor(hex: 0xB4E8F5, alpha: 0.62)
        )
    }

    @Test
    func frostActionAlphaIsCappedOnceAndSurfaceControlCanRaiseTheCap() {
        var profile = AppearanceProfile.default(for: .frost)

        let themedDefault = AppearanceResolver.panel(
            profile: profile,
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false
        )
        #expect(themedDefault.actionAccentColor.alpha == 0.72)

        profile.geometry.surfaceOpacity = 1
        let opaque = AppearanceResolver.panel(
            profile: profile,
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false
        )
        #expect(opaque.actionAccentColor.alpha == 1)
        #expect(opaque.backgroundColor.alpha == 1)

        profile.palette.actionAccent.alpha = 0.5
        let userTranslucent = AppearanceResolver.panel(
            profile: profile,
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false
        )
        #expect(userTranslucent.actionAccentColor.alpha == 0.5)
    }

    @Test
    func customSemanticOrSurfaceColorsRecomputeTheTrackBase() {
        var profile = AppearanceProfile.default(for: .bold)
        let referenceTrack = resolvedPanel(for: .bold).progressTrackColor
        profile.palette.normal = AppearanceColor(hex: 0x55B8FF)
        profile.palette.surface = AppearanceColor(hex: 0xFFF1D2)

        let customized = AppearanceResolver.panel(
            profile: profile,
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false
        )

        #expect(customized.progressTrackColor != referenceTrack)
        #expect(
            customized.progressTrackColor
                == profile.palette.normal.mixed(
                    with: profile.palette.surface,
                    amount: ThemeVisualRecipe.default(
                        for: .bold
                    ).progress.trackTintOpacity
                )
        )
    }

    @Test
    func unavailableStatusKeepsItsThemeBaseWithoutTinting() {
        for theme in AppearanceThemeID.allCases {
            let profile = AppearanceProfile.default(for: theme)
            let status = AppearanceResolver.status(
                profile: profile,
                primaryRemainingPercent: 0,
                weeklyRemainingPercent: 0,
                isUnavailable: true,
                showsFailurePattern: false
            )
            #expect(status.fillColor == profile.palette.unavailableBase)
        }
    }

    private func resolvedPanel(
        for theme: AppearanceThemeID
    ) -> ResolvedPanelAppearance {
        AppearanceResolver.panel(
            profile: .default(for: theme),
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false
        )
    }

    private func colors(_ hexValues: UInt32...) -> [AppearanceColor] {
        hexValues.map { AppearanceColor(hex: $0) }
    }
}
