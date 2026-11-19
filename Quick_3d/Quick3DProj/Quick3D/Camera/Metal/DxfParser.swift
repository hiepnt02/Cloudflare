//
//  DxfParser.swift
//  Quick3D
//

import Foundation

/// One straight piece of a DXF drawing in drawing coordinates (x = easting, y = northing),
/// with the RGB color of its entity.
struct DxfEdge {
    var x1: Double
    var y1: Double
    var x2: Double
    var y2: Double
    var color: UInt32
}

/// Reads the 2D outline of an ASCII DXF for the AR overlay (SC_QUICK-1986).
///
/// Mirrors the web viewer's loader (client/src/ts/viewer/dxf/dxf-loader.ts, built on
/// dxf-parser) so AR and web paint the same drawing: LINE, LWPOLYLINE, POLYLINE, ARC,
/// CIRCLE, ELLIPSE and SPLINE in the ENTITIES section, with the entity's own color, else
/// its layer's color, else light gray. Blocks, text and hatches are skipped on the web
/// too. Binary DXF is not supported.
enum DxfParser {

    static let defaultColor: UInt32 = 0xCCCCCC

    static func parseEdges(_ data: Data) -> [DxfEdge] {
        var bytes = [UInt8](data)
        // strtod stops at the line break after a value; the extra line break and NUL keep
        // it inside the buffer for a last value that has no line break of its own.
        bytes.append(0x0A)
        bytes.append(0)
        return bytes.withUnsafeBufferPointer { buffer in
            var reader = DxfReaderState(buffer: buffer)
            return reader.read()
        }
    }

    /// AutoCAD Color Index → RGB, same table as dxf-parser.
    static func aciColor(_ index: Int) -> UInt32 {
        return (0..<aciTable.count).contains(index) ? aciTable[index] : 0
    }

    static let aciTable: [UInt32] = [
        0x000000, 0xFF0000, 0xFFFF00, 0x00FF00, 0x00FFFF, 0x0000FF, 0xFF00FF, 0xFFFFFF,
        0x808080, 0xC0C0C0, 0xFF0000, 0xFF7F7F, 0xCC0000, 0xCC6666, 0x990000, 0x994C4C,
        0x7F0000, 0x7F3F3F, 0x4C0000, 0x4C2626, 0xFF3F00, 0xFF9F7F, 0xCC3300, 0xCC7F66,
        0x992600, 0x995F4C, 0x7F1F00, 0x7F4F3F, 0x4C1300, 0x4C2F26, 0xFF7F00, 0xFFBF7F,
        0xCC6600, 0xCC9966, 0x994C00, 0x99724C, 0x7F3F00, 0x7F5F3F, 0x4C2600, 0x4C3926,
        0xFFBF00, 0xFFDF7F, 0xCC9900, 0xCCB266, 0x997200, 0x99854C, 0x7F5F00, 0x7F6F3F,
        0x4C3900, 0x4C4226, 0xFFFF00, 0xFFFF7F, 0xCCCC00, 0xCCCC66, 0x989800, 0x98984C,
        0x7F7F00, 0x7F7F3F, 0x4C4C00, 0x4C4C26, 0xBFFF00, 0xDFFF7F, 0x99CC00, 0xB2CC66,
        0x729800, 0x85984C, 0x5F7F00, 0x6F7F3F, 0x394C00, 0x424C26, 0x7FFF00, 0xBFFF7F,
        0x66CC00, 0x99CC66, 0x4C9800, 0x72984C, 0x3F7F00, 0x5F7F3F, 0x264C00, 0x394C26,
        0x3FFF00, 0x9FFF7F, 0x33CC00, 0x7FCC66, 0x269800, 0x5F984C, 0x1F7F00, 0x4F7F3F,
        0x134C00, 0x2F4C26, 0x00FF00, 0x7FFF7F, 0x00CC00, 0x66CC66, 0x009800, 0x4C984C,
        0x007F00, 0x3F7F3F, 0x004C00, 0x264C26, 0x00FF3F, 0x7FFF9F, 0x00CC33, 0x66CC7F,
        0x009826, 0x4C985F, 0x007F1F, 0x3F7F4F, 0x004C13, 0x264C2F, 0x00FF7F, 0x7FFFBF,
        0x00CC66, 0x66CC99, 0x00984C, 0x4C9872, 0x007F3F, 0x3F7F5F, 0x004C26, 0x264C39,
        0x00FFBF, 0x7FFFDF, 0x00CC99, 0x66CCB2, 0x009872, 0x4C9885, 0x007F5F, 0x3F7F6F,
        0x004C39, 0x264C42, 0x00FFFF, 0x7FFFFF, 0x00CCCC, 0x66CCCC, 0x009898, 0x4C9898,
        0x007F7F, 0x3F7F7F, 0x004C4C, 0x264C4C, 0x00BFFF, 0x7FDFFF, 0x0099CC, 0x66B2CC,
        0x007298, 0x4C8598, 0x005F7F, 0x3F6F7F, 0x00394C, 0x26424C, 0x007FFF, 0x7FBFFF,
        0x0066CC, 0x6699CC, 0x004C98, 0x4C7298, 0x003F7F, 0x3F5F7F, 0x00264C, 0x26394C,
        0x003FFF, 0x7F9FFF, 0x0033CC, 0x667FCC, 0x002698, 0x4C5F98, 0x001F7F, 0x3F4F7F,
        0x00134C, 0x262F4C, 0x0000FF, 0x7F7FFF, 0x0000CC, 0x6666CC, 0x000098, 0x4C4C98,
        0x00007F, 0x3F3F7F, 0x00004C, 0x26264C, 0x3F00FF, 0x9F7FFF, 0x3300CC, 0x7F66CC,
        0x260098, 0x5F4C98, 0x1F007F, 0x4F3F7F, 0x13004C, 0x2F264C, 0x7F00FF, 0xBF7FFF,
        0x6600CC, 0x9966CC, 0x4C0098, 0x724C98, 0x3F007F, 0x5F3F7F, 0x26004C, 0x39264C,
        0xBF00FF, 0xDF7FFF, 0x9900CC, 0xB266CC, 0x720098, 0x854C98, 0x5F007F, 0x6F3F7F,
        0x39004C, 0x42264C, 0xFF00FF, 0xFF7FFF, 0xCC00CC, 0xCC66CC, 0x980098, 0x984C98,
        0x7F007F, 0x7F3F7F, 0x4C004C, 0x4C264C, 0xFF00BF, 0xFF7FDF, 0xCC0099, 0xCC66B2,
        0x980072, 0x984C85, 0x7F005F, 0x7F3F6F, 0x4C0039, 0x4C2642, 0xFF007F, 0xFF7FBF,
        0xCC0066, 0xCC6699, 0x98004C, 0x984C72, 0x7F003F, 0x7F3F5F, 0x4C0026, 0x4C2639,
        0xFF003F, 0xFF7F9F, 0xCC0033, 0xCC667F, 0x980026, 0x984C5F, 0x7F001F, 0x7F3F4F,
        0x4C0013, 0x4C262F, 0x333333, 0x5B5B5B, 0x848484, 0xADADAD, 0xD6D6D6, 0xFFFFFF,
    ]

