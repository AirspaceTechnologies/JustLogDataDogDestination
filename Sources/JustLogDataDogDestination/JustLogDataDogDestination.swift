
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
    
    /// An `URLSession` instance that allows you to customize upload behaviour.
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
            let jlLog = try JustLogLogParser.parse(string)
            let log = Log(
                date: jlLog.date,
                status: jlLog.status,
                message: jlLog.message,
                error: nil,
                serviceName: jlLog.serviceName,
                environment: jlLog.environment,
                loggerName: loggerName,
                loggerVersion: Self.dataDogLoggerVersion,
                threadName: "main",
                applicationVersion: jlLog.appVersion,
                userInfo: jlLog.userInfo,
                attributes: jlLog.attributes,
                tags: jlLog.tags
            )
            
            try sendLog(log)
        } catch {
            os_log("Could not decode log: %@", type: .error, String(describing: error))
        }
    }
    
    #if os(tvOS)
    static let ddSource = "tvos"
    #elseif os(iOS)
    static let ddSource = "ios"
    #endif
    
    /// Sends the log using the `urlSession`
    private func sendLog(_ log: Log) throws {
        var url = URLComponents(string: endpoint.url.absoluteString + clientToken)!
        
        url.queryItems = [
            .init(name: "ddsource", value: Self.ddSource),
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
                os_log("Response: %@", type: .info, String(describing: response))
            }
        }.resume()
    }
}
