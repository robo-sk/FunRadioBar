import XCTest
@testable import FunRadioBar

final class StationDiscoveryTests: XCTestCase {
    private func catalog(fun: [String], vlna: [String] = []) throws -> [RadioStation] {
        func mounts(_ names: [String]) -> [String: [String: Int]] {
            Dictionary(uniqueKeysWithValues: names.map { ($0, [:]) })
        }
        let data = try JSONSerialization.data(withJSONObject: [
            "ok": true, "fun": ["mounts": mounts(fun)], "vlna": ["mounts": mounts(vlna)]
        ])
        return try StationDiscovery.stations(from: data)
    }

    func testSeasonalReplacementAndSeparateVlnaStation() throws {
        let old = try catalog(fun: ["vianoce128.mp3", "summer128.mp3"])
        XCTAssertEqual(Set(old.map(\.id)), ["summer", "vianoce"])

        let current = try catalog(fun: ["xmas128.mp3", "xmas64.mp3"], vlna: ["xmas-hi.mp3"])
        XCTAssertEqual(current.map(\.name), ["Fun Vianoce", "Vlna Vianoce"])
        XCTAssertEqual(Set(current.map(\.id)).count, 2)
        XCTAssertEqual(current.first?.icecastMount, "xmas128.mp3")
        XCTAssertEqual(current.first?.streamURL(for: .eco).lastPathComponent, "xmas64.mp3")
        XCTAssertEqual(current.last?.streamURL(for: .eco).lastPathComponent, "xmas-hi.mp3")
    }

    func testBuiltInStationsKeepIdentityAndUseOnlyListedQualities() throws {
        let stations = try catalog(fun: ["funpgm256.mp3", "fun192.mp3", "fun128.mp3", "80-90-64.mp3"],
                                   vlna: ["party-hi.mp3", "party-lo.mp3"])
        XCTAssertEqual(stations.map(\.id), ["fun", "8090", "party"])
        let main = try XCTUnwrap(stations.first)
        XCTAssertEqual(main.streamURL(for: .hd).lastPathComponent, "funpgm256.mp3")
        XCTAssertEqual(main.streamURL(for: .eco).lastPathComponent, "fun128.mp3")
        XCTAssertEqual(stations[1].icecastMount, "80-90-64.mp3")
        XCTAssertEqual(stations[2].streamURL(for: .hd).port, 8000)
        XCTAssertNil(stations[2].streamURL(for: .eco).port)
    }

    func testInvalidOrIncompleteCatalogCannotReplaceTheSavedList() {
        for json in [#"{"ok":false,"fun":{"mounts":{}},"vlna":{"mounts":{}}}"#,
                     #"{"ok":true,"fun":{"mounts":{"fun128.mp3":{}}}}"#] {
            XCTAssertThrowsError(try StationDiscovery.stations(from: Data(json.utf8)))
        }
        XCTAssertThrowsError(try catalog(fun: ["unexpected-format"]))
    }
}
