//
//  MusicBrainzClient.swift
//  SwiftMusicBrainz
//
//  Created by James Mark on 12/9/25.
//

import Foundation

public actor MusicBrainzClient {
    private let session: URLSession
    private let cfg: MusicBrainzConfig
    private let rateLimiter = RateLimiter()
    private let minInterval: TimeInterval = 1.0

    public init(session: URLSession = .shared, cfg: MusicBrainzConfig) {
        self.session = session
        self.cfg = cfg
    }

    private func makeRequest(
        endpoint: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil
    ) -> URLRequest {
        let baseURL = MusicBrainzConfig.apiBaseUrl.appending(path: endpoint)
        var components = URLComponents(
            url: baseURL,
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = queryItems?.isEmpty == false ? queryItems : nil
        guard let url = components.url else {
            fatalError("Invalid URL components for endpoint: \(endpoint)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return request
    }

    func perform<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil
    ) async throws -> T {
        let request = makeRequest(
            endpoint: endpoint,
            method: method,
            queryItems: queryItems,
            body: body
        )
        await rateLimiter.waitIfNeeded(minInterval: minInterval)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

extension MusicBrainzClient {
    public func getRelease(releaseId: String) async throws
        -> MusicBrainzeRelease
    {
        let queryItems = [URLQueryItem(name: "inc", value: "genres")]
        return try await perform(
            "release/\(releaseId)",
            method: "GET",
            queryItems: queryItems,
            body: nil
        )
    }
}

actor RateLimiter {
    private var lastRequestTime: Date?

    func waitIfNeeded(minInterval: TimeInterval) async {
        let now = Date()
        if let last = lastRequestTime {
            let delta = now.timeIntervalSince(last)
            if delta < minInterval {
                try? await Task.sleep(
                    nanoseconds: UInt64((minInterval - delta) * 1_000_000_000)
                )
            }
        }
        lastRequestTime = Date()
    }
}
