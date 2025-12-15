//
//  MusicBrainzClient.swift
//  SwiftMusicBrainz
//
//  Created by James Mark on 12/9/25.
//

import Foundation
import SwiftAPIClient

public actor MusicBrainzClient: APIClient {
    public let session: URLSession
    public let baseURL: URL
    public let defaultHeaders: [String: String]
    private let rateLimiter = RateLimiter()
    private let minInterval: TimeInterval = 1.0

    public init(session: URLSession = .shared, cfg: MusicBrainzConfig) {
        self.session = session
        self.baseURL = MusicBrainzConfig.baseUrl
        self.defaultHeaders = [
            "Accept": "application/json", "Content-Type": "application/json",
            "User-Agent": cfg.getUserAgent(),
        ]
    }

    public func prepareForRequest() async {
        await rateLimiter.waitIfNeeded(minInterval: minInterval)
    }

}

extension MusicBrainzClient {
    public func getRelease(for releaseId: String) async throws
        -> MusicBrainzRelease
    {
        await prepareForRequest()
        let queryItems = [URLQueryItem(name: "inc", value: "genres")]
        return try await get("release/\(releaseId)", queryItems: queryItems)
    }
}

extension MusicBrainzClient {
    func getGenresPage(limit: Int = 100, offset: Int) async throws -> MusicBrainzGenreResponse {
        await prepareForRequest()
        
        let queryItems = [
            URLQueryItem(name: "fmt", value: "json"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        
        return try await get("genre/all", queryItems: queryItems)
    }
}

extension MusicBrainzClient {
    public func getAllGenres() async throws -> [MusicBrainzGenre] {
        var allGenres: [MusicBrainzGenre] = []
        var offset = 0
        var limit = 100
        var totalCount: Int? = nil
        
        while true {
            let response = try await getGenresPage(limit: limit, offset: offset)
            
            allGenres.append(contentsOf: response.genres)
            
            if totalCount == nil {
                totalCount = response.genreCount
            }
            
            offset += response.genres.count
            
            if let totalCount, allGenres.count >= totalCount {
                break
            }
        }
        
        return allGenres
    }
}
