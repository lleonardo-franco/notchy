import AppKit

struct SwipeTracker {
    enum Axis {
        case none
        case horizontal
        case vertical
    }

    enum Output {
        case horizontal(right: Bool)
        case volume(steps: Int)
        case vertical(down: Bool)
    }

    static let axisThreshold: CGFloat = 10
    static let horizontalThreshold: CGFloat = 45
    static let verticalThreshold: CGFloat = 32
    static let volumeStep: CGFloat = 14

    private(set) var axis: Axis = .none
    private var total = CGVector.zero
    private var fired = false
    private var carry: CGFloat = 0

    mutating func reset() {
        axis = .none
        total = .zero
        fired = false
        carry = 0
    }

    mutating func feed(_ event: NSEvent, continuousVertical: Bool) -> Output? {
        guard event.hasPreciseScrollingDeltas, event.momentumPhase.isEmpty else { return nil }
        if event.phase.contains(.began) {
            reset()
        }
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            reset()
            return nil
        }

        let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
        let dx = event.scrollingDeltaX * sign
        let dy = event.scrollingDeltaY * sign
        total.dx += dx
        total.dy += dy

        if axis == .none {
            guard abs(total.dx) > Self.axisThreshold || abs(total.dy) > Self.axisThreshold else { return nil }
            axis = abs(total.dx) > abs(total.dy) ? .horizontal : .vertical
        }

        switch axis {
        case .none:
            return nil
        case .horizontal:
            guard !fired, abs(total.dx) > Self.horizontalThreshold else { return nil }
            fired = true
            return .horizontal(right: total.dx > 0)
        case .vertical:
            if continuousVertical {
                carry -= dy
                var steps = 0
                while carry >= Self.volumeStep {
                    steps += 1
                    carry -= Self.volumeStep
                }
                while carry <= -Self.volumeStep {
                    steps -= 1
                    carry += Self.volumeStep
                }
                return steps == 0 ? nil : .volume(steps: steps)
            }
            guard !fired, abs(total.dy) > Self.verticalThreshold else { return nil }
            fired = true
            return .vertical(down: total.dy > 0)
        }
    }
}
