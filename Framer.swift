import Cocoa

// MARK: - Constants

private let kHandleSize: CGFloat = 12
private let kBorderWidth: CGFloat = 3
private let kGrabPadding: CGFloat = 20
private let kMinWidth: CGFloat = 80

private let kPresets: [(label: String, w: Double, h: Double)] = [
    ("16:9", 16, 9),
    ("9:16", 9, 16),
    ("4:3",  4, 3),
    ("1:1",  1, 1),
    ("3:2",  3, 2),
]

// MARK: - HUD Data Model

struct HUDZone {
    let label: String
    let color: NSColor
    // Normalized coordinates, top-left origin (0 = top/left edge, 1 = bottom/right edge)
    let normX: CGFloat
    let normY: CGFloat
    let normW: CGFloat
    let normH: CGFloat
}

enum Platform: String, CaseIterable {
    case tiktok    = "TikTok"
    case igReels   = "IG Reels"
    case igStories = "IG Stories"
    case ytShorts  = "YT Shorts"
    case ytLong    = "YT Long"
    case fbReels   = "FB Reels"

    var zones: [HUDZone] {
        let W: CGFloat = 1080, H: CGFloat = 1920
        let topClr    = NSColor.systemOrange.withAlphaComponent(0.50)
        let bottomClr = NSColor.systemPurple.withAlphaComponent(0.50)
        let sideClr   = NSColor.systemBlue.withAlphaComponent(0.50)

        switch self {
        case .tiktok:
            return [
                HUDZone(label: "Top Bar",         color: topClr,    normX: 0,       normY: 0,       normW: 1,      normH: 160/H),
                HUDZone(label: "Caption + Audio", color: bottomClr, normX: 0,       normY: 1-480/H, normW: 1,      normH: 480/H),
                HUDZone(label: "Action Bar",      color: sideClr,   normX: 1-120/W, normY: 700/H,   normW: 120/W,  normH: 860/H),
            ]
        case .igReels:
            return [
                HUDZone(label: "Top Bar",         color: topClr,    normX: 0,       normY: 0,       normW: 1,      normH: 250/H),
                HUDZone(label: "Caption + Audio", color: bottomClr, normX: 0,       normY: 1-450/H, normW: 1,      normH: 450/H),
                HUDZone(label: "Action Bar",      color: sideClr,   normX: 1-120/W, normY: 1100/H,  normW: 120/W,  normH: 480/H),
            ]
        case .igStories:
            return [
                HUDZone(label: "Progress + Name", color: topClr,    normX: 0, normY: 0,       normW: 1, normH: 155/H),
                HUDZone(label: "Reply Bar",       color: bottomClr, normX: 0, normY: 1-280/H, normW: 1, normH: 280/H),
            ]
        case .ytShorts:
            return [
                HUDZone(label: "Top Bar",         color: topClr,    normX: 0,       normY: 0,       normW: 1,      normH: 180/H),
                HUDZone(label: "Title + Channel", color: bottomClr, normX: 0,       normY: 1-350/H, normW: 1,      normH: 350/H),
                HUDZone(label: "Action Bar",      color: sideClr,   normX: 1-120/W, normY: 400/H,   normW: 120/W,  normH: 1200/H),
            ]
        case .ytLong:
            // Controls appear on hover; the video itself is the full safe area
            return [
                HUDZone(label: "Player Controls", color: bottomClr, normX: 0, normY: 0.90, normW: 1, normH: 0.10),
            ]
        case .fbReels:
            return [
                HUDZone(label: "Top Bar",         color: topClr,    normX: 0,       normY: 0,       normW: 1,      normH: 250/H),
                HUDZone(label: "Caption + Share", color: bottomClr, normX: 0,       normY: 1-420/H, normW: 1,      normH: 420/H),
                HUDZone(label: "Action Bar",      color: sideClr,   normX: 1-120/W, normY: 400/H,   normW: 120/W,  normH: 1200/H),
            ]
        }
    }

    var aspectRatio: (w: Double, h: Double) {
        switch self {
        case .ytLong: return (16, 9)
        default:      return (9, 16)
        }
    }

