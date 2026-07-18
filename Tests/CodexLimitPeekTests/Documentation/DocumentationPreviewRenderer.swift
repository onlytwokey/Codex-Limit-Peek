import AppKit
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
@testable import CodexLimitPeek

struct DocumentationPNGMetadata: Equatable {
    let width: Int
    let height: Int
    let dpiWidth: Double
    let dpiHeight: Double
    let isPNG: Bool
    let isSRGB: Bool
    let byteCount: Int
}

struct DocumentationStatusFixture {
    let snapshot: QuotaSnapshot
    let health: RefreshHealth
    let referenceDate: Date
    let stateLabel: String
    let detail: String

    var displayText: String {
        [
            snapshot.menuBarTitle(relativeTo: referenceDate),
            snapshot.menuBarTrailingTitle
        ]
            .compactMap { $0 }
            .joined(separator: " | ")
    }
}

struct DocumentationSettingsCell: Equatable {
    let page: MoreOverlayPage
    let scrollTarget: AppearanceEditorInitialScrollTarget?
    let title: String
}

final class DocumentationInMemoryUserDefaults:
    UserDefaults,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var values: [String: Any]

    init(values: [String: Any] = [:]) {
        self.values = values
        super.init(suiteName: nil)!
    }

    override func object(forKey defaultName: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return values[defaultName]
    }

    override func set(
        _ value: Any?,
        forKey defaultName: String
    ) {
        lock.lock()
        defer { lock.unlock() }
        if let value {
            values[defaultName] = value
        } else {
            values.removeValue(forKey: defaultName)
        }
    }

    override func removeObject(forKey defaultName: String) {
        lock.lock()
        defer { lock.unlock() }
        values.removeValue(forKey: defaultName)
    }

    override func dictionaryRepresentation() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

private struct DocumentationQuotaProvider: QuotaProvider {
    func refresh() -> QuotaRefreshResult {
        .unavailable
    }
}

enum DocumentationPreviewRenderError: Error {
    case cannotLocateUserPreferences
    case cannotCreateBitmap
    case cannotEncodePNG
    case cannotReadPNG
    case missingDPI
    case missingColorSpace
}

@MainActor
enum DocumentationPreviewRenderer {
    private static let preferenceSuitePrefix =
        "CodexLimitPeek.DocumentationPreview."
    private static let offscreenMargin: CGFloat = 2_048

    private struct IsolatedStores {
        let appearanceStore: AppearanceStore
        let quotaStore: QuotaStore
    }

    static let themePointSize = NSSize(
        width: 1_200,
        height: 450
    )
    static let quotaStatesPointSize = NSSize(
        width: 920,
        height: 360
    )
    static let refreshStatesPointSize = NSSize(
        width: 920,
        height: 675
    )
    static let settingsPointSize = NSSize(
        width: 720,
        height: 1_200
    )
    static let scale: CGFloat = 2
    static let statusBarThickness: CGFloat = 22

    static let panelData = ThemePanelDisplayData(
        headerText: "CODEX 示例 · 固定数据",
        percentText: "81%",
        primaryQuotaLabel: "5 小时剩余",
        shortResetText: "1h34m",
        primaryResetDetailText: "19:38",
        displayRemainingPercent: 81,
        showsSecondaryQuota: true,
        weeklyPercentText: "49%",
        weeklyResetDateText: "7月14日恢复"
    )

    static let fixedNow = Date(
        timeIntervalSince1970: 1_725_450_400
    )

