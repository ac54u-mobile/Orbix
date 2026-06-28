import Foundation

// MARK: - Radarr API
actor RadarrApi {
    static let shared = RadarrApi()
    private let session = URLSession(configuration: .ephemeral)
    private let decoder = JSONDecoder()

    private var credential: ServiceCredential? {
        CredentialsManager.shared.radarr
    }

    // MARK: - Movie Lookup (TMDB)
    struct RadarrMovie: Codable, Identifiable {
        let id: Int
        let title: String
        let year: Int?
        let overview: String?
        let tmdbId: Int?
        let images: [RadarrImage]?
        let hasFile: Bool?

        enum CodingKeys: String, CodingKey {
            case id, title, year, overview, images, hasFile
            case tmdbId = "tmdbId"
        }
    }

    struct RadarrImage: Codable {
        let coverType: String
        let remoteUrl: String?

        enum CodingKeys: String, CodingKey {
            case coverType, remoteUrl
        }
    }

    /// Search TMDB and return unified search results
    func lookup(query: String) async throws -> [SearchResult] {
        guard let cred = credential, !cred.apiKey.isEmpty else { return [] }
        var urlStr = "\(cred.apiURL)/movie/lookup?term=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        guard let url = URL(string: urlStr) else { return [] }

        var req = URLRequest(url: url)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, _) = try await session.data(for: req)
        let movies = (try? decoder.decode([RadarrMovie].self, from: data)) ?? []
        return movies.map { movie in
            SearchResult(
                num: movie.tmdbId ?? movie.id,
                descr: "",
                fileName: movie.title + (movie.year.map { " (\($0))" } ?? ""),
                fileSize: 0,
                nbLeechers: 0,
                nbSeeders: 0,
                siteUrl: movie.images?.first(where: { $0.coverType == "poster" })?.remoteUrl ?? ""
            )
        }
    }

    /// Fetch movie catalog from Radarr
    func getMovies() async throws -> [RadarrMovie] {
        guard let cred = credential, !cred.apiKey.isEmpty else { return [] }
        guard let url = URL(string: "\(cred.apiURL)/movie") else { return [] }
        var req = URLRequest(url: url)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, _) = try await session.data(for: req)
        return (try? decoder.decode([RadarrMovie].self, from: data)) ?? []
    }
}
