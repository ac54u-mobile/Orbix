import Foundation

final class PersistenceService {
    static let shared = PersistenceService()
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Bookmarks
    func loadBookmarks() -> [String] {
        defaults.stringArray(forKey: "search_bookmarks") ?? []
    }

    func saveBookmarks(_ bookmarks: [String]) {
        defaults.set(bookmarks, forKey: "search_bookmarks")
    }

    func toggleBookmark(_ code: String) -> Bool {
        var bookmarks = loadBookmarks()
        if bookmarks.contains(code) {
            bookmarks.removeAll { $0 == code }
            saveBookmarks(bookmarks)
            return false
        } else {
            bookmarks.append(code)
            saveBookmarks(bookmarks)
            return true
        }
    }

    func isBookmarked(_ code: String) -> Bool {
        loadBookmarks().contains(code)
    }

    // MARK: - Update Cache
    var lastUpdateCheckTime: Date? {
        get { defaults.object(forKey: "last_update_check") as? Date }
        set { defaults.set(newValue, forKey: "last_update_check") }
    }

    var cachedUpdateTag: String? {
        get { defaults.string(forKey: "cached_update_tag") }
        set { defaults.set(newValue, forKey: "cached_update_tag") }
    }

    // MARK: - App Lock
    var appLockEnabled: Bool {
        get { defaults.bool(forKey: "app_lock_face_id") }
        set { defaults.set(newValue, forKey: "app_lock_face_id") }
    }

    // MARK: - Radarr
    var radarrHost: String {
        get { defaults.string(forKey: "radarr_host") ?? "" }
        set { defaults.set(newValue, forKey: "radarr_host") }
    }

    var radarrPort: Int {
        get { defaults.object(forKey: "radarr_port") as? Int ?? 7878 }
        set { defaults.set(newValue, forKey: "radarr_port") }
    }

    var radarrHttps: Bool {
        get { defaults.bool(forKey: "radarr_https") }
        set { defaults.set(newValue, forKey: "radarr_https") }
    }

    // MARK: - Subtitle Service
    var subtitleHost: String {
        get { defaults.string(forKey: "subtitle_host") ?? "" }
        set { defaults.set(newValue, forKey: "subtitle_host") }
    }

    var subtitlePort: Int {
        get { defaults.object(forKey: "subtitle_port") as? Int ?? 8788 }
        set { defaults.set(newValue, forKey: "subtitle_port") }
    }

    /// 字幕任务 id → 种子 hash（用于给种子卡片打"已翻译字幕"标记）
    var subtitleJobMap: [String: String] {
        get { defaults.dictionary(forKey: "subtitle_job_map") as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: "subtitle_job_map") }
    }

    var subtitledHashes: [String] {
        get { defaults.stringArray(forKey: "subtitled_hashes") ?? [] }
        set { defaults.set(newValue, forKey: "subtitled_hashes") }
    }
}
