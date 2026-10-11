import XCTest
import SwiftUI
@testable import GalaxyFit3Companion

final class ConnectionStateTests: XCTestCase {

    func testComputedPropertiesForConnectedState() {
        let state = ConnectionState.connected
        XCTAssertTrue(state.isConnected)
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(state.statusText, "Connected")
        XCTAssertEqual(state.statusIcon, "checkmark.circle.fill")
    }

    func testComputedPropertiesForSyncingState() {
        let state = ConnectionState.syncing
        XCTAssertTrue(state.isConnected)
        XCTAssertTrue(state.isActive)
        XCTAssertEqual(state.statusText, "Syncing Data...")
        XCTAssertEqual(state.statusIcon, "arrow.triangle.2.circlepath.circle.fill")
    }

    func testComputedPropertiesForScanningState() {
        let state = ConnectionState.scanning
        XCTAssertFalse(state.isConnected)
        XCTAssertTrue(state.isActive)
        XCTAssertEqual(state.statusText, "Scanning for Galaxy Fit3...")
        XCTAssertEqual(state.statusIcon, "dot.radiowaves.left.and.right")
    }

    func testComputedPropertiesForConnectingState() {
        let state = ConnectionState.connecting
        XCTAssertFalse(state.isConnected)
        XCTAssertTrue(state.isActive)
        XCTAssertEqual(state.statusText, "Connecting...")
    }

    func testComputedPropertiesForDiscoveringState() {
        let state = ConnectionState.discovering
        XCTAssertFalse(state.isConnected)
        XCTAssertTrue(state.isActive)
        XCTAssertEqual(state.statusText, "Discovering Services...")
    }

    func testComputedPropertiesForAuthenticatingState() {
        let state = ConnectionState.authenticating
        XCTAssertFalse(state.isConnected)
        XCTAssertTrue(state.isActive)
        XCTAssertEqual(state.statusText, "Authenticating...")
    }

    func testComputedPropertiesForDisconnectedState() {
        let state = ConnectionState.disconnected
        XCTAssertFalse(state.isConnected)
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(state.statusText, "Disconnected")
    }

    func testComputedPropertiesForErrorState() {
        let state = ConnectionState.error("Bluetooth powered off")
        XCTAssertFalse(state.isConnected)
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(state.statusText, "Error: Bluetooth powered off")
        XCTAssertEqual(state.statusIcon, "exclamationmark.triangle.fill")
    }

    func testStateEquality() {
        XCTAssertEqual(ConnectionState.idle, ConnectionState.idle)
        XCTAssertEqual(ConnectionState.error("Timeout"), ConnectionState.error("Timeout"))
        XCTAssertNotEqual(ConnectionState.error("Timeout"), ConnectionState.error("Unreachable"))
        XCTAssertNotEqual(ConnectionState.connected, ConnectionState.disconnected)
    }
}