    /// B-spline sampled with de Boor's algorithm, as the web's bspline.ts.
    static func tessellateSpline(degree: Int, controlPoints: [SIMD2<Double>], knots: [Double], samples: Int = 200) -> [SIMD2<Double>] {
        guard controlPoints.count >= 2, knots.count >= 2,
              degree >= 0, degree < knots.count, knots.count - degree - 1 >= 0 else { return controlPoints }
        let tMin = knots[degree]
        let tMax = knots[knots.count - degree - 1]
        guard tMin < tMax else { return controlPoints }
        return (0...samples).map { i in
            deBoor(degree: degree, controlPoints: controlPoints, knots: knots,
                   t: tMin + Double(i) / Double(samples) * (tMax - tMin))
        }
    }

    private static func deBoor(degree: Int, controlPoints: [SIMD2<Double>], knots: [Double], t: Double) -> SIMD2<Double> {
        // Out-of-range knots read as undefined on the web; keep the same fallbacks.
        func knot(_ i: Int) -> Double? { (0..<knots.count).contains(i) ? knots[i] : nil }

        let n = controlPoints.count - 1
        var k = degree
        if degree <= n {
            for i in degree...n {
                if let a = knot(i), let b = knot(i + 1), t >= a, t < b {
                    k = i
                    break
                }
            }
        }
        if let last = knot(n + 1), t >= last {
            k = n
        }

        var d = (0...degree).map { j in controlPoints[Swift.max(0, Swift.min(n, k - degree + j))] }
        if degree >= 1 {
            for r in 1...degree {
                for j in stride(from: degree, through: r, by: -1) {
                    let i = k - degree + j
                    let ki = knot(i) ?? 0
                    let kipr = knot(i + degree - r + 1) ?? 1
                    let denom = kipr - ki
                    let alpha = denom == 0 ? 0 : (t - ki) / denom
                    d[j] = (1 - alpha) * d[j - 1] + alpha * d[j]
                }
            }
        }
        return d[degree]
    }
}

/// Group code and the byte range of its value, as read from two lines of the file.
private struct DxfPair {
    let code: Int
    let start: Int
    let end: Int
}

private struct DxfEntity {
    let type: String
    var pairs: [DxfPair] = []
}

