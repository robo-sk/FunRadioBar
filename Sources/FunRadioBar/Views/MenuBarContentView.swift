import SwiftUI
import AppKit

enum ContentTab: String, CaseIterable, Identifiable {
    case stations = "stations"
    case program = "program"
    case history = "history"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .stations: return "dot.radiowaves.left.and.right"
        case .program: return "person.wave.2.fill"
        case .history: return "heart.text.square.fill"
        }
    }
}

struct MenuBarContentView: View {
    @ObservedObject var manager: RadioPlayerManager
    @ObservedObject private var updates = AppUpdates.shared
    @Environment(\.openURL) private var openURL

    @State private var activeTab: ContentTab = .stations
    @State private var historySubTab: Int = 0 // 0 = Recent, 1 = Liked
    @State private var copiedFeedback: Bool = false

    // High-contrast dark palette (independent of macOS Light/Dark mode)
    private let bgBase = Color(hex: 0x0B0E17)
    private let cardSurface = Color(hex: 0x151A28)
    private let cardElevated = Color(hex: 0x1C2235)
    private let textPrimary = Color.white
    private let textSecondary = Color(hex: 0xD8E2F0)
    private let textMuted = Color(hex: 0x94A3B8)

    private var l10n: L10n { manager.l10n }
    private var currentStationStatus: String? {
        l10n.stationStatus(manager.availability(for: manager.currentStation))
    }

    private var currentTrack: LiveTrackInfo? {
        currentStationStatus == nil ? manager.currentTrack() : nil
    }

    private var currentShow: LiveShowInfo? {
        currentStationStatus == nil ? manager.currentShow() : nil
    }

