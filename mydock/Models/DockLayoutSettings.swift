import Foundation

struct DockLayoutSettings: Equatable {
    static let `default` = DockLayoutSettings()

    var contentInsetLeft: CGFloat = 12
    var contentInsetRight: CGFloat = 12
    var itemSpacing: CGFloat = 10
    var iconSize: CGFloat = 34
    var dockScreenLeftOffset: CGFloat = 16

    var itemDimension: CGFloat {
        max(iconSize + 20, 52)
    }

    var badgeDiameter: CGFloat {
        max(18, min(24, iconSize * 0.5))
    }

    var topInset: CGFloat {
        12
    }

    var bottomInset: CGFloat {
        12
    }
}
