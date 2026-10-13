import AppKit
import SwiftUI

struct AgendaPanel: View {
    let calendar: CalendarService

    var body: some View {
        switch calendar.access {
        case .unknown:
            VStack(spacing: 10) {
                EmptyState(symbol: "calendar", text: "Veja suas próximas reuniões aqui")
                    .frame(height: 80)
                PillButton(title: "Permitir acesso ao Calendário", style: .primary) {
                    calendar.requestAccess()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .denied:
            VStack(spacing: 10) {
                EmptyState(symbol: "calendar.badge.exclamationmark", text: "O Notchy não tem acesso ao Calendário")
                    .frame(height: 80)
                PillButton(title: "Abrir Ajustes do Sistema", style: .secondary) {
                    NSWorkspace.shared.open(CalendarService.privacyURL)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .granted:
            if calendar.events.isEmpty {
                EmptyState(symbol: "calendar", text: "Nada na agenda pelas próximas horas")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(calendar.events) { event in
                            EventRow(event: event)
                                .frame(height: NotchModel.rowHeight)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .padding(.horizontal, -6)
            }
        }
    }
}

struct EventRow: View {
    let event: AgendaEvent

    @State var hovering = false

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let ongoing = event.isOngoing(at: now)
            let soon = event.start.timeIntervalSince(now) < 600
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(event.color)
                    .frame(width: 4, height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(Self.subtitle(event, now: now))
                        .font(.system(size: 11))
                        .foregroundStyle(ongoing ? Color.green.opacity(0.9) : .white.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let url = event.meetingURL {
                    PillButton(title: "Entrar", style: ongoing || soon ? .primary : .secondary) {
                        NSWorkspace.shared.open(url)
                    }
                } else {
                    Text(Self.relative(event, now: now))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 6)
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(ongoing ? Color.green.opacity(0.08) : .white.opacity(hovering ? 0.05 : 0))
            )
        }
        .padding(.horizontal, -6)
        .onHover { hovering = $0 }
    }

    static func subtitle(_ event: AgendaEvent, now: Date) -> String {
        if event.isOngoing(at: now) {
            return String(localized: "agora · termina às \(clock.string(from: event.end))")
        }
        let day = dayLabel(event.start, now: now).map { "\($0) " } ?? ""
        let range = "\(day)\(clock.string(from: event.start)) – \(clock.string(from: event.end))"
        return event.calendarName.isEmpty ? range : "\(range) · \(event.calendarName)"
    }

    static func relative(_ event: AgendaEvent, now: Date) -> String {
        let minutes = Int((event.start.timeIntervalSince(now) / 60).rounded(.up))
        if minutes <= 0 { return String(localized: "agora") }
        if minutes < 60 { return String(localized: "em \(minutes) min") }
        if let day = dayLabel(event.start, now: now) { return day }
        return String(localized: "em \(minutes / 60) h")
    }

    static func dayLabel(_ date: Date, now: Date, calendar: Calendar = .current, locale: Locale = .interface) -> String? {
        if calendar.isDate(date, inSameDayAs: now) { return nil }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return String(localized: "amanhã")
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date).replacingOccurrences(of: "-feira", with: "")
    }
}
