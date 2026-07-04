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
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

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
                [
                    "role": "system",
                    "content": "你是专业日语翻译助手。将输入的日文翻译成简体中文，只输出翻译结果，不要任何解释。如果输入是中文则直接返回原文。"
                ],
                [
                    "role": "user",
                    "content": text
                ]
            ],
            "temperature": 0.1,
            "max_tokens": 1024
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TranslateError.apiError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw TranslateError.parseError
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
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
