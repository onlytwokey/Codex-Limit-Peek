import Foundation

struct StatusItemShadowMetrics: Equatable, Sendable {
    var leading: Double
    var trailing: Double
    var top: Double
    var bottom: Double

    init(
        horizontalOffset: Double,
        verticalOffset: Double,
        blur: Double
    ) {
        let resolvedHorizontalOffset = horizontalOffset.isFinite
            ? horizontalOffset
            : 0
        let resolvedVerticalOffset = verticalOffset.isFinite
            ? verticalOffset
            : 0
        let resolvedBlur = blur.isFinite ? max(blur, 0) : 0

        leading = max(resolvedBlur - resolvedHorizontalOffset, 0)
        trailing = max(resolvedBlur + resolvedHorizontalOffset, 0)
        top = max(resolvedBlur - resolvedVerticalOffset, 0)
        bottom = max(resolvedBlur + resolvedVerticalOffset, 0)
    }

    init(appearance: ResolvedStatusItemAppearance) {
        guard
            appearance.shadowOpacity.isFinite,
            appearance.shadowOpacity > 0
        else {
            self.init(
                horizontalOffset: 0,
                verticalOffset: 0,
                blur: 0
            )
            return
        }
        self.init(
            horizontalOffset: appearance.shadowHorizontalOffset,
            verticalOffset: appearance.shadowVerticalOffset,
            blur: appearance.shadowBlur
        )
    }

    var horizontalBleed: Double {
        leading + trailing
    }

    var verticalBleed: Double {
        top + bottom
    }
}
