import XCTest
@testable import ProxyMac

@MainActor
final class ProxyCoreControllerTests: XCTestCase {
    func testStartsInStoppedState() {
        let controller = ProxyCoreController(controlClient: FakeControlClient())
        XCTAssertEqual(controller.state, .stopped)
    }
}
