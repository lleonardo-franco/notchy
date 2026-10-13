import AppKit
import SwiftUI
import WebKit

struct VideoSurface: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }

    func updateNSView(_ view: WKWebView, context: Context) {}
}

struct VideoContent: View {
    let model: NotchModel

    var body: some View {
        let player = model.video
        VStack(spacing: 0) {
            Color.clear.frame(height: model.notchHeight + 6)
            ZStack {
                Color.black
                VideoSurface(webView: player.webView)
                if let message = player.errorMessage {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.yellow)
                        Text(message)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                        PillButton(title: player.video?.source == nil ? "Abrir no YouTube" : "Voltar para o navegador", style: .primary) {
                            model.returnVideoToBrowser()
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                }
            }
            .frame(height: model.videoHeight)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Color.clear.frame(height: 8)
            controls
                .frame(height: 32)
            Color.clear.frame(height: 12)
        }
        .padding(.horizontal, 14)
    }

    private var controls: some View {
        let player = model.video
        return HStack(spacing: 2) {
            if let hud = model.hud {
                VolumeIndicator(level: hud.level, barWidth: 70, kind: hud.kind)
                    .transition(.opacity)
            } else {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .padding(.trailing, 4)
                Text(player.video?.title ?? "")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 6)
            RateButton(rate: player.rate) {
                player.cycleRate()
            }
            IconButton(symbol: "gobackward.10", size: 12, help: "Voltar 10 s") {
                player.seek(by: -10)
            }
            IconButton(symbol: player.isPlaying ? "pause.fill" : "play.fill", size: 13, help: "Tocar ou pausar") {
                player.togglePlay()
            }
            IconButton(symbol: "goforward.10", size: 12, help: "Avançar 10 s") {
                player.seek(by: 10)
            }
            IconButton(symbol: "arrow.uturn.backward", size: 11, help: player.video?.source == nil ? "Abrir no YouTube" : "Voltar para o navegador no mesmo ponto") {
                model.returnVideoToBrowser()
            }
            IconButton(symbol: player.large ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", size: 11, help: player.large ? "Diminuir" : "Aumentar") {
                player.large.toggle()
            }
            IconButton(symbol: "xmark", size: 11, help: "Fechar o vídeo") {
                model.closeVideo()
            }
        }
    }
}

struct RateButton: View {
    let rate: Double
    let action: () -> Void

    @State var hovering = false

    var body: some View {
        Button(action: action) {
            Text(VideoPlayer.rateLabel(rate))
                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(rate == 1 ? Color.white.opacity(hovering ? 1 : 0.8) : Color.claude)
                .contentTransition(.numericText())
                .frame(minWidth: 34, minHeight: 26)
                .background(Capsule().fill(.white.opacity(hovering ? 0.12 : 0)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.snappy, value: rate)
        .help("Velocidade")
    }
}

struct YouTubeCard: View {
    let video: BrowserVideo
    let javascriptBlocked: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: "https://i.ytimg.com/vi/\(video.videoID)/mqdefault.jpg")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.white.opacity(0.08)
            }
            .frame(width: 96, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                AppIcon(bundleIDs: [video.browserBundleID], size: 22, fallback: "safari")
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                    .offset(x: 6, y: 6)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(video.cleanTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    video.playing == true ? Text("Tocando no \(video.browserName)") : Text("Aberto no \(video.browserName)")
                    if javascriptBlocked {
                        Image(systemName: "info.circle")
                            .help(video.javascriptHint)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
            }

            Spacer(minLength: 6)

            PillButton(title: "Assistir no notch", style: .primary, action: action)
        }
    }
}

struct BatteryGlyph: View {
    let level: Int

    private var symbol: String {
        switch level {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Text("\(level)%")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
            Image(systemName: symbol)
                .font(.system(size: 13))
        }
        .foregroundStyle(level <= 20 ? Color.red : .white.opacity(0.75))
    }
}

struct BluetoothPanel: View {
    let bluetooth: BluetoothService

    var body: some View {
        if bluetooth.devices.isEmpty {
            EmptyState(symbol: "headphones", text: "Nenhum dispositivo Bluetooth conectado")
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(bluetooth.devices) { device in
                        DeviceRow(device: device)
                            .frame(height: NotchModel.rowHeight)
                    }
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: BluetoothDevice

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: device.symbol)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(device.batteryText)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let level = device.lowest {
                BatteryGlyph(level: level)
            }
        }
    }
}
