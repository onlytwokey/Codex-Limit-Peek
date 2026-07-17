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
                    shadowDepth: 3,
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
                    shadowDepth: 2,
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
                    shadowDepth: 2,
                    shadowBlur: 0,
                    horizontalPadding: 7,
                    tagHeight: 18
                )
        )
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
            StatusItemGeometry.EditorRange.shadowDepth == 0...6
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
            shadowDepth: 50,
            shadowBlur: 80,
            horizontalPadding: 100,
            tagHeight: 1
        )

        let result = profile.validated(for: .loud).statusItemGeometry

        #expect(result.fontSize == 14)
        #expect(result.outlineWidth == 0)
        #expect(result.cornerRadius == 28)
        #expect(result.shadowDepth == 6)
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
            shadowDepth: .nan,
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
            shadowDepth: 6,
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
            shadowDepth: 6,
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
        #expect(resolved.shadowDepth > 3)
        #expect(resolved.cornerRadius == 12)
        #expect(
            fitted.tagHeight
                + fitted.outlineWidth
                + fitted.shadowDepth
                + fitted.shadowBlur * 2
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
}
