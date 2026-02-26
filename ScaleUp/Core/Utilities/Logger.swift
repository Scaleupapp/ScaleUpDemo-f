import os

enum Log {
    static let network = Logger(subsystem: "com.scaleup", category: "Network")
    static let auth = Logger(subsystem: "com.scaleup", category: "Auth")
    static let ui = Logger(subsystem: "com.scaleup", category: "UI")
    static let data = Logger(subsystem: "com.scaleup", category: "Data")
    static let notifications = Logger(subsystem: "com.scaleup", category: "Notifications")
    static let navigation = Logger(subsystem: "com.scaleup", category: "Navigation")
}
