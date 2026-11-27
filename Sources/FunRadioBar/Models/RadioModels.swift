import Foundation
import SwiftUI

// MARK: - Radio Network

enum RadioNetwork: String, CaseIterable, Identifiable, Codable {
    case all = "all"
    case favorites = "favorites"
    case funRadio = "funRadio"
    case vlna = "vlna"
    case bauerAndCz = "bauerAndCz"
    case stvr = "stvr"

    var id: String { rawValue }

    var badgeLabel: String {
        switch self {
        case .funRadio: return "FUN"
        case .vlna: return "VLNA"
        case .bauerAndCz: return "SK/CZ"
        case .stvr: return "STVR"
        case .all, .favorites: return "LIVE"
        }
    }

    var websiteURL: URL {
        switch self {
        case .vlna: return URL(string: "https://www.radiovlna.sk")!
        case .bauerAndCz: return URL(string: "https://www.expres.sk")!
        case .stvr: return URL(string: "https://www.stvr.sk/radia")!
        default: return URL(string: "https://www.funradio.sk")!
        }
    }
}

// MARK: - Stream Quality

enum StreamQuality: String, CaseIterable, Identifiable, Codable {
    case hd = "HD Studio"
    case standard = "Standard 128k"
    case eco = "Eco 64k"

    var id: String { rawValue }

    var badgeText: String {
        switch self {
        case .hd: return "HD 256k"
        case .standard: return "128k"
        case .eco: return "64k"
        }
    }
}

// MARK: - Menu Bar Display & Mini Player Modes

enum MenuBarLabelMode: String, CaseIterable, Identifiable, Codable {
    case liveSong = "Práve hrá (Skladba)"
    case stationName = "Názov stanice"
    case iconOnly = "Len ikona"

    var id: String { rawValue }
}

enum MiniPlayerMode: String, CaseIterable, Identifiable, Codable {
    case desktopWidget = "Desktop Widget (Na tapete)"
    case floatingTop = "Mini Player (Nad oknami)"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .desktopWidget: return "macwindow.on.rectangle"
        case .floatingTop: return "pip.enter"
        }
    }
}

// MARK: - Radio Station Definition

struct RadioStation: Identifiable, Hashable, Codable {
    let id: String
    let sepiaKey: String
    let icecastMount: String
    let name: String
    let subtitle: String
    let network: RadioNetwork
    let symbolName: String
    let primaryColorHex: UInt32
    let secondaryColorHex: UInt32
    let standardURL: String
    let hdURL: String
    let ecoURL: String

    func streamURL(for quality: StreamQuality) -> URL {
        let urlString: String
        switch quality {
        case .hd: urlString = hdURL
        case .standard: urlString = standardURL
        case .eco: urlString = ecoURL
        }
        return URL(string: urlString)!
    }

