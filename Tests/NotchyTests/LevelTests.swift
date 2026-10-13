import Testing
@testable import Notchy

struct LevelTests {
    @Test func stepsUpAndDown() {
        #expect(NotchModel.stepped(0.5, by: 1, divisions: 16) == 9.0 / 16)
        #expect(NotchModel.stepped(0.5, by: -1, divisions: 16) == 7.0 / 16)
    }

    @Test func snapsToTheNearestStep() {
        #expect(NotchModel.stepped(0.51, by: 1, divisions: 16) == 9.0 / 16)
    }

    @Test func clampsAtTheEnds() {
        #expect(NotchModel.stepped(1, by: 1, divisions: 16) == 1)
        #expect(NotchModel.stepped(0, by: -1, divisions: 16) == 0)
    }

    @Test func fineSteps() {
        #expect(NotchModel.stepped(0.5, by: 1, divisions: 64) == 33.0 / 64)
    }

    @Test func mapsKeyCodes() {
        #expect(MediaKeyMonitor.Key(code: 0) == .volumeUp)
        #expect(MediaKeyMonitor.Key(code: 1) == .volumeDown)
        #expect(MediaKeyMonitor.Key(code: 7) == .mute)
        #expect(MediaKeyMonitor.Key(code: 2) == .brightnessUp)
        #expect(MediaKeyMonitor.Key(code: 3) == .brightnessDown)
        #expect(MediaKeyMonitor.Key(code: 16) == nil)
    }
}
