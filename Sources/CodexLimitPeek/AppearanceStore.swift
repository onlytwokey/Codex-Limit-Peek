import Combine
import CoreFoundation
import Foundation

enum AppearanceSaveFeedbackState: Equatable, Sendable {
    case saved
    case saving
}

enum AppearancePersistenceKey {
    static let selectedTheme = "appearance.selectedTheme"
    static let editorFontScale = "appearance.editorFontScale.v1"

    static func profile(_ theme: AppearanceThemeID) -> String {
        "appearance.profile.\(theme.rawValue).v3"
    }

    static func legacyProfileV2(_ theme: AppearanceThemeID) -> String {
        "appearance.profile.\(theme.rawValue).v2"
    }

    static func legacyProfileV1(_ theme: AppearanceThemeID) -> String {
        "appearance.profile.\(theme.rawValue).v1"
    }
}

struct LegacyThemePaletteV1: Codable, Equatable, Sendable {
    var background: AppearanceColor
    var surface: AppearanceColor
    var textAndOutline: AppearanceColor
    var normal: AppearanceColor
    var warning: AppearanceColor
    var danger: AppearanceColor
    var unavailableBase: AppearanceColor
    var unavailableStripe: AppearanceColor
}

struct LegacyAppearanceProfileV2: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var themeID: AppearanceThemeID
    var palette: ThemePalette
    var geometry: ThemeGeometry
    var capabilities: ThemeCapabilities

    static func `default`(
        for theme: AppearanceThemeID
    ) -> LegacyAppearanceProfileV2 {
        let profile = AppearanceProfile.default(for: theme)
        return LegacyAppearanceProfileV2(
            schemaVersion: 2,
            themeID: theme,
            palette: profile.palette,
            geometry: profile.geometry,
            capabilities: profile.capabilities
        )
    }

    func migrated(
        for theme: AppearanceThemeID
    ) -> AppearanceProfile {
        let correctedGeometry = geometry.clamped()
        return AppearanceProfile(
            schemaVersion: AppearanceProfile.currentSchemaVersion,
            themeID: theme,
            palette: palette,
            geometry: correctedGeometry,
            statusItemGeometry:
                .migratedFromVersionTwo(
                    theme: theme,
                    panelGeometry: correctedGeometry
                ),
            capabilities: AppearanceProfile.default(
                for: theme
            ).capabilities
        )
        .validated(for: theme)
    }
}

extension StatusItemGeometry {
    static func migratedFromVersionTwo(
        theme: AppearanceThemeID,
        panelGeometry: ThemeGeometry
    ) -> StatusItemGeometry {
        let panelGeometry = panelGeometry.clamped()
        let visuals = ThemeVisualRecipe.default(for: theme)
            .resolved(using: panelGeometry, theme: theme)
        return StatusItemGeometry(
            fontSize: min(
                max(
                    visuals.typography.statusSize
                        * panelGeometry.fontScale,
                    9
                ),
                12.5
            ),
            outlineWidth: visuals.statusChip.outlineWidth,
            cornerRadius: visuals.statusChip.cornerRadius,
            shadowDepth: visuals.statusChip.shadow.depth,
            shadowBlur: visuals.statusChip.shadow.blur,
            horizontalPadding: visuals.statusHorizontalPadding,
            tagHeight: visuals.statusTagHeight
        )
        .validated(defaultingTo: .default(for: theme))
    }
}

struct LegacyAppearanceProfileV1: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var themeID: AppearanceThemeID
    var palette: LegacyThemePaletteV1
    var geometry: ThemeGeometry
    var capabilities: ThemeCapabilities

    func migratedToVersionTwo(
        for theme: AppearanceThemeID
    ) -> LegacyAppearanceProfileV2 {
        let newDefault = AppearanceProfile.default(for: theme)
        let migratedGeometry = geometry == Self.default(for: theme).geometry
            ? newDefault.geometry
            : geometry

        return LegacyAppearanceProfileV2(
            schemaVersion: 2,
            themeID: theme,
            palette: ThemePalette(
                background: palette.background,
                surface: palette.surface,
                textAndOutline: palette.textAndOutline,
                actionAccent: newDefault.palette.actionAccent,
                normal: palette.normal,
                warning: palette.warning,
                danger: palette.danger,
                unavailableBase: palette.unavailableBase,
                unavailableStripe: palette.unavailableStripe
            ),
            geometry: migratedGeometry,
            capabilities: newDefault.capabilities
        )
    }
}