    var primaryColor: Color { Color(hex: primaryColorHex) }
    var secondaryColor: Color { Color(hex: secondaryColorHex) }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let allStations: [RadioStation] = [
        // --- 1. FUN RÁDIO NETWORK (7) ---
        RadioStation(
            id: "fun",
            sepiaKey: "funradio",
            icecastMount: "fun128.mp3",
            name: "Fun Rádio",
            subtitle: "Hity, ktoré milujete · Naživo",
            network: .funRadio,
            symbolName: "dot.radiowaves.left.and.right",
            primaryColorHex: 0xFF2D78,
            secondaryColorHex: 0x7928CA,
            standardURL: "https://stream.funradio.sk:8000/fun128.mp3",
            hdURL: "https://stream.funradio.sk:8000/funpgm256.mp3",
            ecoURL: "https://stream.funradio.sk:8000/fun64.mp3"
        ),
        RadioStation(
            id: "dance",
            sepiaKey: "dance",
            icecastMount: "dance128.mp3",
            name: "Fun Dance",
            subtitle: "Tanečné hity nonstop",
            network: .funRadio,
            symbolName: "waveform.path.ecg",
            primaryColorHex: 0x6366F1,
            secondaryColorHex: 0xEC4899,
            standardURL: "https://stream.funradio.sk:8000/dance128.mp3",
            hdURL: "https://stream.funradio.sk:8000/dance128.mp3",
            ecoURL: "https://stream.funradio.sk:8000/dance64.mp3"
        ),
        RadioStation(
            id: "chill",
            sepiaKey: "chill",
            icecastMount: "chill128.mp3",
            name: "Fun Chill",
            subtitle: "Pohodové tempo na oddych a prácu",
            network: .funRadio,
            symbolName: "leaf.fill",
            primaryColorHex: 0x10B981,
            secondaryColorHex: 0x0EA5E9,
            standardURL: "https://stream.funradio.sk:8000/chill128.mp3",
            hdURL: "https://stream.funradio.sk:8000/chill128.mp3",
            ecoURL: "https://stream.funradio.sk:8000/chill64.mp3"
        ),
        RadioStation(
            id: "8090",
            sepiaKey: "8090",
            icecastMount: "80-90-128.mp3",
            name: "Fun 80s & 90s",
            subtitle: "Legendy dvoch dekád",
            network: .funRadio,
            symbolName: "cassette.fill",
            primaryColorHex: 0x8B5CF6,
            secondaryColorHex: 0x3B82F6,
            standardURL: "https://stream.funradio.sk:8000/80-90-128.mp3",
            hdURL: "https://stream.funradio.sk:8000/80-90-128.mp3",
            ecoURL: "https://stream.funradio.sk:8000/80-90-64.mp3"
        ),
        RadioStation(
            id: "summer",
            sepiaKey: "summer",
            icecastMount: "summer128.mp3",
            name: "Fun Summer",
            subtitle: "Letný soundtrack po celý rok",
            network: .funRadio,
            symbolName: "sun.max.fill",
            primaryColorHex: 0xF97316,
            secondaryColorHex: 0xEAB308,
            standardURL: "https://stream.funradio.sk:8000/summer128.mp3",
            hdURL: "https://stream.funradio.sk:8000/summer128.mp3",
            ecoURL: "https://stream.funradio.sk:8000/summer64.mp3"
        ),
        RadioStation(
            id: "cs",
            sepiaKey: "cs",
            icecastMount: "cs128.mp3",
            name: "Fun CS",
            subtitle: "Česko a Slovensko v hitoch",
            network: .funRadio,
            symbolName: "music.mic",
            primaryColorHex: 0xEC4899,
            secondaryColorHex: 0xF43F5E,
            standardURL: "https://stream.funradio.sk:8000/cs128.mp3",
            hdURL: "https://stream.funradio.sk:8000/cs128.mp3",
            ecoURL: "https://stream.funradio.sk:8000/cs64.mp3"
        ),
        RadioStation(
            id: "mile",
            sepiaKey: "mile",
            icecastMount: "milenialky128.mp3",
            name: "Fun Mileniálky",
            subtitle: "Hity generácie Y (2000s)",
            network: .funRadio,
            symbolName: "sparkles",
            primaryColorHex: 0xEAB308,
            secondaryColorHex: 0xF59E0B,
            standardURL: "https://stream.funradio.sk:8000/milenialky128.mp3",
            hdURL: "https://stream.funradio.sk:8000/milenialky128.mp3",
            ecoURL: "https://stream.funradio.sk:8000/milenialky64.mp3"
        ),

        // --- 2. RÁDIO VLNA NETWORK (5) ---
        RadioStation(
            id: "vlna",
            sepiaKey: "vlna",
            icecastMount: "vlna-hi.mp3",
            name: "Rádio Vlna",
            subtitle: "Hity overené časom · Naživo",
            network: .vlna,
            symbolName: "water.waves",
            primaryColorHex: 0x06B6D4,
            secondaryColorHex: 0x2563EB,
            standardURL: "https://stream.radiovlna.sk/vlna-hi.mp3",
            hdURL: "https://stream.radiovlna.sk/vlna-hi.mp3",
            ecoURL: "https://stream.radiovlna.sk/vlna-lo.mp3"
        ),
        RadioStation(
            id: "gold",
            sepiaKey: "gold",
            icecastMount: "gold-hi.mp3",
            name: "Vlna Gold",
            subtitle: "Zlaté hity 60. a 70. rokov nonstop",
            network: .vlna,
            symbolName: "opticaldisc.fill",
            primaryColorHex: 0xF59E0B,
            secondaryColorHex: 0xD97706,
            standardURL: "https://stream.radiovlna.sk/gold-hi.mp3",
            hdURL: "https://stream.radiovlna.sk/gold-hi.mp3",
            ecoURL: "https://stream.radiovlna.sk/gold-lo.mp3"
        ),
        RadioStation(
            id: "balady",
            sepiaKey: "balady",
            icecastMount: "balady-hi.mp3",
            name: "Vlna Balady",
            subtitle: "Najkrajšie pomalé a zamilované hity",
            network: .vlna,
            symbolName: "heart.fill",
            primaryColorHex: 0xEC4899,
            secondaryColorHex: 0x8B5CF6,
            standardURL: "https://stream.radiovlna.sk/balady-hi.mp3",
            hdURL: "https://stream.radiovlna.sk/balady-hi.mp3",
            ecoURL: "https://stream.radiovlna.sk/balady-lo.mp3"
        ),
        RadioStation(
            id: "party",
            sepiaKey: "party",
            icecastMount: "party-hi.mp3",
            name: "Vlna Oldies Party",
            subtitle: "Nestarnúca párty klasika",
            network: .vlna,
            symbolName: "party.popper.fill",
            primaryColorHex: 0xA855F7,
            secondaryColorHex: 0xEC4899,
            standardURL: "https://stream.radiovlna.sk:8000/party-hi.mp3",
            hdURL: "https://stream.radiovlna.sk:8000/party-hi.mp3",
            ecoURL: "https://stream.radiovlna.sk/party-lo.mp3"
        ),
        RadioStation(
            id: "rock",
            sepiaKey: "rock",
            icecastMount: "rock-hi.mp3",
            name: "Vlna Rock",
            subtitle: "Rockové legendy a hymny",
            network: .vlna,
            symbolName: "guitars.fill",
            primaryColorHex: 0xEF4444,
            secondaryColorHex: 0x991B1B,
            standardURL: "https://stream.radiovlna.sk:8000/rock-hi.mp3",
            hdURL: "https://stream.radiovlna.sk:8000/rock-hi.mp3",
            ecoURL: "https://stream.radiovlna.sk/rock-lo.mp3"
        ),

        // --- 3. BAUER MEDIA SK & CZECH HIT STATIONS (6) ---
        RadioStation(
            id: "expres",
            sepiaKey: "expres",
            icecastMount: "",
            name: "Rádio Expres",
            subtitle: "Najpočúvanejšie rádio na Slovensku",
            network: .bauerAndCz,
            symbolName: "bolt.horizontal.circle.fill",
            primaryColorHex: 0xFF6B00,
            secondaryColorHex: 0xE11D48,
            standardURL: "https://stream.bauermedia.sk/expres-hi.mp3",
            hdURL: "https://stream.bauermedia.sk/expres-hi.mp3",
            ecoURL: "https://stream.bauermedia.sk/expres-lo.mp3"
        ),
        RadioStation(
            id: "europa2",
            sepiaKey: "europa2",
            icecastMount: "",
            name: "Europa 2",
            subtitle: "MaXXimum muziky · SK",
            network: .bauerAndCz,
            symbolName: "flame.fill",
            primaryColorHex: 0xE11D48,
            secondaryColorHex: 0x4F46E5,
            standardURL: "https://stream.bauermedia.sk/europa2-hi.mp3",
            hdURL: "https://stream.bauermedia.sk/europa2-hi.mp3",
            ecoURL: "https://stream.bauermedia.sk/europa2-lo.mp3"
        ),
        RadioStation(
            id: "melody",
            sepiaKey: "melody",
            icecastMount: "",
            name: "Rádio Melody",
            subtitle: "Hity vášho života",
            network: .bauerAndCz,
            symbolName: "music.quarternote.3",
            primaryColorHex: 0xD946EF,
            secondaryColorHex: 0x7C3AED,
            standardURL: "https://stream.bauermedia.sk/melody-hi.mp3",
            hdURL: "https://stream.bauermedia.sk/melody-hi.mp3",
            ecoURL: "https://stream.bauermedia.sk/melody-lo.mp3"
        ),
        RadioStation(
            id: "bauer_rock",
            sepiaKey: "bauer_rock",
            icecastMount: "",
            name: "Rádio Rock",
            subtitle: "To najlepšie z rocku nonstop",
            network: .bauerAndCz,
            symbolName: "bolt.fill",
            primaryColorHex: 0xDC2626,
            secondaryColorHex: 0x7F1D1D,
            standardURL: "https://stream.bauermedia.sk/rock-hi.mp3",
            hdURL: "https://stream.bauermedia.sk/rock-hi.mp3",
            ecoURL: "https://stream.bauermedia.sk/rock-lo.mp3"
        ),
        RadioStation(
            id: "evropa2_cz",
            sepiaKey: "evropa2_cz",
            icecastMount: "",
            name: "Evropa 2 (CZ)",
            subtitle: "Česká hudobná jednotka · Naživo",
            network: .bauerAndCz,
            symbolName: "waveform.badge.magnifyingglass",
            primaryColorHex: 0x3B82F6,
            secondaryColorHex: 0xE11D48,
            standardURL: "https://ice.actve.net/fm-evropa2-128",
            hdURL: "https://ice.actve.net/fm-evropa2-128",
            ecoURL: "https://ice.actve.net/fm-evropa2-128"
        ),
        RadioStation(
            id: "frekvence1_cz",
            sepiaKey: "frekvence1_cz",
            icecastMount: "",
            name: "Frekvence 1 (CZ)",
            subtitle: "České a svetové hity nonstop",
            network: .bauerAndCz,
            symbolName: "antenna.radiowaves.left.and.right",
            primaryColorHex: 0x0EA5E9,
            secondaryColorHex: 0x1D4ED8,
            standardURL: "https://ice.actve.net/fm-frekvence1-128",
            hdURL: "https://ice.actve.net/fm-frekvence1-128",
            ecoURL: "https://ice.actve.net/fm-frekvence1-128"
        ),

        // --- 4. STVR / SLOVENSKÝ ROZHLAS (3) ---
        RadioStation(
            id: "stvr_fm",
            sepiaKey: "stvr_fm",
            icecastMount: "",
            name: "Rádio_FM (STVR)",
            subtitle: "Alternatívna hudba, indie a elektronika",
            network: .stvr,
            symbolName: "headphones.circle.fill",
            primaryColorHex: 0x10B981,
            secondaryColorHex: 0x047857,
            standardURL: "https://icecast.stv.livebox.sk/fm_128.mp3",
            hdURL: "https://icecast.stv.livebox.sk/fm_128.mp3",
            ecoURL: "https://icecast.stv.livebox.sk/fm_128.mp3"
        ),
        RadioStation(
            id: "stvr_slovensko",
            sepiaKey: "stvr_slovensko",
            icecastMount: "",
            name: "Rádio Slovensko",
            subtitle: "Hlavný okruh STVR · Správy a hudba",
            network: .stvr,
            symbolName: "globe.europe.africa.fill",
            primaryColorHex: 0x2563EB,
            secondaryColorHex: 0x1E40AF,
            standardURL: "https://icecast.stv.livebox.sk/slovensko_128.mp3",
            hdURL: "https://icecast.stv.livebox.sk/slovensko_128.mp3",
            ecoURL: "https://icecast.stv.livebox.sk/slovensko_128.mp3"
        ),
        RadioStation(
            id: "stvr_devin",
            sepiaKey: "stvr_devin",
            icecastMount: "",
            name: "Rádio Devín",
            subtitle: "Kultúra, jazz a klasická hudba",
            network: .stvr,
            symbolName: "theatermasks.fill",
            primaryColorHex: 0x8B5CF6,
            secondaryColorHex: 0x4C1D95,
            standardURL: "https://icecast.stv.livebox.sk/devin_128.mp3",
            hdURL: "https://icecast.stv.livebox.sk/devin_128.mp3",
            ecoURL: "https://icecast.stv.livebox.sk/devin_128.mp3"
        )
    ]
}

