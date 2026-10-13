import AppKit
import EventKit
import Observation
import SwiftUI

struct AgendaEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let calendarName: String
    let red: Double
    let green: Double
    let blue: Double
    let meetingURL: URL?

    var color: Color { Color(red: red, green: green, blue: blue) }

    func isOngoing(at date: Date) -> Bool { start <= date && end > date }
}

@MainActor
@Observable
final class CalendarService {
    enum Access {
        case unknown
        case granted
        case denied
    }

    nonisolated static let privacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!

    private(set) var events: [AgendaEvent] = []
    private(set) var access: Access = .unknown
    private(set) var tick = Date()

    @ObservationIgnored var onReminder: (@MainActor (AgendaEvent, Int) -> Void)?
    @ObservationIgnored private var preferences: Preferences?
    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var reminded: Set<String> = []

    private static let linkPattern = try! NSRegularExpression(
        pattern: #"https?://[^\s<>"']*(zoom\.us/(j|my|w|s)/|meet\.google\.com/|teams\.microsoft\.com/l/meetup-join|teams\.live\.com/meet|whereby\.com/|webex\.com/)[^\s<>"']*"#,
        options: [.caseInsensitive]
    )

    func start(preferences: Preferences) {
        self.preferences = preferences
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard !SystemActivity.shared.paused else { return }
                self?.advance()
            }
        }
    }

    func requestAccess() {
        store.requestFullAccessToEvents { [weak self] granted, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.access = granted ? .granted : .denied
                    self?.refresh()
                }
            }
        }
    }

    func refresh() {
        updateAccess()
        guard access == .granted else {
            if !events.isEmpty {
                events = []
            }
            return
        }
        let now = Date()
        let predicate = store.predicateForEvents(
            withStart: now.addingTimeInterval(-6 * 3600),
            end: now.addingTimeInterval(36 * 3600),
            calendars: nil
        )
        let next = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.endDate > now && $0.status != .canceled }
            .sorted { $0.startDate < $1.startDate }
            .prefix(12)
            .map(Self.makeEvent)
        if Array(next) != events {
            events = Array(next)
        }
        advance()
    }

    func imminent(within minutes: Int) -> AgendaEvent? {
        _ = tick
        let now = Date()
        return events.first { event in
            let seconds = event.start.timeIntervalSince(now)
            return seconds <= Double(minutes * 60) && seconds > -300 && event.end > now
        }
    }

    private func advance() {
        tick = Date()
        guard let lead = preferences?.meetingLead, lead > 0 else { return }
        let now = Date()
        for event in events {
            let seconds = event.start.timeIntervalSince(now)
            if seconds > 0, seconds <= Double(lead * 60), reminded.insert("\(event.id)-lead").inserted {
                onReminder?(event, Int((seconds / 60).rounded(.up)))
            } else if seconds <= 0, seconds > -90, reminded.insert("\(event.id)-start").inserted {
                onReminder?(event, 0)
            }
        }
    }

    private func updateAccess() {
        let next: Access
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: next = .granted
        case .notDetermined: next = .unknown
        default: next = .denied
        }
        if next != access {
            access = next
        }
    }

    private static func makeEvent(_ event: EKEvent) -> AgendaEvent {
        let base = event.calendar?.color ?? NSColor.systemBlue
        let color = base.usingColorSpace(.deviceRGB) ?? NSColor.systemBlue
        let start: Date = event.startDate
        return AgendaEvent(
            id: "\(event.eventIdentifier ?? UUID().uuidString)-\(start.timeIntervalSince1970)",
            title: event.title ?? "Sem título",
            start: start,
            end: event.endDate,
            calendarName: event.calendar?.title ?? "",
            red: Double(color.redComponent),
            green: Double(color.greenComponent),
            blue: Double(color.blueComponent),
            meetingURL: meetingLink(event)
        )
    }

    private static func meetingLink(_ event: EKEvent) -> URL? {
        let sources = [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }
        for text in sources {
            let range = NSRange(text.startIndex..., in: text)
            if let match = linkPattern.firstMatch(in: text, range: range),
               let bounds = Range(match.range, in: text),
               let url = URL(string: String(text[bounds])) {
                return url
            }
        }
        return nil
    }
}
