import SwiftUI
import XCTest
@testable import FunRadioBar

final class ControlHelpTests: XCTestCase {
    @MainActor
    func testHelpMatchesOnlyTheControlUnderThePointer() async {
        _ = NSApplication.shared
        let host = NSHostingView(rootView: HStack(spacing: 8) {
            Color.clear.frame(width: 24, height: 22).controlHelp("Rescan")
            Color.clear.frame(width: 24, height: 22).controlHelp("Refresh")
        })
        let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 56, height: 22),
                             styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()

        XCTAssertEqual(ControlHelpRegion.message(at: NSPoint(x: 12, y: 11), in: host), "Rescan")
        XCTAssertEqual(ControlHelpRegion.message(at: NSPoint(x: 44, y: 11), in: host), "Refresh")
        XCTAssertNil(ControlHelpRegion.message(at: NSPoint(x: 28, y: 11), in: host))
    }
}
