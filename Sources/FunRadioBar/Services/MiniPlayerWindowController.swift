import AppKit
import SwiftUI

final class DraggablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?
    private var isDraggingWindow = false
    private var isInteractingWithSlider = false

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            let loc = event.locationInWindow
            // Bottom-right region contains the volume slider (AppKit y=0 is bottom)
            let sliderRegion = NSRect(x: 210, y: 0, width: 130, height: 50)
            isInteractingWithSlider = sliderRegion.contains(loc)
            dragStartMouseLocation = NSEvent.mouseLocation
            dragStartWindowOrigin = self.frame.origin
            isDraggingWindow = false
            super.sendEvent(event)

        case .leftMouseDragged:
            if !isInteractingWithSlider,
               let startMouse = dragStartMouseLocation,
               let startOrigin = dragStartWindowOrigin {
                let currentMouse = NSEvent.mouseLocation
                let dx = currentMouse.x - startMouse.x
                let dy = currentMouse.y - startMouse.y

                if isDraggingWindow || hypot(dx, dy) > 3.0 {
                    isDraggingWindow = true
                    let newOrigin = NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy)
                    self.setFrameOrigin(newOrigin)
                    self.saveFrame(usingName: "FunRadioMiniPlayerFrame")
                    return
                }
            }
            super.sendEvent(event)

        case .leftMouseUp:
            let wasDragging = isDraggingWindow
            dragStartMouseLocation = nil
            dragStartWindowOrigin = nil
            isDraggingWindow = false
            isInteractingWithSlider = false
            if wasDragging {
                self.saveFrame(usingName: "FunRadioMiniPlayerFrame")
            }
            super.sendEvent(event)

        default:
            super.sendEvent(event)
        }
    }
}

@MainActor
final class MiniPlayerWindowController: NSObject, NSWindowDelegate {
    static let shared = MiniPlayerWindowController()

    private var panel: DraggablePanel?

    private override init() {
        super.init()
        let manager = RadioPlayerManager.shared
        manager.onMiniPlayerToggleRequested = { [weak self] visible in
            self?.setVisible(visible)
        }
        manager.onMiniPlayerModeChanged = { [weak self] mode in
            self?.applyMode(mode)
        }
    }

    func setVisible(_ visible: Bool) {
        if visible {
            showPanel()
        } else {
            panel?.orderOut(nil)
        }
    }

    private func showPanel() {
        if panel == nil {
            createPanel()
        }
        guard let panel else { return }
        applyMode(RadioPlayerManager.shared.miniPlayerMode)
        panel.orderFrontRegardless()
    }

    private func createPanel() {
        let contentRect = NSRect(x: 0, y: 0, width: 340, height: 196)
        let newPanel = DraggablePanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.isMovableByWindowBackground = false // Handled explicitly in DraggablePanel.sendEvent
        newPanel.hidesOnDeactivate = false
        newPanel.delegate = self

        let hostingView = NSHostingView(
            rootView: MiniPlayerView(manager: RadioPlayerManager.shared)
        )
        hostingView.frame = contentRect
        newPanel.contentView = hostingView

        // Position in top-right of desktop if no saved position
        if !newPanel.setFrameUsingName("FunRadioMiniPlayerFrame") {
            if let screen = NSScreen.main {
                let visibleFrame = screen.visibleFrame
                let x = visibleFrame.maxX - contentRect.width - 28
                let y = visibleFrame.maxY - contentRect.height - 28
                newPanel.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
        newPanel.setFrameAutosaveName("FunRadioMiniPlayerFrame")
        self.panel = newPanel
    }

    func applyMode(_ mode: MiniPlayerMode) {
        guard let panel else { return }
        switch mode {
        case .desktopWidget:
            let desktopLevel = Int(CGWindowLevelForKey(.desktopIconWindow)) + 1
            panel.level = NSWindow.Level(rawValue: desktopLevel)
            panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        case .floatingTop:
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        }
    }
}
