import Foundation
import AVFoundation

actor SpeechTranscribeService {
    static let shared = SpeechTranscribeService()
    private let serverHost = "http://152.53.131.108:8899"
    private let session: URLSession

    struct Segment: Codable {
        let start: String
        let end: String
        let text: String
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 900
        config.timeoutIntervalForResource = 1800
        session = URLSession(configuration: config)
    }

    func transcribe(audioURL: URL, onPhase: (@Sendable (TranscribePhase) async -> Void)? = nil) async throws -> [Segment] {
        await onPhase?(.extracting)
        let data = try Data(contentsOf: audioURL)

        await onPhase?(.recognizing)
        let url = URL(string: "\(serverHost)/transcribe")!
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
              let segmentsJSON = json["segments"] as? [[String: Any]] else {
            throw TranscribeError.parseError
        }

        return segmentsJSON.compactMap { seg in
            guard let start = seg["start"] as? String,
                  let end = seg["end"] as? String,
                  let text = seg["text"] as? String else { return nil }
            return Segment(start: start, end: end, text: text)
        }
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

    func segmentsToSRT(_ segments: [Segment], with translations: [String]) -> String {
        zip(segments, translations).enumerated().map { idx, pair in
            "\(idx + 1)\n\(pair.0.start) --> \(pair.0.end)\n\(pair.1)\n"
        }.joined(separator: "\n")
    }
}

enum TranscribePhase {
    case extracting
    case recognizing
    case translating(progress: Int, total: Int)
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