// MARK: - Live Song & Queue Metadata

struct LiveTrackInfo: Identifiable, Equatable, Codable {
    var id: String { "\(order)-\(artist)-\(title)" }
    let order: Int // 0 = Now Playing, 1/2 = Up Next
    let artist: String
    let title: String
    let coverURL: URL?
    let videoURL: URL?
    let ageSeconds: Int

    var displayLine: String {
        if !artist.isEmpty && !title.isEmpty {
            return "\(artist) — \(title)"
        }
        return title.isEmpty ? artist : title
    }

    var spotifySearchURL: URL? {
        let query = "\(artist) \(title)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://open.spotify.com/search/\(query)")
    }

    var appleMusicSearchURL: URL? {
        let query = "\(artist) \(title)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://music.apple.com/sk/search?term=\(query)")
    }

    var youtubeWatchOrSearchURL: URL? {
        BroadcastMedia.youtube(videoURL, artist: artist, title: title)
    }
}

// MARK: - Live On-Air Show ("Práve vysiela")

struct LiveShowInfo: Equatable {
    let title: String
    let airtime: String
    let startTime: String?
    let endTime: String?
    let imageURL: URL?
    let allShows: [ScheduledShow]

    struct ScheduledShow: Identifiable, Equatable {
        var id: String { slug }
        let title: String
        let slug: String
        let airtime: String
        let imageURL: URL?
    }

