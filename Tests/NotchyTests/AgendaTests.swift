import Foundation
import Testing
@testable import Notchy

@MainActor
struct AgendaTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }()

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func sameDayHasNoLabel() {
        let now = date(2026, 10, 12, 9)
        #expect(EventRow.dayLabel(date(2026, 10, 12, 23), now: now, calendar: calendar) == nil)
    }

    @Test func nextDayIsTomorrow() {
        let now = date(2026, 10, 12, 23)
        #expect(EventRow.dayLabel(date(2026, 10, 13, 0), now: now, calendar: calendar) == String(localized: "amanhã"))
    }

    @Test func twoDaysLaterIsWeekday() {
        let monday = date(2026, 10, 12)
        let wednesday = date(2026, 10, 14)
        #expect(EventRow.dayLabel(wednesday, now: monday, calendar: calendar, locale: Locale(identifier: "pt_BR")) == "quarta")
        #expect(EventRow.dayLabel(wednesday, now: monday, calendar: calendar, locale: Locale(identifier: "en_US")) == "Wednesday")
        #expect(EventRow.dayLabel(wednesday, now: monday, calendar: calendar, locale: Locale(identifier: "es_ES")) == "miércoles")
    }

    @Test func tomorrowAcrossMonthAndYear() {
        #expect(EventRow.dayLabel(date(2026, 11, 1), now: date(2026, 10, 31), calendar: calendar) == String(localized: "amanhã"))
        #expect(EventRow.dayLabel(date(2027, 1, 1), now: date(2026, 12, 31), calendar: calendar) == String(localized: "amanhã"))
    }

    @Test(arguments: [
        "https://us02web.zoom.us/j/123456789?pwd=abc",
        "https://meet.google.com/abc-defg-hij",
        "https://teams.microsoft.com/l/meetup-join/19%3ameeting",
        "https://acme.webex.com/meet/someone",
        "https://whereby.com/team-room"
    ])
    func findsMeetingLinks(_ link: String) {
        let found = CalendarService.meetingLink(in: ["Sala 3", "Entre pelo link \(link) e aguarde"])
        #expect(found?.absoluteString == link)
    }

    @Test func ignoresOtherLinks() {
        #expect(CalendarService.meetingLink(in: ["https://example.com/agenda", "Escritório"]) == nil)
    }
}