    static var quotaFixtures: [DocumentationStatusFixture] {
        [
            DocumentationStatusFixture(
                snapshot: dualWindowSnapshot(
                    remainingPercent: 74,
                    weeklyRemainingPercent: 82,
                    resetInterval: 3 * 3_600 + 29 * 60
                ),
                health: .live,
                referenceDate: fixedNow,
                stateLabel: "额度充足",
                detail: "5 小时剩余 74%"
            ),
            DocumentationStatusFixture(
                snapshot: dualWindowSnapshot(
                    remainingPercent: 39,
                    weeklyRemainingPercent: 74,
                    resetInterval: 1 * 3_600 + 42 * 60
                ),
                health: .live,
                referenceDate: fixedNow,
                stateLabel: "额度一般",
                detail: "5 小时剩余 39%"
            ),
            DocumentationStatusFixture(
                snapshot: dualWindowSnapshot(
                    remainingPercent: 12,
                    weeklyRemainingPercent: 61,
                    resetInterval: 35 * 60
                ),
                health: .live,
                referenceDate: fixedNow,
                stateLabel: "额度偏低",
                detail: "5 小时剩余 12%"
            )
        ]
    }

    static var refreshFixtures: [DocumentationStatusFixture] {
        let dualWindow = dualWindowSnapshot(
            remainingPercent: 61,
            weeklyRemainingPercent: 74,
            resetInterval: 3 * 3_600 + 8 * 60
        )
        let weeklyOnly = weeklyOnlySnapshot(
            remainingPercent: 69,
            resetInterval: 5 * 86_400 + 22 * 3_600
        )
        return refreshHealthFixtures(for: dualWindow)
            + refreshHealthFixtures(for: weeklyOnly)
    }

    static let settingsCells = [
        DocumentationSettingsCell(
            page: .appearance,
            scrollTarget: .themeSelector,
            title: "主题与基础色板"
        ),
        DocumentationSettingsCell(
            page: .appearance,
            scrollTarget: .panelControls,
            title: "面板字形、几何、阴影与材质"
        ),
        DocumentationSettingsCell(
            page: .statusItem,
            scrollTarget: .statusItemControls,
            title: "状态栏显示层"
        ),
        DocumentationSettingsCell(
            page: .stateColors,
            scrollTarget: .stateColorControls,
            title: "高级状态颜色"
        )
    ]

    private static func dualWindowSnapshot(
        remainingPercent: Int,
        weeklyRemainingPercent: Int,
        resetInterval: TimeInterval
    ) -> QuotaSnapshot {
        QuotaSnapshot(
            remainingPercent: remainingPercent,
            weeklyRemainingPercent: weeklyRemainingPercent,
            resetDate: fixedNow.addingTimeInterval(resetInterval),
            weeklyResetDate: fixedNow.addingTimeInterval(7 * 86_400),
            lastUpdated: fixedNow,
            sourceName: "固定演示数据",
            isUnavailable: false,
            displayMode: .dualWindow
        )
    }

    private static func weeklyOnlySnapshot(
        remainingPercent: Int,
        resetInterval: TimeInterval
    ) -> QuotaSnapshot {
        let resetDate = fixedNow.addingTimeInterval(resetInterval)
        return QuotaSnapshot(
            remainingPercent: remainingPercent,
            weeklyRemainingPercent: remainingPercent,
            resetDate: resetDate,
            weeklyResetDate: resetDate,
            lastUpdated: fixedNow,
            sourceName: "固定演示数据",
            isUnavailable: false,
            displayMode: .weeklyOnly
        )
    }

    private static func refreshHealthFixtures(
        for snapshot: QuotaSnapshot
    ) -> [DocumentationStatusFixture] {
        [
            DocumentationStatusFixture(
                snapshot: snapshot,
                health: .live,
                referenceDate: fixedNow,
                stateLabel: "实时同步正常",
                detail: "显示值来自实时读取"
            ),
            DocumentationStatusFixture(
                snapshot: snapshot,
                health: .confirmingFailure,
                referenceDate: fixedNow,
                stateLabel: "正在确认失败",
                detail: "保留最近可靠值"
            ),
            DocumentationStatusFixture(
                snapshot: snapshot,
                health: .degraded,
                referenceDate: fixedNow,
                stateLabel: "已确认刷新失败",
                detail: "继续自动尝试恢复"
            )
        ]
    }

