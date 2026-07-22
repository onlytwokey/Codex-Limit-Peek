#if DEVELOPER_TOOLS
import Foundation

struct DeveloperPreviewLaunchConfiguration: Equatable, Sendable {
    let exitsWhenWindowCloses: Bool
    let readinessFilePath: String?

    static func resolve(
        arguments: [String]
    ) throws -> DeveloperPreviewLaunchConfiguration? {
        var requested = false
        var readinessFilePath: String?
        let options = Array(arguments.dropFirst())
        var index = 0

        while index < options.count {
            let argument = options[index]
            switch argument {
            case "--developer-preview":
                guard requested == false else {
                    throw DeveloperPreviewLaunchError.duplicateOption(
                        argument
                    )
                }
                requested = true
            case "--developer-preview-ready-file":
                guard readinessFilePath == nil else {
                    throw DeveloperPreviewLaunchError.duplicateOption(
                        argument
                    )
                }
                index += 1
                guard index < options.count else {
                    throw DeveloperPreviewLaunchError.missingValue(
                        argument
                    )
                }
                let path = options[index]
                guard path.hasPrefix("/") else {
                    throw DeveloperPreviewLaunchError.invalidValue(
                        option: argument,
                        value: path
                    )
                }
                readinessFilePath = path
            default:
                if argument.hasPrefix("--developer-") {
                    throw DeveloperPreviewLaunchError.unsupportedOption(
                        argument
                    )
                }
            }
            index += 1
        }

        guard requested else {
            if readinessFilePath != nil {
                throw DeveloperPreviewLaunchError.unsupportedOption(
                    "--developer-preview-ready-file"
                )
            }
            return nil
        }
        return DeveloperPreviewLaunchConfiguration(
            exitsWhenWindowCloses: true,
            readinessFilePath: readinessFilePath
        )
    }
}

enum DeveloperPreviewLaunchError:
    Error,
    Equatable,
    CustomStringConvertible
{
    case duplicateOption(String)
    case unsupportedOption(String)
    case missingValue(String)
    case invalidValue(option: String, value: String)

    var description: String {
        switch self {
        case let .duplicateOption(option):
            "Duplicate developer option \(option)."
        case let .unsupportedOption(option):
            "Unsupported developer option \(option)."
        case let .missingValue(option):
            "Missing value for developer option \(option)."
        case let .invalidValue(option, value):
            "Invalid value \(value) for developer option \(option)."
        }
    }
}
#endif
