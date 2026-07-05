import Foundation
import Switchboard

struct DemoConfiguration {
    let apiKey: String?
    let baseURL: URL
    let endUserID: String?

    enum ConfigurationError: LocalizedError {
        case invalidBaseURL(String)

        var errorDescription: String? {
            switch self {
            case .invalidBaseURL(let rawValue):
                "SWITCHBOARD_BASE_URL is not a valid URL: \(rawValue)"
            }
        }
    }

    static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) throws -> DemoConfiguration {
        let baseURL: URL
        if let rawBaseURL = nonEmpty(environment["SWITCHBOARD_BASE_URL"]) {
            guard let parsedBaseURL = URL(string: rawBaseURL) else {
                throw ConfigurationError.invalidBaseURL(rawBaseURL)
            }
            baseURL = parsedBaseURL
        } else {
            baseURL = Client.defaultBaseURL
        }
        return DemoConfiguration(
            apiKey: nonEmpty(environment["SWITCHBOARD_API_KEY"]),
            baseURL: baseURL,
            endUserID: nonEmpty(environment["SWITCHBOARD_END_USER_ID"])
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