    var body: some View {
        ZStack {
            // Solid deep obsidian base so Light Mode never washes out the popover
            bgBase

            // Subtle ambient station glow at top
            RadialGradient(
                colors: [
                    manager.currentStation.primaryColor.opacity(0.26),
                    manager.currentStation.secondaryColor.opacity(0.10),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 10,
                endRadius: 340
            )

            VStack(spacing: 0) {
                // 1. Top Toolbar
                topUtilityBar
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // 2. Hero Now Playing Card
                heroNowPlayingCard
                    .padding(.horizontal, 14)

                // 3. On-Air Moderator Banner ("Práve vysiela" / "On Air Now")
                if let show = currentShow {
                    onAirShowBanner(show: show)
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                }

                // 4. Transport & Volume Bar
                transportAndVolumeRow
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                Divider()
                    .overlay(Color.white.opacity(0.10))

                // 5. Navigation Tabs (Stations / Schedule & Queue / History)
                tabSelectorBar
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                // 6. Tab Content Area
                Group {
                    switch activeTab {
                    case .stations:
                        stationsTabView
                    case .program:
                        programAndQueueTabView
                    case .history:
                        historyAndLikedTabView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                    .overlay(Color.white.opacity(0.10))

                // 7. Bottom Footer Bar
                if manager.rescanFailed {
                    Text(l10n.rescanFailed)
                        .font(.caption)
                        .foregroundStyle(textSecondary)
                }
                footerBar
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: 0x080A11))
            }
        }
        .frame(width: 410, height: 640)
        .overlay { PlayerToolTips().allowsHitTesting(false) }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - 1. Top Utility Bar

    private var topUtilityBar: some View {
        HStack(spacing: 7) {
            // Live Total Listeners Badge
            HStack(spacing: 5) {
                LivePulseDot()
                let (sum, overflow) = max(0, manager.totalFunListeners).addingReportingOverflow(max(0, manager.totalVlnaListeners))
                let total = overflow ? 0 : sum
                Text(total > 0 ? "\(RadioFormatters.formatListeners(total)) \(l10n.onlineSuffix)" : "FUN & VLNA LIVE")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(cardElevated, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))

            Spacer()

            // Quality Picker Menu
            Menu {
                Picker(l10n.audioQualityTitle, selection: $manager.streamQuality) {
                    ForEach(StreamQuality.allCases) { q in
                        Text("\(q.rawValue) — \(l10n.qualityDescription(q))").tag(q)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(manager.currentStation.primaryColor)
                    Text(manager.streamQuality.badgeText)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(textMuted)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(cardElevated, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .controlHelp(l10n.audioQualityHelp)

            // Sleep Timer Menu
            Menu {
                Section(l10n.sleepTimerTitle) {
                    Button(l10n.sleepTimerOff) { manager.setSleepTimer(minutes: nil) }
                    Divider()
                    Button(l10n.sleepTimerInMinutes(15)) { manager.setSleepTimer(minutes: 15) }
                    Button(l10n.sleepTimerInMinutes(30)) { manager.setSleepTimer(minutes: 30) }
                    Button(l10n.sleepTimerInMinutes(45)) { manager.setSleepTimer(minutes: 45) }
                    Button(l10n.sleepTimerInMinutes(60)) { manager.setSleepTimer(minutes: 60) }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: manager.sleepTimerRemainingText != nil ? "moon.zzz.fill" : "moon.stars.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(manager.sleepTimerRemainingText != nil ? Color(hex: 0xFBBF24) : textSecondary)
                    if let remaining = manager.sleepTimerRemainingText {
                        Text(remaining)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: 0xFBBF24))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(cardElevated, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .controlHelp(l10n.sleepTimerHelp)

            // Desktop Widget / Mini-Player Toggle + Mode Menu
            HStack(spacing: 3) {
                Button {
                    manager.toggleMiniPlayer()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: manager.miniPlayerMode.icon)
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(manager.isMiniPlayerVisible ? l10n.widgetOn : l10n.miniWidget)
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(textPrimary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(
                        manager.isMiniPlayerVisible
                            ? AnyShapeStyle(manager.currentStation.gradient)
                            : AnyShapeStyle(cardElevated),
                        in: Capsule()
                    )
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .controlHelp(l10n.toggleWidgetHelp)

                Menu {
                    Picker(l10n.miniPlayerModeTitle, selection: $manager.miniPlayerMode) {
                        ForEach(MiniPlayerMode.allCases) { mode in
                            Label(l10n.miniPlayerModeName(mode), systemImage: mode.icon).tag(mode)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(textSecondary)
                        .frame(width: 22, height: 22)
                        .background(cardElevated, in: Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .controlHelp(l10n.miniPlayerModeHelp)
            }
        }
    }

    // MARK: - 2. Hero Now Playing Card

    private var heroNowPlayingCard: some View {
        let artworkURL = currentTrack?.coverURL ?? currentShow?.imageURL
        let stationListeners = currentStationStatus == nil ? manager.listenersCount() : 0
        let artist = currentTrack?.artist ?? ""
        let stationDetail = currentStationStatus ?? (artist.isEmpty ? l10n.stationSubtitle(manager.currentStation) : artist)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                // High-res Album Art / Show Avatar
                ZStack(alignment: .bottomTrailing) {
                    ArtworkThumbnailView(
                        imageURL: artworkURL,
                        station: manager.currentStation,
                        size: 84,
                        cornerRadius: 18
                    )

                    if manager.isPlaying {
                        AnimatedEqualizerView(
                            isPlaying: !manager.isBuffering,
                            color: .white,
                            barCount: 4,
                            height: 11
                        )
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(manager.currentStation.primaryColor, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.black.opacity(0.3), lineWidth: 1))
                        .offset(x: 4, y: 4)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Station Badge + Listener Count
                    HStack(spacing: 6) {
                        Text(manager.currentStation.name.uppercased())
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(manager.currentStation.gradient, in: Capsule())

                        if stationListeners > 0 {
                            HStack(spacing: 3.5) {
                                Image(systemName: "headphones")
                                    .font(.system(size: 9.5, weight: .semibold))
                                Text("\(RadioFormatters.formatListeners(stationListeners)) \(l10n.listeningSuffix)")
                                    .font(.system(size: 10.5, weight: .semibold))
                            }
                            .foregroundStyle(textSecondary)
                        }
                    }

                    // Song Title
                    Text(currentTrack?.title.isEmpty == false ? currentTrack!.title : manager.currentStation.name)
                        .font(.system(size: 16.5, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Artist Name
                    Text(stationDetail)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            // Action Pills: Like, Spotify, YouTube, Copy
            if let track = currentTrack, !track.title.isEmpty {
                HStack(spacing: 6) {
                    let isLiked = manager.isTrackLiked(track)
                    Button {
                        manager.toggleLikeCurrentTrack()
                    } label: {
                        Label(isLiked ? l10n.savedBadge : l10n.saveButton, systemImage: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isLiked ? Color(hex: 0xFF2D78) : textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(cardElevated, in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .controlHelp(isLiked ? l10n.removeLikedHelp : l10n.addLikedHelp)

                    if let spotifyURL = track.spotifySearchURL {
                        Button {
                            openURL(spotifyURL)
                        } label: {
                            Label("Spotify", systemImage: "music.note.list")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(hex: 0x1ED760))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(cardElevated, in: Capsule())
                                .overlay(Capsule().strokeBorder(Color(hex: 0x1ED760).opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .controlHelp(l10n.openInSpotifyHelp)
                    }

                    if let ytURL = track.youtubeWatchOrSearchURL {
                        Button {
                            openURL(ytURL)
                        } label: {
                            Label(track.videoURL != nil ? l10n.videoClipButton : "YouTube", systemImage: "play.rectangle.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(hex: 0xFF6B6B))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(cardElevated, in: Capsule())
                                .overlay(Capsule().strokeBorder(Color(hex: 0xFF6B6B).opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .controlHelp(l10n.openInYouTubeHelp)
                    }

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(track.displayLine, forType: .string)
                        copiedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copiedFeedback = false
                        }
                    } label: {
                        Image(systemName: copiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(copiedFeedback ? Color(hex: 0x10B981) : textSecondary)
                            .frame(width: 24, height: 22)
                            .background(cardElevated, in: Circle())
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .controlHelp(l10n.copyTrackHelp)
                }
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            }

            // Up Next Preview Strip ("Nasleduje" / "Up Next") if Sepia provides poradie 1/2
            let upcoming = manager.upcomingTracks()
            if !upcoming.isEmpty {
                HStack(spacing: 6) {
                    Text(l10n.upNextPrefix)
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(manager.currentStation.primaryColor)

                    Text(upcoming.map { "\($0.artist) – \($0.title)" }.joined(separator: "  •  "))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: 0x0F131F), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    manager.currentStation.primaryColor.opacity(0.45),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
        )
    }

    // MARK: - 3. On-Air Moderator Banner ("Práve vysiela" / "On Air Now")

    private func onAirShowBanner(show: LiveShowInfo) -> some View {
        HStack(spacing: 10) {
            if let imgURL = show.imageURL {
                BroadcastImage(url: imgURL) { phase in
                    if case .success(let img) = phase {
                        img.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(manager.currentStation.gradient)
                            .frame(width: 36, height: 36)
                            .overlay(Image(systemName: "mic.fill").font(.system(size: 14)).foregroundStyle(.white))
                    }
                }
                .overlay(Circle().strokeBorder(manager.currentStation.primaryColor, lineWidth: 1.5))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(l10n.onAirBadge)
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(manager.currentStation.primaryColor)
                    if !show.airtime.isEmpty {
                        Text("· \(l10n.localizeAirtime(show.airtime))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(textMuted)
                    }
                }

                Text(show.title)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            // Show Progress Indicator
            if let progress = show.showProgress {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(textSecondary)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.16))
                            Capsule()
                                .fill(manager.currentStation.gradient)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(width: 56, height: 5)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.11), lineWidth: 1)
                )
        )
    }

    // MARK: - 4. Transport & Volume Controls

    private var transportAndVolumeRow: some View {
        let station = manager.currentStation
        let active = manager.isPlaying || manager.isBuffering
        let needsCheck = !active && currentStationStatus != nil
        let checking = needsCheck && manager.availability(for: station) == .checking

        return HStack(spacing: 14) {
            HStack(spacing: 10) {
                Button {
                    manager.previousStation()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(textPrimary)
                        .frame(width: 32, height: 32)
                        .background(cardElevated, in: Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .controlHelp(l10n.previousStationHelp)

                Button {
                    if needsCheck {
                        Task { await manager.checkAvailability(for: station) }
                    } else {
                        manager.togglePlayPause()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if manager.isBuffering || checking {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: active ? "pause.fill" : needsCheck ? "arrow.clockwise" : "play.fill")
                                .font(.system(size: 13, weight: .bold))
                        }
                        Text(active ? l10n.pauseButton : needsCheck ? l10n.checkAvailability : l10n.playLiveButton)
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, needsCheck ? 10 : 16)
                    .frame(height: 34)
                    .background(manager.currentStation.gradient, in: Capsule())
                    .shadow(color: manager.currentStation.primaryColor.opacity(0.45), radius: 8, y: 2)
                }
                .buttonStyle(.plain)
                .controlHelp(active ? l10n.pauseButton : needsCheck ? l10n.checkAvailability : l10n.playLiveButton)
                .disabled(checking)

                Button {
                    manager.nextStation()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(textPrimary)
                        .frame(width: 32, height: 32)
                        .background(cardElevated, in: Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .controlHelp(l10n.nextStationHelp)
            }

            Spacer()

            // Volume Slider
            HStack(spacing: 7) {
                Button {
                    manager.isMuted.toggle()
                } label: {
                    Image(systemName: volumeIconName)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(textSecondary)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                .controlHelp(l10n.muteHelp(isMuted: manager.isMuted))

                Slider(
                    value: Binding(
                        get: { Double(manager.isMuted ? 0 : manager.volume) },
                        set: { newVal in
                            if manager.isMuted && newVal > 0 { manager.isMuted = false }
                            manager.volume = Float(newVal)
                        }
                    ),
                    in: 0...1
                )
                .controlSize(.small)
                .frame(width: 105)
                .tint(manager.currentStation.primaryColor)
            }
        }
    }

    private var volumeIconName: String {
        if manager.isMuted || manager.volume == 0 { return "speaker.slash.fill" }
        if manager.volume < 0.35 { return "speaker.wave.1.fill" }
        if manager.volume < 0.75 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    // MARK: - 5. Tab Selector Bar

    private var tabSelectorBar: some View {
        HStack(spacing: 6) {
            ForEach(ContentTab.allCases) { tab in
                let isSelected = activeTab == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        activeTab = tab
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(l10n.tabTitle(tab, stationCount: manager.stations.count))
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(isSelected ? textPrimary : textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6.5)
                    .background(
                        isSelected
                            ? AnyShapeStyle(cardElevated)
                            : AnyShapeStyle(Color.clear),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(isSelected ? Color.white.opacity(0.15) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .controlHelp(l10n.tabTitle(tab, stationCount: manager.stations.count))
            }
        }
        .padding(3.5)
        .background(cardSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - 6A. Stations List Tab

    private var stationsTabView: some View {
        let sections = manager.stationSections(in: manager.filteredStations)
        return VStack(spacing: 8) {
            // Horizontally scrollable Network Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(RadioNetwork.allCases) { net in
                        let selected = manager.selectedNetworkFilter == net
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                manager.selectedNetworkFilter = net
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if net == .favorites {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9.5))
                                        .foregroundStyle(Color(hex: 0xFBBF24))
                                }
                                Text(l10n.networkFilterName(net, stationCount: manager.stations.count))
                                    .font(.system(size: 11, weight: selected ? .bold : .semibold, design: .rounded))
                            }
                            .foregroundStyle(selected ? textPrimary : textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                selected ? cardElevated : cardSurface,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        selected ? manager.currentStation.primaryColor.opacity(0.6) : Color.white.opacity(0.09),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .controlHelp(l10n.networkFilterName(net, stationCount: manager.stations.count))
                    }
                }
                .padding(.horizontal, 14)
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(sections.regular) { station in
                        stationRow(station: station)
                    }
                    if !sections.unavailable.isEmpty {
                        Toggle(l10n.showUnavailable(sections.unavailable.count), isOn: $manager.showsUnavailableStations)
                            .toggleStyle(.checkbox)
                            .font(.callout)
                            .foregroundStyle(textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if manager.showsUnavailableStations {
                            ForEach(sections.unavailable) { station in
                                stationRow(station: station)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
    }

    private func stationRow(station: RadioStation) -> some View {
        let isCurrent = manager.currentStation.id == station.id
        let isActivePlaying = isCurrent && (manager.isPlaying || manager.isBuffering)
        let availability = manager.availability(for: station)
        let status = l10n.stationStatus(availability)
        let liveTrack = status == nil ? manager.currentTrack(for: station) : nil
        let listeners = status == nil ? manager.listenersCount(for: station) : 0
        let isFav = manager.isFavoriteStation(station)

        return HStack(spacing: 11) {
            // Station Thumbnail / Live Cover
            ZStack {
                ArtworkThumbnailView(
                    imageURL: liveTrack?.coverURL,
                    station: station,
                    size: 44,
                    cornerRadius: 11
                )

                if isActivePlaying {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 44, height: 44)
                    AnimatedEqualizerView(
                        isPlaying: !manager.isBuffering,
                        color: .white,
                        barCount: 4,
                        height: 14
                    )
                }
            }

            // Station Name + What's Currently Playing on this station
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(station.name)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(isCurrent ? station.primaryColor : textPrimary)

                    Text(station.network.badgeLabel)
                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(textSecondary)
                        .padding(.horizontal, 5.5)
                        .padding(.vertical, 1.5)
                        .background(Color.white.opacity(0.10), in: Capsule())

                    if listeners > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 8.5))
                            Text(RadioFormatters.formatListeners(listeners))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        }
                        .foregroundStyle(textMuted)
                    }
                }

                if let liveTrack, !liveTrack.title.isEmpty {
                    HStack(spacing: 4.5) {
                        Image(systemName: "music.note")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(station.primaryColor)
                        Text(liveTrack.displayLine)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(textSecondary)
                            .lineLimit(1)
                    }
                } else {
                    Text(status ?? l10n.stationSubtitle(station))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(textMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            // Favorite Star Button
            Button {
                manager.toggleFavoriteStation(station)
            } label: {
                Image(systemName: isFav ? "star.fill" : "star")
                    .font(.system(size: 12.5))
                    .foregroundStyle(isFav ? Color(hex: 0xFBBF24) : textMuted.opacity(0.6))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .controlHelp(isFav ? l10n.removeFavStationHelp : l10n.addFavStationHelp)

            if status != nil && !isActivePlaying {
                Button {
                    Task { await manager.checkAvailability(for: station) }
                } label: {
                    if availability == .checking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(l10n.checkAvailability, systemImage: "arrow.clockwise")
                            .font(.system(size: 10, weight: .semibold))
                            .fixedSize()
                    }
                }
                .foregroundStyle(textSecondary)
                .buttonStyle(.plain)
                .accessibilityLabel("\(l10n.checkAvailability) · \(station.name)")
                .controlHelp(l10n.checkAvailability)
                .disabled(availability == .checking)
            } else {
                Image(systemName: isActivePlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 21))
                    .foregroundStyle(isCurrent ? station.primaryColor : textSecondary)
                    .controlHelp(isActivePlaying ? l10n.pauseButton : l10n.playLiveButton)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(isCurrent ? cardElevated : cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(
                            isCurrent ? station.primaryColor.opacity(0.75) : Color.white.opacity(0.09),
                            lineWidth: isCurrent ? 1.4 : 1
                        )
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard status == nil || isActivePlaying else { return }
            if isCurrent {
                manager.togglePlayPause()
            } else {
                manager.play(station: station)
            }
        }
    }

    // MARK: - 6B. Program & Queue Tab

    private var programAndQueueTabView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // Section 1: Upcoming Songs Queue
                let upcoming = currentStationStatus == nil ? manager.upcomingTracks() : []
                if !upcoming.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("\(l10n.upcomingTracksHeader) · \(manager.currentStation.name.uppercased())")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(textMuted)

                        ForEach(upcoming) { item in
                            HStack(spacing: 10) {
                                ArtworkThumbnailView(
                                    imageURL: item.coverURL,
                                    station: manager.currentStation,
                                    size: 38,
                                    cornerRadius: 9
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 12.5, weight: .bold))
                                        .foregroundStyle(textPrimary)
                                    Text(item.artist)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(textSecondary)
                                }
                                Spacer()
                                Text(l10n.comingUpBadge)
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(manager.currentStation.primaryColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(manager.currentStation.primaryColor.opacity(0.18), in: Capsule())
                            }
                            .padding(8)
                            .background(cardSurface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }
                }

                // Section 2: Fun Rádio & Rádio Vlna Live Broadcast Schedule
                if let showInfo = manager.currentShow(), !showInfo.allShows.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(l10n.showsAndHostsHeader) · \(manager.currentStation.network == .vlna ? "RÁDIO VLNA" : "FUN RÁDIO")")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(textMuted)

                        ForEach(showInfo.allShows) { rel in
                            let isNowOnAir = rel.title == showInfo.title
                            HStack(spacing: 11) {
                                if let url = rel.imageURL {
                                    BroadcastImage(url: url) { phase in
                                        if case .success(let image) = phase {
                                            image.resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 42, height: 42)
                                                .clipShape(Circle())
                                        } else {
                                            Circle().fill(manager.currentStation.gradient).frame(width: 42, height: 42)
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(rel.title)
                                            .font(.system(size: 12.5, weight: .bold))
                                            .foregroundStyle(textPrimary)
                                        if isNowOnAir {
                                            Text(l10n.onAirBadge)
                                                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(manager.currentStation.gradient, in: Capsule())
                                        }
                                    }
                                    Text(l10n.localizeAirtime(rel.airtime))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(textSecondary)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isNowOnAir ? cardElevated : cardSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(
                                                isNowOnAir ? manager.currentStation.primaryColor.opacity(0.6) : Color.white.opacity(0.08),
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
    }

    // MARK: - 6C. History & Liked Songs Tab

    private var historyAndLikedTabView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    historySubTab = 0
                } label: {
                    Text(l10n.recentHistoryCount(manager.recentHistory.count))
                        .font(.system(size: 11, weight: historySubTab == 0 ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(historySubTab == 0 ? textPrimary : textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(historySubTab == 0 ? cardElevated : cardSurface, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    historySubTab = 1
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Color(hex: 0xFF2D78))
                        Text(l10n.likedTracksCount(manager.likedTracks.count))
                            .font(.system(size: 11, weight: historySubTab == 1 ? .bold : .semibold, design: .rounded))
                    }
                    .foregroundStyle(historySubTab == 1 ? textPrimary : textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(historySubTab == 1 ? cardElevated : cardSurface, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .controlHelp(l10n.likedTracksCount(manager.likedTracks.count))

                Spacer()
            }
            .padding(.horizontal, 14)

            let items = historySubTab == 0 ? manager.recentHistory : manager.likedTracks
            if items.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: historySubTab == 0 ? "clock.arrow.circlepath" : "heart.slash")
                        .font(.system(size: 26))
                        .foregroundStyle(textMuted)
                    Text(historySubTab == 0 ? l10n.emptyHistoryText : l10n.emptyLikedText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(textSecondary)
                    Spacer()
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(items) { track in
                            HStack(spacing: 10) {
                                ArtworkThumbnailView(
                                    imageURL: track.coverURL,
                                    station: manager.currentStation,
                                    size: 38,
                                    cornerRadius: 9
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(textPrimary)
                                        .lineLimit(1)
                                    HStack(spacing: 5) {
                                        Text(track.artist)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(textSecondary)
                                            .lineLimit(1)
                                        Text("· \(track.stationName)")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(textMuted)
                                    }
                                }

                                Spacer()

                                if let sp = track.spotifySearchURL {
                                    Button {
                                        openURL(sp)
                                    } label: {
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color(hex: 0x1ED760))
                                            .frame(width: 26, height: 26)
                                            .background(cardElevated, in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .controlHelp(l10n.openInSpotifyHelp)
                                }

                                if let yt = track.youtubeURL {
                                    Button {
                                        openURL(yt)
                                    } label: {
                                        Image(systemName: "play.rectangle.fill")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color(hex: 0xFF6B6B))
                                            .frame(width: 26, height: 26)
                                            .background(cardElevated, in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .controlHelp(l10n.openInYouTubeHelp)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(cardSurface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }
            }
        }
    }

    // MARK: - 7. Footer Bar

    private var footerBar: some View {
        HStack(spacing: 6) {
            Menu {
                Picker(l10n.menuBarLabelPickerTitle, selection: $manager.menuBarLabelMode) {
                    ForEach(MenuBarLabelMode.allCases) { mode in
                        Text(l10n.menuBarLabelModeName(mode)).tag(mode)
                    }
                }
                Divider()
                Button(l10n.checkForUpdates) { updates.check() }
                    .disabled(!updates.canCheck)
                Toggle(l10n.automaticUpdates, isOn: Binding(get: { updates.checksAutomatically }, set: updates.setAutomaticChecks))
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "menubar.rectangle")
                        .foregroundStyle(manager.currentStation.primaryColor)
                    Text(l10n.menuBarTitle)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(l10n.menuBarLabelPickerTitle)
            .accessibilityValue(l10n.menuBarLabelModeName(manager.menuBarLabelMode))
            .controlHelp("\(l10n.menuBarLabelPickerTitle) · \(l10n.menuBarLabelModeName(manager.menuBarLabelMode))")

            Text("v\(AppUpdates.installedVersion)")
                .foregroundStyle(textMuted)
                .fixedSize()
            if let version = updates.availableVersion {
                Button {
                    updates.check()
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(textPrimary)
                        .frame(width: 22, height: 22)
                        .background(cardElevated, in: Circle())
                }
                .accessibilityLabel(l10n.updateAvailable(version))
                .controlHelp(l10n.updateAvailable(version))
            }

            Spacer(minLength: 0)

            // Language Selector (System Default [EN fallback] / English / Slovenčina)
            Menu {
                Picker(l10n.languagePickerTitle, selection: $manager.appLanguage) {
                    ForEach(AppLanguage.allCases) { langOpt in
                        Text(langOpt.displayName(in: l10n.lang)).tag(langOpt)
                    }
                }
            } label: {
                HStack(spacing: 3.5) {
                    Image(systemName: "globe")
                        .font(.system(size: 10.5, weight: .semibold))
                    Text(l10n.lang.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundStyle(textSecondary)
                .padding(.horizontal, 6.5)
                .padding(.vertical, 3)
                .background(cardElevated, in: Capsule())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .controlHelp(l10n.languagePickerTitle)

            Button {
                Task { await manager.rescanStations() }
            } label: {
                Group {
                    if manager.isRescanning {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                }
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(manager.isRescanning ? l10n.rescanningStations : l10n.rescanStations)
            .disabled(manager.isRescanning)
            .controlHelp(l10n.rescanHelp)

            Button {
                Task { await manager.refreshAllMetadata() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 24, height: 22)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(l10n.refreshInfo)
            .controlHelp(l10n.refreshHelp)

            Button {
                openURL(manager.currentStation.network.websiteURL)
            } label: {
                Image(systemName: "safari")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(textSecondary)
            }
            .buttonStyle(.plain)
            .controlHelp(l10n.openWebsiteHelp)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                    Text(l10n.quitButton)
                }
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(cardElevated, in: Capsule())
            }
            .accessibilityLabel(l10n.quitButton)
            .controlHelp(l10n.quitButton)
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(textSecondary)
        .lineLimit(1)
    }
}
