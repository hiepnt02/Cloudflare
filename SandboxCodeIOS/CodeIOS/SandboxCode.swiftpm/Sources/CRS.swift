//
//  CRS.swift
//  Quick3DDemo
//
//  Bảng hệ toạ độ + phép chiếu, thay cho proj4 của ply-to-gsx-viewer.html (iOS không có proj4).
//  Tập con dùng trong HTML: WGS84 UTM 48–56N, JGD2011/JGD2000 (UTM 51–55N + 19 múi phẳng Nhật),
//  VN-2000 (UTM 48/49N, TM-3 482 & Đà Nẵng), Tokyo datum. Tất cả là longlat hoặc Transverse Mercator
//  nên chỉ cần: TM thuận/nghịch (Snyder 1987), geodetic ↔ ECEF, Helmert 7 tham số (position vector,
//  cùng quy ước +towgs84 của PROJ). Sai số so với proj4 cỡ mm trong phạm vi múi.
//

import Foundation

enum CRS {

    struct Ellipsoid { let a: Double; let f: Double }
    static let wgs84 = Ellipsoid(a: 6378137, f: 1 / 298.257223563)
    static let grs80 = Ellipsoid(a: 6378137, f: 1 / 298.257222101)
    static let bessel = Ellipsoid(a: 6377397.155, f: 1 / 299.1528128)

    enum Projection {
        case longlat
        case tmerc(lat0: Double, lon0: Double, k: Double, x0: Double, y0: Double)   // độ, m
    }

    struct Def {
        let code: String
        let label: String
        let proj: Projection
        let ellps: Ellipsoid
        /// dx dy dz (m), rx ry rz (arcsec), ds (ppm) → WGS84. Toàn 0 = chính là WGS84/GRS80.
        let towgs84: [Double]
        var isGeographic: Bool { if case .longlat = proj { return true }; return false }
    }

    static func utm(_ zone: Int) -> Projection { .tmerc(lat0: 0, lon0: Double(zone) * 6 - 183, k: 0.9996, x0: 500_000, y0: 0) }

    private static let jpZones: [(Double, Double)] = [(33, 129.5), (33, 131), (36, 132 + 10.0 / 60), (33, 133.5), (36, 134 + 20.0 / 60), (36, 136), (36, 137 + 10.0 / 60), (36, 138.5), (36, 139 + 50.0 / 60), (40, 140 + 50.0 / 60), (44, 140.25), (44, 142.25), (44, 144.25), (26, 142), (26, 127.5), (26, 124), (26, 131), (20, 136), (26, 154)]
    private static let roman = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX"]
    private static let zero7 = [Double](repeating: 0, count: 7)
    private static let vn2000: [Double] = [-191.90441429, -39.30318279, -111.45032835, -0.00928836, 0.01975479, -0.00427372, 0.252906278]
    private static let tokyo: [Double] = [-146.414, 507.337, 680.507, 0, 0, 0, 0]

    static let catalog: [Def] = {
        var c: [Def] = []
        c.append(Def(code: "EPSG:4326", label: "EPSG:4326 / WGS 84 (lat/lon, độ)", proj: .longlat, ellps: wgs84, towgs84: zero7))
        for z in 48 ... 56 { c.append(Def(code: "EPSG:326\(z)", label: "EPSG:326\(z) / WGS 84 / UTM zone \(z)N", proj: utm(z), ellps: wgs84, towgs84: zero7)) }
        c.append(Def(code: "EPSG:6668", label: "EPSG:6668 / JGD2011 (lat/lon)", proj: .longlat, ellps: grs80, towgs84: zero7))
        for z in 51 ... 55 { c.append(Def(code: "EPSG:66\(z + 37)", label: "EPSG:66\(z + 37) / JGD2011 / UTM zone \(z)N", proj: utm(z), ellps: grs80, towgs84: zero7)) }
        for (i, zn) in jpZones.enumerated() { c.append(Def(code: "EPSG:\(6669 + i)", label: "EPSG:\(6669 + i) / JGD2011 / Japan Plane Rectangular CS \(roman[i])", proj: .tmerc(lat0: zn.0, lon0: zn.1, k: 0.9999, x0: 0, y0: 0), ellps: grs80, towgs84: zero7)) }
        for (i, zn) in jpZones.enumerated() { c.append(Def(code: "EPSG:\(2443 + i)", label: "EPSG:\(2443 + i) / JGD2000 / Japan Plane Rectangular CS \(roman[i])", proj: .tmerc(lat0: zn.0, lon0: zn.1, k: 0.9999, x0: 0, y0: 0), ellps: grs80, towgs84: zero7)) }
        for z in 51 ... 55 { c.append(Def(code: "EPSG:\(3097 + z - 51)", label: "EPSG:\(3097 + z - 51) / JGD2000 / UTM zone \(z)N", proj: utm(z), ellps: grs80, towgs84: zero7)) }
        c.append(Def(code: "EPSG:4756", label: "EPSG:4756 / VN-2000 (lat/lon)", proj: .longlat, ellps: wgs84, towgs84: vn2000))
        c.append(Def(code: "EPSG:3405", label: "EPSG:3405 / VN-2000 / UTM zone 48N", proj: utm(48), ellps: wgs84, towgs84: vn2000))
        c.append(Def(code: "EPSG:3406", label: "EPSG:3406 / VN-2000 / UTM zone 49N", proj: utm(49), ellps: wgs84, towgs84: vn2000))
        c.append(Def(code: "EPSG:5897", label: "EPSG:5897 / VN-2000 / TM-3 zone 482 (lon0 107°30′)", proj: .tmerc(lat0: 0, lon0: 107.5, k: 0.9999, x0: 500_000, y0: 0), ellps: wgs84, towgs84: vn2000))
        c.append(Def(code: "EPSG:5899", label: "EPSG:5899 / VN-2000 / TM-3 Da Nang zone (lon0 107°45′)", proj: .tmerc(lat0: 0, lon0: 107.75, k: 0.9999, x0: 500_000, y0: 0), ellps: wgs84, towgs84: vn2000))
        c.append(Def(code: "EPSG:4301", label: "EPSG:4301 / Tokyo datum (lat/lon)", proj: .longlat, ellps: bessel, towgs84: tokyo))
        return c
    }()

