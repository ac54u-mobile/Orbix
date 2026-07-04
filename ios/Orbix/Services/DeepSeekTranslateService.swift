import Foundation

actor DeepSeekTranslateService {
    static let shared = DeepSeekTranslateService()

    private let baseURL: String
    private let apiKey: String
    private let session: URLSession

    private init() {
        baseURL = "https://api.deepseek.com"
        apiKey = "sk-c98b48e1eae247f59e5ab82990f396b0"
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        session = URLSession(configuration: config)
    }

    private var _onProgress: (@Sendable (Int, Int) async -> Void)?

    func translateToChinese(_ text: String) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": "你是专业日语翻译助手。将输入的日文翻译成简体中文，只输出翻译结果，不要任何解释。如果输入是中文则直接返回原文。"],
                ["role": "user", "content": text]
            ],
            "temperature": 0.1,
            "max_tokens": 1024
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else { throw TranslateError.apiError }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else { throw TranslateError.parseError }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func translateSubtitles(
        _ entries: [SRTEntry],
        batchSize: Int = 8,
        onProgress: (@Sendable (Int, Int) async -> Void)? = nil
    ) async throws -> [SRTEntry] {
        guard !entries.isEmpty else { return entries }

        var translated: [Int: String] = [:]
        let total = entries.count
        var current = 0

        let batches = stride(from: 0, to: entries.count, by: batchSize).map {
            Array(entries[$0..<min($0 + batchSize, entries.count)])
        }

        for batch in batches {
            let prompt = buildBatchPrompt(batch)
            let response = try await translateToChinese(prompt)
            parseBatchResponse(response, into: &translated, for: batch)

            current += batch.count
            await onProgress?(current, total)

            if current < total {
                try await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        return entries.enumerated().map { idx, entry in
            var result = entry
            result.text = translated[entry.index] ?? entry.text
            return result
        }
    }

    private func buildBatchPrompt(_ entries: [SRTEntry]) -> String {
        let lines = entries.enumerated().map { idx, entry in
            "\(idx + 1). \(entry.text)"
        }.joined(separator: "\n")

        return """
        将以下日文字幕逐行翻译成简体中文。严格按照编号对应输出每行翻译，格式为「编号. 中文」。不要省略任何行，不要添加解释：

        \(lines)
        """
    }

    private func parseBatchResponse(_ response: String, into dict: inout [Int: String], for batch: [SRTEntry]) {
        let lines = response.components(separatedBy: "\n")
        for line in lines {
            guard let dotIndex = line.firstIndex(of: ".") else { continue }
            let numStr = String(line[..<dotIndex]).trimmingCharacters(in: .whitespaces)
            guard let num = Int(numStr), (1...batch.count).contains(num) else { continue }

            let text = String(line[line.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }

            let entry = batch[num - 1]
            dict[entry.index] = text
        }

        for entry in batch where dict[entry.index] == nil {
            dict[entry.index] = entry.text
        }
    }
}

enum TranslateError: LocalizedError {
    case apiError
    case parseError

    var errorDescription: String? {
        switch self {
        case .apiError: return String(localized: "翻译服务请求失败", comment: "")
        case .parseError: return String(localized: "翻译结果解析失败", comment: "")
        }
    }
}
