//
//  MusicBrainzConfig.swift
//  SwiftMusicBrainz
//
//  Created by James Mark on 12/9/25.
//
import Foundation

public struct MusicBrainzConfig {
    static let apiBaseUrl = URL(string: "https://musicbrainz.org/ws/2")!
    public var authToken: String
    public var userAgent: String

    public init(authToken: String, userAgent: String) {
        self.authToken = authToken
        self.userAgent = userAgent
    }
}
