import Foundation

// MARK: - 字幕服务配置

struct SubtitleServiceConfig: Equatable {
    var host: String = ""
    var port: Int = 8788
    var apiKey: String = ""

    var isConfigured: Bool { !host.isEmpty && !apiKey.isEmpty }
    var baseURL: String { "http://\(host):\(port)" }

    static func load() -> SubtitleServiceConfig {
        SubtitleServiceConfig(
            host: PersistenceService.shared.subtitleHost,
            port: PersistenceService.shared.subtitlePort,
            apiKey: KeychainService.loadString(forKey: "subtitle_api_key") ?? ""
        )
    }

    func save() {
        PersistenceService.shared.subtitleHost = host
        PersistenceService.shared.subtitlePort = port
        KeychainService.saveString(apiKey, forKey: "subtitle_api_key")
    }
}

// MARK: - 已翻译字幕标记

/// 记录哪些种子已生成过字幕，供种子卡片显示"已翻译字幕"徽标。
/// 所有调用都在主线程（视图或 MainActor.run 中）发生。
final class SubtitleBadgeStore: ObservableObject {
    static let shared = SubtitleBadgeStore()

    @Published private(set) var hashes: Set<String>
    /// 进行中的任务：种子 hash → 任务（用于卡片上直接显示翻译进度）
    @Published private(set) var activeJobs: [String: SubtitleJob] = [:]

    private init() {
        hashes = Set(PersistenceService.shared.subtitledHashes)
    }

    /// 发起/续接任务时记录 任务id → 种子hash 的关联
    func recordJob(_ jobId: String, torrentHash: String) {
        var map = PersistenceService.shared.subtitleJobMap
        map[jobId] = torrentHash
        PersistenceService.shared.subtitleJobMap = map
    }

    func markSubtitled(_ hash: String) {
        activeJobs.removeValue(forKey: hash)
        guard !hashes.contains(hash) else { return }
        hashes.insert(hash)
        PersistenceService.shared.subtitledHashes = Array(hashes)
    }

    /// 单个任务的即时更新（提取字幕页轮询时同步给卡片）
    func updateActive(_ job: SubtitleJob, torrentHash: String) {
        if job.isRunningOrQueued {
            activeJobs[torrentHash] = job
        } else {
            activeJobs.removeValue(forKey: torrentHash)
            if job.stage == "done" { markSubtitled(torrentHash) }
        }
    }

    /// 用服务器任务列表整体同步：进行中的显示进度，完成的打标（暂停/失败不上卡片）
    func sync(with jobs: [SubtitleJob]) {
        let map = PersistenceService.shared.subtitleJobMap
        var active: [String: SubtitleJob] = [:]
        for job in jobs {
            guard let hash = map[job.id] else { continue }
            if job.stage == "done" {
                markSubtitled(hash)
            } else if job.isRunningOrQueued {
                // 服务器返回按时间倒序，同一种子只保留最新任务
                if active[hash] == nil { active[hash] = job }
            }
        }
        activeJobs = active
    }
}

// MARK: - 字幕任务

struct SubtitleJob: Codable, Identifiable, Equatable {
    let id: String
    let videoPath: String
    let stage: String     // queued/extract/transcribe/translate/write/done/error
    let progress: Int     // 当前阶段 0-100
    let message: String
    let error: String
    let srtPath: String

    enum CodingKeys: String, CodingKey {
        case id, stage, progress, message, error
        case videoPath = "video_path"
        case srtPath = "srt_path"
    }

    var isFinished: Bool { stage == "done" || stage == "error" }

    /// 排队或正在处理（暂停不算）
    var isRunningOrQueued: Bool { !isFinished && stage != "paused" }

    var stageTitle: String {
        switch stage {
        case "queued": return String(localized: "排队中", comment: "Queued")
        case "extract": return String(localized: "提取音频", comment: "Extracting audio")
        case "transcribe": return String(localized: "Whisper 语音识别", comment: "Transcribing")
        case "translate": return String(localized: "DeepSeek 翻译", comment: "Translating")
        case "write": return String(localized: "写入字幕文件", comment: "Writing subtitle")
        case "paused": return String(localized: "已暂停", comment: "Paused")
        case "done": return String(localized: "已完成", comment: "Done")
        case "error": return String(localized: "失败", comment: "Failed")
        default: return stage
        }
    }

    /// 各阶段在整体流程中的估算占比，用于展示总进度
    var overallProgress: Double {
        let stageRange: (start: Double, span: Double)
        switch stage {
        case "queued", "paused": stageRange = (0, 0)
        case "extract": stageRange = (0, 0.10)
        case "transcribe": stageRange = (0.10, 0.60)
        case "translate": stageRange = (0.70, 0.28)
        case "write": stageRange = (0.98, 0.02)
        default: return 1
        }
        return stageRange.start + stageRange.span * Double(progress) / 100
    }
}
