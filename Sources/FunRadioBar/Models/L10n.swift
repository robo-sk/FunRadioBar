import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case en = "en"
    case sk = "sk"

    var id: String { rawValue }

    var resolved: ResolvedLanguage {
        switch self {
        case .en:
            return .en
        case .sk:
            return .sk
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            if preferred.hasPrefix("sk") || preferred.hasPrefix("cs") {
                return .sk
            }
            return .en
        }
    }

    func displayName(in lang: ResolvedLanguage) -> String {
        switch self {
        case .system:
            return lang == .sk ? "Podľa systému (Auto)" : "System Default (Auto)"
        case .en:
            return "English"
        case .sk:
            return "Slovenčina"
        }
    }
}

enum ResolvedLanguage: String {
    case en
    case sk
}

struct L10n {
    let lang: ResolvedLanguage

    // MARK: - Top Utility Bar
    var onlineSuffix: String { lang == .sk ? "online" : "listening" }
    var audioQualityTitle: String { lang == .sk ? "Kvalita zvuku" : "Audio Quality" }
    var audioQualityHelp: String {
        lang == .sk
            ? "Prepínač kvality streamu (HD 256k / 128k / Eco 64k)"
            : "Switch stream audio quality (HD 256k / 128k / Eco 64k)"
    }

    func qualityDescription(_ quality: StreamQuality) -> String {
        switch (quality, lang) {
        case (.hd, .sk): return "Štúdiová kvalita (256 kbps / Hi)"
        case (.hd, .en): return "Studio HD quality (256 kbps / Hi)"
        case (.standard, .sk): return "Štandardná kvalita (128 kbps MP3)"
        case (.standard, .en): return "Standard quality (128 kbps MP3)"
        case (.eco, .sk): return "Šetrič dát (64 kbps / Lo)"
        case (.eco, .en): return "Data saver (64 kbps / Lo)"
        }
    }

    var sleepTimerTitle: String { lang == .sk ? "Časovač vypnutia" : "Sleep Timer" }
    var sleepTimerOff: String { lang == .sk ? "Vypnúť časovač" : "Turn Off Timer" }
    func sleepTimerInMinutes(_ mins: Int) -> String {
        lang == .sk ? "Za \(mins) minút" : "In \(mins) minutes"
    }
    var sleepTimerHelp: String {
        lang == .sk ? "Časovač automatického vypnutia" : "Automatic sleep timer"
    }

    var widgetOn: String { lang == .sk ? "Widget zap." : "Widget On" }
    var miniWidget: String { lang == .sk ? "Mini Widget" : "Mini Widget" }
    var toggleWidgetHelp: String {
        lang == .sk
            ? "Zobraziť / skryť Desktop Widget alebo plávajúci Mini-Player"
            : "Show / hide Desktop Widget or floating Mini-Player"
    }
    var miniPlayerModeTitle: String { lang == .sk ? "Režim Mini-Playera" : "Mini-Player Mode" }
    var miniPlayerModeHelp: String {
        lang == .sk
            ? "Zmeniť režim: Widget na ploche vs. Plávajúce okno"
            : "Switch mode: Desktop Wallpaper Widget vs. Floating Window"
    }

    func miniPlayerModeName(_ mode: MiniPlayerMode) -> String {
        switch (mode, lang) {
        case (.desktopWidget, .sk): return "Desktop Widget (Na tapete)"
        case (.desktopWidget, .en): return "Desktop Widget (On Wallpaper)"
        case (.floatingTop, .sk): return "Mini Player (Nad oknami)"
        case (.floatingTop, .en): return "Mini Player (Always on Top)"
        }
    }