    // Derives the safe zone from the platform zones (normalized, top-left origin)
    var safeRect: CGRect {
        var top: CGFloat = 0, bottom: CGFloat = 1, left: CGFloat = 0, right: CGFloat = 1
        for z in zones {
            if z.normW > 0.5 {                          // horizontal band
                if z.normY < 0.5 { top    = max(top,    z.normY + z.normH) }
                else              { bottom = min(bottom, z.normY)           }
            } else if z.normX > 0.5 {                   // right-side bar
                right = min(right, z.normX)
            } else if z.normX < 0.1 && z.normW < 0.3 { // left-side bar
                left = max(left, z.normX + z.normW)
            }
        }
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var controlPanel: ControlPanel!
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Toggle Overlay", action: #selector(toggleOverlay), keyEquivalent: "t")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Framer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = menu

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: "Framer")
        }
        let statusMenu = NSMenu()
        statusMenu.addItem(withTitle: "Toggle Overlay", action: #selector(toggleOverlay), keyEquivalent: "t")
        statusMenu.addItem(withTitle: "Show Panel", action: #selector(showPanel), keyEquivalent: "p")
        statusMenu.addItem(.separator())
        statusMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = statusMenu

        controlPanel = ControlPanel()
        controlPanel.delegate = self
        controlPanel.center()
        controlPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func toggleOverlay() { controlPanel.toggle() }

    @objc func showPanel() {
        controlPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) { NSApp.terminate(nil) }
}

// MARK: - Control Panel

class ControlPanel: NSPanel {
    private var widthField: NSTextField!
    private var heightField: NSTextField!
    private var toggleButton: NSButton!
    private var sizeLabel: NSTextField!
    private var overlay: OverlayPanel?
    private var platformButtons: [NSButton] = []
    private var selectedPlatform: Platform?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 248),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        title = "Framer"
        level = .floating
        isFloatingPanel = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        setupUI()
        loadSavedRatio()
    }

    private func setupUI() {
        let cv = contentView!

        let label = NSTextField(labelWithString: "Aspect ratio  W : H")
        label.font = .systemFont(ofSize: 11)
        label.frame = NSRect(x: 16, y: 220, width: 200, height: 16)
        cv.addSubview(label)

        widthField = makeField(value: "9", x: 16, y: 192)
        cv.addSubview(widthField)

        let colon = NSTextField(labelWithString: ":")
        colon.frame = NSRect(x: 82, y: 192, width: 16, height: 24)
        colon.alignment = .center
        colon.font = .systemFont(ofSize: 16, weight: .light)
        cv.addSubview(colon)

        heightField = makeField(value: "16", x: 100, y: 192)
        cv.addSubview(heightField)

        sizeLabel = NSTextField(labelWithString: "")
        sizeLabel.frame = NSRect(x: 164, y: 196, width: 62, height: 16)
        sizeLabel.alignment = .right
        sizeLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        sizeLabel.textColor = .secondaryLabelColor
        cv.addSubview(sizeLabel)

        // Preset ratio buttons
        let btnW: CGFloat = 38, gap: CGFloat = 4
        for (i, preset) in kPresets.enumerated() {
            let btn = NSButton(frame: NSRect(x: 16 + CGFloat(i) * (btnW + gap), y: 158, width: btnW, height: 26))
            btn.title = preset.label
            btn.bezelStyle = .recessed
            btn.font = .systemFont(ofSize: 10)
            btn.tag = i
            btn.target = self
            btn.action = #selector(presetSelected(_:))
            cv.addSubview(btn)
        }

        toggleButton = NSButton(frame: NSRect(x: 16, y: 112, width: 208, height: 34))
        toggleButton.title = "Show Overlay"
        toggleButton.bezelStyle = .rounded
        toggleButton.target = self
        toggleButton.action = #selector(toggle)
        cv.addSubview(toggleButton)

        // Separator between overlay controls and HUD section
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: 0, y: 104, width: 240, height: 1)
        cv.addSubview(sep)

        // Platform HUD section label
        let hudLabel = NSTextField(labelWithString: "Platform HUD")
        hudLabel.font = .systemFont(ofSize: 10)
        hudLabel.textColor = .secondaryLabelColor
        hudLabel.frame = NSRect(x: 16, y: 87, width: 160, height: 14)
        cv.addSubview(hudLabel)

        // Platform buttons: 2 rows of 3
        // Row 0 (top): TikTok, IG Reels, IG Stories  (y = 62)
        // Row 1 (bottom): YT Shorts, YT Long, FB Reels (y = 34)
        let pBtnW: CGFloat = 66, pGap: CGFloat = 5
        for (i, platform) in Platform.allCases.enumerated() {
            let col = i % 3
            let row = i / 3
            let btn = NSButton(frame: NSRect(
                x: 16 + CGFloat(col) * (pBtnW + pGap),
                y: 62 - CGFloat(row) * 28,
                width: pBtnW,
                height: 22
            ))
            btn.title = platform.rawValue
            btn.bezelStyle = .recessed
            btn.setButtonType(.toggle)
            btn.font = .systemFont(ofSize: 9)
            btn.tag = i
            btn.target = self
            btn.action = #selector(platformSelected(_:))
            cv.addSubview(btn)
            platformButtons.append(btn)
        }
    }

    private func makeField(value: String, x: CGFloat, y: CGFloat) -> NSTextField {
        let f = NSTextField(frame: NSRect(x: x, y: y, width: 62, height: 24))
        f.stringValue = value
        f.alignment = .center
        return f
    }

    // MARK: - Persistence

    private func loadSavedRatio() {
        let w = UserDefaults.standard.double(forKey: "aspectWidth")
        let h = UserDefaults.standard.double(forKey: "aspectHeight")
        guard w > 0, h > 0 else { return }
        widthField.stringValue = formatValue(w)
        heightField.stringValue = formatValue(h)
    }

    private func saveRatio() {
        UserDefaults.standard.set(widthField.doubleValue, forKey: "aspectWidth")
        UserDefaults.standard.set(heightField.doubleValue, forKey: "aspectHeight")
    }

    private func formatValue(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v)
    }

    // MARK: - Actions

    @objc func toggle() {
        if let o = overlay, o.isVisible {
            o.orderOut(nil)
            toggleButton.title = "Show Overlay"
            sizeLabel.stringValue = ""
            return
        }

        let w = CGFloat(widthField.doubleValue)
        let h = CGFloat(heightField.doubleValue)
        guard w > 0, h > 0 else { return }
        saveRatio()

        if overlay == nil {
            overlay = OverlayPanel(aspectRatio: w / h)
            overlay?.onResize = { [weak self] size in
                self?.sizeLabel.stringValue = "\(Int(size.width)) x \(Int(size.height))"
            }
            // Apply current platform HUD if one is selected
            if let p = selectedPlatform {
                overlay?.overlayView?.applyHUD(zones: p.zones, safeRect: p.safeRect, platform: p)
            }
        } else {
            applyCurrentRatio()
        }

        overlay?.makeKeyAndOrderFront(nil)

        if let size = overlay?.innerSize {
            sizeLabel.stringValue = "\(Int(size.width)) x \(Int(size.height))"
        }
        toggleButton.title = "Hide Overlay"
    }

    @objc private func presetSelected(_ sender: NSButton) {
        let p = kPresets[sender.tag]
        widthField.stringValue = formatValue(p.w)
        heightField.stringValue = formatValue(p.h)
        saveRatio()
        applyCurrentRatio()
    }

    @objc private func platformSelected(_ sender: NSButton) {
        let platform = Platform.allCases[sender.tag]

        if sender.state == .on {
            // Selecting: deselect all others
            selectedPlatform = platform
            platformButtons.filter { $0 !== sender }.forEach { $0.state = .off }
            // Override aspect ratio fields
            let ar = platform.aspectRatio
            widthField.stringValue = formatValue(ar.w)
            heightField.stringValue = formatValue(ar.h)
            saveRatio()
            applyCurrentRatio()
            overlay?.overlayView?.applyHUD(zones: platform.zones, safeRect: platform.safeRect, platform: platform)
        } else {
            // Deselecting
            selectedPlatform = nil
            overlay?.overlayView?.clearHUD()
        }
    }

    private func applyCurrentRatio() {
        let w = CGFloat(widthField.doubleValue)
        let h = CGFloat(heightField.doubleValue)
        guard w > 0, h > 0, let o = overlay, o.isVisible else { return }
        let ratio = w / h
        o.ratio = ratio
        let pad = kGrabPadding * 2
        let innerW = o.frame.width - pad
        let newInnerH = innerW / ratio
        let newFrame = NSRect(x: o.frame.minX, y: o.frame.maxY - newInnerH - pad,
                              width: innerW + pad, height: newInnerH + pad)
        o.setFrame(newFrame, display: true)
        sizeLabel.stringValue = "\(Int(innerW)) x \(Int(newInnerH))"
    }
}

