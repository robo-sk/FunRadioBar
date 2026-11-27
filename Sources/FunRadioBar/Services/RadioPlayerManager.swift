import Foundation
import AVFoundation
import MediaPlayer
import AppKit
import Combine

@MainActor
final class RadioPlayerManager: ObservableObject {
    static let shared = RadioPlayerManager()

    // MARK: - Published Playback State
    @Published var currentStation: RadioStation {
        didSet {
            UserDefaults.standard.set(currentStation.id, forKey: "selectedStationId")
        }
    }
    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false
    @Published var volume: Float {
        didSet {
            player?.volume = isMuted ? 0 : volume
            UserDefaults.standard.set(volume, forKey: "playerVolume")
        }
    }
    @Published var isMuted: Bool = false {
        didSet {
            player?.volume = isMuted ? 0 : volume
        }
    }
    @Published var streamQuality: StreamQuality {
        didSet {
            UserDefaults.standard.set(streamQuality.rawValue, forKey: "streamQuality")
            if (isPlaying || isBuffering),
               currentStation.streamURL(for: oldValue) != currentStation.streamURL(for: streamQuality) {
                pause()
                play(station: currentStation)
            }
        }
    }

    // MARK: - UI & Window Preferences
    @Published var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: "appLanguage")
        }
    }
    var l10n: L10n { L10n(lang: appLanguage.resolved) }
    @Published var selectedNetworkFilter: RadioNetwork = .all
    @Published var menuBarLabelMode: MenuBarLabelMode {
        didSet {
            UserDefaults.standard.set(menuBarLabelMode.rawValue, forKey: "menuBarLabelMode")
        }
    }
    @Published var isMiniPlayerVisible: Bool = false
    @Published var miniPlayerMode: MiniPlayerMode {
        didSet {
            UserDefaults.standard.set(miniPlayerMode.rawValue, forKey: "miniPlayerMode")
            onMiniPlayerModeChanged?(miniPlayerMode)
        }
    }

    // MARK: - Live Radio Data
    @Published private(set) var stations: [RadioStation]
    @Published private(set) var isRescanning = false
    @Published private(set) var rescanFailed = false
    @Published var showsUnavailableStations = false
    @Published private var checkingStreams: Set<URL> = []
    @Published private var streamAvailability: [URL: StationAvailability] {
        didSet { saveCodable(streamAvailability, forKey: "streamAvailability") }
    }
    /// Station ID -> [LiveTrackInfo] (order 0 = current, order 1..2 = upcoming)
    @Published var stationTracks: [String: [LiveTrackInfo]] = [:]
    /// Station ID -> listener count
    @Published var stationListeners: [String: Int] = [:]
    @Published var totalFunListeners: Int = 0
    @Published var totalVlnaListeners: Int = 0
    @Published var funShowInfo: LiveShowInfo?
    @Published var vlnaShowInfo: LiveShowInfo?
    @Published var lastUpdated: Date?

    // MARK: - Favorites, History & Sleep Timer
    @Published var favoriteStationIds: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(favoriteStationIds), forKey: "favoriteStationIds")
        }
    }
    @Published var likedTracks: [SavedTrack] = [] {
        didSet {
            saveCodable(likedTracks, forKey: "likedTracks")
        }
    }
    @Published var recentHistory: [SavedTrack] = [] {
        didSet {
            saveCodable(recentHistory, forKey: "recentHistory")
        }
    }
    @Published var sleepTimerEndDate: Date?
    @Published var sleepTimerRemainingText: String?

    var onMiniPlayerToggleRequested: ((Bool) -> Void)?
    var onMiniPlayerModeChanged: ((MiniPlayerMode) -> Void)?

    // MARK: - Private Properties
    private var player: AVPlayer?
    private var statusObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var metadataTimer: Timer?
    private var sleepCountdownTimer: Timer?
    private var cachedArtworkURL: URL?
    private var cachedArtworkImage: NSImage?

    private init() {
        let stations: [RadioStation]
        if let catalog = Self.loadCodable([RadioStation].self, forKey: "stationCatalog") {
            stations = Self.stations(with: catalog)
        } else {
            // Keep older installations usable until their first successful rescan.
            let discovered = Self.loadCodable([RadioStation].self, forKey: "discoveredStations") ?? []
            let builtInIDs = Set(RadioStation.allStations.map(\.id))
            stations = RadioStation.allStations + discovered.filter { !builtInIDs.contains($0.id) }
        }
        self.streamAvailability = Self.loadCodable([URL: StationAvailability].self, forKey: "streamAvailability") ?? [:]
        self.stations = stations
        let savedStationId = UserDefaults.standard.string(forKey: "selectedStationId") ?? "fun"
        self.currentStation = stations.first(where: { $0.id == savedStationId }) ?? stations[0]

        let savedVol = UserDefaults.standard.object(forKey: "playerVolume") as? Float ?? 0.80
        self.volume = savedVol

        let savedQuality = UserDefaults.standard.string(forKey: "streamQuality")
            .flatMap(StreamQuality.init(rawValue:)) ?? .hd
        self.streamQuality = savedQuality

        let savedLang = UserDefaults.standard.string(forKey: "appLanguage")
            .flatMap(AppLanguage.init(rawValue:)) ?? .system
        self.appLanguage = savedLang

        let savedLabelMode = UserDefaults.standard.string(forKey: "menuBarLabelMode")
            .flatMap(MenuBarLabelMode.init(rawValue:)) ?? .liveSong
        self.menuBarLabelMode = savedLabelMode

        let savedMiniMode = UserDefaults.standard.string(forKey: "miniPlayerMode")
            .flatMap(MiniPlayerMode.init(rawValue:)) ?? .desktopWidget
        self.miniPlayerMode = savedMiniMode

        if let favs = UserDefaults.standard.stringArray(forKey: "favoriteStationIds") {
            self.favoriteStationIds = Set(favs)
        } else {
            self.favoriteStationIds = ["fun", "dance", "chill", "vlna"]
        }

        self.likedTracks = Self.loadCodable([SavedTrack].self, forKey: "likedTracks") ?? []
        self.recentHistory = Self.loadCodable([SavedTrack].self, forKey: "recentHistory") ?? []

        setupRemoteMediaCommands()
        startMetadataPolling()
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        if isPlaying || isBuffering {
            pause()
        } else {
            play(station: currentStation)
        }
    }

    func play(station: RadioStation) {
        guard canPlay(station) else { return }
        let stationChanged = station.id != currentStation.id
        if stationChanged {
            currentStation = station
        }

        let streamURL = station.streamURL(for: streamQuality)
        isBuffering = true
        isPlaying = true

        statusObservation?.invalidate()
        itemObservation?.invalidate()
        let item = AVPlayerItem(url: streamURL)
        item.preferredForwardBufferDuration = 2.0

        if let existingPlayer = player {
            existingPlayer.replaceCurrentItem(with: item)
        } else {
            player = AVPlayer(playerItem: item)
        }
        player?.volume = isMuted ? 0 : volume

        statusObservation = player?.observe(\.timeControlStatus, options: [.new, .initial]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self, player.currentItem === item else { return }
                switch player.timeControlStatus {
                case .playing:
                    self.isBuffering = false
                    self.isPlaying = true
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                    self.isPlaying = true
                case .paused:
                    self.isBuffering = false
                    self.isPlaying = false
                @unknown default:
                    break
                }
                self.updateNowPlayingCenter()
            }
        }

        itemObservation = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self, self.player?.currentItem === item, item.status == .failed else { return }
                let quality = self.streamQuality
                self.pause()
                await self.checkAvailability(for: station, quality: quality)
            }
        }

        player?.play()
        recordTrackInHistoryIfNeeded()
        updateNowPlayingCenter()
    }

    func pause() {
        statusObservation?.invalidate()
        itemObservation?.invalidate()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        isPlaying = false
        isBuffering = false
        updateNowPlayingCenter()
    }

    func nextStation() {
        stepStation(by: 1)
    }

    func previousStation() {
        stepStation(by: -1)
    }

    private func stepStation(by direction: Int) {
        let list = filteredStations.isEmpty ? stations : filteredStations
        guard let index = list.firstIndex(where: { $0.id == currentStation.id }) else {
            if let first = list.first(where: canPlay) { play(station: first) }
            return
        }
        for offset in 1...list.count {
            let candidate = list[(index + direction * offset + list.count) % list.count]
            if canPlay(candidate) {
                play(station: candidate)
                return
            }
        }
    }

    // MARK: - Station & Track Helpers

    func availability(for station: RadioStation) -> StationAvailability {
        let url = station.streamURL(for: streamQuality)
        return checkingStreams.contains(url) ? .checking : streamAvailability[url] ?? .unknown
    }

    func stationSections(in list: [RadioStation]) -> (regular: [RadioStation], unavailable: [RadioStation]) {
        // Use the last completed check so a retry stays in its section until it finishes.
        var regular: [RadioStation] = []
        var unavailable: [RadioStation] = []
        for station in list {
            if streamAvailability[station.streamURL(for: streamQuality)] == .unavailable {
                unavailable.append(station)
            } else {
                regular.append(station)
            }
        }
        return (regular, unavailable)
    }

    private func canPlay(_ station: RadioStation) -> Bool {
        switch availability(for: station) {
        case .unknown, .available: return true
        case .checking, .unavailable: return false
        }
    }

    func checkAvailability(for station: RadioStation) async {
        await checkAvailability(for: station, quality: streamQuality)
    }

    private func checkAvailability(for station: RadioStation, quality: StreamQuality) async {
        let url = station.streamURL(for: quality)
        guard checkingStreams.insert(url).inserted else { return }
        defer { checkingStreams.remove(url) }
        let result = await StationDiscovery.check(station, quality: quality)
        if streamAvailability[url] != result, stations.contains(where: { $0.streamURL(for: quality) == url }) {
            streamAvailability[url] = result
        }
    }

    func rescanStations() async {
        guard !isRescanning else { return }
        isRescanning = true
        rescanFailed = false
        defer { isRescanning = false }

        do {
            let catalog = try await StationDiscovery.fetchStations()
            applyCatalog(catalog)
        } catch {
            rescanFailed = true
        }

        let quality = streamQuality
        await withTaskGroup(of: Void.self) { group in
            var remaining = stations.makeIterator()
            for _ in 0..<6 {
                guard let station = remaining.next() else { break }
                group.addTask { await self.checkAvailability(for: station, quality: quality) }
            }
            while await group.next() != nil, let station = remaining.next() {
                group.addTask { await self.checkAvailability(for: station, quality: quality) }
            }
        }
    }

    private static func stations(with catalog: [RadioStation]) -> [RadioStation] {
        catalog + RadioStation.allStations.filter { $0.network != .funRadio && $0.network != .vlna }
    }

    private func applyCatalog(_ catalog: [RadioStation]) {
        let updated = Self.stations(with: catalog)
        let ids = Set(updated.map(\.id))
        var selectedID = currentStation.id
        if ids.contains("xmas") && !ids.contains("vianoce") {
            if selectedID == "vianoce" { selectedID = "xmas" }
            if favoriteStationIds.remove("vianoce") != nil { favoriteStationIds.insert("xmas") }
        }

        stations = updated
        saveCodable(catalog, forKey: "stationCatalog")
        UserDefaults.standard.removeObject(forKey: "discoveredStations")
        let listedURLs = Set(updated.flatMap { station in StreamQuality.allCases.map { station.streamURL(for: $0) } })
        streamAvailability = streamAvailability.filter { listedURLs.contains($0.key) }

        let replacement = updated.first { $0.id == selectedID }
        let selected = replacement ?? updated[0]
        guard selected != currentStation else { return }
        let wasActive = isPlaying || isBuffering
        let streamChanged = currentStation.streamURL(for: streamQuality) != selected.streamURL(for: streamQuality)
        if wasActive && streamChanged { pause() }
        currentStation = selected
        if wasActive && streamChanged && replacement != nil { play(station: selected) }
        updateNowPlayingCenter()
    }

    var filteredStations: [RadioStation] {
        switch selectedNetworkFilter {
        case .all:
            return stations
        case .favorites:
            return stations.filter { favoriteStationIds.contains($0.id) }
        case .funRadio, .vlna, .bauerAndCz, .stvr:
            return stations.filter { $0.network == selectedNetworkFilter }
        }
    }

    func currentTrack(for station: RadioStation? = nil) -> LiveTrackInfo? {
        let target = station ?? currentStation
        return stationTracks[target.id]?.first(where: { $0.order == 0 }) ?? stationTracks[target.id]?.first
    }

    func upcomingTracks(for station: RadioStation? = nil) -> [LiveTrackInfo] {
        let target = station ?? currentStation
        return (stationTracks[target.id] ?? []).filter { $0.order > 0 }.sorted { $0.order < $1.order }
    }

    func currentShow(for station: RadioStation? = nil) -> LiveShowInfo? {
        let target = station ?? currentStation
        switch target.network {
        case .funRadio: return funShowInfo
        case .vlna: return vlnaShowInfo
        default: return nil
        }
    }

    func listenersCount(for station: RadioStation? = nil) -> Int {
        let target = station ?? currentStation
        return stationListeners[target.id] ?? 0
    }

    func isFavoriteStation(_ station: RadioStation) -> Bool {
        favoriteStationIds.contains(station.id)
    }

    func toggleFavoriteStation(_ station: RadioStation) {
        if favoriteStationIds.contains(station.id) {
            favoriteStationIds.remove(station.id)
        } else {
            favoriteStationIds.insert(station.id)
        }
    }

    func isTrackLiked(_ track: LiveTrackInfo) -> Bool {
        let key = "\(track.artist.lowercased())|\(track.title.lowercased())"
        return likedTracks.contains { "\($0.artist.lowercased())|\($0.title.lowercased())" == key }
    }

    func toggleLikeCurrentTrack() {
        guard let track = currentTrack() else { return }
        let key = "\(track.artist.lowercased())|\(track.title.lowercased())"
        if let idx = likedTracks.firstIndex(where: { "\($0.artist.lowercased())|\($0.title.lowercased())" == key }) {
            likedTracks.remove(at: idx)
        } else {
            let saved = SavedTrack(
                id: UUID().uuidString,
                artist: track.artist,
                title: track.title,
                stationId: currentStation.id,
                stationName: currentStation.name,
                coverURLString: track.coverURL?.absoluteString,
                videoURLString: track.videoURL?.absoluteString,
                timestamp: Date()
            )
            likedTracks.insert(saved, at: 0)
        }
    }

    func toggleMiniPlayer() {
        isMiniPlayerVisible.toggle()
        onMiniPlayerToggleRequested?(isMiniPlayerVisible)
    }

    var menuBarTitleText: String? {
        switch menuBarLabelMode {
        case .iconOnly:
            return nil
        case .stationName:
            return currentStation.name
        case .liveSong:
            if let track = currentTrack(), !track.title.isEmpty {
                let full = track.displayLine
                return full.count > 34 ? String(full.prefix(32)) + "…" : full
            }
            return currentStation.name
        }
    }

    // MARK: - Sleep Timer

    func setSleepTimer(minutes: Int?) {
        sleepCountdownTimer?.invalidate()
        guard let minutes, minutes > 0 else {
            sleepTimerEndDate = nil
            sleepTimerRemainingText = nil
            return
        }
        let end = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimerEndDate = end
        updateSleepTimerRemaining()

        sleepCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateSleepTimerRemaining()
            }
        }
    }

    private func updateSleepTimerRemaining() {
        guard let end = sleepTimerEndDate else {
            sleepTimerRemainingText = nil
            return
        }
        let remaining = Int(end.timeIntervalSinceNow)
        if remaining <= 0 {
            sleepCountdownTimer?.invalidate()
            sleepTimerEndDate = nil
            sleepTimerRemainingText = nil
            pause()
            return
        }
        let mins = remaining / 60
        let secs = remaining % 60
        sleepTimerRemainingText = String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Live Metadata Polling

    func startMetadataPolling() {
        metadataTimer?.invalidate()
        Task {
            await refreshAllMetadata()
        }
        metadataTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAllMetadata()
            }
        }
    }

    func refreshAllMetadata() async {
        async let sepiaTask: Void = fetchSepiaTracks()
        async let icecastTask: Void = fetchIcecastStats()
        async let externalTask: Void = fetchExternalNetworksMetadata()
        async let funRelacieTask: LiveShowInfo? = fetchShowSchedule(stationSlug: "funradio")
        async let vlnaRelacieTask: LiveShowInfo? = fetchShowSchedule(stationSlug: "vlna")

        let (_, _, _, funShow, vlnaShow) = await (sepiaTask, icecastTask, externalTask, funRelacieTask, vlnaRelacieTask)
        if let funShow { self.funShowInfo = funShow }
        if let vlnaShow { self.vlnaShowInfo = vlnaShow }
        self.lastUpdated = Date()

        recordTrackInHistoryIfNeeded()
        updateNowPlayingCenter()
    }

    private func fetchSepiaTracks() async {
        guard let url = URL(string: "https://www.funradio.sk/prave-hra/?stanica=vsetky") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            var updated: [String: [LiveTrackInfo]] = stationTracks
            for station in stations {
                guard let rows = root[station.sepiaKey] as? [[String: Any]] else { continue }
                var parsed: [LiveTrackInfo] = []
                for row in rows {
                    let isActual = (row["aktualna"] as? Bool) ?? true
                    guard isActual else { continue }
                    let order = (row["poradie"] as? Int) ?? 0
                    let artist = (row["interpret"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let title = (row["skladba"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !artist.isEmpty || !title.isEmpty else { continue }

                    let coverStr = (row["cover"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let videoStr = (row["video"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let age = (row["vek"] as? Int) ?? 0

                    parsed.append(
                        LiveTrackInfo(
                            order: order,
                            artist: artist,
                            title: title,
                            coverURL: coverStr.flatMap { URL(string: $0) },
                            videoURL: videoStr.flatMap { URL(string: $0) },
                            ageSeconds: age
                        )
                    )
                }
                if !parsed.isEmpty {
                    updated[station.id] = parsed.sorted { $0.order < $1.order }
                }
            }
            self.stationTracks = updated
        } catch {
            // Keep cached values on transient network failure
        }
    }

    private func fetchIcecastStats() async {
        guard let url = URL(string: "https://www.funradio.sk/api/zive/") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            var listenersMap: [String: Int] = [:]
            var fallbackTitles: [String: String] = [:]

            if let funObj = root["fun"] as? [String: Any] {
                self.totalFunListeners = (funObj["total"] as? Int) ?? 0
                if let mounts = funObj["mounts"] as? [String: [String: Any]] {
                    for station in stations where station.network == .funRadio {
                        if let m = mounts[station.icecastMount] {
                            listenersMap[station.id] = (m["l"] as? Int) ?? 0
                            if let t = m["t"] as? String, !t.trimmingCharacters(in: .whitespaces).isEmpty {
                                fallbackTitles[station.id] = t.trimmingCharacters(in: .whitespaces)
                            }
                        }
                    }
                }
            }

            if let vlnaObj = root["vlna"] as? [String: Any] {
                self.totalVlnaListeners = (vlnaObj["total"] as? Int) ?? 0
                if let mounts = vlnaObj["mounts"] as? [String: [String: Any]] {
                    for station in stations where station.network == .vlna {
                        if let m = mounts[station.icecastMount] {
                            listenersMap[station.id] = (m["l"] as? Int) ?? 0
                            if let t = m["t"] as? String, !t.trimmingCharacters(in: .whitespaces).isEmpty {
                                fallbackTitles[station.id] = t.trimmingCharacters(in: .whitespaces)
                            }
                        }
                    }
                }
            }

            for (k, v) in listenersMap {
                self.stationListeners[k] = v
            }

            // Apply Icecast fallback track title if Sepia didn't have one
            for (stationId, rawTitle) in fallbackTitles {
                if self.stationTracks[stationId]?.isEmpty ?? true {
                    let parts = rawTitle.components(separatedBy: " - ")
                    let artist = parts.count > 1 ? parts[0] : ""
                    let song = parts.count > 1 ? parts.dropFirst().joined(separator: " - ") : rawTitle
                    self.stationTracks[stationId] = [
                        LiveTrackInfo(order: 0, artist: artist, title: song, coverURL: nil, videoURL: nil, ageSeconds: 0)
                    ]
                }
            }
        } catch {
            // Ignore transient error
        }
    }

    private func fetchExternalNetworksMetadata() async {
        async let expresTask: Void = fetchExpresMetadata()
        async let europa2Task: Void = fetchBauerArrayPlaylist(
            stationId: "europa2",
            endpoint: "https://www.europa2.sk/wp-json/radio/v1/playlist"
        )
        async let melodyTask: Void = fetchBauerArrayPlaylist(
            stationId: "melody",
            endpoint: "https://www.radiomelody.sk/wp-json/radio/v1/playlist"
        )
        async let rockTask: Void = fetchBauerArrayPlaylist(
            stationId: "bauer_rock",
            endpoint: "https://api.radiorock.sk/playlist"
        )
        async let evropa2CzTask: Void = fetchCzechActveMetadata(
            stationId: "evropa2_cz",
            channel: "evropa2"
        )
        async let frekvence1CzTask: Void = fetchCzechActveMetadata(
            stationId: "frekvence1_cz",
            channel: "frekvence1"
        )

        _ = await (expresTask, europa2Task, melodyTask, rockTask, evropa2CzTask, frekvence1CzTask)
    }

    private func fetchExpresMetadata() async {
        guard let url = URL(string: "https://www.expres.sk/wp-json/expres/v1/playlist") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = root["current"] as? [String: Any] else { return }
            let artist = (current["interpret"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let title = (current["song"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !artist.isEmpty || !title.isEmpty else { return }
            let coverStr = (current["thumb_high"] as? String) ?? (current["thumb"] as? String)
            let ytStr = (current["youtube"] as? String)

            self.stationTracks["expres"] = [
                LiveTrackInfo(
                    order: 0,
                    artist: artist,
                    title: title,
                    coverURL: coverStr.flatMap(URL.init(string:)),
                    videoURL: ytStr.flatMap(URL.init(string:)),
                    ageSeconds: 0
                )
            ]
        } catch {}
    }

    private func fetchBauerArrayPlaylist(stationId: String, endpoint: String) async {
        guard let url = URL(string: endpoint) else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let first = arr.first else { return }
            let artist = (first["artist"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let title = (first["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !artist.isEmpty || !title.isEmpty else { return }
            let coverStr = (first["imghd"] as? String) ?? (first["img"] as? String)
            let videoStr = (first["video"] as? String)

            self.stationTracks[stationId] = [
                LiveTrackInfo(
                    order: 0,
                    artist: artist,
                    title: title,
                    coverURL: coverStr.flatMap(URL.init(string:)),
                    videoURL: videoStr.flatMap(URL.init(string:)),
                    ageSeconds: 0
                )
            ]
        } catch {}
    }

    private func fetchCzechActveMetadata(stationId: String, channel: String) async {
        guard let url = URL(string: "https://rds.actve.net/v1/metadata/channel/\(channel)") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            let artist = (root["artist"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let title = (root["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !artist.isEmpty || !title.isEmpty else { return }
            let coverBase = root["coverBase"] as? String
            let coverStr = coverBase != nil ? "\(coverBase!)/300" : (root["cover"] as? String)

            self.stationTracks[stationId] = [
                LiveTrackInfo(
                    order: 0,
                    artist: artist,
                    title: title,
                    coverURL: coverStr.flatMap(URL.init(string:)),
                    videoURL: nil,
                    ageSeconds: 0
                )
            ]
        } catch {}
    }

    private func fetchShowSchedule(stationSlug: String) async -> LiveShowInfo? {
        guard let url = URL(string: "https://radiogroup-cms.vercel.app/relacie?stanica=\(stationSlug)") else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

            var allScheduled: [LiveShowInfo.ScheduledShow] = []
            if let relacieArr = root["relacie"] as? [[String: Any]] {
                for r in relacieArr {
                    let title = (r["title"] as? String) ?? ""
                    let slug = (r["slug"] as? String) ?? UUID().uuidString
                    let airtime = (r["airtime"] as? String) ?? ""
                    let imgPath = (r["image"] as? String)
                    allScheduled.append(
                        LiveShowInfo.ScheduledShow(
                            title: title,
                            slug: slug,
                            airtime: airtime,
                            imageURL: resolveFullURL(imgPath)
                        )
                    )
                }
            }

            if let teraz = root["teraz"] as? [String: Any] {
                let title = (teraz["title"] as? String) ?? ""
                let airtime = (teraz["airtime"] as? String) ?? ""
                let od = teraz["od"] as? String
                let doTime = teraz["do"] as? String
                let imgPath = teraz["image"] as? String
                if !title.isEmpty {
                    return LiveShowInfo(
                        title: title,
                        airtime: airtime,
                        startTime: od,
                        endTime: doTime,
                        imageURL: resolveFullURL(imgPath),
                        allShows: allScheduled
                    )
                }
            }
            return nil
        } catch {
            return nil
        }
    }

    private func resolveFullURL(_ pathOrURL: String?) -> URL? {
        guard let raw = pathOrURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return URL(string: raw)
        }
        let prefixed = raw.hasPrefix("/") ? "https://www.funradio.sk\(raw)" : "https://www.funradio.sk/\(raw)"
        return URL(string: prefixed)
    }

    // MARK: - History Recording

    private func recordTrackInHistoryIfNeeded() {
        guard isPlaying, let track = currentTrack(), !track.title.isEmpty else { return }
        if let latest = recentHistory.first,
           latest.artist == track.artist,
           latest.title == track.title,
           latest.stationId == currentStation.id {
            return
        }
        let item = SavedTrack(
            id: UUID().uuidString,
            artist: track.artist,
            title: track.title,
            stationId: currentStation.id,
            stationName: currentStation.name,
            coverURLString: track.coverURL?.absoluteString,
            videoURLString: track.videoURL?.absoluteString,
            timestamp: Date()
        )
        recentHistory.insert(item, at: 0)
        if recentHistory.count > 40 {
            recentHistory = Array(recentHistory.prefix(40))
        }
    }

    // MARK: - macOS Media Keys & Control Center

    private func setupRemoteMediaCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.play(station: self.currentStation)
            }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pause()
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.togglePlayPause()
            }
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.nextStation()
            }
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.previousStation()
            }
            return .success
        }
    }

    private func updateNowPlayingCenter() {
        let infoCenter = MPNowPlayingInfoCenter.default()
        var info: [String: Any] = [:]

        let track = currentTrack()
        let show = currentShow()

        info[MPMediaItemPropertyTitle] = track?.title.isEmpty == false ? track!.title : currentStation.name
        info[MPMediaItemPropertyArtist] = track?.artist.isEmpty == false ? track!.artist : (show?.title ?? currentStation.subtitle)
        info[MPMediaItemPropertyAlbumTitle] = currentStation.name
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        let targetArtURL = track?.coverURL ?? show?.imageURL
        if let targetArtURL, targetArtURL == cachedArtworkURL, let cachedArtworkImage {
            let artwork = MPMediaItemArtwork(boundsSize: cachedArtworkImage.size) { _ in cachedArtworkImage }
            info[MPMediaItemPropertyArtwork] = artwork
        } else if let targetArtURL {
            Task {
                if let img = await BroadcastMedia.artwork(targetArtURL) {
                    await MainActor.run {
                        self.cachedArtworkURL = targetArtURL
                        self.cachedArtworkImage = img
                        self.updateNowPlayingCenter()
                    }
                }
            }
        }

        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = isPlaying ? .playing : .paused
    }

    // MARK: - Persistence Helpers

    private func saveCodable<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func loadCodable<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
