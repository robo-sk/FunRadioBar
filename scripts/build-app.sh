#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="FunRadioBar"
BUNDLE_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
VERSION=${1:-1.0.0}
# CFBundleVersion accepts up to four digits in the first field and two in the others.
if [[ ! $VERSION =~ ^[1-9][0-9]{0,3}\.(0|[1-9][0-9]?)\.(0|[1-9][0-9]?)$ ]]; then
    echo "Expected a stable version such as 1.0.0" >&2
    exit 1
fi
IDENTITY=${CODE_SIGN_IDENTITY:--}

swift package resolve --force-resolved-versions
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$CONTENTS_DIR/Frameworks"
work=$(mktemp -d)
trap '/bin/rm -r "$work"' EXIT
binaries=()
for arch in arm64 x86_64; do
    args=(-c release --arch "$arch" --disable-automatic-resolution)
    swift build "${args[@]}" --product "$APP_NAME" -Xswiftc -gnone -Xswiftc -file-prefix-map -Xswiftc "$ROOT_DIR=." \
        -Xlinker -rpath -Xlinker @executable_path/../Frameworks
    cp "$(swift build "${args[@]}" --show-bin-path)/$APP_NAME" "$work/$arch"
    binaries+=("$work/$arch")
done
lipo -create "${binaries[@]}" -output "$MACOS_DIR/$APP_NAME"
strip -x "$MACOS_DIR/$APP_NAME"
archs=" $(lipo -archs "$MACOS_DIR/$APP_NAME") "
[[ "$archs" == *" arm64 "* && "$archs" == *" x86_64 "* ]]
framework="$CONTENTS_DIR/Frameworks/Sparkle.framework"
ditto .build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework "$framework"

# Generate a custom vibrant AppIcon.icns using Swift & AppKit
ICONSET_DIR="$work/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

swift - "$ICONSET_DIR" << 'SWIFT_ICON'
import AppKit

let args = CommandLine.arguments
let iconsetPath = args[1]

func renderIcon(size: Int, scale: Int) {
    let pixelSize = size * scale
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: CGFloat(pixelSize), height: CGFloat(pixelSize))
    let inset = CGFloat(pixelSize) * 0.08
    let cardRect = rect.insetBy(dx: inset, dy: inset)
    let radius = cardRect.width * 0.225

    let path = NSBezierPath(roundedRect: cardRect, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 1.0, green: 0.176, blue: 0.47, alpha: 1.0),
        NSColor(srgbRed: 0.475, green: 0.157, blue: 0.792, alpha: 1.0),
        NSColor(srgbRed: 0.024, green: 0.714, blue: 0.831, alpha: 1.0)
    ])!
    gradient.draw(in: path, angle: -45)

    if let symbol = NSImage(systemSymbolName: "dot.radiowaves.left.and.right", accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: cardRect.width * 0.46, weight: .bold)
            .applying(.init(paletteColors: [.white]))
        if let configured = symbol.withSymbolConfiguration(config) {
            let symSize = configured.size
            let drawRect = NSRect(
                x: rect.midX - symSize.width / 2,
                y: rect.midY - symSize.height / 2,
                width: symSize.width,
                height: symSize.height
            )
            configured.draw(in: drawRect)
        }
    }

    NSGraphicsContext.restoreGraphicsState()

    if let pngData = rep.representation(using: .png, properties: [:]) {
        let name = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
        try? pngData.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name)"))
    }
}

for s in [16, 32, 128, 256, 512] {
    renderIcon(size: s, scale: 1)
    renderIcon(size: s, scale: 2)
}
SWIFT_ICON

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"


cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>sk.funradio.mac.FunRadioBar</string>
    <key>CFBundleName</key>
    <string>FunRadioBar</string>
    <key>CFBundleDisplayName</key>
    <string>FunRadioBar</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>SUFeedURL</key>
    <string>https://github.com/robo-sk/FunRadioBar/releases/latest/download/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>MVRppXb2u+x9fvOyG0r7z2wrNi/xqu53g5oWZRt5YC4=</string>
    <key>SURequireSignedFeed</key>
    <true/>
    <key>SUVerifyUpdateBeforeExtraction</key>
    <true/>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUEnableSystemProfiling</key>
    <false/>
</dict>
</plist>
EOF

sign=(codesign --force --sign "$IDENTITY")
if [[ $IDENTITY != "-" ]]; then sign+=(--options runtime --timestamp); fi
parts="$framework/Versions/B"
"${sign[@]}" "$parts/XPCServices/Installer.xpc"
"${sign[@]}" --preserve-metadata=entitlements "$parts/XPCServices/Downloader.xpc"
"${sign[@]}" "$parts/Autoupdate"
"${sign[@]}" "$parts/Updater.app"
"${sign[@]}" "$framework"
"${sign[@]}" "$BUNDLE_DIR"
codesign --verify --deep --strict --all-architectures "$BUNDLE_DIR"
echo "Built $BUNDLE_DIR ($VERSION)"