    static func withIsolatedStores<Result>(
        _ operation: (
            AppearanceStore,
            QuotaStore
        ) throws -> Result
    ) throws -> Result {
        let stores = try makeIsolatedStores()
        return try operation(
            stores.appearanceStore,
            stores.quotaStore
        )
    }

    private static func makeIsolatedStores() throws -> IsolatedStores {
        let encoder = JSONEncoder()
        var initialValues: [String: Any] = [
            AppearancePersistenceKey.selectedTheme:
                AppearanceThemeID.loud.rawValue,
            AppearancePersistenceKey.editorFontScale:
                AppearanceEditorTypography.defaultScale
        ]
        for theme in AppearanceThemeID.allCases {
            initialValues[
                AppearancePersistenceKey.profile(theme)
            ] = try encoder.encode(
                AppearanceProfile.default(for: theme)
            )
        }
        let defaults = DocumentationInMemoryUserDefaults(
            values: initialValues
        )

        let now = fixedNow
        let appearanceStore = AppearanceStore(
            defaults: defaults,
            saveDelayNanoseconds: 0
        )
        let quotaStore = QuotaStore(
            provider: DocumentationQuotaProvider(),
            defaults: defaults,
            now: { now },
            monotonicNow: { 0 },
            minimumRefreshInterval: 0,
            sleep: { _ in }
        )
        quotaStore.snapshot = QuotaSnapshot(
            remainingPercent: 81,
            weeklyRemainingPercent: 49,
            resetDate: now.addingTimeInterval(5_640),
            weeklyResetDate: now.addingTimeInterval(432_000),
            lastUpdated: now,
            sourceName: "Codex 示例",
            isUnavailable: false,
            displayMode: .dualWindow
        )
        return IsolatedStores(
            appearanceStore: appearanceStore,
            quotaStore: quotaStore
        )
    }

    private static func userPreferencesDirectory() throws -> URL {
        guard let library = FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first else {
            throw DocumentationPreviewRenderError
                .cannotLocateUserPreferences
        }
        return library
            .appendingPathComponent(
                "Preferences",
                isDirectory: true
            )
            .standardizedFileURL
    }

    static func preferenceArtifactsForTesting() throws -> Set<URL> {
        let directory = try userPreferencesDirectory()
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        return Set(
            contents.filter { url in
                guard url.pathExtension == "plist" else {
                    return false
                }
                let suite = url
                    .deletingPathExtension()
                    .lastPathComponent
                return suite.hasPrefix(preferenceSuitePrefix)
            }
        )
    }

    static func metadata(
        for url: URL
    ) throws -> DocumentationPNGMetadata {
        guard
            let source = CGImageSourceCreateWithURL(
                url as CFURL,
                nil
            ),
            let image = CGImageSourceCreateImageAtIndex(
                source,
                0,
                nil
            )
        else {
            throw DocumentationPreviewRenderError.cannotReadPNG
        }
        guard let colorSpaceName = image.colorSpace?.name else {
            throw DocumentationPreviewRenderError.missingColorSpace
        }
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(
                source,
                0,
                nil
            ) as? [CFString: Any],
            let dpiWidth = (
                properties[kCGImagePropertyDPIWidth] as? NSNumber
            )?.doubleValue,
            let dpiHeight = (
                properties[kCGImagePropertyDPIHeight] as? NSNumber
            )?.doubleValue
        else {
            throw DocumentationPreviewRenderError.missingDPI
        }
        let byteCount = try url.resourceValues(
            forKeys: [.fileSizeKey]
        ).fileSize ?? 0
        let imageType = CGImageSourceGetType(source) as String?
        return DocumentationPNGMetadata(
            width: image.width,
            height: image.height,
            dpiWidth: dpiWidth,
            dpiHeight: dpiHeight,
            isPNG: imageType == UTType.png.identifier,
            isSRGB: colorSpaceName == CGColorSpace.sRGB,
            byteCount: byteCount
        )
    }

