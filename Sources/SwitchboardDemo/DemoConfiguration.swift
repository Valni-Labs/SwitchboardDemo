import Foundation
import Switchboard

struct DemoConfiguration {
    let baseURL: URL

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
        return DemoConfiguration(baseURL: baseURL)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
