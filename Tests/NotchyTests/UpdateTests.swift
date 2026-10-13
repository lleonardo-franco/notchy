import Foundation
import Testing
@testable import Notchy

struct UpdateTests {
    @Test(arguments: [
        ("1.3.0", "1.2.0", true),
        ("1.2.1", "1.2.0", true),
        ("2.0", "1.9.9", true),
        ("1.10.0", "1.9.0", true),
        ("1.2.0", "1.2.0", false),
        ("1.2", "1.2.0", false),
        ("1.1.9", "1.2.0", false),
        ("1.3.0-beta", "1.2.0", true)
    ])
    func comparesVersions(_ candidate: String, _ current: String, _ newer: Bool) {
        #expect(UpdateService.isNewer(candidate, than: current) == newer)
    }

    @Test func parsesTheLatestRelease() throws {
        let json = #"{"tag_name": "v1.3.0", "html_url": "https://github.com/lleonardo-franco/notchy/releases/tag/v1.3.0", "draft": false, "prerelease": false}"#
        let release = UpdateService.parse(Data(json.utf8))
        #expect(release?.version == "1.3.0")
        #expect(release?.page.absoluteString == "https://github.com/lleonardo-franco/notchy/releases/tag/v1.3.0")
    }

    @Test func ignoresPrereleases() {
        let json = #"{"tag_name": "v2.0.0", "prerelease": true}"#
        #expect(UpdateService.parse(Data(json.utf8)) == nil)
    }
}
