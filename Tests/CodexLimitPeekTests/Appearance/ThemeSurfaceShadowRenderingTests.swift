import AppKit
import SwiftUI
import Testing
@testable import CodexLimitPeek

@Suite(.serialized)
struct ThemeSurfaceShadowRenderingTests {
    @Test @MainActor
    func loudQuotaCardKeepsHardShadowInBothPanelLayouts() throws {
        for showsSecondaryQuota in [false, true] {
            let noShadow = shadowPixelCounts(
                in: try renderLOUDPanel(
                    showsSecondaryQuota: showsSecondaryQuota,
                    shadowDepth: 0
                )
            )
            #expect(noShadow.right < 50)
            #expect(noShadow.bottom < 50)

            for _ in 0..<3 {
                let bitmap = try renderLOUDPanel(
                    showsSecondaryQuota: showsSecondaryQuota
                )
                let shadow = shadowPixelCounts(in: bitmap)
                #expect(
                    shadow.right
                        > Int(
                            ThemePanelLayout.height
                                * renderScale
                                * 0.45
                        )
                )
                #expect(
                    shadow.bottom
                        > Int(
                            (
                                ThemePanelLayout.width
                                    - ThemePanelLayout.contentPadding * 4
                            ) * renderScale
                        )
                )
            }
        }
    }

    @Test @MainActor
    func loudPanelShellKeepsItsHardShadowAcrossRepeatedRenders()
        throws
    {
        let noShadow = shellShadowPixelCounts(
            in: try renderShell(
                theme: .loud,
                includesShadow: false
            ),
            theme: .loud
        )
        #expect(noShadow.right < 50)
        #expect(noShadow.bottom < 50)

        for _ in 0..<3 {
            let shadow = shellShadowPixelCounts(
                in: try renderShell(
                    theme: .loud,
                    includesShadow: true
                ),
                theme: .loud
            )
            #expect(
                shadow.right
                    > Int(
                        ThemePanelLayout.height
                            * renderScale
                            * 0.75
                    )
            )
            #expect(
                shadow.bottom
                    > Int(
                        ThemePanelLayout.width
                            * renderScale
                            * 0.75
                    )
            )
        }
    }

    @Test @MainActor
    func frostPanelShellKeepsHardShadowWithoutTintingMaterial()
        throws
    {
        let noShadow = try renderShell(
            theme: .frost,
            includesShadow: false
        )
        let withShadow = try renderShell(
            theme: .frost,
            includesShadow: true
        )
        let noShadowPixels = shellShadowPixelCounts(
            in: noShadow,
            theme: .frost
        )
        let shadowPixels = shellShadowPixelCounts(
            in: withShadow,
            theme: .frost
        )

        #expect(noShadowPixels.right < 50)
        #expect(noShadowPixels.bottom < 50)
        #expect(
            shadowPixels.right
                > Int(
                    ThemePanelLayout.height
                        * renderScale
                        * 0.75
                )
        )
        #expect(
            shadowPixels.bottom
                > Int(
                    ThemePanelLayout.width
                        * renderScale
                        * 0.75
                )
        )

        let withoutShadowColor = try #require(
            shellCenterColor(in: noShadow)?.usingColorSpace(.sRGB)
        )
        let withShadowColor = try #require(
            shellCenterColor(in: withShadow)?.usingColorSpace(.sRGB)
        )
        #expect(
            maximumComponentDifference(
                withoutShadowColor,
                withShadowColor
            ) < 0.01
        )
    }

    @MainActor
    private func renderLOUDPanel(
        showsSecondaryQuota: Bool,
        shadowDepth: Double = 8
    ) throws -> NSBitmapImageRep {
        var profile = AppearanceProfile.default(for: .loud)
        profile.geometry.shadowDepth = shadowDepth
        let appearance = AppearanceResolver.panel(
            profile: profile,
            primaryRemainingPercent: 83,
            weeklyRemainingPercent: 83,
            isUnavailable: false
        )
        var data = ThemePanelDisplayData.reference(for: .loud)
        data.showsSecondaryQuota = showsSecondaryQuota
        data.percentText = "83%"
        data.primaryQuotaLabel = showsSecondaryQuota
            ? "5 小时剩余"
            : "周额度剩余"
        data.shortResetText = showsSecondaryQuota ? "1h34m" : "6d20h"

        let root = ThemePanelComposition(
            appearance: appearance,
            data: data,
            headerForeground:
                appearance.backgroundTextColor.swiftUIColor,
            showsOuterChrome: false
        ) {
            Color.clear
                .frame(width: 58, height: ThemePanelLayout.actionSize)
        }
        .frame(
            width: ThemePanelLayout.width,
            height: ThemePanelLayout.height
        )

        let pointSize = NSSize(
            width: ThemePanelLayout.width,
            height: ThemePanelLayout.height
        )
        return try render(root, pointSize: pointSize)
    }

    @MainActor
    private func renderShell(
        theme: AppearanceThemeID,
        includesShadow: Bool
    ) throws -> NSBitmapImageRep {
        let appearance = AppearanceResolver.panel(
            profile: .default(for: theme),
            primaryRemainingPercent: 83,
            weeklyRemainingPercent: 83,
            isUnavailable: false
        )
        let root = PanelGlassBackground(
            appearance: appearance,
            includesShadow: includesShadow
        )
        .frame(
            width: PanelMetrics.cardWidth,
            height: PanelMetrics.cardHeight
        )
        .padding(PanelMetrics.shadowInset)
        .frame(
            width: PanelMetrics.shadowWidth,
            height: PanelMetrics.shadowHeight
        )
        return try render(
            root,
            pointSize: NSSize(
                width: PanelMetrics.shadowWidth,
                height: PanelMetrics.shadowHeight
            )
        )
    }

    @MainActor
    private func render<V: View>(
        _ root: V,
        pointSize: NSSize
    ) throws -> NSBitmapImageRep {
        let renderedRoot = root
            .environment(\.colorScheme, .light)
            .transaction { transaction in
                transaction.animation = nil
            }
        let host = NSHostingView(rootView: renderedRoot)
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
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.orderFront(nil)
        defer {
            window.contentView = nil
            window.orderOut(nil)
            window.close()
        }

        for _ in 0..<2 {
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
            RunLoop.current.run(
                until: Date().addingTimeInterval(0.01)
            )
        }

        let scale = 2
        let bitmap = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(pointSize.width) * scale,
                pixelsHigh: Int(pointSize.height) * scale,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
        bitmap.size = pointSize
        host.cacheDisplay(in: host.bounds, to: bitmap)
        return bitmap
    }

    private func shadowPixelCounts(
        in bitmap: NSBitmapImageRep
    ) -> (right: Int, bottom: Int) {
        let shadowDepth = CGFloat(
            ThemeVisualRecipe.default(for: .loud)
                .quotaCard.shadow.depth
        )
        let shadowSampleOffset = shadowDepth * 0.6
        let rightShadowX = Int(
            (
                ThemePanelLayout.width
                    - ThemePanelLayout.contentPadding
                    + shadowSampleOffset
            ) * renderScale
        )
        let bottomShadowY = bitmap.pixelsHigh
            - Int(
                (
                    ThemePanelLayout.contentPadding
                        - shadowSampleOffset
                ) * renderScale
            )
        let right = (0..<bitmap.pixelsHigh)
            .filter {
                isLOUDOutline(
                    bitmap.colorAt(
                        x: rightShadowX,
                        y: $0
                    )
                )
            }
            .count
        let bottom = (0..<bitmap.pixelsWide)
            .filter {
                isLOUDOutline(
                    bitmap.colorAt(
                        x: $0,
                        y: bottomShadowY
                    )
                )
            }
            .count
        return (right, bottom)
    }

    private func shellShadowPixelCounts(
        in bitmap: NSBitmapImageRep,
        theme: AppearanceThemeID
    ) -> (right: Int, bottom: Int) {
        let shadowDepth = CGFloat(
            ThemeVisualRecipe.default(for: theme)
                .panelShell.shadow.depth
        )
        let shadowSampleOffset = shadowDepth * 0.6
        let rightShadowX = Int(
            (
                PanelMetrics.shadowInset
                    + PanelMetrics.cardWidth
                    + shadowSampleOffset
            ) * renderScale
        )
        let bottomShadowY = bitmap.pixelsHigh
            - Int(
                (
                    PanelMetrics.shadowInset
                        - shadowSampleOffset
                ) * renderScale
            )
        let right = (0..<bitmap.pixelsHigh)
            .filter {
                isVisibleShadow(
                    bitmap.colorAt(
                        x: rightShadowX,
                        y: $0
                    )
                )
            }
            .count
        let bottom = (0..<bitmap.pixelsWide)
            .filter {
                isVisibleShadow(
                    bitmap.colorAt(
                        x: $0,
                        y: bottomShadowY
                    )
                )
            }
            .count
        return (right, bottom)
    }

    private func shellCenterColor(
        in bitmap: NSBitmapImageRep
    ) -> NSColor? {
        bitmap.colorAt(
            x: Int(
                (
                    PanelMetrics.shadowInset
                        + PanelMetrics.cardWidth / 2
                ) * renderScale
            ),
            y: Int(
                (
                    PanelMetrics.shadowInset
                        + PanelMetrics.cardHeight / 2
                ) * renderScale
            )
        )
    }

    private func maximumComponentDifference(
        _ first: NSColor,
        _ second: NSColor
    ) -> CGFloat {
        [
            abs(first.redComponent - second.redComponent),
            abs(first.greenComponent - second.greenComponent),
            abs(first.blueComponent - second.blueComponent),
            abs(first.alphaComponent - second.alphaComponent)
        ].max() ?? 0
    }

    private func isVisibleShadow(_ color: NSColor?) -> Bool {
        (color?.alphaComponent ?? 0) > 0.2
    }

    private var renderScale: CGFloat {
        2
    }

    private func isLOUDOutline(_ color: NSColor?) -> Bool {
        guard
            let color = color?.usingColorSpace(.sRGB)
        else {
            return false
        }
        return color.alphaComponent > 0.9
            && color.redComponent < 0.16
            && color.greenComponent < 0.16
            && color.blueComponent < 0.16
    }
}
