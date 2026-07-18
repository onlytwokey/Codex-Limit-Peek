import AppKit

final class CompactStatusItemView: NSView {
    var onClick: (() -> Void)?

    private var title = ""
    private var weeklyTitle: String?
    private var resolvedAppearance = AppearanceResolver.status(
        profile: .default(for: .loud),
        primaryRemainingPercent: 100,
        weeklyRemainingPercent: 100,
        isUnavailable: false,
        showsFailurePattern: false
    )
    private var showsFailurePattern = false

    private var horizontalPadding: CGFloat {
        CGFloat(resolvedAppearance.horizontalPadding)
    }

    func update(
        title: String,
        weeklyTitle: String?,
        appearance: ResolvedStatusItemAppearance,
        showsFailurePattern: Bool,
        tooltip: String,
        statusBarThickness: CGFloat = NSStatusBar.system.thickness
    ) {
        self.title = title
        self.weeklyTitle = weeklyTitle
        resolvedAppearance = appearance
        self.showsFailurePattern = showsFailurePattern
        self.toolTip = tooltip
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Codex Limit Peek")
        setAccessibilityValue(
            [title, weeklyTitle]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " | ")
        )
        setAccessibilityHelp(tooltip)

        let chromeWidth = CGFloat(
            appearance.outlineWidth * 2
                + appearance.shadowDepth
                + appearance.shadowBlur * 2
        )
        let width = ceil(
            attributedTitle.size().width
                + horizontalPadding * 2
                + chromeWidth
        )
        frame = NSRect(
            x: 0,
            y: 0,
            width: width,
            height: statusBarThickness
        )
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let size = attributedTitle.size()
        let outlineWidth = CGFloat(resolvedAppearance.outlineWidth)
        let shadowDepth = CGFloat(resolvedAppearance.shadowDepth)
        let shadowBlur = CGFloat(resolvedAppearance.shadowBlur)
        let cornerRadius = CGFloat(resolvedAppearance.cornerRadius)
        let availableHeight = max(
            8,
            bounds.height - shadowDepth - shadowBlur * 2 - 1
        )
        let tagHeight = min(
            CGFloat(resolvedAppearance.tagHeight),
            availableHeight
        )
        let drawableHeight = max(1, bounds.height - shadowBlur * 2)
        let tagRect = NSRect(
            x: shadowBlur + outlineWidth / 2,
            y: shadowBlur
                + floor(
                    (drawableHeight - tagHeight + shadowDepth) / 2
                ),
            width: max(
                1,
                bounds.width
                    - shadowDepth
                    - outlineWidth
                    - shadowBlur * 2
            ),
            height: tagHeight
        )
        let tagPath = NSBezierPath(
            roundedRect: tagRect,
            xRadius: min(cornerRadius, tagHeight / 2),
            yRadius: min(cornerRadius, tagHeight / 2)
        )

        NSGraphicsContext.saveGraphicsState()
        if shadowDepth > 0 || shadowBlur > 0 {
            let shadow = NSShadow()
            shadow.shadowColor = resolvedAppearance.outlineColor.nsColor
                .withAlphaComponent(
                    CGFloat(resolvedAppearance.shadowOpacity)
                )
            shadow.shadowOffset = NSSize(width: shadowDepth, height: -shadowDepth)
            shadow.shadowBlurRadius = shadowBlur
            shadow.set()
        }
        let baseFill = showsFailurePattern
            ? resolvedAppearance.unavailableBaseColor.nsColor
            : resolvedAppearance.fillColor.nsColor
        baseFill.setFill()
        tagPath.fill()
        NSGraphicsContext.restoreGraphicsState()

        if showsFailurePattern {
            drawFailurePattern(in: tagRect, clippedBy: tagPath)
        }

        if outlineWidth > 0 {
            resolvedAppearance.outlineColor.nsColor.setStroke()
            tagPath.lineWidth = outlineWidth
            tagPath.stroke()
        }

        let rect = NSRect(
            x: shadowBlur + horizontalPadding + outlineWidth,
            y: floor(tagRect.midY - size.height / 2),
            width: size.width,
            height: size.height
        )
        attributedTitle.draw(in: rect)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func rightMouseDown(with event: NSEvent) {
        onClick?()
    }

    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }

    private func drawFailurePattern(in tagRect: NSRect, clippedBy tagPath: NSBezierPath) {
        NSGraphicsContext.saveGraphicsState()
        tagPath.addClip()
        resolvedAppearance.unavailableBaseColor.nsColor.setFill()
        tagPath.fill()
        resolvedAppearance.unavailableStripeColor.nsColor
            .withAlphaComponent(0.78)
            .setStroke()
        for x in stride(from: tagRect.minX - tagRect.height, through: tagRect.maxX, by: 7) {
            let stripe = NSBezierPath()
            stripe.lineWidth = 2
            stripe.move(to: NSPoint(x: x, y: tagRect.minY))
            stripe.line(to: NSPoint(x: x + tagRect.height, y: tagRect.maxY))
            stripe.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private var attributedTitle: NSAttributedString {
        let font = resolvedStatusFont
        let primaryAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: resolvedAppearance.primaryTextColor.nsColor,
            .kern: -0.2
        ]
        let renderedTitle = NSMutableAttributedString(
            string: title,
            attributes: primaryAttributes
        )

        if let weeklyTitle, !weeklyTitle.isEmpty {
            renderedTitle.append(NSAttributedString(string: " | ", attributes: primaryAttributes))
            renderedTitle.append(
                NSAttributedString(
                    string: weeklyTitle,
                    attributes: [
                        .font: font,
                        .foregroundColor: resolvedAppearance.weeklyTextColor.nsColor,
                        .kern: -0.2
                    ]
                )
            )
        }

        return renderedTitle
    }

    private var resolvedStatusFont: NSFont {
        let size = CGFloat(resolvedAppearance.fontSize)
        let weight: NSFont.Weight = switch resolvedAppearance.fontWeight {
        case .semibold:
            .semibold
        case .bold:
            .bold
        case .heavy:
            .heavy
        case .black:
            .black
        }

        switch resolvedAppearance.fontFamily {
        case .monospaced:
            return NSFont.monospacedSystemFont(
                ofSize: size,
                weight: weight
            )
        case .rounded:
            let base = NSFont.systemFont(ofSize: size, weight: weight)
            guard
                let descriptor = base.fontDescriptor.withDesign(.rounded),
                let rounded = NSFont(
                    descriptor: descriptor,
                    size: size
                )
            else {
                return base
            }
            return rounded
        case .system:
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
    }
}
