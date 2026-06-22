import Foundation
import Testing

@testable import SwiftMusicBrainz

@Suite("MusicBrainz configuration")
struct MusicBrainzConfigTests {
  @Test("Builds the MusicBrainz user agent")
  func buildsUserAgent() {
    let config = MusicBrainzConfig(
      appName: "RecordShelf",
      appVersion: "2.4.1",
      contactInfo: "maintainer@example.com"
    )

    #expect(
      config.getUserAgent()
        == "RecordShelf/2.4.1 ( maintainer@example.com )"
    )
  }
}

@Suite("MusicBrainz models")
struct MusicBrainzModelTests {
  @Test("Decodes release genres and an absent date")
  func decodesRelease() throws {
    let data = Data(
      """
      {
        "id": "release-1",
        "title": "Selected Ambient Works",
        "genres": [
          { "id": "genre-1", "name": "ambient" },
          { "id": "genre-2", "name": "electronic" }
        ]
      }
      """.utf8
    )

    let release = try JSONDecoder().decode(MusicBrainzRelease.self, from: data)

    #expect(release.id == "release-1")
    #expect(release.title == "Selected Ambient Works")
    #expect(release.date == nil)
    #expect(release.genres?.map(\.name) == ["ambient", "electronic"])
  }

  @Test("Decodes MusicBrainz's hyphenated genre metadata keys")
  func decodesGenreResponse() throws {
    let data = Data(
      """
      {
        "genres": [{ "id": "genre-1", "name": "rock" }],
        "genre-count": 42,
        "genre-offset": 10
      }
      """.utf8
    )

    let response = try JSONDecoder().decode(
      MusicBrainzGenreResponse.self,
      from: data
    )

    #expect(response.genres.map(\.name) == ["rock"])
    #expect(response.genreCount == 42)
    #expect(response.genreOffset == 10)
  }
}

@Suite("MusicBrainz client", .serialized)
struct MusicBrainzClientTests {
  @Test("Requests a release with the selected includes")
  func requestsRelease() async throws {
    URLProtocolStub.configure(
      responses: [
        .json(
          """
          {
            "id": "release-1",
            "title": "Blue",
            "date": "1971-06-22",
            "genres": [{ "id": "genre-1", "name": "folk" }]
          }
          """
        )
      ]
    )
    let client = makeClient()

    let release = try await client.getRelease(
      for: "release-1",
      withInc: [.artistCredits, .genres]
    )
    let request = try #require(URLProtocolStub.requests.first)
    let components = try #require(
      URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
    )

    #expect(release.id == "release-1")
    #expect(release.date == "1971-06-22")
    #expect(request.httpMethod == "GET")
    #expect(components.path == "/ws/2/release/release-1")
    #expect(
      components.queryItems
        == [
          URLQueryItem(
            name: "inc",
            value: "artist-credits+genres"
          )
        ]
    )
    #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    #expect(
      request.value(forHTTPHeaderField: "Content-Type") == "application/json"
    )
    #expect(
      request.value(forHTTPHeaderField: "User-Agent")
        == "TestClient/1.0 ( tests@example.com )"
    )
  }

  @Test("Omits the include query when no includes are requested")
  func requestsReleaseWithoutIncludes() async throws {
    URLProtocolStub.configure(
      responses: [
        .json(
          """
          {
            "id": "release-1",
            "title": "Blue",
            "date": "1971-06-22",
            "genres": []
          }
          """
        )
      ]
    )
    let client = makeClient()

    _ = try await client.getRelease(for: "release-1")
    let request = try #require(URLProtocolStub.requests.first)
    let components = try #require(
      URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
    )

    #expect(components.path == "/ws/2/release/release-1")
    #expect(components.queryItems == nil)
  }

  @Test("Requests a genre page with limit and offset")
  func requestsGenrePage() async throws {
    URLProtocolStub.configure(
      responses: [
        .json(
          """
          {
            "genres": [{ "id": "genre-1", "name": "jazz" }],
            "genre-count": 1,
            "genre-offset": 25
          }
          """
        )
      ]
    )
    let client = makeClient()

    let response = try await client.getGenresPage(limit: 25, offset: 25)
    let request = try #require(URLProtocolStub.requests.first)
    let components = try #require(
      URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
    )
    let query = Dictionary(
      uniqueKeysWithValues: (components.queryItems ?? []).map {
        ($0.name, $0.value)
      }
    )

    #expect(response.genres.map(\.name) == ["jazz"])
    #expect(components.path == "/ws/2/genre/all")
    #expect(query["fmt"] == "json")
    #expect(query["limit"] == "25")
    #expect(query["offset"] == "25")
  }

  @Test("Paginates until the reported genre count is reached")
  func fetchesAllGenrePages() async throws {
    URLProtocolStub.configure(
      responses: [
        .json(
          """
          {
            "genres": [
              { "id": "genre-1", "name": "ambient" },
              { "id": "genre-2", "name": "classical" }
            ],
            "genre-count": 3,
            "genre-offset": 0
          }
          """
        ),
        .json(
          """
          {
            "genres": [
              { "id": "genre-3", "name": "jazz" }
            ],
            "genre-count": 3,
            "genre-offset": 2
          }
          """
        ),
      ]
    )
    let client = makeClient()

    let genres = try await client.getAllGenres()
    let requests = URLProtocolStub.requests
    let offsets = requests.compactMap { request in
      URLComponents(
        url: request.url!,
        resolvingAgainstBaseURL: false
      )?.queryItems?.first(where: { $0.name == "offset" })?.value
    }

    #expect(genres.map(\.name) == ["ambient", "classical", "jazz"])
    #expect(requests.count == 2)
    #expect(offsets == ["0", "2"])
  }

  @Test("Rejects non-success HTTP responses")
  func rejectsServerError() async {
    URLProtocolStub.configure(
      responses: [.init(statusCode: 503, data: Data())]
    )
    let client = makeClient()

    await #expect(throws: URLError.self) {
      try await client.getRelease(for: "unavailable")
    }
  }

  private func makeClient() -> MusicBrainzClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]

    return MusicBrainzClient(
      session: URLSession(configuration: configuration),
      cfg: MusicBrainzConfig(
        appName: "TestClient",
        appVersion: "1.0",
        contactInfo: "tests@example.com"
      )
    )
  }
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
  struct Response {
    let statusCode: Int
    let data: Data

    static func json(_ body: String, statusCode: Int = 200) -> Response {
      Response(statusCode: statusCode, data: Data(body.utf8))
    }
  }

  private static let lock = NSLock()
  nonisolated(unsafe) private static var queuedResponses: [Response] = []
  nonisolated(unsafe) private static var capturedRequests: [URLRequest] = []

  static var requests: [URLRequest] {
    lock.withLock { capturedRequests }
  }

  static func configure(responses: [Response]) {
    lock.withLock {
      queuedResponses = responses
      capturedRequests = []
    }
  }

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    let response = Self.lock.withLock { () -> Response? in
      Self.capturedRequests.append(request)
      guard !Self.queuedResponses.isEmpty else {
        return nil
      }
      return Self.queuedResponses.removeFirst()
    }

    guard let response else {
      client?.urlProtocol(
        self,
        didFailWithError: URLError(.resourceUnavailable)
      )
      return
    }

    let httpResponse = HTTPURLResponse(
      url: request.url!,
      statusCode: response.statusCode,
      httpVersion: nil,
      headerFields: ["Content-Type": "application/json"]
    )!
    client?.urlProtocol(
      self,
      didReceive: httpResponse,
      cacheStoragePolicy: .notAllowed
    )
    client?.urlProtocol(self, didLoad: response.data)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}