// MARK: - Overlay Panel

class OverlayPanel: NSPanel {
    var ratio: CGFloat
    var onResize: ((NSSize) -> Void)?

    var overlayView: OverlayView? { contentView as? OverlayView }

    var innerFrame: NSRect { frame.insetBy(dx: kGrabPadding, dy: kGrabPadding) }
    var innerSize: NSSize {
        NSSize(width: frame.width - kGrabPadding * 2, height: frame.height - kGrabPadding * 2)
    }

    init(aspectRatio: CGFloat) {
        self.ratio = aspectRatio
        let w: CGFloat = 400
        let h = w / aspectRatio
        let s = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let pad = kGrabPadding
        super.init(
            contentRect: NSRect(x: s.midX - w / 2 - pad, y: s.midY - h / 2 - pad,
                                width: w + pad * 2, height: h + pad * 2),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false

        let view = OverlayView()
        view.autoresizingMask = [.width, .height]
        contentView = view

        ResizeHandle.Corner.allCases.forEach { corner in
            let handle = ResizeHandle(corner: corner)
            handle.panel = self
            view.addSubview(handle)
        }
        layoutHandles()
    }

    func layoutHandles() {
        let s = kHandleSize
        let pad = kGrabPadding
        let (w, h) = (frame.width, frame.height)
        contentView?.subviews.compactMap({ $0 as? ResizeHandle }).forEach {
            switch $0.corner {
            case .bottomLeft:  $0.frame = NSRect(x: pad - s/2,     y: pad - s/2,     width: s, height: s)
            case .bottomRight: $0.frame = NSRect(x: w - pad - s/2, y: pad - s/2,     width: s, height: s)
            case .topLeft:     $0.frame = NSRect(x: pad - s/2,     y: h - pad - s/2, width: s, height: s)
            case .topRight:    $0.frame = NSRect(x: w - pad - s/2, y: h - pad - s/2, width: s, height: s)
            }
        }
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        guard let screen = screen ?? NSScreen.main else { return frameRect }
        let vis = screen.visibleFrame
        let pad = kGrabPadding
        var r = frameRect
        if r.maxX > vis.maxX + pad { r.origin.x = vis.maxX + pad - r.width }
        if r.maxY > vis.maxY + pad { r.origin.y = vis.maxY + pad - r.height }
        if r.minX < vis.minX - pad { r.origin.x = vis.minX - pad }
        if r.minY < vis.minY - pad { r.origin.y = vis.minY - pad }
        return r
    }

    override func setFrame(_ r: NSRect, display: Bool) {
        super.setFrame(r, display: display)
        layoutHandles()
        onResize?(innerSize)
    }
}

// MARK: - Overlay View

class OverlayView: NSView {
    private var dragStart = NSPoint.zero
    private var originAtDrag = NSPoint.zero
    private var hudZones: [HUDZone] = []
    private var safeZoneRect: CGRect? = nil
    private var currentPlatform: Platform? = nil

