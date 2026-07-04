import Foundation

actor DeepSeekTranslateService {
    static let shared = DeepSeekTranslateService()

    private let serverURL: String
    private let session: URLSession

    private init() {
        serverURL = "http://152.53.131.108:8899/translate"
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        session = URLSession(configuration: config)
    }

    func translateToChinese(_ text: String) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }

        let url = URL(string: serverURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["text": text]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else { throw TranslateError.apiError }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let translated = json["translated"] as? String else { throw TranslateError.parseError }

        return translated.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func translateSubtitles(
        _ entries: [SRTEntry],
        batchSize: Int = 20,
        maxConcurrent: Int = 3,
        onProgress: (@Sendable (Int, Int) async -> Void)? = nil
    ) async throws -> [SRTEntry] {
        guard !entries.isEmpty else { return entries }

        let total = entries.count
        let batches = stride(from: 0, to: total, by: batchSize).map {
            Array(entries[$0..<min($0 + batchSize, total)])
        }

        var translated: [Int: String] = [:]
        var completed = 0

        try await withThrowingTaskGroup(of: (Int, [Int: String]).self) { group in
            for (batchIndex, batch) in batches.enumerated() {
                if batchIndex >= maxConcurrent {
                    if let result = try await group.next() {
                        completed += result.0
                        for (k, v) in result.1 { translated[k] = v }
                        await onProgress?(completed, total)
                    }
                }
                group.addTask {
                    let prompt = await self.buildBatchPrompt(batch)
                    let response = try await self.translateToChinese(prompt)
                    var batchDict: [Int: String] = [:]
                    await self.parseBatchResponse(response, into: &batchDict, for: batch)
                    return (batch.count, batchDict)
                }
            }
            for try await result in group {
                completed += result.0
                for (k, v) in result.1 { translated[k] = v }
                await onProgress?(completed, total)
            }
        }

        return entries.map { entry in
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