    static func renderAll(
        to directory: URL
    ) async throws -> [URL] {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        await Task.yield()

        let panelURL = directory
            .appendingPathComponent("panel-preview.png")
        let settingsURL = directory
            .appendingPathComponent(
                "appearance-settings-loud.png"
            )
        let quotaStatesURL = directory
            .appendingPathComponent(
                "quota-states-loud.png"
            )
        let refreshStatesURL = directory
            .appendingPathComponent(
                "refresh-states-loud.png"
            )

        let panelPNG = try await renderThemePreviewForTesting(
            data: panelData,
            statusBarThickness: statusBarThickness
        )
        let quotaStatesPNG = try await rasterize(
            DocumentationQuotaStatesPreview(
                fixtures: quotaFixtures
            ),
            pointSize: quotaStatesPointSize,
            statusBarThickness: statusBarThickness
        )
        let refreshStatesPNG = try await rasterize(
            DocumentationRefreshStatesPreview(
                fixtures: refreshFixtures
            ),
            pointSize: refreshStatesPointSize,
            statusBarThickness: statusBarThickness
        )
        let settingsPNG = try await renderSettingsPreviewForTesting()

        try panelPNG.write(to: panelURL, options: .atomic)
        try quotaStatesPNG.write(
            to: quotaStatesURL,
            options: .atomic
        )
        try refreshStatesPNG.write(
            to: refreshStatesURL,
            options: .atomic
        )
        try settingsPNG.write(to: settingsURL, options: .atomic)
        return [
            panelURL,
            quotaStatesURL,
            refreshStatesURL,
            settingsURL
        ]
    }

    static func renderThemePreviewForTesting(
        data: ThemePanelDisplayData,
        statusBarThickness: CGFloat
    ) async throws -> Data {
        try await rasterize(
            DocumentationThemePreview(
                data: data,
                statusBarThickness: statusBarThickness
            ),
            pointSize: themePointSize,
            statusBarThickness: statusBarThickness
        )
    }

    static func renderSettingsPreviewForTesting() async throws -> Data {
        let stores = try makeIsolatedStores()
        return try await rasterize(
            DocumentationSettingsAtlas(
                appearanceStore: stores.appearanceStore,
                quotaStore: stores.quotaStore
            ),
            pointSize: settingsPointSize,
            statusBarThickness: statusBarThickness
        )
    }

    static func renderOverlayPageForTesting(
        page: MoreOverlayPage,
        scrollTarget: AppearanceEditorInitialScrollTarget?
    ) async throws -> Data {
        guard let pointSize = page.fixedSize else {
            throw DocumentationPreviewRenderError
                .cannotCreateBitmap
        }
        let stores = try makeIsolatedStores()
        return try await rasterize(
            DocumentationOverlayPage(
                quotaStore: stores.quotaStore,
                appearanceStore: stores.appearanceStore,
                page: page,
                scrollTarget: scrollTarget
            ),
            pointSize: pointSize,
            statusBarThickness: statusBarThickness
        )
    }

    static func makeStatusItemViewForTesting(
        snapshot: QuotaSnapshot,
        health: RefreshHealth,
        referenceDate: Date
    ) -> CompactStatusItemView {
        let view = CompactStatusItemView()
        configureStatusItemView(
            view,
            snapshot: snapshot,
            health: health,
            referenceDate: referenceDate
        )
        return view
    }

    static func renderStatusItemForTesting(
        snapshot: QuotaSnapshot,
        health: RefreshHealth,
        referenceDate: Date
    ) async throws -> Data {
        let view = makeStatusItemViewForTesting(
            snapshot: snapshot,
            health: health,
            referenceDate: referenceDate
        )
        return try await rasterize(
            view,
            pointSize: view.frame.size
        )
    }

