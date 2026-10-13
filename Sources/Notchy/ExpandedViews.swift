import AppKit
import SwiftUI

struct ExpandedContent: View {
    let model: NotchModel

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: model.notchHeight)
            Color.clear.frame(height: 8)
            Group {
                if let card = model.youTubeCard {
                    YouTubeCard(video: card, javascriptBlocked: model.browser.isBlocked(card)) {
                        model.watchInNotch(card)
                    }
                } else {
                    MusicSection(music: model.music)
                }
            }
            .frame(height: model.musicHeight)
            if let tab = model.currentTab {
                Color.clear.frame(height: 12)
                TabBar(model: model)
                    .frame(height: NotchModel.tabsHeight)
                Color.clear.frame(height: 8)
                Group {
                    switch tab {
                    case .claude:
                        ClaudePanel(model: model)
                    case .agenda:
                        AgendaPanel(calendar: model.calendar)
                    case .weather:
                        WeatherPanel(weather: model.weather)
                    case .clipboard:
                        ClipboardPanel(clipboard: model.clipboard)
                    case .bluetooth:
                        BluetoothPanel(bluetooth: model.bluetooth)
                    case .shelf:
                        ShelfPanel(model: model)
                    }
                }
                .frame(height: NotchModel.contentHeight, alignment: .top)
                .animation(.easeInOut(duration: 0.15), value: tab)
            }
            Color.clear.frame(height: 14)
        }
        .padding(.horizontal, 18)
    }

    private var header: some View {
        HStack(spacing: 10) {
            if model.hud == nil {
                TimelineView(.everyMinute) { context in
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            if let hud = model.hud {
                VolumeIndicator(level: hud.level, barWidth: 64, kind: hud.kind)
                    .transition(.opacity)
            } else if let snapshot = model.weather.snapshot, model.tabs.contains(.weather) {
                Button {
                    model.select(.weather)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: WeatherCondition.symbol(snapshot.code, isDay: snapshot.isDay))
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 11))
                        Text("\(Int(snapshot.temperature.rounded()))°")
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            HStack(spacing: 8) {
                if let device = model.headphones, let level = device.lowest, model.visibleBadges.count <= 1 {
                    Button {
                        model.select(.bluetooth)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: device.symbol)
                                .font(.system(size: 11))
                            Text("\(level)%")
                                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        }
                        .foregroundStyle(level <= 20 ? Color.red : .white.opacity(0.7))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("\(device.name): \(device.batteryText)")
                }
                ForEach(model.visibleBadges) { item in
                    Button {
                        model.open(item.app)
                    } label: {
                        HStack(spacing: 4) {
                            AppGlyph(app: item.app, trigger: item.label, size: 15)
                            Text(item.label)
                                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.7))
                                .contentTransition(.numericText())
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Abrir o \(item.app.rawValue)")
                }
                HStack(spacing: 0) {
                    IconButton(symbol: "gearshape.fill", help: "Ajustes") {
                        model.openSettings()
                    }
                    IconButton(symbol: "power", help: "Sair do Notchy") {
                        NSApp.terminate(nil)
                    }
                }
            }
        }
    }
}

struct MusicSection: View {
    let music: MusicService

    var body: some View {
        if let track = music.track {
            HStack(spacing: 12) {
                Button {
                    music.openPlayer()
                } label: {
                    Artwork(image: music.artwork, size: 64, radius: 10)
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                        .overlay(alignment: .bottomTrailing) {
                            AppIcon(bundleIDs: [track.source.bundleID], size: 22, fallback: "music.note")
                                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                                .offset(x: 6, y: 6)
                        }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                    PlaybackProgress(music: music, duration: track.duration)
                        .padding(.top, 2)
                }

                HStack(spacing: 6) {
                    IconButton(symbol: "backward.fill", size: 14) { music.previous() }
                    IconButton(symbol: music.isPlaying ? "pause.fill" : "play.fill", size: 20, frame: 34) { music.playPause() }
                    IconButton(symbol: "forward.fill", size: 14) { music.next() }
                }
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                Text("Nada tocando")
            }
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.45))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

struct PlaybackProgress: View {
    let music: MusicService
    let duration: Double

    @State var scrub: Double? = nil
    @State var hovering = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let position = scrub ?? music.position(at: context.date)
            let active = hovering || scrub != nil
            VStack(spacing: 3) {
                GeometryReader { proxy in
                    let width = max(proxy.size.width, 1)
                    let progress = duration > 0 ? min(position / duration, 1) : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.15))
                        Capsule()
                            .fill(.white.opacity(active ? 1 : 0.85))
                            .frame(width: width * progress)
                        if active {
                            Circle()
                                .fill(.white)
                                .frame(width: 10, height: 10)
                                .offset(x: width * progress - 5)
                        }
                    }
                    .frame(height: active ? 6 : 4)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                scrub = Self.fraction(value.location.x, width) * duration
                            }
                            .onEnded { value in
                                music.seek(to: Self.fraction(value.location.x, width) * duration)
                                scrub = nil
                            }
                    )
                    .onHover { hovering = $0 }
                }
                .frame(height: 12)

                HStack {
                    Text(Self.format(position))
                    Spacer()
                    Text("-" + Self.format(max(duration - position, 0)))
                }
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.white.opacity(0.45))
            }
        }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }

    static func fraction(_ x: CGFloat, _ width: CGFloat) -> Double {
        Double(min(max(x / width, 0), 1))
    }

    static func format(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct ClaudePanel: View {
    let model: NotchModel

    var body: some View {
        if model.claude.sessions.isEmpty {
            EmptyState(symbol: "asterisk", text: "Nenhuma sessão do Claude Code")
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(model.claude.sessions) { session in
                        SessionRow(session: session, context: model.claude.contexts[session.id]) {
                            model.open(session)
                        }
                        .frame(height: NotchModel.rowHeight)
                    }
                }
                .padding(.horizontal, 6)
            }
            .padding(.horizontal, -6)
        }
    }
}

struct SessionRow: View {
    let session: ClaudeSession
    let context: Double?
    let action: () -> Void

    @State var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                StatusIcon(status: session.effectiveStatus, size: 13)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.project)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(session.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 8)
                if hovering {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        TimelineView(.periodic(from: .now, by: 1)) { timeline in
                            Text(Self.elapsed(from: session.updated, to: timeline.date))
                        }
                        if let context {
                            Text("\(Int(context.rounded()))% ctx")
                        }
                    }
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 6)
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.white.opacity(hovering ? 0.07 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -6)
        .onHover { hovering = $0 }
    }

    static func elapsed(from start: Date, to end: Date) -> String {
        let seconds = max(Int(end.timeIntervalSince(start)), 0)
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h"
    }
}

struct UsageGauge: View {
    let label: String
    let window: UsageWindow

    @State var hovering = false

    private var color: Color {
        if window.usedPercentage >= 95 { return .red }
        if window.usedPercentage >= 80 { return .orange }
        return .green
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .foregroundStyle(.white.opacity(0.4))
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule()
                    .fill(color)
                    .frame(width: 34 * min(max(window.usedPercentage, 0), 100) / 100)
            }
            .frame(width: 34, height: 4)
            Text(hovering ? "↻ \(window.resetText)" : "\(Int(window.usedPercentage.rounded()))%")
                .foregroundStyle(.white.opacity(0.7))
                .frame(minWidth: 30, alignment: .leading)
        }
        .font(.system(size: 10, weight: .semibold).monospacedDigit())
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}