    static func byCode(_ code: String) -> Def? { catalog.first { $0.code == code } }

    /// Hệ HIỂN THỊ cố định của viewer (= "Hệ đích (Quick3D)" mặc định trong ply-to-gsx-viewer.html).
    /// PLY là raw, không có hệ; người dùng GÁN hệ gốc cho nó, app đổi sang hệ này để xem vật thể dịch đi đâu.
    static let displaySystem = "EPSG:5897"

    // MARK: - forward(from → to), như proj4(from.def, to.def).forward([x, y])

    static func forward(from: Def, to: Def, x: Double, y: Double) -> (Double, Double) {
        // 1. hệ nguồn → lat/lon (rad) trên ellipsoid nguồn
        var (lon, lat): (Double, Double)
        switch from.proj {
        case .longlat: (lon, lat) = (x * .pi / 180, y * .pi / 180)
        case .tmerc(let lat0, let lon0, let k, let x0, let y0): (lon, lat) = tmInverse(from.ellps, lat0 * .pi / 180, lon0 * .pi / 180, k, x0, y0, x, y)
        }
        // 2. đổi datum qua WGS84 (chỉ khi khác)
        if from.towgs84 != to.towgs84 || from.ellps.a != to.ellps.a || from.ellps.f != to.ellps.f {
            var ecef = geodeticToECEF(from.ellps, lat, lon)
            if from.towgs84 != zero7 { ecef = helmert(ecef, from.towgs84, inverse: false) }
            if to.towgs84 != zero7 { ecef = helmert(ecef, to.towgs84, inverse: true) }
            (lat, lon) = ecefToGeodetic(to.ellps, ecef)
        }
        // 3. lat/lon → hệ đích
        switch to.proj {
        case .longlat: return (lon * 180 / .pi, lat * 180 / .pi)
        case .tmerc(let lat0, let lon0, let k, let x0, let y0): return tmForward(to.ellps, lat0 * .pi / 180, lon0 * .pi / 180, k, x0, y0, lat, lon)
        }
    }

    // MARK: - Transverse Mercator (Snyder, Map Projections — A Working Manual, 8-9…8-25)