    fileprivate static func configureStatusItemView(
        _ view: CompactStatusItemView,
        snapshot: QuotaSnapshot,
        health: RefreshHealth,
        referenceDate: Date
    ) {
        let showsFailurePattern = health.showsFailurePattern
        let appearance = AppearanceResolver.status(
            profile: .default(for: .loud),
            primaryRemainingPercent:
                snapshot.remainingPercent,
            weeklyRemainingPercent:
                snapshot.weeklyRemainingPercent,
            isUnavailable: snapshot.isUnavailable,
            showsFailurePattern: showsFailurePattern
        )
        .fitted(to: Double(statusBarThickness))
        view.update(
            title: snapshot.menuBarTitle(
                relativeTo: referenceDate
            ),
            weeklyTitle: snapshot.menuBarTrailingTitle,
            appearance: appearance,
            showsFailurePattern: showsFailurePattern,
            tooltip: "固定演示数据",
            statusBarThickness: statusBarThickness
        )
    }

    fileprivate static func statusItemSize(
        snapshot: QuotaSnapshot,
        health: RefreshHealth,
        referenceDate: Date
    ) -> NSSize {
        makeStatusItemViewForTesting(
            snapshot: snapshot,
            health: health,
            referenceDate: referenceDate
        )
        .frame.size
    }

    private static func rasterize<V: View>(
        _ view: V,
        pointSize: NSSize,
        statusBarThickness: CGFloat
    ) async throws -> Data {
        let root = view
            .frame(
                width: pointSize.width,
                height: pointSize.height
            )
            .environment(\.colorScheme, .light)
            .environment(
                \.themeStatusBarThicknessOverride,
                statusBarThickness
            )
            .transaction { transaction in
                transaction.animation = nil
            }

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: pointSize)
        host.appearance = NSAppearance(named: .aqua)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: pointSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.colorSpace = .sRGB
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.contentView = host
        window.setFrameOrigin(
            offscreenOrigin(for: pointSize)
        )
        window.orderFront(nil)
        defer {
            window.contentView = nil
            window.orderOut(nil)
            window.close()
        }

        for _ in 0..<4 {
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
            await Task.yield()
            try? await Task.sleep(
                nanoseconds: 20_000_000
            )
        }

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pointSize.width * scale),
            pixelsHigh: Int(pointSize.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw DocumentationPreviewRenderError
                .cannotCreateBitmap
        }
        bitmap.size = pointSize
        host.cacheDisplay(in: host.bounds, to: bitmap)

        guard let png = bitmap.representation(
            using: NSBitmapImageRep.FileType.png,
            properties: [:]
        ) else {
            throw DocumentationPreviewRenderError
                .cannotEncodePNG
        }
        return png
    }

    private static func rasterize(
        _ view: NSView,
        pointSize: NSSize
    ) async throws -> Data {
        view.frame = NSRect(origin: .zero, size: pointSize)
        view.appearance = NSAppearance(named: .aqua)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: pointSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.colorSpace = .sRGB
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.contentView = view
        window.setFrameOrigin(
            offscreenOrigin(for: pointSize)
        )
        window.orderFront(nil)
        defer {
            window.contentView = nil
            window.orderOut(nil)
            window.close()
        }

        for _ in 0..<2 {
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
            await Task.yield()
        }

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pointSize.width * scale),
            pixelsHigh: Int(pointSize.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw DocumentationPreviewRenderError
                .cannotCreateBitmap
        }
        bitmap.size = pointSize
        view.cacheDisplay(in: view.bounds, to: bitmap)

        guard let png = bitmap.representation(
            using: .png,
            properties: [:]
        ) else {
            throw DocumentationPreviewRenderError
                .cannotEncodePNG
        }
        return png
    }

    private static func offscreenOrigin(
        for pointSize: NSSize
    ) -> NSPoint {
        let screenFrames = NSScreen.screens.map(\.frame)
        let minimumX = screenFrames.map(\.minX).min() ?? 0
        let minimumY = screenFrames.map(\.minY).min() ?? 0
        return NSPoint(
            x: minimumX - pointSize.width - offscreenMargin,
            y: minimumY - pointSize.height - offscreenMargin
        )
    }
}

