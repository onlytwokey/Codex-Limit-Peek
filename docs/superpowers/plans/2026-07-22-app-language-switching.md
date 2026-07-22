# In-App Language Switching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent Follow System / Simplified Chinese / English preference that updates every running application surface, notification, formatter, and voice immediately without changing quota or appearance state.

**Architecture:** Add native SwiftPM localization resources, a dedicated main-actor AppLanguageStore, and an AppLocalization value injected into SwiftUI environment roots and AppKit update paths. Replace localized quota-source strings with a stable QuotaSource enum, then make all user-facing quota and refresh text explicit presentation output that accepts the current localization.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Combine, AVFoundation, UserNotifications, Swift Package Manager, Swift Testing

---

## Scope and sequencing

This plan implements the production application language feature and its tests. Execute it before the companion plan:

`docs/superpowers/plans/2026-07-22-bilingual-documentation-previews.md`

Do not begin implementation while unrelated worktree changes are unresolved. Preserve all existing changes, and stage only files named by the current task at each commit.

## File structure

Create:

- `Sources/CodexLimitPeek/Localization/AppLanguage.swift`: stable saved and resolved language enums.
- `Sources/CodexLimitPeek/Localization/AppLanguageStore.swift`: persistence, system-language observation, and revision publishing.
- `Sources/CodexLimitPeek/Localization/AppLocalization.swift`: typed keys, resource-bundle selection, and formatted-string lookup.
- `Sources/CodexLimitPeek/Localization/AppLocalizationEnvironment.swift`: SwiftUI environment value and observable root wrapper.
- `Sources/CodexLimitPeek/Resources/en.lproj/Localizable.strings`: English values.
- `Sources/CodexLimitPeek/Resources/zh-Hans.lproj/Localizable.strings`: Simplified Chinese values.
- `Sources/CodexLimitPeek/MenuBar/LanguageSettingsView.swift`: the compact language child page.
- `Tests/CodexLimitPeekTests/Localization/AppLanguageStoreTests.swift`: preference, resolution, persistence, and revision tests.
- `Tests/CodexLimitPeekTests/Localization/AppLocalizationTests.swift`: resource parity and formatting tests.
- `Tests/CodexLimitPeekTests/Quota/QuotaLocalizationTests.swift`: bilingual quota presentation tests.

Modify:

- `Package.swift`: declare default localization and executable resources.
- `Sources/CodexLimitPeek/App/AppDelegate.swift`: own the shared language store, inject localized roots, and refresh AppKit text.
- `Sources/CodexLimitPeek/Quota/QuotaDomain.swift`: stable QuotaSource and localized status presentation.
- `Sources/CodexLimitPeek/Quota/AppServerQuotaProvider.swift`: emit stable app-server source.
- `Sources/CodexLimitPeek/Quota/QuotaProviders.swift`: emit stable log and session sources.
- `Sources/CodexLimitPeek/Quota/QuotaStore.swift`: cache migration, localized snapshot presentation, notifications, and speech.
- `Sources/CodexLimitPeek/Quota/RefreshReliability.swift`: localize failure-category descriptions.
- `Sources/CodexLimitPeek/MenuBar/MoreOverlayPresenter.swift`: carry the shared language store and add the language page.
- `Sources/CodexLimitPeek/MenuBar/MoreOverlayViews.swift`: inject localization and route language navigation.
- `Sources/CodexLimitPeek/MenuBar/StatusPanelViews.swift`: consume localized quota presentation and add the Language action.
- `Sources/CodexLimitPeek/Appearance/AppearanceTheme.swift`: localize theme descriptions.
- `Sources/CodexLimitPeek/Appearance/Editor/AppearanceEditorComponents.swift`: localize color controls and accessibility text.
- `Sources/CodexLimitPeek/Appearance/Editor/AppearanceEditorSupport.swift`: localize status-item scroll targets.
- `Sources/CodexLimitPeek/Appearance/Editor/AppearanceEditorView.swift`: localize the main appearance editor.
- `Sources/CodexLimitPeek/Appearance/Editor/StateColorsEditorView.swift`: localize state colors.
- `Sources/CodexLimitPeek/Appearance/Editor/StatusItemEditorView.swift`: localize status-item controls.
- `Sources/CodexLimitPeek/Appearance/ThemeChromeViews.swift`: localize production preview labels and accessibility text.
- `Sources/CodexLimitPeek/DeveloperTools/DeveloperPreviewCoordinator.swift`: inject the shared language environment into debug preview UI.
- `Sources/CodexLimitPeek/DeveloperTools/DeveloperPreviewScenario.swift`: use stable quota sources and localized scenario names.
- `Sources/CodexLimitPeek/DeveloperTools/DeveloperPreviewStatusItemView.swift`: localize debug tooltip text.
- `Sources/CodexLimitPeek/DeveloperTools/DeveloperPreviewView.swift`: localize debug-only controls.
- Existing quota, application, appearance, and developer-tool tests whose constructors or expected strings change.

### Task 1: Add native localization resources and the language model

**Files:**
- Modify: `Package.swift`
- Create: `Sources/CodexLimitPeek/Localization/AppLanguage.swift`
- Create: `Sources/CodexLimitPeek/Localization/AppLocalization.swift`
- Create: `Sources/CodexLimitPeek/Resources/en.lproj/Localizable.strings`
- Create: `Sources/CodexLimitPeek/Resources/zh-Hans.lproj/Localizable.strings`
- Create: `Tests/CodexLimitPeekTests/Localization/AppLocalizationTests.swift`

- [ ] **Step 1: Write failing resource and resolution tests**

Create tests that require deterministic resolution and prove both resource bundles can resolve the same typed keys:

~~~swift
import Foundation
import Testing
@testable import CodexLimitPeek

struct AppLocalizationTests {
    @Test
    func resolvesChineseSystemLanguagesToSimplifiedChinese() {
        #expect(
            ResolvedAppLanguage.resolve(
                preference: .system,
                preferredLanguages: ["zh-Hant-TW", "en-US"]
            ) == .simplifiedChinese
        )
    }

    @Test
    func resolvesUnsupportedSystemLanguagesToEnglish() {
        #expect(
            ResolvedAppLanguage.resolve(
                preference: .system,
                preferredLanguages: ["ja-JP"]
            ) == .english
        )
    }

    @Test
    func explicitPreferenceOverridesSystemLanguage() {
        #expect(
            ResolvedAppLanguage.resolve(
                preference: .english,
                preferredLanguages: ["zh-Hans-CN"]
            ) == .english
        )
    }

    @Test
    func bothBundlesContainCoreKeys() {
        let chinese = AppLocalization(language: .simplifiedChinese)
        let english = AppLocalization(language: .english)

        #expect(chinese.text(.languageTitle) == "语言")
        #expect(english.text(.languageTitle) == "Language")
        #expect(chinese.text(.languageFollowSystem) == "跟随系统")
        #expect(english.text(.languageFollowSystem) == "Follow System")
    }
}
~~~

- [ ] **Step 2: Run the focused test and verify the missing types fail**

Run:

~~~bash
scripts/test.sh --filter AppLocalizationTests
~~~

Expected: compilation fails because AppLanguagePreference, ResolvedAppLanguage, AppLocalization, and AppTextKey do not exist.

- [ ] **Step 3: Declare SwiftPM localization resources**

Update the package declaration:

