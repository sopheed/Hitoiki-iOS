import XCTest
@testable import Hitoiki

final class AdvertisingConfigurationTests: XCTestCase {
    func testProductionRequiresMatchingPublisherAndRealIDs() {
        let app = "ca-app-pub-5120539001782748~7670979521"
        let banner = "ca-app-pub-5120539001782748/1251791274"
        XCTAssertTrue(AdvertisingConfiguration.validProductionIDs(appID: app, bannerID: banner))
        XCTAssertFalse(AdvertisingConfiguration.validProductionIDs(appID: "", bannerID: banner))
        XCTAssertFalse(AdvertisingConfiguration.validProductionIDs(appID: app, bannerID: "$(ADMOB_BANNER_ID)"))
        XCTAssertFalse(AdvertisingConfiguration.validProductionIDs(appID: app, bannerID: "ca-app-pub-1111111111111111/1251791274"))
        XCTAssertFalse(AdvertisingConfiguration.validProductionIDs(appID: AdvertisingConfiguration.testAppID, bannerID: AdvertisingConfiguration.testBannerID))
    }
}
