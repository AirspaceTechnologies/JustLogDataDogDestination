
import os
import Foundation
import JustLog

/**
 A datadog destination type for `JustLog`.
 
 ### Usage
 
 ```
 import JustLog
 import JustLogDataDogDestination

 let destinationSender = JustLogDataDogDestination(
     clientToken: "s3cr3t"
     endpoint: .us,
     urlSession: .shared, // optional
     loggerName: Bundle.main.bundleIdentifier
 )

 let logger = Logger.shared
 logger.enableCustomLogging = true
 logger.setupWithCustomLogSender(destinationSender)

 ```
 */
public struct JustLogDataDogDestination: CustomDestinationSender {
    /// The current version that matches DataDog's logger version.
    /// `1.4.1`
    public static let dataDogLoggerVersion = "1.4.1"

    /// Known DataDog mobile endpoints.
    public enum DataDogEndpoint {
        /// For US servers.
        /// ```
        /// https://mobile-http-intake.logs.datadoghq.com/v1/input/
        /// ```
        case us

        /// For EU servers.
        /// ```
        /// https://mobile-http-intake.logs.datadoghq.eu/v1/input/
        /// ```
        case eu

        /// For government
        /// ```
        /// https://logs.browser-intake-ddog-gov.com/v1/input/
        /// ```
        case gov
        
        /// To provide a custom endpoint; suitable for use with mitmproxy to inspect traffic.
        case custom(_ urlString: String)

        /// The URL object, it will crash if `.custom(_:)` is provided with and invalid URL.
        var url: URL {
            switch self {
            case .us: return URL(string: "https://mobile-http-intake.logs.datadoghq.com/v1/input/")!
            case .eu: return URL(string: "https://mobile-http-intake.logs.datadoghq.eu/v1/input/")!
            case .gov: return URL(string: "https://logs.browser-intake-ddog-gov.com/v1/input/")!
            case .custom(let urlString): return URL(string: urlString)!
            }
        }
    }
    
    /// The DataDog client token.
    /// See https://docs.datadoghq.com/account_management/api-app-keys/ for more information
    public let clientToken: String
    
    /// THe DataDog endpoint to use
    public let endpoint: DataDogEndpoint
    
    /// The name of the logger, DataDog's SDK usually sends the applications `bundle ID`.
    public let loggerName: String
    
    public let urlSession: URLSession
    
    /// An optional `JustLog.Logger` instance that can be used to extract additional configuration.
    public weak var logger: JustLog.Logger?
    
    public init(clientToken: String, endpoint: DataDogEndpoint,
                loggerName: String, urlSession: URLSession = .shared,
                logger: JustLog.Logger? = nil, errorHandler: (() -> Void)? = nil) {
        self.clientToken = clientToken
        self.endpoint = endpoint
        self.loggerName = loggerName
        self.urlSession = urlSession
        self.logger = logger
    }
    
    private let encoder = JSONEncoder()
    
    public func log(_ string: String) {
        do {
            guard let jsonPart = getJSONPart(string) else { return }
            guard let data = jsonPart.data(using: .utf8) else { return }
            let decoded = try JSONSerialization.jsonObject(with: data, options: [])
            guard let logObj = decoded as? [String : Any] else { return }
            
            let userInfo = logObj["user_info"] as? [String : Any] ?? [:]
            let metadata = logObj["metadata"] as? [String : Any] ?? [:]
            
            let log = Log(
                date: parseDate(getLogDate(string)),
                status: logStatus(forLogType: logObj["log_type"] as? String),
                message: logObj["message"] as? String ?? string,
                error: nil,
                serviceName: serviceName(metadata, userInfo),
                environment: environment(metadata, userInfo),
                loggerName: loggerName,
                loggerVersion: Self.dataDogLoggerVersion,
                threadName: "main",
                applicationVersion: appVersion(metadata, userInfo),
                userInfo: self.userInfo(metadata, userInfo),
                attributes: logAttributes(metadata, userInfo),
                tags: nil
            )
            
            try sendLog(log)
        } catch {
            os_log("Could not decode log: %@", type: .error, String(describing: error))
        }
    }

