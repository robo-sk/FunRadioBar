import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var manager: RadioPlayerManager
    @Environment(\.openURL) private var openURL
    @State private var isHovering = false

    private let bgBase = Color(hex: 0x0B0E17)
    private let pillSurface = Color(hex: 0x1A2033)
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

    private var artworkURL: URL? {
        currentTrack?.coverURL ?? currentShow?.imageURL
    }

    var body: some View {
        ZStack {
            // Deep obsidian base + dark vibrancy so it is crystal clear even on bright wallpapers
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            bgBase.opacity(0.92)

            RadialGradient(
                colors: [
                    manager.currentStation.primaryColor.opacity(0.28),
                    manager.currentStation.secondaryColor.opacity(0.10),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 8,
                endRadius: 240
            )

            VStack(alignment: .leading, spacing: 11) {
                // 1. Header row: Station picker menu + Live listeners + Mode / Close
                headerBar

                // 2. Main Now Playing row: Artwork + Track & On-Air Show info
                HStack(spacing: 13) {
                    ArtworkThumbnailView(
                        imageURL: artworkURL,
                        station: manager.currentStation,
                        size: 68,
                        cornerRadius: 15
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        // On-Air Moderator badge ("PRÁVE VYSIELA" / "ON AIR NOW")
                        if let currentStationStatus {
                            Text(currentStationStatus)
                                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                                .foregroundStyle(textSecondary)
                                .lineLimit(1)
                        } else if let show = currentShow {
                            HStack(spacing: 5) {
                                LivePulseDot(color: manager.currentStation.primaryColor)
                                Text("\(l10n.onAirBadge) · \(show.title.uppercased())")
                                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                                    .foregroundStyle(manager.currentStation.primaryColor)
                                    .lineLimit(1)
                            }
                        } else {
                            HStack(spacing: 5) {
                                LivePulseDot()
                                Text("\(l10n.liveBadge) · \(manager.currentStation.name.uppercased())")
                                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                                    .foregroundStyle(textSecondary)
                                    .lineLimit(1)
                            }
                        }

                        // Song Title
                        Text(currentTrack?.title.isEmpty == false ? currentTrack!.title : manager.currentStation.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(textPrimary)
                            .lineLimit(1)

                        // Artist
                        Text(currentTrack?.artist.isEmpty == false ? currentTrack!.artist : l10n.stationSubtitle(manager.currentStation))
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(textSecondary)
                            .lineLimit(1)

                        // Next track preview if available
                        if currentStationStatus == nil, let nextSong = manager.upcomingTracks().first {
                            HStack(spacing: 4) {
                                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(manager.currentStation.primaryColor)
                                Text("\(l10n.upNextMiniPrefix) \(nextSong.artist) – \(nextSong.title)")
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(textMuted)
                                    .lineLimit(1)
                            }
                            .padding(.top, 1)
                        }
                    }

                    Spacer(minLength: 0)
                }

                // 3. Bottom Transport + Volume + Quick Actions
                transportBar
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(width: 340, height: 196)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            manager.currentStation.primaryColor.opacity(0.6),
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.4
                )
        )
        .overlay { PlayerToolTips().allowsHitTesting(false) }
        .environment(\.colorScheme, .dark)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHovering = hovering
            }
        }
    }

    // MARK: - Subviews

    private var headerBar: some View {
        let sections = manager.stationSections(in: manager.stations)
        return HStack(spacing: 8) {
            // Station Quick Picker Menu directly inside the Widget
            Menu {
                Button {
                    Task { await manager.rescanStations() }
                } label: {
                    Label(manager.isRescanning ? l10n.rescanningStations : l10n.rescanStations,
                          systemImage: "antenna.radiowaves.left.and.right")
                }
                .help(l10n.rescanHelp)
                .disabled(manager.isRescanning)

                if manager.rescanFailed {
                    Text(l10n.rescanFailed)
                }

                ForEach(RadioNetwork.allCases.filter { $0 != .all && $0 != .favorites }) { network in
                    let stations = sections.regular.filter { $0.network == network }
                    if !stations.isEmpty {
                        Section(l10n.networkSectionTitle(network, stationCount: stations.count)) {
                            ForEach(stations) { station in
                                stationMenuItem(station)
                            }
                        }
                    }
                }
                if !sections.unavailable.isEmpty {
                    Divider()
                    Toggle(l10n.showUnavailable(sections.unavailable.count), isOn: $manager.showsUnavailableStations)
                    if manager.showsUnavailableStations {
                        ForEach(sections.unavailable) { station in
                            stationMenuItem(station)
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: manager.currentStation.symbolName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(manager.currentStation.primaryColor)
                    Text(manager.currentStation.name)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(textMuted)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(pillSurface, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .controlHelp(l10n.chooseStationHelp)

            // Live listener badge
            let listeners = currentStationStatus == nil ? manager.listenersCount() : 0
            if listeners > 0 {
                HStack(spacing: 3.5) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 8.5))
                    Text(RadioFormatters.formatListeners(listeners))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(pillSurface, in: Capsule())
            }

            Spacer()

            AnimatedEqualizerView(
                isPlaying: manager.isPlaying && !manager.isBuffering,
                color: manager.currentStation.primaryColor,
                barCount: 4,
                height: 12
            )

            // Toggle Desktop Widget vs Floating Mode
            Button {
                manager.miniPlayerMode = (manager.miniPlayerMode == .desktopWidget) ? .floatingTop : .desktopWidget
            } label: {
                Image(systemName: manager.miniPlayerMode == .desktopWidget ? "pin.fill" : "pip.fill")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(manager.miniPlayerMode == .floatingTop ? manager.currentStation.primaryColor : textSecondary)
                    .frame(width: 24, height: 24)
                    .background(pillSurface, in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .controlHelp(l10n.miniPlayerPinHelp(manager.miniPlayerMode))

            // Close Mini Player
            Button {
                manager.toggleMiniPlayer()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(textSecondary)
                    .frame(width: 24, height: 24)
                    .background(pillSurface, in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .controlHelp(l10n.hideMiniPlayerHelp)
        }
    }

    private func stationMenuItem(_ station: RadioStation) -> some View {
        let availability = manager.availability(for: station)
        let active = manager.currentStation.id == station.id && (manager.isPlaying || manager.isBuffering)
        let status = l10n.stationStatus(availability)
        let track = manager.currentTrack(for: station)?.displayLine ?? l10n.stationSubtitle(station)

        return Button {
            if active {
                manager.togglePlayPause()
            } else if status != nil {
                Task { await manager.checkAvailability(for: station) }
            } else {
                manager.play(station: station)
            }
        } label: {
            if active {
                Text("\(station.name) · \(l10n.pauseButton)")
            } else if let status {
                Text(availability == .checking ? "\(station.name) · \(status)" : "\(station.name) · \(status) · \(l10n.checkAvailability)")
            } else {
                Text("\(station.name) · \(track)")
            }
        }
        .disabled(availability == .checking && !active)
    }

    private var transportBar: some View {
        let station = manager.currentStation
        let active = manager.isPlaying || manager.isBuffering
        let needsCheck = !active && currentStationStatus != nil
        let checking = needsCheck && manager.availability(for: station) == .checking
        let actionLabel = active ? l10n.pauseButton : needsCheck ? l10n.checkAvailability : l10n.playLiveButton

        return HStack(spacing: 10) {
            // Previous Station
            Button {
                manager.previousStation()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .frame(width: 29, height: 29)
                    .background(pillSurface, in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .controlHelp(l10n.previousStationHelp)

            // Play / Pause Button
            Button {
                if needsCheck {
                    Task { await manager.checkAvailability(for: station) }
                } else {
                    manager.togglePlayPause()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(manager.currentStation.gradient)
                        .frame(width: 35, height: 35)
                        .shadow(color: manager.currentStation.primaryColor.opacity(0.5), radius: 6, y: 2)

                    if manager.isBuffering || checking {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: active ? "pause.fill" : needsCheck ? "arrow.clockwise" : "play.fill")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: active || needsCheck ? 0 : 1)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(actionLabel)
            .controlHelp(actionLabel)
            .disabled(checking)

            // Next Station
            Button {
                manager.nextStation()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .frame(width: 29, height: 29)
                    .background(pillSurface, in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .controlHelp(l10n.nextStationHelp)

            // Like Current Song
            if let track = currentTrack, !track.title.isEmpty {
                let liked = manager.isTrackLiked(track)
                Button {
                    manager.toggleLikeCurrentTrack()
                } label: {
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(liked ? Color(hex: 0xFF2D78) : textSecondary)
                        .frame(width: 28, height: 28)
                        .background(pillSurface, in: Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .controlHelp(liked ? l10n.removeLikedHelp : l10n.addLikedHelp)
            }

            Spacer(minLength: 4)

            // Compact Volume Control
            HStack(spacing: 5) {
                Button {
                    manager.isMuted.toggle()
                } label: {
                    Image(systemName: manager.isMuted || manager.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(textSecondary)
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
                .controlSize(.mini)
                .frame(width: 78)
                .tint(manager.currentStation.primaryColor)
            }
        }
    }
}
