import AppKit

@MainActor
final class PreferencesWindowController: NSWindowController {
    var onLayoutSettingsChanged: ((DockLayoutSettings) -> Void)? {
        didSet {
            preferencesViewController.onLayoutSettingsChanged = onLayoutSettingsChanged
        }
    }

    private let preferencesViewController = PreferencesViewController()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "mydock Settings"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentViewController = preferencesViewController

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func update(settings: DockLayoutSettings) {
        preferencesViewController.update(settings: settings)
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
private final class PreferencesViewController: NSViewController {
    var onLayoutSettingsChanged: ((DockLayoutSettings) -> Void)?

    private var settings = DockLayoutSettings.default
    private let stackView = NSStackView()

    private lazy var leftPaddingRow = SliderRowView(
        title: "Left Inner Padding",
        minValue: 0,
        maxValue: 40
    ) { [weak self] value in
        self?.updateSetting { $0.contentInsetLeft = value }
    }

    private lazy var rightPaddingRow = SliderRowView(
        title: "Right Inner Padding",
        minValue: 0,
        maxValue: 40
    ) { [weak self] value in
        self?.updateSetting { $0.contentInsetRight = value }
    }

    private lazy var spacingRow = SliderRowView(
        title: "Spacing Between Icons",
        minValue: 0,
        maxValue: 32
    ) { [weak self] value in
        self?.updateSetting { $0.itemSpacing = value }
    }

    private lazy var iconSizeRow = SliderRowView(
        title: "Icon Size",
        minValue: 24,
        maxValue: 72
    ) { [weak self] value in
        self?.updateSetting { $0.iconSize = value }
    }

    private lazy var dockOffsetRow = SliderRowView(
        title: "Dock Left Offset",
        minValue: 0,
        maxValue: 80
    ) { [weak self] value in
        self?.updateSetting { $0.dockScreenLeftOffset = value }
    }

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        configureViewHierarchy()
    }

    func update(settings: DockLayoutSettings) {
        self.settings = settings
        leftPaddingRow.setValue(settings.contentInsetLeft)
        rightPaddingRow.setValue(settings.contentInsetRight)
        spacingRow.setValue(settings.itemSpacing)
        iconSizeRow.setValue(settings.iconSize)
        dockOffsetRow.setValue(settings.dockScreenLeftOffset)
    }

    private func configureViewHierarchy() {
        let titleLabel = NSTextField(labelWithString: "Layout")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)

        let descriptionLabel = NSTextField(
            wrappingLabelWithString: "Changes are applied immediately and persisted in UserDefaults."
        )
        descriptionLabel.textColor = .secondaryLabelColor

        stackView.orientation = .vertical
        stackView.spacing = 16
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false

        [titleLabel, descriptionLabel, leftPaddingRow, rightPaddingRow, spacingRow, iconSizeRow, dockOffsetRow].forEach {
            stackView.addArrangedSubview($0)
        }

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20),
            leftPaddingRow.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            rightPaddingRow.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            spacingRow.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            iconSizeRow.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            dockOffsetRow.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        ])
    }

    private func updateSetting(_ mutate: (inout DockLayoutSettings) -> Void) {
        mutate(&settings)
        onLayoutSettingsChanged?(settings)
    }
}

private final class SliderRowView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "")
    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let onValueChanged: (CGFloat) -> Void

    init(
        title: String,
        minValue: Double,
        maxValue: Double,
        onValueChanged: @escaping (CGFloat) -> Void
    ) {
        self.onValueChanged = onValueChanged
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = title
        slider.minValue = minValue
        slider.maxValue = maxValue
        slider.target = self
        slider.action = #selector(handleSliderChange(_:))
        configureViewHierarchy()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func setValue(_ value: CGFloat) {
        slider.doubleValue = Double(value)
        valueLabel.stringValue = Int(value.rounded()).description
    }

    @objc
    private func handleSliderChange(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue.rounded())
        sender.doubleValue = Double(value)
        valueLabel.stringValue = Int(value).description
        onValueChanged(value)
    }

    private func configureViewHierarchy() {
        let labelsRow = NSStackView(views: [titleLabel, NSView(), valueLabel])
        labelsRow.orientation = .horizontal
        labelsRow.alignment = .centerY
        labelsRow.translatesAutoresizingMaskIntoConstraints = false

        slider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(labelsRow)
        addSubview(slider)

        NSLayoutConstraint.activate([
            labelsRow.leadingAnchor.constraint(equalTo: leadingAnchor),
            labelsRow.trailingAnchor.constraint(equalTo: trailingAnchor),
            labelsRow.topAnchor.constraint(equalTo: topAnchor),

            slider.leadingAnchor.constraint(equalTo: leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor),
            slider.topAnchor.constraint(equalTo: labelsRow.bottomAnchor, constant: 6),
            slider.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