    func applyHUD(zones: [HUDZone], safeRect: CGRect, platform: Platform) {
        hudZones = zones
        safeZoneRect = safeRect
        currentPlatform = platform
        needsDisplay = true
    }

    func clearHUD() {
        hudZones = []
        safeZoneRect = nil
        currentPlatform = nil
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let inner = bounds.insetBy(dx: kGrabPadding, dy: kGrabPadding)

        if let platform = currentPlatform {
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: inner).setClip()
            drawPlatformUI(platform, in: inner)
            NSGraphicsContext.restoreGraphicsState()
        }

        // Draw border on top
        let path = NSBezierPath(rect: inner.insetBy(dx: kBorderWidth / 2, dy: kBorderWidth / 2))
        path.lineWidth = kBorderWidth
        NSColor.systemRed.withAlphaComponent(0.85).setStroke()
        path.stroke()
    }

    private func drawSafeZone(_ safe: CGRect, in inner: NSRect) {
        let sx = inner.minX + safe.origin.x * inner.width
        let sw = safe.size.width * inner.width
        let sh = safe.size.height * inner.height
        let sy = inner.minY + (1.0 - safe.origin.y - safe.size.height) * inner.height
        let rect = NSRect(x: sx, y: sy, width: sw, height: sh)

        let path = NSBezierPath(rect: rect.insetBy(dx: 1, dy: 1))
        path.lineWidth = 1.5
        path.setLineDash([6, 4], count: 2, phase: 0)
        NSColor.systemGreen.withAlphaComponent(0.85).setStroke()
        path.stroke()
    }

    // MARK: - Coordinate Helpers

    private func refPt(_ x: CGFloat, _ y: CGFloat,
                       refW: CGFloat = 1080, refH: CGFloat = 1920, in inner: NSRect) -> NSPoint {
        NSPoint(x: inner.minX + (x / refW) * inner.width,
                y: inner.maxY - (y / refH) * inner.height)
    }

    private func scl(_ refW: CGFloat = 1080, in inner: NSRect) -> CGFloat {
        inner.width / refW
    }

    // MARK: - Drawing Helpers