extension LegacyAppearanceProfileV1 {
    static func `default`(
        for theme: AppearanceThemeID
    ) -> LegacyAppearanceProfileV1 {
        switch theme {
        case .loud:
            LegacyAppearanceProfileV1(
                schemaVersion: 1,
                themeID: .loud,
                palette: LegacyThemePaletteV1(
                    background: AppearanceColor(hex: 0xFFE36E),
                    surface: AppearanceColor(hex: 0xFFFFFF),
                    textAndOutline: AppearanceColor(hex: 0x171717),
                    normal: AppearanceColor(hex: 0x4FC9C1),
                    warning: AppearanceColor(hex: 0xFF9F1C),
                    danger: AppearanceColor(hex: 0xFF676B),
                    unavailableBase: AppearanceColor(hex: 0xFFFFFF),
                    unavailableStripe: AppearanceColor(hex: 0xFF676B)
                ),
                geometry: ThemeGeometry(
                    fontScale: 1,
                    outlineWidth: 3,
                    cornerRadius: 8,
                    shadowDepth: 8,
                    shadowBlur: 0,
                    surfaceOpacity: 1
                ),
                capabilities: ThemeCapabilities(
                    usesMaterial: false,
                    uppercaseMetadata: true,
                    roundedPrimaryTypography: false
                )
            )
        case .bold:
            LegacyAppearanceProfileV1(
                schemaVersion: 1,
                themeID: .bold,
                palette: LegacyThemePaletteV1(
                    background: AppearanceColor(hex: 0xF7F3E8),
                    surface: AppearanceColor(hex: 0xFFFFFF),
                    textAndOutline: AppearanceColor(hex: 0x191919),
                    normal: AppearanceColor(hex: 0x45C7BB),
                    warning: AppearanceColor(hex: 0xE8BE3F),
                    danger: AppearanceColor(hex: 0xE76B68),
                    unavailableBase: AppearanceColor(hex: 0xE9E6DE),
                    unavailableStripe: AppearanceColor(hex: 0xC55B59)
                ),
                geometry: ThemeGeometry(
                    fontScale: 1,
                    outlineWidth: 2,
                    cornerRadius: 10,
                    shadowDepth: 5,
                    shadowBlur: 0,
                    surfaceOpacity: 1
                ),
                capabilities: ThemeCapabilities(
                    usesMaterial: false,
                    uppercaseMetadata: false,
                    roundedPrimaryTypography: false
                )
            )
        case .frost:
            LegacyAppearanceProfileV1(
                schemaVersion: 1,
                themeID: .frost,
                palette: LegacyThemePaletteV1(
                    background: AppearanceColor(
                        hex: 0xDDF3F8,
                        alpha: 0.72
                    ),
                    surface: AppearanceColor(hex: 0xFFFFFF),
                    textAndOutline: AppearanceColor(hex: 0x172027),
                    normal: AppearanceColor(hex: 0x44C7B7),
                    warning: AppearanceColor(hex: 0xE3BB55),
                    danger: AppearanceColor(hex: 0xE46D78),
                    unavailableBase: AppearanceColor(hex: 0xEFF4F5),
                    unavailableStripe: AppearanceColor(hex: 0xCE6670)
                ),
                geometry: ThemeGeometry(
                    fontScale: 1,
                    outlineWidth: 2,
                    cornerRadius: 16,
                    shadowDepth: 5,
                    shadowBlur: 18,
                    surfaceOpacity: 0.55
                ),
                capabilities: ThemeCapabilities(
                    usesMaterial: true,
                    uppercaseMetadata: false,
                    roundedPrimaryTypography: true
                )
            )
        }
    }
}

@MainActor
final class AppearanceStore: ObservableObject {
    @Published private(set) var selectedTheme: AppearanceThemeID
    @Published private(set) var profiles: [AppearanceThemeID: AppearanceProfile]
    @Published private(set) var editorFontScale: Double
    @Published private(set) var revision = 0
    @Published private(set) var isSaved = true
    @Published private(set) var saveFeedbackState:
        AppearanceSaveFeedbackState = .saved

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let saveDelayNanoseconds: UInt64
    private var pendingSaveTask: Task<Void, Never>?
    private var activeSliderEditCount = 0
    private var saveGeneration = 0

    init(
        defaults: UserDefaults = .standard,
        saveDelayNanoseconds: UInt64 = 150_000_000
    ) {
        self.defaults = defaults
        self.saveDelayNanoseconds = saveDelayNanoseconds
        let decoder = JSONDecoder()

        selectedTheme = defaults.string(
            forKey: AppearancePersistenceKey.selectedTheme
        )
        .flatMap(AppearanceThemeID.init(rawValue:)) ?? .loud

        if
            let number = defaults.object(
                forKey: AppearancePersistenceKey.editorFontScale
            ) as? NSNumber,
            CFGetTypeID(number) != CFBooleanGetTypeID()
        {
            editorFontScale = AppearanceEditorTypography.validatedScale(
                number.doubleValue
            )
        } else {
            editorFontScale = AppearanceEditorTypography.defaultScale
        }

        var loaded: [AppearanceThemeID: AppearanceProfile] = [:]
        for theme in AppearanceThemeID.allCases {
            if
                let data = defaults.data(
                    forKey: AppearancePersistenceKey.profile(theme)
                ),
                let decoded = try? decoder.decode(
                    AppearanceProfile.self,
                    from: data
                ),
                decoded.schemaVersion == AppearanceProfile.currentSchemaVersion
            {
                loaded[theme] = decoded.validated(for: theme)
                continue
            }

            if
                let data = defaults.data(
                    forKey: AppearancePersistenceKey.legacyProfileV2(theme)
                ),
                let decoded = try? decoder.decode(
                    LegacyAppearanceProfileV2.self,
                    from: data
                ),
                decoded.schemaVersion == 2
            {
                loaded[theme] = decoded.migrated(for: theme)
                continue
            }

            if
                let data = defaults.data(
                    forKey: AppearancePersistenceKey.legacyProfileV1(theme)
                ),
                let decoded = try? decoder.decode(
                    LegacyAppearanceProfileV1.self,
                    from: data
                ),
                decoded.schemaVersion == 1
            {
                loaded[theme] = decoded
                    .migratedToVersionTwo(for: theme)
                    .migrated(for: theme)
                continue
            }

            loaded[theme] = .default(for: theme)
        }
        profiles = loaded
    }

