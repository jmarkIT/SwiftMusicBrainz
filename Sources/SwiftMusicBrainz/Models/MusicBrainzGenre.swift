//
//  MusicBrainzGenre.swift
//  SwiftMusicBrainz
//
//  Created by James Mark on 12/14/25.
//


public struct MusicBrainzGenre: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
}

struct MusicBrainzGenreResponse: Codable {
    let genres: [MusicBrainzGenre]
    let genreCount: Int
    let genreOffset: Int
    
    enum CodingKeys: String, CodingKey {
        case genres
        case genreCount = "genre-count"
        case genreOffset = "genre-offset"
    }
}
