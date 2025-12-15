//
//  MusicBrainzeRelease.swift
//  SwiftMusicBrainz
//
//  Created by James Mark on 12/9/25.
//

public struct MusicBrainzRelease: Identifiable, Codable, Sendable {
    public let id: String
    public let title: String
    public let date: String
    public let genres: [MusicBrainzGenre]
}

