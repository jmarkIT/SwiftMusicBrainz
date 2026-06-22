//
//  MusicBrainzArtistCredit.swift
//  SwiftMusicBrainz
//
//  Created by James Mark on 6/22/26.
//

public struct MusicBrainzArtistCredit: Codable, Sendable {
  public let name: String
  public let joinPhrase: String
  public let artist: MusicBrainzArtist

  enum CodingKeys: String, CodingKey {
    case name
    case artist
    case joinPhrase = "joinphrase"
  }
}

public struct MusicBrainzArtist: Identifiable, Codable, Sendable {
  public let id: String
  public let name: String
  public let disambiguation: String
}
