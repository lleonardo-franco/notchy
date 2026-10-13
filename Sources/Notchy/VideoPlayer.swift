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

    private(set) var video: Video?
    private(set) var isPlaying = false
    private(set) var errorMessage: String?

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

    func play(id: String, start: Double, title: String, source: BrowserVideo?) {
        guard let safe = YouTubeLink.valid(id) else { return }
        errorMessage = nil
        isPlaying = false
        video = Video(id: safe, title: title, source: source)
        webView.loadHTMLString(Self.page(id: safe, start: Int(max(start, 0))), baseURL: Self.origin)
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
        if let code = message["error"] as? Int {
            isPlaying = false
            switch code {
            case 100: errorMessage = "Vídeo não encontrado ou privado"
            case 101, 150: errorMessage = "O dono do vídeo não deixa assistir fora do YouTube"
            case 152, 153: errorMessage = "O YouTube recusou o player incorporado"
            default: errorMessage = "Não deu para tocar este vídeo"
            }
        }
    }

    private static func page(id: String, start: Int) -> String {
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
        function post(message) {
          try { window.webkit.messageHandlers.notchy.postMessage(message); } catch (e) {}
        }
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            videoId: '\(id)',
            playerVars: { autoplay: 1, start: \(start), playsinline: 1, rel: 0, modestbranding: 1, enablejsapi: 1, origin: '\(origin)', widget_referrer: '\(origin)' },
            events: {
              onReady: function (event) { event.target.playVideo(); },
              onStateChange: function (event) { post({ state: event.data }); },
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