    /// Parse the JSOn portion from the `JustLog` formatted log.
    private func getJSONPart(_ string: String) -> String? {
        guard var startIndex = string.firstIndex(of: "-") else { return nil }
        startIndex = string.index(after: startIndex)
        startIndex = string.index(after: startIndex)

        return String(string[startIndex..<string.endIndex]).trimmingCharacters(in: .whitespaces)
    }

    /// Extract the `service` (in DataDog terms) from the userInfo dictionary. If the keys `"service"` or `"app"` are not found then
    /// `"unknown"` is used as service name.
    private func serviceName(_ metadata: [String : Any], _ userInfo: [String : Any]) -> String {
        if let serviceName = userInfo["service"] as? String {
            return serviceName
        }

        if let appName = userInfo["app"] as? String {
            return appName
        }

        return "unknown"
    }
    
    /// Parse the `JustLog` formatted date, if it cannot be parsed an empty string is returned.
    private func getLogDate(_ string: String) -> String {
        let parts = string.split(separator: " ")
        if parts.count < 2 {
            return ""
        }

        return parts[0..<2].joined(separator: " ")
    }
    
    let justLogDateParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "y-MM-dd H:mm:s.sss"
        return formatter
    }()
    
    /// Parse a JustLog date: 2021-03-03 18:25:34.246
    private func parseDate(_ string: String) -> Date {
        justLogDateParser.date(from: string) ?? Date()
    }

    private func logAttributes(_ metadata: [String : Any], _ userInfo: [String : Any]) -> LogAttributes {
        var userAttributes = [AttributeKey : AttributeValue]()
        for (name, value) in userInfo {
            userAttributes[name] = String(describing: value)
        }
        return LogAttributes(userAttributes: userAttributes, internalAttributes: [:])
    }
    
    /// Extracts the app version from the metadat and user info. It loos for the `app_version`, `version` and `logger.appVersionKey` (if set)
    private func appVersion(_ metadata: [String : Any], _ userInfo: [String : Any]) -> String {
        let versionKeys = Set([
            "app_version",
            "version",
            logger?.appVersionKey
        ]).compactMap({$0})
        
        for key in versionKeys {
            if let version = metadata[key] as? String {
                return version
            }

            if let version = userInfo[key] as? String {
                return version
            }
        }

        return "no version info"
    }
    
    /// Extracts the user info.
    /// - TODO: Currently empty user info is returned
    private func userInfo(_ metadata: [String : Any], _ userInfo: [String : Any]) -> UserInfo {
        UserInfo(id: nil, name: nil, email: nil, extraInfo: [:])
    }
    
    /// Extracts the environment.
    /// This will look for keys `"env"` or `"environment"` in the `userInfo`
    private func environment(_ metadata: [String : Any], _ userInfo: [String : Any]) -> String {
        if let env = userInfo["env"] as? String {
            return env
        }
        
        if let env = userInfo["environment"] as? String {
            return env
        }
    
        return "unknown"
    }

    /// Converts a `JustLog` string log type to DataDog's `Log.Status`. Defaults to `.debug`.
    private func logStatus(forLogType logType: String?) -> Log.Status {
        switch logType {
        case "info": return .info
        case "debug": return .debug
        case "warn": return .warn
        case "error": return .error
        case "notice": return .notice
        default: return .debug
        }
    }
    
    /// Sends the log using the `urlSession`
    private func sendLog(_ log: Log) throws {
        var url = URLComponents(string: endpoint.url.absoluteString + clientToken)!
        
        url.queryItems = [
            .init(name: "ddsource", value: "ios"),
            .init(name: "batch_time", value: String(describing: Int(Date().timeIntervalSince1970)))
        ]

        var request = URLRequest(url: url.url!)
        request.httpMethod = "POST"
        request.httpBody = try encoder.encode([log])
        
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(String(describing: request.httpBody?.count ?? 0), forHTTPHeaderField: "Content-Length")
        
        print(String(data: request.httpBody!, encoding: .utf8)!)

        urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                return os_log("Upload error: %@", type: .error, String(describing: error))
            }

            if let data = data {
                os_log("Data: %@", type: .info, String(data: data, encoding: .utf8)!)
            }
            
            if let response = response {
                os_log("Response: %@", type: .info, String(data: data, encoding: .utf8)!)
            }
        }.resume()
    }
}
