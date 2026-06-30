import Foundation

// MARK: - Radarr API
enum RadarrApi {

    private static let session = URLSession(configuration: .ephemeral)
    private static let decoder = JSONDecoder()

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

    struct QualityProfile: Codable, Identifiable {
        let id: Int
        let name: String
    }

    struct RootFolder: Codable, Identifiable {
        let id: Int
        let path: String
        let freeSpace: Int64?

        enum CodingKeys: String, CodingKey {
            case id, path, freeSpace
        }
    }

    // MARK: - Lookup

    @MainActor
    static func lookup(query: String) async throws -> [SearchResult] {
        guard let cred = CredentialsManager.shared.radarr, !cred.apiKey.isEmpty else {
            throw ApiError.unauthorized
        }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) ?? query
        guard let url = URL(string: "\(cred.apiURL)/movie/lookup?term=\(encoded)") else { return [] }

        var req = URLRequest(url: url)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "Radarr", code: http.statusCode)
        }
        let movies = (try? decoder.decode([RadarrMovie].self, from: data)) ?? []
        return movies.map { movie in
            SearchResult(
                num: movie.tmdbId ?? movie.id,
                descr: "",
                fileName: movie.title + (movie.year.map { " (\($0))" } ?? ""),
                fileSize: 0,
                nbLeechers: 0,
                nbSeeders: 0,
                siteUrl: movie.images?.first(where: { $0.coverType == "poster" })?.remoteUrl ?? "",
                isAdded: movie.id > 0 || movie.hasFile == true
            )
        }
    }

    @MainActor
    static func getMovies() async throws -> [RadarrMovie] {
        guard let cred = CredentialsManager.shared.radarr, !cred.apiKey.isEmpty else { return [] }
        guard let url = URL(string: "\(cred.apiURL)/movie") else { return [] }
        var req = URLRequest(url: url)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "Radarr", code: http.statusCode)
        }
        return (try? decoder.decode([RadarrMovie].self, from: data)) ?? []
    }

    // MARK: - Profiles & Root Folders
    @MainActor
    static func getQualityProfiles() async throws -> [QualityProfile] {
        guard let cred = CredentialsManager.shared.radarr, !cred.apiKey.isEmpty else { return [] }
        guard let url = URL(string: "\(cred.apiURL)/qualityprofile") else { return [] }
        var req = URLRequest(url: url)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "Radarr", code: http.statusCode)
        }
        return (try? decoder.decode([QualityProfile].self, from: data)) ?? []
    }

    @MainActor
    static func getRootFolders() async throws -> [RootFolder] {
        guard let cred = CredentialsManager.shared.radarr, !cred.apiKey.isEmpty else { return [] }
        guard let url = URL(string: "\(cred.apiURL)/rootfolder") else { return [] }
        var req = URLRequest(url: url)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "Radarr", code: http.statusCode)
        }
        return (try? decoder.decode([RootFolder].self, from: data)) ?? []
    }

    // MARK: - Releases

    @MainActor
    static func lookupReleases(movieId: Int) async throws -> [MovieRelease] {
        guard let cred = CredentialsManager.shared.radarr, !cred.apiKey.isEmpty else {
            throw ApiError.unauthorized
        }
        guard let url = URL(string: "\(cred.apiURL)/release?movieId=\(movieId)") else {
            throw ApiError.invalidURL
        }

        var req = URLRequest(url: url)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        req.timeoutInterval = 60
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "Radarr", code: http.statusCode)
        }
        let releases = (try? decoder.decode([MovieRelease].self, from: data)) ?? []
        return releases
    }

    @MainActor
    static func downloadRelease(guid: String, indexerId: Int, movieId: Int?) async throws {
        guard let cred = CredentialsManager.shared.radarr, !cred.apiKey.isEmpty else {
            throw ApiError.unauthorized
        }
        guard let url = URL(string: "\(cred.apiURL)/release") else {
            throw ApiError.invalidURL
        }

        var body: [String: Any] = [
            "guid": guid,
            "indexerId": indexerId
        ]
        if let movieId { body["movieId"] = movieId }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 15
        let (_, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200, http.statusCode != 201 {
            throw NSError(domain: "Radarr", code: http.statusCode)
        }
    }

    @MainActor
    static func fetchQueue() async throws -> [MovieReleaseQueueItem] {
        guard let cred = CredentialsManager.shared.radarr, !cred.apiKey.isEmpty else {
            throw ApiError.unauthorized
        }
        guard let url = URL(string: "\(cred.apiURL)/queue?includeMovie=true&pageSize=50") else {
            throw ApiError.invalidURL
        }

        var req = URLRequest(url: url)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "Radarr", code: http.statusCode)
        }
        let decoder = JSONDecoder()
        let queueResponse = (try? decoder.decode(QueueResponse.self, from: data))
        return queueResponse?.records ?? []
    }

    // MARK: - Add Movie
    @MainActor
    static func addMovie(
        tmdbId: Int,
        title: String,
        year: Int,
        qualityProfileId: Int,
        rootFolderPath: String,
        monitored: Bool = true,
        searchOnAdd: Bool = true
    ) async throws {
        guard let cred = CredentialsManager.shared.radarr, !cred.apiKey.isEmpty else { return }
        guard let url = URL(string: "\(cred.apiURL)/movie") else { return }

        let body: [String: Any] = [
            "tmdbId": tmdbId,
            "title": title,
            "year": year,
            "qualityProfileId": qualityProfileId,
            "rootFolderPath": rootFolderPath,
            "monitored": monitored,
            "addOptions": ["searchForMovie": searchOnAdd]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        req.httpBody = jsonData
        let _ = try await session.data(for: req)
    }
}

struct MovieReleaseQueueItem: Codable, Identifiable {
    let id: Int
    let size: Double
    let sizeleft: Double
    let title: String?
    let status: String?
    let trackedDownloadStatus: String?
    let trackedDownloadState: String?
    let timeleft: String?
    let movieId: Int?

    var progress: Double {
        size > 0 ? 1.0 - (sizeleft / size) : 0
    }

    var progressPercent: Int {
        Int(progress * 100)
    }
}

struct QueueResponse: Codable {
    let records: [MovieReleaseQueueItem]
}
