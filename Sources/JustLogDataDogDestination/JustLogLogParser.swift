//
//  JustLogLogParser.swift
//  JustLogDataDogDestination
//
//  Created by Tristian Azuara on 3/4/21.
//

import Foundation

/// Alias to avoid type conflicts with `DDLog` and `Log` types.
typealias JLDDLog = Log

/**
 A class that parses `JustLog` string logs.
 
 ```
 
 ```
 */
public struct JustLogLogParser {
    
    public enum Error: Swift.Error {
        case missingDate(_ string: String)
        case missingJSON(_ string: String)
        case corruptData(_ string: String)
        case malformedJSON(_ string: String)
    }
    
    public struct Options {
        var appVersionKey: String?
    }
    
    public struct Log {
        var date: Date
        var status: JLDDLog.Status
        var serviceName: String
        var environment: String
        var appVersion: String
        var attributes: LogAttributes
        var userInfo: UserInfo
        var message: String
        var tags: [String] = []
    }

    let options: Options?
    
    /// Create a parser and parse the given string.
    public static func parse(_ string: String, options: Options? = nil) throws -> Log {
        let parser = Self(options: options)
        return try parser.parse(string)
    }

    /// Parse the given string.
    public func parse(_ string: String) throws -> Log {
        guard let date = parseDate(string) else {
            throw Error.missingDate(string)
        }

        guard let jsonPart = getJSONPart(string) else {
            throw Error.missingJSON(string)
        }
        
        guard let data = jsonPart.data(using: .utf8) else { throw Error.corruptData(jsonPart) }
        let decoded = try JSONSerialization.jsonObject(with: data, options: [])
        guard let logObj = decoded as? [String : Any] else { throw Error.corruptData(jsonPart) }
        
        let userInfo = logObj["user_info"] as? [String : Any] ?? [:]
        let metadata = logObj["metadata"] as? [String : Any] ?? [:]

        return Log(
            date: date,
            status: logStatus(forLogType: logObj["log_type"] as? String),
            serviceName: serviceName(metadata, userInfo),
            environment: environment(metadata, userInfo),
            appVersion: appVersion(metadata, userInfo),
            attributes: logAttributes(metadata, userInfo),
            userInfo: self.userInfo(metadata, userInfo),
            message: logObj["message"] as? String ?? string
        )
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
    private func getDatePart(_ string: String, spaceCount: Int) -> String {
        let parts = string.split(separator: " ")
        if parts.count < spaceCount {
            return ""
        }

        return parts[0..<spaceCount].joined(separator: " ")
    }

    let justLogDateParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd H:mm:s.sss"
        return formatter
    }()
    
    let justLogTimeParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm:s.sss"
        return formatter
    }()
    
    private func parseDate(_ string: String) -> Date? {
        if let date = justLogDateParser.date(from: getDatePart(string, spaceCount: 2)) {
            return date
        }
        
        if let time = justLogTimeParser.date(from: getDatePart(string, spaceCount: 1)) {
            return time
        }
        
        return nil
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
            options?.appVersionKey
        ]).compactMap({$0})
        
        for key in versionKeys {
            if let version = metadata[key] as? String {
                return version
            }

            if let version = userInfo[key] as? String {
                return version
            }
        }

        return "unknown"
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
    private func logStatus(forLogType logType: String?) -> JLDDLog.Status {
        switch logType {
        case "info": return .info
        case "debug": return .debug
        case "warn": return .warn
        case "error": return .error
        case "notice": return .notice
        default: return .debug
        }
    }
}
