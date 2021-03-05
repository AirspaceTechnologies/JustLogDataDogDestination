/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

/// Log levels ordered by their severity, with `.debug` being the least severe and
/// `.critical` being the most severe.
internal enum LogLevel: Int, Codable {
    case debug
    case info
    case notice
    case warn
    case error
    case critical

    // MARK: - `LogLevel` <> `Log.Status` conversion

    internal var asLogStatus: Log.Status {
        switch self {
        case .debug:    return .debug
        case .info:     return .info
        case .notice:   return .notice
        case .warn:     return .warn
        case .error:    return .error
        case .critical: return .critical
        }
    }

    internal init(from logStatus: Log.Status) {
        switch logStatus {
        case .debug:    self = .debug
        case .info:     self = .info
        case .notice:   self = .notice
        case .warn:     self = .warn
        case .error:    self = .error
        case .critical: self = .critical
        }
    }
}