    func miniPlayerPinHelp(_ mode: MiniPlayerMode) -> String {
        switch (mode, lang) {
        case (.desktopWidget, .sk):
            return "Režim: Desktop Widget (na tapete). Kliknutím prepnete na plávajúce okno nad aplikáciami."
        case (.desktopWidget, .en):
            return "Mode: Desktop Widget (pinned to wallpaper). Click to float above windows."
        case (.floatingTop, .sk):
            return "Režim: Plávajúce okno (Always on Top). Kliknutím pripnete na plochu ako widget."
        case (.floatingTop, .en):
            return "Mode: Floating Window (Always on Top). Click to pin to desktop wallpaper."
        }
    }

    var hideMiniPlayerHelp: String { lang == .sk ? "Skryť Mini Player" : "Hide Mini Player" }

    // MARK: - Hero & Now Playing
    var listeningSuffix: String { lang == .sk ? "počúva" : "listening" }
    var savedBadge: String { lang == .sk ? "Uložené" : "Saved" }
    var saveButton: String { lang == .sk ? "Uložiť" : "Save" }
    var videoClipButton: String { lang == .sk ? "Klip" : "Video" }
    var copyTrackHelp: String { lang == .sk ? "Skopírovať názov skladby" : "Copy track title" }
    var upNextPrefix: String { lang == .sk ? "NASLEDUJE:" : "UP NEXT:" }
    var upNextMiniPrefix: String { lang == .sk ? "Nasleduje:" : "Up next:" }
    var onAirBadge: String { lang == .sk ? "PRÁVE VYSIELA" : "ON AIR NOW" }
    var liveBadge: String { lang == .sk ? "NAŽIVO" : "LIVE" }

    // MARK: - Transport Controls
    func muteHelp(isMuted: Bool) -> String {
        if isMuted { return lang == .sk ? "Zapnúť zvuk" : "Unmute" }
        return lang == .sk ? "Stíšiť zvuk" : "Mute"
    }
    var previousStationHelp: String { lang == .sk ? "Predchádzajúca stanica" : "Previous station" }
    var nextStationHelp: String { lang == .sk ? "Ďalšia stanica" : "Next station" }
    var pauseButton: String { lang == .sk ? "Pozastaviť" : "Pause" }
    var playLiveButton: String { lang == .sk ? "Pustiť naživo" : "Play Live" }
    var checkAvailability: String { lang == .sk ? "Overiť dostupnosť" : "Check Availability" }

    func stationStatus(_ availability: StationAvailability) -> String? {
        switch availability {
        case .checking: return lang == .sk ? "Overuje sa dostupnosť…" : "Checking availability…"
        case .unavailable: return lang == .sk ? "Momentálne nedostupná" : "Unavailable for now"
        case .unknown, .available: return nil
        }
    }

    var removeLikedHelp: String { lang == .sk ? "Odobrať z uložených skladieb" : "Remove from saved songs" }
    var addLikedHelp: String { lang == .sk ? "Uložiť skladbu do obľúbených" : "Save song to favorites" }
    var removeFavStationHelp: String { lang == .sk ? "Odobrať z obľúbených" : "Remove from favorites" }
    var addFavStationHelp: String { lang == .sk ? "Pridať do obľúbených" : "Add to favorites" }

    // MARK: - Tabs & Filters
    var rescanStations: String { lang == .sk ? "Vyhľadať stanice" : "Rescan Stations" }
    var rescanningStations: String { lang == .sk ? "Vyhľadávajú sa stanice…" : "Rescanning stations…" }
    var rescanFailed: String { lang == .sk ? "Zoznam staníc sa nepodarilo načítať." : "Couldn’t load the station list." }
    var rescanHelp: String {
        lang == .sk ? "Aktualizovať zoznam staníc a overiť prehrávanie v zvolenej kvalite."
                    : "Update the station list and check which streams play at the selected quality."
    }
    func showUnavailable(_ count: Int) -> String {
        lang == .sk ? "Zobraziť nedostupné stanice (\(count))" : "Show unavailable stations (\(count))"
    }
    var chooseStationHelp: String { lang == .sk ? "Vybrať stanicu" : "Choose a station" }

