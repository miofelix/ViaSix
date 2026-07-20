import ServiceManagement
import XCTest

@testable import ViaSixApp

final class TunHelperInstallerTests: XCTestCase {
    func testMapsEveryKnownServiceManagementStatus() {
        XCTAssertEqual(TunHelperInstaller.map(.notRegistered), .notRegistered)
        XCTAssertEqual(TunHelperInstaller.map(.enabled), .enabled)
        XCTAssertEqual(TunHelperInstaller.map(.requiresApproval), .requiresApproval)
        XCTAssertEqual(TunHelperInstaller.map(.notFound), .notFound)
    }
}