~~~swift
let package = Package(
    name: "CodexLimitPeek",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexLimitPeek", targets: ["CodexLimitPeek"])
    ],
    targets: [
        .executableTarget(
            name: "CodexLimitPeek",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define(
                    "DEVELOPER_TOOLS",
                    .when(configuration: .debug)
                )
            ]
        ),
        .testTarget(
            name: "CodexLimitPeekTests",
            dependencies: ["CodexLimitPeek"],
            swiftSettings: [
                .define(
                    "DEVELOPER_TOOLS",
                    .when(configuration: .debug)
                )
            ]
        )
    ]
)
~~~

- [ ] **Step 4: Implement the saved and resolved language enums**

Create AppLanguage.swift with these stable raw values and resolution rules:

~~~swift
import Foundation

enum AppLanguagePreference: String, CaseIterable, Sendable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"
}

enum ResolvedAppLanguage: String, CaseIterable, Sendable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var speechLanguageIdentifier: String {
        switch self {
        case .simplifiedChinese:
            "zh-CN"
        case .english:
            "en-US"
        }
    }

    static func resolve(
        preference: AppLanguagePreference,
        preferredLanguages: [String]
    ) -> Self {
        switch preference {
        case .simplifiedChinese:
            return .simplifiedChinese
        case .english:
            return .english
        case .system:
            let first = preferredLanguages.first ?? "en"
            return first
                .lowercased()
                .hasPrefix("zh")
                ? .simplifiedChinese
                : .english
        }
    }
}
~~~

- [ ] **Step 5: Implement typed lookup and formatting**

Create AppLocalization.swift. Keep keys as stable English identifiers and select the explicit lproj bundle so a manual preference does not depend on process-global localization:

~~~swift
import Foundation

enum AppTextKey: String, CaseIterable, Sendable {
    case languageTitle = "language.title"
    case languageFollowSystem = "language.followSystem"
    case languageSimplifiedChinese = "language.simplifiedChinese"
    case languageEnglish = "language.english"
}

struct AppLocalization {
    let language: ResolvedAppLanguage
    private let resourceBundle: Bundle

    init(language: ResolvedAppLanguage) {
        self.language = language
        let path = Bundle.module.path(
            forResource: language.rawValue,
            ofType: "lproj"
        )
        self.resourceBundle = path
            .flatMap(Bundle.init(path:))
            ?? Bundle.module
    }

    var locale: Locale {
        language.locale
    }

    func text(_ key: AppTextKey) -> String {
        resourceBundle.localizedString(
            forKey: key.rawValue,
            value: nil,
            table: nil
        )
    }

    func format(
        _ key: AppTextKey,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: text(key),
            locale: locale,
            arguments: arguments
        )
    }
}
~~~

- [ ] **Step 6: Add matching initial resource values**

Add these exact entries to English:

~~~text
"language.title" = "Language";
"language.followSystem" = "Follow System";
"language.simplifiedChinese" = "Simplified Chinese";
"language.english" = "English";
~~~

Add these exact entries to Simplified Chinese:

~~~text
"language.title" = "语言";
"language.followSystem" = "跟随系统";
"language.simplifiedChinese" = "简体中文";
"language.english" = "English";
~~~

- [ ] **Step 7: Run the focused tests**

Run:

~~~bash
scripts/test.sh --filter AppLocalizationTests
~~~

Expected: all AppLocalizationTests pass.

- [ ] **Step 8: Commit the foundation**

~~~bash
git add Package.swift Sources/CodexLimitPeek/Localization Sources/CodexLimitPeek/Resources Tests/CodexLimitPeekTests/Localization/AppLocalizationTests.swift
git commit -m "feat: add application localization foundation"
~~~

### Task 2: Add the persistent observable language store

**Files:**
- Create: `Sources/CodexLimitPeek/Localization/AppLanguageStore.swift`
- Create: `Sources/CodexLimitPeek/Localization/AppLocalizationEnvironment.swift`
- Create: `Tests/CodexLimitPeekTests/Localization/AppLanguageStoreTests.swift`

- [ ] **Step 1: Write failing persistence and system-change tests**

~~~swift
import Foundation
import Testing
@testable import CodexLimitPeek

@MainActor
struct AppLanguageStoreTests {
    @Test
    func missingPreferenceFollowsSystemAndPersistsSelection() {
        let suite = "AppLanguageStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = AppLanguageStore(
            defaults: defaults,
            preferredLanguages: { ["zh-Hans-CN"] },
            notificationCenter: NotificationCenter()
        )

        #expect(store.preference == .system)
        #expect(store.resolvedLanguage == .simplifiedChinese)

        store.select(.english)

        #expect(defaults.string(forKey: "app.language") == "en")
        #expect(store.resolvedLanguage == .english)
    }

    @Test
    func invalidPreferenceFallsBackToSystem() {
        let suite = "AppLanguageStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("broken", forKey: "app.language")

        let store = AppLanguageStore(
            defaults: defaults,
            preferredLanguages: { ["en-GB"] },
            notificationCenter: NotificationCenter()
        )

        #expect(store.preference == .system)
        #expect(store.resolvedLanguage == .english)
    }

    @Test
    func localeNotificationOnlyRevisesEffectiveSystemLanguage() {
        let center = NotificationCenter()
        var languages = ["en-US"]
        let store = AppLanguageStore(
            defaults: UserDefaults(suiteName: UUID().uuidString)!,
            preferredLanguages: { languages },
            notificationCenter: center
        )
        let initialRevision = store.revision

        languages = ["zh-Hans-CN"]
        center.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)

        #expect(store.resolvedLanguage == .simplifiedChinese)
        #expect(store.revision == initialRevision + 1)
    }
}
~~~

- [ ] **Step 2: Run the focused tests and verify failure**

Run:

~~~bash
scripts/test.sh --filter AppLanguageStoreTests
~~~

Expected: compilation fails because AppLanguageStore does not exist.

- [ ] **Step 3: Implement AppLanguageStore**

Use one published revision for all AppKit and SwiftUI refresh paths:

~~~swift
import Combine
import Foundation

@MainActor
final class AppLanguageStore: ObservableObject {
    @Published private(set) var preference: AppLanguagePreference
    @Published private(set) var resolvedLanguage: ResolvedAppLanguage
    @Published private(set) var revision = 0

    private let defaults: UserDefaults
    private let preferredLanguages: () -> [String]
    private let notificationCenter: NotificationCenter
    private var localeObserver: NSObjectProtocol?

    init(
        defaults: UserDefaults = .standard,
        preferredLanguages: @escaping () -> [String] = {
            Locale.preferredLanguages
        },
        notificationCenter: NotificationCenter = .default
    ) {
        self.defaults = defaults
        self.preferredLanguages = preferredLanguages
        self.notificationCenter = notificationCenter
        let saved = defaults.string(forKey: Self.preferenceKey)
            .flatMap(AppLanguagePreference.init(rawValue:))
            ?? .system
        self.preference = saved
        self.resolvedLanguage = .resolve(
            preference: saved,
            preferredLanguages: preferredLanguages()
        )
        localeObserver = notificationCenter.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.resolveCurrentPreference()
            }
        }
    }

    deinit {
        if let localeObserver {
            notificationCenter.removeObserver(localeObserver)
        }
    }

    var localization: AppLocalization {
        AppLocalization(language: resolvedLanguage)
    }

    var locale: Locale {
        resolvedLanguage.locale
    }

    func select(_ preference: AppLanguagePreference) {
        guard self.preference != preference else { return }
        self.preference = preference
        defaults.set(preference.rawValue, forKey: Self.preferenceKey)
        resolveCurrentPreference()
    }

    private func resolveCurrentPreference() {
        let next = ResolvedAppLanguage.resolve(
            preference: preference,
            preferredLanguages: preferredLanguages()
        )
        guard next != resolvedLanguage else { return }
        resolvedLanguage = next
        revision &+= 1
    }

    private static let preferenceKey = "app.language"
}
~~~

