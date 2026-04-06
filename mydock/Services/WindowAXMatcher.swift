import ApplicationServices
import CoreGraphics
import Foundation

struct AXWindowCandidate {
    let element: AXUIElement
    let title: String?
    let bounds: CGRect
}

final class WindowAXMatcher {
    func bestMatch(for target: WindowIdentity, applicationElement: AXUIElement) -> AXUIElement? {
        let candidates = axWindowCandidates(for: applicationElement)

        guard !candidates.isEmpty else {
            return nil
        }

        if candidates.count == 1 {
            return candidates[0].element
        }

        return candidates
            .map { ($0.element, score(for: $0, target: target)) }
            .max(by: { $0.1 < $1.1 })?
            .0
    }

    private func axWindowCandidates(for applicationElement: AXUIElement) -> [AXWindowCandidate] {
        guard let windows = copyAttributeValue(
            for: applicationElement,
            attribute: kAXWindowsAttribute as CFString
        ) as? [AXUIElement] else {
            return []
        }

        return windows.map { window in
            AXWindowCandidate(
                element: window,
                title: copyAttributeValue(for: window, attribute: kAXTitleAttribute as CFString) as? String,
                bounds: bounds(for: window)
            )
        }
    }

    private func score(for candidate: AXWindowCandidate, target: WindowIdentity) -> Double {
        var score = 0.0
        let candidateTitle = normalized(candidate.title)
        let targetTitle = normalized(target.title)

        if !candidateTitle.isEmpty, candidateTitle == targetTitle {
            score += 120
        } else if !candidateTitle.isEmpty, !targetTitle.isEmpty {
            if candidateTitle.localizedCaseInsensitiveContains(targetTitle)
                || targetTitle.localizedCaseInsensitiveContains(candidateTitle) {
                score += 70
            }
        } else if candidateTitle.isEmpty, targetTitle.isEmpty {
            score += 15
        }

        let originDistance = abs(candidate.bounds.minX - target.bounds.minX)
            + abs(candidate.bounds.minY - target.bounds.minY)
        let sizeDistance = abs(candidate.bounds.width - target.bounds.width)
            + abs(candidate.bounds.height - target.bounds.height)
        let distancePenalty = min(originDistance + sizeDistance, 140)

        score += max(0, 110 - distancePenalty)

        if candidate.bounds.integral.equalTo(target.bounds.integral) {
            score += 40
        }

        return score
    }

    private func bounds(for window: AXUIElement) -> CGRect {
        let position = copyAXValue(for: window, attribute: kAXPositionAttribute as CFString)
            .flatMap(pointValue(from:))
            ?? .zero
        let size = copyAXValue(for: window, attribute: kAXSizeAttribute as CFString)
            .flatMap(sizeValue(from:))
            ?? .zero

        return CGRect(origin: position, size: size)
    }

    private func copyAttributeValue(for element: AXUIElement, attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else {
            return nil
        }

        return value
    }

    private func copyAXValue(for element: AXUIElement, attribute: CFString) -> AXValue? {
        guard let value = copyAttributeValue(for: element, attribute: attribute) else {
            return nil
        }

        return unsafeDowncast(value, to: AXValue.self)
    }

    private func pointValue(from value: AXValue) -> CGPoint? {
        guard AXValueGetType(value) == .cgPoint else {
            return nil
        }

        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    private func sizeValue(from value: AXValue) -> CGSize? {
        guard AXValueGetType(value) == .cgSize else {
            return nil
        }

        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    private func normalized(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
