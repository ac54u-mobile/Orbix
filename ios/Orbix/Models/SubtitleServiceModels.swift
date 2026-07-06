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

    var stageTitle: String {
        switch stage {
        case "queued": return String(localized: "排队中", comment: "Queued")
        case "extract": return String(localized: "提取音频", comment: "Extracting audio")
        case "transcribe": return String(localized: "Whisper 语音识别", comment: "Transcribing")
        case "translate": return String(localized: "DeepSeek 翻译", comment: "Translating")
        case "write": return String(localized: "写入字幕文件", comment: "Writing subtitle")
        case "done": return String(localized: "已完成", comment: "Done")
        case "error": return String(localized: "失败", comment: "Failed")
        default: return stage
        }
    }

    /// 各阶段在整体流程中的估算占比，用于展示总进度
    var overallProgress: Double {
        let stageRange: (start: Double, span: Double)
        switch stage {
        case "queued": stageRange = (0, 0)
        case "extract": stageRange = (0, 0.10)
        case "transcribe": stageRange = (0.10, 0.60)
        case "translate": stageRange = (0.70, 0.28)
        case "write": stageRange = (0.98, 0.02)
        default: return 1
        }
        return stageRange.start + stageRange.span * Double(progress) / 100
    }
}