Selecting a different saved preference that resolves to the same effective language updates the checkmark through preference publishing but does not increment revision.

- [ ] **Step 4: Add the SwiftUI environment root**

~~~swift
import SwiftUI

private struct AppLocalizationEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppLocalization(language: .english)
}

extension EnvironmentValues {
    var appLocalization: AppLocalization {
        get { self[AppLocalizationEnvironmentKey.self] }
        set { self[AppLocalizationEnvironmentKey.self] = newValue }
    }
}

struct AppLanguageRoot<Content: View>: View {
    @ObservedObject var store: AppLanguageStore
    private let content: Content

    init(
        store: AppLanguageStore,
        @ViewBuilder content: () -> Content
    ) {
        self.store = store
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.locale, store.locale)
            .environment(\.appLocalization, store.localization)
    }
}
~~~

The observed store invalidates the root when either preference or effective language changes. Do not add an id modifier: forcing identity replacement would discard local scroll or editor state and violate the in-place switching requirement.

- [ ] **Step 5: Run store and localization tests**

Run:

~~~bash
scripts/test.sh --filter AppLanguage
~~~

Expected: all AppLanguageStoreTests and AppLocalizationTests pass.

- [ ] **Step 6: Commit the store**

~~~bash
git add Sources/CodexLimitPeek/Localization/AppLanguageStore.swift Sources/CodexLimitPeek/Localization/AppLocalizationEnvironment.swift Tests/CodexLimitPeekTests/Localization/AppLanguageStoreTests.swift
git commit -m "feat: persist and publish app language"
~~~

### Task 3: Replace localized quota-source identity with a stable enum

**Files:**
- Modify: `Sources/CodexLimitPeek/Quota/QuotaDomain.swift`
- Modify: `Sources/CodexLimitPeek/Quota/AppServerQuotaProvider.swift`
- Modify: `Sources/CodexLimitPeek/Quota/QuotaProviders.swift`
- Modify: `Sources/CodexLimitPeek/Quota/QuotaStore.swift`
- Modify: `Tests/CodexLimitPeekTests/Quota/AppServerQuotaProviderTests.swift`
- Modify: `Tests/CodexLimitPeekTests/Quota/CodexSessionQuotaProviderTests.swift`
- Modify: `Tests/CodexLimitPeekTests/Quota/QuotaStoreTests.swift`

- [ ] **Step 1: Change tests to require QuotaSource**

Add migration coverage and replace sourceName assertions with enum assertions:

~~~swift
@Test
func cachedSnapshotMigratesLegacyChineseSource() {
    let suite = "QuotaSourceMigration.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(61, forKey: "quota.remainingPercent")
    defaults.set(74, forKey: "quota.weeklyRemainingPercent")
    defaults.set(Date().addingTimeInterval(3_600).timeIntervalSince1970, forKey: "quota.resetDate")
    defaults.set(Date().addingTimeInterval(86_400).timeIntervalSince1970, forKey: "quota.weeklyResetDate")
    defaults.set(Date().timeIntervalSince1970, forKey: "quota.lastUpdated")
    defaults.set("Codex 会话", forKey: "quota.sourceName")

    let snapshot = QuotaSnapshot.cached(defaults: defaults)

    #expect(snapshot?.source == .cache)
    #expect(defaults.string(forKey: "quota.source") == "localSession")
}

@Test
func localSessionProviderUsesStableSource() {
    let snapshot = makeLocalSessionSnapshot()
    #expect(snapshot.source == .localSession)
}
~~~

Change RateLimitRecord test construction from sourceName: "Test" to source: .localLog. Change app-server expectations to .appServer.

- [ ] **Step 2: Run quota tests and verify compilation failure**

~~~bash
scripts/test.sh --filter QuotaStoreTests
~~~

Expected: compilation fails because QuotaSource and QuotaSnapshot.source do not exist.

- [ ] **Step 3: Add QuotaSource and change snapshot construction**

Add this stable model to QuotaDomain.swift:

~~~swift
enum QuotaSource: String, Sendable, Codable {
    case appServer
    case localLog
    case localSession
    case cache
    case unavailable

    static func migrateLegacy(_ rawValue: String?) -> Self {
        switch rawValue {
        case "Codex 实时额度":
            .appServer
        case "Codex 日志":
            .localLog
        case "Codex 会话":
            .localSession
        case "本机缓存":
            .cache
        case "额度未获取":
            .unavailable
        default:
            rawValue.flatMap(Self.init(rawValue:)) ?? .cache
        }
    }
}
~~~

Change RateLimitRecord.snapshot to:

~~~swift
func snapshot(
    recordedAt: Date,
    source: QuotaSource
) -> QuotaSnapshot {
    let primaryUsed = Int(primary.usedPercent.rounded())
    let weeklyUsed = Int(secondary.usedPercent.rounded())
    return QuotaSnapshot(
        remainingPercent: max(0, min(100, 100 - primaryUsed)),
        weeklyRemainingPercent: max(0, min(100, 100 - weeklyUsed)),
        resetDate: Date(timeIntervalSince1970: primary.resetsAt),
        weeklyResetDate: Date(timeIntervalSince1970: secondary.resetsAt),
        lastUpdated: recordedAt,
        source: source,
        isUnavailable: false,
        displayMode: displayMode
    )
}
~~~

Replace QuotaSnapshot.sourceName with source: QuotaSource.

- [ ] **Step 4: Update providers and cache keys**

AppServerQuotaProvider emits .appServer, log fallback emits .localLog, and session fallback emits .localSession.

Cache stable identifiers under a new key while reading the legacy key:

~~~swift
let savedSource = defaults.string(forKey: CacheKey.source)
let legacySource = defaults.string(forKey: CacheKey.sourceName)
let migratedSource = savedSource
    .flatMap(QuotaSource.init(rawValue:))
    ?? QuotaSource.migrateLegacy(legacySource)
defaults.set(migratedSource.rawValue, forKey: CacheKey.source)

return QuotaSnapshot(
    remainingPercent: defaults.integer(forKey: CacheKey.remainingPercent),
    weeklyRemainingPercent: defaults.integer(forKey: CacheKey.weeklyRemainingPercent),
    resetDate: Date(timeIntervalSince1970: defaults.double(forKey: CacheKey.resetDate)),
    weeklyResetDate: Date(timeIntervalSince1970: defaults.double(forKey: CacheKey.weeklyResetDate)),
    lastUpdated: Date(timeIntervalSince1970: defaults.double(forKey: CacheKey.lastUpdated)),
    source: .cache,
    isUnavailable: false,
    displayMode: defaults.string(forKey: CacheKey.displayMode)
        .flatMap(QuotaDisplayMode.init(rawValue:)) ?? .dualWindow
)
~~~

When caching a live or local snapshot, set source.rawValue for quota.source and remove quota.sourceName only after the new value has been written. When reading through cached(), preserve the current user-facing meaning by returning source .cache while normalizing the original legacy value into the new stable key. QuotaSnapshot.unavailable uses .unavailable.

- [ ] **Step 5: Make fallback logic enum-based**

Replace localized-string checks in QuotaStatusFormatter with:

~~~swift
let isLocalFallback =
    snapshot.source == .localLog
    || snapshot.source == .localSession
