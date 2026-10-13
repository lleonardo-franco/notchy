import AppKit
import SwiftUI

final class TrackpadCatcher: NSView {
    var onScroll: ((NSEvent) -> Void)?
    var onClick: ((CGPoint) -> Void)?
    var onMove: ((CGPoint?) -> Void)?

    private var tracking: NSTrackingArea?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        tracking = area
    }

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?(convert(event.locationInWindow, from: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        onMove?(convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        onMove?(nil)
    }
}

struct TrackpadCatcherView: NSViewRepresentable {
    let onScroll: (NSEvent) -> Void
    let onClick: (CGPoint) -> Void
    let onMove: (CGPoint?) -> Void

    func makeNSView(context: Context) -> TrackpadCatcher {
        let view = TrackpadCatcher()
        update(view)
        return view
    }

    func updateNSView(_ view: TrackpadCatcher, context: Context) {
        update(view)
    }

    private func update(_ view: TrackpadCatcher) {
        view.onScroll = onScroll
        view.onClick = onClick
        view.onMove = onMove
    }
}

struct PadShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.width * 0.035
        let top: CGFloat = 14
        let bottom = rect.height * 0.32
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + top), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - bottom))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - inset - bottom, y: rect.maxY),
            control: CGPoint(x: rect.maxX - inset, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + inset + bottom, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.maxY + 10)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + inset, y: rect.maxY - bottom),
            control: CGPoint(x: rect.minX + inset, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + top))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct HapticTestPad: View {
    let prefs: Preferences

    struct Ripple: Identifiable {
        let id = UUID()
        let point: CGPoint
    }

    struct Swipe: Equatable {
        let id = UUID()
        let right: Bool
        let label: String
    }

    @State var ripples: [Ripple] = []
    @State var pointer: CGPoint? = nil
    @State var swipe: Swipe? = nil
    @State var volume: Double = 0.5
    @State var showVolume = false
    @State var volumeToken = UUID()
    @State var note: String? = nil
    @State var tracker = SwipeTracker()

    private let lightBar = LinearGradient(
        colors: [Color.claude, Color.clickupPink, Color.clickup],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                ZStack {
                    PadShape()
                        .fill(LinearGradient(
                            colors: [Color(white: 0.2), Color(white: 0.09)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                    PadShape()
                        .stroke(.white.opacity(0.12), lineWidth: 1)

                    Capsule()
                        .fill(lightBar)
                        .frame(width: proxy.size.width * 0.5, height: 3)
                        .shadow(color: Color.clickupPink.opacity(0.8), radius: 6)
                        .position(x: proxy.size.width / 2, y: 7)

                    if let pointer {
                        Circle()
                            .fill(RadialGradient(colors: [.white.opacity(0.18), .clear], center: .center, startRadius: 0, endRadius: 40))
                            .frame(width: 80, height: 80)
                            .position(pointer)
                            .allowsHitTesting(false)
                    }

                    ForEach(ripples) { ripple in
                        RippleView()
                            .position(ripple.point)
                    }

                    centerContent
                        .allowsHitTesting(false)

                    if showVolume {
                        volumeBar
                            .position(x: proxy.size.width - 34, y: proxy.size.height / 2)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }

                    TrackpadCatcherView(
                        onScroll: handleScroll,
                        onClick: handleClick,
                        onMove: { pointer = $0 }
                    )
                }
                .clipShape(PadShape())
            }
            .frame(height: 150)
            .environment(\.colorScheme, .dark)

            Text("Vibração atual: \(prefs.hapticLevel.title). Clique, deslize com dois dedos para os lados ou para cima e para baixo.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var centerContent: some View {
        if let swipe {
            HStack(spacing: 8) {
                if !swipe.right {
                    Image(systemName: "chevron.left.2")
                }
                Text(swipe.label)
                if swipe.right {
                    Image(systemName: "chevron.right.2")
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .id(swipe.id)
            .transition(.asymmetric(
                insertion: .move(edge: swipe.right ? .leading : .trailing).combined(with: .opacity),
                removal: .move(edge: swipe.right ? .trailing : .leading).combined(with: .opacity)
            ))
        } else if let note {
            Text(note)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .transition(.opacity)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "hand.point.up.left")
                    .font(.system(size: 18))
                Text("Toque aqui para testar")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.35))
        }
    }

    private var volumeBar: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                Capsule().fill(.white.opacity(0.15))
                Capsule()
                    .fill(.white)
                    .frame(height: 90 * volume)
            }
            .frame(width: 6, height: 90)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: volume)
            Text("\(Int((volume * 100).rounded()))")
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.75))
                .contentTransition(.numericText())
        }
    }

    private func handleClick(_ point: CGPoint) {
        Haptics.shared.perform(.normal)
        let ripple = Ripple(point: point)
        ripples.append(ripple)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            ripples.removeAll { $0.id == ripple.id }
        }
    }

    private func handleScroll(_ event: NSEvent) {
        guard let output = tracker.feed(event, continuousVertical: prefs.verticalGesture == .volume) else { return }
        switch output {
        case .horizontal(let right):
            guard prefs.swipeTracks else {
                flashNote(String(localized: "Troca de música está desligada"))
                return
            }
            Haptics.shared.perform(.normal)
            let next = right == prefs.swipeRightNext
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                swipe = Swipe(right: right, label: next ? String(localized: "Próxima música") : String(localized: "Música anterior"))
                note = nil
            }
            let current = swipe
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                if swipe == current {
                    withAnimation(.easeOut(duration: 0.25)) {
                        swipe = nil
                    }
                }
            }
        case .volume(let steps):
            let notch = (volume * SystemVolume.steps).rounded()
            let next = min(max(notch + Double(steps), 0), SystemVolume.steps) / SystemVolume.steps
            if next != volume, next == 0 || next == 1 {
                Haptics.shared.perform(.subtle)
            }
            volume = next
            withAnimation(.easeOut(duration: 0.15)) {
                showVolume = true
            }
            let token = UUID()
            volumeToken = token
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if volumeToken == token {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showVolume = false
                    }
                }
            }
        case .vertical(let down):
            switch prefs.verticalGesture {
            case .openClose:
                flashNote(down ? String(localized: "Abriria o notch") : String(localized: "Fecharia o notch"))
            case .off, .volume:
                flashNote(String(localized: "Gesto vertical desligado"))
            }
        }
    }

    private func flashNote(_ text: String) {
        withAnimation(.easeOut(duration: 0.15)) {
            swipe = nil
            note = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if note == text {
                withAnimation(.easeOut(duration: 0.25)) {
                    note = nil
                }
            }
        }
    }
}

struct RippleView: View {
    @State var expanded = false

    var body: some View {
        Circle()
            .stroke(.white.opacity(expanded ? 0 : 0.7), lineWidth: 2)
            .frame(width: 26, height: 26)
            .scaleEffect(expanded ? 3.2 : 0.4)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    expanded = true
                }
            }
    }
}
