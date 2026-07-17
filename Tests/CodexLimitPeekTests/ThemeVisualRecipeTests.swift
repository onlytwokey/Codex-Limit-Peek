import Testing
@testable import CodexLimitPeek

struct ThemeVisualRecipeTests {
    @Test
    func loudMatchesApprovedComponentDefaults() {
        let recipe = ThemeVisualRecipe.default(for: .loud)

        #expect(
            recipe.panelShell
                == ThemeChromeRecipe(
                    outlineWidth: 3,
                    cornerRadius: 0,
                    shadow: .hard(depth: 8)
                )
        )
        #expect(
            recipe.quotaCard
                == ThemeChromeRecipe(
                    outlineWidth: 3,
                    cornerRadius: 0,
                    shadow: .hard(depth: 5)
                )
        )
        #expect(
            recipe.actionButton
                == ThemeChromeRecipe(
                    outlineWidth: 2,
                    cornerRadius: 0,
                    shadow: .hard(depth: 2)
                )
        )
        #expect(recipe.progress.track.outlineWidth == 2)
        #expect(recipe.progress.track.cornerRadius == 0)
        #expect(recipe.progress.height == 9)
        #expect(
            recipe.progress.trackColor
                == AppearanceColor(hex: 0xD8F5F1)
        )
        #expect(recipe.progress.fillDividerWidth == 2)
        #expect(recipe.weeklyDividerWidth == 2)
        #expect(recipe.statusChip.cornerRadius == 0)
        #expect(recipe.statusChip.shadow.depth == 3)
        #expect(recipe.typography.percentSize == 46)
        #expect(recipe.typography.countdownSize == 24)
        #expect(recipe.typography.uppercaseMetadata)
    }

    @Test
    func boldMatchesApprovedComponentDefaults() {
        let recipe = ThemeVisualRecipe.default(for: .bold)

        #expect(
            recipe.panelShell
                == ThemeChromeRecipe(
                    outlineWidth: 2,
                    cornerRadius: 10,
                    shadow: .hard(depth: 5, opacity: 0.9)
                )
        )
        #expect(recipe.quotaCard.outlineWidth == 2)
        #expect(recipe.quotaCard.cornerRadius == 7)
        #expect(recipe.actionButton.outlineWidth == 1.5)
        #expect(recipe.actionButton.cornerRadius == 4)
        #expect(recipe.actionButton.shadow == .hard(depth: 1.5))
        #expect(recipe.progress.track.cornerRadius == 4)
        #expect(
            recipe.progress.trackColor
                == AppearanceColor(hex: 0xDCE9E7)
        )
        #expect(recipe.progress.fillDividerWidth == 1.5)
        #expect(recipe.statusChip.cornerRadius == 5)
        #expect(recipe.statusChip.shadow == .hard(depth: 2))
        #expect(recipe.panelFill == .solid)
        #expect(!recipe.typography.uppercaseMetadata)
    }

    @Test
    func boldAndFrostInformationCardsDoNotHaveShadows() {
        #expect(
            ThemeVisualRecipe.default(for: .bold).quotaCard.shadow == .none
        )
        #expect(
            ThemeVisualRecipe.default(for: .frost).quotaCard.shadow == .none
        )
    }

    @Test
    func menuRowsKeepApprovedPerThemeChromeDefaults() {
        let expected: [AppearanceThemeID: ThemeChromeRecipe] = [
            .loud: ThemeChromeRecipe(
                outlineWidth: 2,
                cornerRadius: 0,
                shadow: .hard(depth: 2)
            ),
            .bold: ThemeChromeRecipe(
                outlineWidth: 1.5,
                cornerRadius: 4,
                shadow: .none
            ),
            .frost: ThemeChromeRecipe(
                outlineWidth: 1.5,
                cornerRadius: 6,
                shadow: .none
            )
        ]

        for theme in AppearanceThemeID.allCases {
            #expect(ThemeVisualRecipe.default(for: theme).menuRow == expected[theme])
        }
    }

    @Test
    func frostSeparatesMaterialFromExternalShadowBlur() {
        let recipe = ThemeVisualRecipe.default(for: .frost)

        #expect(recipe.panelFill == .materialGradient)
        #expect(
            recipe.panelGradientStartColor
                == AppearanceColor(hex: 0xFFFFFF, alpha: 0.78)
        )
        #expect(
            recipe.panelGradientEndColor
                == AppearanceColor(hex: 0xB4E8F5, alpha: 0.62)
        )
        #expect(
            recipe.panelShell.shadow
                == .hard(depth: 5, opacity: 0.78)
        )
        #expect(recipe.panelShell.shadow.blur == 0)
        #expect(recipe.panelShell.cornerRadius == 16)
        #expect(recipe.quotaCard.cornerRadius == 10)
        #expect(recipe.quotaSurfaceOpacity == 0.38)
        #expect(recipe.actionSurfaceOpacity == 0.72)
        #expect(recipe.statusFillOpacity == 0.3)
        #expect(recipe.typography.percentFamily == .rounded)
    }

    @Test
    func everyThemeKeepsReferenceLayoutMetrics() {
        for theme in AppearanceThemeID.allCases {
            let recipe = ThemeVisualRecipe.default(for: theme)

            #expect(recipe.typography.percentSize == 46)
            #expect(recipe.typography.countdownSize == 24)
            #expect(recipe.progress.height == 9)
            #expect(recipe.statusHorizontalPadding == 7)
            #expect(recipe.statusTagHeight == 18)
        }
    }

    @Test
    func userGeometryPreservesComponentHierarchy() {
        var profile = AppearanceProfile.default(for: .bold)
        profile.geometry.outlineWidth = 4
        profile.geometry.cornerRadius = 14
        profile.geometry.shadowDepth = 10

        let resolved = ThemeVisualRecipe.default(for: .bold)
            .resolved(using: profile.geometry, theme: .bold)

        #expect(resolved.panelShell.outlineWidth == 4)
        #expect(resolved.quotaCard.outlineWidth == 4)
        #expect(resolved.actionButton.outlineWidth == 3)
        #expect(resolved.panelShell.cornerRadius == 14)
        #expect(resolved.quotaCard.cornerRadius == 11)
        #expect(resolved.actionButton.cornerRadius == 8)
        #expect(resolved.panelShell.shadow.depth == 10)
        #expect(resolved.actionButton.shadow.depth == 3)
        #expect(resolved.quotaCard.shadow == .none)
        #expect(resolved.progress.fillDividerWidth == 3)
        #expect(resolved.weeklyDividerWidth == 3)
    }

    @Test
    func userBlurAffectsOnlyEnabledShadows() {
        var geometry = AppearanceProfile.default(for: .frost).geometry
        geometry.shadowBlur = 12

        let resolved = ThemeVisualRecipe.default(for: .frost)
            .resolved(using: geometry, theme: .frost)

        #expect(
            resolved.panelShell.shadow
                == .soft(depth: 5, blur: 12, opacity: 0.78)
        )
        #expect(resolved.actionButton.shadow.blur == 12)
        #expect(resolved.quotaCard.shadow == .none)
        #expect(resolved.progress.track.shadow == .none)
    }

    @Test
    func userSurfaceOpacityScalesInformationAndActionSurfaces() {
        var geometry = AppearanceProfile.default(for: .frost).geometry
        geometry.surfaceOpacity = 1

        let resolved = ThemeVisualRecipe.default(for: .frost)
            .resolved(using: geometry, theme: .frost)

        #expect(
            abs(resolved.quotaSurfaceOpacity - (0.38 / 0.55)) < 0.000_001
        )
        #expect(resolved.actionSurfaceOpacity == 1)
    }

    @Test
    func menuBarFittingScalesChromeAsAUnit() {
        var appearance = AppearanceResolver.status(
            profile: .default(for: .loud),
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false,
            showsFailurePattern: false
        )
        appearance.tagHeight = 30

        let fitted = appearance.fitted(to: 24)

        #expect(fitted.tagHeight < appearance.tagHeight)
        #expect(fitted.outlineWidth < appearance.outlineWidth)
        #expect(fitted.shadowDepth < appearance.shadowDepth)
        #expect(fitted.horizontalPadding < appearance.horizontalPadding)
        #expect(
            fitted.tagHeight
                + fitted.outlineWidth
                + fitted.shadowDepth
                <= 23.000_001
        )
    }

    @Test
    func menuBarFittingIncludesSoftShadowBlur() {
        var appearance = AppearanceResolver.status(
            profile: .default(for: .frost),
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false,
            showsFailurePattern: false
        )
        appearance.shadowDepth = 0
        appearance.shadowBlur = 20

        let fitted = appearance.fitted(to: 24)

        #expect(fitted.shadowBlur < appearance.shadowBlur)
        #expect(
            fitted.tagHeight
                + fitted.outlineWidth
                + fitted.shadowDepth
                + fitted.shadowBlur * 2
                <= 23.000_001
        )
    }

    @Test
    func extremeMenuBarEffectsPreserveLegibleTextInsideTheTag() {
        for theme in AppearanceThemeID.allCases {
            var profile = AppearanceProfile.default(for: theme)
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
                primaryRemainingPercent: 81,
                weeklyRemainingPercent: 49,
                isUnavailable: false,
                showsFailurePattern: false
            )
            let fitted = resolved.fitted(to: 24)

            #expect(fitted.fontSize >= 8)
            #expect(fitted.tagHeight >= fitted.fontSize + 3.5)
            #expect(
                fitted.tagHeight
                    + fitted.outlineWidth
                    + fitted.shadowDepth
                    + fitted.shadowBlur * 2
                    <= 23.000_001
            )
        }
    }
}