~~~

No business condition may compare localized display strings.

- [ ] **Step 6: Run all quota tests**

~~~bash
scripts/test.sh --filter Quota
~~~

Expected: all quota-provider and QuotaStore tests pass with stable source assertions.

- [ ] **Step 7: Commit the domain migration**

~~~bash
git add Sources/CodexLimitPeek/Quota Tests/CodexLimitPeekTests/Quota
git commit -m "refactor: stabilize quota source identity"
~~~

### Task 4: Localize quota presentation and refresh failure descriptions

**Files:**
- Modify: `Sources/CodexLimitPeek/Localization/AppLocalization.swift`
- Modify: both Localizable.strings files
- Modify: `Sources/CodexLimitPeek/Quota/QuotaDomain.swift`
- Modify: `Sources/CodexLimitPeek/Quota/QuotaStore.swift`
- Modify: `Sources/CodexLimitPeek/Quota/RefreshReliability.swift`
- Create: `Tests/CodexLimitPeekTests/Quota/QuotaLocalizationTests.swift`
- Modify: `Tests/CodexLimitPeekTests/Quota/RefreshReliabilityTests.swift`

- [ ] **Step 1: Write bilingual presentation tests**

~~~swift
import Foundation
import Testing
@testable import CodexLimitPeek

struct QuotaLocalizationTests {
    private let date = Date(timeIntervalSince1970: 1_784_334_240)

    @Test
    func dualWindowPresentationUsesSelectedLanguage() {
        let snapshot = QuotaSnapshot(
            remainingPercent: 61,
            weeklyRemainingPercent: 74,
            resetDate: date.addingTimeInterval(3_600),
            weeklyResetDate: date.addingTimeInterval(6 * 86_400),
            lastUpdated: date,
            source: .appServer,
            isUnavailable: false,
            displayMode: .dualWindow
        )

        let zh = snapshot.presentation(
            localization: AppLocalization(language: .simplifiedChinese),
            referenceDate: date,
            timeZone: TimeZone(secondsFromGMT: 8 * 3_600)!
        )
        let en = snapshot.presentation(
            localization: AppLocalization(language: .english),
            referenceDate: date,
            timeZone: TimeZone(secondsFromGMT: 8 * 3_600)!
        )

        #expect(zh.primaryQuotaLabel == "5 小时剩余")
        #expect(en.primaryQuotaLabel == "5-hour remaining")
        #expect(zh.voiceBroadcastText.contains("五小时额度剩余 61%"))
        #expect(en.voiceBroadcastText.contains("5-hour quota has 61% remaining"))
    }

    @Test
    func failureDescriptionsAreLocalized() {
        let zh = AppLocalization(language: .simplifiedChinese)
        let en = AppLocalization(language: .english)

        #expect(RefreshFailureCategory.cliMissing.displayText(using: zh) == "未找到 Codex CLI")
        #expect(RefreshFailureCategory.cliMissing.displayText(using: en) == "Codex CLI not found")
    }
}
~~~

- [ ] **Step 2: Run focused tests and verify missing presentation failure**

~~~bash
scripts/test.sh --filter QuotaLocalizationTests
~~~

Expected: compilation fails because presentation(localization:referenceDate:timeZone:) and localized failure descriptions do not exist.

- [ ] **Step 3: Define typed keys and resource pairs**

Add typed keys and matching values for these groups:

~~~text
quota.source.appServer: Codex live quota / Codex 实时额度
quota.source.localLog: Codex log / Codex 日志
quota.source.localSession: Codex session / Codex 会话
quota.source.cache: Local cache / 本机缓存
quota.source.unavailable: Quota unavailable / 额度未获取
quota.unsynced: Not synced / 未同步
quota.primary.dual: 5-hour remaining / 5 小时剩余
quota.primary.weekly: Weekly remaining / 周额度剩余
quota.name.fiveHour: 5-hour quota / 五小时额度
quota.name.weekly: Weekly quota / 周额度
quota.updatedAt: Updated at %@ / 更新于 %@
quota.resetDate: Resets %@ / %@恢复
quota.resetUnavailable: Reset time unavailable / 暂无重置信息
quota.relative.daysHours: in %d days %d hours / %d天%d小时后
quota.relative.hoursMinutes: in %d hours %d minutes / %d小时%d分后
quota.relative.minutes: in %d minutes / %d分后
quota.voice: Codex %@ has %d%% remaining. It resets %@. / Codex %@剩余 %d%%，距离额度恢复 %@。
status.live: %@ · Updated at %@ / %@ · 更新于 %@
status.retry.first: Live read failed · Retry in 15 seconds / 实时读取失败 · 15 秒后重试
status.retry.second: Confirming failure · Retry in 45 seconds / 正在确认失败 · 45 秒后重试
status.sync.unavailable: Syncing · Quota unavailable / 正在同步 · 额度未获取
status.sync.cached: Syncing · Showing last data / 正在同步 · 使用上次数据
status.failed.unavailable: Refresh failed · Quota unavailable / 刷新失败 · 额度未获取
status.localFallback: Local fallback · Updated at %@ / 本地回退 · 更新于 %@
status.failed.cached: Refresh failed · Last success %@ / 刷新失败 · 上次成功 %@
failure.cliMissing: Codex CLI not found / 未找到 Codex CLI
failure.launchFailed: app-server failed to start / app-server 启动失败
failure.timedOut: app-server timed out / app-server 响应超时
failure.exited: app-server exited unexpectedly / app-server 意外退出
failure.protocolError: app-server protocol error / app-server 协议异常
failure.invalidQuota: Invalid quota fields / 额度字段无效
failure.loggedOut: Codex login expired / Codex 登录状态失效
failure.unknown: Unknown local error / 未知本地错误
~~~

Use exact resource keys matching the AppTextKey raw values. Percent characters in .strings format values must be escaped as %% where required by String(format:).

- [ ] **Step 4: Introduce QuotaPresentation**

Move localized snapshot text out of stored state:

~~~swift
struct QuotaPresentation: Sendable {
    let menuBarTitle: String
    let menuBarTrailingTitle: String?
    let primaryQuotaLabel: String
    let primaryResetDateText: String
    let primaryResetDetailText: String
    let weeklyResetDateText: String
    let resetText: String
    let lastUpdatedText: String
    let voiceBroadcastText: String
    let notificationQuotaName: String
}
~~~

Implement:

~~~swift
func presentation(
    localization: AppLocalization,
    referenceDate: Date = Date(),
    timeZone: TimeZone = .current
) -> QuotaPresentation
~~~

Build all language-dependent values using localization.format, Date.FormatStyle.locale(localization.locale), and an explicit time zone. Keep percentText, weeklyPercentText, displayRemainingPercent, showsSecondaryQuota, and compact d/h/m reset text language-neutral on QuotaSnapshot.

- [ ] **Step 5: Localize status headers and failure categories**

Change QuotaStatusFormatter.header to require AppLocalization:

~~~swift
static func header(
    snapshot: QuotaSnapshot,
    health: RefreshHealth,
    localization: AppLocalization,
    confirmationAttempt: Int = 0,
    timeZone: TimeZone = .current
) -> String
~~~

Change RefreshFailureCategory from displayText to:

~~~swift
func displayText(using localization: AppLocalization) -> String
~~~

Switch enum cases to typed keys. Do not store the rendered description.

- [ ] **Step 6: Run quota localization and reliability tests**

~~~bash
scripts/test.sh --filter QuotaLocalizationTests
scripts/test.sh --filter RefreshReliabilityTests
~~~

