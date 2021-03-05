# JustLogDataDogDestination

A logging destination for use with the [JustLog](https://github.com/justeat/JustLog) logging library. It support iOS and tvOS 
platforms.

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

## Important notes

This is **NOT A FULL** integration with datadog, , it specifically leaves out the following information by hardcoding or 
commenting out from the original DD source files:

  * Carrier Network Info
  * Reachibility Network Information
  * Any RUM properties
  * Span or Spannable properties
  * Custom date providers