    func tabTitle(_ tab: ContentTab, stationCount: Int) -> String {
        switch (tab, lang) {
        case (.stations, .sk): return "Stanice (\(stationCount))"
        case (.stations, .en): return "Stations (\(stationCount))"
        case (.program, .sk): return "Program & Rad"
        case (.program, .en): return "Schedule & Queue"
        case (.history, .sk): return "História"
        case (.history, .en): return "History"
        }
    }

    func networkFilterName(_ net: RadioNetwork, stationCount: Int) -> String {
        switch (net, lang) {
        case (.all, .sk): return "Všetky (\(stationCount))"
        case (.all, .en): return "All (\(stationCount))"
        case (.favorites, .sk): return "Obľúbené"
        case (.favorites, .en): return "Favorites"
        case (.funRadio, _): return "Fun Rádio"
        case (.vlna, _): return "Rádio Vlna"
        case (.bauerAndCz, .sk): return "SK & CZ Hity"
        case (.bauerAndCz, .en): return "SK & CZ Hits"
        case (.stvr, _): return "STVR"
        case (.somaFM, _): return "SomaFM Chill"
        }
    }

    func networkSectionTitle(_ net: RadioNetwork, stationCount: Int) -> String {
        let name: String
        switch net {
        case .stvr: name = lang == .sk ? "STVR / Verejnoprávne" : "STVR Public Radio"
        case .somaFM: name = "SomaFM Focus & Chill"
        default: name = networkFilterName(net, stationCount: stationCount)
        }
        let stationWord: String
        if lang == .sk {
            switch stationCount {
            case 1: stationWord = "stanica"
            case 2...4: stationWord = "stanice"
            default: stationWord = "staníc"
            }
        } else {
            stationWord = stationCount == 1 ? "station" : "stations"
        }
        return "\(name) (\(stationCount) \(stationWord))"
    }

    // MARK: - Schedule & Queue Tab
    var upcomingTracksHeader: String { lang == .sk ? "NASLEDUJÚCE SKLADBY" : "UPCOMING SONGS" }
    var comingUpBadge: String { lang == .sk ? "o chvíľu" : "up next" }
    var showsAndHostsHeader: String { lang == .sk ? "RELÁCIE A MODERÁTORI" : "SHOWS & HOSTS" }

    // MARK: - History & Saved Tab
    func recentHistoryCount(_ count: Int) -> String {
        lang == .sk ? "Naposledy hrané (\(count))" : "Recently Played (\(count))"
    }
    func likedTracksCount(_ count: Int) -> String {
        lang == .sk ? "Uložené skladby (\(count))" : "Saved Songs (\(count))"
    }
    var emptyHistoryText: String {
        lang == .sk ? "Zatiaľ žiadna história prehrávania." : "No playback history yet."
    }
    var emptyLikedText: String {
        lang == .sk ? "Zatiaľ nemáte uložené žiadne obľúbené skladby." : "No saved favorite songs yet."
    }
    var openInSpotifyHelp: String { lang == .sk ? "Otvoriť v Spotify" : "Open in Spotify" }
    var openInYouTubeHelp: String { lang == .sk ? "Otvoriť na YouTube" : "Open on YouTube" }

    // MARK: - Footer Bar
    var menuBarTitle: String { lang == .sk ? "Horná lišta" : "Menu Bar" }
    var menuBarLabelPickerTitle: String {
        lang == .sk ? "Text v hornej lište (Menu Bar)" : "Menu Bar Title Display"
    }

    func menuBarLabelModeName(_ mode: MenuBarLabelMode) -> String {
        switch (mode, lang) {
        case (.liveSong, .sk): return "Práve hrá (Skladba)"
        case (.liveSong, .en): return "Now Playing (Song)"
        case (.stationName, .sk): return "Názov stanice"
        case (.stationName, .en): return "Station Name"
        case (.iconOnly, .sk): return "Len ikona"
        case (.iconOnly, .en): return "Icon Only"
        }
    }

