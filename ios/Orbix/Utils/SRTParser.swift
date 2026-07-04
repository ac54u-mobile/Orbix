import Foundation

struct SRTEntry: Sendable {
    let index: Int
    let start: String
    let end: String
    let text: String
}

enum SRTParser {
    static func parse(_ content: String) -> [SRTEntry] {
        var entries: [SRTEntry] = []
        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for block in blocks {
            let lines = block.components(separatedBy: "\n")
            guard lines.count >= 3 else { continue }

            let indexLine = lines[0].trimmingCharacters(in: .whitespaces)
            guard let index = Int(indexLine) else { continue }

            let timeLine = lines[1].trimmingCharacters(in: .whitespaces)
            let parts = timeLine.components(separatedBy: "-->")
            guard parts.count == 2 else { continue }

            let start = parts[0].trimmingCharacters(in: .whitespaces)
            let end = parts[1].trimmingCharacters(in: .whitespaces)
            let text = lines[2...].joined(separator: "\n")

            entries.append(SRTEntry(index: index, start: start, end: end, text: text))
        }

        return entries
    }

    static func generate(from entries: [SRTEntry]) -> String {
        entries.enumerated().map { idx, entry in
            "\(idx + 1)\n\(entry.start) --> \(entry.end)\n\(entry.text)\n"
        }.joined(separator: "\n")
    }
}
