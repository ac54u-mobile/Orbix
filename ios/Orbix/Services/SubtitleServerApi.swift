import Foundation

actor SubtitleServerApi {
    static let shared = SubtitleServerApi()
    private init() {}

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 20
        return URLSession(configuration: cfg)
    }()

    enum SubtitleError: LocalizedError {
        case notConfigured
        case unauthorized
        case http(Int)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return String(localized: "未配置字幕服务", comment: "Subtitle service not configured")
            case .unauthorized: return String(localized: "API Key 无效", comment: "Invalid API key")
            case .http(let code): return "HTTP \(code)"
            }
        }
    }

    private func request(
        _ path: String,
        query: [URLQueryItem] = [],
        method: String = "GET",
        body: Data? = nil,
        config overrideConfig: SubtitleServiceConfig? = nil
    ) async throws -> Data {
        let config = overrideConfig ?? SubtitleServiceConfig.load()
        guard config.isConfigured else { throw SubtitleError.notConfigured }

        var comps = URLComponents(string: "\(config.baseURL)/api/\(path)")
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
        case 200, 201, 202: return data
        case 401: throw SubtitleError.unauthorized
        default: throw SubtitleError.http(http.statusCode)
        }
    }

    // MARK: - API

    /// 连接测试（走需要鉴权的接口，同时验证地址和 key）
    func testConnection(config: SubtitleServiceConfig? = nil) async throws {
        _ = try await request("jobs", config: config)
    }

    /// 创建字幕任务；服务端对同一视频的进行中任务会直接复用
    func createJob(videoPath: String) async throws -> SubtitleJob {
        let body = try JSONSerialization.data(withJSONObject: ["video_path": videoPath])
        let data = try await request("jobs", method: "POST", body: body)
        return try JSONDecoder().decode(SubtitleJob.self, from: data)
    }

    func getJob(id: String) async throws -> SubtitleJob {
        let data = try await request("jobs/\(id)")
        return try JSONDecoder().decode(SubtitleJob.self, from: data)
    }

    /// 按视频路径查最近的任务（重新打开页面时续接进度）
    func findJob(videoPath: String) async throws -> SubtitleJob? {
        let data = try await request("jobs", query: [URLQueryItem(name: "video_path", value: videoPath)])
        let jobs = try JSONDecoder().decode([SubtitleJob].self, from: data)
        return jobs.first
    }

    /// 全部任务（最近 50 条，新的在前）
    func listJobs() async throws -> [SubtitleJob] {
        let data = try await request("jobs")
        return try JSONDecoder().decode([SubtitleJob].self, from: data)
    }

    /// 暂停任务（运行中的会停下，排队中的下一个任务自动开始）
    @discardableResult
    func pauseJob(id: String) async throws -> SubtitleJob {
        let data = try await request("jobs/\(id)/pause", method: "POST")
        return try JSONDecoder().decode(SubtitleJob.self, from: data)
    }

    /// 恢复已暂停的任务（重新排队，从头处理）
    @discardableResult
    func resumeJob(id: String) async throws -> SubtitleJob {
        let data = try await request("jobs/\(id)/resume", method: "POST")
        return try JSONDecoder().decode(SubtitleJob.self, from: data)
    }

    /// 删除任务记录，可选同时删除服务器上的字幕文件
    func deleteJob(id: String, deleteFile: Bool = false) async throws {
        _ = try await request(
            "jobs/\(id)",
            query: deleteFile ? [URLQueryItem(name: "delete_file", value: "true")] : [],
            method: "DELETE"
        )
    }

    /// 下载已完成任务的 srt 字幕内容
    func downloadSrt(jobId: String) async throws -> String {
        let data = try await request("jobs/\(jobId)/srt")
        return String(data: data, encoding: .utf8) ?? ""
    }
}

/// 把服务器上的字幕下载为本地临时 .srt 文件，供分享导出
enum SubtitleExporter {
    static func export(_ job: SubtitleJob) async throws -> URL {
        let content = try await SubtitleServerApi.shared.downloadSrt(jobId: job.id)
        let base = ((job.videoPath as NSString).lastPathComponent as NSString).deletingPathExtension
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(base).zh.srt")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
