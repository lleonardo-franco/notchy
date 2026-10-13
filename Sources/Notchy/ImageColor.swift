import AppKit

extension NSImage {
    func dominantColor() -> NSColor? {
        let side = 24
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: side,
            pixelsHigh: side,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(in: NSRect(x: 0, y: 0, width: side, height: side), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        var bins = Array(repeating: (weight: CGFloat(0), r: CGFloat(0), g: CGFloat(0), b: CGFloat(0)), count: 12)
        var total = (r: CGFloat(0), g: CGFloat(0), b: CGFloat(0), count: CGFloat(0))

        for x in 0..<side {
            for y in 0..<side {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                total.r += color.redComponent
                total.g += color.greenComponent
                total.b += color.blueComponent
                total.count += 1
                let weight = color.saturationComponent * color.brightnessComponent
                guard weight > 0.08 else { continue }
                let index = min(Int(color.hueComponent * 12), 11)
                bins[index].weight += weight
                bins[index].r += color.redComponent * weight
                bins[index].g += color.greenComponent * weight
                bins[index].b += color.blueComponent * weight
            }
        }

        let base: NSColor
        if let best = bins.max(by: { $0.weight < $1.weight }), best.weight > 4 {
            base = NSColor(deviceRed: best.r / best.weight, green: best.g / best.weight, blue: best.b / best.weight, alpha: 1)
        } else if total.count > 0 {
            base = NSColor(deviceRed: total.r / total.count, green: total.g / total.count, blue: total.b / total.count, alpha: 1)
        } else {
            return nil
        }

        return NSColor(
            deviceHue: base.hueComponent,
            saturation: min(base.saturationComponent * 1.1, 0.75),
            brightness: 0.42,
            alpha: 1
        )
    }
}