/// A POLYLINE collects the VERTEX entities that follow it, up to SEQEND.
private struct DxfOpenPolyline {
    var points: [SIMD2<Double>] = []
    let isClosed: Bool
    let color: UInt32
}

private struct DxfReaderState {
    let buffer: UnsafeBufferPointer<UInt8>
    var position = 0
    var layerColors: [String: UInt32] = [:]
    var edges: [DxfEdge] = []

    init(buffer: UnsafeBufferPointer<UInt8>) {
        self.buffer = buffer
    }

    mutating func read() -> [DxfEdge] {
        var section = ""
        var entity: DxfEntity?
        var polyline: DxfOpenPolyline?
        var layerName: String?
        var layerColor: UInt32?

        while let pair = nextPair() {
            guard pair.code == 0 else {
                if section == "ENTITIES" {
                    entity?.pairs.append(pair)
                } else if section == "TABLES", layerName != nil {
                    if pair.code == 2 {
                        layerName = string(pair)
                    } else if pair.code == 62 {
                        layerColor = DxfParser.aciColor(abs(Int(number(pair))))
                    }
                }
                continue
            }

            if let finished = entity {
                finish(finished, polyline: &polyline)
                entity = nil
            }
            if let name = layerName {
                if let color = layerColor { layerColors[name] = color }
                layerName = nil
                layerColor = nil
            }

            switch string(pair) {
            case "SECTION":
                section = nextPair().map { string($0) } ?? ""
            case "ENDSEC":
                if let open = polyline { addPolyline(open) }
                polyline = nil
                section = ""
            case "EOF":
                return edges
            case let type where section == "ENTITIES":
                entity = DxfEntity(type: type)
            case "LAYER" where section == "TABLES":
                layerName = ""
            default:
                break
            }
        }
        return edges
    }

    // MARK: Entities

    private mutating func finish(_ entity: DxfEntity, polyline: inout DxfOpenPolyline?) {
        switch entity.type {
        case "VERTEX":
            polyline?.points.append(point(entity, x: 10, y: 20))
            return
        case "SEQEND":
            if let open = polyline { addPolyline(open) }
            polyline = nil
            return
        default:
            if let open = polyline { addPolyline(open) }
            polyline = nil
        }

        let color = resolveColor(entity)
        switch entity.type {
        case "LINE":
            addEdge(point(entity, x: 10, y: 20), point(entity, x: 11, y: 21), color)

        case "LWPOLYLINE":
            var points: [SIMD2<Double>] = []
            for pair in entity.pairs {
                if pair.code == 10 {
                    points.append([number(pair), 0])
                } else if pair.code == 20, !points.isEmpty {
                    points[points.count - 1].y = number(pair)
                }
            }
            let flags = Int(value(entity, 70) ?? 0)
            addPolyline(DxfOpenPolyline(points: points, isClosed: flags & 1 != 0, color: color))

        case "POLYLINE":
            let flags = Int(value(entity, 70) ?? 0)
            polyline = DxfOpenPolyline(isClosed: flags & 1 != 0, color: color)

        case "ARC":
            guard let radius = value(entity, 40) else { return }
            let start = (value(entity, 50) ?? 0) * .pi / 180
            let end = value(entity, 51).map { $0 * .pi / 180 } ?? 2 * .pi
            addArc(center: point(entity, x: 10, y: 20), radius: radius, from: start, to: end, color: color)

        case "CIRCLE":
            guard let radius = value(entity, 40) else { return }
            addArc(center: point(entity, x: 10, y: 20), radius: radius, from: 0, to: 2 * .pi, color: color)

        case "ELLIPSE":
            addEllipse(entity, color: color)

        case "SPLINE":
            var controlPoints: [SIMD2<Double>] = []
            var knots: [Double] = []
            for pair in entity.pairs {
                switch pair.code {
                case 10: controlPoints.append([number(pair), 0])
                case 20: if !controlPoints.isEmpty { controlPoints[controlPoints.count - 1].y = number(pair) }
                case 40: knots.append(number(pair))
                default: break
                }
            }
            let degree = Int(value(entity, 71) ?? 3)
            guard controlPoints.count >= 2, knots.count >= 2 else { return }
            let curve = DxfParser.tessellateSpline(degree: degree, controlPoints: controlPoints, knots: knots)
            addPolyline(DxfOpenPolyline(points: curve, isClosed: false, color: color))

        default:
            break
        }
    }

