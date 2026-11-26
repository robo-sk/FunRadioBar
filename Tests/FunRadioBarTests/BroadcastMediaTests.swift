import XCTest
@testable import FunRadioBar

final class BroadcastMediaTests: XCTestCase {
    func testArtworkDestinations() {
        XCTAssertTrue(BroadcastMedia.allowsArtwork(URL(string: "https://i.ytimg.com/image.jpg")!))
        for value in ["http://i.ytimg.com/x", "https://127.0.0.1/x", "https://i.ytimg.com.example/x",
                      "https://i.ytimg.com:8443/x", "https://user@i.ytimg.com/x"] {
            XCTAssertFalse(BroadcastMedia.allowsArtwork(URL(string: value)!))
        }
    }

    func testLiveAndSavedVideoLinks() {
        let video = "https://youtu.be/8KqrdMbF3lo"
        XCTAssertEqual(BroadcastMedia.youtube(URL(string: video), artist: "", title: "")?.absoluteString,
                       "https://www.youtube.com/watch?v=8KqrdMbF3lo")
        let unexpected = "https://www.youtube.com/redirect?event=test"
        let live = LiveTrackInfo(order: 0, artist: "A&B", title: "Song", coverURL: nil,
                                 videoURL: URL(string: unexpected), ageSeconds: 0)
        let saved = SavedTrack(id: "1", artist: "A&B", title: "Song", stationId: "fun", stationName: "Fun",
                               coverURLString: nil, videoURLString: "file:///tmp/video", timestamp: Date())
        XCTAssertEqual(live.youtubeWatchOrSearchURL, saved.youtubeURL)
        XCTAssertEqual(saved.youtubeURL?.path, "/results")
    }

    func testInvalidScheduleTime() {
        let show = LiveShowInfo(title: "Test", airtime: "", startTime: "\(Int.max):00", endTime: "15:30",
                                imageURL: nil, allShows: [])
        XCTAssertNil(show.showProgress)
    }
}
