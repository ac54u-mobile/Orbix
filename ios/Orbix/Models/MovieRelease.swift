import Foundation

struct MovieRelease: Codable, Identifiable {
    var id: String { guid }

    let guid: String
    let title: String
    let size: Int
    let age: Int
    let rejected: Bool
    let downloadAllowed: Bool

    let indexerId: Int
    let indexer: String?
    let seeders: Int?
    let leechers: Int?

    let quality: MovieReleaseQuality
    let qualityWeight: Int

    let releaseWeight: Int

    let infoUrl: String?

    enum CodingKeys: String, CodingKey {
        case guid
        case title
        case size
        case age
        case rejected
        case downloadAllowed
        case indexerId
        case indexer
        case seeders
        case leechers
        case quality
        case qualityWeight
        case releaseWeight
        case infoUrl
    }

    var isTorrent: Bool { true }

    var sizeLabel: String {
        formatBytes(Int64(size))
    }

    var qualityLabel: String {
        quality.quality.name
    }

    var ageLabel: String {
        if age < 60 { return "\(age)m" }
        if age < 1440 { return "\(age / 60)h" }
        return "\(age / 1440)d"
    }

    var indexerLabel: String {
        indexer ?? String(localized: "未知索引器")
    }
}

struct MovieReleaseQuality: Codable {
    let quality: MovieQuality

    struct MovieQuality: Codable {
        let id: Int
        let name: String
    }
}

struct MovieReleaseSort: Equatable {
    var option: Option = .bySeeders
    var ascending: Bool = false

    enum Option: String, CaseIterable, Identifiable {
        case bySeeders, bySize, byQuality, byAge

        var id: Self { self }

        var label: String {
            switch self {
            case .bySeeders: String(localized: "做种数")
            case .bySize: String(localized: "大小")
            case .byQuality: String(localized: "质量")
            case .byAge: String(localized: "发布时间")
            }
        }
    }
}