    /// Same rule as the web's resolveEntityColor: an own color (index 1...255, or the true
    /// color that dxf-parser puts in its place) wins, else the layer's, else light gray.
    private func resolveColor(_ entity: DxfEntity) -> UInt32 {
        var index: Int?
        var color: UInt32?
        var layer: String?
        for pair in entity.pairs {
            switch pair.code {
            case 62:
                let ci = Int(number(pair))
                index = ci
                color = DxfParser.aciColor(abs(ci))
            case 420:
                color = UInt32(truncatingIfNeeded: Int(number(pair)))
            case 8:
                layer = string(pair)
            default:
                break
            }
        }
        if let ci = index, (1...255).contains(ci), let own = color, own != 0 {
            return own
        }
        if let name = layer, let layerColor = layerColors[name], layerColor != 0 {
            return layerColor
        }
        return DxfParser.defaultColor
    }

    private mutating func addEllipse(_ entity: DxfEntity, color: UInt32) {
        let center = point(entity, x: 10, y: 20)
        let major = point(entity, x: 11, y: 21)
        let majorLength = (major.x * major.x + major.y * major.y).squareRoot()
        guard majorLength > 0 else { return }
        let ratio = value(entity, 40) ?? 1
        let minor = SIMD2<Double>(-major.y * ratio, major.x * ratio)
        let start = value(entity, 41) ?? 0
        let end = value(entity, 42) ?? 2 * .pi
        var span = end - start
        while span <= 1e-9 { span += 2 * .pi }
        let segments = Swift.min(512, Swift.max(12, Int((majorLength * span).rounded(.up))))
        var previous: SIMD2<Double>?
        for i in 0...segments {
            let t = start + span * Double(i) / Double(segments)
            let p = center + cos(t) * major + sin(t) * minor
            if let a = previous { addEdge(a, p, color) }
            previous = p
        }
    }

    /// Circular arc, angles in radians counter-clockwise, about one segment per meter.
    private mutating func addArc(center: SIMD2<Double>, radius: Double, from start: Double, to end: Double, color: UInt32) {
        guard radius > 0 else { return }
        var span = end - start
        while span <= 1e-9 { span += 2 * .pi }
        let segments = Swift.min(512, Swift.max(8, Int((radius * span).rounded(.up))))
        var previous: SIMD2<Double>?
        for i in 0...segments {
            let t = start + span * Double(i) / Double(segments)
            let p = center + radius * SIMD2<Double>(cos(t), sin(t))
            if let a = previous { addEdge(a, p, color) }
            previous = p
        }
    }

    private mutating func addPolyline(_ polyline: DxfOpenPolyline) {
        let points = polyline.points
        guard points.count >= 2 else { return }
        for i in 0..<(points.count - 1) {
            addEdge(points[i], points[i + 1], polyline.color)
        }
        if polyline.isClosed, points.count > 2 {
            addEdge(points[points.count - 1], points[0], polyline.color)
        }
    }

    private mutating func addEdge(_ a: SIMD2<Double>, _ b: SIMD2<Double>, _ color: UInt32) {
        edges.append(DxfEdge(x1: a.x, y1: a.y, x2: b.x, y2: b.y, color: color))
    }

    // MARK: Values

    private func point(_ entity: DxfEntity, x: Int, y: Int) -> SIMD2<Double> {
        return [value(entity, x) ?? 0, value(entity, y) ?? 0]
    }

    private func value(_ entity: DxfEntity, _ code: Int) -> Double? {
        return entity.pairs.first { $0.code == code }.map { number($0) }
    }

    private func number(_ pair: DxfPair) -> Double {
        let pointer = UnsafeRawPointer(buffer.baseAddress! + pair.start).assumingMemoryBound(to: CChar.self)
        return strtod(pointer, nil)
    }

    private func string(_ pair: DxfPair) -> String {
        return String(decoding: UnsafeBufferPointer(rebasing: buffer[pair.start..<pair.end]), as: UTF8.self)
    }

    // MARK: Lines

    private mutating func nextPair() -> DxfPair? {
        guard let codeLine = nextLine(), let valueLine = nextLine() else { return nil }
        var code = 0
        var hasDigit = false
        for index in codeLine {
            let byte = buffer[index]
            guard byte >= 0x30, byte <= 0x39 else { return nil }
            code = code * 10 + Int(byte - 0x30)
            hasDigit = true
        }
        guard hasDigit else { return nil }
        return DxfPair(code: code, start: valueLine.lowerBound, end: valueLine.upperBound)
    }

    /// Next line without its line break and surrounding blanks.
    private mutating func nextLine() -> Range<Int>? {
        let count = buffer.count - 1 // trailing NUL
        guard position < count else { return nil }
        var end = position
        while end < count, buffer[end] != 0x0A { end += 1 }
        var lower = position
        var upper = end
        position = end + 1
        while lower < upper, Self.isBlank(buffer[lower]) { lower += 1 }
        while upper > lower, Self.isBlank(buffer[upper - 1]) { upper -= 1 }
        return lower..<upper
    }

    private static func isBlank(_ byte: UInt8) -> Bool {
        return byte == 0x20 || byte == 0x09 || byte == 0x0D
    }
}
