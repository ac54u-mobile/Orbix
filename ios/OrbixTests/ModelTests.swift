import XCTest
import SwiftUI
@testable import Orbix

final class TorrentStatusTests: XCTestCase {
    func testStatusColor_forDownloading_returnsAccent() {
        XCTAssertEqual(TorrentStatus.downloading.statusColor, Color.blue)
    }

    func testStatusColor_forUploading_returnsSuccess() {
        XCTAssertEqual(TorrentStatus.uploading.statusColor, Color.green)
    }

    func testStatusColor_forError_returnsDanger() {
        XCTAssertEqual(TorrentStatus.error.statusColor, Color.red)
    }

    func testIsActive_forDownloading_returnsTrue() {
        XCTAssertTrue(TorrentStatus.downloading.isActive)
    }

    func testIsActive_forPaused_returnsFalse() {
        XCTAssertFalse(TorrentStatus.pausedDL.isActive)
    }

    func testIsPaused_forStoppedDL_returnsTrue() {
        XCTAssertTrue(TorrentStatus.stoppedDL.isPaused)
    }
}

final class TorrentInfoTests: XCTestCase {
    func testProgressColor_whenError_returnsDanger() {
        let t = TorrentInfo(name: "test", state: "error")
        XCTAssertEqual(t.progressColor, Color.red)
    }

    func testProgressColor_whenCompleted_returnsSuccess() {
        let t = TorrentInfo(name: "test", state: "uploading", progress: 1.0)
        XCTAssertEqual(t.progressColor, Color.green)
    }

    func testProgressColor_default_returnsAccent() {
        let t = TorrentInfo(name: "test", state: "downloading", progress: 0.5)
        XCTAssertEqual(t.progressColor, Color.blue)
    }

    func testStatusBadge_fromRawValue() {
        let t = TorrentInfo(name: "test", state: "downloading")
        XCTAssertEqual(t.statusBadge, .downloading)
    }

    func testIsCompleted_whenProgressAtOne_returnsTrue() {
        let t = TorrentInfo(name: "test", state: "uploading", progress: 1.0)
        XCTAssertTrue(t.isCompleted)
    }
}

final class TrackerStatusTests: XCTestCase {
    func testStatusColor_working_returnsSuccess() {
        let t = TorrentTracker(url: "udp://test", status: 2, tier: 0, numPeers: 0, numSeeds: 0, numLeeches: 0, numDownloaded: 0, msg: "")
        XCTAssertEqual(t.statusColor, Color.green)
    }

    func testStatusColor_disabled_returnsDanger() {
        let t = TorrentTracker(url: "udp://test", status: 0, tier: 0, numPeers: 0, numSeeds: 0, numLeeches: 0, numDownloaded: 0, msg: "")
        XCTAssertEqual(t.statusColor, Color.red)
    }
}

final class ServerConfigTests: XCTestCase {
    func testServerConfigURL() {
        let config = ServerConfig(name: "Test", host: "192.168.1.1", port: 8080, username: "admin", password: "pass", https: false)
        XCTAssertEqual(config.url, "http://192.168.1.1:8080")
    }

    func testServerConfigURL_https() {
        let config = ServerConfig(name: "Test", host: "nas.local", port: 443, username: "admin", password: "pass", https: true)
        XCTAssertEqual(config.url, "https://nas.local:443")
    }
}
