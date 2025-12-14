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
        //        return try await perform(
        //            "release/\(releaseId)",
        //            method: "GET",
        //            queryItems: queryItems,
        //            body: nil
        //        )
    }
}
