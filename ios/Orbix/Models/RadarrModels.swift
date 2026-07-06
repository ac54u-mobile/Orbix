import Foundation

// MARK: - Radarr 配置

struct RadarrConfig: Equatable {
    var host: String = ""
    var port: Int = 7878
    var https: Bool = false
    var apiKey: String = ""

    var isConfigured: Bool { !host.isEmpty && !apiKey.isEmpty }
    var baseURL: String { "\(https ? "https" : "http")://\(host):\(port)" }

    static func load() -> RadarrConfig {
        RadarrConfig(
            host: PersistenceService.shared.radarrHost,
            port: PersistenceService.shared.radarrPort,
            https: PersistenceService.shared.radarrHttps,
            apiKey: KeychainService.loadString(forKey: "radarr_api_key") ?? ""
        )
    }

    func save() {
        PersistenceService.shared.radarrHost = host
        PersistenceService.shared.radarrPort = port
        PersistenceService.shared.radarrHttps = https
        KeychainService.saveString(apiKey, forKey: "radarr_api_key")
    }
}

// MARK: - 电影

struct RadarrMovie: Codable, Identifiable, Equatable {
    /// 在 Radarr 片库中的 id，未添加时为 nil 或 0
    var libraryId: Int?
    let title: String
    let year: Int
    let tmdbId: Int
    let overview: String?
    let remotePoster: String?
    let runtime: Int?
    let genres: [String]?
    let ratings: RadarrRatings?
    let hasFile: Bool?
    let images: [RadarrImage]?
    let originalTitle: String?
    let studio: String?

    var id: Int { tmdbId }

    var isInLibrary: Bool { (libraryId ?? 0) > 0 }

    var posterURL: String? {
        if let remotePoster, !remotePoster.isEmpty { return remotePoster }
        return images?.first(where: { $0.coverType == "poster" })?.remoteUrl
    }

    var ratingValue: Double? {
        ratings?.tmdb?.value ?? ratings?.imdb?.value
    }

    enum CodingKeys: String, CodingKey {
        case libraryId = "id"
        case title, year, tmdbId, overview, remotePoster, runtime, genres, ratings, hasFile, images, originalTitle, studio
    }

    static func == (lhs: RadarrMovie, rhs: RadarrMovie) -> Bool {
        lhs.tmdbId == rhs.tmdbId
    }
}

struct RadarrRatings: Codable {
    let tmdb: RadarrRatingValue?
    let imdb: RadarrRatingValue?
}

struct RadarrRatingValue: Codable {
    let value: Double?
}

struct RadarrImage: Codable {
    let coverType: String?
    let remoteUrl: String?
}

// MARK: - 添加电影所需

struct RadarrQualityProfile: Codable, Identifiable {
    let id: Int
    let name: String
}

struct RadarrRootFolder: Codable, Identifiable {
    let id: Int
    let path: String
}

struct RadarrSystemStatus: Codable {
    let version: String?
}

// MARK: - 下载资源（release）

struct RadarrRelease: Codable, Identifiable {
    let guid: String
    let title: String
    let size: Int64?
    let indexer: String?
    let seeders: Int?
    let leechers: Int?
    let quality: RadarrReleaseQuality?
    let magnetUrl: String?
    let downloadUrl: String?
    let rejected: Bool?

    var id: String { guid }

    /// 优先磁力链接，其次种子文件链接，交给 qBittorrent 均可
    var downloadLink: String? {
        if let magnetUrl, !magnetUrl.isEmpty { return magnetUrl }
        if let downloadUrl, !downloadUrl.isEmpty { return downloadUrl }
        return nil
    }

    var qualityName: String? { quality?.quality?.name }
}

struct RadarrReleaseQuality: Codable {
    let quality: RadarrReleaseQualityInner?
}

struct RadarrReleaseQualityInner: Codable {
    let name: String?
}