Expected: both suites pass in Chinese and English.

- [ ] **Step 7: Commit localized quota presentation**

~~~bash
git add Sources/CodexLimitPeek/Localization Sources/CodexLimitPeek/Resources Sources/CodexLimitPeek/Quota Tests/CodexLimitPeekTests/Quota
git commit -m "feat: localize quota presentation"
~~~

### Task 5: Localize notification and speech side effects

**Files:**
- Modify: `Sources/CodexLimitPeek/Localization/AppLocalization.swift`
- Modify: both Localizable.strings files
- Modify: `Sources/CodexLimitPeek/Quota/QuotaStore.swift`
- Modify: `Tests/CodexLimitPeekTests/Quota/QuotaStoreTests.swift`

- [ ] **Step 1: Add injectable side-effect tests**

Expose internal seams for a notification request recorder and speech driver, then test English delivery and cancellation:

~~~swift
@Test @MainActor
func languageChangeStopsSpeechAndFutureSpeechUsesNewVoice() {
    let languageStore = makeLanguageStore(preferredLanguages: ["zh-Hans"])
    let speech = RecordingSpeechDriver()
    let store = makeQuotaStore(
        languageStore: languageStore,
        speechDriver: speech
    )

    store.speakForTesting(makeSnapshot())
    #expect(speech.lastLanguage == "zh-CN")

    languageStore.select(.english)
    #expect(speech.stopCount == 1)

    store.speakForTesting(makeSnapshot())
    #expect(speech.lastLanguage == "en-US")
    #expect(speech.lastText.contains("remaining"))
}

@Test @MainActor
func notificationTextUsesCurrentLanguageAtDeliveryTime() {
    let languageStore = makeLanguageStore(preferredLanguages: ["en-US"])
    let notifications = RecordingNotificationDriver()
    let store = makeQuotaStore(
        languageStore: languageStore,
        notificationDriver: notifications
    )

    store.evaluateNotificationsForTesting(
        snapshot: makeSnapshot(remainingPercent: 10)
    )

    #expect(notifications.lastTitle == "Codex quota nearly exhausted")
    #expect(notifications.lastBody.contains("10%"))
}
~~~

- [ ] **Step 2: Run tests and verify the missing injection seams fail**

~~~bash
scripts/test.sh --filter QuotaStoreTests
~~~

Expected: compilation fails for languageStore, speechDriver, and notificationDriver constructor arguments.

- [ ] **Step 3: Add side-effect protocols and production adapters**

Define main-actor internal protocols near QuotaStore:

~~~swift
@MainActor
protocol SpeechDriving: AnyObject {
    func speak(_ text: String, languageIdentifier: String)
    func stop()
}

@MainActor
protocol NotificationDriving: AnyObject {
    func requestAuthorization()
    func deliver(identifier: String, title: String, body: String)
}
~~~

Wrap AVSpeechSynthesizer and UNUserNotificationCenter in production implementations. The speech adapter first requests AVSpeechSynthesisVoice(language:), then falls back to the first installed voice whose language has the same two-letter prefix.

- [ ] **Step 4: Inject the shared language store**

QuotaStore stores the passed AppLanguageStore, subscribes to its revision, and calls speechDriver.stop() when the effective language changes. It reads languageStore.localization only at the moment text is generated.

Add resource pairs:

~~~text
notification.danger.title: Codex quota nearly exhausted / Codex 额度接近耗尽
notification.danger.body: Current %@ has %d%% remaining. Consider slowing high-consumption tasks. / 当前 %@ 剩余 %d%%，建议放慢高消耗任务。
notification.warning.title: Codex quota is low / Codex 额度偏低
notification.warning.body: Current %@ has %d%% remaining. It resets %@. / 当前 %@ 剩余 %d%%，距离额度恢复 %@。
~~~

The notification quota name comes from QuotaPresentation. Speech uses QuotaPresentation.voiceBroadcastText.

- [ ] **Step 5: Run QuotaStore tests**

~~~bash
scripts/test.sh --filter QuotaStoreTests
~~~

Expected: all notification, voice, timer, and refresh tests pass without real user-facing side effects.

- [ ] **Step 6: Commit side-effect localization**

~~~bash
git add Sources/CodexLimitPeek/Localization Sources/CodexLimitPeek/Resources Sources/CodexLimitPeek/Quota/QuotaStore.swift Tests/CodexLimitPeekTests/Quota/QuotaStoreTests.swift
git commit -m "feat: localize quota notifications and speech"
~~~

### Task 6: Propagate language through AppDelegate and hosting roots

**Files:**
- Modify: `Sources/CodexLimitPeek/App/AppDelegate.swift`
- Modify: `Sources/CodexLimitPeek/MenuBar/MoreOverlayPresenter.swift`
- Modify: `Sources/CodexLimitPeek/MenuBar/MoreOverlayViews.swift`
- Modify: `Sources/CodexLimitPeek/MenuBar/StatusPanelViews.swift`
- Modify: `Tests/CodexLimitPeekTests/Application/AppDelegateLifecycleTests.swift`
- Modify: `Tests/CodexLimitPeekTests/Application/MoreOverlayTests.swift`

- [ ] **Step 1: Write an AppDelegate language-refresh test**

Add test accessors for the saved preference, effective language, and current status tooltip:

~~~swift
@Test @MainActor
func switchingLanguageRefreshesLoadedSurfacesWithoutClosingThem() {
    let app = AppDelegate(arguments: [])
    app.applicationDidFinishLaunching(
        Notification(name: NSApplication.didFinishLaunchingNotification)
    )
    _ = app.ensurePanelWindow()
    app.setMoreOverlayPageForTesting(.actions)

    app.selectLanguageForTesting(.english)

    #expect(app.resolvedLanguageForTesting == .english)
    #expect(app.isPanelWindowLoaded)
    #expect(app.moreOverlayPageForTesting == .actions)
    #expect(app.statusTooltipForTesting?.contains("remaining") == true)
}
~~~

- [ ] **Step 2: Run application tests and verify missing language accessors fail**

~~~bash
scripts/test.sh --filter AppDelegateLifecycleTests
~~~

Expected: compilation fails because the AppDelegate language seam does not exist.

- [ ] **Step 3: Own one shared language store**

Create AppDelegate properties in this dependency order:

~~~swift
private lazy var languageStore = AppLanguageStore()
private lazy var quotaStore = QuotaStore(languageStore: languageStore)
private lazy var appearanceStore = AppearanceStore()
~~~

Pass languageStore into MoreOverlayPresenter. Change the status publisher to include languageStore.$revision:

~~~swift
snapshotCancellable = Publishers.CombineLatest4(
    quotaStore.$snapshot,
    quotaStore.$refreshHealth,
    appearanceStore.$revision,
    languageStore.$revision
).sink { [weak self] snapshot, health, _, _ in
    self?.updateStatusItem(with: snapshot, health: health)
    self?.scheduleVisiblePanelReposition()
}
~~~

- [ ] **Step 4: Wrap every production hosting root**

Wrap StatusPanelView, StatusPanelShadowView, MoreOverlayInteractionView, and MoreOverlayDecorationView in AppLanguageRoot. Pass the same store through MoreOverlayPresenter initializers and root-view replacement paths.

Do not create a second AppLanguageStore inside a panel or presenter.

- [ ] **Step 5: Localize AppKit status text**

In updateStatusItem:

