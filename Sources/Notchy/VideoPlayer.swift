import AppKit
import Observation
import WebKit

final class ScriptBridge: NSObject, WKScriptMessageHandler {
    var onMessage: ((Any) -> Void)?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        onMessage?(message.body)
    }
}

@MainActor
@Observable
final class VideoPlayer {
    struct Video: Equatable {
        let id: String
        let title: String
        let source: BrowserVideo?
    }

    static let origin = URL(string: "https://io.github.lleonardo-franco.notchy")!
    nonisolated static let rates: [Double] = [1, 1.25, 1.5, 2]

    private(set) var video: Video?
    private(set) var isPlaying = false
    private(set) var errorMessage: String?
    private(set) var rate: Double = 1

    var large: Bool {
        didSet { UserDefaults.standard.set(large, forKey: "videoLarge") }
    }

    @ObservationIgnored let webView: WKWebView
    @ObservationIgnored private let bridge: ScriptBridge

    init() {
        large = UserDefaults.standard.bool(forKey: "videoLarge")
        let bridge = ScriptBridge()
        self.bridge = bridge
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(bridge, name: "notchy")
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        bridge.onMessage = { [weak self] body in
            MainActor.assumeIsolated { self?.handle(body) }
        }
    }

    func play(id: String, start: Double, title: String, source: BrowserVideo?, rate: Double = 1) {
        guard let safe = YouTubeLink.valid(id) else { return }
        errorMessage = nil
        isPlaying = false
        self.rate = Self.closestRate(to: rate)
        video = Video(id: safe, title: title, source: source)
        webView.loadHTMLString(Self.page(id: safe, start: Int(max(start, 0)), rate: self.rate), baseURL: Self.origin)
    }

    func cycleRate() {
        let index = Self.rates.firstIndex(of: rate) ?? 0
        setRate(Self.rates[(index + 1) % Self.rates.count])
    }

    func setRate(_ value: Double) {
        rate = value
        webView.evaluateJavaScript("setRate(\(value))")
    }

    nonisolated static func closestRate(to value: Double) -> Double {
        rates.min { abs($0 - value) < abs($1 - value) } ?? 1
    }

    nonisolated static func rateLabel(_ value: Double) -> String {
        let text = value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
        return text + "×"
    }

    func togglePlay() {
        webView.evaluateJavaScript("toggle()")
    }

    func seek(by seconds: Double) {
        webView.evaluateJavaScript("seekBy(\(seconds))")
    }

    func currentTime() async -> Double {
        let value = try? await webView.evaluateJavaScript("time()")
        return (value as? NSNumber)?.doubleValue ?? 0
    }

    func stop() {
        webView.loadHTMLString("<html><body style='background:#000'></body></html>", baseURL: nil)
        video = nil
        isPlaying = false
        errorMessage = nil
    }

    func openOnYouTube() {
        guard let video, let url = URL(string: "https://www.youtube.com/watch?v=\(video.id)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func handle(_ body: Any) {
        guard let message = body as? [String: Any] else { return }
        if let state = message["state"] as? Int {
            isPlaying = state == 1
        }
        if let value = message["rate"] as? Double, value != rate {
            rate = value
        }
        if let code = message["error"] as? Int {
            isPlaying = false
            switch code {
            case 100: errorMessage = String(localized: "Vídeo não encontrado ou privado")
            case 101, 150: errorMessage = String(localized: "O dono do vídeo não deixa assistir fora do YouTube")
            case 152, 153: errorMessage = String(localized: "O YouTube recusou o player incorporado")
            default: errorMessage = String(localized: "Não deu para tocar este vídeo")
            }
        }
    }

    private static func page(id: String, start: Int, rate: Double) -> String {
        let origin = Self.origin.absoluteString
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="referrer" content="strict-origin-when-cross-origin">
        <style>
        html, body { margin: 0; height: 100%; background: #000; overflow: hidden; }
        #player { position: absolute; inset: 0; width: 100%; height: 100%; }
        </style>
        </head>
        <body>
        <div id="player"></div>
        <script>
        var player;
        var wanted = \(rate);
        function post(message) {
          try { window.webkit.messageHandlers.notchy.postMessage(message); } catch (e) {}
        }
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            videoId: '\(id)',
            playerVars: { autoplay: 1, start: \(start), playsinline: 1, rel: 0, modestbranding: 1, enablejsapi: 1, origin: '\(origin)', widget_referrer: '\(origin)' },
            events: {
              onReady: function (event) { event.target.setPlaybackRate(wanted); event.target.playVideo(); },
              onStateChange: function (event) { post({ state: event.data }); },
              onPlaybackRateChange: function (event) { post({ rate: event.data }); },
              onError: function (event) { post({ error: event.data }); }
            }
          });
        }
        function toggle() {
          if (!player || !player.getPlayerState) return;
          if (player.getPlayerState() === 1) { player.pauseVideo(); } else { player.playVideo(); }
        }
        function seekBy(seconds) {
          if (!player || !player.getCurrentTime) return;
          player.seekTo(Math.max(0, player.getCurrentTime() + seconds), true);
        }
        function setRate(rate) {
          wanted = rate;
          if (player && player.setPlaybackRate) { player.setPlaybackRate(rate); }
        }
        function time() {
          return player && player.getCurrentTime ? player.getCurrentTime() : 0;
        }
        </script>
        <script src="https://www.youtube.com/iframe_api"></script>
        </body>
        </html>
        """
    }
}