private enum DocumentationLOUDStyle {
    static var ink: Color {
        AppearanceColor(hex: 0x171717).swiftUIColor
    }

    static var paper: Color {
        AppearanceColor.white.swiftUIColor
    }

    static var yellow: Color {
        AppearanceColor(hex: 0xFFE36E).swiftUIColor
    }

    static var coral: Color {
        AppearanceColor(hex: 0xFF716F).swiftUIColor
    }

    static var teal: Color {
        AppearanceColor(hex: 0x52D2C8).swiftUIColor
    }

    static var mutedInk: Color {
        AppearanceColor(hex: 0x6B6242).swiftUIColor
    }
}

@MainActor
private struct DocumentationStatusItemRepresentable:
    NSViewRepresentable
{
    let snapshot: QuotaSnapshot
    let health: RefreshHealth
    let referenceDate: Date

    func makeNSView(
        context: Context
    ) -> CompactStatusItemView {
        DocumentationPreviewRenderer
            .makeStatusItemViewForTesting(
                snapshot: snapshot,
                health: health,
                referenceDate: referenceDate
            )
    }

    func updateNSView(
        _ nsView: CompactStatusItemView,
        context: Context
    ) {
        DocumentationPreviewRenderer
            .configureStatusItemView(
                nsView,
                snapshot: snapshot,
                health: health,
                referenceDate: referenceDate
            )
    }
}

@MainActor
private struct DocumentationProductionStatusItem: View {
    let fixture: DocumentationStatusFixture

    var body: some View {
        let size = DocumentationPreviewRenderer.statusItemSize(
            snapshot: fixture.snapshot,
            health: fixture.health,
            referenceDate: fixture.referenceDate
        )
        DocumentationStatusItemRepresentable(
            snapshot: fixture.snapshot,
            health: fixture.health,
            referenceDate: fixture.referenceDate
        )
        .frame(
            width: size.width,
            height: size.height
        )
        .accessibilityHidden(true)
    }
}

private struct DocumentationQuotaStatesPreview: View {
    let fixtures: [DocumentationStatusFixture]

    var body: some View {
        ZStack {
            DocumentationLOUDStyle.yellow

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("菜单栏用量颜色")
                        .font(
                            .system(
                                size: 27,
                                weight: .black,
                                design: .rounded
                            )
                        )
                    Text(
                        "颜色跟随左侧 5 小时剩余额度，最右侧保持显示周额度"
                    )
                    .font(
                        .system(
                            size: 12,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        DocumentationLOUDStyle.mutedInk
                    )
                }

                HStack(spacing: 18) {
                    ForEach(
                        Array(fixtures.enumerated()),
                        id: \.offset
                    ) { _, fixture in
                        quotaCard(fixture)
                    }
                }
            }
            .padding(28)
        }
        .foregroundStyle(DocumentationLOUDStyle.ink)
        .frame(
            width: DocumentationPreviewRenderer
                .quotaStatesPointSize.width,
            height: DocumentationPreviewRenderer
                .quotaStatesPointSize.height
        )
    }

    private func quotaCard(
        _ fixture: DocumentationStatusFixture
    ) -> some View {
        VStack(spacing: 18) {
            DocumentationProductionStatusItem(
                fixture: fixture
            )
            .frame(height: 30)

            Text(fixture.stateLabel)
                .font(
                    .system(
                        size: 19,
                        weight: .black,
                        design: .rounded
                    )
                )

            Text(fixture.detail)
                .font(
                    .system(
                        size: 11,
                        weight: .bold,
                        design: .monospaced
                    )
                )
                .foregroundStyle(
                    DocumentationLOUDStyle.mutedInk
                )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 205)
        .background(DocumentationLOUDStyle.paper)
        .overlay(
            Rectangle()
                .stroke(
                    DocumentationLOUDStyle.ink,
                    lineWidth: 3
                )
        )
        .background {
            Rectangle()
                .fill(DocumentationLOUDStyle.ink)
                .offset(x: 7, y: 7)
        }
    }
}