~~~swift
let localization = languageStore.localization
let presentation = snapshot.presentation(
    localization: localization
)
let healthText = QuotaStatusFormatter.header(
    snapshot: snapshot,
    health: health,
    localization: localization,
    confirmationAttempt: quotaStore.confirmationAttempt
)
~~~

Add typed resource keys for:

~~~text
tooltip.lastAvailable: Currently showing the most recent available quota / 当前显示最近一次可用额度
tooltip.lastReliable: Continuing to show the last reliable quota / 当前继续显示最后一次可靠额度
tooltip.weekly: Weekly quota %d%% remaining, %@ / 周额度剩余 %d%%，%@
tooltip.dual: 5h quota %d%% remaining, resets %@\nWeekly quota %d%% remaining, %@ / 5h 额度剩余 %d%%，距离额度恢复 %@\n周额度剩余 %d%%，%@
tooltip.reason: Reason: %@ / 原因：%@
~~~

Use presentation values and localization.format; remove direct Chinese strings.

- [ ] **Step 6: Run AppDelegate and More overlay tests**

~~~bash
scripts/test.sh --filter AppDelegateLifecycleTests
scripts/test.sh --filter MoreOverlayTests
~~~

Expected: all tests pass, and loaded windows remain loaded after language revision.

- [ ] **Step 7: Commit app-shell propagation**

~~~bash
git add Sources/CodexLimitPeek/App/AppDelegate.swift Sources/CodexLimitPeek/MenuBar/MoreOverlayPresenter.swift Sources/CodexLimitPeek/MenuBar/MoreOverlayViews.swift Sources/CodexLimitPeek/MenuBar/StatusPanelViews.swift Tests/CodexLimitPeekTests/Application
git commit -m "feat: refresh app surfaces on language changes"
~~~

### Task 7: Add the language child page to the More overlay

**Files:**
- Create: `Sources/CodexLimitPeek/MenuBar/LanguageSettingsView.swift`
- Modify: `Sources/CodexLimitPeek/Localization/AppLocalization.swift`
- Modify: both Localizable.strings files
- Modify: `Sources/CodexLimitPeek/MenuBar/MoreOverlayPresenter.swift`
- Modify: `Sources/CodexLimitPeek/MenuBar/MoreOverlayViews.swift`
- Modify: `Sources/CodexLimitPeek/MenuBar/StatusPanelViews.swift`
- Modify: `Tests/CodexLimitPeekTests/Application/MoreOverlayTests.swift`

- [ ] **Step 1: Write failing page and dismissal-policy tests**

~~~swift
@Test
func languagePageUsesCompactActionsWidth() {
    #expect(MoreOverlayPage.language.width == MoreOverlayMetrics.actionsWidth)
    #expect(MoreOverlayPage.language.fixedSize == nil)
}

@Test @MainActor
func languageSelectionKeepsOverlayOnLanguagePage() {
    let presenter = makePresenter()
    presenter.navigate(to: .language)

    presenter.languageStoreForTesting.select(.english)

    #expect(presenter.page == .language)
    #expect(presenter.isPresented)
}
~~~

- [ ] **Step 2: Run More overlay tests and verify failure**

~~~bash
scripts/test.sh --filter MoreOverlayTests
~~~

Expected: compilation fails because MoreOverlayPage.language and the shared language store are missing from page routing.

- [ ] **Step 3: Add language routing**

Add .language to MoreOverlayPage. It uses actionsWidth and dynamic fitting height. In MoreOverlayInteractionView:

~~~swift
case .language:
    LanguageSettingsView(
        languageStore: languageStore,
        appearance: appearance,
        onBack: { onNavigate(.actions) }
    )
    .frame(width: MoreOverlayMetrics.actionsWidth)
~~~

- [ ] **Step 4: Implement LanguageSettingsView**

Use existing ActionMenuRow chrome:

~~~swift
import SwiftUI

struct LanguageSettingsView: View {
    @ObservedObject var languageStore: AppLanguageStore
    let appearance: ResolvedPanelAppearance
    let onBack: () -> Void
    @Environment(\.appLocalization) private var localization

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onBack) {
                ActionMenuRow(
                    systemImage: "chevron.left",
                    title: localization.text(.languageTitle),
                    trailing: nil,
                    appearance: appearance
                )
            }
            .buttonStyle(.plain)

            Divider()

            ForEach(AppLanguagePreference.allCases, id: \.self) { preference in
                Button {
                    languageStore.select(preference)
                } label: {
                    ActionMenuRow(
                        systemImage: languageStore.preference == preference
                            ? "checkmark.circle.fill"
                            : "circle",
                        title: preference.displayName(using: localization),
                        trailing: nil,
                        appearance: appearance
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
    }
}
~~~

Implement displayName(using:) by mapping the three preferences to the existing language keys.

- [ ] **Step 5: Add the Language action**

ActionsPopover receives languageStore and onShowLanguage. Insert after Appearance and before debug preview or Quit:

~~~swift
Button {
    withAnimation(.easeOut(duration: 0.12)) {
        onShowLanguage()
    }
} label: {
    ActionMenuRow(
        systemImage: "globe",
        title: localization.text(.languageTitle),
        trailing: languageStore.preference.displayName(
            using: localization
        ),
        appearance: appearance
    )
}
.buttonStyle(.plain)
~~~

Add a Divider before and after the row according to the existing actions rhythm. The action must not call close or terminate.

- [ ] **Step 6: Run overlay tests**

~~~bash
scripts/test.sh --filter MoreOverlayTests
~~~

Expected: routing, fitting size, click shielding, and page-preservation tests pass.

- [ ] **Step 7: Commit the language UI**

~~~bash
git add Sources/CodexLimitPeek/MenuBar Sources/CodexLimitPeek/Localization Sources/CodexLimitPeek/Resources Tests/CodexLimitPeekTests/Application/MoreOverlayTests.swift
git commit -m "feat: add language settings page"
~~~

### Task 8: Localize main panel and action controls

**Files:**
- Modify: `Sources/CodexLimitPeek/Localization/AppLocalization.swift`
- Modify: both Localizable.strings files
- Modify: `Sources/CodexLimitPeek/MenuBar/StatusPanelViews.swift`
- Modify: `Sources/CodexLimitPeek/Appearance/ThemeChromeViews.swift`
- Modify: `Tests/CodexLimitPeekTests/Application/MoreOverlayTests.swift`
- Modify: relevant appearance preview tests

- [ ] **Step 1: Add focused production-control localization tests**

~~~swift
@Test
func coreControlKeysHaveBothLanguages() {
    let zh = AppLocalization(language: .simplifiedChinese)
    let en = AppLocalization(language: .english)

    #expect(zh.text(.actionRefresh) == "刷新")
    #expect(en.text(.actionRefresh) == "Refresh")
    #expect(zh.text(.actionMore) == "更多")
    #expect(en.text(.actionMore) == "More")
    #expect(zh.text(.actionAppearance) == "外观")
    #expect(en.text(.actionAppearance) == "Appearance")
}
~~~

- [ ] **Step 2: Add exact action and preview resource pairs**

Add:

~~~text
action.refresh: Refresh / 刷新
action.more: More / 更多
action.voice.enable: Enable Voice / 开启播报
action.voice.disable: Disable Voice / 关闭播报
action.voice.interval: Voice Interval / 播报间隔
action.minutes: %d min / %d 分钟
action.appearance: Appearance / 外观
action.developerPreview: Developer Preview / 开发者预览
action.quit: Quit App / 退出应用
preview.weeklyQuota: Weekly quota / 周额度
accessibility.quotaRemaining: Quota remaining / 额度剩余
accessibility.panelPreview: Current theme panel preview / 当前额度面板主题预览
accessibility.statusPreview: Menu bar status preview / 菜单栏状态预览
accessibility.statusPreviewValue: 81%%, 1 hour 34 minutes, weekly quota 49%% / 81%%，1小时34分钟，周额度49%%
~~~

- [ ] **Step 3: Replace direct strings with environment localization**

Each affected SwiftUI view declares:

~~~swift
@Environment(\.appLocalization) private var localization
~~~

Use Text(verbatim: localization.text(...)) for already-resolved strings, localized values for help and accessibility modifiers, and localization.format(.actionMinutes, minutes) for intervals.

ThemePanelDisplayData.reference becomes:

~~~swift
static func reference(
    for theme: AppearanceThemeID,
    localization: AppLocalization
) -> Self
~~~

All production callers pass the current environment localization. Do not keep a Chinese default argument.

- [ ] **Step 4: Run application and appearance tests**

~~~bash
scripts/test.sh --filter MoreOverlayTests
scripts/test.sh --filter ThemeVisualRecipeTests
~~~

Expected: tests pass and no production main-panel or actions literal remains in the touched views.

- [ ] **Step 5: Commit panel localization**

~~~bash
git add Sources/CodexLimitPeek/MenuBar/StatusPanelViews.swift Sources/CodexLimitPeek/Appearance/ThemeChromeViews.swift Sources/CodexLimitPeek/Localization Sources/CodexLimitPeek/Resources Tests/CodexLimitPeekTests/Application Tests/CodexLimitPeekTests/Appearance
git commit -m "feat: localize panel controls and previews"
~~~

### Task 9: Localize the complete appearance editor

**Files:**
- Modify: `Sources/CodexLimitPeek/Appearance/AppearanceTheme.swift`
- Modify: `Sources/CodexLimitPeek/Appearance/Editor/AppearanceEditorComponents.swift`
- Modify: `Sources/CodexLimitPeek/Appearance/Editor/AppearanceEditorSupport.swift`
- Modify: `Sources/CodexLimitPeek/Appearance/Editor/AppearanceEditorView.swift`
- Modify: `Sources/CodexLimitPeek/Appearance/Editor/StateColorsEditorView.swift`
- Modify: `Sources/CodexLimitPeek/Appearance/Editor/StatusItemEditorView.swift`
- Modify: `Sources/CodexLimitPeek/Localization/AppLocalization.swift`
- Modify: both Localizable.strings files
- Modify: appearance editor tests

- [ ] **Step 1: Add a complete appearance-key parity test**

Add all appearance keys to AppTextKey, then require neither locale to return a raw key:

~~~swift
@Test
func everyDeclaredKeyResolvesInBothLanguages() {
    for language in ResolvedAppLanguage.allCases {
        let localization = AppLocalization(language: language)
        for key in AppTextKey.allCases {
            #expect(
                localization.text(key) != key.rawValue,
                "Missing \(key.rawValue) for \(language.rawValue)"
            )
        }
    }
}
~~~

