import XCTest
@testable import Orbix

final class TorrentStatusTests: XCTestCase {
    func testStatusColor_forDownloading_returnsAccent() {
        XCTAssertEqual(TorrentStatus.downloading.statusColor, AppColors.accentPrimary)
    }

    func testStatusColor_forUploading_returnsSuccess() {
        XCTAssertEqual(TorrentStatus.uploading.statusColor, AppColors.success)
    }

    func testStatusColor_forError_returnsDanger() {
        XCTAssertEqual(TorrentStatus.error.statusColor, AppColors.danger)
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
        XCTAssertEqual(t.progressColor, AppColors.danger)
    }

    func testProgressColor_whenCompleted_returnsSuccess() {
        let t = TorrentInfo(name: "test", state: "uploading", progress: 1.0)
        XCTAssertEqual(t.progressColor, AppColors.success)
    }

    func testProgressColor_default_returnsAccent() {
        let t = TorrentInfo(name: "test", state: "downloading", progress: 0.5)
        XCTAssertEqual(t.progressColor, AppColors.accentPrimary)
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
        XCTAssertEqual(t.statusColor, AppColors.success)
    }

    func testStatusColor_disabled_returnsDanger() {
        let t = TorrentTracker(url: "udp://test", status: 0, tier: 0, numPeers: 0, numSeeds: 0, numLeeches: 0, numDownloaded: 0, msg: "")
        XCTAssertEqual(t.statusColor, AppColors.danger)
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
