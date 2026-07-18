import AppKit
import SwiftUI

enum PanelMetrics {
    static let cardWidth = ThemePanelLayout.width
    static let cardHeight = ThemePanelLayout.height
    static let shadowInset = ThemePanelLayout.shadowSafetyInset
    static let shadowWidth: CGFloat = cardWidth + shadowInset * 2
    static let shadowHeight: CGFloat = cardHeight + shadowInset * 2
    static let verticalGap: CGFloat = 14
    static let screenPadding: CGFloat = 8

    static func contentFrame(
        relativeTo anchorRect: NSRect,
        within visibleFrame: NSRect,
        shadowInsets: EdgeInsets
    ) -> NSRect {
        let proposedX = anchorRect.midX - cardWidth / 2
        let minimumX = visibleFrame.minX
            + screenPadding
            + shadowInsets.leading
        let maximumX = max(
            minimumX,
            visibleFrame.maxX
                - cardWidth
                - screenPadding
                - shadowInsets.trailing
        )
        let x = min(
            max(proposedX, minimumX),
            maximumX
        )
        let minimumY = visibleFrame.minY
            + screenPadding
            + shadowInsets.bottom
        let maximumY = min(
            anchorRect.minY - cardHeight - verticalGap,
            visibleFrame.maxY
                - cardHeight
                - screenPadding
                - shadowInsets.top
        )
        let y = max(minimumY, maximumY)
        return NSRect(
            x: x,
            y: y,
            width: cardWidth,
            height: cardHeight
        )
    }

    static func shadowFrame(
        around contentFrame: NSRect
    ) -> NSRect {
        contentFrame.insetBy(dx: -shadowInset, dy: -shadowInset)
    }

    static func visualFrame(
        around contentFrame: NSRect,
        shadowInsets: EdgeInsets
    ) -> NSRect {
        NSRect(
            x: contentFrame.minX - shadowInsets.leading,
            y: contentFrame.minY - shadowInsets.bottom,
            width: contentFrame.width
                + shadowInsets.leading
                + shadowInsets.trailing,
            height: contentFrame.height
                + shadowInsets.top
                + shadowInsets.bottom
        )
    }
}
