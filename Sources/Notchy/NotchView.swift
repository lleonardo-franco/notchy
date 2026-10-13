import AppKit
import SwiftUI

struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let left = rect.minX + topRadius
        let right = rect.maxX - topRadius
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: left, y: rect.minY + topRadius), control: CGPoint(x: left, y: rect.minY))
        path.addLine(to: CGPoint(x: left, y: rect.maxY - bottomRadius))
        path.addQuadCurve(to: CGPoint(x: left + bottomRadius, y: rect.maxY), control: CGPoint(x: left, y: rect.maxY))
        path.addLine(to: CGPoint(x: right - bottomRadius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: right, y: rect.maxY - bottomRadius), control: CGPoint(x: right, y: rect.maxY))
        path.addLine(to: CGPoint(x: right, y: rect.minY + topRadius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: right, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct NotchView: View {
    let model: NotchModel

    var body: some View {
        let shape = NotchShape(topRadius: model.topRadius, bottomRadius: model.bottomRadius)
        let tint = model.accentColor ?? .clear
        ZStack(alignment: .top) {
            shape
                .fill(Color.black)
                .shadow(color: .black.opacity(model.isWide ? 0.45 : 0), radius: 18, y: 8)

            Capsule()
                .fill(LinearGradient(
                    colors: [.clear, Color.claude, Color(red: 1, green: 0.88, blue: 0.74), Color.claude, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: model.glowWidth, height: 3)
                .shadow(color: Color.claude.opacity(0.9), radius: 8)
                .shadow(color: Color.claude.opacity(0.5), radius: 2)
                .offset(y: model.notchHeight - 1.5)
                .opacity(model.glowOpacity)
                .zIndex(1)

            shape
                .fill(LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: model.notchFraction),
                        .init(color: tint.opacity(0.55), location: 0.6),
                        .init(color: tint.opacity(0.9), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .opacity(model.accentColor == nil ? 0 : 1)

            content
                .padding(.horizontal, model.topRadius)
                .frame(width: model.size.width, height: model.size.height, alignment: .top)
                .clipShape(shape)
        }
        .frame(width: model.size.width, height: model.size.height)
        .animation(model.shapeAnimation, value: model.mode)
        .animation(model.shapeAnimation, value: model.size)
        .animation(.easeInOut(duration: 0.25), value: model.peek)
        .animation(.easeInOut(duration: 0.6), value: model.accentColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var content: some View {
        switch model.mode {
        case .expanded:
            ExpandedContent(model: model)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                    removal: .opacity.animation(.easeOut(duration: 0.1))
                ))
        case .approval:
            ApprovalContent(model: model)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                    removal: .opacity.animation(.easeOut(duration: 0.1))
                ))
        case .collapsed, .peek:
            CollapsedContent(model: model)
                .transition(.opacity)
        case .farewell:
            FarewellContent(model: model)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .top)).animation(.easeOut(duration: 0.5).delay(0.15)),
                    removal: .opacity.animation(.easeOut(duration: 0.3))
                ))
        case .closing:
            Color.clear
        case .video:
            VideoContent(model: model)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                    removal: .opacity.animation(.easeOut(duration: 0.15))
                ))
        }
    }
}

struct CollapsedContent: View {
    let model: NotchModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                leftEar.frame(width: model.earWidth)
                Spacer(minLength: model.notchWidth)
                rightEar.frame(width: model.earWidth)
            }
            .frame(width: model.notchWidth + model.earWidth * 2, height: model.notchHeight)
            .opacity(model.showsEars || model.peek != nil || model.volumeLevel != nil ? 1 : 0)

            if let level = model.volumeLevel {
                VolumeIndicator(level: level, barWidth: 140)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .transition(.opacity)
            } else if let peek = model.peek {
                HStack(spacing: 6) {
                    PeekIcon(style: peek.style)
                    Text(peek.title)
                        .fontWeight(.semibold)
                    Text(peek.subtitle)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var leftEar: some View {
        if let event = model.imminentEvent {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(event.color)
                .symbolEffect(.pulse, options: .repeating)
        } else if model.music.track != nil {
            Artwork(image: model.music.artwork, size: model.notchHeight * 0.58, radius: 5)
        } else if let top = model.activeSessions.first {
            StatusIcon(status: top.effectiveStatus, size: 12)
        } else if let first = model.visibleBadges.first {
            AppGlyph(app: first.app, trigger: first.label, size: model.notchHeight * 0.58)
                .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var rightEar: some View {
        HStack(spacing: 4) {
            primaryRight
            ForEach(model.visibleBadges) { item in
                EarBadge(item: item)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: model.visibleBadges)
    }

    @ViewBuilder
    private var primaryRight: some View {
        if let event = model.imminentEvent {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(Self.countdown(to: event.start, now: context.date))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(event.color)
                    .lineLimit(1)
                    .fixedSize()
            }
        } else if let top = model.activeSessions.first {
            if model.music.track != nil {
                StatusIcon(status: top.effectiveStatus, size: 12)
            } else if top.effectiveStatus == .working {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(SessionRow.elapsed(from: top.promptDate, to: context.date))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.claude)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        } else if model.music.track != nil {
            Equalizer(playing: model.music.isPlaying)
        }
    }

    static func countdown(to start: Date, now: Date) -> String {
        let seconds = start.timeIntervalSince(now)
        if seconds <= 0 { return "agora" }
        return "\(Int((seconds / 60).rounded(.up)))m"
    }
}

struct FarewellContent: View {
    let model: NotchModel

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: model.notchHeight)
            HStack(spacing: 7) {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.claude)
                    .shadow(color: Color.claude.opacity(0.8), radius: 4)
                    .symbolEffect(.pulse, options: .repeating)
                Text("Até logo")
                    .fontWeight(.semibold)
                Text("desligando o Notchy")
                    .foregroundStyle(.white.opacity(0.55))
            }
            .font(.system(size: 12))
            .foregroundStyle(.white)
            .lineLimit(1)
            .frame(height: 32)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PeekIcon: View {
    let style: NotchModel.PeekStyle

    var body: some View {
        switch style {
        case .waiting:
            StatusIcon(status: .waiting, size: 11)
        case .done:
            StatusIcon(status: .done, size: 11)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
        case .info:
            Image(systemName: "sparkles")
                .font(.system(size: 11))
                .foregroundStyle(Color.claude)
        case .meeting:
            Image(systemName: "calendar")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.claude)
        case .app(let app):
            AppGlyph(app: app, trigger: "", size: 16)
        case .device(let symbol):
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(.white)
        }
    }
}