    private func drawIcon(_ name: String, at center: NSPoint, size: CGFloat,
                          color: NSColor = .white) {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }
        let sz = base.size
        let tinted = NSImage(size: sz)
        tinted.lockFocus()
        base.draw(in: NSRect(origin: .zero, size: sz))
        color.set()
        NSRect(origin: .zero, size: sz).fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.draw(in: NSRect(x: center.x - sz.width / 2, y: center.y - sz.height / 2,
                               width: sz.width, height: sz.height))
    }

    private func drawLabel(_ text: String, at pt: NSPoint, size: CGFloat,
                           weight: NSFont.Weight = .regular, color: NSColor = .white) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        str.draw(at: NSPoint(x: pt.x, y: pt.y - str.size().height))
    }

    private func drawLabelCentered(_ text: String, at center: NSPoint, size: CGFloat,
                                   weight: NSFont.Weight = .regular, color: NSColor = .white) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let sz = str.size()
        str.draw(at: NSPoint(x: center.x - sz.width / 2, y: center.y - sz.height / 2))
    }

    private func drawTopGradient(height: CGFloat, refH: CGFloat = 1920, in inner: NSRect) {
        let h = (height / refH) * inner.height
        let rect = NSRect(x: inner.minX, y: inner.maxY - h, width: inner.width, height: h)
        NSGradient(starting: NSColor.black.withAlphaComponent(0.5),
                   ending: NSColor.black.withAlphaComponent(0.0))?
            .draw(in: rect, angle: 270)
    }

    private func drawBottomGradient(height: CGFloat, refH: CGFloat = 1920, in inner: NSRect) {
        let h = (height / refH) * inner.height
        let rect = NSRect(x: inner.minX, y: inner.minY, width: inner.width, height: h)
        NSGradient(starting: NSColor.black.withAlphaComponent(0.5),
                   ending: NSColor.black.withAlphaComponent(0.0))?
            .draw(in: rect, angle: 90)
    }

    private func drawPill(_ text: String, at pt: NSPoint, scale s: CGFloat,
                          fill: NSColor = NSColor.white.withAlphaComponent(0.15),
                          stroke: NSColor = NSColor.white.withAlphaComponent(0.5),
                          textColor: NSColor = .white) {
        let font = NSFont.systemFont(ofSize: 34 * s, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        let str = NSAttributedString(string: text, attributes: attrs)
        let sz = str.size()
        let pad: CGFloat = 20 * s
        let pillH = sz.height + pad
        let pillRect = NSRect(x: pt.x, y: pt.y - pillH, width: sz.width + pad * 2, height: pillH)
        let path = NSBezierPath(roundedRect: pillRect, xRadius: pillH / 2, yRadius: pillH / 2)
        fill.setFill(); path.fill()
        stroke.setStroke(); path.lineWidth = 2 * s; path.stroke()
        str.draw(at: NSPoint(x: pt.x + pad, y: pt.y - pillH + pad / 2))
    }

    private func drawCircle(at center: NSPoint, radius: CGFloat,
                            fill: NSColor? = nil, stroke: NSColor? = nil) {
        let rect = NSRect(x: center.x - radius, y: center.y - radius,
                          width: radius * 2, height: radius * 2)
        let path = NSBezierPath(ovalIn: rect)
        if let f = fill { f.setFill(); path.fill() }
        if let s = stroke { s.setStroke(); path.lineWidth = 1; path.stroke() }
    }

    // MARK: - Platform UI Dispatch

    private func drawPlatformUI(_ platform: Platform, in inner: NSRect) {
        switch platform {
        case .igReels:   drawIGReels(in: inner)
        case .igStories: drawIGStories(in: inner)
        case .tiktok:    drawTikTok(in: inner)
        case .ytShorts:  drawYTShorts(in: inner)
        case .ytLong:    drawYTLong(in: inner)
        case .fbReels:   drawFBReels(in: inner)
        }
    }

    // MARK: - IG Reels

    private func drawIGReels(in inner: NSRect) {
        let s = scl(in: inner)

        drawTopGradient(height: 250, in: inner)
        drawBottomGradient(height: 650, in: inner)

        // Top bar
        drawIcon("chevron.left", at: refPt(60, 60, in: inner), size: 52 * s)
        drawLabelCentered("Reels", at: refPt(540, 60, in: inner), size: 56 * s, weight: .bold)
        drawIcon("camera", at: refPt(1000, 60, in: inner), size: 56 * s)

        // Right action bar
        let ax: CGFloat = 980
        drawIcon("heart", at: refPt(ax, 1180, in: inner), size: 64 * s)
        drawLabelCentered("5000", at: refPt(ax, 1240, in: inner), size: 30 * s, weight: .semibold)

        drawIcon("bubble.right", at: refPt(ax, 1350, in: inner), size: 64 * s)
        drawLabelCentered("6000", at: refPt(ax, 1410, in: inner), size: 30 * s, weight: .semibold)

        drawIcon("paperplane", at: refPt(ax, 1510, in: inner), size: 60 * s)
        drawLabelCentered("7000", at: refPt(ax, 1570, in: inner), size: 30 * s, weight: .semibold)

        drawIcon("ellipsis", at: refPt(ax, 1660, in: inner), size: 52 * s)

        // Audio disc
        drawCircle(at: refPt(ax, 1770, in: inner), radius: 44 * s,
                   fill: NSColor.gray.withAlphaComponent(0.5), stroke: .white)
        drawIcon("music.note", at: refPt(ax, 1770, in: inner), size: 26 * s)

        // Bottom info
        let by: CGFloat = 1520
        drawCircle(at: refPt(60, by + 20, in: inner), radius: 48 * s,
                   fill: NSColor.gray.withAlphaComponent(0.6), stroke: .white)
        drawLabel("your.name", at: refPt(125, by, in: inner), size: 42 * s, weight: .bold)
        drawIcon("checkmark.seal.fill", at: refPt(400, by + 15, in: inner), size: 36 * s,
                 color: .systemBlue)
        drawPill("Follow", at: refPt(450, by - 5, in: inner), scale: s)

        drawLabel("Lorem metus porttitor purus enim. Non et m...",
                  at: refPt(30, by + 80, in: inner), size: 36 * s,
                  color: NSColor.white.withAlphaComponent(0.9))

        drawIcon("music.note", at: refPt(45, by + 150, in: inner), size: 30 * s)
        drawLabel("Lorem metus porttitor pur...", at: refPt(85, by + 138, in: inner),
                  size: 33 * s, color: NSColor.white.withAlphaComponent(0.85))
        drawIcon("person.2.fill", at: refPt(640, by + 150, in: inner), size: 30 * s)
        drawLabel("55 users", at: refPt(680, by + 138, in: inner),
                  size: 33 * s, color: NSColor.white.withAlphaComponent(0.85))
    }

    // MARK: - IG Stories

    private func drawIGStories(in inner: NSRect) {
        let s = scl(in: inner)

        drawTopGradient(height: 250, in: inner)
        drawBottomGradient(height: 350, in: inner)

        // Progress bars
        let barY: CGFloat = 105, barH: CGFloat = 6, barPad: CGFloat = 12
        let numBars = 3
        let totalPad = barPad * CGFloat(numBars + 1)
        let barW = (1080 - totalPad) / CGFloat(numBars)
        for i in 0..<numBars {
            let bx = barPad + CGFloat(i) * (barW + barPad)
            let pt = refPt(bx, barY, in: inner)
            let w = barW * s, h = barH * s
            let rect = NSRect(x: pt.x, y: pt.y - h, width: w, height: h)
            let path = NSBezierPath(roundedRect: rect, xRadius: h / 2, yRadius: h / 2)
            (i == 0 ? NSColor.white : NSColor.white.withAlphaComponent(0.4)).setFill()
            path.fill()
        }

        // Profile + name
        drawCircle(at: refPt(70, 175, in: inner), radius: 48 * s,
                   fill: NSColor.gray.withAlphaComponent(0.5),
                   stroke: NSColor.white.withAlphaComponent(0.8))
        drawLabel("your.name", at: refPt(135, 155, in: inner), size: 42 * s, weight: .semibold)
        drawLabel("2h", at: refPt(135, 205, in: inner), size: 36 * s,
                  color: NSColor.white.withAlphaComponent(0.7))

        drawIcon("xmark", at: refPt(1010, 175, in: inner), size: 52 * s)
        drawIcon("ellipsis", at: refPt(920, 175, in: inner), size: 48 * s)

        // Bottom: Send message bar
        let msgY: CGFloat = 1740
        let msgPt = refPt(30, msgY, in: inner)
        let msgBtm = refPt(30, msgY + 80, in: inner)
        let msgRect = NSRect(x: msgPt.x, y: msgBtm.y, width: 760 * s, height: 80 * s)
        let msgPath = NSBezierPath(roundedRect: msgRect, xRadius: 40 * s, yRadius: 40 * s)
        NSColor.white.withAlphaComponent(0.15).setFill(); msgPath.fill()
        NSColor.white.withAlphaComponent(0.4).setStroke(); msgPath.lineWidth = 2 * s; msgPath.stroke()
        drawLabel("Send message",
                  at: NSPoint(x: msgRect.minX + 30 * s, y: msgRect.midY + 10 * s),
                  size: 36 * s, color: NSColor.white.withAlphaComponent(0.6))

        drawIcon("heart", at: refPt(890, msgY + 40, in: inner), size: 56 * s)
        drawIcon("paperplane", at: refPt(1000, msgY + 40, in: inner), size: 56 * s)
    }

    // MARK: - TikTok

    private func drawTikTok(in inner: NSRect) {
        let s = scl(in: inner)

        drawTopGradient(height: 200, in: inner)
        drawBottomGradient(height: 700, in: inner)

        // Top tabs
        drawLabelCentered("Following", at: refPt(350, 70, in: inner), size: 42 * s,
                         color: NSColor.white.withAlphaComponent(0.6))
        drawLabelCentered("For You", at: refPt(590, 70, in: inner), size: 44 * s, weight: .bold)
        let tabPt = refPt(520, 100, in: inner)
        let tabEnd = NSPoint(x: tabPt.x + 140 * s, y: tabPt.y)
        let tabLine = NSBezierPath()
        tabLine.move(to: tabPt); tabLine.line(to: tabEnd)
        tabLine.lineWidth = 3 * s
        NSColor.white.setStroke(); tabLine.stroke()
        drawIcon("magnifyingglass", at: refPt(1000, 70, in: inner), size: 52 * s)

        // Right action bar
        let ax: CGFloat = 980

        // Profile circle (96px diameter)
        drawCircle(at: refPt(ax, 730, in: inner), radius: 48 * s,
                   fill: NSColor.gray.withAlphaComponent(0.5), stroke: .white)
        drawCircle(at: refPt(ax, 790, in: inner), radius: 16 * s,
                   fill: .systemPink)
        drawIcon("plus", at: refPt(ax, 790, in: inner), size: 14 * s)

        // Heart (~120-130px spacing between groups)
        drawIcon("heart.fill", at: refPt(ax, 940, in: inner), size: 64 * s)
        drawLabelCentered("633.0K", at: refPt(ax, 1000, in: inner), size: 26 * s, weight: .medium)

        // Comment
        drawIcon("ellipsis.bubble.fill", at: refPt(ax, 1120, in: inner), size: 60 * s)
        drawLabelCentered("10 K", at: refPt(ax, 1180, in: inner), size: 26 * s, weight: .medium)

        // Bookmark
        drawIcon("bookmark.fill", at: refPt(ax, 1300, in: inner), size: 56 * s)
        drawLabelCentered("60.5K", at: refPt(ax, 1360, in: inner), size: 26 * s, weight: .medium)

        // Share
        drawIcon("arrowshape.turn.up.right.fill", at: refPt(ax, 1470, in: inner), size: 56 * s)
        drawLabelCentered("11.9 K", at: refPt(ax, 1530, in: inner), size: 26 * s, weight: .medium)

        // Audio disc (90px diameter)
        drawCircle(at: refPt(ax, 1670, in: inner), radius: 44 * s,
                   fill: NSColor.darkGray, stroke: .gray)
        drawIcon("music.note", at: refPt(ax, 1670, in: inner), size: 26 * s)

        // Bottom info
        drawLabel("USERNAME", at: refPt(30, 1600, in: inner), size: 44 * s, weight: .bold)
        drawLabel("Description  #music  #dance",
                  at: refPt(30, 1665, in: inner), size: 36 * s,
                  color: NSColor.white.withAlphaComponent(0.9))
        drawLabel("#foryou  #foryoupage",
                  at: refPt(30, 1720, in: inner), size: 36 * s,
                  color: NSColor.white.withAlphaComponent(0.9))
        drawLabel("see translation", at: refPt(30, 1775, in: inner), size: 30 * s,
                  weight: .semibold, color: NSColor.white.withAlphaComponent(0.7))
        drawIcon("music.note", at: refPt(40, 1845, in: inner), size: 30 * s)
        drawLabel("Original Sound", at: refPt(80, 1832, in: inner),
                  size: 32 * s, color: NSColor.white.withAlphaComponent(0.85))
    }

    // MARK: - YT Shorts

    private func drawYTShorts(in inner: NSRect) {
        let s = scl(in: inner)

        drawTopGradient(height: 180, in: inner)
        drawBottomGradient(height: 550, in: inner)

        // Top bar
        drawIcon("magnifyingglass", at: refPt(900, 65, in: inner), size: 52 * s)
        drawIcon("ellipsis", at: refPt(1010, 65, in: inner), size: 52 * s)

        // Right action bar
        let ax: CGFloat = 980

        // Like
        drawIcon("hand.thumbsup", at: refPt(ax, 770, in: inner), size: 60 * s)
        drawLabelCentered("45K", at: refPt(ax, 830, in: inner), size: 28 * s, weight: .medium)

        // Dislike
        drawIcon("hand.thumbsdown", at: refPt(ax, 930, in: inner), size: 60 * s)
        drawLabelCentered("Dislike", at: refPt(ax, 990, in: inner), size: 26 * s, weight: .medium)

        // Comments
        drawIcon("text.bubble", at: refPt(ax, 1090, in: inner), size: 56 * s)
        drawLabelCentered("1.2K", at: refPt(ax, 1150, in: inner), size: 28 * s, weight: .medium)

        // Share
        drawIcon("arrowshape.turn.up.right", at: refPt(ax, 1250, in: inner), size: 56 * s)
        drawLabelCentered("Share", at: refPt(ax, 1310, in: inner), size: 26 * s, weight: .medium)

        // Remix
        drawIcon("arrow.2.squarepath", at: refPt(ax, 1400, in: inner), size: 52 * s)
        drawLabelCentered("Remix", at: refPt(ax, 1460, in: inner), size: 26 * s, weight: .medium)

        // Audio disc (larger on YT Shorts ~120px)
        drawCircle(at: refPt(ax, 1580, in: inner), radius: 52 * s,
                   fill: NSColor.darkGray, stroke: .gray)
        drawIcon("music.note", at: refPt(ax, 1580, in: inner), size: 26 * s)

        // Bottom: channel + subscribe
        drawCircle(at: refPt(70, 1630, in: inner), radius: 48 * s,
                   fill: NSColor.gray.withAlphaComponent(0.5), stroke: .white)
        drawLabel("@channel_name", at: refPt(135, 1615, in: inner), size: 42 * s, weight: .semibold)
        drawPill("Subscribe", at: refPt(440, 1612, in: inner), scale: s,
                 fill: .red, stroke: .red)

        drawLabel("Amazing video title goes here #shorts",
                  at: refPt(30, 1700, in: inner), size: 36 * s,
                  color: NSColor.white.withAlphaComponent(0.9))
        drawIcon("music.note", at: refPt(45, 1775, in: inner), size: 30 * s)
        drawLabel("Original audio", at: refPt(85, 1762, in: inner), size: 33 * s,
                  color: NSColor.white.withAlphaComponent(0.85))
    }

    // MARK: - YT Long

    private func drawYTLong(in inner: NSRect) {
        let refW: CGFloat = 1920, refH: CGFloat = 1080
        let s = inner.width / refW

        drawBottomGradient(height: 150, refH: refH, in: inner)

        // Progress bar
        let barPt = refPt(24, 960, refW: refW, refH: refH, in: inner)
        let barW = inner.width - 48 * s
        let barRect = NSRect(x: barPt.x, y: barPt.y, width: barW, height: 8 * s)
        NSColor.white.withAlphaComponent(0.3).setFill()
        let barPath = NSBezierPath(roundedRect: barRect, xRadius: 4 * s, yRadius: 4 * s)
        barPath.fill()
        // Played portion (40%)
        let playedRect = NSRect(x: barPt.x, y: barPt.y, width: barW * 0.4, height: 8 * s)
        NSColor.red.setFill()
        NSBezierPath(roundedRect: playedRect, xRadius: 4 * s, yRadius: 4 * s).fill()
        // Scrubber dot
        drawCircle(at: NSPoint(x: barPt.x + barW * 0.4, y: barPt.y + 4 * s),
                   radius: 14 * s, fill: .red)

        // Controls row
        let cy: CGFloat = 1020
        drawIcon("play.fill", at: refPt(70, cy, refW: refW, refH: refH, in: inner), size: 48 * s)
        drawIcon("forward.end.fill", at: refPt(170, cy, refW: refW, refH: refH, in: inner), size: 40 * s)
        drawIcon("speaker.wave.2.fill", at: refPt(280, cy, refW: refW, refH: refH, in: inner), size: 40 * s)
        drawLabel("3:42 / 8:15", at: refPt(380, cy - 15, refW: refW, refH: refH, in: inner),
                  size: 36 * s, color: NSColor.white.withAlphaComponent(0.9))

        drawIcon("captions.bubble", at: refPt(1580, cy, refW: refW, refH: refH, in: inner), size: 42 * s)
        drawIcon("gear", at: refPt(1680, cy, refW: refW, refH: refH, in: inner), size: 42 * s)
        drawIcon("rectangle.on.rectangle", at: refPt(1780, cy, refW: refW, refH: refH, in: inner), size: 40 * s)
        drawIcon("arrow.up.left.and.arrow.down.right",
                 at: refPt(1870, cy, refW: refW, refH: refH, in: inner), size: 42 * s)
    }

    // MARK: - FB Reels

    private func drawFBReels(in inner: NSRect) {
        let s = scl(in: inner)

        drawTopGradient(height: 250, in: inner)
        drawBottomGradient(height: 600, in: inner)

        // Top bar
        drawLabel("Reels", at: refPt(30, 50, in: inner), size: 54 * s, weight: .bold)
        drawIcon("camera", at: refPt(1000, 65, in: inner), size: 56 * s)

        // Right action bar
        let ax: CGFloat = 980

        drawIcon("hand.thumbsup", at: refPt(ax, 1100, in: inner), size: 60 * s)
        drawLabelCentered("12K", at: refPt(ax, 1160, in: inner), size: 28 * s, weight: .semibold)

        drawIcon("bubble.right", at: refPt(ax, 1280, in: inner), size: 60 * s)
        drawLabelCentered("847", at: refPt(ax, 1340, in: inner), size: 28 * s, weight: .semibold)

        drawIcon("arrowshape.turn.up.right.fill", at: refPt(ax, 1460, in: inner), size: 60 * s)
        drawLabelCentered("2.3K", at: refPt(ax, 1520, in: inner), size: 28 * s, weight: .semibold)

        drawIcon("ellipsis", at: refPt(ax, 1620, in: inner), size: 52 * s)

        // Bottom: profile + follow
        drawCircle(at: refPt(65, 1590, in: inner), radius: 48 * s,
                   fill: NSColor.gray.withAlphaComponent(0.5), stroke: .white)
        drawLabel("Page Name", at: refPt(130, 1575, in: inner), size: 42 * s, weight: .bold)
        drawPill("Follow", at: refPt(380, 1572, in: inner), scale: s)

        drawLabel("Amazing reel content with great caption...",
                  at: refPt(30, 1660, in: inner), size: 36 * s,
                  color: NSColor.white.withAlphaComponent(0.9))
        drawIcon("music.note", at: refPt(45, 1740, in: inner), size: 30 * s)
        drawLabel("Original audio - Page Name", at: refPt(85, 1728, in: inner),
                  size: 33 * s, color: NSColor.white.withAlphaComponent(0.85))
    }

    // Grab zone: border region only; interior is click-through
    override func hitTest(_ p: NSPoint) -> NSView? {
        guard bounds.contains(p) else { return nil }
        for sub in subviews.reversed() {
            if let hit = sub.hitTest(p) { return hit }
        }
        let inner = bounds.insetBy(dx: kGrabPadding * 2, dy: kGrabPadding * 2)
        return (inner.width > 0 && inner.height > 0 && inner.contains(p)) ? nil : self
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) { updateCursor(for: event) }
    override func mouseMoved(with event: NSEvent)   { updateCursor(for: event) }
    override func mouseExited(with event: NSEvent)  { NSCursor.arrow.set() }

    private func updateCursor(for event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let inner = bounds.insetBy(dx: kGrabPadding * 2, dy: kGrabPadding * 2)
        if inner.width > 0 && inner.height > 0 && inner.contains(p) {
            NSCursor.arrow.set()
        } else {
            NSCursor.openHand.set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.closedHand.set()
        dragStart = NSEvent.mouseLocation
        originAtDrag = window?.frame.origin ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        let cur = NSEvent.mouseLocation
        window?.setFrameOrigin(NSPoint(
            x: originAtDrag.x + cur.x - dragStart.x,
            y: originAtDrag.y + cur.y - dragStart.y
        ))
    }

    override func mouseUp(with event: NSEvent) { updateCursor(for: event) }
}

// MARK: - Resize Handle

class ResizeHandle: NSView {
    enum Corner: CaseIterable { case topLeft, topRight, bottomLeft, bottomRight }

    let corner: Corner
    weak var panel: OverlayPanel?

    private var dragStart = NSPoint.zero
    private var frameAtDrag = NSRect.zero

    init(corner: Corner) {
        self.corner = corner
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2)).fill()
        let oval = NSBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2))
        oval.lineWidth = 1.5
        NSColor.systemRed.withAlphaComponent(0.9).setStroke()
        oval.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        frameAtDrag = panel?.frame ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let panel else { return }
        let dx = NSEvent.mouseLocation.x - dragStart.x
        let ratio = panel.ratio
        let f = frameAtDrag

        let pad = kGrabPadding * 2
        let newW = max(kMinWidth + pad, (corner == .bottomRight || corner == .topRight) ? f.width + dx : f.width - dx)
        let innerW = newW - pad
        let newH = innerW / ratio + pad

        let newFrame: NSRect
        switch corner {
        case .bottomRight: newFrame = NSRect(x: f.minX,        y: f.maxY - newH, width: newW, height: newH)
        case .bottomLeft:  newFrame = NSRect(x: f.maxX - newW, y: f.maxY - newH, width: newW, height: newH)
        case .topRight:    newFrame = NSRect(x: f.minX,        y: f.minY,        width: newW, height: newH)
        case .topLeft:     newFrame = NSRect(x: f.maxX - newW, y: f.minY,        width: newW, height: newH)
        }
        panel.setFrame(newFrame, display: true)
    }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