Run it before adding resource values and verify it fails on the new keys.

- [ ] **Step 2: Add appearance resource groups**

Add exact keys for these Chinese/English pairs:

~~~text
appearance.title: Appearance / 外观
appearance.backToMore: Back to More / 返回更多
appearance.saved: Saved / 已保存
appearance.saving: Saving / 正在保存
appearance.theme: Theme / 主题
appearance.palette.title: Base Palette / 基础色板
appearance.palette.subtitle: Panel colors; status item text and shadow can be overridden / 面板配色；状态栏可单独覆盖文字与阴影
appearance.color.background: Background / 背景
appearance.color.surface: Surface / 表面
appearance.color.textOutline: Text & Outline / 文字与描边
appearance.color.controls: Controls / 操作控件
appearance.lowContrast: Text contrast is low; the rendered text will automatically use black or white. / 当前文字对比度不足，实际显示会自动改用黑色或白色。
appearance.panelGeometry.title: Panel Typography & Geometry / 面板字形与几何
appearance.panelGeometry.subtitle: Affects the expanded panel only / 仅影响展开面板
appearance.panelFont: Panel Font Size / 面板字体大小
appearance.editorFont: Settings Font Size / 设置页字体大小
appearance.editorFont.note: Global · Settings pages only / 全局 · 仅影响设置页面
appearance.outline: Outline / 描边
appearance.cornerRadius: Corner Radius / 圆角
appearance.panelMaterial.title: Panel Shadow & Material / 面板阴影与材质
appearance.shadowDepth: Shadow Depth / 阴影深度
appearance.shadowBlur: Shadow Blur / 阴影模糊
appearance.surfaceOpacity: Surface Opacity / 表面不透明度
appearance.statusItem.title: Menu Bar Status Item / 状态栏显示层
appearance.statusItem.summary: Colors · Font · Outline · Shadow · Size › / 颜色 · 字体 · 描边 · 阴影 · 尺寸 ›
appearance.stateColors.title: Advanced State Colors / 高级状态颜色
appearance.stateColors.summary: Normal · Warning · Danger · Unavailable › / 正常 · 警告 · 危险 · 不可用 ›
appearance.reset.enabled: Restore Theme Defaults / 恢复当前主题默认值
appearance.reset.disabled: Theme Already Uses Defaults / 当前主题已是默认设置
appearance.reset.note: Only %@ is reset; the other themes and settings font size are preserved. / 只重置 %@；另外两套主题和设置页字号会保留。
appearance.reset.confirmTitle: Restore %@? / 确认恢复 %@？
appearance.reset.confirmBody: This theme's colors, panel, and status item settings will return to defaults. / 当前主题的颜色、面板和状态栏设置将恢复默认。
appearance.reset.confirm: Restore / 确认恢复
appearance.reset.cancel: Cancel / 取消
appearance.livePreview: Live Preview / 实时预览
stateColors.title: State Colors / 状态颜色
stateColors.back: Back to Appearance / 返回外观
stateColors.themeAccessibility: Select the theme whose state colors you want to edit / 选择要编辑状态颜色的主题
stateColors.note: Each theme is saved separately; quota thresholds remain unchanged. / 每套主题分别保存；正常、警告、危险的额度阈值保持不变。
stateColors.section: Quota & Failure States / 额度与失败状态
stateColors.subtitle: Status item text contrast is adjusted automatically / 状态栏会自动保证文字对比度
state.normal: Normal / 正常
state.warning: Warning / 警告
state.danger: Danger / 危险
state.unavailableBackground: Unavailable Background / 不可用底色
state.unavailableStripe: Unavailable Stripe / 不可用条纹
statusItem.text.title: Text / 文字
statusItem.text.subtitle: Primary and weekly quota can be set separately / 主额度与周额度可分别设置
statusItem.primary: Primary Quota / 主额度
statusItem.weekly: Weekly Quota / 周额度
statusItem.shadow.title: Shadow / 阴影
statusItem.shadow.subtitle: Negative horizontal values move left; positive vertical values move down / 水平负值向左，垂直正值向下
statusItem.shadowColor: Shadow Color / 阴影颜色
statusItem.shadowOpacity: Shadow Opacity / 阴影透明度
statusItem.geometry.title: Geometry / 几何
statusItem.geometry.subtitle: Font, outline, and label size / 字号、轮廓与标签尺寸
statusItem.layoutNote: Final size adapts to the system menu bar height; horizontal shadow is not compressed by height. / 最终尺寸会根据系统菜单栏高度自动适配；水平阴影不会因高度被压缩。
~~~

