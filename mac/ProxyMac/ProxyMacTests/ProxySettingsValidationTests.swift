import XCTest
@testable import ProxyMac

final class ProxySettingsValidationTests: XCTestCase {
    func testPortValidationRejectsOutOfRange() {
        XCTAssertNotNil(ProxySettingsValidation.portError(0))
        XCTAssertNotNil(ProxySettingsValidation.portError(70000))
    }

    func testPortValidationAcceptsValid() {
        XCTAssertNil(ProxySettingsValidation.portError(1))
        XCTAssertNil(ProxySettingsValidation.portError(65535))
    }

    func testControlAddressValidationRejectsMissingPort() {
        XCTAssertNotNil(ProxySettingsValidation.controlAddressError("localhost"))
        XCTAssertNotNil(ProxySettingsValidation.controlAddressError(""))
    }

    func testControlAddressValidationRejectsInvalidPort() {
        XCTAssertNotNil(ProxySettingsValidation.controlAddressError("localhost:0"))
        XCTAssertNotNil(ProxySettingsValidation.controlAddressError("localhost:70000"))
        XCTAssertNotNil(ProxySettingsValidation.controlAddressError("localhost:abc"))
    }

    func testControlAddressValidationAcceptsValid() {
        XCTAssertNil(ProxySettingsValidation.controlAddressError("127.0.0.1:5959"))
        XCTAssertNil(ProxySettingsValidation.controlAddressError("localhost:8080"))
    }
}
