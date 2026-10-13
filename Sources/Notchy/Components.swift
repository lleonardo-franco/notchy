import AppKit
import SwiftUI

extension Color {
    static let claude = Color(red: 0.85, green: 0.47, blue: 0.34)
    static let clickup = Color(red: 0.48, green: 0.41, blue: 0.93)
    static let clickupPink = Color(red: 0.99, green: 0.44, blue: 0.69)
}

struct NotificationBadge: View {
    let text: String
    let colors: [Color]

    @State var bump = false

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white)
            .contentTransition(.numericText())
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 16)
            .background(
                Capsule().fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            )
            .shadow(color: (colors.last ?? .white).opacity(bump ? 0.9 : 0), radius: bump ? 8 : 0)
            .scaleEffect(bump ? 1.35 : 1)
            .fixedSize()
            .animation(.snappy, value: text)
            .onChange(of: text) { old, new in
                guard BadgeService.value(new) > BadgeService.value(old) else { return }
                withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
                    bump = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        bump = false
                    }
                }
            }
    }
}

struct AppGlyph: View {
    let app: BadgeApp
    let trigger: String
    var size: CGFloat = 12

    var body: some View {
        Image(systemName: app.symbol)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(LinearGradient(colors: app.colors, startPoint: .top, endPoint: .bottom))
            .symbolEffect(.bounce, value: trigger)
    }
}

struct StatusIcon: View {
    let status: ClaudeSession.Status
    var size: CGFloat = 13

    var body: some View {
        switch status {
        case .working:
            TimelineView(.animation) { context in
                let angle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2) * 180
                Image(systemName: "asterisk")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(Color.claude)
                    .rotationEffect(.degrees(angle))
            }
        case .waiting:
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.system(size: size))
                .foregroundStyle(.yellow)
                .symbolEffect(.pulse, options: .repeating)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: size))
                .foregroundStyle(.green)
        case .idle:
            Circle()
                .fill(.white.opacity(0.3))
                .frame(width: size * 0.5, height: size * 0.5)
        }
    }
}

struct Equalizer: View {
    let playing: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !playing)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    let phase = Double(index)
                    Capsule()
                        .fill(.white.opacity(0.85))
                        .frame(width: 2.5, height: playing ? 4 + 9 * abs(sin(time * (3 + phase * 0.7) + phase)) : 3)
                }
            }
            .frame(height: 14)
        }
    }
}

struct Artwork: View {
    let image: NSImage?
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct IconButton: View {
    let symbol: String
    var size: CGFloat = 12
    var frame: CGFloat = 26
    var help: String = ""
    let action: () -> Void

    @State var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white.opacity(hovering ? 1 : 0.8))
                .frame(width: frame, height: frame)
                .background(Circle().fill(.white.opacity(hovering ? 0.12 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

struct PillButton: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    let style: Style
    let action: () -> Void

    @State var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(style == .primary ? Color.black : Color.white)
                .padding(.horizontal, 16)
                .frame(height: 28)
                .background(
                    Capsule().fill(style == .primary
                        ? Color.white.opacity(hovering ? 1 : 0.9)
                        : Color.white.opacity(hovering ? 0.2 : 0.12))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct VolumeIndicator: View {
    let level: Double
    let barWidth: CGFloat

    private var symbol: String {
        if level <= 0 { return "speaker.slash.fill" }
        if level < 0.34 { return "speaker.wave.1.fill" }
        if level < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 18)
                .contentTransition(.symbolEffect(.replace))
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule()
                    .fill(.white)
                    .frame(width: barWidth * level)
            }
            .frame(width: barWidth, height: 5)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: level)
            Text("\(Int((level * 100).rounded()))")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 24, alignment: .trailing)
                .contentTransition(.numericText())
        }
    }
}
