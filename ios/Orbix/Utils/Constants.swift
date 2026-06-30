import Foundation

enum NetworkTimeout {
    static let brief: TimeInterval = 3
    static let standard: TimeInterval = 8
    static let login: TimeInterval = 5
    static let download: TimeInterval = 30
}

enum RefreshInterval {
    static let torrentList: TimeInterval = 2
}

enum Polling {
    static let initialBackoffNanos: UInt64 = 300_000_000
    static let maxBackoffNanos: UInt64 = 1_200_000_000
}

enum UpdateConstants {
    static let checkCacheInterval: TimeInterval = 1800
}

enum AppConstants {
    static let lockGracePeriod: TimeInterval = 8
}
