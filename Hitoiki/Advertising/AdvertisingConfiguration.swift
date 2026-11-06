import Foundation

enum AdvertisingConfiguration {
    static let testAppID = "ca-app-pub-3940256099942544~1458002511"
    static let testBannerID = "ca-app-pub-3940256099942544/2934735716"

    static var bannerID: String {
        #if DEBUG
        return testBannerID
        #else
        return Bundle.main.object(forInfoDictionaryKey: "BannerAdUnitIdentifier") as? String ?? ""
        #endif
    }

    static var childDirected: Bool {
        Bundle.main.object(forInfoDictionaryKey: "ChildDirectedAdvertising") as? Bool ?? false
    }

    static var layoutPreview: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--ad-layout-preview")
        #else
        return false
        #endif
    }

    static var enabled: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        #if DEBUG
        if arguments.contains("--ad-testing") { return true }
        if layoutPreview || arguments.contains(where: {
            ["-ui-testing", "--uitest", "--wordpet-ui-testing", "--store-screenshots"].contains($0)
        }) { return false }
        return true
        #else
        return validProductionIDs(
            appID: Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String ?? "",
            bannerID: bannerID
        )
        #endif
    }

    // An ID from another AdMob publisher, an unresolved build setting, or a demo ID
    // must never silently become the production configuration.
    static func validProductionIDs(appID: String, bannerID: String) -> Bool {
        let appPattern = #"^ca-app-pub-(\d{16})~\d{10}$"#
        let bannerPattern = #"^ca-app-pub-(\d{16})/\d{10}$"#
        guard appID.range(of: appPattern, options: .regularExpression) != nil,
              bannerID.range(of: bannerPattern, options: .regularExpression) != nil,
              !appID.contains("3940256099942544"), !bannerID.contains("3940256099942544") else { return false }
        return appID.prefix(27) == bannerID.prefix(27)
    }
}
