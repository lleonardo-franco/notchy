import Testing
@testable import Notchy

struct SwipeTrackerTests {
    @Test func smallMovementsDoNothing() {
        var tracker = SwipeTracker()
        #expect(tracker.feed(dx: 4, dy: 3, began: true, continuousVertical: true) == nil)
        #expect(tracker.axis == .none)
    }

    @Test func horizontalSwipeFiresOnce() {
        var tracker = SwipeTracker()
        #expect(tracker.feed(dx: 20, dy: 2, began: true, continuousVertical: true) == nil)
        #expect(tracker.feed(dx: 30, dy: 0, continuousVertical: true) == .horizontal(right: true))
        #expect(tracker.feed(dx: 60, dy: 0, continuousVertical: true) == nil)
    }

    @Test func leftSwipe() {
        var tracker = SwipeTracker()
        _ = tracker.feed(dx: -20, dy: 0, began: true, continuousVertical: true)
        #expect(tracker.feed(dx: -30, dy: 0, continuousVertical: true) == .horizontal(right: false))
    }

    @Test func axisLocksToTheFirstDirection() {
        var tracker = SwipeTracker()
        _ = tracker.feed(dx: 12, dy: 2, began: true, continuousVertical: true)
        #expect(tracker.axis == .horizontal)
        #expect(tracker.feed(dx: 0, dy: -80, continuousVertical: true) == nil)
    }

    @Test func verticalSwipeChangesVolumeInSteps() {
        var tracker = SwipeTracker()
        _ = tracker.feed(dx: 0, dy: -12, began: true, continuousVertical: true)
        #expect(tracker.axis == .vertical)
        #expect(tracker.feed(dx: 0, dy: -16, continuousVertical: true) == .volume(steps: 2))
        #expect(tracker.feed(dx: 0, dy: 30, continuousVertical: true) == .volume(steps: -2))
    }

    @Test func verticalSwipeWithoutVolumeFiresOnce() {
        var tracker = SwipeTracker()
        _ = tracker.feed(dx: 0, dy: 20, began: true, continuousVertical: false)
        #expect(tracker.feed(dx: 0, dy: 20, continuousVertical: false) == .vertical(down: true))
        #expect(tracker.feed(dx: 0, dy: 20, continuousVertical: false) == nil)
    }

    @Test func endingResets() {
        var tracker = SwipeTracker()
        _ = tracker.feed(dx: 30, dy: 0, began: true, continuousVertical: true)
        #expect(tracker.feed(dx: 0, dy: 0, ended: true, continuousVertical: true) == nil)
        #expect(tracker.axis == .none)
    }
}
