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

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var controlPanel: ControlPanel!
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Main menu (for keyboard shortcuts when app is active)
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Toggle Overlay", action: #selector(toggleOverlay), keyEquivalent: "t")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Framer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = menu

        // Status bar item
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

    @objc func toggleOverlay() {
        controlPanel.toggle()
    }

    @objc func showPanel() {
        controlPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}

// MARK: - Control Panel

class ControlPanel: NSPanel {
    private var widthField: NSTextField!
    private var heightField: NSTextField!
    private var toggleButton: NSButton!
    private var sizeLabel: NSTextField!
    private var overlay: OverlayPanel?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 152),
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
        label.frame = NSRect(x: 16, y: 124, width: 200, height: 16)
        cv.addSubview(label)

        widthField = makeField(value: "9", x: 16, y: 96)
        cv.addSubview(widthField)

        let colon = NSTextField(labelWithString: ":")
        colon.frame = NSRect(x: 82, y: 96, width: 16, height: 24)
        colon.alignment = .center
        colon.font = .systemFont(ofSize: 16, weight: .light)
        cv.addSubview(colon)

        heightField = makeField(value: "16", x: 100, y: 96)
        cv.addSubview(heightField)

        sizeLabel = NSTextField(labelWithString: "")
        sizeLabel.frame = NSRect(x: 164, y: 100, width: 62, height: 16)
        sizeLabel.alignment = .right
        sizeLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        sizeLabel.textColor = .secondaryLabelColor
        cv.addSubview(sizeLabel)

        // Preset ratio buttons
        let btnW: CGFloat = 38, gap: CGFloat = 4
        for (i, preset) in kPresets.enumerated() {
            let btn = NSButton(frame: NSRect(x: 16 + CGFloat(i) * (btnW + gap), y: 62, width: btnW, height: 26))
            btn.title = preset.label
            btn.bezelStyle = .recessed
            btn.font = .systemFont(ofSize: 10)
            btn.tag = i
            btn.target = self
            btn.action = #selector(presetSelected(_:))
            cv.addSubview(btn)
        }

        toggleButton = NSButton(frame: NSRect(x: 16, y: 16, width: 208, height: 34))
        toggleButton.title = "Show Overlay"
        toggleButton.bezelStyle = .rounded
        toggleButton.target = self
        toggleButton.action = #selector(toggle)
        cv.addSubview(toggleButton)
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

    // Resizes the visible overlay to the current ratio, keeping its width.
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

    /// The visible overlay rect (inside the grab padding)
    var innerFrame: NSRect {
        frame.insetBy(dx: kGrabPadding, dy: kGrabPadding)
    }

    var innerSize: NSSize {
        NSSize(width: frame.width - kGrabPadding * 2, height: frame.height - kGrabPadding * 2)
    }

    init(aspectRatio: CGFloat) {
        self.ratio = aspectRatio
        let w: CGFloat = 270
        let h = w / aspectRatio
        let s = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        // Window is larger than visible overlay by kGrabPadding on each side
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
        // Allow the window to extend off-screen by kGrabPadding so the visible
        // frame can be placed flush against any screen edge or corner.
        guard let screen = screen ?? NSScreen.main else { return frameRect }
        let vis = screen.visibleFrame
        let pad = kGrabPadding
        let minX = vis.minX - pad
        let minY = vis.minY - pad
        let maxX = vis.maxX + pad
        let maxY = vis.maxY + pad
        var r = frameRect
        if r.maxX > maxX { r.origin.x = maxX - r.width }
        if r.maxY > maxY { r.origin.y = maxY - r.height }
        if r.minX < minX { r.origin.x = minX }
        if r.minY < minY { r.origin.y = minY }
        return r
    }

    override func setFrame(_ r: NSRect, display: Bool) {
        super.setFrame(r, display: display)
        layoutHandles()
        onResize?(innerSize)
    }
}

// MARK: - Overlay View (draws border + handles drag-to-move)

class OverlayView: NSView {
    private var dragStart = NSPoint.zero
    private var originAtDrag = NSPoint.zero
    private var isDragging = false

    override func draw(_ dirtyRect: NSRect) {
        // Draw border inset by grab padding so it appears at the visual edge
        let borderRect = bounds.insetBy(dx: kGrabPadding, dy: kGrabPadding)
        let path = NSBezierPath(rect: borderRect.insetBy(dx: kBorderWidth / 2, dy: kBorderWidth / 2))
        path.lineWidth = kBorderWidth
        NSColor.systemRed.withAlphaComponent(0.85).setStroke()
        path.stroke()
    }

    // Grab zone: kGrabPadding outside and inside the border. Interior is click-through.
    override func hitTest(_ p: NSPoint) -> NSView? {
        guard bounds.contains(p) else { return nil }
        for sub in subviews.reversed() {
            if let hit = sub.hitTest(p) { return hit }
        }
        // The visible border sits at kGrabPadding inset. Allow grabbing from
        // the window edge (0) up to kGrabPadding past the border inward.
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
    override func mouseMoved(with event: NSEvent) { updateCursor(for: event) }
    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }

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
        isDragging = true
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

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        updateCursor(for: event)
    }
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

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