    var currentProfile: AppearanceProfile {
        profile(for: selectedTheme)
    }

    var canResetCurrentTheme: Bool {
        currentProfile != .default(for: selectedTheme)
    }

    func profile(for theme: AppearanceThemeID) -> AppearanceProfile {
        profiles[theme] ?? .default(for: theme)
    }

    func select(_ theme: AppearanceThemeID) {
        guard selectedTheme != theme else { return }
        selectedTheme = theme
        markChanged()
    }

    func updateCurrent(
        _ mutation: (inout AppearanceProfile) -> Void
    ) {
        var profile = currentProfile
        mutation(&profile)
        let validated = profile.validated(for: selectedTheme)
        guard validated != currentProfile else { return }
        profiles[selectedTheme] = validated
        markChanged()
    }

    func setEditorFontScale(_ value: Double) {
        let validated = AppearanceEditorTypography.validatedScale(value)
        guard validated != editorFontScale else { return }
        editorFontScale = validated
        markChanged(affectsThemeRendering: false)
    }

    func color(for token: AppearanceColorToken) -> AppearanceColor {
        currentProfile.palette[token]
    }

    func setColor(
        _ color: AppearanceColor,
        for token: AppearanceColorToken
    ) {
        setColor(
            color,
            for: token,
            in: selectedTheme
        )
    }

    func setColor(
        _ color: AppearanceColor,
        for token: AppearanceColorToken,
        in theme: AppearanceThemeID
    ) {
        var profile = profile(for: theme)
        profile.palette[token] = color
        let validated = profile.validated(for: theme)
        guard validated != self.profile(for: theme) else {
            return
        }
        profiles[theme] = validated
        markChanged(
            affectsThemeRendering: theme == selectedTheme
        )
    }

    func resetCurrentTheme() {
        guard canResetCurrentTheme else { return }
        profiles[selectedTheme] = .default(for: selectedTheme)
        markChanged()
    }

    func sliderEditingChanged(_ isEditing: Bool) {
        if isEditing {
            if activeSliderEditCount == 0 {
                cancelPendingSave()
            }
            activeSliderEditCount += 1
            return
        }

        guard activeSliderEditCount > 0 else { return }
        activeSliderEditCount -= 1
        guard activeSliderEditCount == 0, !isSaved else { return }
        saveFeedbackState = .saving
        scheduleDebouncedSave()
    }

    func flushPendingSave() {
        cancelPendingSave()
        activeSliderEditCount = 0
        persist()
    }

    private func markChanged(
        affectsThemeRendering: Bool = true
    ) {
        if affectsThemeRendering {
            revision &+= 1
        }
        isSaved = false
        cancelPendingSave()
        guard activeSliderEditCount == 0 else { return }
        saveFeedbackState = .saving
        scheduleDebouncedSave()
    }

    private func cancelPendingSave() {
        saveGeneration &+= 1
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
    }

    private func scheduleDebouncedSave() {
        cancelPendingSave()
        let delay = saveDelayNanoseconds
        let generation = saveGeneration
        pendingSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard
                !Task.isCancelled,
                let self,
                self.saveGeneration == generation,
                self.activeSliderEditCount == 0
            else {
                return
            }
            self.pendingSaveTask = nil
            self.persist()
        }
    }

    private func persist() {
        defaults.set(
            selectedTheme.rawValue,
            forKey: AppearancePersistenceKey.selectedTheme
        )
        var didSaveAllProfiles = true
        for theme in AppearanceThemeID.allCases {
            let profile = profile(for: theme).validated(for: theme)
            guard let data = try? encoder.encode(profile) else {
                didSaveAllProfiles = false
                continue
            }
            defaults.set(data, forKey: AppearancePersistenceKey.profile(theme))
        }
        defaults.set(
            editorFontScale,
            forKey: AppearancePersistenceKey.editorFontScale
        )
        isSaved = didSaveAllProfiles
        if didSaveAllProfiles {
            saveFeedbackState = .saved
        }
    }
}
