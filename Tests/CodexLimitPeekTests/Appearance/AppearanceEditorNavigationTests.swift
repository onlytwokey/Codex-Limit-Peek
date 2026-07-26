import Testing
@testable import CodexLimitPeek

struct AppearanceEditorNavigationTests {
    @Test
    func panelNavigationUsesTheApprovedOrderAnchorsAndIdentifiers() {
        let destinations = PanelEditorSectionDestination.allCases

        #expect(
            destinations.map(\.title) == [
                "颜色",
                "文字",
                "几何",
                "阴影"
            ]
        )
        #expect(
            destinations.map(\.scrollTarget) == [
                .panelColorControls,
                .panelControls,
                .panelGeometryControls,
                .panelShadowControls
            ]
        )
        #expect(
            destinations.map(\.accessibilityIdentifier) == [
                "panel-section-navigation-color",
                "panel-section-navigation-text",
                "panel-section-navigation-geometry",
                "panel-section-navigation-shadow"
            ]
        )
    }
}
