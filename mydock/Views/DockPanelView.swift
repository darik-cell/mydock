import AppKit

final class DockPanelView: NSView {
    var onItemSelected: ((DockItem) -> Void)?
    var itemMenuProvider: ((DockItem) -> NSMenu?)?
    var panelMenuProvider: (() -> NSMenu?)?

    private let effectView = NSVisualEffectView()
    private let stackView = NSStackView()
    private var items: [DockItem] = []
    private var layoutSettings = DockLayoutSettings.default

    var preferredPanelSize: NSSize {
        let itemHeight: CGFloat = layoutSettings.itemDimension
        let spacing: CGFloat = stackView.spacing
        let count = max(items.count, 1)
        let height = layoutSettings.topInset
            + layoutSettings.bottomInset
            + (CGFloat(count) * itemHeight)
            + (CGFloat(max(0, count - 1)) * spacing)
        let width = layoutSettings.contentInsetLeft + layoutSettings.contentInsetRight + layoutSettings.itemDimension
        return NSSize(width: width, height: height)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureViewHierarchy()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        preferredPanelSize
    }

    func update(items: [DockItem]) {
        self.items = items
        reload()
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    func update(layoutSettings: DockLayoutSettings) {
        self.layoutSettings = layoutSettings
        stackView.spacing = layoutSettings.itemSpacing
        stackView.edgeInsets = NSEdgeInsets(
            top: layoutSettings.topInset,
            left: layoutSettings.contentInsetLeft,
            bottom: layoutSettings.bottomInset,
            right: layoutSettings.contentInsetRight
        )
        reload()
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = panelMenuProvider?() else {
            super.rightMouseDown(with: event)
            return
        }

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func layout() {
        super.layout()
        effectView.frame = bounds
    }

    private func configureViewHierarchy() {
        wantsLayer = true

        effectView.material = .hudWindow
        effectView.state = .active
        effectView.blendingMode = .withinWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 18
        effectView.layer?.masksToBounds = true
        effectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effectView)

        stackView.orientation = .vertical
        stackView.spacing = layoutSettings.itemSpacing
        stackView.alignment = .centerX
        stackView.edgeInsets = NSEdgeInsets(
            top: layoutSettings.topInset,
            left: layoutSettings.contentInsetLeft,
            bottom: layoutSettings.bottomInset,
            right: layoutSettings.contentInsetRight
        )
        stackView.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(stackView)

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: effectView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor)
        ])
    }

    private func reload() {
        stackView.arrangedSubviews.forEach { subview in
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        for item in items {
            let itemView = DockItemView(item: item, layoutSettings: layoutSettings)
            itemView.onPrimaryAction = { [weak self] in
                self?.onItemSelected?(item)
            }
            itemView.menuProvider = itemMenuProvider

            stackView.addArrangedSubview(itemView)
        }
    }
}