private struct DocumentationRefreshStatesPreview: View {
    let fixtures: [DocumentationStatusFixture]

    var body: some View {
        ZStack(alignment: .topLeading) {
            DocumentationLOUDStyle.yellow

            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("刷新健康状态")
                        .font(
                            .system(
                                size: 27,
                                weight: .black,
                                design: .rounded
                            )
                        )
                    Text(
                        "额度文本保持不变；仅在确认失败后启用白底红纹"
                    )
                    .font(
                        .system(
                            size: 12,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        DocumentationLOUDStyle.mutedInk
                    )
                }

                refreshRow(
                    title: "5 小时 + 周额度",
                    fixtures: Array(fixtures.prefix(3))
                )
                refreshRow(
                    title: "仅周额度",
                    fixtures: Array(fixtures.suffix(3))
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        "确认节奏：15 秒 → 45 秒 → 3 次失败且至少经过 60 秒"
                    )
                    Text(
                        "确认失败后：首次等待 2 分钟；持续失败的重试间隔最长 5 分钟"
                    )
                }
                .font(
                    .system(
                        size: 11,
                        weight: .black,
                        design: .monospaced
                    )
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .background(DocumentationLOUDStyle.coral)
                .overlay(
                    Rectangle()
                        .stroke(
                            DocumentationLOUDStyle.ink,
                            lineWidth: 2
                        )
                )
            }
            .padding(24)
        }
        .foregroundStyle(DocumentationLOUDStyle.ink)
        .frame(
            width: DocumentationPreviewRenderer
                .refreshStatesPointSize.width,
            height: DocumentationPreviewRenderer
                .refreshStatesPointSize.height
        )
    }

    private func refreshRow(
        title: String,
        fixtures: [DocumentationStatusFixture]
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(
                    .system(
                        size: 14,
                        weight: .black,
                        design: .rounded
                    )
                )

            HStack(spacing: 18) {
                ForEach(
                    Array(fixtures.enumerated()),
                    id: \.offset
                ) { _, fixture in
                    refreshCard(fixture)
                }
            }
        }
    }

    private func refreshCard(
        _ fixture: DocumentationStatusFixture
    ) -> some View {
        VStack(spacing: 11) {
            DocumentationProductionStatusItem(
                fixture: fixture
            )
            .frame(height: 28)

            Circle()
                .fill(healthAccent(fixture.health))
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(
                            DocumentationLOUDStyle.ink,
                            lineWidth: 1.5
                        )
                )

            Text(fixture.stateLabel)
                .font(
                    .system(
                        size: 16,
                        weight: .black,
                        design: .rounded
                    )
                )

            Text(fixture.detail)
                .font(
                    .system(
                        size: 10,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    DocumentationLOUDStyle.mutedInk
                )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 196)
        .background(DocumentationLOUDStyle.paper)
        .overlay(
            Rectangle()
                .stroke(
                    DocumentationLOUDStyle.ink,
                    lineWidth: 3
                )
        )
        .background {
            Rectangle()
                .fill(DocumentationLOUDStyle.ink)
                .offset(x: 6, y: 6)
        }
    }

    private func healthAccent(
        _ health: RefreshHealth
    ) -> Color {
        switch health {
        case .live:
            DocumentationLOUDStyle.teal
        case .confirmingFailure:
            DocumentationLOUDStyle.yellow
        case .degraded, .unavailable:
            DocumentationLOUDStyle.coral
        }
    }
}

