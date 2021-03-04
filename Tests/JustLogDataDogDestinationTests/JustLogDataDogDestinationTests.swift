import XCTest
@testable import JustLogDataDogDestination

import JustLog

final class JustLogDataDogDestinationTests: XCTestCase {
    func test_force_send() {
        let sender = JustLogDataDogDestination(
            clientToken: "pub7100613f185abd9cc3f41c458bb98cc2",
            endpoint: .custom("http://192.168.0.111:8080/v1/input/"),
            urlSession: .shared,
            loggerName: self.name
        )

        Logger.shared.enableLogstashLogging = false
        Logger.shared.enableCustomLogging = true
        Logger.shared.setupWithCustomLogSender(sender)
        Logger.shared.defaultUserInfo = [
            "service": "justlog-plugin",
            "version": "2.27.0"
        ]
        
        Logger.shared.debug("SAMPLE DEBUG SEND", userInfo: [
            "a": 99
        ])
        
        let sendExp = XCTestExpectation(description: "Force Send logs")
        Logger.shared.forceSend { error in
            guard error == nil else {
                return XCTFail(String(describing: error!))
            }
            
            sendExp.fulfill()
        }
        
        wait(for: [sendExp], timeout: 10)
    }

    static var allTests = [
        ("test_force_send", test_force_send),
    ]
}
