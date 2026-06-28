import Foundation

// MARK: - Service Kinds
enum ServiceKind: String, Codable, CaseIterable {
    case qBittorrent = "qBittorrent"
    case prowlarr = "Prowlarr"
    case radarr = "Radarr"

    var icon: String {
        switch self {
        case .qBittorrent: return "arrow.down.circle"
        case .prowlarr: return "antenna.radiowaves.left.and.right"
        case .radarr: return "film"
        }
    }
}

// MARK: - Credential Model
struct ServiceCredential: Codable, Identifiable, Equatable {
    var id: String { "\(kind.rawValue)_\(host):\(port)" }
    var kind: ServiceKind
    var name: String
    var host: String
    var port: Int
    var https: Bool
    var apiKey: String
    var username: String
    var password: String

    var baseURL: String {
        let scheme = https ? "https" : "http"
        return "\(scheme)://\(host):\(port)"
    }

    var apiURL: String {
        switch kind {
        case .qBittorrent: return baseURL
        case .prowlarr: return "\(baseURL)/api/v1"
        case .radarr: return "\(baseURL)/api/v3"
        }
    }
}

// MARK: - Credentials Manager
@MainActor
final class CredentialsManager: ObservableObject {
    static let shared = CredentialsManager()

    @Published var qBittorrent: ServiceCredential?
    @Published var prowlarr: ServiceCredential?
    @Published var radarr: ServiceCredential?

    private let defaults = UserDefaults.standard
    private let key = "service_credentials"

    private init() { loadAll() }

    // MARK: - Load / Save
    private func loadAll() {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([ServiceCredential].self, from: data)
        else { return }
        for cred in list {
            switch cred.kind {
            case .qBittorrent: qBittorrent = cred
            case .prowlarr: prowlarr = cred
            case .radarr: radarr = cred
            }
        }
    }

    func save(_ credential: ServiceCredential) {
        var list = allCredentials
        list.removeAll { $0.kind == credential.kind }
        list.append(credential)
        persist(list)

        switch credential.kind {
        case .qBittorrent: qBittorrent = credential
        case .prowlarr: prowlarr = credential
        case .radarr: radarr = credential
        }
    }

    func remove(_ kind: ServiceKind) {
        var list = allCredentials
        list.removeAll { $0.kind == kind }
        persist(list)

        switch kind {
        case .qBittorrent: qBittorrent = nil
        case .prowlarr: prowlarr = nil
        case .radarr: radarr = nil
        }
    }

    var allCredentials: [ServiceCredential] {
        [qBittorrent, prowlarr, radarr].compactMap { $0 }
    }

    var activeServices: [ServiceKind] {
        allCredentials.map(\.kind)
    }

    func credential(for kind: ServiceKind) -> ServiceCredential? {
        switch kind {
        case .qBittorrent: return qBittorrent
        case .prowlarr: return prowlarr
        case .radarr: return radarr
        }
    }

    private func persist(_ list: [ServiceCredential]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        defaults.set(data, forKey: key)
    }
}
