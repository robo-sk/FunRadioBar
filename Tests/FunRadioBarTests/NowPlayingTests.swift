import XCTest
@testable import FunRadioBar

@MainActor
final class NowPlayingTests: XCTestCase {
    func testSuccessiveFallbackTitlesReplaceThePreviousSong() {
        for id in ["cba", "vlna_test"] {
            var displayed: [String: [LiveTrackInfo]] = [:]
            for title in ["Song One", "Song Two - Live"] {
                let refresh = RadioPlayerManager.nowPlayingTracks(playlists: [:], fallbackTitles: [id: "Artist - " + title])
                displayed.merge(refresh) { _, new in new }
                XCTAssertEqual(displayed[id]?.map(\.title), [title])
                XCTAssertEqual(displayed[id]?.first?.artist, "Artist")
            }
        }
    }

    func testPlaylistWinsAndFallbackPreservesUpcomingSongs() {
        let cover = URL(string: "https://www.funradio.sk/cover.jpg")
        let current = LiveTrackInfo(order: 0, artist: "Artist", title: "Song", coverURL: cover, videoURL: nil, ageSeconds: 12)
        let next = LiveTrackInfo(order: 1, artist: "Next Artist", title: "Next Song", coverURL: nil, videoURL: nil, ageSeconds: 0)
        let tracks = RadioPlayerManager.nowPlayingTracks(
            playlists: ["fun": [current, next], "vlna": [next]],
            fallbackTitles: ["fun": "Older title", "vlna": "Current title"]
        )
        XCTAssertEqual(tracks["fun"], [current, next])
        XCTAssertEqual(tracks["vlna"]?.map(\.title), ["Current title", "Next Song"])
    }
}
