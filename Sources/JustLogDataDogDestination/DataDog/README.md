#  DataDog iOS SDK

Most of the classes in this directory are a butchered version of the official DataDog iOS SDK, which can be found
here:

  * https://github.com/DataDog/dd-sdk-ios/releases/tag/1.4.1
  
  
The classes are used to encode the log objects it specifically leaves out the following information by hardcoding or 
masking out:

  * Carrier Network Info
  * Reachibility Network Information
  * Any RUM properties
  * Span or Spannable properties

