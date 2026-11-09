import SwiftUI

/// Seven beveled bars and a decimal-point segment, with matching clock colons.
struct ScoreboardEightSegmentNumber: View {
    let value: String
    let fontSize: CGFloat
    let color: Color
    let minScale: CGFloat

    var body: some View {
        Canvas { context, size in
            let glyphs = Self.glyphs(for: value)
            let width = glyphs.reduce(CGFloat.zero) { $0 + $1.width } + CGFloat(max(0, glyphs.count - 1)) * 8
            guard width > 0, size.width > 0, size.height > 0 else { return }
            let scale = min(size.width / width, size.height / 100)
            var context = context
            context.translateBy(x: (size.width - width * scale) / 2, y: (size.height - 100 * scale) / 2)
            context.scaleBy(x: scale, y: scale)

            var lit = Path()
            var unlit = Path()
            var offset: CGFloat = 0
            for glyph in glyphs {
                let placement = CGAffineTransform(translationX: offset, y: 0)
                switch glyph.kind {
                case .digit:
                    for (index, segment) in Self.segments.enumerated() {
                        if glyph.mask & (UInt8(1) << index) != 0 {
                            lit.addPath(segment, transform: placement)
                        } else {
                            unlit.addPath(segment, transform: placement)
                        }
                    }
                case .colon:
                    lit.addEllipse(in: CGRect(x: offset + 5, y: 25, width: 10, height: 10))
                    lit.addEllipse(in: CGRect(x: offset + 5, y: 65, width: 10, height: 10))
                case .point:
                    lit.addEllipse(in: CGRect(x: offset + 1, y: 90, width: 10, height: 10))
                case .space:
                    break
                }
                offset += glyph.width + 8
            }
            context.fill(unlit, with: .color(color.opacity(0.06)))
            context.addFilter(.shadow(color: color.opacity(0.22), radius: 1.5))
            context.fill(lit, with: .color(color))
        }
        .frame(minHeight: fontSize * max(0.55, minScale), idealHeight: fontSize * 1.08, maxHeight: fontSize * 1.08)
        .accessibilityRepresentation { Text(value) }
    }

    static func supports(_ value: String) -> Bool {
        value.allSatisfy { masks[$0] != nil || $0 == ":" || $0 == "." || $0 == " " }
    }

    private struct Glyph {
        enum Kind { case digit, colon, point, space }
        let kind: Kind
        let mask: UInt8
        let width: CGFloat
    }

    private static func glyphs(for value: String) -> [Glyph] {
        let characters = Array(value)
        var result: [Glyph] = []
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if var mask = masks[character] {
                // A following decimal illuminates the digit's eighth segment
                // without inserting another digit cell or moving the clock.
                if index + 1 < characters.count, characters[index + 1] == "." {
                    mask |= 0x80
                    index += 1
                }
                result.append(Glyph(kind: .digit, mask: mask, width: 76))
            } else if character == ":" {
                result.append(Glyph(kind: .colon, mask: 0, width: 20))
            } else if character == "." {
                result.append(Glyph(kind: .point, mask: 0, width: 12))
            } else {
                result.append(Glyph(kind: .space, mask: 0, width: 32))
            }
            index += 1
        }
        return result
    }

    // Clockwise from the top: a, b, c, d, e, f, g, then the decimal point.
    private static let masks: [Character: UInt8] = [
        "0": 0x3F, "1": 0x06, "2": 0x5B, "3": 0x4F, "4": 0x66,
        "5": 0x6D, "6": 0x7D, "7": 0x07, "8": 0x7F, "9": 0x6F,
        "-": 0x40
    ]

    private static let segments: [Path] = [
        horizontalBar(y: 0), verticalBar(x: 50, y: 8), verticalBar(x: 50, y: 53),
        horizontalBar(y: 90), verticalBar(x: 0, y: 53), verticalBar(x: 0, y: 8),
        horizontalBar(y: 45), Path(ellipseIn: CGRect(x: 65, y: 90, width: 10, height: 10))
    ]

    private static func horizontalBar(y: CGFloat) -> Path {
        polygon([
            CGPoint(x: 10, y: y), CGPoint(x: 50, y: y), CGPoint(x: 55, y: y + 5),
            CGPoint(x: 50, y: y + 10), CGPoint(x: 10, y: y + 10), CGPoint(x: 5, y: y + 5)
        ])
    }

    private static func verticalBar(x: CGFloat, y: CGFloat) -> Path {
        polygon([
            CGPoint(x: x + 5, y: y), CGPoint(x: x + 10, y: y + 5), CGPoint(x: x + 10, y: y + 34),
            CGPoint(x: x + 5, y: y + 39), CGPoint(x: x, y: y + 34), CGPoint(x: x, y: y + 5)
        ])
    }

    private static func polygon(_ points: [CGPoint]) -> Path {
        Path { path in
            path.addLines(points)
            path.closeSubpath()
        }
    }
}
