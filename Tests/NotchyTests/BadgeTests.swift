import Testing
@testable import Notchy

struct BadgeTests {
    @Test(arguments: [
        ("3", 3),
        ("99+", 99),
        ("•", 1),
        ("", 0)
    ])
    func readsBadgeValue(_ label: String, _ value: Int) {
        #expect(BadgeService.value(label) == value)
    }

    @Test func missingBadgeIsZero() {
        #expect(BadgeService.value(nil) == 0)
    }

    @Test func matchesDockTitles() {
        #expect(BadgeApp.matching(dockTitle: "WhatsApp") == .whatsapp)
        #expect(BadgeApp.matching(dockTitle: "Telegram Desktop") == .telegram)
        #expect(BadgeApp.matching(dockTitle: "Slack") == .slack)
        #expect(BadgeApp.matching(dockTitle: "Finder") == nil)
    }
}
