import AppKit
import SwiftUI

struct TabBar: View {
    let model: NotchModel

    var body: some View {
        HStack(spacing: 4) {
            ViewThatFits(in: .horizontal) {
                pills(compact: false)
                pills(compact: true)
            }
            Spacer(minLength: 8)
            accessory
        }
    }

    private func pills(compact: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(model.tabs, id: \.self) { tab in
                let selected = model.currentTab == tab
                TabPill(title: tab.title, symbol: compact && !selected ? tab.symbol : nil, selected: selected) {
                    model.select(tab)
                }
            }
        }
    }

    @ViewBuilder
    private var accessory: some View {
        switch model.currentTab {
        case .agenda?, nil:
            EmptyView()
        case .bluetooth?:
            IconButton(symbol: "arrow.clockwise", size: 10, frame: 22, help: "Atualizar") {
                model.bluetooth.refresh()
            }
        case .claude?:
            HStack(spacing: 10) {
                if let window = model.claude.usage.fiveHour {
                    UsageGauge(label: "5h", window: window, length: 5 * 3600)
                }
                if let window = model.claude.usage.sevenDay {
                    UsageGauge(label: "7d", window: window, length: 7 * 86400)
                }
            }
        case .weather?:
            if model.weather.isLoading {
                ProgressView()
                    .controlSize(.mini)
            } else {
                IconButton(symbol: "arrow.clockwise", size: 10, frame: 22, help: "Atualizar") {
                    model.weather.refresh()
                }
            }
        case .shelf?:
            if !model.shelf.items.isEmpty, !model.fileDrag {
                HStack(spacing: 6) {
                    IconButton(symbol: "dot.radiowaves.left.and.right", size: 10, frame: 22, help: "Enviar tudo por AirDrop") {
                        model.shelf.airDrop(model.shelf.items.map(\.url))
                    }
                    Button {
                        model.shelf.clear()
                    } label: {
                        Text("Limpar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        case .clipboard?:
            if !model.clipboard.items.isEmpty {
                Button {
                    model.clipboard.clear()
                } label: {
                    Text("Limpar")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct TabPill: View {
    let title: String
    var symbol: String?
    let selected: Bool
    let action: () -> Void

    @Environment(\.notchHighlight) private var highlight

    @State var hovering = false

    var body: some View {
        Button(action: action) {
            label
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(selected ? 1 : (hovering ? 0.75 : 0.45)))
                .padding(.horizontal, symbol == nil ? 10 : 8)
                .frame(height: 22)
                .background(
                    Capsule().fill(selected ? highlight.opacity(0.3) : .white.opacity(hovering ? 0.06 : 0))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(symbol == nil ? "" : title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var label: some View {
        if let symbol {
            Image(systemName: symbol)
        } else {
            Text(title)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

struct EmptyState: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WeatherPanel: View {
    let weather: WeatherService

    var body: some View {
        if let snapshot = weather.snapshot {
            VStack(spacing: 10) {
                summary(snapshot)
                    .frame(height: 62)
                hourly(snapshot)
            }
        } else if weather.failed {
            VStack(spacing: 10) {
                EmptyState(symbol: "wifi.exclamationmark", text: "Não consegui carregar o clima")
                    .frame(height: 70)
                Button {
                    weather.refresh()
                } label: {
                    Text("Tentar de novo")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 24)
                        .background(Capsule().fill(.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Carregando o clima…")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func summary(_ snapshot: WeatherSnapshot) -> some View {
        HStack(spacing: 14) {
            Image(systemName: WeatherCondition.symbol(snapshot.code, isDay: snapshot.isDay))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 34))
                .frame(width: 46)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(Int(snapshot.temperature.rounded()))°")
                    .font(.system(size: 32, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                Text(WeatherCondition.text(snapshot.code))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(snapshot.city)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Text("máx \(Int(snapshot.high.rounded()))°  mín \(Int(snapshot.low.rounded()))°")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
                Text("sensação \(Int(snapshot.feelsLike.rounded()))°")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func hourly(_ snapshot: WeatherSnapshot) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(snapshot.hours.enumerated()), id: \.element.id) { index, hour in
                VStack(spacing: 5) {
                    Text(index == 0 ? String(localized: "Agora") : Self.hourLabel(hour.date, zone: snapshot.timeZone))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Image(systemName: WeatherCondition.symbol(hour.code, isDay: hour.isDay))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 15))
                        .frame(height: 18)
                    Text("\(Int(hour.temperature.rounded()))°")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                    Text(hour.rain >= 10 ? "\(hour.rain)%" : " ")
                        .font(.system(size: 9, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(red: 0.45, green: 0.72, blue: 1))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.06))
        )
    }

    static func hourLabel(_ date: Date, zone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return "\(calendar.component(.hour, from: date))h"
    }
}

struct ClipboardPanel: View {
    let clipboard: ClipboardService

    @State var copied: UUID? = nil

    var body: some View {
        if clipboard.items.isEmpty {
            EmptyState(symbol: "doc.on.clipboard", text: "Copie algo e ele aparece aqui")
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(clipboard.items) { item in
                        ClipRow(item: item, copied: copied == item.id) {
                            clipboard.copy(item)
                            copied = item.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                if copied == item.id {
                                    copied = nil
                                }
                            }
                        } onRemove: {
                            clipboard.remove(item)
                        }
                    }
                }
                .padding(.horizontal, 6)
            }
            .padding(.horizontal, -6)
        }
    }
}

struct ClipRow: View {
    let item: ClipItem
    let copied: Bool
    let onCopy: () -> Void
    let onRemove: () -> Void

    @State var hovering = false

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 10) {
                thumbnail
                    .frame(width: 26, height: 26)
                Text(item.preview)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, 8)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.white.opacity(hovering ? 0.07 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Clique para copiar de novo")
    }

    @ViewBuilder
    private var trailing: some View {
        if copied {
            Label("Copiado", systemImage: "checkmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.green)
        } else if hovering {
            IconButton(symbol: "xmark", size: 9, frame: 20, help: "Remover", action: onRemove)
        } else {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(Self.ago(item.date, now: context.date))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch item.kind {
        case .image(let image):
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        case .file(let url):
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .text:
            Image(systemName: "text.alignleft")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.white.opacity(0.08))
                )
        }
    }

    static func ago(_ date: Date, now: Date) -> String {
        let seconds = max(Int(now.timeIntervalSince(date)), 0)
        if seconds < 60 { return String(localized: "agora") }
        if seconds < 3600 { return "\(seconds / 60) min" }
        if seconds < 86400 { return "\(seconds / 3600) h" }
        return "\(seconds / 86400) d"
    }
}
