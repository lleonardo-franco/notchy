import Foundation
import Testing
@testable import Notchy

@MainActor
struct MediaTests {
    @Test(arguments: [
        ("https://www.youtube.com/watch?v=dQw4w9WgXcQ", "dQw4w9WgXcQ"),
        ("https://youtu.be/dQw4w9WgXcQ?t=42", "dQw4w9WgXcQ"),
        ("https://www.youtube.com/shorts/abcdEFGH123", "abcdEFGH123"),
        ("https://www.youtube.com/live/abcdEFGH123", "abcdEFGH123")
    ])
    func extractsVideoID(_ url: String, _ id: String) {
        #expect(YouTubeLink.videoID(url) == id)
    }

    @Test func rejectsNonYouTubeLinks() {
        #expect(YouTubeLink.videoID("https://vimeo.com/123456") == nil)
        #expect(YouTubeLink.videoID("https://www.youtube.com/watch?v=<script>") == nil)
    }

    @Test func parsesStartTime() {
        #expect(YouTubeLink.start("https://youtu.be/dQw4w9WgXcQ?t=42") == 42)
        #expect(YouTubeLink.start("https://youtu.be/dQw4w9WgXcQ?t=1m30s") == 90)
        #expect(YouTubeLink.start("https://youtu.be/dQw4w9WgXcQ?t=1h2m3s") == 3723)
        #expect(YouTubeLink.start("https://youtu.be/dQw4w9WgXcQ") == nil)
    }

    @Test func parsesBrowserState() {
        let playing = BrowserMediaService.parseState("1|12.5|1.5")
        #expect(playing.playing == true)
        #expect(playing.time == 12.5)
        #expect(playing.rate == 1.5)
        #expect(playing.blocked == false)

        let older = BrowserMediaService.parseState("0|3")
        #expect(older.playing == false)
        #expect(older.rate == nil)

        #expect(BrowserMediaService.parseState("nojs").blocked)
        #expect(BrowserMediaService.parseState("").time == nil)
    }

    @Test func playbackRates() {
        #expect(VideoPlayer.closestRate(to: 1.3) == 1.25)
        #expect(VideoPlayer.closestRate(to: 3) == 2)
        #expect(VideoPlayer.rateLabel(1) == "1×")
        #expect(VideoPlayer.rateLabel(1.25) == "1.25×")
        #expect(VideoPlayer.rateLabel(2) == "2×")
    }

    @Test func nowPlayingPosition() {
        let start = Date(timeIntervalSince1970: 1_000)
        let info = NowPlayingInfo(pid: 1, bundleID: nil, title: "Song", artist: "", album: "", duration: 200, elapsed: 30, timestamp: start, rate: 1, playing: true, artwork: nil)
        #expect(info.position(at: start.addingTimeInterval(10)) == 40)
        #expect(info.position(at: start.addingTimeInterval(500)) == 200)

        var paused = info
        paused.playing = false
        #expect(paused.position(at: start.addingTimeInterval(10)) == 30)
    }

    @Test func nowPlayingNeedsTitle() {
        #expect(NowPlayingInfo.from([:], pid: 1, playing: true) == nil)
        let info = NowPlayingInfo.from(["kMRMediaRemoteNowPlayingInfoTitle": "Song", "kMRMediaRemoteNowPlayingInfoDuration": 180], pid: 7, playing: true)
        #expect(info?.title == "Song")
        #expect(info?.duration == 180)
        #expect(info?.pid == 7)
    }

    @Test func formatsPlaybackTime() {
        #expect(PlaybackProgress.format(0) == "0:00")
        #expect(PlaybackProgress.format(75.9) == "1:15")
        #expect(PlaybackProgress.format(3600) == "60:00")
    }
}