    var languagePickerTitle: String { lang == .sk ? "Jazyk aplikácie" : "App Language" }
    var refreshInfo: String { lang == .sk ? "Obnoviť údaje" : "Refresh Info" }
    var refreshHelp: String {
        lang == .sk ? "Obnoviť informácie o skladbách, počty poslucháčov a program."
                    : "Refresh song information, listener counts and the programme schedule."
    }
    var openWebsiteHelp: String { lang == .sk ? "Otvoriť web stanice" : "Open station website" }
    var checkForUpdates: String { lang == .sk ? "Vyhľadať aktualizácie aplikácie…" : "Check for App Updates…" }
    var automaticUpdates: String { lang == .sk ? "Automaticky hľadať aktualizácie" : "Automatically Check for Updates" }
    func updateAvailable(_ version: String) -> String {
        lang == .sk ? "Aktualizácia na verziu \(version)…" : "Update to version \(version)…"
    }
    var quitButton: String { lang == .sk ? "Ukončiť" : "Quit" }

    // MARK: - Dynamic Content Helpers (Station Subtitles & Show Airtimes)

    func stationSubtitle(_ station: RadioStation) -> String {
        guard lang == .en else { return station.subtitle }
        switch station.id {
        case "fun": return "Hits You Love · Live Broadcast"
        case "dance": return "Non-stop Dance & Club Hits"
        case "chill": return "Relaxing Chillout & Focus Beats"
        case "8090": return "Legends of the 80s & 90s"
        case "summer": return "Summer Vibes All Year Round"
        case "cs": return "Czech & Slovak Greatest Hits"
        case "mile": return "Millennial & 2000s Pop Hits"
        case "vlna": return "Timeless Classics · Live Broadcast"
        case "gold": return "Golden 60s & 70s Hits Non-stop"
        case "balady": return "Greatest Love Songs & Ballads"
        case "party": return "Timeless Oldies Party Classics"
        case "rock": return "Rock Legends & Anthems"
        case "expres": return "Slovakia's #1 Hit Radio · Live"
        case "europa2": return "MaXXimum Music & New Pop · SK"
        case "melody": return "Hits of Your Life · Soft Pop"
        case "bauer_rock": return "The Best of Rock Non-stop"
        case "evropa2_cz": return "Czechia's #1 Hit Music Station · Live"
        case "frekvence1_cz": return "Czech & International Hits Non-stop"
        case "stvr_fm": return "Alternative, Indie & Electronic · STVR"
        case "stvr_slovensko": return "STVR Main Public Channel · News & Music"
        case "stvr_devin": return "Culture, Jazz & Classical Music · STVR"
        case "soma_groovesalad": return "Ambient & Downtempo Beats for Focus"
        case "soma_defcon": return "Music for Hacking, Coding & Focus"
        case "soma_secretagent": return "Spy Lounge, Cool Jazz & Soundtracks"
        case "soma_u80s": return "Early 80s Synthpop & UK New Wave"
        default: return station.subtitle
        }
    }

    func localizeAirtime(_ raw: String) -> String {
        guard lang == .en, !raw.isEmpty else { return raw }
        var s = raw
        let replacements: [(String, String)] = [
            ("po-pia", "Mon–Fri"),
            ("po-štv", "Mon–Thu"),
            ("ut-štv", "Tue–Thu"),
            ("so-ne", "Sat–Sun"),
            ("pondelok", "Monday"),
            ("utorok", "Tuesday"),
            ("streda", "Wednesday"),
            ("štvrtok", "Thursday"),
            ("piatok", "Friday"),
            ("sobota", "Saturday"),
            ("nedeľa", "Sunday")
        ]
        for (sk, en) in replacements {
            s = s.replacingOccurrences(of: sk, with: en, options: .caseInsensitive)
        }
        return s
    }
}
