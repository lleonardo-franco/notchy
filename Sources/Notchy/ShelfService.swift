import AppKit
import Observation

struct ShelfItem: Identifiable, Equatable {
    let url: URL

    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

@MainActor
@Observable
final class ShelfService {
    static let storageKey = "shelfItems"
    static let limit = 40
    static let airDropIcon: NSImage? = {
        let path = "/System/Library/CoreServices/Finder.app/Contents/Applications/AirDrop.app"
        return FileManager.default.fileExists(atPath: path) ? NSWorkspace.shared.icon(forFile: path) : nil
    }()

    private(set) var items: [ShelfItem] = []

    init() {
        let stored = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []
        items = stored.map { ShelfItem(url: URL(fileURLWithPath: $0)) }.filter(Self.exists)
    }

    func add(_ urls: [URL]) {
        let incoming = urls.filter(\.isFileURL).map { ShelfItem(url: $0.standardizedFileURL) }.filter(Self.exists)
        guard !incoming.isEmpty else { return }
        let fresh = incoming.filter { !items.contains($0) }
        items = Array((fresh + items.filter { !incoming.contains($0) }).prefix(Self.limit))
        save()
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0 == item }
        save()
    }

    func clear() {
        items = []
        save()
    }

    func prune() {
        let existing = items.filter(Self.exists)
        if existing != items {
            items = existing
            save()
        }
    }

    func open(_ item: ShelfItem) {
        NSWorkspace.shared.open(item.url)
    }

    func reveal(_ items: [ShelfItem]) {
        NSWorkspace.shared.activateFileViewerSelecting(items.map(\.url))
    }

    @discardableResult
    func airDrop(_ urls: [URL]) -> Bool {
        let files = urls.filter(\.isFileURL)
        guard !files.isEmpty,
              let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: files) else { return false }
        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: files)
        return true
    }

    private func save() {
        UserDefaults.standard.set(items.map(\.url.path), forKey: Self.storageKey)
    }

    nonisolated static func exists(_ item: ShelfItem) -> Bool {
        FileManager.default.fileExists(atPath: item.url.path)
    }
}
