import AppKit
import SwiftUI

struct ShelfPanel: View {
    let model: NotchModel

    @State var shelfTargeted = false
    @State var airDropTargeted = false

    var body: some View {
        let shelf = model.shelf
        Group {
            if model.fileDrag {
                HStack(spacing: 10) {
                    DropZone(symbol: "tray.and.arrow.down.fill", title: "Guardar na bandeja", targeted: shelfTargeted)
                        .dropDestination(for: URL.self) { urls, _ in
                            shelf.add(urls)
                            model.endFileDrag()
                            return true
                        } isTargeted: { shelfTargeted = $0 }
                    DropZone(symbol: "dot.radiowaves.left.and.right", image: ShelfService.airDropIcon, title: "AirDrop", targeted: airDropTargeted)
                        .frame(width: 150)
                        .dropDestination(for: URL.self) { urls, _ in
                            model.endFileDrag()
                            return shelf.airDrop(urls)
                        } isTargeted: { airDropTargeted = $0 }
                }
                .transition(.opacity)
            } else if shelf.items.isEmpty {
                EmptyState(symbol: "tray", text: "Arraste arquivos para o notch para guardar aqui")
                    .dropDestination(for: URL.self) { urls, _ in
                        shelf.add(urls)
                        return true
                    }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(shelf.items) { item in
                            ShelfTile(item: item, shelf: shelf)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .padding(.horizontal, -6)
                .frame(maxHeight: .infinity)
                .dropDestination(for: URL.self) { urls, _ in
                    shelf.add(urls)
                    return true
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.fileDrag)
    }
}

struct DropZone: View {
    let symbol: String
    var image: NSImage? = nil
    let title: LocalizedStringKey
    let targeted: Bool

    var body: some View {
        VStack(spacing: 10) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .opacity(targeted ? 1 : 0.8)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .symbolEffect(.bounce, value: targeted)
            }
            Text(title)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(targeted ? 1 : 0.6))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(targeted ? 0.14 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(targeted ? 0.6 : 0.2), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        )
        .scaleEffect(targeted ? 1.02 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: targeted)
    }
}

struct ShelfTile: View {
    let item: ShelfItem
    let shelf: ShelfService

    @State var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 52, height: 52)
            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
                .frame(width: 76, height: 26, alignment: .top)
        }
        .padding(.vertical, 8)
        .frame(width: 84)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(hovering ? 0.08 : 0))
        )
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button {
                    shelf.remove(item)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .white.opacity(0.25))
                }
                .buttonStyle(.plain)
                .padding(4)
                .help("Remover")
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { shelf.open(item) }
        .draggable(item.url)
        .contextMenu {
            Button("Abrir") { shelf.open(item) }
            Button("Mostrar no Finder") { shelf.reveal([item]) }
            Button("Enviar por AirDrop") { shelf.airDrop([item.url]) }
            Divider()
            Button("Remover") { shelf.remove(item) }
        }
        .help(item.name)
    }
}
