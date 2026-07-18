import AppKit
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
@testable import CodexLimitPeek

struct DocumentationPNGMetadata: Equatable {
    let width: Int
    let height: Int
    let isPNG: Bool
    let isSRGB: Bool
    let byteCount: Int
}

private struct DocumentationQuotaProvider: QuotaProvider {
    func refresh() -> QuotaRefreshResult {
        .unavailable
    }
}

enum DocumentationPreviewRenderError: Error {
    case cannotCreateUserDefaults
    case cannotCreateBitmap
    case cannotEncodePNG
    case cannotReadPNG
    case missingColorSpace
}

@MainActor
enum DocumentationPreviewRenderer {
    private struct IsolatedStores {
        let suite: String
        let defaults: UserDefaults
        let appearanceStore: AppearanceStore
        let quotaStore: QuotaStore
    }

    static let themePointSize = NSSize(
        width: 1_200,
        height: 450
    )
    static let settingsPointSize = NSSize(
        width: 720,
        height: 600
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

    private static let fixedNow = Date(
        timeIntervalSince1970: 1_725_450_400
    )

    static func withIsolatedStores<Result>(
        _ operation: (
            AppearanceStore,
            QuotaStore
        ) throws -> Result
    ) throws -> Result {
        let stores = try makeIsolatedStores()
        defer {
            stores.defaults.removePersistentDomain(
                forName: stores.suite
            )
        }
        return try operation(
            stores.appearanceStore,
            stores.quotaStore
        )
    }

    private static func makeIsolatedStores() throws -> IsolatedStores {
        let suite = "CodexLimitPeek.DocumentationPreview."
            + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw DocumentationPreviewRenderError
                .cannotCreateUserDefaults
        }

        let encoder = JSONEncoder()
        for theme in AppearanceThemeID.allCases {
            defaults.set(
                try encoder.encode(
                    AppearanceProfile.default(for: theme)
                ),
                forKey: AppearancePersistenceKey.profile(theme)
            )
        }
        defaults.set(
            AppearanceThemeID.loud.rawValue,
            forKey: AppearancePersistenceKey.selectedTheme
        )
        defaults.set(
            AppearanceEditorTypography.defaultScale,
            forKey: AppearancePersistenceKey.editorFontScale
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
            suite: suite,
            defaults: defaults,
            appearanceStore: appearanceStore,
            quotaStore: quotaStore
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
        let byteCount = try url.resourceValues(
            forKeys: [.fileSizeKey]
        ).fileSize ?? 0
        let imageType = CGImageSourceGetType(source) as String?
        return DocumentationPNGMetadata(
            width: image.width,
            height: image.height,
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

        let panelPNG = try await renderThemePreviewForTesting(
            data: panelData,
            statusBarThickness: statusBarThickness
        )
        let settingsPNG = try await renderSettingsPreviewForTesting(
            appearanceScrollTarget: .themeSelector,
            statusScrollTarget: .statusItemControls
        )

        try panelPNG.write(to: panelURL, options: .atomic)
        try settingsPNG.write(to: settingsURL, options: .atomic)
        return [panelURL, settingsURL]
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

    static func renderSettingsPreviewForTesting(
        appearanceScrollTarget:
            AppearanceEditorInitialScrollTarget?,
        statusScrollTarget:
            AppearanceEditorInitialScrollTarget?
    ) async throws -> Data {
        let stores = try makeIsolatedStores()
        defer {
            stores.defaults.removePersistentDomain(
                forName: stores.suite
            )
        }
        return try await rasterize(
            DocumentationSettingsPreview(
                appearanceStore: stores.appearanceStore,
                quotaStore: stores.quotaStore,
                appearanceScrollTarget:
                    appearanceScrollTarget,
                statusScrollTarget: statusScrollTarget
            ),
            pointSize: settingsPointSize,
            statusBarThickness: statusBarThickness
        )
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
        window.contentView = host
        window.setFrameOrigin(
            NSPoint(x: -10_000, y: -10_000)
        )
        window.orderFrontRegardless()
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

    var body: some View {
        ZStack {
            MoreOverlayDecorationView(
                quotaStore: quotaStore,
                appearanceStore: appearanceStore,
                contentSize: NSSize(width: 320, height: 548)
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
        .frame(width: 320, height: 548)
        .clipped()
    }
}

private struct DocumentationSettingsPreview: View {
    @ObservedObject var appearanceStore: AppearanceStore
    @ObservedObject var quotaStore: QuotaStore
    let appearanceScrollTarget:
        AppearanceEditorInitialScrollTarget?
    let statusScrollTarget:
        AppearanceEditorInitialScrollTarget?

    var body: some View {
        ZStack {
            Color(
                nsColor: NSColor(
                    srgbRed: 0.91,
                    green: 0.93,
                    blue: 0.95,
                    alpha: 1
                )
            )

            HStack(spacing: 32) {
                DocumentationOverlayPage(
                    quotaStore: quotaStore,
                    appearanceStore: appearanceStore,
                    page: .appearance,
                    scrollTarget: appearanceScrollTarget
                )
                DocumentationOverlayPage(
                    quotaStore: quotaStore,
                    appearanceStore: appearanceStore,
                    page: .statusItem,
                    scrollTarget: statusScrollTarget
                )
            }
        }
        .frame(
            width: DocumentationPreviewRenderer
                .settingsPointSize.width,
            height: DocumentationPreviewRenderer
                .settingsPointSize.height
        )
    }
}