private struct DocumentationThemePreview: View {
    let data: ThemePanelDisplayData
    let statusBarThickness: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.13, blue: 0.15),
                    Color(red: 0.32, green: 0.34, blue: 0.37)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 12) {
                ForEach(
                    AppearanceThemeID.allCases,
                    id: \.self
                ) { theme in
                    themeColumn(theme)
                }
            }
            .padding(24)
        }
        .frame(
            width: DocumentationPreviewRenderer
                .themePointSize.width,
            height: DocumentationPreviewRenderer
                .themePointSize.height
        )
    }

    private func panelAppearance(
        _ theme: AppearanceThemeID
    ) -> ResolvedPanelAppearance {
        AppearanceResolver.panel(
            profile: .default(for: theme),
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false
        )
    }

    private func statusAppearance(
        _ theme: AppearanceThemeID
    ) -> ResolvedStatusItemAppearance {
        AppearanceResolver.status(
            profile: .default(for: theme),
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false,
            showsFailurePattern: false
        )
    }

    private func themeColumn(
        _ theme: AppearanceThemeID
    ) -> some View {
        VStack(spacing: 10) {
            Text(theme.displayName)
                .font(
                    .system(
                        size: 15,
                        weight: .black,
                        design: .monospaced
                    )
                )
                .tracking(1)
                .foregroundStyle(.white)

            ThemeStatusChromePreview(
                appearance: statusAppearance(theme)
            )
            .environment(
                \.themeStatusBarThicknessOverride,
                statusBarThickness
            )

            ScaledThemePanelChromePreview(
                appearance: panelAppearance(theme),
                data: data,
                targetWidth: 360
            )
        }
        .frame(width: 376)
    }
}

private struct DocumentationOverlayPage: View {
    @ObservedObject var quotaStore: QuotaStore
    @ObservedObject var appearanceStore: AppearanceStore
    let page: MoreOverlayPage
    let scrollTarget: AppearanceEditorInitialScrollTarget?

    private var contentSize: NSSize {
        page.fixedSize ?? .zero
    }

    var body: some View {
        ZStack {
            MoreOverlayDecorationView(
                quotaStore: quotaStore,
                appearanceStore: appearanceStore,
                contentSize: contentSize
            )

            MoreOverlayInteractionView(
                quotaStore: quotaStore,
                appearanceStore: appearanceStore,
                page: page,
                onNavigate: { _ in },
                onOpenCustomColor: { _ in }
            )
            .environment(
                \.appearanceEditorInitialScrollTarget,
                scrollTarget
            )
        }
        .frame(
            width: contentSize.width,
            height: contentSize.height
        )
        .fixedSize()
        .clipped()
    }
}

private struct DocumentationSettingsAtlas: View {
    @ObservedObject var appearanceStore: AppearanceStore
    @ObservedObject var quotaStore: QuotaStore

    var body: some View {
        ZStack {
            DocumentationLOUDStyle.yellow

            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(
                        Array(
                            DocumentationPreviewRenderer
                                .settingsCells
                                .prefix(2)
                                .enumerated()
                        ),
                        id: \.offset
                    ) { _, cell in
                        atlasCell(cell)
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    ForEach(
                        Array(
                            DocumentationPreviewRenderer
                                .settingsCells
                                .suffix(2)
                                .enumerated()
                        ),
                        id: \.offset
                    ) { _, cell in
                        atlasCell(cell)
                    }
                }
            }
            .padding(16)
        }
        .frame(
            width: DocumentationPreviewRenderer
                .settingsPointSize.width,
            height: DocumentationPreviewRenderer
                .settingsPointSize.height
        )
    }

    private func atlasCell(
        _ cell: DocumentationSettingsCell
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(cell.title)
                .font(
                    .system(
                        size: 12,
                        weight: .black,
                        design: .monospaced
                    )
                )
                .foregroundStyle(
                    DocumentationLOUDStyle.ink
                )
                .frame(height: 20)

            DocumentationOverlayPage(
                quotaStore: quotaStore,
                appearanceStore: appearanceStore,
                page: cell.page,
                scrollTarget: cell.scrollTarget
            )
        }
        .frame(
            width: 336,
            height: 576,
            alignment: .topLeading
        )
    }
}
