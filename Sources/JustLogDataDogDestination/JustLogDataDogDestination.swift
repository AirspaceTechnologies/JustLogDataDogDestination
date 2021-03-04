
import os
import Foundation
import JustLog

public struct JustLogDataDogDestination: CustomDestinationSender {

    public static let dataDogLoggerVersion = "1.4.1"
    
    public enum DataDogEndpoint {
        case us
        case eu
        case gov
        case custom(_ urlString: String)

        var url: URL {
            switch self {
            case .us: return URL(string: "https://mobile-http-intake.logs.datadoghq.com/v1/input/")!
            case .eu: return URL(string: "https://mobile-http-intake.logs.datadoghq.eu/v1/input/")!
            case .gov: return URL(string: "https://logs.browser-intake-ddog-gov.com/v1/input/")!
            case .custom(let urlString): return URL(string: urlString)!
            }
        }
    }
    
    public let clientToken: String
    public let endpoint: DataDogEndpoint
    public let urlSession: URLSession = .shared
    public let loggerName: String
    public weak var logger: JustLog.Logger?
    
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
    
    private func getJSONPart(_ string: String) -> String? {
        guard var startIndex = string.firstIndex(of: "-") else { return nil }
        startIndex = string.index(after: startIndex)
        startIndex = string.index(after: startIndex)

        return String(string[startIndex..<string.endIndex]).trimmingCharacters(in: .whitespaces)
    }
    
    private func serviceName(_ metadata: [String : Any], _ userInfo: [String : Any]) -> String {
        if let serviceName = userInfo["service"] as? String {
            return serviceName
        }

        if let appName = userInfo["app"] as? String {
            return appName
        }

        return "unknown"
    }
    
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
    
    private func userInfo(_ metadata: [String : Any], _ userInfo: [String : Any]) -> UserInfo {
        UserInfo(id: nil, name: nil, email: nil, extraInfo: [:])
    }
    
    private func environment(_ metadata: [String : Any], _ userInfo: [String : Any]) -> String {
        if let env = userInfo["env"] as? String {
            return env
        }
        
        if let env = userInfo["environment"] as? String {
            return env
        }
    
        return "unknown"
    }

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

        let task = urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                return os_log("Upload error: %2", type: .error, String(describing: error))
            }

            if let data = data {
                print("Data", String(data: data, encoding: .utf8)!)
            }
            
            if let response = response {
                print("Response", response)
            }
        }

        task.resume()
    }
}
