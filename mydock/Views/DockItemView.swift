import AppKit

final class DockItemView: NSView {
    var onPrimaryAction: (() -> Void)?
    var menuProvider: ((DockItem) -> NSMenu?)?

    private let item: DockItem
    private let layoutSettings: DockLayoutSettings
    private let backgroundView = NSView()
    private let iconView = NSImageView()
    private let badgeView = NSView()
    private let badgeLabel = NSTextField(labelWithString: "")
    private let dotsStackView = NSStackView()
    private var iconSizeConstraint: NSLayoutConstraint?
    private var trackingAreaRef: NSTrackingArea?
    private var isHovering = false

    init(item: DockItem, layoutSettings: DockLayoutSettings) {
        self.item = item
        self.layoutSettings = layoutSettings
        let dimension = layoutSettings.itemDimension
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: dimension, height: dimension)))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: dimension).isActive = true
        heightAnchor.constraint(equalToConstant: dimension).isActive = true
        configureViewHierarchy()
        apply(item: item)
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let trackingAreaRef = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )

        addTrackingArea(trackingAreaRef)
        self.trackingAreaRef = trackingAreaRef
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance()
    }

    override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else {
            return
        }

        onPrimaryAction?()
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = menuProvider?(item) else {
            super.rightMouseDown(with: event)
            return
        }

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private func configureViewHierarchy() {
        backgroundView.wantsLayer = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        badgeView.wantsLayer = true
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(badgeView)

        badgeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        badgeLabel.alignment = .center
        badgeLabel.textColor = .white
        badgeLabel.maximumNumberOfLines = 1
        badgeLabel.lineBreakMode = .byClipping
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeView.addSubview(badgeLabel)

        dotsStackView.orientation = .horizontal
        dotsStackView.alignment = .centerY
        dotsStackView.spacing = 4
        dotsStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dotsStackView)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -4),
            badgeView.leadingAnchor.constraint(equalTo: iconView.leadingAnchor, constant: 1),
            badgeView.topAnchor.constraint(equalTo: iconView.topAnchor, constant: 1),
            badgeView.widthAnchor.constraint(equalToConstant: layoutSettings.badgeDiameter),
            badgeView.heightAnchor.constraint(equalToConstant: layoutSettings.badgeDiameter),

            badgeLabel.centerXAnchor.constraint(equalTo: badgeView.centerXAnchor),
            badgeLabel.centerYAnchor.constraint(equalTo: badgeView.centerYAnchor),

            dotsStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            dotsStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])

        let iconSizeConstraint = iconView.widthAnchor.constraint(equalToConstant: layoutSettings.iconSize)
        iconSizeConstraint.isActive = true
        self.iconSizeConstraint = iconSizeConstraint
        iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor).isActive = true
    }

    private func apply(item: DockItem) {
        iconView.image = item.icon
        iconSizeConstraint?.constant = layoutSettings.iconSize
        badgeLabel.stringValue = item.indexLabel ?? ""
        badgeView.isHidden = item.indexLabel == nil
        toolTip = item.displayName

        dotsStackView.arrangedSubviews.forEach { dot in
            dotsStackView.removeArrangedSubview(dot)
            dot.removeFromSuperview()
        }

        for _ in 0..<item.windowDotsCount {
            dotsStackView.addArrangedSubview(makeDotView())
        }

        dotsStackView.isHidden = item.windowDotsCount == 0
    }

    private func makeDotView() -> NSView {
        let dotView = NSView()
        dotView.wantsLayer = true
        dotView.translatesAutoresizingMaskIntoConstraints = false
        dotView.layer?.cornerRadius = 2.5
        dotView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.95).cgColor

        NSLayoutConstraint.activate([
            dotView.widthAnchor.constraint(equalToConstant: 5),
            dotView.heightAnchor.constraint(equalToConstant: 5)
        ])

        return dotView
    }

    private func updateAppearance() {
        let baseColor: NSColor
        if item.isActive {
            baseColor = NSColor.controlAccentColor.withAlphaComponent(0.22)
        } else if isHovering {
            baseColor = NSColor.white.withAlphaComponent(0.10)
        } else {
            baseColor = NSColor.clear
        }

        backgroundView.layer?.cornerRadius = 16
        backgroundView.layer?.backgroundColor = baseColor.cgColor
        backgroundView.layer?.borderWidth = item.isActive ? 1 : 0
        backgroundView.layer?.borderColor = item.isActive
            ? NSColor.controlAccentColor.withAlphaComponent(0.45).cgColor
            : NSColor.clear.cgColor

        badgeView.layer?.cornerRadius = layoutSettings.badgeDiameter / 2
        badgeView.layer?.backgroundColor = NSColor.black.cgColor
        badgeView.layer?.borderWidth = 1
        badgeView.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor

        alphaValue = item.isRunning ? 1.0 : 0.54
    }
}