Also add keys for all eight scroll-target labels, color-picker help, follow-theme state, color accessibility sentences, low-contrast warning format, navigation accessibility labels and hints, and LOUD/BOLD/FROST descriptions found by:

~~~bash
rg -n '"[^"\n]*[一-龥][^"\n]*"' Sources/CodexLimitPeek/Appearance
~~~

The command must return only comments or fixed demonstration data after the production replacements; every remaining user-facing match must be converted before this task passes.

- [ ] **Step 3: Refactor title-sensitive color logic**

Remove title.hasSuffix("颜色"). Replace it with explicit semantics:

~~~swift
enum AppearanceColorLabelStyle {
    case complete
    case appendColorNoun
}
~~~

Color rows receive a localized title and label style. Build the custom-color accessibility label with one of two format keys instead of inspecting Chinese suffixes.

- [ ] **Step 4: Replace direct strings file by file**

Every view reads AppLocalization from the environment. AppearanceTheme exposes:

~~~swift
func description(using localization: AppLocalization) -> String
~~~

AppearanceEditorScrollTarget exposes:

~~~swift
func accessibilityLabel(
    using localization: AppLocalization
) -> String
~~~

Dynamic reset, contrast, and color accessibility sentences use localization.format with explicit arguments. Do not concatenate translated sentence fragments.

- [ ] **Step 5: Run resource parity and appearance tests**

~~~bash
scripts/test.sh --filter AppLocalizationTests
scripts/test.sh --filter Appearance
~~~

Expected: every key resolves in both languages and all appearance suites pass.

- [ ] **Step 6: Scan for remaining production Chinese literals**

~~~bash
rg -n '"[^"\n]*[一-龥][^"\n]*"' Sources/CodexLimitPeek/Appearance Sources/CodexLimitPeek/MenuBar Sources/CodexLimitPeek/App Sources/CodexLimitPeek/Quota
~~~

Expected: no user-facing production literal remains. Any fixed documentation fixture is handled by the companion documentation plan, not silently ignored.

- [ ] **Step 7: Commit appearance localization**

~~~bash
git add Sources/CodexLimitPeek/Appearance Sources/CodexLimitPeek/Localization Sources/CodexLimitPeek/Resources Tests/CodexLimitPeekTests/Appearance Tests/CodexLimitPeekTests/Localization
git commit -m "feat: localize appearance editor"
~~~

### Task 10: Localize debug developer preview without affecting release behavior

**Files:**
- Modify: `Sources/CodexLimitPeek/App/AppDelegate.swift`
- Modify: `Sources/CodexLimitPeek/DeveloperTools/DeveloperPreviewCoordinator.swift`
- Modify: `Sources/CodexLimitPeek/DeveloperTools/DeveloperPreviewScenario.swift`
- Modify: `Sources/CodexLimitPeek/DeveloperTools/DeveloperPreviewStatusItemView.swift`
- Modify: `Sources/CodexLimitPeek/DeveloperTools/DeveloperPreviewView.swift`
- Modify: localization resources and keys
- Modify: `Tests/CodexLimitPeekTests/DeveloperTools/DeveloperPreviewCoordinatorTests.swift`
- Modify: `Tests/CodexLimitPeekTests/DeveloperTools/DeveloperPreviewEnvironmentTests.swift`

- [ ] **Step 1: Add a debug preview language test**

Under DEVELOPER_TOOLS, construct a coordinator with a shared AppLanguageStore, switch English, and assert the hosted preview remains loaded and exposes English scenario labels.

~~~swift
#if DEVELOPER_TOOLS
@Test @MainActor
func developerPreviewUsesSharedAppLanguage() {
    let languageStore = makeLanguageStore(preferredLanguages: ["zh-Hans"])
    let coordinator = DeveloperPreviewCoordinator(
        languageStore: languageStore,
        onClose: {}
    )
    coordinator.show()

    languageStore.select(.english)

    #expect(coordinator.isWindowLoaded)
    #expect(
        DeveloperPreviewScenario.warning
            .displayName(using: languageStore.localization)
            == "Warning"
    )
    coordinator.tearDown()
}
#endif
~~~

- [ ] **Step 2: Inject AppLanguageRoot into the debug window**

AppDelegate passes its shared languageStore into DeveloperPreviewCoordinator. The coordinator wraps DeveloperPreviewView in AppLanguageRoot. No debug-only store is created.

- [ ] **Step 3: Localize debug controls and use stable sources**

Add pairs for Developer Preview, Fixed data · Does not change app settings, Debug build, Theme, Implementation, Scenario, Real Status Item, actual menu bar height, stage accessibility text, and the six scenario names. DeveloperPreviewScenario snapshots use .appServer or .unavailable instead of localized sourceName strings.

- [ ] **Step 4: Run developer-tool tests**

~~~bash
scripts/test.sh --filter DeveloperPreview
~~~

Expected: all debug preview tests pass in the normal debug test build.

- [ ] **Step 5: Commit debug localization**

~~~bash
git add Sources/CodexLimitPeek/App/AppDelegate.swift Sources/CodexLimitPeek/DeveloperTools Sources/CodexLimitPeek/Localization Sources/CodexLimitPeek/Resources Tests/CodexLimitPeekTests/DeveloperTools
git commit -m "feat: localize developer preview"
~~~

### Task 11: Complete integration verification and install the localized app

**Files:**
- Modify: any tests whose explicit constructor signatures changed in Tasks 1-10
- No production behavior additions beyond fixes required by failing verification

- [ ] **Step 1: Run the complete test suite**

~~~bash
scripts/test.sh
~~~

Expected: all tests pass; DocumentationPreviewRenderingTests remain skipped under the established CI/local-render boundary unless explicitly selected.

- [ ] **Step 2: Run a release build**

~~~bash
scripts/build-app.sh
~~~

Expected: Codex Limit Peek builds successfully with both lproj resource directories copied into the application bundle.

- [ ] **Step 3: Inspect the bundle resources**

~~~bash
find "Codex Limit Peek.app/Contents/Resources" -maxdepth 2 -type f -name 'Localizable.strings' -print
~~~

Expected: one English and one zh-Hans Localizable.strings file are present. If build-app.sh places the app elsewhere, inspect the exact output path printed by that script.

- [ ] **Step 4: Install and restart**

~~~bash
scripts/install.sh
scripts/restart.sh
~~~

Expected: the installed menu-bar app launches and the repository-local .build directory is not created by installation.

- [ ] **Step 5: Perform real UI acceptance**

Verify this exact sequence:

1. Open the main panel and More overlay.
2. Enter Language and choose English.
3. Confirm the overlay stays open on the Language page with English labels.
4. Return to More and Appearance; confirm English labels, help, and accessibility text.
5. Confirm menu-bar tooltip, quota source, reset description, and failure reason are English.
6. Enable voice; confirm the next utterance uses an English voice and sentence.
7. Choose Simplified Chinese and repeat the same surfaces.
8. Choose Follow System; confirm the effective language matches macOS.
9. Switch themes and confirm the language preference remains unchanged.
10. Restart the app and confirm the saved preference persists.

- [ ] **Step 6: Check repository status and commit only verification fixes**

~~~bash
git status --short
git diff --check
~~~

Expected: no accidental .build artifacts, generated temporary resources, or unrelated files are staged. If verification required source fixes, stage their exact files and commit:

~~~bash
git commit -m "test: verify app language switching"
~~~

Do not create an empty commit when no fixes were required.
