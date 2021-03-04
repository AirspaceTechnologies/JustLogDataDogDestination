# JustLogDataDogDestination

A logging destination for use with the [JustLog](https://github.com/justeat/JustLog) logging library.

## Usage

```swift
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

logger.debug("Sending logs!!")
logger.forceSend()
```
