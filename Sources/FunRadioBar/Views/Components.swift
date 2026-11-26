import SwiftUI
import AppKit

extension View {
    func controlHelp(_ message: String) -> some View {
        help(message)
            .background { ControlHelpRegion(message: message).allowsHitTesting(false) }
    }
}

struct ControlHelpRegion: NSViewRepresentable {
    let message: String

    final class Region: NSView {
        var message = ""
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> Region { Region() }
    func updateNSView(_ view: Region, context: Context) { view.message = message }

    static func message(at windowPoint: NSPoint, in view: NSView) -> String? {
        let point = view.convert(windowPoint, from: nil)
        guard !view.isHidden, view.visibleRect.contains(point) else { return nil }
        if let region = view as? Region {
            return region.bounds.contains(point) ? region.message : nil
        }
        for child in view.subviews.reversed() {
            if let message = message(at: windowPoint, in: child) { return message }
        }
        return nil
    }
}

// Draw explicit help inside the player so it stays in the same window as the control.
struct PlayerToolTips: NSViewRepresentable {
    final class WindowView: NSView {
        private var monitor: Any?
        private weak var bubble: NSView?
        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            bubble?.removeFromSuperview()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.allowsToolTipsWhenApplicationIsInactive = true
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown, .keyDown, .scrollWheel]) { [weak self] event in
                guard let self, let window = self.window, event.window === window else { return event }
                if event.type == .keyDown {
                    guard event.keyCode == 53, self.bubble != nil else { return event }
                    self.bubble?.removeFromSuperview()
                    return nil
                }
                self.bubble?.removeFromSuperview()
                let secondary = event.type == .rightMouseDown || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
                guard secondary, let content = window.contentView,
                      let message = ControlHelpRegion.message(at: event.locationInWindow, in: content) else { return event }
                self.show(message, at: self.convert(event.locationInWindow, from: nil))
                return nil
            }
        }

        private func show(_ message: String, at point: NSPoint) {
            let font = NSFont.toolTipsFont(ofSize: NSFont.smallSystemFontSize)
            let width = min(220, ceil((message as NSString).size(withAttributes: [.font: font]).width))
            let tip = NSHostingView(rootView: Text(message)
                .font(Font(font))
                .foregroundStyle(.white)
                .frame(width: width, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(7)
                .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.secondary.opacity(0.4)))
                .environment(\.colorScheme, .dark))
            let size = tip.fittingSize
            let x = min(max(4, point.x - size.width / 2), bounds.width - size.width - 4)
            let above = point.y - size.height - 8
            let y = above >= 4 ? above : point.y + 8
            tip.frame = NSRect(origin: NSPoint(x: x, y: y), size: size)
            addSubview(tip)
            bubble = tip
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak tip] in tip?.removeFromSuperview() }
        }
    }

    func makeNSView(context: Context) -> WindowView { WindowView() }
    func updateNSView(_ view: WindowView, context: Context) {}
}

// MARK: - Native macOS Vibrancy Wrapper

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.appearance = NSAppearance(named: .darkAqua)
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.appearance = NSAppearance(named: .darkAqua)
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Animated Equalizer Bars

struct AnimatedEqualizerView: View {
    let isPlaying: Bool
    let color: Color
    var barCount: Int = 4
    var height: CGFloat = 14

    @State private var phase: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.18, paused: !isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2.2) {
                ForEach(0..<barCount, id: \.self) { index in
                    let factor = isPlaying
                        ? CGFloat(0.28 + 0.72 * abs(sin(t * (3.2 + Double(index) * 0.85) + Double(index) * 1.1)))
                        : 0.22
                    Capsule(style: .continuous)
                        .fill(color)
                        .frame(width: 2.6, height: max(3, height * factor))
                        .animation(.easeInOut(duration: 0.18), value: factor)
                }
            }
            .frame(height: height, alignment: .bottom)
        }
    }
}

// MARK: - Live Pulsing Dot

struct LivePulseDot: View {
    var color: Color = Color(hex: 0x10B981)
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.35))
                .frame(width: 11, height: 11)
                .scaleEffect(pulse ? 1.35 : 0.8)
            Circle()
                .fill(color)
                .frame(width: 6.5, height: 6.5)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Artwork / Station Thumbnail with Glow

struct ArtworkThumbnailView: View {
    let imageURL: URL?
    let station: RadioStation
    var size: CGFloat = 64
    var cornerRadius: CGFloat = 14
    var showVinylSpin: Bool = false

    var body: some View {
        ZStack {
            // Subtle station ambient glow
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(station.gradient)
                .frame(width: size, height: size)
                .blur(radius: size * 0.16)
                .opacity(0.48)

            if let imageURL {
                BroadcastImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    default:
                        fallbackBadge
                    }
                }
            } else {
                fallbackBadge
            }
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var fallbackBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(station.gradient)
            Image(systemName: station.symbolName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Formatted Listener Number Helper

enum RadioFormatters {
    static func formatListeners(_ count: Int) -> String {
        guard count > 0 else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}