    private static func meridianArc(_ e: Ellipsoid, _ phi: Double) -> Double {
        let e2 = 2 * e.f - e.f * e.f, e4 = e2 * e2, e6 = e4 * e2
        return e.a * ((1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * phi
                      - (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * sin(2 * phi)
                      + (15 * e4 / 256 + 45 * e6 / 1024) * sin(4 * phi)
                      - (35 * e6 / 3072) * sin(6 * phi))
    }

    private static func tmForward(_ e: Ellipsoid, _ lat0: Double, _ lon0: Double, _ k: Double, _ x0: Double, _ y0: Double, _ phi: Double, _ lam: Double) -> (Double, Double) {
        let e2 = 2 * e.f - e.f * e.f, ep2 = e2 / (1 - e2)
        let sinp = sin(phi), cosp = cos(phi), tanp = tan(phi)
        let N = e.a / sqrt(1 - e2 * sinp * sinp), T = tanp * tanp, C = ep2 * cosp * cosp, A = (lam - lon0) * cosp
        let M = meridianArc(e, phi), M0 = meridianArc(e, lat0)
        let A2 = A * A, A3 = A2 * A, A4 = A3 * A, A5 = A4 * A, A6 = A5 * A
        let x = x0 + k * N * (A + (1 - T + C) * A3 / 6 + (5 - 18 * T + T * T + 72 * C - 58 * ep2) * A5 / 120)
        let y = y0 + k * (M - M0 + N * tanp * (A2 / 2 + (5 - T + 9 * C + 4 * C * C) * A4 / 24 + (61 - 58 * T + T * T + 600 * C - 330 * ep2) * A6 / 720))
        return (x, y)
    }

    private static func tmInverse(_ e: Ellipsoid, _ lat0: Double, _ lon0: Double, _ k: Double, _ x0: Double, _ y0: Double, _ x: Double, _ y: Double) -> (lon: Double, lat: Double) {
        let e2 = 2 * e.f - e.f * e.f, e4 = e2 * e2, e6 = e4 * e2, ep2 = e2 / (1 - e2)
        let M = meridianArc(e, lat0) + (y - y0) / k
        let mu = M / (e.a * (1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256))
        let e1 = (1 - sqrt(1 - e2)) / (1 + sqrt(1 - e2))
        let phi1 = mu + (3 * e1 / 2 - 27 * pow(e1, 3) / 32) * sin(2 * mu) + (21 * e1 * e1 / 16 - 55 * pow(e1, 4) / 32) * sin(4 * mu)
            + (151 * pow(e1, 3) / 96) * sin(6 * mu) + (1097 * pow(e1, 4) / 512) * sin(8 * mu)
        let sinp = sin(phi1), cosp = cos(phi1), tanp = tan(phi1)
        let C1 = ep2 * cosp * cosp, T1 = tanp * tanp
        let N1 = e.a / sqrt(1 - e2 * sinp * sinp), R1 = e.a * (1 - e2) / pow(1 - e2 * sinp * sinp, 1.5)
        let D = (x - x0) / (N1 * k), D2 = D * D, D3 = D2 * D, D4 = D3 * D, D5 = D4 * D, D6 = D5 * D
        let phi = phi1 - (N1 * tanp / R1) * (D2 / 2 - (5 + 3 * T1 + 10 * C1 - 4 * C1 * C1 - 9 * ep2) * D4 / 24
                                             + (61 + 90 * T1 + 298 * C1 + 45 * T1 * T1 - 252 * ep2 - 3 * C1 * C1) * D6 / 720)
        let lam = lon0 + (D - (1 + 2 * T1 + C1) * D3 / 6 + (5 - 2 * C1 + 28 * T1 - 3 * C1 * C1 + 8 * ep2 + 24 * T1 * T1) * D5 / 120) / cosp
        return (lam, phi)
    }

    // MARK: - Datum

    private static func geodeticToECEF(_ e: Ellipsoid, _ lat: Double, _ lon: Double) -> SIMD3<Double> {
        let e2 = 2 * e.f - e.f * e.f
        let N = e.a / sqrt(1 - e2 * sin(lat) * sin(lat))
        return SIMD3(N * cos(lat) * cos(lon), N * cos(lat) * sin(lon), N * (1 - e2) * sin(lat))       // h = 0
    }

    private static func ecefToGeodetic(_ e: Ellipsoid, _ p: SIMD3<Double>) -> (lat: Double, lon: Double) {
        let e2 = 2 * e.f - e.f * e.f
        let lon = atan2(p.y, p.x), r = hypot(p.x, p.y)
        var lat = atan2(p.z, r * (1 - e2))
        for _ in 0 ..< 6 {
            let N = e.a / sqrt(1 - e2 * sin(lat) * sin(lat))
            lat = atan2(p.z + e2 * N * sin(lat), r)
        }
        return (lat, lon)
    }

    /// Helmert 7 tham số, quy ước position vector như PROJ +towgs84. inverse = dùng tham số đổi dấu.
    private static func helmert(_ p: SIMD3<Double>, _ t: [Double], inverse: Bool) -> SIMD3<Double> {
        let s: Double = inverse ? -1 : 1
        let dx = s * t[0], dy = s * t[1], dz = s * t[2]
        let rx = s * t[3] * .pi / 648_000, ry = s * t[4] * .pi / 648_000, rz = s * t[5] * .pi / 648_000
        let m = 1 + s * t[6] * 1e-6
        return SIMD3(dx + m * (p.x - rz * p.y + ry * p.z),
                     dy + m * (rz * p.x + p.y - rx * p.z),
                     dz + m * (-ry * p.x + rx * p.y + p.z))
    }
}
