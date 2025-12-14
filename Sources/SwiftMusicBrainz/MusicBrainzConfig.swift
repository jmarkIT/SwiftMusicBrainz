//
//  MusicBrainzConfig.swift
//  SwiftMusicBrainz
//
//  Created by James Mark on 12/9/25.
//
import Foundation

public struct MusicBrainzConfig {
    static let baseUrl = URL(string: "https://musicbrainz.org/ws/2")!
    public var authToken: String
    public var appName: String
    public var appVersion: String
    public var contactInfo: String

    public init(
        authToken: String,
        appName: String,
        appVersion: String,
        contactInfo: String
    ) {
        self.authToken = authToken
        self.appName = appName
        self.appVersion = appVersion
        self.contactInfo = contactInfo
    }
}

extension MusicBrainzConfig {
    public func getUserAgent() -> String {
        return "\(appName)/\(appVersion) ( \(contactInfo) )"
    }
}
