#if DEVELOPER_TOOLS
import Testing
@testable import CodexLimitPeek

struct DeveloperPreviewLaunchConfigurationTests {
    @Test
    func ordinaryLaunchDoesNotRequestDeveloperPreview() throws {
        let configuration = try DeveloperPreviewLaunchConfiguration.resolve(
            arguments: ["CodexLimitPeek"]
        )

        #expect(configuration == nil)
    }

    @Test
    func developerArgumentRequestsAutomaticPreview() throws {
        let resolved = try DeveloperPreviewLaunchConfiguration.resolve(
            arguments: ["CodexLimitPeek", "--developer-preview"]
        )
        let configuration = try #require(resolved)

        #expect(configuration.exitsWhenWindowCloses)
        #expect(configuration.readinessFilePath == nil)
    }

    @Test
    func readinessFileIsAcceptedOnlyWithDeveloperPreview() throws {
        let resolved = try DeveloperPreviewLaunchConfiguration.resolve(
            arguments: [
                "CodexLimitPeek",
                "--developer-preview",
                "--developer-preview-ready-file",
                "/private/tmp/codex-limit-peek-ready"
            ]
        )
        let configuration = try #require(resolved)

        #expect(
            configuration.readinessFilePath
                == "/private/tmp/codex-limit-peek-ready"
        )
    }

    @Test
    func unrelatedArgumentsAreIgnored() throws {
        let configuration = try DeveloperPreviewLaunchConfiguration.resolve(
            arguments: ["CodexLimitPeek", "--some-system-argument"]
        )

        #expect(configuration == nil)
    }

    @Test(arguments: [
        ["CodexLimitPeek", "--developer-preview", "--developer-preview"],
        ["CodexLimitPeek", "--developer-unknown"],
        ["CodexLimitPeek", "--developer-preview-ready-file"],
        [
            "CodexLimitPeek",
            "--developer-preview-ready-file",
            "/private/tmp/codex-limit-peek-ready"
        ],
        [
            "CodexLimitPeek",
            "--developer-preview",
            "--developer-preview-ready-file",
            "relative/path"
        ]
    ])
    func duplicateOrUnknownDeveloperArgumentFails(arguments: [String]) {
        #expect(throws: DeveloperPreviewLaunchError.self) {
            try DeveloperPreviewLaunchConfiguration.resolve(
                arguments: arguments
            )
        }
    }
}
#endif
