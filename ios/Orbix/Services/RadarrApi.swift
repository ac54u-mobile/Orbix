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

    private func request(
        _ path: String,
        query: [URLQueryItem] = [],
        method: String = "GET",
        body: Data? = nil,
        timeout: TimeInterval = 15,
        config overrideConfig: RadarrConfig? = nil
    ) async throws -> Data {
        let config = overrideConfig ?? RadarrConfig.load()
        guard config.isConfigured else { throw RadarrError.notConfigured }

        var comps = URLComponents(string: "\(config.baseURL)/api/v3/\(path)")
        if !query.isEmpty { comps?.queryItems = query }
        guard let url = comps?.url else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = timeout
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

    /// 连接测试，成功返回 Radarr 版本号。传入 config 时用给定配置测试（不要求已保存）
    func systemStatus(config: RadarrConfig? = nil) async throws -> String {
        let data = try await request("system/status", config: config)
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

    /// 确保电影在 Radarr 片库中（不存在则以"不监控、不自动下载"方式登记），返回片库 id。
    /// 登记是调用资源搜索接口的前提，不会触发 Radarr 自己下载。
    func ensureInLibrary(_ movie: RadarrMovie) async throws -> Int {
        if let id = movie.libraryId, id > 0 { return id }

        // 可能之前已登记过，先按 tmdbId 查
        if let data = try? await request("movie", query: [URLQueryItem(name: "tmdbId", value: String(movie.tmdbId))]),
           let existing = try? JSONDecoder().decode([RadarrMovie].self, from: data),
           let id = existing.first?.libraryId, id > 0 {
            return id
        }

        async let profiles = qualityProfiles()
        async let folders = rootFolders()
        guard let profile = try await profiles.first, let folder = try await folders.first else {
            throw RadarrError.noDefaults
        }
        let payload: [String: Any] = [
            "title": movie.title,
            "tmdbId": movie.tmdbId,
            "year": movie.year,
            "qualityProfileId": profile.id,
            "rootFolderPath": folder.path,
            "monitored": false,
            "addOptions": ["searchForMovie": false]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let data = try await request("movie", method: "POST", body: body)
        struct Added: Codable { let id: Int }
        return try JSONDecoder().decode(Added.self, from: data).id
    }

    /// 通过 Radarr 的索引器交互式搜索电影的下载资源（可能需要几十秒）
    func releases(movieId: Int) async throws -> [RadarrRelease] {
        let data = try await request(
            "release",
            query: [URLQueryItem(name: "movieId", value: String(movieId))],
            timeout: 120
        )
        return try JSONDecoder().decode([RadarrRelease].self, from: data)
    }

    /// 让 Radarr 抓取该资源并推送给它配置的下载器（兜底方案，适用于 app 拿不到种子文件的场景）
    func grabRelease(guid: String, indexerId: Int) async throws {
        let payload: [String: Any] = ["guid": guid, "indexerId": indexerId]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await request("release", method: "POST", body: body, timeout: 60)
    }
}
