import Foundation

actor RadarrApi {
    static let shared = RadarrApi()
    private init() {}

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 15
        return URLSession(configuration: cfg)
    }()

    enum RadarrError: LocalizedError {
        case notConfigured
        case unauthorized
        case noDefaults
        case http(Int)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return String(localized: "未配置 Radarr 服务器", comment: "Radarr not configured")
            case .unauthorized: return String(localized: "API Key 无效", comment: "Invalid API key")
            case .noDefaults: return String(localized: "Radarr 缺少质量配置或根目录", comment: "Missing quality profile or root folder")
            case .http(let code): return "HTTP \(code)"
            }
        }
    }

    private func request(_ path: String, query: [URLQueryItem] = [], method: String = "GET", body: Data? = nil) async throws -> Data {
        let config = RadarrConfig.load()
        guard config.isConfigured else { throw RadarrError.notConfigured }

        var comps = URLComponents(string: "\(config.baseURL)/api/v3/\(path)")
        if !query.isEmpty { comps?.queryItems = query }
        guard let url = comps?.url else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(config.apiKey, forHTTPHeaderField: "X-Api-Key")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        switch http.statusCode {
        case 200, 201: return data
        case 401: throw RadarrError.unauthorized
        default: throw RadarrError.http(http.statusCode)
        }
    }

    // MARK: - API

    /// 连接测试，成功返回 Radarr 版本号
    func systemStatus() async throws -> String {
        let data = try await request("system/status")
        let status = try JSONDecoder().decode(RadarrSystemStatus.self, from: data)
        return status.version ?? "?"
    }

    /// 按片名搜索电影（TMDB 元数据 + 是否已在片库）
    func lookup(_ term: String) async throws -> [RadarrMovie] {
        let data = try await request("movie/lookup", query: [URLQueryItem(name: "term", value: term)])
        return try JSONDecoder().decode([RadarrMovie].self, from: data)
    }

    func qualityProfiles() async throws -> [RadarrQualityProfile] {
        let data = try await request("qualityprofile")
        return try JSONDecoder().decode([RadarrQualityProfile].self, from: data)
    }

    func rootFolders() async throws -> [RadarrRootFolder] {
        let data = try await request("rootfolder")
        return try JSONDecoder().decode([RadarrRootFolder].self, from: data)
    }

    /// 添加电影到 Radarr 并让其自动搜索下载资源
    func addMovie(_ movie: RadarrMovie, qualityProfileId: Int, rootFolderPath: String) async throws {
        let payload: [String: Any] = [
            "title": movie.title,
            "tmdbId": movie.tmdbId,
            "year": movie.year,
            "qualityProfileId": qualityProfileId,
            "rootFolderPath": rootFolderPath,
            "monitored": true,
            "addOptions": ["searchForMovie": true]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await request("movie", method: "POST", body: body)
    }
}
