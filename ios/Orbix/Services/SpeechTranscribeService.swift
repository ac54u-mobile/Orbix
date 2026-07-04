import Foundation
import AVFoundation

actor SpeechTranscribeService {
    static let shared = SpeechTranscribeService()
    private let serverURL = "http://152.53.131.108:8899/pipeline"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 900
        config.timeoutIntervalForResource = 1800
        session = URLSession(configuration: config)
    }

    func transcribeAndTranslate(audioURL: URL) async throws -> String {
        let data = try Data(contentsOf: audioURL)

        let url = URL(string: serverURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TranscribeError.serverError
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let srt = json["srt"] as? String else {
            throw TranscribeError.parseError
        }

        return srt
    }

    static func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVAsset(url: videoURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscribeError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw TranscribeError.exportFailed
        }

        return outputURL
    }
}

enum TranscribeError: LocalizedError {
    case exportFailed
    case serverError
    case parseError

    var errorDescription: String? {
        switch self {
        case .exportFailed: return String(localized: "音频提取失败", comment: "")
        case .serverError: return String(localized: "服务器处理失败", comment: "")
        case .parseError: return String(localized: "结果解析失败", comment: "")
        }
    }
}