    /// Calculates progress (0.0 ... 1.0) of the current on-air show in Bratislava timezone
    var showProgress: Double? {
        guard let startStr = startTime, let endStr = endTime else { return nil }
        let startParts = startStr.split(separator: ":").compactMap { Int($0) }
        let endParts = endStr.split(separator: ":").compactMap { Int($0) }
        guard startParts.count == 2, endParts.count == 2,
              (0..<24).contains(startParts[0]), (0..<60).contains(startParts[1]),
              (0..<24).contains(endParts[0]), (0..<60).contains(endParts[1]) else { return nil }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Bratislava") ?? .current
        let now = Date()
        let comps = cal.dateComponents([.hour, .minute, .second], from: now)
        let nowMinutes = Double((comps.hour ?? 0) * 60 + (comps.minute ?? 0)) + Double(comps.second ?? 0) / 60.0
        let startMinutes = Double(startParts[0] * 60 + startParts[1])
        var endMinutes = Double(endParts[0] * 60 + endParts[1])
        if endMinutes <= startMinutes { endMinutes += 24 * 60 }

        guard endMinutes > startMinutes else { return nil }
        let raw = (nowMinutes - startMinutes) / (endMinutes - startMinutes)
        return min(max(raw, 0.0), 1.0)
    }
}

// MARK: - Saved / History Track

struct SavedTrack: Identifiable, Codable, Equatable {
    let id: String
    let artist: String
    let title: String
    let stationId: String
    let stationName: String
    let coverURLString: String?
    let videoURLString: String?
    let timestamp: Date

    var coverURL: URL? {
        guard let coverURLString else { return nil }
        return URL(string: coverURLString)
    }

    var spotifySearchURL: URL? {
        let query = "\(artist) \(title)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://open.spotify.com/search/\(query)")
    }

    var youtubeURL: URL? {
        BroadcastMedia.youtube(videoURLString.flatMap(URL.init(string:)), artist: artist, title: title)
    }
}

// MARK: - Color Hex Helper

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
