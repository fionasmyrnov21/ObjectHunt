import Foundation

enum AppConstants {
    static let appsFlyerDevKey = "2Cir4D6iM3TsgjYJ254bY5"
    static let appsFlyerAppleAppID = "6813802238"

    static var bundleID: String {
        Bundle.main.bundleIdentifier ?? "com.ObjectHuntColorGame"
    }
    static var storeID: String {
        "id\(appsFlyerAppleAppID)"
    }

    static let configEndpoint = "https://objecthuntcolorgame.online/config.php"

    static let privacyPolicyAddress = "https://objecthuntcolorgame.online/privacy-policy.html"

    static let osName = "IOS"
    static let pushTokenPlaceholder = "00000000000000000000"
    static let firebaseProjectID = "152516372933"

    static let gcdRetryDelay: TimeInterval = 1.0
    static let mergeWaitInterval: TimeInterval = 3.0
    static let configRequestTimeouts: [TimeInterval] = [15, 15, 30]
    static let launchLoaderDuration: TimeInterval = 15 + 15 + 30

    static let pushPermissionRetryDelay: TimeInterval = 60 * 60 * 24 * 3

    static let pushDataAddressKey = "url"
}
